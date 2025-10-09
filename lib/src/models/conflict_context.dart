import 'package:synq_manager/src/models/sync_metadata.dart';

/// Types of conflicts detected between local and remote representations.
enum ConflictType {
  bothModified,
  userMismatch,
  localNotSynced,
  deletionConflict,
}

/// Context information describing a synchronization conflict.
class ConflictContext {
  const ConflictContext({
    required this.userId,
    required this.entityId,
    required this.type,
    required this.detectedAt,
    this.localMetadata,
    this.remoteMetadata,
  });
  final String userId;
  final String entityId;
  final ConflictType type;
  final SyncMetadata? localMetadata;
  final SyncMetadata? remoteMetadata;
  final DateTime detectedAt;
}
