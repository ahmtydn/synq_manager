import 'package:synq_manager/src/models/conflict_context.dart';
import 'package:synq_manager/src/models/conflict_resolution.dart';
import 'package:synq_manager/src/models/syncable_entity.dart';
import 'package:synq_manager/src/resolvers/sync_conflict_resolver.dart';

class RemotePriorityResolver<T extends SyncableEntity>
    extends SyncConflictResolver<T> {
  @override
  Future<ConflictResolution<T>> resolve({
    required T? localItem,
    required T? remoteItem,
    required ConflictContext context,
  }) async {
    if (remoteItem != null) {
      return ConflictResolution.useRemote(remoteItem);
    }

    if (localItem != null) {
      return ConflictResolution.useLocal(localItem);
    }

    return ConflictResolution.abort('No data available to resolve conflict.');
  }

  @override
  String get name => 'RemotePriority';
}
