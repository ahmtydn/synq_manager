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

class SynqManager<T extends SyncableEntity> {
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

  final LocalAdapter<T> localAdapter;
  final RemoteAdapter<T> remoteAdapter;
  final SyncConflictResolver<T> conflictResolver;
  final SynqConfig config;
  final ConnectivityChecker connectivityChecker;
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

  Stream<SyncEvent<T>> get eventStream => _eventController.stream;

  Stream<DataChangeEvent<T>> get onDataChange => eventStream
      .where((event) => event is DataChangeEvent<T>)
      .cast<DataChangeEvent<T>>();

  Stream<SyncStartedEvent<T>> get onSyncStarted => eventStream
      .where((event) => event is SyncStartedEvent<T>)
      .cast<SyncStartedEvent<T>>();

  Stream<SyncProgressEvent<T>> get onSyncProgress => eventStream
      .where((event) => event is SyncProgressEvent<T>)
      .cast<SyncProgressEvent<T>>();

  Stream<SyncCompletedEvent<T>> get onSyncCompleted => eventStream
      .where((event) => event is SyncCompletedEvent<T>)
      .cast<SyncCompletedEvent<T>>();

  Stream<ConflictDetectedEvent<T>> get onConflict => eventStream
      .where((event) => event is ConflictDetectedEvent<T>)
      .cast<ConflictDetectedEvent<T>>();

  Stream<UserSwitchedEvent<T>> get onUserSwitched => eventStream
      .where((event) => event is UserSwitchedEvent<T>)
      .cast<UserSwitchedEvent<T>>();

  Stream<SyncErrorEvent<T>> get onError => eventStream
      .where((event) => event is SyncErrorEvent<T>)
      .cast<SyncErrorEvent<T>>();

  Stream<SyncStatusSnapshot> get syncStatusStream => _statusSubject.stream;

  void addMiddleware(SynqMiddleware<T> middleware) =>
      _middlewares.add(middleware);

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

  Future<List<T>> getAll(String userId) async {
    _ensureInitialized();
    final items = await localAdapter.getAll(userId);
    return Future.wait(items.map(_transformAfterFetch));
  }

  Future<T?> getById(String id, String userId) async {
    _ensureInitialized();
    final item = await localAdapter.getById(id, userId);
    if (item == null) return null;
    return _transformAfterFetch(item);
  }

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

  Future<void> cancelSync(String userId) async {
    _ensureInitialized();
    _syncEngine?.cancel(userId);
  }

  Future<void> pauseSync(String userId) async {
    _ensureInitialized();
    await _syncEngine?.pause(userId);
  }

  Future<void> resumeSync(String userId) async {
    _ensureInitialized();
    _syncEngine?.resume(userId);
  }

  Future<SyncStatusSnapshot> getSyncSnapshot(String userId) async {
    _ensureInitialized();
    return _syncEngine!.getSnapshot(userId);
  }

  Future<SyncStatistics> getSyncStatistics(String userId) async {
    _ensureInitialized();
    return _statistics;
  }

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
    } on Exception catch (e) {
      return UserSwitchResult.failure(
        previousUserId: oldUserId,
        newUserId: newUserId,
        errorMessage: e.toString(),
      );
    }
  }

  void startAutoSync(String userId, {Duration? interval}) {
    _ensureInitialized();
    stopAutoSync(userId: userId);
    final syncInterval = interval ?? config.autoSyncInterval;
    _autoSyncTimers[userId] = Timer.periodic(syncInterval, (_) {
      unawaited(sync(userId));
    });
  }

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

  Future<SyncStatus> getSyncStatus(String userId) async {
    final snapshot = await getSyncSnapshot(userId);
    return snapshot.status;
  }

  Future<int> getPendingCount(String userId) async {
    _ensureInitialized();
    await _queueManager.initializeUser(userId);
    return _queueManager.getPending(userId).length;
  }

  Future<void> retryFailedOperations(String userId) async {
    _ensureInitialized();
    await sync(userId, force: true);
  }

  Future<void> clearFailedOperations(String userId) async {
    _ensureInitialized();
    // For now failed operations remain in queue; we simply log.
    logger.warn('clearFailedOperations is not yet implemented.');
  }

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
