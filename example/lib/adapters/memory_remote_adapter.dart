import 'package:synq_manager/synq_manager.dart';

/// In-memory implementation of RemoteAdapter for demonstration purposes.
/// In production, use Firebase, REST API, GraphQL, or other remote storage.
class MemoryRemoteAdapter<T extends SyncableEntity>
    implements RemoteAdapter<T> {
  MemoryRemoteAdapter({required this.fromJson});
  final Map<String, Map<String, T>> _remoteStorage = {};
  final T Function(Map<String, dynamic>) fromJson;
  final bool _isConnected = true;

  @override
  Future<List<T>> fetchAll(String userId) async {
    if (!_isConnected) {
      throw Exception('No network connection');
    }

    // Simulate network delay
    await Future<void>.delayed(const Duration(milliseconds: 100));

    return _remoteStorage[userId]?.values.toList() ?? [];
  }

  @override
  Future<T?> fetchById(String id, String userId) async {
    if (!_isConnected) {
      throw Exception('No network connection');
    }

    // Simulate network delay
    await Future<void>.delayed(const Duration(milliseconds: 50));

    return _remoteStorage[userId]?[id];
  }

  @override
  Future<T> push(T item, String userId) async {
    if (!_isConnected) {
      throw Exception('No network connection');
    }

    // Simulate network delay
    await Future<void>.delayed(const Duration(milliseconds: 100));

    _remoteStorage.putIfAbsent(userId, () => {});
    _remoteStorage[userId]![item.id] = item;

    return item;
  }

  @override
  Future<void> deleteRemote(String id, String userId) async {
    if (!_isConnected) {
      throw Exception('No network connection');
    }

    // Simulate network delay
    await Future<void>.delayed(const Duration(milliseconds: 100));

    _remoteStorage[userId]?.remove(id);
  }

  @override
  Future<BatchSyncResult<T>> batchSync(
    List<SyncOperation<T>> operations,
    String userId,
  ) async {
    if (!_isConnected) {
      throw Exception('No network connection');
    }

    final startTime = DateTime.now();
    final successful = <T>[];
    final failed = <SyncOperationFailure<T>>[];

    // Simulate network delay
    await Future<void>.delayed(const Duration(milliseconds: 200));

    _remoteStorage.putIfAbsent(userId, () => {});

    for (final op in operations) {
      try {
        switch (op.type) {
          case SyncOperationType.create:
          case SyncOperationType.update:
            if (op.data != null) {
              _remoteStorage[userId]![op.data!.id] = op.data!;
              successful.add(op.data!);
            }
          case SyncOperationType.delete:
            _remoteStorage[userId]?.remove(op.entityId);
        }
      } on Exception catch (e) {
        failed.add(
          SyncOperationFailure(
            operation: op,
            error: e.toString(),
            canRetry: true,
          ),
        );
      }
    }

    return BatchSyncResult(
      successful: successful,
      failed: failed,
      totalProcessed: operations.length,
      duration: DateTime.now().difference(startTime),
    );
  }

  @override
  Future<SyncMetadata?> getRemoteSyncMetadata(String userId) async {
    if (!_isConnected) {
      throw Exception('No network connection');
    }

    // For demo purposes, return basic metadata
    final items = _remoteStorage[userId]?.values.toList() ?? [];
    return SyncMetadata(
      lastSyncTime: DateTime.now(),
      userId: userId,
      deviceId: 'demo-device',
      dataHash: items.length.toString(),
      itemCount: items.length,
    );
  }

  @override
  Future<bool> isConnected() async {
    return _isConnected;
  }

  @override
  Stream<RemoteChangeEvent<T>>? subscribeToChanges(String userId) {
    // Not implemented for demo - return null to disable real-time sync
    return null;
  }
}
