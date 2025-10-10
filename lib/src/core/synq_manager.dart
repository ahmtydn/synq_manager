import 'dart:async';

import 'package:rxdart/rxdart.dart';
import 'package:synq_manager/src/adapters/local_adapter.dart';
import 'package:synq_manager/src/adapters/remote_adapter.dart';
import 'package:synq_manager/src/config/synq_config.dart';
import 'package:synq_manager/src/core/conflict_detector.dart';
import 'package:synq_manager/src/core/queue_manager.dart';
import 'package:synq_manager/src/core/sync_engine.dart';
import 'package:synq_manager/src/events/conflict_event.dart';
import 'package:synq_manager/src/events/data_change_event.dart';
import 'package:synq_manager/src/events/initial_sync_event.dart';
import 'package:synq_manager/src/events/sync_event.dart';
import 'package:synq_manager/src/events/user_switch_event.dart';
import 'package:synq_manager/src/metrics/synq_metrics.dart';
import 'package:synq_manager/src/middleware/synq_middleware.dart';
import 'package:synq_manager/src/models/sync_operation.dart';
import 'package:synq_manager/src/models/sync_result.dart';
import 'package:synq_manager/src/models/syncable_entity.dart';
import 'package:synq_manager/src/models/user_switch_result.dart';
import 'package:synq_manager/src/resolvers/last_write_wins_resolver.dart';
import 'package:synq_manager/src/resolvers/sync_conflict_resolver.dart';
import 'package:synq_manager/src/utils/connectivity_checker.dart';
import 'package:synq_manager/src/utils/logger.dart';
import 'package:uuid/uuid.dart';

/// Main entry point for managing synchronization
/// between local and remote data.
class SynqManager<T extends SyncableEntity> {
  /// Creates a SynqManager instance.
  SynqManager({
    required this.localAdapter,
    required this.remoteAdapter,
    SyncConflictResolver<T>? conflictResolver,
    SynqConfig? synqConfig,
    ConnectivityChecker? connectivity,
    SynqLogger? initialLogger,
  })  : conflictResolver = conflictResolver ?? LastWriteWinsResolver<T>(),
        config = synqConfig ?? SynqConfig.defaultConfig(),
        connectivityChecker = connectivity ?? ConnectivityChecker(),
        logger = initialLogger ??
            SynqLogger(
              enabled: (synqConfig ?? SynqConfig.defaultConfig()).enableLogging,
            ),
        _eventController = StreamController<SyncEvent<T>>.broadcast(),
        _statusSubject = BehaviorSubject<SyncStatusSnapshot>(),
        _metrics = SynqMetrics();

  /// Local data adapter.
  final LocalAdapter<T> localAdapter;

  /// Remote data adapter.
  final RemoteAdapter<T> remoteAdapter;

  /// Conflict resolution strategy.
  final SyncConflictResolver<T> conflictResolver;

  /// Configuration settings.
  final SynqConfig config;

  /// Connectivity checker.
  final ConnectivityChecker connectivityChecker;

  /// Logger instance.
  final SynqLogger logger;

  final StreamController<SyncEvent<T>> _eventController;
  final BehaviorSubject<SyncStatusSnapshot> _statusSubject;
  final List<SynqMiddleware<T>> _middlewares = [];
  final Map<String, Timer> _autoSyncTimers = {};
  final SynqMetrics _metrics;
  late final QueueManager<T> _queueManager;
  late final ConflictDetector<T> _conflictDetector;
  SyncEngine<T>? _syncEngine;
  SyncStatistics _statistics = const SyncStatistics();

  bool _initialized = false;

  /// Stream of all sync events.
  Stream<SyncEvent<T>> get eventStream => _eventController.stream;

  /// Stream of data change events.
  Stream<DataChangeEvent<T>> get onDataChange => eventStream
      .where((event) => event is DataChangeEvent<T>)
      .cast<DataChangeEvent<T>>();

  /// Stream of initialization payloads that emits initial data automatically.
  ///
  /// This stream automatically fetches all existing entities from local storage
  /// and emits an [InitialSyncEvent] when you first subscribe to it. This is
  /// useful for initializing your UI state when the application starts.
  ///
  /// **Behavior:**
  /// - On first subscription, automatically fetches all local data
  /// - Emits an [InitialSyncEvent] containing all locally stored entities
  /// - If no data exists, emits an event with an empty list
  /// - The userId in the event is taken from the first entity if available,
  ///   otherwise an empty string
  ///
  /// **Important:** Ensure [initialize] is called before subscribing to this
  /// stream, otherwise a [StateError] will be thrown.
  ///
  /// **Usage:**
  /// ```dart
  /// await synqManager.initialize();
  ///
  /// // Simply subscribe - initial data loads automatically!
  /// synqManager.onInit.listen((event) {
  ///   print('Initial data loaded: ${event.data.length} items');
  ///   print('User ID: ${event.userId}');
  ///   // Update your UI with initial data
  /// });
  /// ```
  ///
  /// See also:
  /// - [InitialSyncEvent] for the event structure
  /// - [onDataChange] for subsequent data changes
  Stream<InitialSyncEvent<T>> get onInit {
    _ensureInitialized();
    return eventStream
        .where((event) => event is InitialSyncEvent<T>)
        .cast<InitialSyncEvent<T>>()
        .doOnListen(() async {
      _ensureInitialized();
      try {
        final initialData = await getAll();
        _eventController.add(
          InitialSyncEvent<T>(
            userId: initialData.isNotEmpty ? initialData.first.userId : '',
            data: initialData,
          ),
        );
      } on Object catch (e, stack) {
        _eventController.add(
          SyncErrorEvent<T>(
            userId: '',
            error: 'Failed to fetch initial data: $e',
            stackTrace: stack,
          ),
        );
      }
    });
  }

  /// Stream of sync started events.
  Stream<SyncStartedEvent<T>> get onSyncStarted => eventStream
      .where((event) => event is SyncStartedEvent<T>)
      .cast<SyncStartedEvent<T>>();

  /// Stream of sync progress events.
  Stream<SyncProgressEvent<T>> get onSyncProgress => eventStream
      .where((event) => event is SyncProgressEvent<T>)
      .cast<SyncProgressEvent<T>>();

  /// Stream of sync completed events.
  Stream<SyncCompletedEvent<T>> get onSyncCompleted => eventStream
      .where((event) => event is SyncCompletedEvent<T>)
      .cast<SyncCompletedEvent<T>>();

  /// Stream of conflict detected events.
  Stream<ConflictDetectedEvent<T>> get onConflict => eventStream
      .where((event) => event is ConflictDetectedEvent<T>)
      .cast<ConflictDetectedEvent<T>>();

  /// Stream of user switched events.
  Stream<UserSwitchedEvent<T>> get onUserSwitched => eventStream
      .where((event) => event is UserSwitchedEvent<T>)
      .cast<UserSwitchedEvent<T>>();

  /// Stream of sync error events.
  Stream<SyncErrorEvent<T>> get onError => eventStream
      .where((event) => event is SyncErrorEvent<T>)
      .cast<SyncErrorEvent<T>>();

  /// Stream of sync status snapshots.
  Stream<SyncStatusSnapshot> get syncStatusStream => _statusSubject.stream;

  /// Adds a middleware to the processing pipeline.
  void addMiddleware(SynqMiddleware<T> middleware) =>
      _middlewares.add(middleware);

  /// Initializes the sync manager.
  Future<void> initialize() async {
    if (_initialized) return;
    await localAdapter.initialize();
    _conflictDetector = ConflictDetector<T>();
    _queueManager = QueueManager<T>(localAdapter: localAdapter, logger: logger);
    _syncEngine = SyncEngine<T>(
      localAdapter: localAdapter,
      remoteAdapter: remoteAdapter,
      conflictResolver: conflictResolver,
      queueManager: _queueManager,
      conflictDetector: _conflictDetector,
      logger: logger,
      config: config,
      connectivityChecker: connectivityChecker,
      eventController: _eventController,
      statusSubject: _statusSubject,
      middlewares: _middlewares,
    );
    _initialized = true;
  }

  /// Retrieves all entities for a specific user from local storage.
  ///
  /// Returns a list of entities after applying post-fetch transformations.
  Future<List<T>> getAll({String? userId}) async {
    _ensureInitialized();
    final items = await localAdapter.getAll(userId: userId);
    return Future.wait(items.map(_transformAfterFetch));
  }

  /// Retrieves a single entity by ID for a specific user.
  ///
  /// Returns the entity if found, or null otherwise.
  /// Applies post-fetch transformations.
  Future<T?> getById(String id, String userId) async {
    _ensureInitialized();
    final item = await localAdapter.getById(id, userId);
    if (item == null) return null;
    return _transformAfterFetch(item);
  }

  /// Saves an entity to local storage and queues it for synchronization.
  ///
  /// Creates a new entity if it doesn't exist, or updates an existing one.
  /// Applies pre-save transformations and triggers a data change event.
  Future<T> save(T item, String userId) async {
    _ensureInitialized();
    await _queueManager.initializeUser(userId);
    final existing = await localAdapter.getById(item.id, userId);
    final transformed = await _transformBeforeSave(item);
    await localAdapter.save(transformed, userId);

    final operation = SyncOperation<T>(
      id: const Uuid().v4(),
      userId: userId,
      type: existing == null
          ? SyncOperationType.create
          : SyncOperationType.update,
      data: transformed,
      entityId: transformed.id,
      timestamp: DateTime.now(),
    );
    await _queueManager.enqueue(userId, operation);

    _eventController.add(
      DataChangeEvent<T>(
        userId: userId,
        data: transformed,
        changeType: existing == null ? ChangeType.created : ChangeType.updated,
        source: DataSource.local,
      ),
    );
    return transformed;
  }

  /// Deletes an entity from local storage and
  /// queues the deletion for synchronization.
  ///
  /// If the entity doesn't exist locally, the operation is skipped.
  /// Triggers a data change event for the deletion.
  Future<void> delete(String id, String userId) async {
    _ensureInitialized();
    await _queueManager.initializeUser(userId);
    final existing = await localAdapter.getById(id, userId);
    if (existing == null) return;
    await localAdapter.delete(id, userId);

    final operation = SyncOperation<T>(
      id: const Uuid().v4(),
      userId: userId,
      type: SyncOperationType.delete,
      entityId: id,
      timestamp: DateTime.now(),
    );
    await _queueManager.enqueue(userId, operation);

    _eventController.add(
      DataChangeEvent<T>(
        userId: userId,
        data: existing,
        changeType: ChangeType.deleted,
        source: DataSource.local,
      ),
    );
  }

  /// Initiates a synchronization process for a specific user.
  ///
  /// Syncs local changes to the remote source and pulls remote changes.
  /// Can be forced to run even if conditions are not met. Updates metrics.
  Future<SyncResult> sync(
    String userId, {
    bool force = false,
    SyncOptions? options,
  }) async {
    _ensureInitialized();
    await _queueManager.initializeUser(userId);
    final engine = _syncEngine!;
    final result =
        await engine.synchronize(userId, force: force, options: options);
    _updateStatistics(result);
    _metrics.totalSyncOperations += 1;
    _metrics.successfulSyncs += result.failedCount == 0 ? 1 : 0;
    _metrics.failedSyncs += result.failedCount > 0 ? 1 : 0;
    _metrics.conflictsDetected += result.conflictsResolved;
    _metrics.activeUsers.add(userId);
    return result;
  }

  /// Cancels an ongoing synchronization process for a specific user.
  Future<void> cancelSync(String userId) async {
    _ensureInitialized();
    _syncEngine?.cancel(userId);
  }

  /// Pauses an ongoing synchronization process for a specific user.
  Future<void> pauseSync(String userId) async {
    _ensureInitialized();
    await _syncEngine?.pause(userId);
  }

  /// Resumes a paused synchronization process for a specific user.
  Future<void> resumeSync(String userId) async {
    _ensureInitialized();
    _syncEngine?.resume(userId);
  }

  /// Retrieves the current synchronization status snapshot for a user.
  Future<SyncStatusSnapshot> getSyncSnapshot(String userId) async {
    _ensureInitialized();
    return _syncEngine!.getSnapshot(userId);
  }

  /// Retrieves synchronization statistics for a specific user.
  Future<SyncStatistics> getSyncStatistics(String userId) async {
    _ensureInitialized();
    return _statistics;
  }

  /// Switches the active user, optionally handling unsynced data.
  ///
  /// Supports different strategies: sync before switch,
  /// discard changes, or queue changes.
  /// Returns the result of the user switch operation including any errors.
  Future<UserSwitchResult> switchUser({
    required String? oldUserId,
    required String newUserId,
    UserSwitchStrategy? strategy,
  }) async {
    _ensureInitialized();
    final resolvedStrategy = strategy ?? config.defaultUserSwitchStrategy;
    final hadUnsynced =
        oldUserId != null && _queueManager.getPending(oldUserId).isNotEmpty;

    try {
      switch (resolvedStrategy) {
        case UserSwitchStrategy.syncThenSwitch:
          if (oldUserId != null) {
            await sync(oldUserId, force: true);
          }
        case UserSwitchStrategy.clearAndFetch:
          await localAdapter.clearUserData(newUserId);
        case UserSwitchStrategy.promptIfUnsyncedData:
          if (hadUnsynced) {
            return UserSwitchResult.failure(
              previousUserId: oldUserId,
              newUserId: newUserId,
              errorMessage: 'Unsynced data present for '
                  '$oldUserId. Resolve before switching or '
                  'choose a different strategy.',
            );
          }
        case UserSwitchStrategy.keepLocal:
          break;
      }

      await _queueManager.initializeUser(newUserId);
      _eventController.add(
        UserSwitchedEvent<T>(
          previousUserId: oldUserId,
          newUserId: newUserId,
          hadUnsyncedData: hadUnsynced,
        ),
      );
      _metrics.userSwitchCount += 1;
      return UserSwitchResult.success(
        previousUserId: oldUserId,
        newUserId: newUserId,
        unsyncedOperationsHandled: hadUnsynced ? 1 : 0,
      );
    } on Object catch (e) {
      return UserSwitchResult.failure(
        previousUserId: oldUserId,
        newUserId: newUserId,
        errorMessage: e.toString(),
      );
    }
  }

  /// Starts automatic periodic synchronization for a user.
  ///
  /// Syncs at the specified interval or uses the default from config.
  /// Stops any existing auto-sync for the same user first.
  void startAutoSync(String userId, {Duration? interval}) {
    _ensureInitialized();
    stopAutoSync(userId: userId);
    final syncInterval = interval ?? config.autoSyncInterval;
    _autoSyncTimers[userId] = Timer.periodic(syncInterval, (_) {
      unawaited(sync(userId));
    });
  }

  /// Stops automatic synchronization for one or all users.
  ///
  /// If a userId is provided, stops auto-sync for that user only.
  /// Otherwise, stops all active auto-syncs.
  void stopAutoSync({String? userId}) {
    if (userId != null) {
      _autoSyncTimers.remove(userId)?.cancel();
      return;
    }
    for (final timer in _autoSyncTimers.values) {
      timer.cancel();
    }
    _autoSyncTimers.clear();
  }

  /// Gets the current synchronization status for a user.
  Future<SyncStatus> getSyncStatus(String userId) async {
    final snapshot = await getSyncSnapshot(userId);
    return snapshot.status;
  }

  /// Returns the number of pending operations for a user.
  Future<int> getPendingCount(String userId) async {
    _ensureInitialized();
    await _queueManager.initializeUser(userId);
    return _queueManager.getPending(userId).length;
  }

  /// Retries all failed sync operations for a user by forcing a new sync.
  Future<void> retryFailedOperations(String userId) async {
    _ensureInitialized();
    await sync(userId, force: true);
  }

  /// Clears failed operations from the queue (not yet implemented).
  Future<void> clearFailedOperations(String userId) async {
    _ensureInitialized();
    // For now failed operations remain in queue; we simply log.
    logger.warn('clearFailedOperations is not yet implemented.');
  }

  /// Disposes of all resources and closes streams.
  ///
  /// Should be called when the sync manager is no longer needed.
  Future<void> dispose() async {
    stopAutoSync();
    await _eventController.close();
    await _statusSubject.close();
    await _queueManager.dispose();
    await localAdapter.dispose();
  }

  Future<T> _transformBeforeSave(T item) async {
    var transformed = item;
    for (final middleware in _middlewares) {
      transformed = await middleware.transformBeforeSave(transformed);
    }
    return transformed;
  }

  Future<T> _transformAfterFetch(T item) async {
    var transformed = item;
    for (final middleware in _middlewares) {
      transformed = await middleware.transformAfterFetch(transformed);
    }
    return transformed;
  }

  void _updateStatistics(SyncResult result) {
    final totalSyncs = _statistics.totalSyncs + 1;
    final totalDuration = _statistics.totalSyncDuration + result.duration;
    final avgDuration = totalSyncs == 0
        ? Duration.zero
        : Duration(milliseconds: totalDuration.inMilliseconds ~/ totalSyncs);
    _statistics = _statistics.copyWith(
      totalSyncs: totalSyncs,
      successfulSyncs:
          _statistics.successfulSyncs + (result.failedCount == 0 ? 1 : 0),
      failedSyncs: _statistics.failedSyncs + (result.failedCount > 0 ? 1 : 0),
      conflictsDetected:
          _statistics.conflictsDetected + result.conflictsResolved,
      conflictsAutoResolved:
          _statistics.conflictsAutoResolved + result.conflictsResolved,
      averageDuration: avgDuration,
      totalSyncDuration: totalDuration,
    );
  }

  void _ensureInitialized() {
    if (!_initialized || _syncEngine == null) {
      throw StateError('SynqManager.initialize() must be called before use.');
    }
  }
}
