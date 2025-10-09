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
  /// Creates a conflict resolution result.
  const ConflictResolution({
    required this.strategy,
    this.resolvedData,
    this.requiresUserInput = false,
    this.message,
  });

  /// Creates a resolution that uses the local version.
  factory ConflictResolution.useLocal(T localData) => ConflictResolution(
        strategy: ResolutionStrategy.useLocal,
        resolvedData: localData,
      );

  /// Creates a resolution that uses the remote version.
  factory ConflictResolution.useRemote(T remoteData) => ConflictResolution(
        strategy: ResolutionStrategy.useRemote,
        resolvedData: remoteData,
      );

  /// Creates a resolution with merged data.
  factory ConflictResolution.merge(T mergedData) => ConflictResolution(
        strategy: ResolutionStrategy.merge,
        resolvedData: mergedData,
      );

  /// Creates a resolution requiring user input.
  factory ConflictResolution.requireUserInput(String message) =>
      ConflictResolution(
        strategy: ResolutionStrategy.askUser,
        requiresUserInput: true,
        message: message,
      );

  /// Creates an aborted resolution.
  factory ConflictResolution.abort(String reason) => ConflictResolution(
        strategy: ResolutionStrategy.abort,
        message: reason,
      );
      
  /// The strategy used to resolve the conflict.
  final ResolutionStrategy strategy;
  
  /// The resolved entity data.
  final T? resolvedData;
  
  /// Whether user input is required.
  final bool requiresUserInput;
  
  /// Optional message about the resolution.
  final String? message;
}
