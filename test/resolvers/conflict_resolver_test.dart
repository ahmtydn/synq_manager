import 'package:flutter_test/flutter_test.dart';
import 'package:synq_manager/src/models/conflict_context.dart';
import 'package:synq_manager/src/models/conflict_resolution.dart';
import 'package:synq_manager/src/resolvers/last_write_wins_resolver.dart';
import 'package:synq_manager/src/resolvers/local_priority_resolver.dart';
import 'package:synq_manager/src/resolvers/merge_resolver.dart';
import 'package:synq_manager/src/resolvers/remote_priority_resolver.dart';
import 'package:synq_manager/src/resolvers/user_prompt_resolver.dart';

import '../mocks/test_entity.dart';

class TestMergeResolver extends MergeResolver<TestEntity> {
  @override
  Future<TestEntity> merge(
    TestEntity? localItem,
    TestEntity? remoteItem,
    ConflictContext context,
  ) async {
    if (localItem != null) return localItem;
    if (remoteItem != null) return remoteItem;
    throw Exception('Both items cannot be null for a successful merge');
  }
}

void main() {
  group('Conflict Resolvers', () {
    final context = ConflictContext(
      type: ConflictType.bothModified,
      entityId: 'test-id',
      userId: 'test-user',
      detectedAt: DateTime.now(),
    );

    group('MergeResolver', () {
      test('should abort when both local and remote items are null', () async {
        // Arrange
        final resolver = TestMergeResolver();

        // Act
        final resolution = await resolver.resolve(
          localItem: null,
          remoteItem: null,
          context: context,
        );

        // Assert
        expect(resolution.strategy, ResolutionStrategy.abort);
        expect(
          resolution.message,
          'No entities supplied to merge resolver.',
        );
      });
    });

    group('LocalPriorityResolver', () {
      test('should abort when both local and remote items are null', () async {
        // Arrange
        final resolver = LocalPriorityResolver<TestEntity>();

        // Act
        final resolution = await resolver.resolve(
          localItem: null,
          remoteItem: null,
          context: context,
        );

        // Assert
        expect(resolution.strategy, ResolutionStrategy.abort);
        expect(resolution.message, 'No data available to resolve conflict.');
      });
    });

    group('RemotePriorityResolver', () {
      test('should abort when both local and remote items are null', () async {
        // Arrange
        final resolver = RemotePriorityResolver<TestEntity>();

        // Act
        final resolution = await resolver.resolve(
          localItem: null,
          remoteItem: null,
          context: context,
        );

        // Assert
        expect(resolution.strategy, ResolutionStrategy.abort);
        expect(resolution.message, 'No data available to resolve conflict.');
      });
    });

    group('LastWriteWinsResolver', () {
      test('should abort when both local and remote items are null', () async {
        final resolver = LastWriteWinsResolver<TestEntity>();
        final resolution = await resolver.resolve(
          localItem: null,
          remoteItem: null,
          context: context,
        );
        expect(resolution.strategy, ResolutionStrategy.abort);
        expect(resolution.message, 'No data available for resolution.');
      });
    });

    group('UserPromptResolver', () {
      late TestEntity localItem;
      late TestEntity remoteItem;
      late ConflictContext context;

      setUp(() {
        localItem = TestEntity(
          id: 'entity1',
          userId: 'user1',
          name: 'Local',
          value: 42,
          modifiedAt: DateTime.now(),
          createdAt: DateTime.now(),
          version: 1,
        );
        remoteItem = TestEntity(
          id: 'entity1',
          userId: 'user1',
          name: 'Remote',
          value: 100,
          modifiedAt: DateTime.now().add(const Duration(seconds: 10)),
          createdAt: DateTime.now(),
          version: 2,
        );
        context = ConflictContext(
          type: ConflictType.bothModified,
          entityId: 'entity1',
          userId: 'user1',
          detectedAt: DateTime.now(),
        );
      });

      test('should use local when user chooses useLocal', () async {
        // Arrange
        final resolver = UserPromptResolver<TestEntity>(
          promptUser: (ctx, local, remote) async => ResolutionStrategy.useLocal,
        );

        // Act
        final resolution = await resolver.resolve(
          localItem: localItem,
          remoteItem: remoteItem,
          context: context,
        );

        // Assert
        expect(resolution.strategy, ResolutionStrategy.useLocal);
        expect(resolution.resolvedData, localItem);
      });

      test('should abort when user chooses useLocal but local is null',
          () async {
        // Arrange
        final resolver = UserPromptResolver<TestEntity>(
          promptUser: (ctx, local, remote) async => ResolutionStrategy.useLocal,
        );

        // Act
        final resolution = await resolver.resolve(
          localItem: null,
          remoteItem: remoteItem,
          context: context,
        );

        // Assert
        expect(resolution.strategy, ResolutionStrategy.abort);
        expect(
          resolution.message,
          'Local data unavailable for chosen strategy.',
        );
      });

      test('should use remote when user chooses useRemote', () async {
        // Arrange
        final resolver = UserPromptResolver<TestEntity>(
          promptUser: (ctx, local, remote) async =>
              ResolutionStrategy.useRemote,
        );

        // Act
        final resolution = await resolver.resolve(
          localItem: localItem,
          remoteItem: remoteItem,
          context: context,
        );

        // Assert
        expect(resolution.strategy, ResolutionStrategy.useRemote);
        expect(resolution.resolvedData, remoteItem);
      });

      test('should abort when user chooses useRemote but remote is null',
          () async {
        // Arrange
        final resolver = UserPromptResolver<TestEntity>(
          promptUser: (ctx, local, remote) async =>
              ResolutionStrategy.useRemote,
        );

        // Act
        final resolution = await resolver.resolve(
          localItem: localItem,
          remoteItem: null,
          context: context,
        );

        // Assert
        expect(resolution.strategy, ResolutionStrategy.abort);
        expect(
          resolution.message,
          'Remote data unavailable for chosen strategy.',
        );
      });

      test('should merge when user chooses merge', () async {
        // Arrange
        final resolver = UserPromptResolver<TestEntity>(
          promptUser: (ctx, local, remote) async => ResolutionStrategy.merge,
        );

        // Act
        final resolution = await resolver.resolve(
          localItem: localItem,
          remoteItem: remoteItem,
          context: context,
        );

        // Assert
        expect(resolution.strategy, ResolutionStrategy.merge);
        // The default merge behavior in the test resolver is to use local
        expect(resolution.resolvedData, localItem);
      });

      test('should abort when user chooses abort', () async {
        // Arrange
        final resolver = UserPromptResolver<TestEntity>(
          promptUser: (ctx, local, remote) async => ResolutionStrategy.abort,
        );

        // Act
        final resolution = await resolver.resolve(
          localItem: localItem,
          remoteItem: remoteItem,
          context: context,
        );

        // Assert
        expect(resolution.strategy, ResolutionStrategy.abort);
        expect(resolution.message, 'User cancelled');
      });
    });
  });
}
