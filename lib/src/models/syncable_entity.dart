import 'package:synq_manager/synq_manager.dart';

/// The target for serialization, allowing different fields for local vs. remote.
enum MapTarget {
  /// For serialization to the local database.
  local,

  /// For serialization to the remote data source.
  remote,
}

/// Base class for all entities that can be synchronized by [SynqManager].
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

  /// Serializes the entity to a map.
  Map<String, dynamic> toMap({MapTarget target = MapTarget.local});

  /// Creates a copy of the entity with updated fields.
  ///
  /// This method is crucial for immutability. Instead of modifying an entity
  /// directly, you create a new instance with the desired changes.
  SyncableEntity copyWith({
    DateTime? modifiedAt,
    int? version,
    bool? isDeleted,
  });

  /// Compares this entity with an older version and returns a map of the
  /// fields that have changed.
  ///
  /// Returns `null` if there are no differences.
  Map<String, dynamic>? diff(SyncableEntity oldVersion);
}
