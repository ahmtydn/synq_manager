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
  String get version;

  /// Whether the entity has been soft deleted.
  bool get isDeleted;

  /// Convert this entity to a serializable representation.
  Map<String, dynamic> toJson();

  /// Create a copy with optional overrides.
  SyncableEntity copyWith({
    String? userId,
    DateTime? modifiedAt,
    String? version,
    bool? isDeleted,
  });

  /// Factory intended to be overridden by concrete implementations.
  static SyncableEntity fromJson(Map<String, dynamic> json) =>
      throw UnimplementedError(
        'Override SyncableEntity.fromJson in your entity implementation.',
      );
}
