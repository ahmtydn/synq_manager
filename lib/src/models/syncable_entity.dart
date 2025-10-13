import 'package:synq_manager/synq_manager.dart';

/// An interface for entities that can be synchronized by [SynqManager].
abstract class SyncableEntity {
  /// A unique identifier for the entity.
  String get id;

  /// The ID of the user who owns this entity.
  String get userId;

  /// The last time the entity was modified.
  DateTime get modifiedAt;

  /// The time the entity was created.
  DateTime get createdAt;

  /// The version of the entity, used for conflict detection.
  int get version;

  /// A flag indicating if the entity is soft-deleted.
  bool get isDeleted;

  /// Creates a JSON representation of the entity.
  Map<String, dynamic> toJson();

  /// Creates a copy of the entity with updated fields.
  SyncableEntity copyWith();

  /// Compares this entity with an older version and returns a map of changed fields.
  Map<String, dynamic>? diff(SyncableEntity oldVersion);
}
