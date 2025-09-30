// ignore_for_file: require_trailing_commas

import 'dart:async';

import 'package:synq_manager/synq_manager.dart';

/// Main singleton manager for synchronization operations
class SynqManager<T extends DocumentSerializable> {
  SynqManager._({
    required this.instanceName,
    required this.storageService,
    required this.syncService,
  });

  /// Instance name for this manager
  final String instanceName;

  /// Storage service for local operations
  final StorageService<T> storageService;

  /// Sync service for cloud operations
  final SyncService<T> syncService;

  /// Static instances cache
  static final Map<String, SynqManager<dynamic>> _instances = {};

  /// Stream controller for unified events
  final StreamController<SynqEvent<T>> _eventController =
      StreamController<SynqEvent<T>>.broadcast();

  /// Subscriptions to underlying services
  StreamSubscription<SynqEvent<T>>? _syncSubscription;

  /// Whether the manager is initialized
  bool _isInitialized = false;

  /// Socket.io style event listeners instances
  final Map<String, SynqListeners<T>> _listenerInstances = {};

  Map<String, SynqListeners<T>> get listenerInstances =>
      Map.unmodifiable(_listenerInstances);

  /// Creates or retrieves a SynqManager instance
  ///
  /// [instanceName] - Unique name for this manager instance
  /// [config] - Configuration for synchronization
  /// [cloudSyncFunction] - Function to push data to cloud
  /// [cloudFetchFunction] - Function to fetch data from cloud
  /// [fromJson] - Function to deserialize T from JSON
  /// [toJson] - Function to serialize T to JSON
  static Future<SynqManager<T>> getInstance<T extends DocumentSerializable>({
    required String instanceName,
    required CloudSyncFunction<T> cloudSyncFunction,
    required CloudFetchFunction<T> cloudFetchFunction,
    SyncConfig? config,
    FromJsonFunction<T>? fromJson,
    ToJsonFunction<T>? toJson,
    String? userId,
  }) async {
    final key = '${instanceName}_$T';

    if (_instances.containsKey(key)) {
      final existing = _instances[key]! as SynqManager<T>;
      if (existing._isInitialized) {
        return existing;
      }
    }

    // Create new instance
    final finalConfig = config ?? const SyncConfig();

    final storageService = await StorageService.create<T>(
      boxName: instanceName,
      encryptionKey: finalConfig.encryptionKey,
      maxSizeMiB: finalConfig.maxStorageSize,
      fromJson: fromJson,
      toJson: toJson,
    );

    final syncService = await SyncService.create<T>(
      storageService: storageService,
      config: finalConfig,
      cloudSyncFunction: cloudSyncFunction,
      cloudFetchFunction: cloudFetchFunction,
    );

    final manager = SynqManager<T>._(
      instanceName: instanceName,
      storageService: storageService,
      syncService: syncService,
    );

    await manager._initialize();
    _instances[key] = manager;

    return manager;
  }

  /// Initializes the manager
  Future<void> _initialize() async {
    try {
      _syncSubscription = syncService.events.listen(
        _eventController.add,
        onError: (Object error) => _eventController.add(
          SynqEvent<T>.syncError(key: '__sync__', error: error),
        ),
      );

      _isInitialized = true;

      _eventController.add(
        SynqEvent<T>(
          data: SyncData<T>.empty(),
          type: SynqEventType.connected,
          key: '__manager_ready__',
          timestamp: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    } catch (error) {
      _eventController.add(
        SynqEvent<T>.syncError(
          key: '__manager_init__',
          error: error,
        ),
      );
      rethrow;
    }
  }

  /// Stream of all events from this manager
  Stream<SynqEvent<T>> get events => _eventController.stream;

  /// Stream of events filtered by type
  Stream<SynqEvent<T>> onEvent(SynqEventType type) {
    return events.where((event) => event.type == type);
  }

  /// Stream of data events (create, update, delete)
  Stream<SynqEvent<T>> get onData => events.where(
        (event) =>
            event.type == SynqEventType.create ||
            event.type == SynqEventType.update ||
            event.type == SynqEventType.delete,
      );

  /// Stream of error events
  Stream<SynqEvent<T>> get onError => onEvent(SynqEventType.syncError);

  /// Stream of sync completion events
  Stream<SynqEvent<T>> get onDone => onEvent(SynqEventType.syncComplete);

  /// Stream of conflict events
  Stream<SynqEvent<T>> get onConflict => onEvent(SynqEventType.conflict);

  /// Stream of connection events
  Stream<SynqEvent<T>> get onConnected => onEvent(SynqEventType.connected);

  /// Stream of disconnection events
  Stream<SynqEvent<T>> get onDisconnected =>
      onEvent(SynqEventType.disconnected);

  /// Whether the manager is ready for operations
  bool get isReady => _isInitialized && storageService.isReady;

  /// Current connectivity status
  ConnectivityStatus get connectivityStatus => syncService.connectivityStatus;

  /// Whether sync is currently in progress
  bool get isSyncing => syncService.isSyncing;

  /// Number of pending changes waiting for sync
  int get pendingChangesCount => syncService.pendingChangesCount;

  /// Active conflicts that need resolution
  Map<String, DataConflict<T>> get activeConflicts =>
      syncService.activeConflicts;

  /// Last sync timestamp
  int get lastSyncTimestamp => syncService.lastSyncTimestamp;

  /// Storage statistics
  Future<StorageStats> get storageStats => storageService.getStats();

  /// Sync statistics
  SyncStats get syncStats => syncService.getStats();

  // ========== LOCAL STORAGE OPERATIONS ==========

  /// Stores a value with the given key
  Future<void> put(
    String key,
    T value, {
    Map<String, dynamic>? metadata,
  }) async {
    _ensureReady();
    await storageService.put(key, value, metadata: metadata);
  }

  Future<void> add(
    T value, {
    Map<String, dynamic>? metadata,
  }) async {
    _ensureReady();
    await storageService.add(value, metadata: metadata);
  }

  /// Retrieves a value for the given key
  Future<T?> get(String key) async {
    _ensureReady();
    return storageService.getValue(key);
  }

  /// Updates an existing value
  Future<void> update(
    String key,
    T value, {
    Map<String, dynamic>? metadata,
  }) async {
    _ensureReady();
    await storageService.update(key, value, metadata: metadata);
  }

  /// Deletes a value with the given key (soft delete)
  Future<bool> delete(String key) async {
    _ensureReady();
    return storageService.delete(key);
  }

  /// Permanently deletes a value with the given key (hard delete)
  /// Warning: This bypasses sync and removes the item immediately
  Future<bool> hardDelete(String key) async {
    _ensureReady();
    return storageService.hardDelete(key);
  }

  /// Retrieves all active values
  Future<Map<String, T>> getAll() async {
    _ensureReady();
    return storageService.getAllValues();
  }

  /// Stores multiple key-value pairs
  Future<void> putAll(
    Map<String, T> entries, {
    Map<String, dynamic>? metadata,
  }) async {
    _ensureReady();
    await storageService.putAll(entries, metadata: metadata);
  }

  /// Clears all data
  Future<void> clear() async {
    _ensureReady();
    await storageService.clear();
  }

  /// Gets all keys
  List<String> get keys {
    _ensureReady();
    return storageService.keys;
  }

  /// Checks if a key exists
  Future<bool> containsKey(String key) async {
    _ensureReady();
    final value = await get(key);
    return value != null;
  }

  /// Number of items in storage
  int get length {
    _ensureReady();
    return storageService.length;
  }

  /// Whether storage is empty
  bool get isEmpty {
    _ensureReady();
    return storageService.isEmpty;
  }

  /// Whether storage is not empty
  bool get isNotEmpty {
    _ensureReady();
    return storageService.isNotEmpty;
  }

  // ========== SYNCHRONIZATION OPERATIONS ==========

  /// Manually triggers synchronization
  Future<void> sync() async {
    _ensureReady();
    await syncService.sync();
  }

  /// Syncs specific keys
  Future<void> syncKeys(List<String> keys) async {
    _ensureReady();
    await syncService.syncKeys(keys);
  }

  /// Resolves a conflict manually
  Future<void> resolveConflict(
    String key,
    ConflictResolutionStrategy strategy, {
    SyncData<T> Function(SyncData<T>, SyncData<T>)? customResolver,
  }) async {
    _ensureReady();
    await syncService.resolveConflict(
      key,
      strategy,
      customResolver: customResolver,
    );
  }

  // ========== UTILITY METHODS ==========

  /// Compacts storage to optimize space usage
  Future<void> compact() async {
    _ensureReady();
    await storageService.compact();
  }

  /// Stream of changes for a specific key
  Stream<SynqEvent<T>> watchKey(String key) {
    return events.where((event) => event.key == key);
  }

  /// Stream of changes for multiple keys
  Stream<SynqEvent<T>> watchKeys(List<String> keys) {
    return events.where((event) => keys.contains(event.key));
  }

  /// Gets detailed sync data for a key (including metadata, version, etc.)
  Future<SyncData<T>?> getSyncData(String key) async {
    _ensureReady();
    return storageService.get(key);
  }

  /// Gets items modified since a specific timestamp
  Future<Map<String, SyncData<T>>> getModifiedSince(int timestamp) async {
    _ensureReady();
    return storageService.getModifiedSince(timestamp);
  }

  /// Checks if the manager is ready for operations
  void _ensureReady() {
    if (!isReady) {
      throw StateError('SynqManager is not ready. Call getInstance() first.');
    }
  }

  // ========== SOCKET.IO STYLE API ==========

  /// Creates a new SynqListeners instance for fluent API
  SynqListeners<T> on() {
    final listenerId = DateTime.now().millisecondsSinceEpoch.toString();
    final listeners = SynqListeners<T>(this);
    _listenerInstances[listenerId] = listeners;
    return listeners;
  }

  /// Socket.io style onInit - called when manager is ready with all data
  SynqListeners<T> onInit(void Function(Map<String, T> data) callback) {
    return on().onInit(callback);
  }

  /// Socket.io style onCreate - called when new data is created
  SynqListeners<T> onCreate(void Function(String key, T data) callback) {
    return on().onCreate(callback);
  }

  /// Socket.io style onUpdate - called when data is updated
  SynqListeners<T> onUpdate(void Function(String key, T data) callback) {
    return on().onUpdate(callback);
  }

  /// Socket.io style onDelete - called when data is deleted
  SynqListeners<T> onDelete(void Function(String key) callback) {
    return on().onDelete(callback);
  }

  /// Socket.io style onEvent - called for all events
  SynqListeners<T> onEventCallback(void Function(SynqEvent<T> event) callback) {
    return on().onEvent(callback);
  }

  /// Socket.io style onError - called when errors occur
  SynqListeners<T> onErrorCallback(void Function(Object error) callback) {
    return on().onError(callback);
  }

  // ========== LIFECYCLE MANAGEMENT ==========

  /// Closes the manager and releases all resources
  Future<void> close() async {
    await _syncSubscription?.cancel();

    await syncService.close();
    await storageService.close();

    await _eventController.close();

    _instances.remove('${instanceName}_$T');
    _isInitialized = false;
  }

  /// Closes all manager instances
  static Future<void> closeAll() async {
    final futures = <Future<void>>[];

    for (final instance in _instances.values) {
      futures.add(instance.close());
    }

    await Future.wait(futures);
    _instances.clear();
  }

  /// Gets all active manager instances
  static Map<String, SynqManager<dynamic>> get instances =>
      Map.unmodifiable(_instances);

  @override
  String toString() {
    return 'SynqManager<$T>(name: $instanceName, ready: $isReady, '
        'syncing: $isSyncing, items: $length)';
  }
}
