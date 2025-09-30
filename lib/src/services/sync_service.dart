import 'dart:async';
import 'dart:math' as math;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive_plus_secure/hive_plus_secure.dart';
import 'package:synq_manager/src/events/event_types.dart';
import 'package:synq_manager/src/models/cloud_callbacks.dart';
import 'package:synq_manager/src/models/conflict_resolution.dart';
import 'package:synq_manager/src/models/sync_config.dart';
import 'package:synq_manager/src/models/sync_data.dart';
import 'package:synq_manager/src/models/sync_event.dart';
import 'package:synq_manager/src/models/sync_result.dart';
import 'package:synq_manager/src/models/sync_stats.dart';
import 'package:synq_manager/src/services/storage_service.dart';
import 'package:workmanager/workmanager.dart';

/// Orchestrates synchronization between local storage and cloud backend.
///
/// This service handles:
/// - Bidirectional sync with conflict detection and resolution
/// - Automatic retry with exponential backoff
/// - Network connectivity monitoring
/// - Background sync scheduling
/// - User account migration scenarios
class SyncService<T extends DocumentSerializable> {
  SyncService._({
    required this.storageService,
    required this.config,
    required this.cloudSyncFunction,
    required this.cloudFetchFunction,
  });

  final StorageService<T> storageService;
  final SyncConfig config;
  final CloudSyncFunction<T> cloudSyncFunction;
  final CloudFetchFunction<T> cloudFetchFunction;

  // Event broadcasting
  final _eventController = StreamController<SynqEvent<T>>.broadcast();
  Stream<SynqEvent<T>> get events => _eventController.stream;

  // Connectivity monitoring
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  ConnectivityStatus _connectivityStatus = ConnectivityStatus.unknown;
  ConnectivityStatus get connectivityStatus => _connectivityStatus;

  // Sync state management
  Timer? _syncTimer;
  bool _isSyncing = false;
  bool _isDisposed = false;
  bool get isSyncing => _isSyncing;

  // Change tracking
  final _pendingChanges = <String>{};
  int get pendingChangesCount => _pendingChanges.length;

  // Conflict tracking
  final _activeConflicts = <String, DataConflict<T>>{};
  Map<String, DataConflict<T>> get activeConflicts =>
      Map.unmodifiable(_activeConflicts);

  // Persistent metadata storage
  Box<String>? _metadataBox;
  static const _syncTimestampKey = '__sync_timestamp__';
  static const _userIdKey = '__user_id__';

  int get lastSyncTimestamp => _getTimestamp();
  String? get _storedUserId => _metadataBox?.get(_userIdKey);

  /// Creates and initializes a new sync service instance.
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

  /// Initializes all service components in a controlled sequence.
  Future<void> _initialize() async {
    try {
      await _initializeMetadataBox();
      _startConnectivityMonitoring();
      _startStorageMonitoring();
      _scheduleSyncTimer();

      if (config.enableBackgroundSync) {
        await _registerBackgroundSync();
      }

      _emitEvent(SynqEvent<T>.connected());
    } catch (error, stackTrace) {
      _emitError('initialization', error, stackTrace);
      rethrow;
    }
  }

  /// Opens the metadata box for storing sync timestamps and user IDs.
  Future<void> _initializeMetadataBox() async {
    final boxName = '${storageService.boxName}_sync_metadata';
    _metadataBox = Hive.box<String>(
      name: boxName,
      encryptionKey: config.encryptionKey,
    );
  }

  /// Starts monitoring network connectivity changes.
  void _startConnectivityMonitoring() {
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen(_handleConnectivityChange, onError: _handleConnectivityError);
  }

  /// Handles changes in network connectivity.
  void _handleConnectivityChange(ConnectivityResult result) {
    final previousStatus = _connectivityStatus;
    _connectivityStatus = _mapConnectivity(result);

    if (_hasConnectivityRestored(previousStatus)) {
      _emitEvent(SynqEvent<T>.connected());
      _triggerSync();
    } else if (_connectivityStatus == ConnectivityStatus.offline) {
      _emitEvent(SynqEvent<T>.disconnected());
    }
  }

  /// Determines if connectivity was restored.
  bool _hasConnectivityRestored(ConnectivityStatus previous) {
    return previous == ConnectivityStatus.offline &&
        _connectivityStatus == ConnectivityStatus.online;
  }

  /// Maps connectivity result to internal status enum.
  ConnectivityStatus _mapConnectivity(ConnectivityResult result) {
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

  /// Handles connectivity monitoring errors.
  void _handleConnectivityError(Object error, StackTrace stackTrace) {
    _emitError('connectivity_monitoring', error, stackTrace);
  }

  /// Starts monitoring storage events for change tracking.
  void _startStorageMonitoring() {
    storageService.events.listen(
      _handleStorageEvent,
      onError: (error, stackTrace) =>
          _emitError('storage_monitoring', error, stackTrace),
    );
  }

  /// Handles storage events and tracks changes for sync.
  void _handleStorageEvent(SynqEvent<T> event) {
    _eventController.add(event);

    if (_isChangeEvent(event)) {
      _trackChange(event.key);
    }
  }

  /// Determines if an event represents a data change.
  bool _isChangeEvent(SynqEvent<T> event) {
    return event.type == SynqEventType.create ||
        event.type == SynqEventType.update ||
        event.type == SynqEventType.delete;
  }

  /// Tracks a key for synchronization and triggers immediate sync if needed.
  void _trackChange(String key) {
    _pendingChanges.add(key);

    if (_shouldSyncImmediately()) {
      _triggerSync();
    }
  }

  /// Determines if changes should trigger immediate sync.
  bool _shouldSyncImmediately() {
    return config.priority == SyncPriority.high ||
        config.priority == SyncPriority.critical;
  }

  /// Schedules periodic sync operations.
  void _scheduleSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(config.syncInterval, (_) {
      if (_canSync()) {
        _triggerSync();
      }
    });
  }

  /// Checks if sync can be performed.
  bool _canSync() {
    return _connectivityStatus == ConnectivityStatus.online && !_isSyncing;
  }

  /// Triggers a sync operation asynchronously without awaiting.
  void _triggerSync() {
    unawaited(_performSync());
  }

  /// Registers background sync with WorkManager.
  Future<void> _registerBackgroundSync() async {
    try {
      await Workmanager().initialize(_callbackDispatcher);

      await Workmanager().registerPeriodicTask(
        'sync_${storageService.boxName}',
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
    } catch (error, stackTrace) {
      _emitError('background_sync_registration', error, stackTrace);
    }
  }

  /// Manually triggers a synchronization operation.
  Future<void> sync() => _performSync();

  /// Forces synchronization of specific keys.
  Future<void> syncKeys(List<String> keys) async {
    if (_isSyncing) return;

    _pendingChanges.addAll(keys);
    await _performSync();
  }

  /// Performs the complete synchronization workflow.
  Future<void> _performSync() async {
    if (!_canPerformSync()) return;

    _isSyncing = true;
    _emitEvent(SynqEvent<T>.syncStart(key: '__sync__'));

    try {
      await _executeSync();
      await _persistSyncTimestamp();
      _emitEvent(SynqEvent<T>.syncComplete(key: '__sync__'));
    } catch (error, stackTrace) {
      _handleSyncError(error, stackTrace);
    } finally {
      _isSyncing = false;
    }
  }

  /// Checks if sync can proceed.
  bool _canPerformSync() {
    return !_isSyncing &&
        !_isDisposed &&
        _connectivityStatus == ConnectivityStatus.online;
  }

  /// Executes the appropriate sync strategy based on sync history.
  Future<void> _executeSync() async {
    if (_getTimestamp() == 0) {
      await _performInitialSync();
    } else {
      await _performIncrementalSync();
    }
  }

  /// Handles sync errors and schedules retry if enabled.
  void _handleSyncError(Object error, StackTrace stackTrace) {
    _emitError('sync', error, stackTrace);

    if (config.enableAutoRetry) {
      _scheduleRetry();
    }
  }

  /// Performs initial synchronization for first-time sync.
  ///
  /// Strategy:
  /// 1. Fetch all remote data
  /// 2. Get all local data
  /// 3. Detect conflicts between local and remote
  /// 4. Push non-conflicted local data
  /// 5. Apply non-conflicted remote data (excluding pushed items)
  /// 6. Handle conflicts according to strategy
  Future<void> _performInitialSync() async {
    final remoteResponse = await _fetchFromCloud();
    final localData = await storageService.getAll();

    final conflicts = _detectConflicts(localData, remoteResponse.data);
    final cleanLocal = _removeConflicts(localData, conflicts);
    final pushedKeys = <String>{};

    if (cleanLocal.isNotEmpty) {
      await _pushToCloud(cleanLocal);
      pushedKeys.addAll(cleanLocal.keys);
    }

    await _applyRemoteChanges(remoteResponse.data, conflicts,
        excludeKeys: pushedKeys);
    await _resolveConflicts(conflicts);

    _pendingChanges.clear();
  }

  /// Performs incremental synchronization for subsequent syncs.
  ///
  /// Strategy:
  /// 1. Fetch remote changes since last sync
  /// 2. Get local changes since last sync
  /// 3. Detect conflicts
  /// 4. Push non-conflicted local changes
  /// 5. Apply non-conflicted remote changes (excluding pushed items)
  /// 6. Handle conflicts
  Future<void> _performIncrementalSync() async {
    final remoteResponse = await _fetchFromCloud();
    final localChanges = await _gatherPendingChanges();

    final conflicts = _detectConflicts(localChanges, remoteResponse.data);
    final pushedKeys = <String>{};

    if (localChanges.isNotEmpty) {
      final cleanLocal = _removeConflicts(localChanges, conflicts);
      if (cleanLocal.isNotEmpty) {
        await _pushToCloud(cleanLocal);
        // Track which keys were successfully pushed
        pushedKeys.addAll(cleanLocal.keys);
      }
    }

    // Apply remote changes but exclude items we just pushed
    await _applyRemoteChanges(remoteResponse.data, conflicts,
        excludeKeys: pushedKeys);
    await _resolveConflicts(conflicts);

    _clearProcessedChanges(localChanges, conflicts);
  }

  /// Gathers all pending local changes for synchronization.
  Future<Map<String, SyncData<T>>> _gatherPendingChanges() async {
    final changes = <String, SyncData<T>>{};

    // First pass: explicitly tracked changes
    await _collectTrackedChanges(changes);

    // Second pass: scan for untracked changes if nothing tracked
    if (changes.isEmpty) {
      await _scanForUntrackedChanges(changes);
    }

    return changes;
  }

  /// Collects explicitly tracked pending changes.
  Future<void> _collectTrackedChanges(Map<String, SyncData<T>> changes) async {
    final keysToRemove = <String>[];

    for (final key in _pendingChanges) {
      final data = await storageService.get(key);
      if (data != null) {
        changes[key] = data;
      } else {
        keysToRemove.add(key);
      }
    }

    _pendingChanges.removeAll(keysToRemove);
  }

  /// Scans storage for changes newer than last sync timestamp.
  Future<void> _scanForUntrackedChanges(
      Map<String, SyncData<T>> changes) async {
    if (_getTimestamp() == 0) return;

    final allData = await storageService.getAll();
    final threshold = _getTimestamp();

    for (final entry in allData.entries) {
      if (entry.value.timestamp > threshold + 1000) {
        changes[entry.key] = entry.value;
        _pendingChanges.add(entry.key);
      }
    }
  }

  /// Fetches remote updates from cloud storage.
  Future<CloudFetchResponse<T>> _fetchFromCloud() async {
    _emitEvent(SynqEvent<T>.cloudFetchStart(key: '__cloud_fetch__'));

    try {
      final response = await cloudFetchFunction(
        _getTimestamp(),
        config.customHeaders,
      );

      _emitCloudFetchSuccess(response);
      await _handleUserAccountMigration(response);

      return response;
    } catch (error, stackTrace) {
      _emitCloudFetchError(error, stackTrace);
      rethrow;
    }
  }

  /// Emits cloud fetch success event with metadata.
  void _emitCloudFetchSuccess(CloudFetchResponse<T> response) {
    _emitEvent(SynqEvent<T>.cloudFetchSuccess(
      key: '__cloud_fetch__',
      metadata: {
        'remoteDataCount': response.data.length,
        'cloudUserId': response.cloudUserId,
        'cloudMetadata': response.metadata,
      },
    ));
  }

  /// Emits cloud fetch error event.
  void _emitCloudFetchError(Object error, StackTrace stackTrace) {
    _emitEvent(SynqEvent<T>.cloudFetchError(
      key: '__cloud_fetch__',
      error: error,
      metadata: {'operation': 'cloudFetchFunction'},
    ));
  }

  /// Handles user account migration scenarios.
  ///
  /// Scenarios handled:
  /// 1. Guest user signs in → Accept cloud data
  /// 2. User creates data offline → Push to cloud
  /// 3. User switches accounts → Ask user preference
  /// 4. Same user continues → Normal sync
  Future<void> _handleUserAccountMigration(
      CloudFetchResponse<T> response) async {
    final scenario = await _analyzeAccountScenario(response);

    switch (scenario) {
      case _AccountScenario.guestSignIn:
        await _acceptCloudData(response);
        break;

      case _AccountScenario.offlineDataUpload:
        await _uploadLocalData();
        break;

      case _AccountScenario.accountSwitch:
        await _resolveAccountConflict(response);
        break;

      case _AccountScenario.normalSync:
        // Continue with normal sync
        break;
    }
  }

  /// Analyzes the account migration scenario.
  Future<_AccountScenario> _analyzeAccountScenario(
    CloudFetchResponse<T> response,
  ) async {
    final hasLocal = (await storageService.getAll()).isNotEmpty;
    final hasCloud = response.hasData;
    final cloudUserId = response.cloudUserId;

    // No stored user, no local data, cloud has user and data
    if (_storedUserId == null && !hasLocal && cloudUserId != null && hasCloud) {
      return _AccountScenario.guestSignIn;
    }

    // No stored user, has local data, no cloud data
    if (_storedUserId == null && hasLocal && !hasCloud) {
      return _AccountScenario.offlineDataUpload;
    }

    // Different users with data on both sides
    if (_storedUserId != null &&
        cloudUserId != null &&
        _storedUserId != cloudUserId &&
        hasLocal &&
        hasCloud) {
      return _AccountScenario.accountSwitch;
    }

    // Has stored user, has local data,
    // different cloud user, no cloud data
    if (_storedUserId != null &&
        hasLocal &&
        cloudUserId != null &&
        _storedUserId != cloudUserId &&
        !hasCloud) {
      return _AccountScenario.offlineDataUpload;
    }

    return _AccountScenario.normalSync;
  }

  /// Accepts cloud data and discards local data (guest sign-in scenario).
  Future<void> _acceptCloudData(CloudFetchResponse<T> response) async {
    await storageService.clear();
    await _persistUserId(response.cloudUserId);

    for (final entry in response.data.entries) {
      if (!entry.value.deleted && entry.value.value != null) {
        await storageService.put(
          entry.key,
          entry.value.value!,
          metadata: entry.value.metadata,
        );
      }
    }
  }

  /// Uploads all local data to cloud (offline data upload scenario).
  Future<void> _uploadLocalData() async {
    final allLocal = await storageService.getAll();
    if (allLocal.isNotEmpty) {
      await _pushToCloud(allLocal);
    }
  }

  /// Resolves account conflict by asking user preference.
  Future<void> _resolveAccountConflict(CloudFetchResponse<T> response) async {
    if (config.conflictResolutionCallback == null) {
      throw StateError(
        'Account conflict detected but no resolution callback provided',
      );
    }

    final context = ConflictContext<T>(
      type: ConflictType.userAccount,
      key: '__user_account__',
      localUserId: _storedUserId,
      cloudUserId: response.cloudUserId,
      hasLocalData: (await storageService.getAll()).isNotEmpty,
      hasCloudData: response.hasData,
    );

    final action = await config.conflictResolutionCallback!(context);
    await _applyAccountAction(action, response);
  }

  /// Applies user's choice for account conflict resolution.
  Future<void> _applyAccountAction(
    ConflictAction action,
    CloudFetchResponse<T> response,
  ) async {
    switch (action) {
      case ConflictAction.useCloudData:
        await _acceptCloudData(response);
        break;

      case ConflictAction.keepLocalData:
        await _uploadLocalData();
        break;

      case ConflictAction.cancel:
        throw StateError('User cancelled sync due to account conflict');

      default:
        throw ArgumentError('Invalid action for account conflict: $action');
    }
  }

  /// Detects conflicts between local and remote data.
  List<DataConflict<T>> _detectConflicts(
    Map<String, SyncData<T>> localData,
    Map<String, SyncData<T>> remoteData,
  ) {
    final conflicts = <DataConflict<T>>[];

    for (final entry in localData.entries) {
      final key = entry.key;
      final local = entry.value;
      final remote = remoteData[key];

      if (remote != null && _hasVersionConflict(local, remote)) {
        conflicts.add(DataConflict<T>(
          key: key,
          localData: local,
          remoteData: remote,
          strategy: ConflictResolutionStrategy.manual,
        ));
      }
    }

    return conflicts;
  }

  /// Checks if two sync data items have a version conflict.
  bool _hasVersionConflict(SyncData<T> local, SyncData<T> remote) {
    return local.version != remote.version &&
        local.timestamp != remote.timestamp;
  }

  /// Removes conflicted items from the data map.
  Map<String, SyncData<T>> _removeConflicts(
    Map<String, SyncData<T>> data,
    List<DataConflict<T>> conflicts,
  ) {
    final clean = Map<String, SyncData<T>>.from(data);
    for (final conflict in conflicts) {
      clean.remove(conflict.key);
    }
    return clean;
  }

  /// Pushes local changes to cloud storage.
  Future<void> _pushToCloud(Map<String, SyncData<T>> localChanges) async {
    _emitEvent(SynqEvent<T>.cloudSyncStart(
      key: '__cloud_sync__',
      metadata: {'localChangesCount': localChanges.length},
    ));

    try {
      final result =
          await cloudSyncFunction(localChanges, config.customHeaders);

      if (!result.success) {
        final error = result.error ?? StateError('Sync failed without error');
        _emitCloudSyncError(error);
        throw error;
      }

      _emitCloudSyncSuccess(result);
      for (final key in localChanges.keys) {
        _pendingChanges.remove(key);
      }
    } catch (error) {
      _emitCloudSyncError(error);
      rethrow;
    }
  }

  /// Emits cloud sync success event.
  void _emitCloudSyncSuccess(SyncResult<T> result) {
    _emitEvent(SynqEvent<T>.cloudSyncSuccess(
      key: '__cloud_sync__',
      metadata: {
        'remoteDataCount': result.remoteData.length,
        'syncMetadata': result.metadata,
      },
    ));
  }

  /// Emits cloud sync error event.
  void _emitCloudSyncError(Object error) {
    _emitEvent(SynqEvent<T>.cloudSyncError(
      key: '__cloud_sync__',
      error: error,
      metadata: {'operation': 'cloudSyncFunction'},
    ));
  }

  /// Applies non-conflicted remote changes to local storage.
  Future<void> _applyRemoteChanges(
    Map<String, SyncData<T>> remoteData,
    List<DataConflict<T>> conflicts, {
    Set<String> excludeKeys = const {},
  }) async {
    final conflictKeys = conflicts.map((c) => c.key).toSet();

    for (final entry in remoteData.entries) {
      if (conflictKeys.contains(entry.key)) continue;
      // Skip items that were just pushed to avoid re-applying same data
      if (excludeKeys.contains(entry.key)) continue;

      await _applyRemoteItem(entry.key, entry.value);
    }
  }

  /// Applies a single remote item to local storage.
  Future<void> _applyRemoteItem(String key, SyncData<T> remote) async {
    final local = await storageService.get(key);

    if (local == null) {
      await _createFromRemote(key, remote);
    } else if (local.version < remote.version) {
      await _updateFromRemote(key, remote);
    } else if (local.version == remote.version &&
        remote.timestamp > local.timestamp) {
      await _updateFromRemote(key, remote);
    }
  }

  /// Creates a new local item from remote data.
  Future<void> _createFromRemote(String key, SyncData<T> remote) async {
    if (!remote.deleted && remote.value != null) {
      await storageService.put(
        key,
        remote.value!,
        metadata: remote.metadata,
      );
    }
  }

  /// Updates an existing local item from remote data.
  Future<void> _updateFromRemote(String key, SyncData<T> remote) async {
    if (remote.deleted) {
      await storageService.delete(key);
    } else if (remote.value != null) {
      await storageService.update(
        key,
        remote.value!,
        metadata: remote.metadata,
      );
    }
  }

  /// Resolves conflicts according to configured strategy.
  Future<void> _resolveConflicts(List<DataConflict<T>> conflicts) async {
    for (final conflict in conflicts) {
      await _resolveConflict(conflict);
    }
  }

  /// Resolves a single conflict.
  Future<void> _resolveConflict(DataConflict<T> conflict) async {
    if (!config.enableConflictResolution) {
      _storeConflictForManualResolution(conflict);
      return;
    }

    try {
      final resolution = conflict.resolve();

      if (resolution.isResolved && resolution.resolvedData != null) {
        await _applyResolution(conflict.key, resolution.resolvedData!);
      } else {
        _storeConflictForManualResolution(conflict);
      }
    } catch (error, stackTrace) {
      _emitError('conflict_resolution', error, stackTrace);
      _storeConflictForManualResolution(conflict);
    }
  }

  /// Applies a resolved conflict to storage.
  Future<void> _applyResolution(String key, SyncData<T> resolved) async {
    await storageService.put(
      key,
      resolved.value!,
      metadata: resolved.metadata,
    );

    _emitEvent(SynqEvent<T>(
      type: SynqEventType.conflictResolved,
      key: key,
      data: resolved,
    ));
  }

  /// Stores a conflict for manual resolution.
  void _storeConflictForManualResolution(DataConflict<T> conflict) {
    _activeConflicts[conflict.key] = conflict;
    _emitEvent(SynqEvent<T>.conflict(
      key: conflict.key,
      data: conflict.localData,
    ));
  }

  /// Manually resolves a conflict with a specific strategy.
  Future<void> resolveConflict(
    String key,
    ConflictResolutionStrategy strategy, {
    SyncData<T> Function(SyncData<T>, SyncData<T>)? customResolver,
  }) async {
    final conflict = _activeConflicts[key];
    if (conflict == null) {
      throw ArgumentError('No active conflict for key: $key');
    }

    final updated = conflict.copyWith(
      strategy: strategy,
      customResolver: customResolver,
    );

    final resolution = updated.resolve();
    if (!resolution.isResolved || resolution.resolvedData == null) {
      throw StateError('Failed to resolve conflict for key: $key');
    }

    await _applyResolution(key, resolution.resolvedData!);
    _activeConflicts.remove(key);
  }

  /// Clears processed changes and performs hard deletion of synced items.
  void _clearProcessedChanges(
    Map<String, SyncData<T>> localChanges,
    List<DataConflict<T>> conflicts,
  ) {
    final conflictKeys = conflicts.map((c) => c.key).toSet();
    final deletedKeys = <String>[];

    for (final entry in localChanges.entries) {
      if (!conflictKeys.contains(entry.key)) {
        _pendingChanges.remove(entry.key);

        if (entry.value.deleted) {
          deletedKeys.add(entry.key);
        }
      }
    }

    _performHardDeletion(deletedKeys);
  }

  /// Performs hard deletion of synced items asynchronously.
  void _performHardDeletion(List<String> keys) {
    if (keys.isEmpty) return;

    Future.microtask(() async {
      for (final key in keys) {
        try {
          await storageService.hardDelete(key);
        } catch (error, stackTrace) {
          _emitError('hard_delete', error, stackTrace, key: key);
        }
      }
    });
  }

  /// Schedules retry attempts with exponential backoff.
  void _scheduleRetry() {
    Future.microtask(() async {
      for (var attempt = 1; attempt <= config.retryAttempts; attempt++) {
        final delay = _calculateBackoff(attempt);
        await Future<void>.delayed(delay);

        if (!_canPerformSync()) continue;

        try {
          await _performSync();
          return; // Success - exit retry loop
        } catch (error, stackTrace) {
          if (attempt == config.retryAttempts) {
            _emitError('retry_exhausted', error, stackTrace);
          }
        }
      }
    });
  }

  /// Calculates exponential backoff delay for retry attempts.
  Duration _calculateBackoff(int attempt) {
    final multiplier = math.pow(2, attempt - 1).toInt();
    return Duration(
      milliseconds: config.retryDelay.inMilliseconds * multiplier,
    );
  }

  /// Retrieves the last sync timestamp from persistent storage.
  int _getTimestamp() {
    final value = _metadataBox?.get(_syncTimestampKey);
    return value != null ? int.tryParse(value) ?? 0 : 0;
  }

  /// Persists the current timestamp as the last successful sync time.
  Future<void> _persistSyncTimestamp() async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _metadataBox?.put(_syncTimestampKey, timestamp.toString());
      _pendingChanges.clear();
    } catch (error, stackTrace) {
      _emitError('persist_timestamp', error, stackTrace);
      // Don't rethrow - sync should continue despite timestamp persistence failure
    }
  }

  /// Persists user ID to storage.
  Future<void> _persistUserId(String? userId) async {
    if (userId == null) return;

    try {
      _metadataBox?.put(_userIdKey, userId);
    } catch (error, stackTrace) {
      _emitError('persist_user_id', error, stackTrace);
    }
  }

  /// Returns current synchronization statistics.
  SyncStats getStats() {
    return SyncStats(
      lastSyncTimestamp: _getTimestamp(),
      pendingChangesCount: _pendingChanges.length,
      activeConflictsCount: _activeConflicts.length,
      connectivityStatus: _connectivityStatus,
      isSyncing: _isSyncing,
    );
  }

  /// Emits a sync event to listeners.
  void _emitEvent(SynqEvent<T> event) {
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
  }

  /// Emits an error event with standardized metadata.
  void _emitError(
    String operation,
    Object error,
    StackTrace stackTrace, {
    String? key,
  }) {
    if (_eventController.isClosed) return;

    _eventController.add(SynqEvent<T>.syncError(
      key: key ?? '__$operation\__',
      error: error,
      metadata: {
        'operation': operation,
        'stackTrace': stackTrace.toString(),
      },
    ));
  }

  /// Releases all resources and cancels ongoing operations.
  Future<void> close() async {
    if (_isDisposed) return;
    _isDisposed = true;

    _syncTimer?.cancel();
    _syncTimer = null;

    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;

    if (config.enableBackgroundSync) {
      await _cancelBackgroundSync();
    }

    _metadataBox?.close();
    await _eventController.close();
  }

  /// Cancels background sync task.
  Future<void> _cancelBackgroundSync() async {
    try {
      await Workmanager().cancelByUniqueName('sync_${storageService.boxName}');
    } catch (error, stackTrace) {
      // Log but don't throw - we're already disposing
      _emitError('cancel_background_sync', error, stackTrace);
    }
  }
}

/// Internal enum for account migration scenarios.
enum _AccountScenario {
  /// Guest user signing in with cloud data
  guestSignIn,

  /// User uploading offline-created data
  offlineDataUpload,

  /// User switching between different accounts
  accountSwitch,

  /// Normal sync between same user's devices
  normalSync,
}

/// Background task callback dispatcher for WorkManager.
@pragma('vm:entry-point')
void _callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    // Background sync implementation would go here
    // This would need to reconstruct the sync service and execute sync
    // For now, return success as a placeholder
    try {
      // TODO: Implement background sync logic
      // 1. Initialize Hive
      // 2. Reconstruct storage service
      // 3. Execute sync
      return true;
    } catch (error) {
      return false;
    }
  });
}
