import 'package:synq_manager/src/models/conflict_context.dart';
import 'package:synq_manager/src/models/conflict_resolution.dart';
import 'package:synq_manager/src/models/syncable_entity.dart';
import 'package:synq_manager/src/resolvers/sync_conflict_resolver.dart';

/// Resolves conflicts by prompting the user to choose.
class UserPromptResolver<T extends SyncableEntity>
    extends SyncConflictResolver<T> {
  /// Creates a user prompt resolver with a custom prompt function.
  UserPromptResolver({required this.promptUser});

  /// Function that prompts the user to choose a resolution strategy.
  final Future<ResolutionStrategy> Function(
    ConflictContext context,
    T? local,
    T? remote,
  ) promptUser;

  @override
  Future<ConflictResolution<T>> resolve({
    required T? localItem,
    required T? remoteItem,
    required ConflictContext context,
  }) async {
    final choice = await promptUser(context, localItem, remoteItem);

    switch (choice) {
      case ResolutionStrategy.useLocal:
        if (localItem == null) {
          return ConflictResolution.abort(
            'Local data unavailable for chosen strategy.',
          );
        }
        return ConflictResolution.useLocal(localItem);
      case ResolutionStrategy.useRemote:
        if (remoteItem == null) {
          return ConflictResolution.abort(
            'Remote data unavailable for chosen strategy.',
          );
        }
        return ConflictResolution.useRemote(remoteItem);
      case ResolutionStrategy.merge:
        if (localItem != null) {
          return ConflictResolution.merge(localItem);
        }
        if (remoteItem != null) {
          return ConflictResolution.merge(remoteItem);
        }
        return ConflictResolution.abort('No data available to merge.');
      case ResolutionStrategy.askUser:
        return ConflictResolution.requireUserInput(
          'Additional user input required.',
        );
      case ResolutionStrategy.abort:
        return ConflictResolution.abort('User cancelled');
    }
  }

  @override
  String get name => 'UserPrompt';
}
