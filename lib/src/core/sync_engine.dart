import 'dart:async';
import 'dart:math' as math;

import 'package:rxdart/rxdart.dart';
import 'package:synq_manager/src/adapters/local_adapter.dart';
import 'package:synq_manager/src/adapters/remote_adapter.dart';
import 'package:synq_manager/src/config/synq_config.dart';
import 'package:synq_manager/src/core/conflict_detector.dart';
import 'package:synq_manager/src/core/queue_manager.dart';
import 'package:synq_manager/src/events/conflict_event.dart';
import 'package:synq_manager/src/events/data_change_event.dart';
import 'package:synq_manager/src/events/sync_event.dart';
import 'package:synq_manager/src/middleware/synq_middleware.dart';
import 'package:synq_manager/src/models/conflict_context.dart';
import 'package:synq_manager/src/models/conflict_resolution.dart';
import 'package:synq_manager/src/models/exceptions.dart';
import 'package:synq_manager/src/models/sync_metadata.dart';
import 'package:synq_manager/src/models/sync_operation.dart';
import 'package:synq_manager/src/models/sync_result.dart';
import 'package:synq_manager/src/models/sync_scope.dart';
import 'package:synq_manager/src/models/syncable_entity.dart';
import 'package:synq_manager/src/resolvers/sync_conflict_resolver.dart';
import 'package:synq_manager/src/utils/connectivity_checker.dart';
import 'package:synq_manager/src/utils/hash_generator.dart';
import 'package:synq_manager/src/utils/logger.dart';

/// Engine responsible for executing synchronization operations
/// between local and remote data sources.
///
/// Manages the full sync lifecycle including conflict
/// detection, resolution, retry logic,
/// and progress tracking. Coordinates with adapters,
/// resolvers, and middleware to ensure
/// reliable bidirectional data synchronization.
class SyncEngine<T extends SyncableEntity> {
  /// Creates a new sync engine with the specified dependencies.
  SyncEngine({
    required this.localAdapter,
    required this.remoteAdapter,
    required this.conflictResolver,
    required this.queueManager,
    required this.conflictDetector,
    required this.logger,
    required this.config,
    required this.connectivityChecker,
    required this.eventController,
    required this.statusSubject,
    required this.middlewares,
  });

  /// Adapter for local data storage operations.
  final LocalAdapter<T> localAdapter;

  /// Adapter for remote data source operations.
  final RemoteAdapter<T> remoteAdapter;

  /// Resolver for handling sync conflicts.
  final SyncConflictResolver<T> conflictResolver;

  /// Manager for queued sync operations.
  final QueueManager<T> queueManager;

  /// Detector for identifying conflicts.
  final ConflictDetector<T> conflictDetector;

  /// Logger for sync operations.
  final SynqLogger logger;

  /// Configuration for sync behavior.
  final SynqConfig config;

  /// Checker for network connectivity.
  final ConnectivityChecker connectivityChecker;

  /// Controller for sync events.
  final StreamController<SyncEvent<T>> eventController;

  /// Subject for sync status updates.
  final BehaviorSubject<SyncStatusSnapshot> statusSubject;

  /// Middleware chain for sync operations.
  final List<SynqMiddleware<T>> middlewares;

  final Set<String> _activeSyncs = <String>{};
  final Set<String> _pausedUsers = <String>{};
  final Set<String> _cancelledUsers = <String>{};
  final Map<String, Completer<void>> _pauseCompleters = {};
  final Map<String, SyncStatusSnapshot> _latestSnapshots = {};
  final HashGenerator _hashGenerator = const HashGenerator();

  /// Synchronizes data for the specified user between local and remote sources.
  ///
  /// Executes the full sync cycle: push local changes, pull remote changes,
  /// detect and resolve conflicts. Can be
  /// forced to run regardless of conditions.
  /// Honors timeout and cancellation. Returns a detailed result summary.
  Future<SyncResult> synchronize(
    String userId, {
    bool force = false,
    SyncOptions? options,
    SyncScope? scope,
  }) async {
    if (_activeSyncs.contains(userId)) {
      throw StateError('Sync already in progress for user $userId');
    }

    _activeSyncs.add(userId);
    final stopwatch = Stopwatch()..start();
    final startedAt = DateTime.now();
    final deadline = _calculateDeadline(options);
    var completed = 0;
    var failed = 0;
    var conflictsResolved = 0;
    final errors = <Object>[];

    try {
      await queueManager.initializeUser(userId);
      final pendingOperations = queueManager.getPending(userId);

      eventController.add(
        SyncStartedEvent<T>(
          userId: userId,
          pendingOperations: pendingOperations.length,
        ),
      );

      _updateStatus(
        userId,
        SyncStatus.syncing,
        pendingOperations: pendingOperations.length,
        completedOperations: completed,
        failedOperations: failed,
        lastStartedAt: startedAt,
      );

      await _ensureConnectivity(userId);

      for (final middleware in middlewares) {
        await middleware.beforeSync(userId);
      }

      await _processPendingOperations(
        userId,
        pendingOperations,
        options: options,
        deadline: deadline,
        onCompleted: (operation, result) {
          completed += 1;
          eventController.add(
            SyncProgressEvent<T>(
              userId: userId,
              completed: completed,
              total: pendingOperations.length,
            ),
          );
          _updateStatus(
            userId,
            SyncStatus.syncing,
            pendingOperations: queueManager.getPending(userId).length,
            completedOperations: completed,
            failedOperations: failed,
          );
        },
        onFailed: (operation, error, stackTrace) {
          // This path is now for non-retryable errors or exhausted retries.
          failed += 1;
          errors.add(error);
          logger.warn(
            'Operation ${operation.id} failed for user $userId: $error',
          );
          _updateStatus(
            userId,
            SyncStatus.syncing,
            pendingOperations: queueManager.getPending(userId).length,
            completedOperations: completed,
            failedOperations: failed,
          );
        },
      );

      if (_cancelledUsers.remove(userId)) {
        throw _SyncCancelledException();
      }

      final localMetadata = await localAdapter.getSyncMetadata(userId);
      final remoteMetadata = await remoteAdapter.getSyncMetadata(userId);

      final shouldForce = force || (options?.forceFullSync ?? false);
      final shouldSyncRemotely = shouldForce ||
          pendingOperations.isNotEmpty ||
          _shouldSynchronize(localMetadata, remoteMetadata);

      _ensureNotTimedOut(deadline);

      if (shouldSyncRemotely) {
        final remoteItems = await remoteAdapter.fetchAll(userId, scope: scope);
        final remoteSummary = await _reconcileRemoteItems(
          userId,
          remoteItems,
          deadline: deadline,
          resolveConflicts: options?.resolveConflicts ?? true,
          isPartialSync: scope != null,
          localMetadata: localMetadata,
          remoteMetadata: remoteMetadata,
          onConflictResolved: (resolution, context, localItem, remoteItem) {
            conflictsResolved += 1;
            eventController.add(
              ConflictDetectedEvent<T>(
                userId: userId,
                context: context,
                localData: localItem,
                remoteData: remoteItem,
              ),
            );
            _notifyMiddlewareConflict(context, localItem, remoteItem);
          },
        );
        conflictsResolved += remoteSummary.remoteConflicts;
      }

      final currentItems = await localAdapter.getAll(userId: userId);
      final metadata = SyncMetadata(
        userId: userId,
        lastSyncTime: DateTime.now(),
        dataHash: _hashGenerator.hashEntities(currentItems),
        itemCount: currentItems.length,
      );
      await localAdapter.updateSyncMetadata(metadata, userId);
      await remoteAdapter.updateSyncMetadata(metadata, userId);

      stopwatch.stop();

      final result = SyncResult(
        userId: userId,
        syncedCount: completed,
        failedCount: failed,
        conflictsResolved: conflictsResolved,
        pendingOperations: queueManager
            .getPending(userId)
            .cast<SyncOperation<SyncableEntity>>(),
        duration: stopwatch.elapsed,
        errors: errors,
      );

      for (final middleware in middlewares) {
        await middleware.afterSync(userId, result);
      }

      eventController.add(
        SyncCompletedEvent<T>(
          userId: userId,
          synced: completed,
          failed: failed,
        ),
      );

      _updateStatus(
        userId,
        failed > 0 ? SyncStatus.failed : SyncStatus.completed,
        pendingOperations: queueManager.getPending(userId).length,
        completedOperations: completed,
        failedOperations: failed,
        lastCompletedAt: DateTime.now(),
      );

      return result;
    } on _SyncCancelledException {
      stopwatch.stop();

      _updateStatus(
        userId,
        SyncStatus.cancelled,
        pendingOperations: queueManager.getPending(userId).length,
        completedOperations: 0,
        failedOperations: 0,
        lastCompletedAt: DateTime.now(),
      );

      eventController.add(
        SyncErrorEvent<T>(
          userId: userId,
          error: 'Sync cancelled',
        ),
      );

      return SyncResult(
        userId: userId,
        syncedCount: completed,
        failedCount: failed,
        conflictsResolved: 0,
        pendingOperations: queueManager
            .getPending(userId)
            .cast<SyncOperation<SyncableEntity>>(),
        duration: stopwatch.elapsed,
        wasCancelled: true,
      );
    } on _SyncTimeoutException catch (timeout) {
      stopwatch.stop();
      logger.error(
        'Sync timed out for user $userId after ${timeout.duration}',
        timeout,
        StackTrace.current,
      );

      final pendingCount = queueManager.getPending(userId).length;
      final snapshot = _latestSnapshots[userId];

      _updateStatus(
        userId,
        SyncStatus.failed,
        pendingOperations: pendingCount,
        completedOperations: snapshot?.completedOperations ?? completed,
        failedOperations: snapshot?.failedOperations ?? failed,
        lastCompletedAt: DateTime.now(),
      );

      eventController.add(
        SyncErrorEvent<T>(
          userId: userId,
          error: 'Sync timed out after ${timeout.duration}',
        ),
      );

      return SyncResult(
        userId: userId,
        syncedCount: snapshot?.completedOperations ?? completed,
        failedCount: snapshot?.failedOperations ?? failed,
        conflictsResolved: conflictsResolved,
        pendingOperations: queueManager
            .getPending(userId)
            .cast<SyncOperation<SyncableEntity>>(),
        duration: stopwatch.elapsed,
        errors: errors..add(TimeoutException('Sync timed out')),
      );
    } on Object catch (error, stackTrace) {
      stopwatch.stop();
      logger.error('Sync failed for $userId: $error', error, stackTrace);

      _updateStatus(
        userId,
        SyncStatus.failed,
        pendingOperations: queueManager.getPending(userId).length,
        completedOperations: completed,
        failedOperations:
            failed == 0 ? queueManager.getPending(userId).length : failed,
        lastCompletedAt: DateTime.now(),
      );

      eventController.add(
        SyncErrorEvent<T>(
          userId: userId,
          error: error.toString(),
          stackTrace: stackTrace,
        ),
      );

      rethrow;
    } finally {
      _activeSyncs.remove(userId);
    }
  }

  /// Pauses the synchronization process for a specific user.
  ///
  /// While paused, no new sync operations will be executed for the user.
  /// Returns a future that completes when the sync is resumed.
  Future<void> pause(String userId) async {
    if (_pausedUsers.contains(userId)) return;
    _pausedUsers.add(userId);
    final completer = Completer<void>();
    _pauseCompleters[userId] = completer;

    _updateStatus(
      userId,
      SyncStatus.paused,
      pendingOperations: queueManager.getPending(userId).length,
      completedOperations: 0,
      failedOperations: 0,
    );

    await completer.future;
  }

  /// Resumes a paused synchronization process for a specific user.
  ///
  /// Completes the pause future and allows sync operations to continue.
  void resume(String userId) {
    if (!_pausedUsers.remove(userId)) return;
    _pauseCompleters.remove(userId)?.complete();

    _updateStatus(
      userId,
      SyncStatus.syncing,
      pendingOperations: queueManager.getPending(userId).length,
      completedOperations: 0,
      failedOperations: 0,
    );
  }

  /// Cancels an ongoing synchronization process for a specific user.
  ///
  /// Sets the cancellation flag and completes any pending pause operations.
  void cancel(String userId) {
    _cancelledUsers.add(userId);
    _pauseCompleters.remove(userId)?.complete();
  }

  /// Gets the current sync status snapshot for a specific user.
  ///
  /// Returns the latest cached snapshot or creates a
  /// new idle snapshot if none exists.
  Future<SyncStatusSnapshot> getSnapshot(String userId) async {
    return _latestSnapshots[userId] ??
        SyncStatusSnapshot(
          userId: userId,
          status: SyncStatus.idle,
          pendingOperations: queueManager.getPending(userId).length,
          completedOperations: 0,
          failedOperations: 0,
          progress: 0,
        );
  }

  Future<void> _processPendingOperations(
    String userId,
    List<SyncOperation<T>> operations, {
    required SyncOptions? options,
    required DateTime? deadline,
    required void Function(SyncOperation<T> operation, T? result) onCompleted,
    required void Function(
      SyncOperation<T> operation,
      Object error,
      StackTrace stackTrace,
    ) onFailed,
  }) async {
    // This method now handles the retry logic internally.
    if (operations.isEmpty) return;

    final includeDeletes = options?.includeDeletes ?? true;
    final batchSize = _resolveBatchSize(options);

    for (var i = 0; i < operations.length; i += batchSize) {
      final batchEnd = math.min(i + batchSize, operations.length);
      final batch = operations.sublist(i, batchEnd);

      for (final operation in batch) {
        _ensureNotTimedOut(deadline);
        await _checkPaused(userId);

        if (_cancelledUsers.contains(userId)) {
          throw _SyncCancelledException();
        }

        if (!includeDeletes && operation.type == SyncOperationType.delete) {
          logger.debug(
            'Skipping delete operation ${operation.id} for user $userId',
          );
          continue;
        }

        try {
          for (final middleware in middlewares) {
            await middleware.beforeOperation(operation);
          }

          T? remoteResult;

          switch (operation.type) {
            case SyncOperationType.create:
            case SyncOperationType.update:
              final data = operation.data;
              if (data == null) {
                throw AdapterException(
                  'local',
                  'Operation ${operation.id} has no data to sync',
                );
              }
              final prepared = await _transformBeforeSave(data);
              remoteResult = await remoteAdapter.push(prepared, userId);
              final normalized = await _transformAfterFetch(remoteResult);
              await localAdapter.save(normalized, userId);
              eventController.add(
                DataChangeEvent<T>(
                  userId: userId,
                  data: normalized,
                  changeType: operation.type == SyncOperationType.create
                      ? ChangeType.created
                      : ChangeType.updated,
                  source: DataSource.remote,
                ),
              );
            case SyncOperationType.delete:
              await remoteAdapter.deleteRemote(operation.entityId, userId);
          }

          await queueManager.markCompleted(userId, operation.id);
          await _notifyAfterOperation(operation, remoteResult);
          onCompleted(operation, remoteResult);
        } on Object catch (error, stackTrace) {
          // Implement per-operation retry logic
          final canRetry =
              error is NetworkException || error is AdapterException;
          if (canRetry && operation.retryCount < config.maxRetries) {
            logger.debug(
              'Operation ${operation.id} failed, scheduling for retry '
              '(${operation.retryCount + 1}/${config.maxRetries})',
            );
            final updatedOp = operation.copyWith(
              retryCount: operation.retryCount + 1,
              lastAttemptAt: DateTime.now(),
            );
            await queueManager.update(userId, updatedOp);
            continue; // Continue to the next operation in the batch
          } else {
            await _notifyOperationError(operation, error, stackTrace);
            onFailed(operation, error, stackTrace);
          }
        }
      }
    }
  }

  Future<_RemoteSyncSummary> _reconcileRemoteItems(
    String userId,
    List<T> remoteItems, {
    required bool resolveConflicts,
    required bool isPartialSync,
    required DateTime? deadline,
    required SyncMetadata? localMetadata,
    required SyncMetadata? remoteMetadata,
    required void Function(
      ConflictResolution<T> resolution,
      ConflictContext context,
      T? localItem,
      T remoteItem,
    ) onConflictResolved,
  }) async {
    final pendingIds = queueManager
        .getPending(userId)
        .map((operation) => operation.entityId)
        .toSet();

    if (remoteItems.isEmpty) {
      final restored = await _restoreRemoteFromLocal(
        userId,
        pendingIds: pendingIds,
        deadline: deadline,
      );

      if (restored) {
        logger.info('Remote empty for $userId, restored from local cache.');
        return const _RemoteSyncSummary();
      }

      // Do not perform deletions if it's a partial sync
      if (!isPartialSync) {
        final deletions = await _applyRemoteDeletions(
          userId,
          remoteIds: const <String>{},
          pendingIds: pendingIds,
          deadline: deadline,
        );
        return _RemoteSyncSummary(remoteDeletes: deletions);
      }
      return const _RemoteSyncSummary();
    }

    final remoteIds = <String>{};
    var conflictCount = 0;

    // Batch-fetch all relevant local items at once to avoid N+1 queries.
    final remoteItemIds = remoteItems.map((item) => item.id).toList();
    final localItemsMap = await localAdapter.getByIds(remoteItemIds, userId);

    for (final remoteItem in remoteItems) {
      _ensureNotTimedOut(deadline);
      await _checkPaused(userId);

      if (_cancelledUsers.contains(userId)) {
        throw _SyncCancelledException();
      }

      remoteIds.add(remoteItem.id);

      final localItem = localItemsMap[remoteItem.id];

      if (remoteItem.isDeleted) {
        if (!pendingIds.contains(remoteItem.id)) {
          await localAdapter.delete(remoteItem.id, userId);
          eventController.add(
            DataChangeEvent<T>(
              userId: userId,
              data: remoteItem,
              changeType: ChangeType.deleted,
              source: DataSource.remote,
            ),
          );
        }
        continue;
      }

      if (!resolveConflicts) {
        final normalized = await _transformAfterFetch(remoteItem);
        await localAdapter.save(normalized, userId);
        eventController.add(
          DataChangeEvent<T>(
            userId: userId,
            data: normalized,
            changeType:
                localItem == null ? ChangeType.created : ChangeType.updated,
            source: DataSource.remote,
          ),
        );
        continue;
      }

      final conflictContext = conflictDetector.detect(
        localItem: localItem,
        remoteItem: remoteItem,
        userId: userId,
        localMetadata: localMetadata,
        remoteMetadata: remoteMetadata,
      );

      if (conflictContext != null) {
        final resolution = await conflictResolver.resolve(
          localItem: localItem,
          remoteItem: remoteItem,
          context: conflictContext,
        );

        await _applyConflictResolution(
          userId,
          resolution,
          conflictContext,
          localItem,
          remoteItem,
        );

        onConflictResolved(resolution, conflictContext, localItem, remoteItem);
        conflictCount += 1;
      } else {
        final normalized = await _transformAfterFetch(remoteItem);
        await localAdapter.save(normalized, userId);
        eventController.add(
          DataChangeEvent<T>(
            userId: userId,
            data: normalized,
            changeType:
                localItem == null ? ChangeType.created : ChangeType.updated,
            source: DataSource.remote,
          ),
        );
      }
    }

    var deletions = 0;
    // Only apply deletions if this is a full sync
    if (!isPartialSync) {
      deletions = await _applyRemoteDeletions(
        userId,
        remoteIds: remoteIds,
        pendingIds: pendingIds,
        deadline: deadline,
      );
    }
    return _RemoteSyncSummary(
      remoteConflicts: conflictCount,
      remoteDeletes: deletions,
    );
  }

  Future<int> _applyRemoteDeletions(
    String userId, {
    required Set<String> remoteIds,
    required DateTime? deadline,
    Set<String>? pendingIds,
  }) async {
    final pending = pendingIds ??
        queueManager
            .getPending(userId)
            .map((operation) => operation.entityId)
            .toSet();

    var deletions = 0;
    final localItems = await localAdapter.getAll(userId: userId);
    for (final localItem in localItems) {
      _ensureNotTimedOut(deadline);
      if (remoteIds.contains(localItem.id)) {
        continue;
      }
      if (pending.contains(localItem.id)) {
        continue;
      }

      await localAdapter.delete(localItem.id, userId);
      deletions += 1;

      eventController.add(
        DataChangeEvent<T>(
          userId: userId,
          data: localItem,
          changeType: ChangeType.deleted,
          source: DataSource.remote,
        ),
      );
    }

    return deletions;
  }

  Future<bool> _restoreRemoteFromLocal(
    String userId, {
    required Set<String> pendingIds,
    required DateTime? deadline,
  }) async {
    final localItems = await localAdapter.getAll(userId: userId);
    final candidates = localItems
        .where((item) => !item.isDeleted && !pendingIds.contains(item.id))
        .toList();

    if (candidates.isEmpty) {
      return false;
    }

    for (final item in candidates) {
      _ensureNotTimedOut(deadline);
      await _checkPaused(userId);

      if (_cancelledUsers.contains(userId)) {
        throw _SyncCancelledException();
      }

      final prepared = await _transformBeforeSave(item);
      final remoteResult = await remoteAdapter.push(prepared, userId);
      final normalized = await _transformAfterFetch(remoteResult);
      await localAdapter.save(normalized, userId);

      eventController.add(
        DataChangeEvent<T>(
          userId: userId,
          data: normalized,
          changeType: ChangeType.updated,
          source: DataSource.remote,
        ),
      );
    }

    return true;
  }

  Future<void> _applyConflictResolution(
    String userId,
    ConflictResolution<T> resolution,
    ConflictContext context,
    T? localItem,
    T remoteItem,
  ) async {
    switch (resolution.strategy) {
      case ResolutionStrategy.useLocal:
        if (localItem != null) {
          await remoteAdapter.push(localItem, userId);
        }
      case ResolutionStrategy.useRemote:
        if (resolution.resolvedData != null) {
          final normalized =
              await _transformAfterFetch(resolution.resolvedData!);
          await localAdapter.save(normalized, userId);
          eventController.add(
            DataChangeEvent<T>(
              userId: userId,
              data: normalized,
              changeType:
                  localItem == null ? ChangeType.created : ChangeType.updated,
              source: DataSource.remote,
            ),
          );
        }
      case ResolutionStrategy.merge:
        if (resolution.resolvedData != null) {
          final mergedLocal =
              await _transformBeforeSave(resolution.resolvedData!);
          await localAdapter.save(mergedLocal, userId);
          await remoteAdapter.push(mergedLocal, userId);
          eventController.add(
            DataChangeEvent<T>(
              userId: userId,
              data: mergedLocal,
              changeType: ChangeType.updated,
              source: DataSource.merged,
            ),
          );
        }
      case ResolutionStrategy.askUser:
      case ResolutionStrategy.abort:
        logger.warn(
          'Conflict for entity ${context.entityId} requires manual action.',
        );
    }
  }

  Future<void> _checkPaused(String userId) async {
    if (_pausedUsers.contains(userId)) {
      final completer = _pauseCompleters[userId];
      if (completer != null && !completer.isCompleted) {
        await completer.future;
      }
    }
  }

  void _notifyMiddlewareConflict(
    ConflictContext context,
    T? localItem,
    T remoteItem,
  ) {
    for (final middleware in middlewares) {
      unawaited(middleware.onConflict(context, localItem, remoteItem));
    }
  }

  Future<void> _notifyAfterOperation(
    SyncOperation<T> operation,
    T? result,
  ) async {
    for (final middleware in middlewares) {
      await middleware.afterOperation(operation, result);
    }
  }

  Future<void> _notifyOperationError(
    SyncOperation<T> operation,
    Object error,
    StackTrace stackTrace,
  ) async {
    final synqError = error is SynqException
        ? error
        : AdapterException('remote', error.toString(), stackTrace);
    for (final middleware in middlewares) {
      await middleware.onOperationError(operation, synqError);
    }
  }

  int _resolveBatchSize(SyncOptions? options) {
    final override = options?.overrideBatchSize;
    if (override != null && override > 0) {
      return override;
    }
    return math.max(1, config.batchSize);
  }

  void _ensureNotTimedOut(DateTime? deadline) {
    if (deadline == null) return;
    final now = DateTime.now();
    if (now.isAfter(deadline)) {
      throw _SyncTimeoutException(now.difference(deadline));
    }
  }

  DateTime? _calculateDeadline(SyncOptions? options) {
    final durations = <Duration>[];
    if (config.syncTimeout > Duration.zero) {
      durations.add(config.syncTimeout);
    }
    final timeout = options?.timeout;
    if (timeout != null && timeout > Duration.zero) {
      durations.add(timeout);
    }
    if (durations.isEmpty) return null;
    var shortest = durations.first;
    for (final duration in durations.skip(1)) {
      if (duration.compareTo(shortest) < 0) {
        shortest = duration;
      }
    }
    return DateTime.now().add(shortest);
  }

  Future<void> _ensureConnectivity(String userId) async {
    final connected = await connectivityChecker.isConnected;
    final remoteAvailable = await remoteAdapter.isConnected();
    if (!connected || !remoteAvailable) {
      throw NetworkException(
        'No network connectivity available for sync of user $userId',
      );
    }
  }

  bool _shouldSynchronize(SyncMetadata? local, SyncMetadata? remote) {
    if (local == null || remote == null) return true;
    if (local.dataHash != remote.dataHash) return true;
    if (local.itemCount != remote.itemCount) return true;
    return false;
  }

  Future<T> _transformBeforeSave(T item) async {
    var transformed = item;
    for (final middleware in middlewares) {
      transformed = await middleware.transformBeforeSave(transformed);
    }
    return transformed;
  }

  Future<T> _transformAfterFetch(T item) async {
    var transformed = item;
    for (final middleware in middlewares) {
      transformed = await middleware.transformAfterFetch(transformed);
    }
    return transformed;
  }

  void _updateStatus(
    String userId,
    SyncStatus status, {
    required int pendingOperations,
    required int completedOperations,
    required int failedOperations,
    DateTime? lastStartedAt,
    DateTime? lastCompletedAt,
  }) {
    final total = pendingOperations + completedOperations + failedOperations;
    final progress = total == 0 ? 1.0 : completedOperations / total;

    final snapshot = SyncStatusSnapshot(
      userId: userId,
      status: status,
      pendingOperations: pendingOperations,
      completedOperations: completedOperations,
      failedOperations: failedOperations,
      progress: progress.clamp(0, 1),
      lastStartedAt: lastStartedAt ?? _latestSnapshots[userId]?.lastStartedAt,
      lastCompletedAt:
          lastCompletedAt ?? _latestSnapshots[userId]?.lastCompletedAt,
    );

    _latestSnapshots[userId] = snapshot;

    if (!statusSubject.isClosed) {
      statusSubject.add(snapshot);
    }
  }
}

class _RemoteSyncSummary {
  const _RemoteSyncSummary({
    this.remoteConflicts = 0,
    this.remoteDeletes = 0,
  });

  final int remoteConflicts;
  final int remoteDeletes;
}

class _SyncCancelledException implements Exception {}

class _SyncTimeoutException implements Exception {
  _SyncTimeoutException(this.duration);

  final Duration duration;
}
