import 'package:synq_manager/synq_manager.dart';

/// Local storage adapter abstraction that provides access to offline data.
abstract class LocalAdapter<T extends SyncableEntity> {
  /// A descriptive name for the adapter (e.g., "Hive", "SQLite").
  /// Defaults to the runtime class name.
  String get name => runtimeType.toString();

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

  /// A stream that emits when the schema version changes.
  ///
  /// This is an optional stream that can be used for advanced scenarios where
  /// the UI needs to react to schema migrations.
  Stream<int>? schemaVersionStream() {
    return null;
  }

  /// Watch all items belonging to the given user.
  ///
  /// Returns a stream that emits the full list of items from the local cache
  /// whenever the underlying data changes. This is the foundation for building
  /// reactive UIs that are offline-first.
  /// Return null if the adapter doesn't support reactive queries.
  Stream<List<T>>? watchAll({String? userId}) {
    return null;
  }

  /// Watch a single item by its identifier for the given user.
  ///
  /// Returns a stream that emits the item from the local cache whenever it
  /// changes.
  /// Emits null if the item is deleted.
  /// Return null if the adapter doesn't support reactive queries.
  Stream<T?>? watchById(String id, String userId) {
    return null;
  }

  /// Watch a paginated list of items.
  ///
  /// Returns a stream that emits a paginated result from the local cache
  /// whenever the underlying data changes.
  /// Return null if the adapter doesn't support reactive queries.
  Stream<PaginatedResult<T>>? watchAllPaginated(
    PaginationConfig config, {
    String? userId,
  }) {
    return null;
  }

  /// Watch a subset of items matching a query.
  ///
  /// Returns a stream that emits a filtered list of items from the local cache
  /// whenever the underlying data changes.
  /// Return null if the adapter doesn't support reactive queries.
  Stream<List<T>>? watchQuery(SynqQuery query, {String? userId}) {
    return null;
  }

  /// Returns a stream that emits the total number of entities, optionally
  /// matching a query.
  ///
  /// This is an efficient way to reactively display counts in the UI without
  /// fetching and processing the full list of items.
  /// Return null if the adapter does not support this feature.
  Stream<int>? watchCount({SynqQuery? query, String? userId}) {
    return null;
  }

  /// Returns a stream that emits the first entity matching a query.
  ///
  /// Useful for reactively displaying a single item from a filtered set.
  /// Emits `null` if no matching entities are found.
  Stream<T?>? watchFirst({SynqQuery? query, String? userId}) {
    return null;
  }

  /// Fetch all items belonging to the given user.
  Future<List<T>> getAll({String? userId});

  /// Fetch a single item by its identifier for the given user.
  Future<T?> getById(String id, String userId);

  /// Fetch multiple items by their identifiers for the given user.
  Future<Map<String, T>> getByIds(List<String> ids, String userId);

  /// Fetch a paginated list of items.
  Future<PaginatedResult<T>> getAllPaginated(
    PaginationConfig config, {
    String? userId,
  });

  /// Persist or update a full entity locally.
  Future<void> push(T item, String userId);

  /// Apply a partial update (a "patch") to an existing entity locally.
  ///
  /// The [delta] map should contain only the fields that have changed.
  /// Throws an exception if the entity does not exist.
  /// Returns the full, updated entity from local storage after the patch is applied.
  Future<T> patch(String id, String userId, Map<String, dynamic> delta);

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

  /// Retrieve the schema version currently stored in the database.
  /// Should return 0 if no version is stored.
  Future<int> getStoredSchemaVersion();

  /// Persist the new schema version to the database.
  Future<void> setStoredSchemaVersion(int version);

  /// Fetch all data for a user as a list of raw maps.
  /// This is used during schema migrations to avoid deserialization issues.
  Future<List<Map<String, dynamic>>> getAllRawData({String? userId});

  /// Overwrite all existing data with a new set of raw data maps.
  /// This is used during schema migrations after transforming the data.
  Future<void> overwriteAllRawData(
    List<Map<String, dynamic>> data, {
    String? userId,
  });

  /// Executes a block of code within a transaction.
  ///
  /// All database operations within the `action` block are treated as a single
  /// atomic unit. If the future returned by `action` completes with an error,
  /// all changes are rolled back.
  Future<R> transaction<R>(Future<R> Function() action);

  /// Dispose of underlying resources (close boxes, connections, etc.).
  Future<void> dispose();
}
