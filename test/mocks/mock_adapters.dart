import 'dart:async';

import 'package:rxdart/rxdart.dart';
import 'package:synq_manager/src/adapters/local_adapter.dart';
import 'package:synq_manager/src/adapters/remote_adapter.dart';
import 'package:synq_manager/src/models/change_detail.dart';
import 'package:synq_manager/src/models/sync_metadata.dart';
import 'package:synq_manager/src/models/sync_operation.dart';
import 'package:synq_manager/src/models/syncable_entity.dart';
import 'package:synq_manager/src/query/pagination.dart';

class MockLocalAdapter<T extends SyncableEntity> implements LocalAdapter<T> {
  final Map<String, Map<String, T>> _storage = {};
  final Map<String, List<SyncOperation<T>>> _pendingOps = {};
  final Map<String, SyncMetadata> _metadata = {};
  final _changeController = StreamController<ChangeDetail<T>>.broadcast();

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
    _pendingOps.putIfAbsent(userId, () => []).add(operation);
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
}

class MockRemoteAdapter<T extends SyncableEntity> implements RemoteAdapter<T> {
  final Map<String, Map<String, T>> _remoteStorage = {};
  final Map<String, SyncMetadata> _remoteMetadata = {};
  bool connected = true;
  final _changeController = StreamController<ChangeDetail<T>>.broadcast();
  final List<String> _failedIds = [];

  void setFailedIds(List<String> ids) => _failedIds
    ..clear()
    ..addAll(ids);

  @override
  Future<List<T>> fetchAll(String userId) async {
    if (!connected) throw Exception('No connection');
    return _remoteStorage[userId]?.values.toList() ?? [];
  }

  @override
  Future<T?> fetchById(String id, String userId) async {
    if (!connected) throw Exception('No connection');
    return _remoteStorage[userId]?[id];
  }

  @override
  Future<T> push(T item, String userId) async {
    if (!connected) throw Exception('No connection');
    if (_failedIds.contains(item.id)) {
      throw Exception('Simulated push failure for ${item.id}');
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
