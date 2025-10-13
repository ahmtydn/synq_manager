import 'package:synq_manager/synq_manager.dart';

/// An observer class to monitor operations within [SynqManager].
///
/// Implement this class and register it with `SynqManager.addObserver()`
/// to receive notifications about key operations like saving and deleting
/// entities. This is useful for analytics, custom logging, or triggering
/// side effects in response to data modifications.
abstract class SynqObserver<T extends SyncableEntity> {
  /// Called at the beginning of a `save` operation.
  ///
  /// - [item]: The entity being saved.
  /// - [userId]: The ID of the user for whom the item is being saved.
  /// - [source]: The origin of the save operation.
  void onSaveStart(T item, String userId, DataSource source) {}

  /// Called at the end of a successful `save` operation.
  ///
  /// - [item]: The final, transformed entity that was saved.
  /// - [userId]: The ID of the user.
  /// - [source]: The origin of the save operation.
  void onSaveEnd(T item, String userId, DataSource source) {}

  /// Called at thebeginning of a `delete` operation.
  void onDeleteStart(String id, String userId) {}

  /// Called at the end of a `delete` operation.
  /// - [success]: Whether the deletion was successful.
  void onDeleteEnd(String id, String userId, {required bool success}) {}
}
