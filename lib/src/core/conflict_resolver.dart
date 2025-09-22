import 'package:synq_manager/src/domain/conflict_event.dart';
import 'package:synq_manager/src/domain/sync_entity.dart';

/// Abstract interface for resolving conflicts between local and remote entities
/// Provides hooks for the host application to handle conflicts
abstract class ConflictResolver<T extends SyncEntity> {
  /// Resolve a conflict between local and remote entities
  /// Returns the entity that should be kept or a merged entity
  Future<T> resolve(ConflictEvent<T> conflictEvent);

  /// Get the resolution strategy for automatic conflict resolution
  ConflictResolutionStrategy get strategy;

  /// Set a custom resolution callback
  void setResolutionCallback(Future<T> Function(ConflictEvent<T>) callback);
}

/// Default implementation of ConflictResolver
class DefaultConflictResolver<T extends SyncEntity>
    implements ConflictResolver<T> {
  DefaultConflictResolver({
    this.strategy = ConflictResolutionStrategy.prompt,
    this.resolutionCallback,
    this.timeoutDuration = const Duration(minutes: 5),
  });

  @override
  final ConflictResolutionStrategy strategy;

  /// Custom callback for conflict resolution
  Future<T> Function(ConflictEvent<T>)? resolutionCallback;

  /// Timeout for conflict resolution
  final Duration timeoutDuration;

  @override
  Future<T> resolve(ConflictEvent<T> conflictEvent) async {
    switch (strategy) {
      case ConflictResolutionStrategy.localWins:
        return conflictEvent.localEntity;

      case ConflictResolutionStrategy.remoteWins:
        return conflictEvent.remoteEntity;

      case ConflictResolutionStrategy.newerWins:
        return conflictEvent.localEntity.updatedAt
                .isAfter(conflictEvent.remoteEntity.updatedAt)
            ? conflictEvent.localEntity
            : conflictEvent.remoteEntity;

      case ConflictResolutionStrategy.prompt:
        if (resolutionCallback != null) {
          return resolutionCallback!(conflictEvent).timeout(timeoutDuration);
        }
        // Fallback to newer wins if no callback is set
        return conflictEvent.localEntity.updatedAt
                .isAfter(conflictEvent.remoteEntity.updatedAt)
            ? conflictEvent.localEntity
            : conflictEvent.remoteEntity;

      case ConflictResolutionStrategy.merge:
        // Default merge strategy - subclasses should override for custom merging
        return mergeEntities(
          conflictEvent.localEntity,
          conflictEvent.remoteEntity,
        );
    }
  }

  /// Override this method to implement custom merge logic
  Future<T> mergeEntities(T local, T remote) async {
    // Default implementation: choose newer entity
    return local.updatedAt.isAfter(remote.updatedAt) ? local : remote;
  }

  @override
  void setResolutionCallback(Future<T> Function(ConflictEvent<T>) callback) {
    resolutionCallback = callback;
  }
}

/// Strategies for automatic conflict resolution
enum ConflictResolutionStrategy {
  /// Always keep the local version
  localWins,

  /// Always keep the remote version
  remoteWins,

  /// Keep the version with the newer timestamp
  newerWins,

  /// Prompt the user to choose (requires callback)
  prompt,

  /// Attempt to merge the entities (requires custom implementation)
  merge,
}
