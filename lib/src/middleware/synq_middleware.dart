import 'package:synq_manager/src/models/conflict_context.dart';
import 'package:synq_manager/src/models/exceptions.dart';
import 'package:synq_manager/src/models/sync_operation.dart';
import 'package:synq_manager/src/models/sync_result.dart';
import 'package:synq_manager/src/models/syncable_entity.dart';

abstract class SynqMiddleware<T extends SyncableEntity> {
  Future<void> beforeOperation(SyncOperation<T> operation) async {}

  Future<void> afterOperation(SyncOperation<T> operation, T? result) async {}

  Future<void> onOperationError(
    SyncOperation<T> operation,
    SynqException error,
  ) async {}

  Future<void> beforeSync(String userId) async {}

  Future<void> afterSync(String userId, SyncResult result) async {}

  Future<void> onConflict(ConflictContext context, T? local, T? remote) async {}

  Future<T> transformBeforeSave(T item) async => item;

  Future<T> transformAfterFetch(T item) async => item;
}
