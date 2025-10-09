import 'dart:async';

import 'package:synq_manager/src/adapters/local_adapter.dart';
import 'package:synq_manager/src/models/sync_operation.dart';
import 'package:synq_manager/src/models/syncable_entity.dart';
import 'package:synq_manager/src/utils/logger.dart';

/// Manages the queue of pending sync operations per user.
class QueueManager<T extends SyncableEntity> {
  /// Creates a queue manager.
  QueueManager({required this.localAdapter, required this.logger});

  /// Local adapter for persisting operations.
  final LocalAdapter<T> localAdapter;

  /// Logger instance.
  final SynqLogger logger;

  final Map<String, List<SyncOperation<T>>> _pendingByUser = {};
  final Map<String, StreamController<List<SyncOperation<T>>>> _controllers = {};

  /// Initializes the queue for a specific user.
  Future<void> initializeUser(String userId) async {
    if (_controllers.containsKey(userId)) {
      return;
    }
    final operations = await localAdapter.getPendingOperations(userId);
    _pendingByUser[userId] = operations;
    _controllers[userId] = StreamController<List<SyncOperation<T>>>.broadcast();
    _controllers[userId]!.add(List.unmodifiable(operations));
  }

  /// Watches the queue for a specific user.
  Stream<List<SyncOperation<T>>> watch(String userId) {
    return _controllers[userId]?.stream ?? const Stream.empty();
  }

  /// Gets pending operations for a user.
  List<SyncOperation<T>> getPending(String userId) {
    return List.unmodifiable(_pendingByUser[userId] ?? const []);
  }

  /// Adds an operation to the queue.
  Future<void> enqueue(String userId, SyncOperation<T> operation) async {
    final list = _pendingByUser.putIfAbsent(userId, () => [])..add(operation);
    await localAdapter.addPendingOperation(userId, operation);
    _controllers[userId]?.add(List.unmodifiable(list));
    logger.debug(
      'Queued operation ${operation.id} for user '
      '$userId (${operation.type.name})',
    );
  }

  Future<void> markCompleted(String userId, String operationId) async {
    final list = _pendingByUser[userId];
    if (list == null) return;
    list.removeWhere((op) => op.id == operationId);
    await localAdapter.markAsSynced(operationId);
    _controllers[userId]?.add(List.unmodifiable(list));
    logger.debug('Marked operation $operationId as synced for $userId');
  }

  Future<void> clear(String userId) async {
    _pendingByUser[userId]?.clear();
    _controllers[userId]?.add(const []);
  }

  Future<void> dispose() async {
    for (final controller in _controllers.values) {
      await controller.close();
    }
  }
}
