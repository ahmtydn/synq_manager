import 'dart:async';

import 'package:synq_manager/synq_manager.dart';

/// In-memory implementation of RemoteAdapter for demonstration purposes.
/// In production, use Firebase, REST API, GraphQL, or other remote storage.
class MemoryRemoteAdapter<T extends SyncableEntity>
    implements RemoteAdapter<T> {
  MemoryRemoteAdapter({required this.fromJson});
  final Map<String, Map<String, T>> _remoteStorage = {};
  final Map<String, SyncMetadata> _remoteMetadata = {};
  final _changeController = StreamController<ChangeDetail<T>>.broadcast();
  final T Function(Map<String, dynamic>) fromJson;
  final bool _isConnected = true;

  @override
  String get name => 'MemoryRemoteAdapter';

  @override
  Future<List<T>> fetchAll(String userId, {SyncScope? scope}) async {
    if (!_isConnected) {
      throw Exception('No network connection');
    }

    // Simulate network delay
    await Future<void>.delayed(const Duration(milliseconds: 100));
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
  Future<T> patch(String id, String userId, Map<String, dynamic> delta) async {
    if (!_isConnected) {
      throw Exception('No network connection');
    }

    // Simulate network delay
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final existing = _remoteStorage[userId]?[id];
    if (existing == null) throw Exception('Entity not found for patching');

    final json = existing.toMap()..addAll(delta);
    final patchedItem = fromJson(json);
    _remoteStorage.putIfAbsent(userId, () => {})[id] = patchedItem;
    return patchedItem;
  }

  @override
  Future<void> deleteRemote(String id, String userId) async {
    if (!_isConnected) {
      throw Exception('No network connection');
    }

    // Simulate network delay
    await Future<void>.delayed(const Duration(milliseconds: 100));

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
  Stream<ChangeDetail<T>>? get changeStream => _changeController.stream;
}
