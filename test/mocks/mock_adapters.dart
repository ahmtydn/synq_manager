import 'dart:async';

import 'package:synq_manager/synq_manager.dart';

class MockLocalAdapter<T extends SyncableEntity> implements LocalAdapter<T> {
  MockLocalAdapter({this.fromJson});

  final Map<String, Map<String, T>> _storage = {};
  final Map<String, Map<String, Map<String, dynamic>>> _rawStorage = {};
  final Map<String, List<SyncOperation<T>>> _pendingOps = {};
  final Map<String, SyncMetadata> _metadata = {};
  final _changeController = StreamController<ChangeDetail<T>>.broadcast();
  int _schemaVersion = 0;

  /// A function to deserialize JSON into an entity of type T.
  final T Function(Map<String, dynamic>)? fromJson;

  @override
  String get name => 'MockLocalAdapter';

  @override
  Future<void> initialize() async {
    // No-op for mock
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
    _storage.putIfAbsent(userId, () => {})[item.id] = item;
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
    return List.from(_pendingOps[userId] ?? []);
  }

  @override
  Future<void> addPendingOperation(
    String userId,
    SyncOperation<T> operation,
  ) async {
    final userOps = _pendingOps.putIfAbsent(userId, () => []);
    // Handle updates for retry logic
    final existingIndex = userOps.indexWhere((op) => op.id == operation.id);
    if (existingIndex != -1) {
      userOps[existingIndex] = operation;
    } else {
      userOps.add(operation);
    }
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
  Future<void> updateSyncMetadata(SyncMetadata metadata, String userId) async {
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
      // Mock implementation for a 'completed' filter on TestEntity
      if (query.filters.containsKey('completed')) {
        items = items.where((item) {
          final json = item.toJson();
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
    // A real implementation (e.g., with semaphores or temporary state)
    // would be more complex.
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

  /// Helper to directly add an item to the mock storage for test setup.
  void addLocalItem(String userId, T item) {
    _storage.putIfAbsent(userId, () => {})[item.id] = item;
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
    // Prioritize raw storage if it has data, otherwise use regular storage.
    if (_rawStorage.isNotEmpty) {
      if (userId != null) {
        return _rawStorage[userId]?.values.toList() ?? [];
      }
      return _rawStorage.values.expand((map) => map.values).toList();
    }
    final items = await getAll(userId: userId);
    return items.map((item) => item.toJson()).toList();
  }

  @override
  Future<void> overwriteAllRawData(
    List<Map<String, dynamic>> data, {
    String? userId,
  }) async {
    if (userId != null && userId.isNotEmpty) {
      _rawStorage[userId]?.clear();
    } else {
      _rawStorage.clear();
    }

    // For migration tests, store the raw data directly to avoid re-serialization
    // that could interfere with test assertions.
    for (final rawItem in data) {
      final itemUserId = rawItem['userId'] as String? ?? '';
      final itemId = rawItem['id'] as String? ?? '';
      _rawStorage.putIfAbsent(itemUserId, () => {})[itemId] = rawItem;
    }
  }
}

class MockRemoteAdapter<T extends SyncableEntity> implements RemoteAdapter<T> {
  final Map<String, Map<String, T>> _remoteStorage = {};
  final Map<String, SyncMetadata> _remoteMetadata = {};
  bool connected = true;
  final _changeController = StreamController<ChangeDetail<T>>.broadcast();
  final List<String> _failedIds = [];

  @override
  String get name => 'MockRemoteAdapter';

  void setFailedIds(List<String> ids) => _failedIds
    ..clear()
    ..addAll(ids);

  @override
  Future<List<T>> fetchAll(String userId, {SyncScope? scope}) async {
    if (!connected) throw Exception('No connection');
    var items = _remoteStorage[userId]?.values.toList() ?? [];
    if (scope?.filters['minModifiedDate'] != null) {
      final minDate =
          DateTime.parse(scope!.filters['minModifiedDate'] as String);
      items = items.where((item) => item.modifiedAt.isAfter(minDate)).toList();
    }
    return items;
  }

  @override
  Future<T?> fetchById(String id, String userId) async {
    if (!connected) throw Exception('No connection');
    return _remoteStorage[userId]?[id];
  }

  @override
  Future<T> push(T item, String userId) async {
    if (!connected) throw NetworkException('No connection');
    if (_failedIds.contains(item.id)) {
      throw NetworkException('Simulated push failure for ${item.id}');
    }
    _remoteStorage.putIfAbsent(userId, () => {})[item.id] = item;
    _changeController.add(
      ChangeDetail(
        entityId: item.id,
        userId: userId,
        type: SyncOperationType.update,
        timestamp: DateTime.now(),
        data: item,
      ),
    );
    return item;
  }

  @override
  Future<void> deleteRemote(String id, String userId) async {
    if (!connected) throw Exception('No connection');
    final item = _remoteStorage[userId]?.remove(id);
    if (item != null) {
      _changeController.add(
        ChangeDetail(
          entityId: id,
          userId: userId,
          type: SyncOperationType.delete,
          timestamp: DateTime.now(),
        ),
      );
    }
  }

  @override
  Future<SyncMetadata?> getSyncMetadata(String userId) async {
    return _remoteMetadata[userId];
  }

  @override
  Future<void> updateSyncMetadata(
    SyncMetadata metadata,
    String userId,
  ) async {
    _remoteMetadata[userId] = metadata;
  }

  SyncMetadata? metadataFor(String userId) => _remoteMetadata[userId];

  @override
  Future<bool> isConnected() async => connected;

  void addRemoteItem(String userId, T item) {
    _remoteStorage.putIfAbsent(userId, () => {})[item.id] = item;
  }

  void setRemoteMetadata(String userId, SyncMetadata metadata) {
    _remoteMetadata[userId] = metadata;
  }

  @override
  Stream<ChangeDetail<T>>? get changeStream => _changeController.stream;

  /// Closes the stream controller. Call this in test tearDown.
  Future<void> dispose() async {
    await _changeController.close();
  }
}
