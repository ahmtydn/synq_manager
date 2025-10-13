import 'package:flutter_test/flutter_test.dart';
import 'package:synq_manager/src/models/conflict_context.dart';
import 'package:synq_manager/src/models/conflict_resolution.dart';
import 'package:synq_manager/src/resolvers/last_write_wins_resolver.dart';
import 'package:synq_manager/src/resolvers/local_priority_resolver.dart';
import 'package:synq_manager/src/resolvers/merge_resolver.dart';
import 'package:synq_manager/src/resolvers/remote_priority_resolver.dart';

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
  });
}
