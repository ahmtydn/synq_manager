// ignore_for_file: require_trailing_commas

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive_plus_secure/hive_plus_secure.dart';
import 'package:synq_manager/src/events/event_types.dart';
import 'package:synq_manager/src/models/conflict_resolution.dart';
import 'package:synq_manager/src/models/sync_config.dart';
import 'package:synq_manager/src/models/sync_data.dart';
import 'package:synq_manager/src/models/sync_event.dart';
import 'package:synq_manager/src/services/storage_service.dart';
import 'package:synq_manager/src/services/sync_service.dart';

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

/// Extension methods for easier usage patterns
extension SynqManagerExtensions<T extends DocumentSerializable>
    on SynqManager<T> {
  /// Puts a value and waits for sync completion
  Future<void> putAndSync(
    String key,
    T value, {
    Map<String, dynamic>? metadata,
  }) async {
    await put(key, value, metadata: metadata);
    await sync();
  }

  /// Updates a value and waits for sync completion
  Future<void> updateAndSync(
    String key,
    T value, {
    Map<String, dynamic>? metadata,
  }) async {
    await update(key, value, metadata: metadata);
    await sync();
  }

  /// Deletes a value and waits for sync completion
  Future<bool> deleteAndSync(String key) async {
    final result = await delete(key);
    await sync();
    return result;
  }

  /// Listens to events with automatic error handling
  StreamSubscription<SynqEvent<T>> listen({
    void Function(SynqEvent<T> event)? onData,
    void Function(Object error)? onError,
    void Function()? onDone,
  }) {
    return events.listen(
      onData,
      onError: onError ??
          (Object error) {
            // Default error handling - could be customized
            debugPrint('SynqManager error: $error');
          },
      onDone: onDone,
    );
  }

  /// Waits for the next sync completion
  Future<void> waitForSync() {
    return onDone.first;
  }

  /// Waits for connectivity to be restored
  Future<void> waitForConnection() {
    if (connectivityStatus == ConnectivityStatus.online) {
      return Future.value();
    }
    return onConnected.first;
  }

  // ========== SOCKET.IO STYLE EVENT LISTENERS ==========

  /// Initialize Socket.io style listeners
  SynqListeners<T> on([String? namespace]) {
    final key = namespace ?? 'default';
    _listenerInstances[key] ??= SynqListeners<T>(this);
    return _listenerInstances[key]!;
  }

  /// Quick setup method similar to Socket.io
  ///
  /// Example:
  /// ```dart
  /// await manager.onInit((data) {
  ///   print('Initial data loaded: ${data.length} items');
  /// }).onUpdate((key, data) {
  ///   print('Data updated: $key');
  /// }).onError((error) {
  ///   print('Error occurred: $error');
  /// }).start();
  /// ```
  SynqSocketBuilder<T> onInit(void Function(Map<String, T> data) callback) {
    return SynqSocketBuilder<T>(this, callback);
  }
}

/// Socket.io style event listeners for SynqManager
class SynqListeners<T extends DocumentSerializable> {
  SynqListeners(this._manager);
  final SynqManager<T> _manager;
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  /// Listen for initial data load (when manager becomes ready)
  SynqListeners<T> onInit(void Function(Map<String, T> data) callback) {
    // Store the callback to be called manually, don't auto-subscribe to events
    // This prevents double initialization
    return this;
  }

  /// Listen for data creation events
  SynqListeners<T> onCreate(void Function(String key, T data) callback) {
    _subscriptions.add(
      _manager.onEvent(SynqEventType.create).listen((event) async {
        if (event.data.value != null) {
          callback(event.key, event.data.value!);
        }
      }),
    );
    return this;
  }

  /// Listen for data update events
  SynqListeners<T> onUpdate(void Function(String key, T data) callback) {
    _subscriptions.add(
      _manager.onEvent(SynqEventType.update).listen((event) async {
        if (event.data.value != null) {
          callback(event.key, event.data.value!);
        }
      }),
    );
    return this;
  }

  /// Listen for data delete events
  SynqListeners<T> onDelete(void Function(String key) callback) {
    _subscriptions.add(
      _manager.onEvent(SynqEventType.delete).listen((event) {
        callback(event.key);
      }),
    );
    return this;
  }

  /// Listen for any data change (create, update, delete)
  SynqListeners<T> onChange(
      void Function(String key, T? data, String action) callback) {
    _subscriptions.add(
      _manager.onData.listen((event) {
        String action;
        final value = event.data.value;

        switch (event.type) {
          case SynqEventType.create:
            action = 'create';
          case SynqEventType.update:
            action = 'update';
          case SynqEventType.delete:
            action = 'delete';
          default:
            return;
        }
        callback(event.key, value, action);
      }),
    );
    return this;
  }

  /// Listen for sync completion events
  SynqListeners<T> onSyncComplete(void Function() callback) {
    _subscriptions.add(
      _manager.onDone.listen((_) => callback()),
    );
    return this;
  }

  /// Listen for sync start events
  SynqListeners<T> onSyncStart(void Function() callback) {
    _subscriptions.add(
      _manager.onEvent(SynqEventType.syncStart).listen((_) => callback()),
    );
    return this;
  }

  /// Listen for error events
  SynqListeners<T> onError(void Function(Object error) callback) {
    _subscriptions.add(
      _manager.onError
          .listen((event) => callback(event.error ?? 'Unknown error')),
    );
    return this;
  }

  /// Listen for conflict events
  SynqListeners<T> onConflict(
      void Function(String key, Object conflict) callback) {
    _subscriptions.add(
      _manager.onConflict.listen((event) {
        // Since conflict data structure might vary, we pass the error or metadata
        callback(
          event.key,
          (event.metadata['conflict'] as Object?) ??
              event.error ??
              'Conflict detected',
        );
      }),
    );
    return this;
  }

  /// Listen for connection status changes
  SynqListeners<T> onConnectionChange(void Function(bool isOnline) callback) {
    _subscriptions.add(
      _manager.onConnected.listen((_) => callback(true)),
    );
    _subscriptions.add(
      _manager.onDisconnected.listen((_) => callback(false)),
    );
    return this;
  }

  /// Listen for cloud sync start events
  SynqListeners<T> onCloudSyncStart(void Function() callback) {
    _subscriptions.add(
      _manager.onEvent(SynqEventType.cloudSyncStart).listen((_) => callback()),
    );
    return this;
  }

  /// Listen for cloud sync success events
  SynqListeners<T> onCloudSyncSuccess(
      void Function(Map<String, dynamic> metadata) callback) {
    _subscriptions.add(
      _manager
          .onEvent(SynqEventType.cloudSyncSuccess)
          .listen((event) => callback(event.metadata)),
    );
    return this;
  }

  /// Listen for cloud sync error events
  SynqListeners<T> onCloudSyncError(
      void Function(Object error, Map<String, dynamic> metadata) callback) {
    _subscriptions.add(
      _manager.onEvent(SynqEventType.cloudSyncError).listen((event) => callback(
            event.error ?? 'Unknown cloud sync error',
            event.metadata,
          )),
    );
    return this;
  }

  /// Listen for cloud fetch start events
  SynqListeners<T> onCloudFetchStart(void Function() callback) {
    _subscriptions.add(
      _manager.onEvent(SynqEventType.cloudFetchStart).listen((_) => callback()),
    );
    return this;
  }

  /// Listen for cloud fetch success events
  SynqListeners<T> onCloudFetchSuccess(
      void Function(Map<String, dynamic> metadata) callback) {
    _subscriptions.add(
      _manager
          .onEvent(SynqEventType.cloudFetchSuccess)
          .listen((event) => callback(event.metadata)),
    );
    return this;
  }

  /// Listen for cloud fetch error events
  SynqListeners<T> onCloudFetchError(
      void Function(Object error, Map<String, dynamic> metadata) callback) {
    _subscriptions.add(
      _manager
          .onEvent(SynqEventType.cloudFetchError)
          .listen((event) => callback(
                event.error ?? 'Unknown cloud fetch error',
                event.metadata,
              )),
    );
    return this;
  }

  /// Cancel all event listeners
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
  }
}

/// Socket.io style builder pattern for quick setup
class SynqSocketBuilder<T extends DocumentSerializable> {
  SynqSocketBuilder(this._manager, this._onInit);
  final SynqManager<T> _manager;
  final void Function(Map<String, T> data) _onInit;
  void Function(String key, T data)? _onCreate;
  void Function(String key, T data)? _onUpdate;
  void Function(String key)? _onDelete;
  void Function(Object error)? _onError;
  void Function()? _onSyncComplete;
  void Function()? _onSyncStart;
  void Function()? _onCloudSyncStart;
  void Function(Map<String, dynamic> metadata)? _onCloudSyncSuccess;
  void Function(Object error, Map<String, dynamic> metadata)? _onCloudSyncError;
  void Function()? _onCloudFetchStart;
  void Function(Map<String, dynamic> metadata)? _onCloudFetchSuccess;
  void Function(Object error, Map<String, dynamic> metadata)?
      _onCloudFetchError;

  /// Set create event handler
  SynqSocketBuilder<T> onCreate(void Function(String key, T data) callback) {
    _onCreate = callback;
    return this;
  }

  /// Set update event handler
  SynqSocketBuilder<T> onUpdate(void Function(String key, T data) callback) {
    _onUpdate = callback;
    return this;
  }

  /// Set delete event handler
  SynqSocketBuilder<T> onDelete(void Function(String key) callback) {
    _onDelete = callback;
    return this;
  }

  /// Set error event handler
  SynqSocketBuilder<T> onError(void Function(Object error) callback) {
    _onError = callback;
    return this;
  }

  /// Set sync complete event handler
  SynqSocketBuilder<T> onSyncComplete(void Function() callback) {
    _onSyncComplete = callback;
    return this;
  }

  /// Set sync start event handler
  SynqSocketBuilder<T> onSyncStart(void Function() callback) {
    _onSyncStart = callback;
    return this;
  }

  /// Set cloud sync start event handler
  SynqSocketBuilder<T> onCloudSyncStart(void Function() callback) {
    _onCloudSyncStart = callback;
    return this;
  }

  /// Set cloud sync success event handler
  SynqSocketBuilder<T> onCloudSyncSuccess(
      void Function(Map<String, dynamic> metadata) callback) {
    _onCloudSyncSuccess = callback;
    return this;
  }

  /// Set cloud sync error event handler
  SynqSocketBuilder<T> onCloudSyncError(
      void Function(Object error, Map<String, dynamic> metadata) callback) {
    _onCloudSyncError = callback;
    return this;
  }

  /// Set cloud fetch start event handler
  SynqSocketBuilder<T> onCloudFetchStart(void Function() callback) {
    _onCloudFetchStart = callback;
    return this;
  }

  /// Set cloud fetch success event handler
  SynqSocketBuilder<T> onCloudFetchSuccess(
      void Function(Map<String, dynamic> metadata) callback) {
    _onCloudFetchSuccess = callback;
    return this;
  }

  /// Set cloud fetch error event handler
  SynqSocketBuilder<T> onCloudFetchError(
      void Function(Object error, Map<String, dynamic> metadata) callback) {
    _onCloudFetchError = callback;
    return this;
  }

  /// Start listening and trigger initial data load
  Future<SynqListeners<T>> start() async {
    final listeners = _manager.on();

    // Set up all listeners EXCEPT onInit to prevent double triggering
    if (_onCreate != null) {
      listeners.onCreate(_onCreate!);
    }

    if (_onUpdate != null) {
      listeners.onUpdate(_onUpdate!);
    }

    if (_onDelete != null) {
      listeners.onDelete(_onDelete!);
    }

    if (_onError != null) {
      listeners.onError(_onError!);
    }

    if (_onSyncComplete != null) {
      listeners.onSyncComplete(_onSyncComplete!);
    }

    if (_onSyncStart != null) {
      listeners.onSyncStart(_onSyncStart!);
    }

    if (_onCloudSyncStart != null) {
      listeners.onCloudSyncStart(_onCloudSyncStart!);
    }

    if (_onCloudSyncSuccess != null) {
      listeners.onCloudSyncSuccess(_onCloudSyncSuccess!);
    }

    if (_onCloudSyncError != null) {
      listeners.onCloudSyncError(_onCloudSyncError!);
    }

    if (_onCloudFetchStart != null) {
      listeners.onCloudFetchStart(_onCloudFetchStart!);
    }

    if (_onCloudFetchSuccess != null) {
      listeners.onCloudFetchSuccess(_onCloudFetchSuccess!);
    }

    if (_onCloudFetchError != null) {
      listeners.onCloudFetchError(_onCloudFetchError!);
    }

    // Trigger initial data load ONLY ONCE when manager is ready
    if (_manager.isReady) {
      final data = await _manager.getAll();
      _onInit(data);
    } else {
      // If not ready, wait for connected event and trigger init once
      final subscription = _manager.onConnected.listen((_) async {
        final data = await _manager.getAll();
        _onInit(data);
      });
      // Add subscription to listeners for proper cleanup
      listeners._subscriptions.add(subscription);
    }

    return listeners;
  }
}
