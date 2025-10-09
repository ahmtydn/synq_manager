import 'package:synq_manager/src/models/conflict_context.dart';
import 'package:synq_manager/src/models/conflict_resolution.dart';
import 'package:synq_manager/src/models/syncable_entity.dart';
import 'package:synq_manager/src/resolvers/sync_conflict_resolver.dart';

class LastWriteWinsResolver<T extends SyncableEntity>
    extends SyncConflictResolver<T> {
  @override
  Future<ConflictResolution<T>> resolve({
    required T? localItem,
    required T? remoteItem,
    required ConflictContext context,
  }) async {
    if (localItem == null && remoteItem == null) {
      return ConflictResolution.abort('No data available for resolution.');
    }

    if (localItem == null) {
      return ConflictResolution.useRemote(remoteItem!);
    }

    if (remoteItem == null) {
      return ConflictResolution.useLocal(localItem);
    }

    if (localItem.modifiedAt.isAfter(remoteItem.modifiedAt)) {
      return ConflictResolution.useLocal(localItem);
    }

    return ConflictResolution.useRemote(remoteItem);
  }

  @override
  String get name => 'LastWriteWins';
}
