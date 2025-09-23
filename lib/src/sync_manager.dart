import 'dart:async';

import 'package:synq_manager/src/background/sync_background_task.dart';
import 'package:synq_manager/src/core/cloud_adapter.dart';
import 'package:synq_manager/src/core/conflict_resolver.dart';
import 'package:synq_manager/src/core/local_store.dart';
import 'package:synq_manager/src/domain/conflict_event.dart';
import 'package:synq_manager/src/domain/sync_entity.dart';
import 'package:synq_manager/src/domain/sync_policy.dart';
import 'package:synq_manager/src/domain/sync_status.dart';
import 'package:synq_manager/src/utils/logger.dart';
import 'package:synq_manager/src/utils/network_checker.dart';

/// Main synchronization manager class
/// Provides the single entry point for all sync operations
class SyncManager {
  SyncManager({
    required this.policy,
    SyncLogger? logger,
    NetworkChecker? networkChecker,
  })  : _logger = logger ?? SyncLogger(),
        _networkChecker = networkChecker ?? NetworkChecker();

  final SyncPolicy policy;
  final SyncLogger _logger;
  final NetworkChecker _networkChecker;

  final Map<Type, LocalStore> _localStores = {};
  final Map<Type, CloudAdapter> _cloudAdapters = {};
  final Map<Type, ConflictResolver> _conflictResolvers = {};

  Timer? _periodicSyncTimer;
  bool _initialized = false;

  final StreamController<SyncSystemStatus> _statusController =
      StreamController<SyncSystemStatus>.broadcast();

  final StreamController<ConflictEvent> _conflictController =
      StreamController<ConflictEvent>.broadcast();

  SyncSystemStatus _currentStatus = const SyncSystemStatus(
    isOnline: false,
    lastSyncTime: null,
    pendingCount: 0,
    conflictCount: 0,
  );

  /// Initialize the sync manager with stores, adapters, and auth provider
  Future<void> initialize({
    required List<LocalStore> stores,
    required Map<Type, CloudAdapter> adapters,
    Map<Type, ConflictResolver>? conflictResolvers,
  }) async {
    if (_initialized) {
      throw StateError('SyncManager is already initialized');
    }

    _logger.info('Initializing SyncManager');

    // Initialize local stores
    for (final store in stores) {
      await store.initialize();
      _localStores[store.runtimeType] = store;
    }

    // Initialize cloud adapters
    for (final entry in adapters.entries) {
      await entry.value.initialize();
      _cloudAdapters[entry.key] = entry.value;
    }

    // Set up conflict resolvers
    if (conflictResolvers != null) {
      _conflictResolvers.addAll(conflictResolvers);
    }

    // Set up network monitoring
    await _networkChecker.initialize();
    _networkChecker.connectivityStream.listen(_onConnectivityChanged);

    // Set up periodic sync if enabled
    if (policy.backgroundSyncEnabled) {
      _setupPeriodicSync();

      // Initialize background tasks
      await SyncBackgroundTask.initialize();
      await SyncBackgroundTask.registerPeriodicSync(
        policy.autoSyncInterval,
        onSyncRequested: triggerSync,
      );
    }

    // Initial sync if policy allows
    if (policy.fetchOnStart) {
      unawaited(_performInitialSync());
    }

    _initialized = true;
    _updateStatus(isOnline: await _networkChecker.isConnected);
    _logger.info('SyncManager initialization complete');
  }

  /// Register a local store for a specific entity type
  void registerLocalStore<T extends SyncEntity>(LocalStore<T> store) {
    _ensureInitialized();
    _localStores[T] = store;
  }

  /// Register a cloud adapter for a specific entity type
  void registerCloudAdapter<T extends SyncEntity>(CloudAdapter<T> adapter) {
    _ensureInitialized();
    _cloudAdapters[T] = adapter;
  }

  /// Register a conflict resolver for a specific entity type
  void registerConflictResolver<T extends SyncEntity>(
    ConflictResolver<T> resolver,
  ) {
    _ensureInitialized();
    _conflictResolvers[T] = resolver;
  }

  /// Trigger a manual sync operation
  Future<void> triggerSync({bool full = false}) async {
    _ensureInitialized();

    if (!await _networkChecker.isConnected) {
      _logger.warning('Cannot sync: no network connection');
      return;
    }

    _logger.info('Starting ${full ? 'full' : 'incremental'} sync');
    _updateStatus(isOnline: true);

    try {
      for (final storeEntry in _localStores.entries) {
        final entityType = storeEntry.key;
        final store = storeEntry.value;
        final adapter = _cloudAdapters[entityType];

        if (adapter == null) {
          _logger.warning('No cloud adapter registered for $entityType');
          continue;
        }

        await _syncEntityType(store, adapter, full: full);
      }

      _updateStatus(lastSyncTime: DateTime.now());
      _logger.info('Sync completed successfully');
    } catch (e, stackTrace) {
      _logger.error('Sync failed: $e', stackTrace);
      _updateStatus(error: e.toString());
    }
  }

  /// Sync a specific entity type
  Future<void> _syncEntityType(
    LocalStore store,
    CloudAdapter adapter, {
    bool full = false,
  }) async {
    // Push local changes
    await _pushLocalChanges(store, adapter);

    // Pull remote changes
    await _pullRemoteChanges(store, adapter, full: full);
  }

  /// Push local changes to the cloud
  Future<void> _pushLocalChanges(LocalStore store, CloudAdapter adapter) async {
    // Push dirty entities
    final dirtyEntities = await store.getDirtyEntities();
    for (final entity in dirtyEntities) {
      await _pushEntity(store, adapter, entity);
    }

    // Push deletions
    final deletedEntities = await store.getDeletedEntities();
    for (final entity in deletedEntities) {
      await _pushDeletion(store, adapter, entity);
    }
  }

  /// Push a single entity to the cloud
  Future<void> _pushEntity(
    LocalStore store,
    CloudAdapter adapter,
    SyncEntity entity,
  ) async {
    try {
      SyncEntity updatedEntity;

      if (entity.version == 0) {
        // New entity
        updatedEntity = await adapter.pushCreate(entity);
      } else {
        // Updated entity
        updatedEntity = await adapter.pushUpdate(entity);
      }

      // Update local store with synced entity
      final syncedEntity = updatedEntity.markAsSynced();
      await store.save(syncedEntity);
    } catch (e) {
      _logger.error('Failed to push entity ${entity.id}: $e');
      await _handlePushError(store, entity, e);
    }
  }

  /// Push a deletion to the cloud
  Future<void> _pushDeletion(
    LocalStore store,
    CloudAdapter adapter,
    SyncEntity entity,
  ) async {
    try {
      await adapter.pushDelete(entity.id, version: entity.version);
      await store.delete(entity.id);
    } catch (e) {
      _logger.error('Failed to push deletion ${entity.id}: $e');
    }
  }

  /// Pull remote changes from the cloud
  Future<void> _pullRemoteChanges(
    LocalStore store,
    CloudAdapter adapter, {
    bool full = false,
  }) async {
    try {
      List<SyncEntity> remoteEntities;

      if (full || _currentStatus.lastSyncTime == null) {
        remoteEntities = await adapter.fetchAll();
      } else {
        remoteEntities = await adapter.fetchSince(_currentStatus.lastSyncTime!);
      }

      for (final remoteEntity in remoteEntities) {
        await _handleRemoteEntity(store, remoteEntity);
      }
    } catch (e) {
      _logger.error('Failed to pull remote changes: $e');
    }
  }

  /// Handle a remote entity (conflict detection and resolution)
  Future<void> _handleRemoteEntity(
    LocalStore store,
    SyncEntity remoteEntity,
  ) async {
    final localEntity = await store.get(remoteEntity.id);

    if (localEntity == null) {
      // New remote entity
      await store.save(remoteEntity);
      return;
    }

    // Check for conflicts
    if (_hasConflict(localEntity, remoteEntity)) {
      await _handleConflict(store, localEntity, remoteEntity);
    } else if (remoteEntity.version > localEntity.version) {
      // Remote is newer, update local
      await store.save(remoteEntity);
    }
    // Local is newer or same version, keep local
  }

  /// Check if there's a conflict between local and remote entities
  bool _hasConflict(SyncEntity local, SyncEntity remote) {
    // Conflict if both have been modified since last sync
    return local.isDirty && remote.version > local.version;
  }

  /// Handle a conflict between local and remote entities
  Future<void> _handleConflict(
    LocalStore store,
    SyncEntity local,
    SyncEntity remote,
  ) async {
    final entityType = local.runtimeType;
    final resolver = _conflictResolvers[entityType];

    if (resolver == null) {
      _logger.warning(
        'No conflict resolver for $entityType, using remote version',
      );
      await store.save(remote);
      return;
    }

    final conflictEvent = ConflictEvent(
      localEntity: local,
      remoteEntity: remote,
      entityType: entityType,
    );

    _conflictController.add(conflictEvent);
    _updateStatus(conflictCount: _currentStatus.conflictCount + 1);

    try {
      final resolvedEntity = await resolver.resolve(conflictEvent);
      await store.save(resolvedEntity);

      _updateStatus(conflictCount: _currentStatus.conflictCount - 1);
      _logger.info('Conflict resolved for entity ${local.id}');
    } catch (e) {
      _logger.error('Failed to resolve conflict for entity ${local.id}: $e');
    }
  }

  /// Handle push errors (e.g., version conflicts)
  Future<void> _handlePushError(
    LocalStore store,
    SyncEntity entity,
    dynamic error,
  ) async {
    // Implement retry logic with exponential backoff
    var retryCount = 0;
    var delay = const Duration(seconds: 1);

    while (retryCount < policy.maxRetryAttempts) {
      await Future<void>.delayed(delay);

      try {
        // Fetch latest version from remote
        final adapter = _cloudAdapters[entity.runtimeType];
        if (adapter != null) {
          final remoteEntity = await adapter.fetchById(entity.id);
          if (remoteEntity != null) {
            await _handleRemoteEntity(store, remoteEntity);
          }
        }
        break;
      } catch (e) {
        retryCount++;
        delay = Duration(
          milliseconds:
              (delay.inMilliseconds * policy.retryBackoffMultiplier).round(),
        );
        _logger.warning('Retry $retryCount failed for entity ${entity.id}: $e');
      }
    }
  }

  /// Set up periodic sync timer
  void _setupPeriodicSync() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = Timer.periodic(policy.autoSyncInterval, (_) {
      if (policy.backgroundSyncEnabled) {
        unawaited(triggerSync());
      }
    });
  }

  /// Handle connectivity changes
  void _onConnectivityChanged(bool isConnected) {
    _updateStatus(isOnline: isConnected);

    if (isConnected && policy.fetchOnStart) {
      // Trigger sync when coming back online
      unawaited(triggerSync());
    }
  }

  /// Perform initial sync on startup
  Future<void> _performInitialSync() async {
    try {
      await triggerSync();
    } catch (e) {
      _logger.error('Initial sync failed: $e');
    }
  }

  /// Update the sync system status
  void _updateStatus({
    bool? isOnline,
    DateTime? lastSyncTime,
    int? pendingCount,
    int? conflictCount,
    String? error,
  }) {
    _currentStatus = _currentStatus.copyWith(
      isOnline: isOnline,
      lastSyncTime: lastSyncTime,
      pendingCount: pendingCount,
      conflictCount: conflictCount,
      error: error,
    );

    if (!_statusController.isClosed) {
      _statusController.add(_currentStatus);
    }
  }

  /// Stream of sync system status changes
  Stream<SyncSystemStatus> get statusStream => _statusController.stream;

  /// Stream of conflict events
  Stream<ConflictEvent> get conflictStream => _conflictController.stream;

  /// Get the current sync status
  SyncSystemStatus get currentStatus => _currentStatus;

  /// Shutdown the sync manager and clean up resources
  Future<void> shutdown() async {
    _logger.info('Shutting down SyncManager');

    _periodicSyncTimer?.cancel();

    // Close streams
    await _statusController.close();
    await _conflictController.close();

    // Close local stores
    for (final store in _localStores.values) {
      await store.close();
    }

    // Dispose cloud adapters
    for (final adapter in _cloudAdapters.values) {
      await adapter.dispose();
    }
    // Dispose network checker
    await _networkChecker.dispose();

    _initialized = false;
    _logger.info('SyncManager shutdown complete');
  }

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError('SyncManager must be initialized before use');
    }
  }
}
