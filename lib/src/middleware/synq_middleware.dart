import 'package:synq_manager/src/models/conflict_context.dart';
import 'package:synq_manager/src/models/exceptions.dart';
import 'package:synq_manager/src/models/sync_operation.dart';
import 'package:synq_manager/src/models/sync_result.dart';
import 'package:synq_manager/src/models/syncable_entity.dart';

/// Middleware for intercepting and modifying sync operations.
abstract class SynqMiddleware<T extends SyncableEntity> {
  /// Called before a sync operation is executed.
  Future<void> beforeOperation(SyncOperation<T> operation) async {}

  /// Called after a sync operation completes successfully.
  Future<void> afterOperation(SyncOperation<T> operation, T? result) async {}

  /// Called when a sync operation encounters an error.
  Future<void> onOperationError(
    SyncOperation<T> operation,
    SynqException error,
  ) async {}

  /// Called before a sync cycle starts.
  Future<void> beforeSync(String userId) async {}

  /// Called after a sync cycle completes.
  Future<void> afterSync(String userId, SyncResult result) async {}

  /// Called when a conflict is detected.
  Future<void> onConflict(ConflictContext context, T? local, T? remote) async {}

  /// Transforms an item before saving to local storage.
  Future<T> transformBeforeSave(T item) async => item;

  /// Transforms an item after fetching from remote.
  Future<T> transformAfterFetch(T item) async => item;
}
