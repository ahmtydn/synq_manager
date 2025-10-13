import 'dart:async';

import 'package:crypto/crypto.dart';
import 'package:synq_manager/synq_manager.dart';

/// The core engine that orchestrates the synchronization process.
class SyncEngine<T extends SyncableEntity> {
  /// Creates a [SyncEngine].
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
    required this.metadataSubject,
    required this.observers,
    required this.middlewares,
  });

  /// The local data adapter.
  final LocalAdapter<T> localAdapter;

  /// The remote data adapter.
  final RemoteAdapter<T> remoteAdapter;

  /// The conflict resolver.
  final SyncConflictResolver<T> conflictResolver;

  /// The queue manager for pending operations.
  final QueueManager<T> queueManager;

  /// The conflict detector.
  final ConflictDetector<T> conflictDetector;

  /// The logger instance.
  final SynqLogger logger;

  /// The synchronization configuration.
  final SynqConfig<T> config;

  /// The connectivity checker.
  final ConnectivityChecker connectivityChecker;

  /// The stream controller for sync events.
  final StreamController<SyncEvent<T>> eventController;

  /// The subject for sync status snapshots.
  final BehaviorSubject<SyncStatusSnapshot> statusSubject;

  /// The subject for sync metadata.
  final BehaviorSubject<SyncMetadata> metadataSubject;

  /// The list of observers.
  final List<SynqObserver<T>> observers;

  /// The list of middlewares.
  final List<SynqMiddleware<T>> middlewares;

  final Map<String, SyncStatusSnapshot> _snapshots = {};

  /// Synchronizes data for a given user.
  Future<SyncResult> synchronize(
    String userId, {
    bool force = false,
    SyncOptions<T>? options,
    SyncScope? scope,
  }) async {
    final snapshot = _getSnapshot(userId);
    if (snapshot.status == SyncStatus.syncing && !force) {
      logger.info('Sync already in progress for user $userId. Skipping.');
      return SyncResult.skipped(userId, snapshot.pendingOperations);
    }

    final stopwatch = Stopwatch()..start();

    // Set status to syncing and reset counters for the new cycle in one step.
    _updateSnapshot(
      userId,
      (s) => s.copyWith(
        status: SyncStatus.syncing,
        syncedCount: 0,
        conflictsResolved: 0,
        failedOperations: 0,
      ),
    );
    _notifyObservers((o) => o.onSyncStart(userId));
    // Yield to the event loop to allow the 'syncing' status to be emitted
    // and observed by listeners before proceeding.
    await Future<void>.delayed(Duration.zero);
    await _notifyMiddlewares((m) => m.beforeSync(userId));

    try {
      final direction = options?.direction ?? config.defaultSyncDirection;

      if (direction == SyncDirection.pushThenPull ||
          direction == SyncDirection.pushOnly) {
        await _pushChanges(userId);
      }

      if (direction == SyncDirection.pushThenPull ||
          direction == SyncDirection.pullOnly) {
        await _pullChanges(userId, options, scope);
      }

      final finalPending = queueManager.getPending(userId);
      final result = SyncResult.fromSnapshot(
        _getSnapshot(userId),
        duration: stopwatch.elapsed,
        pendingOperations: finalPending,
      );

      _updateStatus(userId, SyncStatus.idle, clearErrors: true);
      _notifyObservers((o) => o.onSyncEnd(userId, result));
      await _notifyMiddlewares((m) => m.afterSync(userId, result));
      return result;
    } on Object catch (e, stack) {
      _updateStatus(userId, SyncStatus.failed, error: e);
      logger.error('Synchronization failed for user $userId', stack);
      final result = SyncResult.fromSnapshot(
        _getSnapshot(userId),
        duration: stopwatch.elapsed,
        errors: [e],
      );
      _notifyObservers((o) => o.onSyncEnd(userId, result));
      await _notifyMiddlewares((m) => m.afterSync(userId, result));
      rethrow;
    } finally {
      stopwatch.stop();
      // The status is already set to idle/failed in the try/catch blocks.
    }
  }

  /// Cancels an ongoing synchronization.
  void cancel(String userId) {
    _updateStatus(userId, SyncStatus.cancelled);
  }

  /// Pauses an ongoing synchronization.
  Future<void> pause(String userId) async {
    _updateStatus(userId, SyncStatus.paused);
  }

  /// Resumes a paused synchronization.
  void resume(String userId) {
    _updateStatus(userId, SyncStatus.syncing);
  }

  /// Gets the current sync status snapshot for a user.
  SyncStatusSnapshot getSnapshot(String userId) => _getSnapshot(userId);

  /// Ensures a user has an initial status snapshot.
  ///
  /// If the user has no existing snapshot, an initial 'idle' one is created
  /// and emitted.
  void initializeUser(String userId) {
    if (!_snapshots.containsKey(userId)) {
      _updateSnapshot(userId, (s) => s); // This will create and emit initial
    }
  }

  Future<void> _pushChanges(String userId) async {
    // Create a copy of the pending list to iterate over. This prevents
    // concurrent modification issues if the queue is updated during the loop
    // (e.g., by the retry logic).
    final operationsToProcess = List<SyncOperation<T>>.from(
      queueManager.getPending(userId),
    );
    if (operationsToProcess.isEmpty) {
      logger.info('No pending changes to push for user $userId.');
      return;
    }

    logger.info(
      'Pushing ${operationsToProcess.length} changes for user $userId...',
    );

    // Track processed operation IDs to avoid double-processing
    final processedIds = <String>{};

    for (final operation in operationsToProcess) {
      if (_getSnapshot(userId).status != SyncStatus.syncing) break;

      // Skip if already processed in this sync cycle
      if (processedIds.contains(operation.id)) {
        logger.debug('Operation ${operation.id} already processed, skipping.');
        continue;
      }

      await _processPendingOperation(operation);
      processedIds.add(operation.id);
    }
  }

  Future<void> _processPendingOperation(SyncOperation<T> operation) async {
    logger.info(
      'SYNC: Processing operation ${operation.id} for entity ${operation.entityId}. '
      'Current retryCount: ${operation.retryCount}',
    );
    _notifyObservers((o) => o.onOperationStart(operation));
    await _notifyMiddlewares((m) => m.beforeOperation(operation));

    try {
      T? remoteResult;
      final prepared = operation.data; // Already transformed on save

      switch (operation.type) {
        case SyncOperationType.create:
          if (prepared == null) throw ArgumentError('Create op needs data');
          remoteResult = await remoteAdapter.push(prepared, operation.userId);
        case SyncOperationType.update:
          if (prepared == null) throw ArgumentError('Update op needs data');
          // Use delta if available for a partial update
          if (operation.delta != null && operation.delta!.isNotEmpty) {
            remoteResult = await remoteAdapter.patch(
              operation.entityId,
              operation.userId,
              operation.delta!,
            );
          } else {
            remoteResult = await remoteAdapter.push(prepared, operation.userId);
          }
        case SyncOperationType.delete:
          await remoteAdapter.deleteRemote(
            operation.entityId,
            operation.userId,
          );
      }

      await queueManager.dequeue(operation.id);
      _updateSnapshot(
        operation.userId,
        (s) => s.copyWith(syncedCount: s.syncedCount + 1),
      );
      _notifyObservers((o) => o.onOperationSuccess(operation, remoteResult));
      await _notifyMiddlewares(
        (m) => m.afterOperation(operation, remoteResult),
      );
    } on Object catch (e, stack) {
      logger.error('SYNC: Operation $operation failed', stack);
      if (e is! NetworkException || operation.retryCount >= config.maxRetries) {
        _updateSnapshot(
          operation.userId,
          (s) => s.copyWith(failedOperations: s.failedOperations + 1),
        );
        _notifyObservers((o) => o.onOperationFailure(operation, e, stack));
        final synqError = e is SynqException
            ? e
            : AdapterException(
                remoteAdapter.name,
                'Unknown error during operation: $e',
              );
        await _notifyMiddlewares(
          (m) => m.onOperationError(operation, synqError),
        );
        // Optionally dequeue permanently failed operations
        // await queueManager.dequeue(operation.id);
      } else {
        // It's a retryable network error, increment retry count ONCE
        final updatedOp =
            operation.copyWith(retryCount: operation.retryCount + 1);
        await queueManager.update(updatedOp);
        logger.warn(
          'SYNC: Operation ${operation.id} failed with network error. '
          'Incrementing retry count from ${operation.retryCount} to ${updatedOp.retryCount}. '
          'Will retry on next sync.',
        );
      }
    }
  }

  Future<void> _pullChanges(
    String userId,
    SyncOptions<T>? options,
    SyncScope? scope,
  ) async {
    logger.info('Pulling remote changes for user $userId...');

    // Helper to update metadata at the end of the pull process.
    Future<void> updateMetadata() async {
      final items = await localAdapter.getAll(userId: userId);
      // Create a stable hash of the data content.
      final contentToHash = items.map((e) => e.toMap().toString()).join(',');
      final dataHash = contentToHash.isNotEmpty
          ? sha1.convert(contentToHash.codeUnits).toString()
          : '';

      final newMetadata = SyncMetadata(
        userId: userId,
        lastSyncTime: DateTime.now(),
        itemCount: items.length,
        dataHash: dataHash,
      );
      await localAdapter.updateSyncMetadata(newMetadata, userId);
      await remoteAdapter.updateSyncMetadata(newMetadata, userId);
      metadataSubject.add(newMetadata);
    }

    final remoteItems = await remoteAdapter.fetchAll(userId, scope: scope);
    final localItemsMap = await localAdapter.getByIds(
      remoteItems.map((e) => e.id).toList(),
      userId,
    );

    for (final remoteItem in remoteItems) {
      // If the sync is cancelled during the loop, break out.
      if (_getSnapshot(userId).status != SyncStatus.syncing) break;
      final localItem = localItemsMap[remoteItem.id];
      final context = conflictDetector.detect(
        localItem: localItem,
        remoteItem: remoteItem,
        userId: userId,
      );

      if (context == null) {
        // No conflict, just save the remote item
        await localAdapter.push(remoteItem, userId);
        continue;
      }

      _notifyObservers(
        (o) => o.onConflictDetected(context, localItem, remoteItem),
      );
      await _notifyMiddlewares(
        (m) => m.onConflict(context, localItem, remoteItem),
      );

      final resolver = options?.conflictResolver ??
          config.defaultConflictResolver ??
          conflictResolver;
      final resolution = await resolver.resolve(
        localItem: localItem,
        remoteItem: remoteItem,
        context: context,
      );

      _notifyObservers((o) => o.onConflictResolved(context, resolution));

      switch (resolution.strategy) {
        case ResolutionStrategy.useLocal:
          // Do nothing, keep local version
          break;
        case ResolutionStrategy.useRemote:
          await localAdapter.push(remoteItem, userId);
        case ResolutionStrategy.merge:
          if (resolution.resolvedData == null) {
            throw StateError('Merge resolution must provide a merged item.');
          }
          await localAdapter.push(resolution.resolvedData!, userId);
        case ResolutionStrategy.abort:
          logger.warn('Conflict resolution aborted for ${context.entityId}');
        case ResolutionStrategy.askUser:
          // This case should be handled by the resolver, not the engine.
          logger.warn(
            'Conflict resolution requires user input for ${context.entityId}',
          );
      }
      _updateSnapshot(
        userId,
        (s) => s.copyWith(conflictsResolved: s.conflictsResolved + 1),
      );
    }

    // Always update metadata after a pull, even if there were no items.
    await updateMetadata();
  }

  SyncStatusSnapshot _getSnapshot(String userId) {
    return _snapshots[userId] ?? SyncStatusSnapshot.initial(userId);
  }

  void _updateStatus(
    String userId,
    SyncStatus status, {
    Object? error,
    bool clearErrors = false,
  }) {
    _updateSnapshot(userId, (s) {
      final newErrors = List<Object>.from(s.errors);
      if (clearErrors) {
        newErrors.clear();
      }
      if (error != null) {
        newErrors.add(error);
      }
      return s.copyWith(status: status, errors: newErrors);
    });
  }

  void _updateSnapshot(
    String userId,
    SyncStatusSnapshot Function(SyncStatusSnapshot) updater,
  ) {
    final current = _getSnapshot(userId);
    final updated = updater(current);
    _snapshots[userId] = updated;
    statusSubject.add(updated);
  }

  void _notifyObservers(void Function(SynqObserver<T> observer) action) {
    for (final observer in observers) {
      try {
        action(observer);
      } on Object catch (e, stack) {
        logger.error('Observer ${observer.runtimeType} threw an error', stack);
      }
    }
  }

  Future<void> _notifyMiddlewares(
    Future<void> Function(SynqMiddleware<T> middleware) action,
  ) async {
    for (final middleware in middlewares) {
      try {
        await action(middleware);
      } on Object catch (e, stack) {
        logger.error(
          'Middleware ${middleware.runtimeType} threw an error',
          stack,
        );
      }
    }
  }
}
