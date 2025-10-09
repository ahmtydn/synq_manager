import 'package:synq_manager/src/adapters/local_adapter.dart';
import 'package:synq_manager/src/adapters/remote_adapter.dart';
import 'package:synq_manager/src/models/remote_change_event.dart';
import 'package:synq_manager/src/models/sync_metadata.dart';
import 'package:synq_manager/src/models/sync_operation.dart';
import 'package:synq_manager/src/models/syncable_entity.dart';

class MockLocalAdapter<T extends SyncableEntity> implements LocalAdapter<T> {
  final Map<String, Map<String, T>> _storage = {};
  final Map<String, List<SyncOperation<T>>> _pendingOps = {};
  final Map<String, SyncMetadata> _metadata = {};

  @override
  Future<void> initialize() async {}

  @override
  Future<List<T>> getAll(String userId) async {
    return _storage[userId]?.values.toList() ?? [];
  }

  @override
  Future<T?> getById(String id, String userId) async {
    return _storage[userId]?[id];
  }

  @override
  Future<void> save(T item, String userId) async {
    _storage.putIfAbsent(userId, () => {})[item.id] = item;
  }

  @override
  Future<void> delete(String id, String userId) async {
    _storage[userId]?.remove(id);
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
  }
}

class MockRemoteAdapter<T extends SyncableEntity> implements RemoteAdapter<T> {
  final Map<String, Map<String, T>> _remoteStorage = {};
  final Map<String, SyncMetadata> _remoteMetadata = {};
  bool _connected = true;
  final List<String> _failedIds = [];

  void setConnected(bool connected) => _connected = connected;
  void setFailedIds(List<String> ids) => _failedIds
    ..clear()
    ..addAll(ids);

  @override
  Future<List<T>> fetchAll(String userId) async {
    if (!_connected) throw Exception('No connection');
    return _remoteStorage[userId]?.values.toList() ?? [];
  }

  @override
  Future<T?> fetchById(String id, String userId) async {
    if (!_connected) throw Exception('No connection');
    return _remoteStorage[userId]?[id];
  }

  @override
  Future<T> push(T item, String userId) async {
    if (!_connected) throw Exception('No connection');
    if (_failedIds.contains(item.id)) {
      throw Exception('Simulated push failure for ${item.id}');
    }
    _remoteStorage.putIfAbsent(userId, () => {})[item.id] = item;
    return item;
  }

  @override
  Future<void> deleteRemote(String id, String userId) async {
    if (!_connected) throw Exception('No connection');
    _remoteStorage[userId]?.remove(id);
  }

  @override
  Future<BatchSyncResult<T>> batchSync(
    List<SyncOperation<T>> operations,
    String userId,
  ) async {
    if (!_connected) throw Exception('No connection');

    final stopwatch = Stopwatch()..start();
    final successful = <T>[];
    final failed = <SyncOperationFailure<T>>[];

    for (final op in operations) {
      try {
        if (_failedIds.contains(op.entityId)) {
          throw Exception('Simulated failure for ${op.entityId}');
        }

        switch (op.type) {
          case SyncOperationType.create:
          case SyncOperationType.update:
            if (op.data != null) {
              final result = await push(op.data!, userId);
              successful.add(result);
            }
          case SyncOperationType.delete:
            await deleteRemote(op.entityId, userId);
        }
      } catch (e) {
        failed.add(
          SyncOperationFailure(
            operation: op,
            error: e,
            canRetry: true,
          ),
        );
      }
    }

    stopwatch.stop();
    return BatchSyncResult(
      successful: successful,
      failed: failed,
      totalProcessed: operations.length,
      duration: stopwatch.elapsed,
    );
  }

  @override
  Future<SyncMetadata?> getRemoteSyncMetadata(String userId) async {
    return _remoteMetadata[userId];
  }

  @override
  Future<bool> isConnected() async => _connected;

  @override
  Stream<RemoteChangeEvent<T>>? subscribeToChanges(String userId) => null;

  void addRemoteItem(String userId, T item) {
    _remoteStorage.putIfAbsent(userId, () => {})[item.id] = item;
  }

  void setRemoteMetadata(String userId, SyncMetadata metadata) {
    _remoteMetadata[userId] = metadata;
  }
}
