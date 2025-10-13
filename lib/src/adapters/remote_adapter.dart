import 'package:synq_manager/synq_manager.dart';

/// Remote storage adapter abstraction for cloud data sources.
abstract class RemoteAdapter<T extends SyncableEntity> {
  /// A descriptive name for the adapter (e.g., "Firebase", "REST").
  /// Defaults to the runtime class name.
  String get name => runtimeType.toString();

  /// Stream of changes that occur in the remote data source.
  /// Emits events when data changes externally.
  /// Return null if the adapter doesn't support real-time change notifications.
  Stream<ChangeDetail<T>>? get changeStream => null;

  /// Fetch all items for a user, optionally filtered by a [SyncScope].
  Future<List<T>> fetchAll(String userId, {SyncScope? scope});

  /// Fetch a single item by its identifier for the given user.
  Future<T?> fetchById(String id, String userId);

  /// Push a full entity to the remote data source (for creates or full updates).
  ///
  /// Returns the entity as it exists on the remote after the push, which may
  /// include server-generated fields or transformations.
  Future<T> push(T item, String userId);

  /// Apply a partial update (a "patch") to an existing entity.
  ///
  /// The [delta] map should contain only the fields that have changed.
  /// Returns the full entity from the remote after the patch is applied.
  Future<T> patch(String id, String userId, Map<String, dynamic> delta);

  /// Delete an entity from the remote data source.
  Future<void> deleteRemote(String id, String userId);

  /// Retrieve metadata describing the user's sync state from the remote.
  Future<SyncMetadata?> getSyncMetadata(String userId);

  /// Persist updated metadata for the user's sync state to the remote.
  Future<void> updateSyncMetadata(SyncMetadata metadata, String userId);

  /// Check if the remote data source is currently reachable.
  Future<bool> isConnected();
}
