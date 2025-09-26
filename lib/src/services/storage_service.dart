import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive_plus_secure/hive_plus_secure.dart';
import 'package:path_provider/path_provider.dart';
import 'package:synq_manager/synq_manager.dart';

/// Service for secure local storage operations
class StorageService<T extends DocumentSerializable> {
  StorageService._({
    required this.boxName,
    required this.encryptionKey,
    required this.maxSizeMiB,
    required this.fromJson,
    required this.toJson,
  });

  /// Box name for storage
  final String boxName;

  /// Encryption key for secure storage
  final String? encryptionKey;

  /// Maximum storage size in MiB
  final int maxSizeMiB;

  /// Function to deserialize T from JSON
  final FromJsonFunction<T>? fromJson;

  /// Function to serialize T to JSON
  final ToJsonFunction<T>? toJson;

  /// Hive box instance
  Box<SyncData<T>>? _box;

  /// Stream controller for real-time events
  final StreamController<SynqEvent<T>> _eventController =
      StreamController<SynqEvent<T>>.broadcast();

  /// Watch subscription for box changes
  StreamSubscription<ChangeDetail>? _watchSubscription;

  /// Creates a new storage service instance
  static Future<StorageService<T>> create<T extends DocumentSerializable>({
    required String boxName,
    String? encryptionKey,
    int maxSizeMiB = 5,
    FromJsonFunction<T>? fromJson,
    ToJsonFunction<T>? toJson,
  }) async {
    final service = StorageService<T>._(
      boxName: boxName,
      encryptionKey: encryptionKey,
      maxSizeMiB: maxSizeMiB,
      fromJson: fromJson,
      toJson: toJson,
    );

    await service._initialize();
    return service;
  }

  /// Initializes the storage service
  Future<void> _initialize() async {
    try {
      // Set default directory for Hive
      if (Hive.defaultDirectory == null) {
        final directory = await _getStorageDirectory();
        Hive.defaultDirectory = directory.path;
      }

      // Register adapter for SyncData
      Hive.registerAdapter<SyncData<T>>(
        'SyncData_$T',
        (json) => SyncData<T>.fromJson(
          json as Map<String, dynamic>,
          fromJson: fromJson,
        ),
        SyncData<T>,
      );

      // Open the box
      _box = Hive.box<SyncData<T>>(
        name: boxName,
        encryptionKey: encryptionKey,
        maxSizeMiB: maxSizeMiB,
      );

      // Set up watch subscription for real-time events
      _setupWatcher();
    } catch (error) {
      _eventController.add(
        SynqEvent<T>.syncError(
          key: '__storage_init__',
          error: error,
        ),
      );
      rethrow;
    }
  }

  /// Gets the appropriate storage directory
  Future<Directory> _getStorageDirectory() async {
    if (kIsWeb) {
      throw UnsupportedError('Web platform not supported for local storage');
    }

    try {
      return await getApplicationDocumentsDirectory();
    } catch (_) {
      return Directory.systemTemp;
    }
  }

  /// Sets up the watcher for real-time events
  void _setupWatcher() {
    if (_box == null) return;

    _watchSubscription = _box!
        .watchDetailed<T>(
      documentParser: fromJson,
    )
        .listen(
      (event) {
        final result = switch (event.changeType) {
          ChangeType.insert => SynqEvent<T>.create(
              key: event.key,
              data: SyncData(
                value: event.fullDocument,
                timestamp: DateTime.now().millisecondsSinceEpoch,
              ),
            ),
          ChangeType.update => SynqEvent<T>.update(
              key: event.key,
              data: SyncData(
                value: event.fullDocument,
                timestamp: DateTime.now().millisecondsSinceEpoch,
              ),
            ),
          ChangeType.delete => SynqEvent<T>.delete(
              key: event.key,
              data: SyncData(
                value: event.fullDocument,
                timestamp: DateTime.now().millisecondsSinceEpoch,
              ),
            ),
        };
        _eventController.add(result);
      },
      onError: (Object error) {
        _eventController.add(
          SynqEvent<T>.syncError(
            key: '__watch_error__',
            error: error,
          ),
        );
      },
    );
  }

  /// Stream of real-time storage events
  Stream<SynqEvent<T>> get events => _eventController.stream;

  /// Whether the storage service is ready
  bool get isReady => _box != null && _box!.isOpen;

  /// Number of items in storage
  int get length => _box?.length ?? 0;

  /// Whether storage is empty
  bool get isEmpty => length == 0;

  /// Whether storage is not empty
  bool get isNotEmpty => length > 0;

  /// All keys in storage
  List<String> get keys => _box?.keys ?? [];

  Future<void> add(
    T value, {
    Map<String, dynamic>? metadata,
  }) async {
    if (!isReady) throw StateError('Storage service not ready');

    try {
      final syncData = SyncData<T>(
        value: value,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        metadata: metadata ?? {},
      );

      _box!.add(syncData);
    } catch (error) {
      _eventController.add(
        SynqEvent<T>.syncError(
          key: '__add__',
          error: error,
        ),
      );
      rethrow;
    }
  }

  /// Stores data with the given key
  Future<void> put(
    String key,
    T value, {
    Map<String, dynamic>? metadata,
  }) async {
    if (!isReady) throw StateError('Storage service not ready');

    try {
      final syncData = SyncData<T>(
        value: value,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        metadata: metadata ?? {},
      );

      _box!.put(key, syncData);
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

  /// Retrieves data for the given key
  Future<SyncData<T>?> get(String key) async {
    if (!isReady) throw StateError('Storage service not ready');

    try {
      return _box!.get(key);
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

  /// Retrieves the value for the given key
  Future<T?> getValue(String key) async {
    final syncData = await get(key);
    return syncData?.deleted ?? false ? null : syncData?.value;
  }

  /// Updates existing data with the given key
  Future<void> update(
    String key,
    T value, {
    Map<String, dynamic>? metadata,
  }) async {
    if (!isReady) throw StateError('Storage service not ready');

    try {
      final existing = await get(key);
      if (existing == null) {
        throw ArgumentError('Key "$key" does not exist');
      }

      final updatedData = existing.incrementVersion(
        newValue: value,
        newMetadata: metadata,
      );
      _box!.put(key, updatedData);
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

  /// Deletes data with the given key
  Future<bool> delete(String key) async {
    if (!isReady) throw StateError('Storage service not ready');

    try {
      final existing = await get(key);
      if (existing == null) return false;

      _box!.delete(
        key,
      );

      return true;
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

  /// Retrieves all data entries
  Future<Map<String, SyncData<T>>> getAll() async {
    if (!isReady) throw StateError('Storage service not ready');

    try {
      final result = <String, SyncData<T>>{};
      for (final key in _box!.keys) {
        final data = _box!.get(key);
        if (data != null) {
          result[key] = data;
        }
      }
      return result;
    } catch (error) {
      _eventController.add(
        SynqEvent<T>.syncError(
          key: '__get_all__',
          error: error,
        ),
      );
      rethrow;
    }
  }

  /// Retrieves all active (non-deleted) entries
  Future<Map<String, T>> getAllValues() async {
    final allData = await getAll();
    final result = <String, T>{};

    for (final entry in allData.entries) {
      if (!entry.value.deleted && entry.value.value != null) {
        result[entry.key] = entry.value.value!;
      }
    }

    return result;
  }

  /// Retrieves entries modified since the given timestamp
  Future<Map<String, SyncData<T>>> getModifiedSince(int timestamp) async {
    final allData = await getAll();
    final result = <String, SyncData<T>>{};

    for (final entry in allData.entries) {
      if (entry.value.timestamp > timestamp) {
        result[entry.key] = entry.value;
      }
    }

    return result;
  }

  /// Stores multiple entries in a batch operation
  Future<void> putAll(
    Map<String, T> entries, {
    Map<String, dynamic>? metadata,
  }) async {
    if (!isReady) throw StateError('Storage service not ready');

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      for (final entry in entries.entries) {
        final syncData = SyncData<T>(
          value: entry.value,
          timestamp: timestamp,
          metadata: metadata ?? {},
        );

        _box!.put(entry.key, syncData);
      }
    } catch (error) {
      _eventController.add(
        SynqEvent<T>.syncError(
          key: '__put_all__',
          error: error,
        ),
      );
      rethrow;
    }
  }

  /// Clears all data from storage
  Future<void> clear() async {
    if (!isReady) throw StateError('Storage service not ready');

    try {
      _box!.clear();
    } catch (error) {
      _eventController.add(
        SynqEvent<T>.syncError(
          key: '__clear__',
          error: error,
        ),
      );
      rethrow;
    }
  }

  /// Closes the storage service and releases resources
  Future<void> close() async {
    await _watchSubscription?.cancel();
    _watchSubscription = null;

    _box?.close();
    _box = null;

    await _eventController.close();
  }

  /// Compacts the storage to optimize space usage
  Future<void> compact() async {
    if (!isReady) throw StateError('Storage service not ready');

    try {
      // Remove entries marked as deleted
      final keysToRemove = <String>[];

      for (final key in _box!.keys) {
        final data = _box!.get(key);
        if (data != null && data.deleted) {
          keysToRemove.add(key);
        }
      }

      if (keysToRemove.isNotEmpty) {
        for (final key in keysToRemove) {
          _box!.delete(key);
        }
      }
    } catch (error) {
      _eventController.add(
        SynqEvent<T>.syncError(
          key: '__compact__',
          error: error,
        ),
      );
      rethrow;
    }
  }

  /// Gets storage statistics
  Future<StorageStats> getStats() async {
    if (!isReady) throw StateError('Storage service not ready');

    var totalEntries = 0;
    var activeEntries = 0;
    var deletedEntries = 0;
    var totalSize = 0;

    for (final key in _box!.keys) {
      final data = _box!.get(key);
      if (data != null) {
        totalEntries++;
        totalSize += key.length + data.toString().length;

        if (data.deleted) {
          deletedEntries++;
        } else {
          activeEntries++;
        }
      }
    }

    return StorageStats(
      totalEntries: totalEntries,
      activeEntries: activeEntries,
      deletedEntries: deletedEntries,
      estimatedSizeBytes: totalSize,
    );
  }
}

/// Statistics about storage usage
class StorageStats {
  const StorageStats({
    required this.totalEntries,
    required this.activeEntries,
    required this.deletedEntries,
    required this.estimatedSizeBytes,
  });

  /// Total number of entries in storage
  final int totalEntries;

  /// Number of active (non-deleted) entries
  final int activeEntries;

  /// Number of deleted entries
  final int deletedEntries;

  /// Estimated storage size in bytes
  final int estimatedSizeBytes;

  /// Estimated storage size in kilobytes
  double get estimatedSizeKB => estimatedSizeBytes / 1024.0;

  /// Estimated storage size in megabytes
  double get estimatedSizeMB => estimatedSizeKB / 1024.0;

  @override
  String toString() {
    return 'StorageStats(total: $totalEntries, active: $activeEntries, '
        'deleted: $deletedEntries, size: ${estimatedSizeMB.toStringAsFixed(2)} MB)';
  }
}
