import 'package:synq_manager/src/models/conflict_context.dart';
import 'package:synq_manager/src/models/sync_metadata.dart';
import 'package:synq_manager/src/models/syncable_entity.dart';

class ConflictDetector<T extends SyncableEntity> {
  ConflictContext? detect({
    required T? localItem,
    required T? remoteItem,
    required String userId,
    SyncMetadata? localMetadata,
    SyncMetadata? remoteMetadata,
  }) {
    if (remoteItem != null && remoteItem.userId != userId) {
      return ConflictContext(
        userId: userId,
        entityId: remoteItem.id,
        type: ConflictType.userMismatch,
        localMetadata: localMetadata,
        remoteMetadata: remoteMetadata,
        detectedAt: DateTime.now(),
      );
    }

    if (localItem != null && remoteItem == null) {
      return null;
    }

    if (localItem == null && remoteItem != null) {
      return null;
    }

    if (localItem != null && remoteItem != null) {
      if (localItem.isDeleted != remoteItem.isDeleted) {
        return ConflictContext(
          userId: userId,
          entityId: localItem.id,
          type: ConflictType.deletionConflict,
          localMetadata: localMetadata,
          remoteMetadata: remoteMetadata,
          detectedAt: DateTime.now(),
        );
      }

      final localModified = localItem.modifiedAt;
      final remoteModified = remoteItem.modifiedAt;
      if (localModified.difference(remoteModified).abs() >
              const Duration(milliseconds: 10) &&
          localItem.version != remoteItem.version) {
        return ConflictContext(
          userId: userId,
          entityId: localItem.id,
          type: ConflictType.bothModified,
          localMetadata: localMetadata,
          remoteMetadata: remoteMetadata,
          detectedAt: DateTime.now(),
        );
      }
    }

    return null;
  }
}
