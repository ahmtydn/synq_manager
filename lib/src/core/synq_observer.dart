import 'package:synq_manager/synq_manager.dart';

/// An observer class to monitor operations within [SynqManager].
///
/// Implement this class and register it with `SynqManager.addObserver()`
/// to receive notifications about key operations like saving and deleting
/// entities. This is useful for analytics, custom logging, or triggering
/// side effects in response to data modifications.
abstract class SynqObserver<T extends SyncableEntity> {
  /// Called at the beginning of a `push` operation.
  ///
  /// - [item]: The entity being saved.
  /// - [userId]: The ID of the user for whom the item is being saved.
  /// - [source]: The origin of the save operation.
  void onSaveStart(T item, String userId, DataSource source) {}

  /// Called at the end of a successful `push` operation.
  ///
  /// - [item]: The final, transformed entity that was saved.
  /// - [userId]: The ID of the user.
  /// - [source]: The origin of the save operation.
  void onPushEnd(T item, String userId, DataSource source) {}

  /// Called when a `push` operation results in a partial update (a "delta").
  ///
  /// - [entityId]: The ID of the entity being updated.
  /// - [userId]: The ID of the user.
  /// - [delta]: A map of the fields that have changed.
  void onPartialUpdate(
    String entityId,
    String userId,
    Map<String, dynamic> delta,
  ) {}

  /// Called at thebeginning of a `delete` operation.
  void onDeleteStart(String id, String userId) {}

  /// Called at the end of a `delete` operation.
  /// - [success]: Whether the deletion was successful.
  void onDeleteEnd(String id, String userId, {required bool success}) {}

  /// Called when a synchronization cycle is about to start.
  void onSyncStart(String userId) {}

  /// Called when a synchronization cycle has finished.
  void onSyncEnd(String userId, SyncResult result) {}

  /// Called before an individual sync operation is attempted.
  void onOperationStart(SyncOperation<T> operation) {}

  /// Called after an individual sync operation succeeds.
  void onOperationSuccess(SyncOperation<T> operation, T? result) {}

  /// Called when an individual sync operation fails after all retries.
  void onOperationFailure(
    SyncOperation<T> operation,
    Object error,
    StackTrace stackTrace,
  ) {}

  /// Called when a conflict is detected between local and remote data.
  void onConflictDetected(ConflictContext context, T? local, T? remote) {}

  /// Called after a conflict has been resolved.
  void onConflictResolved(
    ConflictContext context,
    ConflictResolution<T> resolution,
  ) {}

  /// Called before a user switch is attempted.
  void onUserSwitchStart(
    String? oldUserId,
    String newUserId,
    UserSwitchStrategy strategy,
  ) {}

  /// Called after a user switch attempt has finished.
  void onUserSwitchEnd(UserSwitchResult result) {}

  /// Called when the schema migration process is about to start.
  void onMigrationStart(int fromVersion, int toVersion) {}

  /// Called when the schema migration process has finished successfully.
  void onMigrationEnd(int finalVersion) {}

  /// Called when a migration fails.
  ///
  /// This is for observation purposes. To handle the error and define a
  /// recovery strategy, use `SynqConfig.onMigrationError`.
  void onMigrationError(Object error, StackTrace stackTrace) {}
}
