import 'package:synq_manager/src/models/conflict_context.dart';
import 'package:synq_manager/src/models/conflict_resolution.dart';
import 'package:synq_manager/src/models/syncable_entity.dart';

/// Base interface for components that resolve synchronization conflicts.
abstract class SyncConflictResolver<T extends SyncableEntity> {
  /// Resolves a conflict between local and remote data.
  Future<ConflictResolution<T>> resolve({
    required T? localItem,
    required T? remoteItem,
    required ConflictContext context,
  });

  /// Name of the resolver strategy.
  String get name;
}
