import 'package:synq_manager/src/models/conflict_context.dart';
import 'package:synq_manager/src/models/conflict_resolution.dart';
import 'package:synq_manager/src/models/syncable_entity.dart';
import 'package:synq_manager/src/resolvers/sync_conflict_resolver.dart';

/// Resolver that allows subclasses to provide custom merge logic.
abstract class MergeResolver<T extends SyncableEntity>
    extends SyncConflictResolver<T> {
  @override
  Future<ConflictResolution<T>> resolve({
    required T? localItem,
    required T? remoteItem,
    required ConflictContext context,
  }) async {
    if (localItem == null && remoteItem == null) {
      return ConflictResolution.abort(
        'No entities supplied to merge resolver.',
      );
    }

    final merged = await merge(localItem, remoteItem, context);
    return ConflictResolution.merge(merged);
  }

  /// Hook for implementing merge logic in subclasses.
  Future<T> merge(T? localItem, T? remoteItem, ConflictContext context);

  @override
  String get name => 'Merge';
}
