import 'package:synq_manager/src/models/sync_metadata.dart';

/// Types of conflicts detected between local and remote representations.
enum ConflictType {
  /// Both local and remote versions were modified independently.
  bothModified,

  /// Entity user ownership changed between versions.
  userMismatch,

  /// Local entity exists but was never synced to remote.
  localNotSynced,

  /// One version deleted while other was modified.
  deletionConflict,
}

/// Context information describing a synchronization conflict.
class ConflictContext {
  /// Creates a conflict context.
  const ConflictContext({
    required this.userId,
    required this.entityId,
    required this.type,
    required this.detectedAt,
    this.localMetadata,
    this.remoteMetadata,
  });

  /// User ID associated with the conflict.
  final String userId;

  /// Entity ID involved in the conflict.
  final String entityId;

  /// Type of conflict detected.
  final ConflictType type;

  /// Metadata from the local version.
  final SyncMetadata? localMetadata;

  /// Metadata from the remote version.
  final SyncMetadata? remoteMetadata;

  /// Timestamp when the conflict was detected.
  final DateTime detectedAt;
}
