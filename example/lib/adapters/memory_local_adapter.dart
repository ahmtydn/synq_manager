import 'package:synq_manager/synq_manager.dart';

/// In-memory implementation of LocalAdapter for demonstration purposes.
/// In production, use Hive, SQLite, or other persistent storage.
class MemoryLocalAdapter<T extends SyncableEntity> implements LocalAdapter<T> {
  MemoryLocalAdapter({required this.fromJson});
  final Map<String, Map<String, T>> _storage = {};
  final Map<String, List<SyncOperation<T>>> _pendingOps = {};
  final Map<String, SyncMetadata> _metadata = {};
  final T Function(Map<String, dynamic>) fromJson;

  @override
  Future<void> initialize() async {
    // No initialization needed for in-memory storage
  }

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
    _storage.putIfAbsent(userId, () => {});
    _storage[userId]![item.id] = item;
  }

  @override
  Future<void> delete(String id, String userId) async {
    _storage[userId]?.remove(id);
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
  }
}
