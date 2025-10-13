import 'dart:async';

import 'package:crypto/crypto.dart';
import 'package:synchronized/synchronized.dart';
import 'package:synq_manager/src/core/isolate_helper.dart';
import 'package:synq_manager/src/core/migration_executor.dart';
import 'package:synq_manager/synq_manager.dart';
import 'package:uuid/uuid.dart';

/// Orchestrates bidirectional synchronization between local
/// and remote data stores.
///
/// This manager handles conflict resolution, queuing, user switching, and
/// lifecycle management for synchronized entities. It provides a reactive
/// interface through event streams and supports middleware transformations.
///
/// **Lifecycle:**
/// 1. Create instance with required adapters
/// 2. Call [initialize] before any operations
/// 3. Perform sync operations as needed
/// 4. Call [dispose] when finished
///
/// **Thread Safety:** This class is not thread-safe. Ensure all operations
/// occur on the same isolate or use appropriate synchronization.
class SynqManager<T extends SyncableEntity> {
  /// Creates a [SynqManager] with the provided adapters
  /// and optional configurations.
  SynqManager({
    required this.localAdapter,
    required this.remoteAdapter,
    SyncConflictResolver<T>? conflictResolver,
    SynqConfig<T>? synqConfig,
    ConnectivityChecker? connectivity,
    SynqLogger? initialLogger,
  })  : _conflictResolver = conflictResolver ?? LastWriteWinsResolver<T>(),
        _config = synqConfig ?? SynqConfig<T>.defaultConfig(),
        _connectivityChecker = connectivity ?? ConnectivityChecker(),
        _logger = initialLogger ??
            SynqLogger(
              enabled: (synqConfig ?? SynqConfig.defaultConfig()).enableLogging,
            ) {
    _initializeInternalComponents();
  }

  // Core dependencies - immutable after construction
  /// Adapter for local data storage operations.
  final LocalAdapter<T> localAdapter;

  /// Adapter for remote data source operations.
  final RemoteAdapter<T> remoteAdapter;
  final SyncConflictResolver<T> _conflictResolver;
  final SynqConfig<T> _config;
  final ConnectivityChecker _connectivityChecker;
  final SynqLogger _logger;

  // Internal state management
  final StreamController<SyncEvent<T>> _eventController =
      StreamController<SyncEvent<T>>.broadcast();
  final BehaviorSubject<SyncStatusSnapshot> _statusSubject =
      BehaviorSubject.seeded(
    SyncStatusSnapshot.initial(_uninitializedUserId),
  );
  final BehaviorSubject<SyncMetadata> _metadataSubject =
      BehaviorSubject<SyncMetadata>();

  // A unique, private constant to seed the status subject.
  static const String _uninitializedUserId = '__uninitialized__';
  final List<SynqMiddleware<T>> _middlewares = [];
  final List<SynqObserver<T>> _observers = [];
  final Map<String, Timer> _autoSyncTimers = {};
  final _metrics = SynqMetrics();
  final _externalChangeLock = Lock();
  final Map<String, String> _processedChangeKeys = {};

  late final QueueManager<T> _queueManager;
  late final IsolateHelper _isolateHelper;
  late final ConflictDetector<T> _conflictDetector;
  final BehaviorSubject<SyncStatistics> _statisticsSubject =
      BehaviorSubject<SyncStatistics>.seeded(const SyncStatistics());

  SyncEngine<T>? _syncEngine;
  bool _initialized = false;
  bool _disposed = false;

  StreamSubscription<ChangeDetail<T>>? _localChangeSubscription;
  StreamSubscription<ChangeDetail<T>>? _remoteChangeSubscription;

  // Configuration constants
  static const int _maxProcessedChangesCache = 1000;
  static const int _timestampToleranceSeconds = 1;

  /// Public event streams - filtered views of the main event stream
  Stream<SyncEvent<T>> get eventStream => _eventController.stream;

  /// Emits when local data changes (create, update, delete).
  Stream<DataChangeEvent<T>> get onDataChange =>
      eventStream.whereType<DataChangeEvent<T>>();

  /// Emits initial data automatically upon first subscription.
  ///
  /// **Critical:** Must call [initialize] before subscribing.
  /// Automatically fetches all local entities
  /// and emits them as an [InitialSyncEvent].
  /// If an error occurs during fetch, emits a [SyncErrorEvent] instead.
  Stream<InitialSyncEvent<T>> get onInit {
    _ensureInitialized();
    return eventStream
        .whereType<InitialSyncEvent<T>>()
        .doOnListen(_emitInitialData);
  }

  /// Stream of sync started events.
  Stream<SyncStartedEvent<T>> get onSyncStarted =>
      eventStream.whereType<SyncStartedEvent<T>>();

  /// Stream of sync progress events.
  Stream<SyncProgressEvent<T>> get onSyncProgress =>
      eventStream.whereType<SyncProgressEvent<T>>();

  /// Stream of sync completed events.
  Stream<SyncCompletedEvent<T>> get onSyncCompleted =>
      eventStream.whereType<SyncCompletedEvent<T>>();

  /// Stream of conflict detected events.
  Stream<ConflictDetectedEvent<T>> get onConflict =>
      eventStream.whereType<ConflictDetectedEvent<T>>();

  /// Stream of user switched events.
  Stream<UserSwitchedEvent<T>> get onUserSwitched =>
      eventStream.whereType<UserSwitchedEvent<T>>();

  /// Stream of sync error events.
  Stream<SyncErrorEvent<T>> get onError =>
      eventStream.whereType<SyncErrorEvent<T>>();

  /// Stream of sync metadata updates. Emits the latest metadata after each
  /// successful sync cycle for a given user.
  Stream<SyncMetadata> onMetadataChange(String userId) =>
      _metadataSubject.stream.where((meta) => meta.userId == userId);

  /// Returns a stream of sync status snapshots for the specified user.
  ///
  /// The stream emits a new snapshot whenever the sync status changes.
  Stream<SyncStatusSnapshot> watchSyncStatus(String userId) {
    _ensureInitializedAndNotDisposed();
    unawaited(_ensureUserInitialized(userId));
    return _statusSubject.stream.where((snapshot) => snapshot.userId == userId);
  }

  /// Returns a stream of cumulative synchronization statistics.
  Stream<SyncStatistics> watchSyncStatistics() {
    return _statisticsSubject.stream;
  }

  /// Registers a middleware for data transformation pipeline.
  ///
  /// Middlewares are executed in registration order for both
  /// pre-save and post-fetch operations.
  void addMiddleware(SynqMiddleware<T> middleware) {
    if (_disposed) {
      throw StateError('Cannot add middleware after disposal');
    }
    _middlewares.add(middleware);
    _logger.debug('Middleware added: ${middleware.runtimeType}');
  }

  /// Registers an observer to be notified of manager operations.
  ///
  /// Observers are notified in the order they are added.
  void addObserver(SynqObserver<T> observer) {
    if (_disposed) {
      throw StateError('Cannot add observer after disposal');
    }
    _observers.add(observer);
    _logger.debug('Observer added: ${observer.runtimeType}');
  }

  /// Initializes all internal components and establishes change subscriptions.
  ///
  /// **Idempotent:** Safe to call multiple times (no-op after first call).
  /// **Must be called** before any data operations.
  ///
  /// Throws [StateError] if called after [dispose].
  Future<void> initialize() async {
    if (_disposed) {
      throw StateError('Cannot initialize after disposal');
    }

    if (_initialized) {
      _logger.debug('Already initialized, skipping');
      return;
    }

    try {
      await _initializeAdapters();
      await _isolateHelper.initialize();
      await _runSchemaMigrations();
      _initializeSyncComponents();
      _initialized = true;
      await _setupAutoSyncIfEnabled();
      await _subscribeToChangeStreams();
      _logger.info('SynqManager initialized successfully.');
    } on Object catch (e, stack) {
      _logger.error('Initialization failed', stack);
      _emitError('', 'Initialization failed: $e', stack);
      rethrow;
    }
  }

  /// Retrieves all entities for the specified user from local storage.
  ///
  /// Applies all registered middleware transformations post-fetch.
  /// Returns empty list if no data exists.
  Future<List<T>> getAll({String? userId}) async {
    _ensureInitializedAndNotDisposed();

    try {
      final items = await localAdapter.getAll(userId: userId);
      return Future.wait(items.map(_applyPostFetchTransformations));
    } on Object catch (e, stack) {
      _logger.error('Failed to get all items for user: $userId', stack);
      rethrow;
    }
  }

  /// Retrieves a single entity by ID for the specified user.
  ///
  /// Returns null if entity doesn't exist or has been deleted.
  /// Applies all registered middleware transformations post-fetch.
  Future<T?> getById(String id, String userId) async {
    _ensureInitializedAndNotDisposed();

    if (id.isEmpty) {
      throw ArgumentError.value(id, 'id', 'Must not be empty');
    }

    try {
      final item = await localAdapter.getById(id, userId);
      if (item == null) return null;

      return _applyPostFetchTransformations(item);
    } on Object catch (e, stack) {
      _logger.error('Failed to get item by ID: $id for user: $userId', stack);
      rethrow;
    }
  }

  /// Returns a stream of all entities for the specified user.
  ///
  /// The stream emits a new list of entities whenever the underlying data changes.
  /// Returns an empty stream if the adapter does not support watching.
  Stream<List<T>> watchAll({String? userId}) {
    _ensureInitializedAndNotDisposed();
    return localAdapter.watchAll(userId: userId) ?? const Stream.empty();
  }

  /// Returns a stream for a single entity by its ID.
  ///
  /// The stream emits the entity when it changes, or `null` if it's deleted.
  /// Returns an empty stream if the adapter does not support watching.
  Stream<T?> watchById(String id, String userId) {
    _ensureInitializedAndNotDisposed();

    if (id.isEmpty) {
      throw ArgumentError.value(id, 'id', 'Must not be empty');
    }
    if (userId.isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'Must not be empty');
    }
    return localAdapter.watchById(id, userId) ?? const Stream.empty();
  }

  /// Returns a stream of paginated entities for the specified user.
  ///
  /// The stream emits a new paginated result whenever the underlying data changes.
  /// Returns an empty stream if the adapter does not support watching.
  Stream<PaginatedResult<T>> watchAllPaginated(
    PaginationConfig config, {
    String? userId,
  }) {
    _ensureInitializedAndNotDisposed();
    return localAdapter.watchAllPaginated(config, userId: userId) ??
        const Stream.empty();
  }

  /// Returns a stream of entities matching the given query.
  ///
  /// The stream emits a new list of entities whenever the underlying data changes.
  /// Returns an empty stream if the adapter does not support watching.
  Stream<List<T>> watchQuery(SynqQuery query, {String? userId}) {
    _ensureInitializedAndNotDisposed();
    return localAdapter.watchQuery(query, userId: userId) ??
        const Stream.empty();
  }

  /// Returns a stream that emits the total number of entities, optionally
  /// matching a query.
  ///
  /// This is more efficient than `watchAll().map((list) => list.length)`
  /// as it avoids fetching and transforming the full list of entities.
  /// Returns a stream of `0` if the adapter does not support this feature.
  Stream<int> watchCount({SynqQuery? query, String? userId}) {
    _ensureInitializedAndNotDisposed();
    return localAdapter.watchCount(query: query, userId: userId) ??
        Stream.value(0);
  }

  /// Returns a stream that emits the first entity matching a query,
  /// optionally sorted by the adapter's implementation.
  ///
  /// Emits `null` if no matching entities are found.
  /// Returns a stream of `null` if the adapter does not support this feature.
  Stream<T?> watchFirst({SynqQuery? query, String? userId}) {
    _ensureInitializedAndNotDisposed();
    return localAdapter.watchFirst(query: query, userId: userId) ??
        Stream.value(null);
  }

  /// Returns a stream that emits `true` if at least one entity exists
  /// matching the query, and `false` otherwise.
  ///
  /// This is a convenience method built on top of [watchCount] and is highly
  /// efficient for checking for the presence of data.
  Stream<bool> watchExists({SynqQuery? query, String? userId}) {
    _ensureInitializedAndNotDisposed();
    return watchCount(query: query, userId: userId).map((count) => count > 0);
  }

  /// Persists an entity to local storage and queues it for remote synchronization.
  ///
  /// Creates a new entity if `item.id` doesn't exist, otherwise updates.
  /// Applies all registered middleware transformations pre-save.
  /// Emits [DataChangeEvent] upon successful save.
  ///
  /// The [source] parameter indicates the origin of the change. If the source
  /// is [DataSource.remote], the operation will not be re-queued for remote sync.
  /// The [forceRemoteSync] parameter can be set to `true` to override this
  /// behavior and ensure the operation is queued for remote sync regardless
  /// of the source.
  ///
  /// Returns the transformed entity that was actually saved.
  Future<T> push(
    T item,
    String userId, {
    DataSource source = DataSource.local,
    bool forceRemoteSync = false,
  }) async {
    _ensureInitializedAndNotDisposed();

    if (userId.isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'Must not be empty');
    }

    _logger.info('Pushing entity ${item.id} for user $userId from $source...');

    _notifyObservers((o) => o.onSaveStart(item, userId, DataSource.local));

    try {
      await _ensureUserInitialized(userId);

      final existing = await localAdapter.getById(item.id, userId);
      final isCreate = existing == null;
      _logger.debug(
        'Operation determined as ${isCreate ? 'create' : 'update'} '
        'for entity ${item.id}',
      );

      final transformed = await _applyPreSaveTransformations(item);

      // For updates, calculate the delta (the changed fields)
      Map<String, dynamic>? delta;
      if (!isCreate) {
        delta = transformed.diff(existing);
        if (delta == null) {
          _logger.debug(
            'No changes detected for entity ${item.id}, skipping save.',
          );
          return transformed; // No-op if no fields changed
        }
        _logger.debug(
          'Delta update detected for entity ${item.id}. '
          'Changes: ${delta.keys.join(', ')}',
        );
        _notifyObservers((o) => o.onPartialUpdate(item.id, userId, delta!));
      }

      if (isCreate || delta == null) {
        _logger.debug('Pushing full entity ${item.id} to local adapter');
        await localAdapter.push(transformed, userId);
      } else {
        _logger.debug(
          'Patching entity ${item.id} in local adapter with ${delta.length} changes',
        );
        await localAdapter.patch(transformed.id, userId, delta);
      }

      if (source == DataSource.local || forceRemoteSync) {
        final operation = _createOperation(
          userId: userId,
          type: isCreate ? SyncOperationType.create : SyncOperationType.update,
          entityId: transformed.id,
          data: transformed,
          delta: delta, // Store the delta for the sync engine
        );
        await _queueManager.enqueue(operation);
      }

      _emitDataChangeEvent(
        userId: userId,
        data: transformed,
        changeType: isCreate ? ChangeType.created : ChangeType.updated,
        source: DataSource.local,
      );

      _logger.info('Successfully saved entity ${item.id} for user $userId');
      _notifyObservers(
        (o) => o.onPushEnd(transformed, userId, DataSource.local),
      );
      return transformed;
    } on Object catch (e, stack) {
      _logger.error(
        'Failed to save entity ${item.id} for user: $userId',
        stack,
      );
      rethrow;
    }
  }

  /// Removes an entity from local storage and queues deletion for remote sync.
  ///
  /// No-op if entity doesn't exist locally.
  /// Emits [DataChangeEvent] with deletion type upon successful removal.
  Future<bool> delete(
    String id,
    String userId, {
    DataSource source = DataSource.local,
    bool forceRemoteSync = false,
  }) async {
    _ensureInitializedAndNotDisposed();

    if (id.isEmpty) {
      throw ArgumentError.value(id, 'id', 'Must not be empty');
    }
    if (userId.isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'Must not be empty');
    }

    _logger.info(
      'Deleting entity $id for user $userId from $source...',
    );

    _notifyObservers((o) => o.onDeleteStart(id, userId));

    try {
      await _ensureUserInitialized(userId);

      final existing = await localAdapter.getById(id, userId);
      if (existing == null) {
        _logger.debug(
          'Entity $id does not exist for user $userId, skipping delete',
        );
        return false;
      }

      final deleted = await localAdapter.delete(id, userId);
      if (!deleted) {
        _logger.warn('Local adapter failed to delete entity $id');
        _notifyObservers((o) => o.onDeleteEnd(id, userId, success: false));
        return false;
      }
      _logger.debug('Deleted entity $id from local adapter');

      if (source == DataSource.local || forceRemoteSync) {
        final operation = _createOperation(
          userId: userId,
          type: SyncOperationType.delete,
          entityId: id,
        );

        await _queueManager.enqueue(operation);
      }

      _emitDataChangeEvent(
        userId: userId,
        data: existing,
        changeType: ChangeType.deleted,
        source: DataSource.local,
      );

      _logger.info('Successfully deleted entity $id for user $userId');
      _notifyObservers((o) => o.onDeleteEnd(id, userId, success: true));
      return true;
    } on Object catch (e, stack) {
      _logger.error('Failed to delete entity $id for user: $userId', stack);
      rethrow;
    }
  }

  /// Persists an entity and immediately triggers a synchronization.
  ///
  /// A convenience method that combines [push] and [sync].
  /// Returns the [SyncResult] from the subsequent synchronization.
  Future<SyncResult> pushAndSync(
    T item,
    String userId, {
    DataSource source = DataSource.local,
    bool forceRemoteSync = false,
    SyncOptions<T>? options,
    SyncScope? scope,
  }) async {
    _ensureInitializedAndNotDisposed();
    await push(
      item,
      userId,
      source: source,
      forceRemoteSync: forceRemoteSync,
    );
    return sync(
      userId,
      options: options,
      scope: scope,
    );
  }

  /// Removes an entity and immediately triggers a synchronization.
  ///
  /// A convenience method that combines [delete] and [sync].
  /// Returns the [SyncResult] from the subsequent synchronization.
  Future<SyncResult> deleteAndSync(
    String id,
    String userId, {
    DataSource source = DataSource.local,
    bool forceRemoteSync = false,
    SyncOptions<T>? options,
    SyncScope? scope,
  }) async {
    _ensureInitializedAndNotDisposed();
    await delete(
      id,
      userId,
      source: source,
      forceRemoteSync: forceRemoteSync,
    );
    return sync(
      userId,
      options: options,
      scope: scope,
    );
  }

  /// Executes a full synchronization cycle for the specified user.
  ///
  /// Pushes pending local changes to remote, then pulls remote changes.
  /// Use [force] to bypass typical sync conditions (connectivity, timing).
  /// Updates internal metrics and statistics.
  ///
  /// Returns [SyncResult] containing detailed outcome information.
  Future<SyncResult> sync(
    String userId, {
    bool force = false,
    SyncOptions<T>? options,
    SyncScope? scope,
  }) async {
    _ensureInitializedAndNotDisposed();

    if (userId.isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'Must not be empty');
    }

    try {
      await _ensureUserInitialized(userId);

      final engine = _syncEngine!;
      final result = await engine.synchronize(
        userId,
        force: force,
        options: options,
        scope: scope,
      );

      _updateMetricsAndStatistics(result, userId);

      return result;
    } on Object catch (e, stack) {
      _logger.error('Sync failed for user: $userId', stack);
      _emitError(userId, 'Sync failed: $e', stack);
      rethrow;
    }
  }

  /// Cancels an ongoing synchronization for the specified user.
  Future<void> cancelSync(String userId) async {
    _ensureInitializedAndNotDisposed();
    _syncEngine?.cancel(userId);
    _logger.info('Sync cancelled for user: $userId');
  }

  /// Pauses an ongoing synchronization for the specified user.
  Future<void> pauseSync(String userId) async {
    _ensureInitializedAndNotDisposed();
    await _syncEngine?.pause(userId);
    _logger.info('Sync paused for user: $userId');
  }

  /// Resumes a previously paused synchronization for the specified user.
  Future<void> resumeSync(String userId) async {
    _ensureInitializedAndNotDisposed();
    _syncEngine?.resume(userId);
    _logger.info('Sync resumed for user: $userId');
  }

  /// Retrieves current synchronization status snapshot for the specified user.
  Future<SyncStatusSnapshot> getSyncSnapshot(String userId) async {
    _ensureInitializedAndNotDisposed();
    return _syncEngine!.getSnapshot(userId);
  }

  /// Retrieves cumulative synchronization statistics.
  ///
  /// Note: Currently returns global statistics, not per-user.
  Future<SyncStatistics> getSyncStatistics(String userId) async {
    _ensureInitializedAndNotDisposed();
    return _statisticsSubject.value;
  }

  /// Switches the active user with configurable handling of unsynced data.
  ///
  /// **Strategies:**
  /// - [UserSwitchStrategy.syncThenSwitch]: Sync old user before switching
  /// - [UserSwitchStrategy.clearAndFetch]: Clear new user's local data
  /// - [UserSwitchStrategy.promptIfUnsyncedData]: Fail if old user has
  ///   pending ops
  /// - [UserSwitchStrategy.keepLocal]: Switch without modifications
  ///
  /// Returns [UserSwitchResult] indicating success or failure with details.
  Future<UserSwitchResult> switchUser({
    required String? oldUserId,
    required String newUserId,
    UserSwitchStrategy? strategy,
  }) async {
    _ensureInitializedAndNotDisposed();

    if (newUserId.isEmpty) {
      throw ArgumentError.value(newUserId, 'newUserId', 'Must not be empty');
    }

    if (oldUserId != null && oldUserId.isNotEmpty) {
      await _ensureUserInitialized(oldUserId);
    }

    final resolvedStrategy = strategy ?? _config.defaultUserSwitchStrategy;
    _notifyObservers(
      (o) => o.onUserSwitchStart(
        oldUserId,
        newUserId,
        resolvedStrategy,
      ),
    );
    final hadUnsynced = await _hasUnsyncedData(oldUserId);

    try {
      // Execute the strategy. This will throw on failure for certain strategies.
      await _executeUserSwitchStrategy(
        resolvedStrategy,
        oldUserId,
        newUserId,
        hadUnsynced,
      );

      // If the strategy succeeds, proceed with success-related logic.
      await _ensureUserInitialized(newUserId);

      _emitUserSwitchedEvent(oldUserId, newUserId, hadUnsynced);
      _metrics.userSwitchCount += 1;
      _logger.info('User switched from $oldUserId to $newUserId');

      // Return the success result.
      final result = UserSwitchResult.success(
        previousUserId: oldUserId,
        newUserId: newUserId,
        unsyncedOperationsHandled: hadUnsynced ? 1 : 0,
      );
      _notifyObservers((o) => o.onUserSwitchEnd(result));
      return result;
    } on UserSwitchException catch (e) {
      // Handle specific user switch failures (e.g., promptIfUnsyncedData).
      _logger.warn('User switch rejected: ${e.message}');
      final result = UserSwitchResult.failure(
        previousUserId: oldUserId,
        newUserId: newUserId,
        errorMessage: e.message,
      );
      _notifyObservers((o) => o.onUserSwitchEnd(result));
      return result;
    } on Object catch (e, stack) {
      // Handle any other unexpected errors during the switch.
      _logger.error('User switch failed', stack);
      final result = UserSwitchResult.failure(
        previousUserId: oldUserId,
        newUserId: newUserId,
        errorMessage: 'User switch failed: $e',
      );
      _notifyObservers((o) => o.onUserSwitchEnd(result));
      return result;
    }
  }

  /// Starts automatic periodic synchronization for the specified user.
  ///
  /// Uses [interval] if provided, otherwise uses [SynqConfig.autoSyncInterval].
  /// Automatically stops any existing auto-sync for the same user.
  void startAutoSync(String userId, {Duration? interval}) {
    _ensureInitializedAndNotDisposed();

    if (userId.isEmpty) {
      return;
    }

    stopAutoSync(userId: userId);

    final syncInterval = interval ?? _config.autoSyncInterval;
    _autoSyncTimers[userId] = Timer.periodic(syncInterval, (_) {
      unawaited(
        sync(userId).catchError((Object e, StackTrace stack) {
          _logger.error('Auto-sync failed for user $userId', stack);
          return SyncResult(
            userId: userId,
            syncedCount: 0,
            failedCount: 1,
            conflictsResolved: 0,
            pendingOperations: const [],
            duration: Duration.zero,
            errors: [e],
          );
        }),
      );
    });

    _logger
        .info('Auto-sync started for user $userId (interval: $syncInterval)');
  }

  /// Stops automatic synchronization for one or all users.
  ///
  /// If [userId] is provided, stops only that user's auto-sync.
  /// If [userId] is null, stops all active auto-syncs.
  void stopAutoSync({String? userId}) {
    if (userId != null) {
      final timer = _autoSyncTimers.remove(userId);
      timer?.cancel();
      if (timer != null) {
        _logger.info('Auto-sync stopped for user: $userId');
      }
      return;
    }

    // Stop all auto-syncs
    final count = _autoSyncTimers.length;
    for (final timer in _autoSyncTimers.values) {
      timer.cancel();
    }
    _autoSyncTimers.clear();

    if (count > 0) {
      _logger.info('All auto-syncs stopped ($count users)');
    }
  }

  /// Gets the current synchronization status for the specified user.
  Future<SyncStatus> getSyncStatus(String userId) async {
    final snapshot = await getSyncSnapshot(userId);
    return snapshot.status;
  }

  /// Returns the number of pending synchronization operations for the user.
  Future<int> getPendingCount(String userId) async {
    _ensureInitializedAndNotDisposed();
    await _ensureUserInitialized(userId);
    return _queueManager.getPending(userId).length;
  }

  /// Returns a list of pending synchronization operations for the user.
  /// This is mainly for testing and debugging purposes.
  List<SyncOperation<T>> getPendingOperations(String userId) {
    _ensureInitializedAndNotDisposed();
    // This is a direct, synchronous access to the in-memory queue.
    return _queueManager.getPending(userId);
  }

  /// Retries all failed synchronization operations by forcing a new sync.
  Future<void> retryFailedOperations(String userId) async {
    _ensureInitializedAndNotDisposed();
    _logger.info('Retrying failed operations for user: $userId');
    await sync(userId, force: true);
  }

  /// Releases all resources and closes streams.
  ///
  /// **Must be called** when the manager is no longer needed.
  /// After disposal, the manager cannot be reused.
  Future<void> dispose() async {
    if (_disposed) {
      _logger.debug('Already disposed, skipping');
      return;
    }

    _logger.info('Disposing SynqManager');

    _disposed = true;

    try {
      stopAutoSync();
      await _localChangeSubscription?.cancel();
      await _remoteChangeSubscription?.cancel();
      _processedChangeKeys.clear();
      _observers.clear();
      await _eventController.close();
      await _metadataSubject.close();
      await _statusSubject.close();
      await _statisticsSubject.close();
      await _queueManager.dispose();
      _isolateHelper.dispose();
      await localAdapter.dispose();

      _logger.info('SynqManager disposed successfully.');
    } on Object catch (e, stack) {
      _logger.error('Error during disposal', stack);
      // Don't rethrow - disposal should be best-effort
    }
  }

  // ========== Private Helper Methods ==========

  Future<void> _runSchemaMigrations() async {
    final executor = MigrationExecutor(
      localAdapter: localAdapter,
      migrations: _config.migrations,
      targetVersion: _config.schemaVersion,
      logger: _logger,
      observers: _observers,
    );

    final needsMigration = await executor.needsMigration();
    if (needsMigration) {
      try {
        await executor.execute();
      } on Object catch (e, stack) {
        _logger.error('Schema migration failed', stack);
        executor.notifyObservers((o) => o.onMigrationError(e, stack));
        if (_config.onMigrationError != null) {
          await _config.onMigrationError!(e, stack);
        } else {
          rethrow;
        }
      }
    }
  }

  void _initializeInternalComponents() {
    // Components that can be initialized in constructor
    _conflictDetector = ConflictDetector<T>();
    _isolateHelper = IsolateHelper();
    _queueManager = QueueManager<T>(
      localAdapter: localAdapter,
      logger: _logger,
    );
  }

  Future<void> _initializeAdapters() async {
    _logger.debug('Initializing local adapter: ${localAdapter.name}');
    await localAdapter.initialize();
    _logger.debug('Initializing remote adapter: ${remoteAdapter.name}');
  }

  void _initializeSyncComponents() {
    _logger.debug('Initializing sync engine');
    _syncEngine = SyncEngine<T>(
      localAdapter: localAdapter,
      remoteAdapter: remoteAdapter,
      conflictResolver: _conflictResolver,
      queueManager: _queueManager,
      conflictDetector: _conflictDetector,
      logger: _logger,
      config: _config,
      connectivityChecker: _connectivityChecker,
      eventController: _eventController,
      statusSubject: _statusSubject,
      metadataSubject: _metadataSubject,
      observers: _observers,
      isolateHelper: _isolateHelper,
      middlewares: _middlewares,
    );
  }

  Future<void> _setupAutoSyncIfEnabled() async {
    if (!_config.autoStartSync) return;

    _logger.debug('Auto-start sync enabled, discovering users');
    await _autoStartSyncForAllUsers();
  }

  Future<void> _autoStartSyncForAllUsers() async {
    try {
      await _queueManager.initializeUser(_config.initialUserId ?? '');
      startAutoSync(_config.initialUserId ?? '');
    } on Object catch (e, stack) {
      _logger.error('Auto-start sync failed', stack);
      _emitError('', 'Auto-start sync failed: $e', stack);
    }
  }

  Future<void> _subscribeToChangeStreams() async {
    await _subscribeToLocalChanges();
    await _subscribeToRemoteChanges();
  }

  Future<void> _subscribeToLocalChanges() async {
    final localChangeStream = localAdapter.changeStream();
    if (localChangeStream == null) {
      _logger.debug('Local adapter does not provide change stream');
      return;
    }

    _localChangeSubscription = localChangeStream.listen(
      (change) => _handleExternalChange(
        change,
        source: DataSource.local,
      ),
      onError: (Object error, StackTrace stackTrace) {
        _logger.error('Error in local change stream', stackTrace);
      },
      cancelOnError: false,
    );

    _logger.info('Subscribed to local adapter change stream');
  }

  Future<void> _subscribeToRemoteChanges() async {
    final remoteChangeStream = remoteAdapter.changeStream;
    if (remoteChangeStream == null) {
      _logger.debug('Remote adapter does not provide change stream');
      return;
    }

    _remoteChangeSubscription = remoteChangeStream.listen(
      (change) => _handleExternalChange(
        change,
        source: DataSource.remote,
      ),
      onError: (Object error, StackTrace stackTrace) {
        _logger.error('Error in remote change stream', stackTrace);
      },
      cancelOnError: false,
    );

    _logger.info('Subscribed to remote adapter change stream');
  }

  Future<void> _emitInitialData() async {
    _ensureInitialized();

    try {
      final initialData = await getAll();
      final userId = initialData.isNotEmpty ? initialData.first.userId : '';

      _eventController.add(
        InitialSyncEvent<T>(
          userId: userId,
          data: initialData,
        ),
      );

      _logger.debug('Emitted initial data: ${initialData.length} items');
    } on Object catch (e, stack) {
      _logger.error('Failed to fetch initial data', stack);
      _emitError('', 'Failed to fetch initial data: $e', stack);
    }
  }

  Future<T> _applyPreSaveTransformations(T item) async {
    var transformed = item;

    for (final middleware in _middlewares) {
      try {
        transformed = await middleware.transformBeforeSave(transformed);
      } on Object catch (e, stack) {
        _logger.error(
          'Middleware ${middleware.runtimeType} failed during pre-save',
          stack,
        );
        rethrow;
      }
    }

    return transformed;
  }

  Future<T> _applyPostFetchTransformations(T item) async {
    var transformed = item;

    for (final middleware in _middlewares) {
      try {
        transformed = await middleware.transformAfterFetch(transformed);
      } on Object catch (e, stack) {
        _logger.error(
          'Middleware ${middleware.runtimeType} failed during post-fetch',
          stack,
        );
        rethrow;
      }
    }

    return transformed;
  }

  SyncOperation<T> _createOperation({
    required String userId,
    required SyncOperationType type,
    required String entityId,
    T? data,
    Map<String, dynamic>? delta,
  }) {
    return SyncOperation<T>(
      id: const Uuid().v4(),
      userId: userId,
      type: type,
      data: data,
      delta: delta,
      entityId: entityId,
      timestamp: DateTime.now(),
    )..logCreation(_logger, 'SynqManager._createOperation');
  }

  void _updateMetricsAndStatistics(SyncResult result, String userId) {
    _updateMetrics(result, userId);
    _updateStatistics(result);
  }

  void _updateMetrics(SyncResult result, String userId) {
    _metrics
      ..totalSyncOperations += 1
      ..successfulSyncs += result.failedCount == 0 ? 1 : 0
      ..failedSyncs += result.failedCount > 0 ? 1 : 0
      ..conflictsDetected += result.conflictsResolved
      ..activeUsers.add(userId);
  }

  void _updateStatistics(SyncResult result) {
    final currentStats = _statisticsSubject.value;
    final totalSyncs = currentStats.totalSyncs + 1;
    final totalDuration = currentStats.totalSyncDuration + result.duration;
    final avgDuration = Duration(
      milliseconds: totalDuration.inMilliseconds ~/ totalSyncs,
    );

    final newStats = currentStats.copyWith(
      totalSyncs: totalSyncs,
      successfulSyncs:
          currentStats.successfulSyncs + (result.failedCount == 0 ? 1 : 0),
      failedSyncs: currentStats.failedSyncs + (result.failedCount > 0 ? 1 : 0),
      conflictsDetected:
          currentStats.conflictsDetected + result.conflictsResolved,
      conflictsAutoResolved:
          currentStats.conflictsAutoResolved + result.conflictsResolved,
      averageDuration: avgDuration,
      totalSyncDuration: totalDuration,
    );
    _statisticsSubject.add(newStats);
  }

  Future<bool> _hasUnsyncedData(String? userId) async {
    if (userId == null || userId.isEmpty) return false;

    try {
      return _queueManager.getPending(userId).isNotEmpty;
    } on Object catch (e) {
      _logger.error('Failed to check unsynced data for user: $userId', e);
      return false;
    }
  }

  Future<void> _executeUserSwitchStrategy(
    UserSwitchStrategy strategy,
    String? oldUserId,
    String newUserId,
    bool hadUnsynced,
  ) async {
    switch (strategy) {
      case UserSwitchStrategy.syncThenSwitch:
        if (oldUserId != null && oldUserId.isNotEmpty) {
          _logger.info('Syncing old user before switch: $oldUserId');
          await sync(oldUserId, force: true);
        }

      case UserSwitchStrategy.clearAndFetch:
        _logger.info('Clearing local data for new user: $newUserId');
        await localAdapter.clearUserData(newUserId);

      case UserSwitchStrategy.promptIfUnsyncedData:
        if (hadUnsynced) {
          throw UserSwitchException(
            oldUserId,
            newUserId,
            'Unsynced data present for $oldUserId. '
            'Resolve before switching or choose a different strategy.',
          );
        }

      case UserSwitchStrategy.keepLocal:
        _logger.debug('Keeping local data during user switch');
    }
  }

  void _emitDataChangeEvent({
    required String userId,
    required T data,
    required ChangeType changeType,
    required DataSource source,
  }) {
    _eventController.add(
      DataChangeEvent<T>(
        userId: userId,
        data: data,
        changeType: changeType,
        source: source,
      ),
    );
  }

  void _emitUserSwitchedEvent(
    String? previousUserId,
    String newUserId,
    bool hadUnsyncedData,
  ) {
    _eventController.add(
      UserSwitchedEvent<T>(
        previousUserId: previousUserId,
        newUserId: newUserId,
        hadUnsyncedData: hadUnsyncedData,
      ),
    );
  }

  void _emitError(String userId, String message, [StackTrace? stackTrace]) {
    _eventController.add(
      SyncErrorEvent<T>(
        userId: userId,
        error: message,
        stackTrace: stackTrace,
      ),
    );
  }

  Future<void> _ensureUserInitialized(String userId) async {
    try {
      await _queueManager.initializeUser(userId);
      _syncEngine?.initializeUser(userId);
    } on Object catch (e, stack) {
      _logger.error('Failed to initialize user: $userId', stack);
      rethrow;
    }
  }

  /// Handles external changes from local or remote adapters.
  ///
  /// Implements sophisticated deduplication to prevent infinite loops:
  /// 1. Checks if change was already processed (by unique key)
  /// 2. Checks if change already exists in pending operations
  /// 3. Checks if local data is already identical
  ///
  /// Only processes changes that represent actual new work.
  Future<void> _handleExternalChange(
    ChangeDetail<T> change, {
    required DataSource source,
  }) async {
    if (_disposed) {
      _logger.debug('Ignoring change after disposal');
      return;
    }

    // Notify observers immediately, before any deduplication logic.
    // This ensures that all incoming external events are visible for debugging.
    _notifyObservers((o) => o.onExternalChange(change, source));
    _logger.info(
      'Received external change from $source: ${change.type.name} for ${change.entityId}',
    );

    // Use a lock to prevent race conditions when multiple identical changes
    // arrive at the same time. This ensures they are processed sequentially.
    await _externalChangeLock.synchronized(() async {
      try {
        final changeKey = _computeChangeKey(change);
        final dataHash = _computeDataHash(change.data);

        if (_isAlreadyProcessed(changeKey, dataHash)) {
          _logger.debug('Skipping duplicate change from $source: $changeKey');
          return;
        }

        if (await _isDuplicateOfPendingOperation(change)) {
          _logger.debug('Change already queued in pending operations');
          _markAsProcessed(changeKey, dataHash);
          return;
        }

        if (await _isDataAlreadyCurrent(change)) {
          _logger.debug('Local data already matches change');
          _markAsProcessed(changeKey, dataHash);
          return;
        }

        await _applyExternalChange(change, source: source);
        _markAsProcessed(changeKey, dataHash);

        _logger.debug('External change processed successfully: $changeKey');
      } on Object catch (e, stack) {
        _logger.error('Failed to handle external change', stack);
        _emitError(
          change.userId,
          'Failed to process external change: $e',
          stack,
        );
      }
    });
  }

  /// Computes a unique key for change deduplication.
  String _computeChangeKey(ChangeDetail<T> change) {
    return '${change.type.name}_'
        '${change.entityId}_'
        '${change.userId}_'
        '${change.timestamp.millisecondsSinceEpoch}';
  }

  String _computeDataHash(T? data) {
    if (data == null) {
      return 'null';
    }
    try {
      final payload = _extractDataPayload(data.toMap()).toString();
      return sha1.convert(payload.codeUnits).toString();
    } on Object catch (_) {
      return data.hashCode.toString();
    }
  }

  bool _isAlreadyProcessed(String changeKey, String dataHash) {
    return _processedChangeKeys.containsKey(changeKey) &&
        _processedChangeKeys[changeKey] == dataHash;
  }

  void _markAsProcessed(String changeKey, String dataHash) {
    _processedChangeKeys[changeKey] = dataHash;
    _pruneProcessedChangesCache();
  }

  void _pruneProcessedChangesCache() {
    if (_processedChangeKeys.length <= _maxProcessedChangesCache) {
      return;
    }

    final excessCount = _processedChangeKeys.length - _maxProcessedChangesCache;
    final keysToRemove = _processedChangeKeys.keys.take(excessCount).toList();
    _processedChangeKeys.removeWhere((key, _) => keysToRemove.contains(key));

    _logger.debug('Pruned $excessCount old change keys from cache');
  }

  /// Checks if this change duplicates an operation already in the queue.
  Future<bool> _isDuplicateOfPendingOperation(ChangeDetail<T> change) async {
    try {
      final pendingOps = await localAdapter.getPendingOperations(change.userId);

      for (final op in pendingOps) {
        if (!_isMatchingOperation(op, change)) {
          continue;
        }

        // For creates and updates, verify data matches
        if (change.data != null && op.data != null) {
          if (_areEntitiesEquivalent(op.data!, change.data!)) {
            return true;
          }
        } else if (change.data == null && op.data == null) {
          // Both are deletes for same entity
          return true;
        }
      }

      return false;
    } on Object catch (e, stack) {
      _logger.error('Error checking duplicate operation', stack);
      // On error, assume not duplicate to allow processing
      return false;
    }
  }

  bool _isMatchingOperation(
    SyncOperation<T> operation,
    ChangeDetail<T> change,
  ) {
    return operation.type == change.type &&
        operation.entityId == change.entityId;
  }

  /// Checks if local data already matches the incoming change.
  Future<bool> _isDataAlreadyCurrent(ChangeDetail<T> change) async {
    try {
      // For deletions, check if entity is already gone or marked deleted
      if (change.type == SyncOperationType.delete) {
        return await _isAlreadyDeleted(change.entityId, change.userId);
      }

      // For creates/updates, compare actual data
      if (change.data == null) {
        return false;
      }

      final existing = await localAdapter.getById(
        change.entityId,
        change.userId,
      );

      if (existing == null) {
        return false;
      }

      return _areEntitiesEquivalent(existing, change.data!);
    } on Object catch (e, stack) {
      _logger.error('Error checking data currency', stack);
      // On error, assume data is not current to allow processing
      return false;
    }
  }

  Future<bool> _isAlreadyDeleted(String entityId, String userId) async {
    final existing = await localAdapter.getById(entityId, userId);
    return existing == null || existing.isDeleted;
  }

  /// Compares two entities for logical equivalence.
  ///
  /// Considers metadata (id, version, timestamps) and data payload.
  /// Allows small timestamp differences due to serialization rounding.
  bool _areEntitiesEquivalent(T entity1, T entity2) {
    // Check metadata fields
    if (entity1.id != entity2.id ||
        entity1.userId != entity2.userId ||
        entity1.version != entity2.version ||
        entity1.isDeleted != entity2.isDeleted) {
      return false;
    }

    // Compare timestamps with tolerance for serialization differences
    if (!_areTimestampsEquivalent(
          entity1.modifiedAt,
          entity2.modifiedAt,
        ) ||
        !_areTimestampsEquivalent(
          entity1.createdAt,
          entity2.createdAt,
        )) {
      return false;
    }

    // Compare business data via JSON representation
    return _areDataPayloadsEquivalent(entity1, entity2);
  }

  bool _areTimestampsEquivalent(DateTime ts1, DateTime ts2) {
    return ts1.difference(ts2).abs().inSeconds <= _timestampToleranceSeconds;
  }

  /// Compares entity data payloads excluding metadata fields.
  bool _areDataPayloadsEquivalent(T entity1, T entity2) {
    try {
      final json1 = _extractDataPayload(entity1.toMap());
      final json2 = _extractDataPayload(entity2.toMap());

      // Deep comparison via string representation
      // In production, consider using a proper deep equality package
      return json1.toString() == json2.toString();
    } on Object catch (e, stack) {
      _logger.error('Error comparing entity payloads', stack);
      // On error, assume different to allow processing
      return false;
    }
  }

  /// Extracts business data from JSON by removing metadata fields.
  Map<String, dynamic> _extractDataPayload(Map<String, dynamic> json) {
    // Create a copy to avoid modifying original
    final payload = Map<String, dynamic>.from(json)
      ..remove('id')
      ..remove('userId')
      ..remove('modifiedAt')
      ..remove('createdAt')
      ..remove('version')
      ..remove('isDeleted');

    return payload;
  }

  /// Applies an external change to local storage.
  Future<void> _applyExternalChange(
    ChangeDetail<T> change, {
    required DataSource source,
  }) async {
    switch (change.type) {
      case SyncOperationType.create:
      case SyncOperationType.update:
        if (change.data == null) {
          _logger.warn(
            'Ignoring ${change.type.name} change with null data '
            'for entity ${change.entityId}',
          );
          return;
        }

        await push(
          change.data!,
          change.userId,
          source: source, // Pass the source to prevent re-queuing
        );
        _logger.info(
          'Applied external ${change.type.name} for entity ${change.entityId}',
        );

      case SyncOperationType.delete:
        await delete(
          change.entityId, change.userId,
          source: source, // Pass the source to prevent re-queuing
        );
        _logger.info('Applied external delete for entity ${change.entityId}');
    }
  }

  void _notifyObservers(void Function(SynqObserver<T> observer) action) {
    for (final observer in _observers) {
      try {
        action(observer);
      } on Object catch (e, stack) {
        _logger.error('Observer ${observer.runtimeType} threw an error', stack);
      }
    }
  }

  void _ensureInitialized() {
    if (!_initialized || _syncEngine == null) {
      throw StateError(
        'SynqManager.initialize() must be called before use.',
      );
    }
  }

  void _ensureInitializedAndNotDisposed() {
    if (_disposed) {
      throw StateError('Cannot perform operations after disposal');
    }
    _ensureInitialized();
  }
}
