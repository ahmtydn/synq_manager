import 'dart:async';

import 'package:hive_plus_secure/hive_plus_secure.dart';
import 'package:path_provider/path_provider.dart';
import 'package:synq_manager/src/core/local_store.dart';
import 'package:synq_manager/src/storage/cache_model.dart';
import 'package:synq_manager/src/storage/cache_operation.dart';

/// Hive-based implementation of LocalStore
/// Uses your existing cache patterns with Hive
class HiveLocalStore<T extends SyncCacheModel> implements LocalStore<T> {
  HiveLocalStore({
    required this.boxName,
    required this.adapter,
    this.encryptionKey,
  });

  final String boxName;
  final T Function(Map<String, dynamic>) adapter;
  final String? encryptionKey;

  late final HiveCacheOperation<T> _cacheOperation;
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) return;

    final documentPath = (await getApplicationDocumentsDirectory()).path;
    Hive.defaultDirectory = documentPath;

    // Register the adapter for this type
    Hive.registerAdapter(
      T.toString(),
      (json) => adapter(json as Map<String, dynamic>),
      T,
    );

    _cacheOperation = HiveCacheOperation<T>(
      boxName: boxName,
      encryptionKey: encryptionKey,
    );

    _initialized = true;
  }

  @override
  Future<void> save(T entity) async {
    _ensureInitialized();
    _cacheOperation.add(entity);
  }

  @override
  Future<void> saveAll(List<T> entities) async {
    _ensureInitialized();
    _cacheOperation.addAll(entities);
  }

  @override
  Future<void> delete(String id) async {
    _ensureInitialized();
    _cacheOperation.remove(id);
  }

  @override
  Future<T?> get(String id) async {
    _ensureInitialized();
    return _cacheOperation.get(id);
  }

  @override
  Future<List<T>> getAll() async {
    _ensureInitialized();
    return _cacheOperation.getAll();
  }

  @override
  Future<List<T>> getDirtyEntities() async {
    _ensureInitialized();
    final all = await getAll();
    return all.where((entity) => entity.isDirty).toList();
  }

  @override
  Future<List<T>> getDeletedEntities() async {
    _ensureInitialized();
    final all = await getAll();
    return all.where((entity) => entity.isDeleted).toList();
  }

  @override
  StreamSubscription<WatchEvent<Object, T>> watch({String? key}) {
    _ensureInitialized();
    return _cacheOperation.watch(key: key);
  }

  @override
  Future<void> clear() async {
    _ensureInitialized();
    _cacheOperation.clear();
  }

  @override
  Future<int> count() async {
    _ensureInitialized();
    final all = await getAll();
    return all.length;
  }

  @override
  Future<List<T>> getModifiedSince(DateTime timestamp) async {
    _ensureInitialized();
    final all = await getAll();
    return all.where((entity) => entity.updatedAt.isAfter(timestamp)).toList();
  }

  @override
  Future<void> markAsSynced(List<String> ids) async {
    _ensureInitialized();
    for (final id in ids) {
      final entity = await get(id);
      if (entity != null) {
        final syncedEntity = entity.markAsSynced() as T;
        await save(syncedEntity);
      }
    }
  }

  @override
  Future<void> close() async {
    if (_initialized) {
      _cacheOperation.close();
    }
  }

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError('HiveLocalStore must be initialized before use');
    }
  }
}

/// Hive cache operation implementation following your pattern
class HiveCacheOperation<T extends CacheModel> extends CacheOperation<T> {
  HiveCacheOperation({
    required this.boxName,
    this.encryptionKey,
  }) {
    _box = Hive.box<T>(
      name: boxName,
      encryptionKey: encryptionKey,
    );
  }

  final String boxName;
  final String? encryptionKey;
  late final Box<T> _box;

  @override
  void add(T item) {
    _box.put(item.id, item);
  }

  @override
  void addAll(List<T> items) {
    final itemMap = {
      for (final item in items) item.id: item,
    };
    _box.putAll(itemMap);
  }

  @override
  void clear() {
    _box.clear();
  }

  @override
  T? get(String id) {
    return _box.get(id);
  }

  @override
  List<T> getAll() {
    return _box
        .getAll(_box.keys)
        .where((element) => element != null)
        .cast<T>()
        .toList();
  }

  @override
  void remove(String id) {
    _box.delete(id);
  }

  @override
  StreamSubscription<WatchEvent<Object, T>> watch({String? key}) {
    final stream = _box.watch(key: key);
    final subscription = stream.listen((null));
    return subscription;
  }

  @override
  void close() {
    Hive.closeAllBoxes();
  }
}
