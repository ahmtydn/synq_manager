import 'package:synq_manager/src/domain/sync_entity.dart';

/// Event fired when a conflict is detected during sync
class ConflictEvent<T extends SyncEntity> {
  const ConflictEvent({
    required this.localEntity,
    required this.remoteEntity,
    required this.entityType,
    this.conflictReason,
  });

  /// The local version of the entity
  final T localEntity;

  /// The remote version of the entity
  final T remoteEntity;

  /// Type of the entity (for logging and debugging)
  final Type entityType;

  /// Reason for the conflict (optional)
  final String? conflictReason;

  /// Whether the conflict is based on version mismatch
  bool get isVersionConflict => localEntity.version != remoteEntity.version;

  /// Whether the conflict is based on timestamp
  bool get isTimestampConflict =>
      localEntity.updatedAt.isAfter(remoteEntity.updatedAt) &&
      remoteEntity.updatedAt.isAfter(localEntity.updatedAt);

  /// Get a human-readable description of the conflict
  String get description {
    if (conflictReason != null) return conflictReason!;

    if (isVersionConflict) {
      return 'Version conflict: local v${localEntity.version} vs remote v${remoteEntity.version}';
    }

    if (isTimestampConflict) {
      return 'Timestamp conflict: local ${localEntity.updatedAt} vs remote ${remoteEntity.updatedAt}';
    }

    return 'Unknown conflict between local and remote versions';
  }
}
