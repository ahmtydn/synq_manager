import 'dart:async';
import 'package:synq_manager/synq_manager.dart';

/// In-memory implementation of LocalAdapter for demonstration purposes.
/// In production, use Hive, SQLite, or other persistent storage.
class MemoryLocalAdapter<T extends SyncableEntity> implements LocalAdapter<T> {
  MemoryLocalAdapter({required this.fromJson});
  final Map<String, Map<String, T>> _storage = {};
  final Map<String, List<SyncOperation<T>>> _pendingOps = {};
  final Map<String, SyncMetadata> _metadata = {};
  final _changeController = StreamController<ChangeDetail<T>>.broadcast();
  int _schemaVersion = 0;

  final T Function(Map<String, dynamic>) fromJson;

  @override
  String get name => 'MemoryLocalAdapter';

  @override
  Future<void> initialize() async {
    // No initialization needed for in-memory storage
  }

  @override
  Future<List<T>> getAll({String? userId}) async {
    if (userId != null) {
      return _storage[userId]?.values.toList() ?? [];
    }
    return _storage.values.expand((map) => map.values).toList();
  }

  @override
  Future<T?> getById(String id, String userId) async {
    return _storage[userId]?[id];
  }

  @override
  Future<Map<String, T>> getByIds(List<String> ids, String userId) async {
    final userStorage = _storage[userId];
    if (userStorage == null) return {};

    final results = <String, T>{};
    for (final id in ids) {
      if (userStorage.containsKey(id)) results[id] = userStorage[id]!;
    }
    return results;
  }

  @override
  Future<void> save(T item, String userId) async {
    _storage.putIfAbsent(userId, () => {});
    _storage[userId]![item.id] = item;
    _changeController.add(
      ChangeDetail(
        entityId: item.id,
        userId: userId,
        type: SyncOperationType.update,
        timestamp: DateTime.now(),
        data: item,
      ),
    );
  }

  @override
  Future<bool> delete(String id, String userId) async {
    final item = _storage[userId]?.remove(id);
    if (item != null) {
      _changeController.add(
        ChangeDetail(
          entityId: id,
          userId: userId,
          type: SyncOperationType.delete,
          timestamp: DateTime.now(),
          data: item,
        ),
      );
      return true;
    }
    return false;
  }

  @override
  Future<List<SyncOperation<T>>> getPendingOperations(String userId) async {
    return _pendingOps[userId] ?? [];
  }

  @override
  Future<void> addPendingOperation(
    String userId,
    SyncOperation<T> operation,
  ) async {
    _pendingOps.putIfAbsent(userId, () => []);
    _pendingOps[userId]!.add(operation);
  }

  @override
  Future<void> markAsSynced(String operationId) async {
    for (final ops in _pendingOps.values) {
      ops.removeWhere((op) => op.id == operationId);
    }
  }

  @override
  Future<void> clearUserData(String userId) async {
    _storage.remove(userId);
    _pendingOps.remove(userId);
    _metadata.remove(userId);
  }

  @override
  Future<SyncMetadata?> getSyncMetadata(String userId) async {
    return _metadata[userId];
  }

  @override
  Future<void> updateSyncMetadata(
    SyncMetadata metadata,
    String userId,
  ) async {
    _metadata[userId] = metadata;
  }

  @override
  Future<void> dispose() async {
    _storage.clear();
    _pendingOps.clear();
    _metadata.clear();
    await _changeController.close();
  }

  @override
  Stream<ChangeDetail<T>>? changeStream() {
    return _changeController.stream;
  }

  @override
  Stream<int>? schemaVersionStream() {
    return null;
  }

  @override
  Stream<List<T>>? watchAll({String? userId}) {
    final stream = changeStream();
    if (stream == null) return null;

    final initialDataStream = Stream.fromFuture(getAll(userId: userId));
    final updateStream = stream
        .where((event) => userId == null || event.userId == userId)
        .asyncMap((_) => getAll(userId: userId));

    return Rx.concat([initialDataStream, updateStream]);
  }

  @override
  Stream<T?>? watchById(String id, String userId) {
    final stream = changeStream();
    if (stream == null) return null;

    final initialDataStream = Stream.fromFuture(getById(id, userId));
    final updateStream = stream
        .where((event) => event.entityId == id && event.userId == userId)
        .asyncMap((_) => getById(id, userId));

    return ConcatStream([initialDataStream, updateStream]);
  }

  @override
  Future<PaginatedResult<T>> getAllPaginated(
    PaginationConfig config, {
    String? userId,
  }) async {
    final allItems = await getAll(userId: userId);
    final totalCount = allItems.length;
    final totalPages = (totalCount / config.pageSize).ceil();
    final currentPage = config.currentPage ?? 1;

    final startIndex = (currentPage - 1) * config.pageSize;
    if (startIndex >= totalCount) {
      return PaginatedResult(
        items: [],
        totalCount: totalCount,
        currentPage: currentPage,
        totalPages: totalPages,
        hasMore: false,
      );
    }

    final endIndex = (startIndex + config.pageSize > totalCount)
        ? totalCount
        : startIndex + config.pageSize;
    final pageItems = allItems.sublist(startIndex, endIndex);

    return PaginatedResult(
      items: pageItems,
      totalCount: totalCount,
      currentPage: currentPage,
      totalPages: totalPages,
      hasMore: currentPage < totalPages,
    );
  }

  @override
  Stream<PaginatedResult<T>>? watchAllPaginated(
    PaginationConfig config, {
    String? userId,
  }) {
    final stream = changeStream();
    if (stream == null) return null;

    final initialDataStream =
        Stream.fromFuture(getAllPaginated(config, userId: userId));
    final updateStream = stream
        .where((event) => userId == null || event.userId == userId)
        .asyncMap((_) => getAllPaginated(config, userId: userId));

    return Rx.concat([initialDataStream, updateStream]);
  }

  @override
  Stream<List<T>>? watchQuery(SynqQuery query, {String? userId}) {
    final stream = changeStream();
    if (stream == null) return null;

    // Helper to apply query
    Future<List<T>> getFiltered() async {
      var items = await getAll(userId: userId);
      // Simple mock implementation for a 'completed' filter on Task
      if (query.filters.containsKey('completed')) {
        items = items.where((item) {
          final json = item.toMap();
          return json['completed'] == query.filters['completed'];
        }).toList();
      }
      return items;
    }

    final initialDataStream = Stream.fromFuture(getFiltered());
    final updateStream = stream.asyncMap((_) => getFiltered());

    return Rx.concat([initialDataStream, updateStream]);
  }

  @override
  Stream<int>? watchCount({SynqQuery? query, String? userId}) {
    final sourceStream = query != null
        ? watchQuery(query, userId: userId)
        : watchAll(userId: userId);

    return sourceStream?.map((list) => list.length);
  }

  @override
  Stream<T?>? watchFirst({SynqQuery? query, String? userId}) {
    final sourceStream = query != null
        ? watchQuery(query, userId: userId)
        : watchAll(userId: userId);

    return sourceStream?.map((list) => list.isNotEmpty ? list.first : null);
  }

  @override
  Future<R> transaction<R>(Future<R> Function() action) async {
    // This is a simplified mock transaction. It doesn't provide true rollback
    // for the in-memory map, but it allows testing the flow.
    final backupStorage = _storage.map<String, Map<String, T>>(
      (key, value) => MapEntry(key, Map<String, T>.from(value)),
    );
    try {
      return await action();
    } catch (e) {
      // Restore from backup on error
      _storage
        ..clear()
        ..addAll(backupStorage);
      rethrow;
    }
  }

  @override
  Future<int> getStoredSchemaVersion() async {
    return _schemaVersion;
  }

  @override
  Future<void> setStoredSchemaVersion(int version) async {
    _schemaVersion = version;
  }

  @override
  Future<List<Map<String, dynamic>>> getAllRawData({String? userId}) async {
    final items = await getAll(userId: userId);
    return items.map((item) => item.toMap()).toList();
  }

  @override
  Future<void> overwriteAllRawData(
    List<Map<String, dynamic>> data, {
    String? userId,
  }) async {
    if (userId != null) {
      _storage[userId]?.clear();
    } else {
      _storage.clear();
    }

    for (final rawItem in data) {
      final item = fromJson(rawItem);
      _storage.putIfAbsent(item.userId, () => {})[item.id] = item;
    }
  }
}
