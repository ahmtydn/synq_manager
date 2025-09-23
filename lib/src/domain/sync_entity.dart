/// Abstract base class for all entities that can be synchronized
/// Provides the common properties needed for sync operations
abstract class SyncEntity {
  /// Unique identifier for the entity
  String get id;

  /// Last update timestamp for optimistic concurrency control
  DateTime get updatedAt;

  /// Version number for conflict detection
  int get version;

  /// Flag to track if this entity is marked for deletion
  bool get isDeleted;

  /// Flag to track if this entity has local changes that need to be synced
  bool get isDirty;

  /// Convert entity to JSON for storage and transmission
  Map<String, dynamic> toJson();

  /// Create a copy of this entity with updated sync metadata
  SyncEntity copyWithSyncData({
    DateTime? updatedAt,
    int? version,
    bool? isDeleted,
    bool? isDirty,
  });

  /// Create a copy of this entity marking it as dirty (needs sync)
  SyncEntity markAsDirty() {
    return copyWithSyncData(
      isDirty: true,
      updatedAt: DateTime.now(),
    );
  }

  /// Create a copy of this entity marking it as deleted
  SyncEntity markAsDeleted() {
    return copyWithSyncData(
      isDeleted: true,
      isDirty: true,
      updatedAt: DateTime.now(),
    );
  }

  /// Create a copy of this entity after successful sync
  SyncEntity markAsSynced({int? newVersion}) {
    return copyWithSyncData(
      isDirty: false,
      version: newVersion ?? version + 1,
    );
  }
}
