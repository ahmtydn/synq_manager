import 'package:synq_manager/src/models/change_detail.dart';
import 'package:synq_manager/src/models/conflict_context.dart';
import 'package:synq_manager/src/models/conflict_resolution.dart';
import 'package:synq_manager/src/models/sync_metadata.dart';
import 'package:synq_manager/src/models/sync_operation.dart';
import 'package:synq_manager/src/models/syncable_entity.dart';

/// Remote adapter abstraction for communicating with server-side data sources.
abstract class RemoteAdapter<T extends SyncableEntity> {
  /// Stream of changes that occur in the remote storage.
  /// Implementations should emit events when data changes externally
  /// (e.g., from another device or user).
  /// Return null if the adapter doesn't support change notifications.
  Stream<ChangeDetail<T>>? get changeStream => null;

  /// Fetch all items belonging to the user from the remote source.
  Future<List<T>> fetchAll(String userId);

  /// Fetch a single item by identifier.
  Future<T?> fetchById(String id, String userId);

  /// Push (create/update) an item to the remote source,
  /// returning the stored representation.
  Future<T> push(T item, String userId);

  /// Delete the item from the remote source.
  Future<void> deleteRemote(String id, String userId);

  /// Retrieve remote-side metadata to compare sync states.
  Future<SyncMetadata?> getSyncMetadata(String userId);

  /// Persist the latest sync metadata on the remote side.
  ///
  /// Implementations should store the provided [metadata] so that subsequent
  /// calls to [getSyncMetadata] can retrieve an up-to-date snapshot.
  Future<void> updateSyncMetadata(
    SyncMetadata metadata,
    String userId,
  );

  /// Determine whether remote connectivity is currently available.
  Future<bool> isConnected();
}

/// Details about a failed sync operation.
class SyncOperationFailure<T extends SyncableEntity> {
  /// Creates a sync operation failure.
  const SyncOperationFailure({
    required this.operation,
    required this.error,
    required this.canRetry,
    this.conflictResolution,
    this.conflictContext,
  });

  /// The operation that failed.
  final SyncOperation<T> operation;

  /// The error that occurred.
  final Object error;

  /// Whether the operation can be retried.
  final bool canRetry;

  /// Resolution if the failure was due to a conflict.
  final ConflictResolution<T>? conflictResolution;

  /// Context if the failure was due to a conflict.
  final ConflictContext? conflictContext;
}
