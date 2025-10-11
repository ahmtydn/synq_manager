import 'package:synq_manager/synq_manager.dart';

/// In-memory implementation of RemoteAdapter for demonstration purposes.
/// In production, use Firebase, REST API, GraphQL, or other remote storage.
class MemoryRemoteAdapter<T extends SyncableEntity>
    implements RemoteAdapter<T> {
  MemoryRemoteAdapter({required this.fromJson});
  final Map<String, Map<String, T>> _remoteStorage = {};
  final Map<String, SyncMetadata> _remoteMetadata = {};
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
  Future<SyncMetadata?> getSyncMetadata(String userId) async {
    if (!_isConnected) {
      throw Exception('No network connection');
    }

    final existing = _remoteMetadata[userId];
    if (existing != null) {
      return existing;
    }

    // Fallback: derive metadata from current storage snapshot.
    final items = _remoteStorage[userId]?.values.toList() ?? [];
    final derived = SyncMetadata(
      lastSyncTime: DateTime.now(),
      userId: userId,
      deviceId: 'demo-device',
      dataHash: items.length.toString(),
      itemCount: items.length,
    );
    _remoteMetadata[userId] = derived;
    return derived;
  }

  /// Exposes stored metadata for demos and tests.
  SyncMetadata? getStoredMetadata(String userId) => _remoteMetadata[userId];

  @override
  Future<void> updateSyncMetadata(
    SyncMetadata metadata,
    String userId,
  ) async {
    if (!_isConnected) {
      throw Exception('No network connection');
    }

    _remoteMetadata[userId] = metadata;
  }

  @override
  Future<bool> isConnected() async {
    return _isConnected;
  }

  @override
  Stream<ChangeDetail<T>>? get changeStream => throw UnimplementedError();
}
