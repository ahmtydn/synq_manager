import 'package:synq_manager/src/models/conflict_context.dart';
import 'package:synq_manager/src/models/conflict_resolution.dart';
import 'package:synq_manager/src/models/remote_change_event.dart';
import 'package:synq_manager/src/models/sync_metadata.dart';
import 'package:synq_manager/src/models/sync_operation.dart';
import 'package:synq_manager/src/models/syncable_entity.dart';

/// Remote adapter abstraction for communicating with server-side data sources.
abstract class RemoteAdapter<T extends SyncableEntity> {
  /// Fetch all items belonging to the user from the remote source.
  Future<List<T>> fetchAll(String userId);

  /// Fetch a single item by identifier.
  Future<T?> fetchById(String id, String userId);

  /// Push (create/update) an item to the remote source,
  /// returning the stored representation.
  Future<T> push(T item, String userId);

  /// Delete the item from the remote source.
  Future<void> deleteRemote(String id, String userId);

  /// Perform a batch sync operation, reconciling
  /// local operations with the remote source.
  Future<BatchSyncResult<T>> batchSync(
    List<SyncOperation<T>> operations,
    String userId,
  );

  /// Retrieve remote-side metadata to compare sync states.
  Future<SyncMetadata?> getRemoteSyncMetadata(String userId);

  /// Determine whether remote connectivity is currently available.
  Future<bool> isConnected();

  /// Subscribe to remote change notifications to power real-time syncing.
  Stream<RemoteChangeEvent<T>>? subscribeToChanges(String userId);
}

/// Result of a batch sync invocation that captures successes and failures.
class BatchSyncResult<T extends SyncableEntity> {
  /// Creates a batch sync result.
  const BatchSyncResult({
    required this.successful,
    required this.failed,
    required this.totalProcessed,
    required this.duration,
  });

  /// Successfully synced items.
  final List<T> successful;

  /// Failed operations.
  final List<SyncOperationFailure<T>> failed;

  /// Total number of operations processed.
  final int totalProcessed;

  /// Duration of the batch operation.
  final Duration duration;

  /// Whether any operations failed.
  bool get hasFailures => failed.isNotEmpty;

  /// Success rate as a fraction (0.0 to 1.0).
  double get successRate =>
      totalProcessed == 0 ? 0 : successful.length / totalProcessed;
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
