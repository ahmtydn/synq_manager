import 'package:flutter_test/flutter_test.dart';
import 'package:synq_manager/src/models/conflict_context.dart';
import 'package:synq_manager/src/models/conflict_resolution.dart';
import 'package:synq_manager/src/resolvers/last_write_wins_resolver.dart';
import 'package:synq_manager/src/resolvers/local_priority_resolver.dart';
import 'package:synq_manager/src/resolvers/remote_priority_resolver.dart';

import '../mocks/test_entity.dart';

void main() {
  group('LastWriteWinsResolver', () {
    late LastWriteWinsResolver<TestEntity> resolver;

    setUp(() {
      resolver = LastWriteWinsResolver<TestEntity>();
    });

    test('chooses remote when remote is newer', () async {
      final baseTime = DateTime.now();
      final local = TestEntity(
        id: 'entity1',
        userId: 'user1',
        name: 'Local',
        value: 42,
        modifiedAt: baseTime,
        createdAt: baseTime,
        version: 1,
      );

      final remote = TestEntity(
        id: 'entity1',
        userId: 'user1',
        name: 'Remote',
        value: 100,
        modifiedAt: baseTime.add(const Duration(seconds: 10)),
        createdAt: baseTime,
        version: 2,
      );

      final context = ConflictContext(
        userId: 'user1',
        entityId: 'entity1',
        type: ConflictType.bothModified,
        detectedAt: DateTime.now(),
      );

      final resolution = await resolver.resolve(
        localItem: local,
        remoteItem: remote,
        context: context,
      );

      expect(resolution.strategy, ResolutionStrategy.useRemote);
      expect(resolution.resolvedData, equals(remote));
    });

    test('chooses local when local is newer', () async {
      final baseTime = DateTime.now();
      final local = TestEntity(
        id: 'entity1',
        userId: 'user1',
        name: 'Local',
        value: 42,
        modifiedAt: baseTime.add(const Duration(seconds: 10)),
        createdAt: baseTime,
        version: 2,
      );

      final remote = TestEntity(
        id: 'entity1',
        userId: 'user1',
        name: 'Remote',
        value: 100,
        modifiedAt: baseTime,
        createdAt: baseTime,
        version: 1,
      );

      final context = ConflictContext(
        userId: 'user1',
        entityId: 'entity1',
        type: ConflictType.bothModified,
        detectedAt: DateTime.now(),
      );

      final resolution = await resolver.resolve(
        localItem: local,
        remoteItem: remote,
        context: context,
      );

      expect(resolution.strategy, ResolutionStrategy.useLocal);
      expect(resolution.resolvedData, equals(local));
    });

    test('chooses remote when only remote exists', () async {
      final remote = TestEntity(
        id: 'entity1',
        userId: 'user1',
        name: 'Remote',
        value: 100,
        modifiedAt: DateTime.now(),
        createdAt: DateTime.now(),
        version: 1,
      );

      final context = ConflictContext(
        userId: 'user1',
        entityId: 'entity1',
        type: ConflictType.bothModified,
        detectedAt: DateTime.now(),
      );

      final resolution = await resolver.resolve(
        localItem: null,
        remoteItem: remote,
        context: context,
      );

      expect(resolution.strategy, ResolutionStrategy.useRemote);
      expect(resolution.resolvedData, equals(remote));
    });

    test('chooses local when only local exists', () async {
      final local = TestEntity(
        id: 'entity1',
        userId: 'user1',
        name: 'Local',
        value: 42,
        modifiedAt: DateTime.now(),
        createdAt: DateTime.now(),
        version: 1,
      );

      final context = ConflictContext(
        userId: 'user1',
        entityId: 'entity1',
        type: ConflictType.bothModified,
        detectedAt: DateTime.now(),
      );

      final resolution = await resolver.resolve(
        localItem: local,
        remoteItem: null,
        context: context,
      );

      expect(resolution.strategy, ResolutionStrategy.useLocal);
      expect(resolution.resolvedData, equals(local));
    });
  });

  group('LocalPriorityResolver', () {
    late LocalPriorityResolver<TestEntity> resolver;

    setUp(() {
      resolver = LocalPriorityResolver<TestEntity>();
    });

    test('always chooses local when it exists', () async {
      final local = TestEntity(
        id: 'entity1',
        userId: 'user1',
        name: 'Local',
        value: 42,
        modifiedAt: DateTime.now(),
        createdAt: DateTime.now(),
        version: 1,
      );

      final remote = TestEntity(
        id: 'entity1',
        userId: 'user1',
        name: 'Remote',
        value: 100,
        modifiedAt: DateTime.now().add(const Duration(seconds: 10)),
        createdAt: DateTime.now(),
        version: 2,
      );

      final context = ConflictContext(
        userId: 'user1',
        entityId: 'entity1',
        type: ConflictType.bothModified,
        detectedAt: DateTime.now(),
      );

      final resolution = await resolver.resolve(
        localItem: local,
        remoteItem: remote,
        context: context,
      );

      expect(resolution.strategy, ResolutionStrategy.useLocal);
      expect(resolution.resolvedData, equals(local));
    });

    test('uses remote when local does not exist', () async {
      final remote = TestEntity(
        id: 'entity1',
        userId: 'user1',
        name: 'Remote',
        value: 100,
        modifiedAt: DateTime.now(),
        createdAt: DateTime.now(),
        version: 1,
      );

      final context = ConflictContext(
        userId: 'user1',
        entityId: 'entity1',
        type: ConflictType.bothModified,
        detectedAt: DateTime.now(),
      );

      final resolution = await resolver.resolve(
        localItem: null,
        remoteItem: remote,
        context: context,
      );

      expect(resolution.strategy, ResolutionStrategy.useRemote);
      expect(resolution.resolvedData, equals(remote));
    });
  });

  group('RemotePriorityResolver', () {
    late RemotePriorityResolver<TestEntity> resolver;

    setUp(() {
      resolver = RemotePriorityResolver<TestEntity>();
    });

    test('always chooses remote when it exists', () async {
      final local = TestEntity(
        id: 'entity1',
        userId: 'user1',
        name: 'Local',
        value: 42,
        modifiedAt: DateTime.now().add(const Duration(seconds: 10)),
        createdAt: DateTime.now(),
        version: 2,
      );

      final remote = TestEntity(
        id: 'entity1',
        userId: 'user1',
        name: 'Remote',
        value: 100,
        modifiedAt: DateTime.now(),
        createdAt: DateTime.now(),
        version: 1,
      );

      final context = ConflictContext(
        userId: 'user1',
        entityId: 'entity1',
        type: ConflictType.bothModified,
        detectedAt: DateTime.now(),
      );

      final resolution = await resolver.resolve(
        localItem: local,
        remoteItem: remote,
        context: context,
      );

      expect(resolution.strategy, ResolutionStrategy.useRemote);
      expect(resolution.resolvedData, equals(remote));
    });

    test('uses local when remote does not exist', () async {
      final local = TestEntity(
        id: 'entity1',
        userId: 'user1',
        name: 'Local',
        value: 42,
        modifiedAt: DateTime.now(),
        createdAt: DateTime.now(),
        version: 1,
      );

      final context = ConflictContext(
        userId: 'user1',
        entityId: 'entity1',
        type: ConflictType.bothModified,
        detectedAt: DateTime.now(),
      );

      final resolution = await resolver.resolve(
        localItem: local,
        remoteItem: null,
        context: context,
      );

      expect(resolution.strategy, ResolutionStrategy.useLocal);
      expect(resolution.resolvedData, equals(local));
    });
  });
}
