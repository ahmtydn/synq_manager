import 'package:synq_manager/src/models/sync_metadata.dart';
import 'package:synq_manager/src/models/sync_operation.dart';
import 'package:synq_manager/src/models/syncable_entity.dart';

/// Local storage adapter abstraction that provides access to offline data.
abstract class LocalAdapter<T extends SyncableEntity> {
  /// Initialize the local storage implementation
  /// (open boxes, create tables, etc.).
  Future<void> initialize();

  /// Fetch all items belonging to the given user.
  Future<List<T>> getAll({String? userId});

  /// Fetch a single item by its identifier for the given user.
  Future<T?> getById(String id, String userId);

  /// Persist or update an entity locally.
  Future<void> save(T item, String userId);

  /// Remove an entity locally. Implementations
  /// may perform soft deletes if needed.
  Future<void> delete(String id, String userId);

  /// Return the list of pending sync operations awaiting remote reconciliation.
  Future<List<SyncOperation<T>>> getPendingOperations(String userId);

  /// Add a new pending operation to the queue for persistence.
  Future<void> addPendingOperation(String userId, SyncOperation<T> operation);

  /// Mark a pending operation as synced so it can be removed from the queue.
  Future<void> markAsSynced(String operationId);

  /// Remove all local data associated with the provided user.
  Future<void> clearUserData(String userId);

  /// Retrieve metadata describing the user's sync state (hashes, counts, etc.).
  Future<SyncMetadata?> getSyncMetadata(String userId);

  /// Persist updated metadata for the user's sync state.
  Future<void> updateSyncMetadata(SyncMetadata metadata, String userId);

  /// Dispose of underlying resources (close boxes, connections, etc.).
  Future<void> dispose();
}
