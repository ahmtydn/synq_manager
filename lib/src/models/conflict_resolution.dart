import 'package:synq_manager/src/models/syncable_entity.dart';

/// Strategies used when resolving conflicts.
enum ResolutionStrategy {
  useLocal,
  useRemote,
  merge,
  askUser,
  abort,
}

/// Result of a conflict resolution attempt.
class ConflictResolution<T extends SyncableEntity> {
  const ConflictResolution({
    required this.strategy,
    this.resolvedData,
    this.requiresUserInput = false,
    this.message,
  });

  factory ConflictResolution.useLocal(T localData) => ConflictResolution(
        strategy: ResolutionStrategy.useLocal,
        resolvedData: localData,
      );

  factory ConflictResolution.useRemote(T remoteData) => ConflictResolution(
        strategy: ResolutionStrategy.useRemote,
        resolvedData: remoteData,
      );

  factory ConflictResolution.merge(T mergedData) => ConflictResolution(
        strategy: ResolutionStrategy.merge,
        resolvedData: mergedData,
      );

  factory ConflictResolution.requireUserInput(String message) =>
      ConflictResolution(
        strategy: ResolutionStrategy.askUser,
        requiresUserInput: true,
        message: message,
      );

  factory ConflictResolution.abort(String reason) => ConflictResolution(
        strategy: ResolutionStrategy.abort,
        message: reason,
      );
  final ResolutionStrategy strategy;
  final T? resolvedData;
  final bool requiresUserInput;
  final String? message;
}
