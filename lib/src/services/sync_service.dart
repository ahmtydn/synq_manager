import 'dart:async';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive_plus_secure/hive_plus_secure.dart';
import 'package:synq_manager/src/events/event_types.dart';
import 'package:synq_manager/src/models/conflict_resolution.dart';
import 'package:synq_manager/src/models/sync_config.dart';
import 'package:synq_manager/src/models/sync_data.dart';
import 'package:synq_manager/src/models/sync_event.dart';
import 'package:synq_manager/src/services/storage_service.dart';
import 'package:workmanager/workmanager.dart';

/// Function signature for cloud synchronization operations
typedef CloudSyncFunction<T> = Future<SyncResult<T>> Function(
  Map<String, SyncData<T>> localChanges,
  Map<String, String> headers,
);

/// Function signature for fetching remote data
typedef CloudFetchFunction<T> = Future<Map<String, SyncData<T>>> Function(
  int lastSyncTimestamp,
  Map<String, String> headers,
);

/// Result of a synchronization operation
class SyncResult<T> {
  const SyncResult({
    required this.success,
    this.remoteData = const {},
    this.conflicts = const [],
    this.error,
    this.metadata = const {},
  });

  /// Whether the sync operation was successful
  final bool success;

  /// Data received from remote source
  final Map<String, SyncData<T>> remoteData;

  /// Conflicts detected during sync
  final List<DataConflict<T>> conflicts;

  /// Error information if sync failed
  final Object? error;

  /// Additional metadata about the sync operation
  final Map<String, dynamic> metadata;
}

/// Service for handling cloud synchronization
class SyncService<T extends DocumentSerializable> {
  SyncService._({
    required this.storageService,
    required this.config,
    required this.cloudSyncFunction,
    required this.cloudFetchFunction,
  });

  /// Storage service for local data
  final StorageService<T> storageService;

  /// Synchronization configuration
  final SyncConfig config;

  /// Function for pushing data to cloud
  final CloudSyncFunction<T> cloudSyncFunction;

  /// Function for fetching data from cloud
  final CloudFetchFunction<T> cloudFetchFunction;

  /// Stream controller for sync events
  final StreamController<SynqEvent<T>> _eventController =
      StreamController<SynqEvent<T>>.broadcast();

  /// Connectivity subscription
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  /// Background sync timer
  Timer? _syncTimer;

  /// Current connectivity status
  ConnectivityStatus _connectivityStatus = ConnectivityStatus.unknown;

  /// Last successful sync timestamp
  int _lastSyncTimestamp = 0;

  /// Whether sync is currently in progress
  bool _isSyncing = false;

  /// Pending changes queue
  final List<String> _pendingChanges = [];

  /// Active conflicts that need resolution
  final Map<String, DataConflict<T>> _activeConflicts = {};

  /// Storage key for sync metadata
  static const String _syncMetadataKey = '__sync_metadata__';

  /// Box for storing sync metadata
  Box<int>? _metadataBox;

  /// Creates a new sync service instance
  static Future<SyncService<T>> create<T extends DocumentSerializable>({
    required StorageService<T> storageService,
    required SyncConfig config,
    required CloudSyncFunction<T> cloudSyncFunction,
    required CloudFetchFunction<T> cloudFetchFunction,
  }) async {
    final service = SyncService<T>._(
      storageService: storageService,
      config: config,
      cloudSyncFunction: cloudSyncFunction,
      cloudFetchFunction: cloudFetchFunction,
    );

    await service._initialize();
    return service;
  }

  /// Initializes the sync service
  Future<void> _initialize() async {
    try {
      // Initialize metadata storage
      await _initializeMetadataStorage();

      // Load last sync timestamp
      await _loadLastSyncTimestamp();

      // Set up connectivity monitoring
      _setupConnectivityMonitoring();

      // Set up storage event monitoring
      _setupStorageEventMonitoring();

      // Register background sync if enabled
      if (config.enableBackgroundSync) {
        await _registerBackgroundSync();
      }

      // Set up periodic sync timer
      _setupSyncTimer();

      _eventController.add(SynqEvent<T>.connected());
    } catch (error) {
      _eventController.add(
        SynqEvent<T>.syncError(
          key: '__sync_init__',
          error: error,
        ),
      );
      rethrow;
    }
  }

  /// Sets up connectivity monitoring
  void _setupConnectivityMonitoring() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      (ConnectivityResult result) {
        final previousStatus = _connectivityStatus;
        _connectivityStatus = _mapConnectivityResult(result);

        if (previousStatus == ConnectivityStatus.offline &&
            _connectivityStatus == ConnectivityStatus.online) {
          // Connection restored, trigger sync
          _eventController.add(SynqEvent<T>.connected());
          unawaited(_performSync());
        } else if (_connectivityStatus == ConnectivityStatus.offline) {
          _eventController.add(SynqEvent<T>.disconnected());
        }
      },
      onError: (Object error) {
        _eventController.add(
          SynqEvent<T>.syncError(
            key: '__connectivity__',
            error: error,
          ),
        );
      },
    );
  }

  /// Maps connectivity result to our status enum
  ConnectivityStatus _mapConnectivityResult(ConnectivityResult result) {
    switch (result) {
      case ConnectivityResult.wifi:
      case ConnectivityResult.mobile:
      case ConnectivityResult.ethernet:
        return ConnectivityStatus.online;
      case ConnectivityResult.none:
        return ConnectivityStatus.offline;
      default:
        return ConnectivityStatus.unknown;
    }
  }

  /// Sets up storage event monitoring
  void _setupStorageEventMonitoring() {
    storageService.events.listen(
      (SynqEvent<T> event) {
        // Forward storage events
        _eventController.add(event);

        // Track changes for sync
        if (event.type == SynqEventType.create ||
            event.type == SynqEventType.update ||
            event.type == SynqEventType.delete) {
          _trackChange(event.key);
        }
      },
      onError: (Object error) {
        _eventController.add(
          SynqEvent<T>.syncError(
            key: '__storage_events__',
            error: error,
          ),
        );
      },
    );
  }

  /// Initializes metadata storage for sync timestamps
  Future<void> _initializeMetadataStorage() async {
    try {
      // Open a dedicated box for sync metadata using HivePlusSecure API
      final metadataBoxName = '${storageService.boxName}_sync_metadata';
      _metadataBox = Hive.box<int>(
        name: metadataBoxName,
        encryptionKey: config.encryptionKey,
      );
    } catch (error) {
      _eventController.add(
        SynqEvent<T>.syncError(
          key: '__metadata_storage_init__',
          error: error,
        ),
      );
      rethrow;
    }
  }

  /// Loads last sync timestamp from persistent storage
  Future<void> _loadLastSyncTimestamp() async {
    try {
      _lastSyncTimestamp = _metadataBox?.get(_syncMetadataKey) ?? 0;
    } catch (error) {
      _eventController.add(
        SynqEvent<T>.syncError(
          key: '__load_sync_timestamp__',
          error: error,
        ),
      );
      // Continue with default value (0) if loading fails
      _lastSyncTimestamp = 0;
    }
  }

  /// Saves last sync timestamp to persistent storage
  Future<void> _saveLastSyncTimestamp() async {
    try {
      _metadataBox?.put(_syncMetadataKey, _lastSyncTimestamp);
    } catch (error) {
      _eventController.add(
        SynqEvent<T>.syncError(
          key: '__save_sync_timestamp__',
          error: error,
        ),
      );
      // Don't rethrow - sync should continue even if timestamp save fails
    }
  }

  /// Tracks a change for synchronization
  void _trackChange(String key) {
    if (!_pendingChanges.contains(key)) {
      _pendingChanges.add(key);
    }

    // Trigger immediate sync for high priority changes
    if (config.priority == SyncPriority.high ||
        config.priority == SyncPriority.critical) {
      unawaited(_performSync());
    }
  }

  /// Sets up periodic sync timer
  void _setupSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(config.syncInterval, (_) {
      if (_connectivityStatus == ConnectivityStatus.online && !_isSyncing) {
        unawaited(_performSync());
      }
    });
  }

  /// Registers background sync with WorkManager
  Future<void> _registerBackgroundSync() async {
    try {
      await Workmanager().initialize(
        _callbackDispatcher,
      );

      await Workmanager().registerPeriodicTask(
        'sync_task_${storageService.boxName}',
        'syncTask',
        frequency: config.syncInterval,
        constraints: Constraints(
          networkType: NetworkType.connected,
          requiresCharging: false,
          requiresDeviceIdle: false,
        ),
        inputData: {
          'boxName': storageService.boxName,
          'encryptionKey': config.encryptionKey,
        },
      );
    } catch (error) {
      _eventController.add(
        SynqEvent<T>.syncError(
          key: '__background_sync_register__',
          error: error,
        ),
      );
    }
  }

  /// Stream of sync events
  Stream<SynqEvent<T>> get events => _eventController.stream;

  /// Current connectivity status
  ConnectivityStatus get connectivityStatus => _connectivityStatus;

  /// Whether sync is currently in progress
  bool get isSyncing => _isSyncing;

  /// Number of pending changes
  int get pendingChangesCount => _pendingChanges.length;

  /// Active conflicts that need resolution
  Map<String, DataConflict<T>> get activeConflicts =>
      Map.unmodifiable(_activeConflicts);

  /// Last sync timestamp
  int get lastSyncTimestamp => _lastSyncTimestamp;

  /// Manually triggers a synchronization
  Future<void> sync() async {
    await _performSync();
  }

  /// Performs the actual synchronization
  Future<void> _performSync() async {
    if (_isSyncing) return;
    if (_connectivityStatus != ConnectivityStatus.online) return;

    _isSyncing = true;
    _eventController.add(SynqEvent<T>.syncStart(key: '__sync__'));

    try {
      // Handle first-time sync differently
      if (_lastSyncTimestamp == 0) {
        await _performInitialSync();
      } else {
        await _performIncrementalSync();
      }

      _lastSyncTimestamp = DateTime.now().millisecondsSinceEpoch;
      await _saveLastSyncTimestamp();
      _eventController.add(SynqEvent<T>.syncComplete(key: '__sync__'));
    } catch (error) {
      _eventController.add(
        SynqEvent<T>.syncError(
          key: '__sync__',
          error: error,
        ),
      );

      if (config.enableAutoRetry) {
        await _scheduleRetry();
      }
    } finally {
      _isSyncing = false;
    }
  }

  /// Performs initial sync when no previous sync exists
  Future<void> _performInitialSync() async {
    // Step 1: Get all local data for initial sync
    final allLocalData = await storageService.getAll();

    // Step 2: Fetch all remote data
    final remoteData = await _fetchRemoteUpdates();

    // Step 3: Detect conflicts
    final conflicts = await _detectConflicts(allLocalData, remoteData);

    // Step 4: Push non-conflicted local data
    final cleanLocalChanges = _removeConflictedItems(allLocalData, conflicts);
    if (cleanLocalChanges.isNotEmpty) {
      await _pushLocalChanges(cleanLocalChanges);
    }

    // Step 5: Apply non-conflicted remote data
    await _processRemoteData(remoteData, conflicts);

    // Step 6: Handle conflicts
    await _handleConflicts(conflicts);

    // Step 7: Clear all pending changes (initial sync complete)
    _pendingChanges.clear();
  }

  /// Performs incremental sync with only changed data
  Future<void> _performIncrementalSync() async {
    // Step 1: Always fetch remote updates first to detect conflicts
    final remoteData = await _fetchRemoteUpdates();

    // Step 2: Get pending local changes
    final localChanges = await _getPendingChanges();

    // Step 3: Detect conflicts between local and remote data
    final conflicts = await _detectConflicts(localChanges, remoteData);

    // Step 4: If we have local changes, push them to remote
    if (localChanges.isNotEmpty) {
      // Remove conflicted items from local changes for now
      final cleanLocalChanges = _removeConflictedItems(localChanges, conflicts);

      if (cleanLocalChanges.isNotEmpty) {
        await _pushLocalChanges(cleanLocalChanges);
      }
    }

    // Step 5: Apply remote changes (non-conflicted ones)
    await _processRemoteData(remoteData, conflicts);

    // Step 6: Handle conflicts
    await _handleConflicts(conflicts);

    // Step 7: Clear pending changes for non-conflicted items
    _clearProcessedChanges(localChanges, conflicts);
  }

  /// Gets pending changes from storage
  Future<Map<String, SyncData<T>>> _getPendingChanges() async {
    final changes = <String, SyncData<T>>{};

    // Only get explicitly tracked pending changes
    for (final key in List<String>.from(_pendingChanges)) {
      final data = await storageService.get(key);
      if (data != null) {
        changes[key] = data;
      } else {
        // Remove non-existent keys from pending list
        _pendingChanges.remove(key);
      }
    }

    return changes;
  }

  /// Fetches remote updates and returns the data
  Future<Map<String, SyncData<T>>> _fetchRemoteUpdates() async {
    _eventController.add(SynqEvent<T>.cloudFetchStart(key: '__cloud_fetch__'));

    try {
      final remoteData = await cloudFetchFunction(
        _lastSyncTimestamp,
        config.customHeaders,
      );

      _eventController.add(
        SynqEvent<T>.cloudFetchSuccess(
          key: '__cloud_fetch__',
          metadata: {'remoteDataCount': remoteData.length},
        ),
      );

      return remoteData;
    } catch (error) {
      _eventController.add(
        SynqEvent<T>.cloudFetchError(
          key: '__cloud_fetch__',
          error: error,
          metadata: const {'operation': 'cloudFetchFunction'},
        ),
      );
      rethrow;
    }
  }

  /// Detects conflicts between local and remote data
  Future<List<DataConflict<T>>> _detectConflicts(
    Map<String, SyncData<T>> localChanges,
    Map<String, SyncData<T>> remoteData,
  ) async {
    final conflicts = <DataConflict<T>>[];

    for (final entry in localChanges.entries) {
      final key = entry.key;
      final localItem = entry.value;
      final remoteItem = remoteData[key];

      if (remoteItem != null) {
        // Both local and remote have changes
        if (localItem.version != remoteItem.version &&
            localItem.timestamp != remoteItem.timestamp) {
          // Version or timestamp mismatch indicates conflict
          conflicts.add(
            DataConflict<T>(
              key: key,
              localData: localItem,
              remoteData: remoteItem,
              strategy: ConflictResolutionStrategy.manual,
            ),
          );
        }
      }
    }

    return conflicts;
  }

  /// Removes conflicted items from local changes map
  Map<String, SyncData<T>> _removeConflictedItems(
    Map<String, SyncData<T>> localChanges,
    List<DataConflict<T>> conflicts,
  ) {
    final cleanChanges = Map<String, SyncData<T>>.from(localChanges);
    for (final conflict in conflicts) {
      cleanChanges.remove(conflict.key);
    }
    return cleanChanges;
  }

  /// Pushes local changes to remote
  Future<void> _pushLocalChanges(Map<String, SyncData<T>> localChanges) async {
    _eventController.add(
      SynqEvent<T>.cloudSyncStart(
        key: '__cloud_sync__',
        metadata: {'localChangesCount': localChanges.length},
      ),
    );

    try {
      final result =
          await cloudSyncFunction(localChanges, config.customHeaders);

      if (result.success) {
        _eventController.add(
          SynqEvent<T>.cloudSyncSuccess(
            key: '__cloud_sync__',
            metadata: {
              'remoteDataCount': result.remoteData.length,
              'syncMetadata': result.metadata,
            },
          ),
        );
      } else {
        final error =
            result.error ?? Exception('Sync failed without specific error');
        _eventController.add(
          SynqEvent<T>.cloudSyncError(
            key: '__cloud_sync__',
            error: error,
            metadata: {
              'operation': 'cloudSyncFunction',
              'syncMetadata': result.metadata,
            },
          ),
        );
        throw error;
      }
    } catch (error) {
      _eventController.add(
        SynqEvent<T>.cloudSyncError(
          key: '__cloud_sync__',
          error: error,
          metadata: const {'operation': 'cloudSyncFunction'},
        ),
      );
      rethrow;
    }
  }

  /// Clears processed changes from pending queue
  void _clearProcessedChanges(
    Map<String, SyncData<T>> localChanges,
    List<DataConflict<T>> conflicts,
  ) {
    // Remove successfully processed items from pending changes
    final conflictKeys = conflicts.map((c) => c.key).toSet();
    for (final key in localChanges.keys) {
      if (!conflictKeys.contains(key)) {
        _pendingChanges.remove(key);
      }
    }
  }

  /// Processes remote data, excluding conflicted items
  Future<void> _processRemoteData(
    Map<String, SyncData<T>> remoteData,
    List<DataConflict<T>> conflicts,
  ) async {
    final conflictKeys = conflicts.map((c) => c.key).toSet();

    for (final entry in remoteData.entries) {
      final key = entry.key;
      final remoteItem = entry.value;

      // Skip conflicted items - they will be handled separately
      if (conflictKeys.contains(key)) {
        continue;
      }

      final localItem = await storageService.get(key);

      if (localItem == null) {
        // New item from remote
        await storageService.put(
          key,
          remoteItem.value!,
          metadata: remoteItem.metadata,
        );
      } else if (localItem.version < remoteItem.version) {
        // Remote is newer
        if (remoteItem.deleted) {
          await storageService.delete(key);
        } else {
          await storageService.update(
            key,
            remoteItem.value!,
            metadata: remoteItem.metadata,
          );
        }
      } else if (localItem.version > remoteItem.version) {
        // Local is newer - no action needed
        continue;
      } else {
        // Same version, check timestamps
        if (remoteItem.timestamp > localItem.timestamp) {
          if (remoteItem.deleted) {
            await storageService.delete(key);
          } else {
            await storageService.update(
              key,
              remoteItem.value!,
              metadata: remoteItem.metadata,
            );
          }
        }
      }
    }
  }

  /// Handles synchronization conflicts
  Future<void> _handleConflicts(List<DataConflict<T>> conflicts) async {
    for (final conflict in conflicts) {
      if (config.enableConflictResolution) {
        try {
          final resolution = conflict.resolve();

          if (resolution.isResolved && resolution.resolvedData != null) {
            // Apply resolved data
            await storageService.put(
              conflict.key,
              resolution.resolvedData!.value!,
              metadata: resolution.resolvedData!.metadata,
            );

            _eventController.add(
              SynqEvent<T>(
                type: SynqEventType.conflictResolved,
                key: conflict.key,
                data: resolution.resolvedData!,
              ),
            );
          } else {
            // Manual resolution required
            _activeConflicts[conflict.key] = conflict;

            _eventController.add(
              SynqEvent<T>.conflict(
                key: conflict.key,
                data: conflict.localData,
              ),
            );
          }
        } catch (error) {
          // Conflict resolution failed
          _activeConflicts[conflict.key] = conflict;

          _eventController.add(
            SynqEvent<T>.conflict(
              key: conflict.key,
              data: conflict.localData,
            ),
          );
        }
      } else {
        // Store conflict for manual resolution
        _activeConflicts[conflict.key] = conflict;

        _eventController.add(
          SynqEvent<T>.conflict(
            key: conflict.key,
            data: conflict.localData,
          ),
        );
      }
    }
  }

  /// Manually resolves a conflict
  Future<void> resolveConflict(
    String key,
    ConflictResolutionStrategy strategy, {
    SyncData<T> Function(SyncData<T>, SyncData<T>)? customResolver,
  }) async {
    final conflict = _activeConflicts[key];
    if (conflict == null) {
      throw ArgumentError('No active conflict found for key: $key');
    }

    try {
      final updatedConflict = conflict.copyWith(
        strategy: strategy,
        customResolver: customResolver,
      );

      final resolution = updatedConflict.resolve();

      if (resolution.isResolved && resolution.resolvedData != null) {
        // Apply resolved data
        await storageService.put(
          key,
          resolution.resolvedData!.value!,
          metadata: resolution.resolvedData!.metadata,
        );

        // Remove from active conflicts
        _activeConflicts.remove(key);

        _eventController.add(
          SynqEvent<T>(
            type: SynqEventType.conflictResolved,
            key: key,
            data: resolution.resolvedData!,
          ),
        );
      } else {
        throw StateError('Failed to resolve conflict for key: $key');
      }
    } catch (error) {
      _eventController.add(
        SynqEvent<T>.syncError(
          key: key,
          error: error,
        ),
      );
      rethrow;
    }
  }

  /// Schedules a retry for failed sync operations
  Future<void> _scheduleRetry() async {
    for (var attempt = 1; attempt <= config.retryAttempts; attempt++) {
      final delay = Duration(
        milliseconds:
            config.retryDelay.inMilliseconds * pow(2, attempt - 1).toInt(),
      );

      await Future<void>.delayed(delay);

      if (_connectivityStatus == ConnectivityStatus.online) {
        try {
          await _performSync();
          return; // Success, no more retries needed
        } catch (error) {
          if (attempt == config.retryAttempts) {
            // Final attempt failed
            _eventController.add(
              SynqEvent<T>.syncError(
                key: '__retry_failed__',
                error: error,
              ),
            );
          }
        }
      }
    }
  }

  /// Forces a sync of specific keys
  Future<void> syncKeys(List<String> keys) async {
    if (_isSyncing) return;

    _pendingChanges.addAll(keys.where((k) => !_pendingChanges.contains(k)));
    await _performSync();
  }

  /// Gets sync statistics
  SyncStats getStats() {
    return SyncStats(
      lastSyncTimestamp: _lastSyncTimestamp,
      pendingChangesCount: _pendingChanges.length,
      activeConflictsCount: _activeConflicts.length,
      connectivityStatus: _connectivityStatus,
      isSyncing: _isSyncing,
    );
  }

  /// Closes the sync service and releases resources
  Future<void> close() async {
    _syncTimer?.cancel();
    _syncTimer = null;

    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;

    if (config.enableBackgroundSync) {
      await Workmanager()
          .cancelByUniqueName('sync_task_${storageService.boxName}');
    }

    _metadataBox?.close();
    await _eventController.close();
  }
}

/// Statistics about sync operations
class SyncStats {
  const SyncStats({
    required this.lastSyncTimestamp,
    required this.pendingChangesCount,
    required this.activeConflictsCount,
    required this.connectivityStatus,
    required this.isSyncing,
  });

  /// Timestamp of last successful sync
  final int lastSyncTimestamp;

  /// Number of pending changes
  final int pendingChangesCount;

  /// Number of active conflicts
  final int activeConflictsCount;

  /// Current connectivity status
  final ConnectivityStatus connectivityStatus;

  /// Whether sync is currently in progress
  final bool isSyncing;

  /// Time since last sync
  Duration get timeSinceLastSync {
    if (lastSyncTimestamp == 0) return Duration.zero;
    return Duration(
      milliseconds: DateTime.now().millisecondsSinceEpoch - lastSyncTimestamp,
    );
  }

  @override
  String toString() {
    return 'SyncStats(lastSync: '
        '${DateTime.fromMillisecondsSinceEpoch(lastSyncTimestamp)}, '
        'pending: $pendingChangesCount, conflicts: $activeConflictsCount, '
        'status: $connectivityStatus, syncing: $isSyncing)';
  }
}

/// Background task callback dispatcher
@pragma('vm:entry-point')
void _callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      // This would need to be implemented based on specific requirements
      // For now, we'll return success
      return Future.value(true);
    } catch (error) {
      return Future.value(false);
    }
  });
}
