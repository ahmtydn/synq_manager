/// Base contract for entities that participate in synchronization.
abstract class SyncableEntity {
  /// Unique identifier for the entity.
  String get id;

  /// Owner of the entity.
  String get userId;

  /// Timestamp of last modification.
  DateTime get modifiedAt;

  /// Timestamp of creation.
  DateTime get createdAt;

  /// Version or hash used during conflict detection.
  int get version;

  /// Whether the entity has been soft deleted.
  bool get isDeleted;

  /// Convert this entity to a serializable representation.
  Map<String, dynamic> toJson();
}
