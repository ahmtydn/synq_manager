import 'package:synq_manager/src/models/change_detail.dart';
import 'package:synq_manager/src/models/sync_metadata.dart';
import 'package:synq_manager/src/models/sync_operation.dart';
import 'package:synq_manager/src/models/syncable_entity.dart';
import 'package:synq_manager/src/query/pagination.dart';

/// Local storage adapter abstraction that provides access to offline data.
abstract class LocalAdapter<T extends SyncableEntity> {
  /// Initialize the local storage implementation
  /// (open boxes, create tables, etc.).
  Future<void> initialize();

  /// Stream of changes that occur in the local storage.
  /// Implementations should emit events when data changes externally
  /// (e.g., from another instance or background sync).
  /// Return null if the adapter doesn't support change notifications.
  Stream<ChangeDetail<T>>? changeStream() {
    return null;
  }

  /// Watch all items belonging to the given user.
  ///
  /// Returns a stream that emits the full list of items whenever data changes.
  /// Return null if the adapter doesn't support reactive queries.
  Stream<List<T>>? watchAll({String? userId}) {
    return null;
  }

  /// Watch a single item by its identifier for the given user.
  ///
  /// Returns a stream that emits the item whenever it changes.
  /// Emits null if the item is deleted.
  /// Return null if the adapter doesn't support reactive queries.
  Stream<T?>? watchById(String id, String userId) {
    return null;
  }

  /// Watch a paginated list of items.
  ///
  /// Returns a stream that emits a paginated result whenever data changes.
  /// Return null if the adapter doesn't support reactive queries.
  Stream<PaginatedResult<T>>? watchAllPaginated(
    PaginationConfig config, {
    String? userId,
  }) {
    return null;
  }

  /// Fetch all items belonging to the given user.
  Future<List<T>> getAll({String? userId});

  /// Fetch a single item by its identifier for the given user.
  Future<T?> getById(String id, String userId);

  /// Fetch a paginated list of items.
  Future<PaginatedResult<T>> getAllPaginated(
    PaginationConfig config, {
    String? userId,
  });

  /// Persist or update an entity locally.
  Future<void> save(T item, String userId);

  /// Remove an entity locally. Implementations
  /// should return `true` if an item was deleted, `false` otherwise.
  Future<bool> delete(String id, String userId);

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
