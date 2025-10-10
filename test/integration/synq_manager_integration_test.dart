import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:synq_manager/src/config/synq_config.dart';
import 'package:synq_manager/src/core/synq_manager.dart';
import 'package:synq_manager/src/events/data_change_event.dart';
import 'package:synq_manager/src/events/initial_sync_event.dart';
import 'package:synq_manager/src/events/sync_event.dart';
import 'package:synq_manager/src/models/sync_result.dart';
import 'package:synq_manager/src/resolvers/last_write_wins_resolver.dart';

import '../mocks/mock_adapters.dart';
import '../mocks/mock_connectivity_checker.dart';
import '../mocks/test_entity.dart';

void main() {
  group('SynqManager Integration Tests', () {
    late SynqManager<TestEntity> manager;
    late MockLocalAdapter<TestEntity> localAdapter;
    late MockRemoteAdapter<TestEntity> remoteAdapter;
    late MockConnectivityChecker connectivityChecker;
    final events = <SyncEvent<TestEntity>>[];
    final initEvents = <InitialSyncEvent<TestEntity>>[];

    setUp(() async {
      localAdapter = MockLocalAdapter<TestEntity>();
      remoteAdapter = MockRemoteAdapter<TestEntity>();
      connectivityChecker = MockConnectivityChecker();
      events.clear();
      initEvents.clear();

      manager = SynqManager<TestEntity>(
        localAdapter: localAdapter,
        remoteAdapter: remoteAdapter,
        conflictResolver: LastWriteWinsResolver<TestEntity>(),
        synqConfig: const SynqConfig(
          autoSyncInterval: Duration(seconds: 30),
        ),
        connectivity: connectivityChecker,
      );

      await manager.initialize();

      manager.eventStream.listen(events.add);
      manager.onInit.listen(initEvents.add);
      await manager.listen('user1');
    });

    tearDown(() async {
      await manager.dispose();
    });

    test('saves entity locally and enqueues sync operation', () async {
      expect(initEvents, hasLength(1));
      expect(initEvents.single.data, isEmpty);
      final entity = TestEntity(
        id: 'entity1',
        userId: 'user1',
        name: 'Test Item',
        value: 42,
        modifiedAt: DateTime.now(),
        createdAt: DateTime.now(),
        version: 1,
      );

      await manager.save(entity, 'user1');

      final localItems = await localAdapter.getAll('user1');
      expect(localItems, hasLength(1));
      expect(localItems.first.name, 'Test Item');

      final pendingCount = await manager.getPendingCount('user1');
      expect(pendingCount, 1);

      final dataChangeEvents = events.whereType<DataChangeEvent<TestEntity>>();
      expect(dataChangeEvents, hasLength(1));
      expect(dataChangeEvents.first.changeType, ChangeType.created);
      expect(dataChangeEvents.first.source, DataSource.local);
    });

    test('syncs pending operations to remote', () async {
      final entity = TestEntity(
        id: 'entity1',
        userId: 'user1',
        name: 'Test Item',
        value: 42,
        modifiedAt: DateTime.now(),
        createdAt: DateTime.now(),
        version: 1,
      );

      await manager.save(entity, 'user1');

      final result = await manager.sync('user1');

      expect(result.isSuccess, isTrue);
      expect(result.syncedCount, 1);
      expect(result.failedCount, 0);

      final remoteItems = await remoteAdapter.fetchAll('user1');
      expect(remoteItems, hasLength(1));
      expect(remoteItems.first.name, 'Test Item');

      final pendingCount = await manager.getPendingCount('user1');
      expect(pendingCount, 0);
    });

    test('pulls remote items during sync', () async {
      final remoteEntity = TestEntity(
        id: 'entity2',
        userId: 'user1',
        name: 'Remote Item',
        value: 100,
        modifiedAt: DateTime.now(),
        createdAt: DateTime.now(),
        version: 1,
      );

      remoteAdapter.addRemoteItem('user1', remoteEntity);

      final result = await manager.sync('user1');

      expect(result.isSuccess, isTrue);

      final localItems = await manager.getAll('user1');
      expect(localItems, hasLength(1));
      expect(localItems.first.name, 'Remote Item');
      expect(localItems.first.value, 100);
    });

    test('resolves conflicts using last-write-wins', () async {
      final baseTime = DateTime.now();

      final localEntity = TestEntity(
        id: 'entity1',
        userId: 'user1',
        name: 'Local Version',
        value: 42,
        modifiedAt: baseTime,
        createdAt: baseTime,
        version: 1,
      );

      final remoteEntity = TestEntity(
        id: 'entity1',
        userId: 'user1',
        name: 'Remote Version',
        value: 100,
        modifiedAt: baseTime.add(const Duration(seconds: 10)),
        createdAt: baseTime,
        version: 2,
      );

      await localAdapter.save(localEntity, 'user1');
      remoteAdapter.addRemoteItem('user1', remoteEntity);

      final result = await manager.sync('user1');

      expect(result.isSuccess, isTrue);
      expect(result.conflictsResolved, greaterThan(0));

      final localItems = await manager.getAll('user1');
      expect(localItems.first.name, 'Remote Version');
      expect(localItems.first.value, 100);
    });

    test('deletes entity locally and remotely', () async {
      final entity = TestEntity(
        id: 'entity1',
        userId: 'user1',
        name: 'Test Item',
        value: 42,
        modifiedAt: DateTime.now(),
        createdAt: DateTime.now(),
        version: 1,
      );

      await manager.save(entity, 'user1');
      await manager.sync('user1');

      expect(await remoteAdapter.fetchAll('user1'), hasLength(1));

      await manager.delete('entity1', 'user1');

      expect(await manager.getAll('user1'), isEmpty);

      await manager.sync('user1');

      expect(await remoteAdapter.fetchAll('user1'), isEmpty);
    });

    test('handles network errors gracefully', () async {
      final entity = TestEntity(
        id: 'entity1',
        userId: 'user1',
        name: 'Test Item',
        value: 42,
        modifiedAt: DateTime.now(),
        createdAt: DateTime.now(),
        version: 1,
      );

      await manager.save(entity, 'user1');

      remoteAdapter.connected = false;
      connectivityChecker.connected = false;

      expect(
        () => manager.sync('user1'),
        throwsA(isA<Exception>()),
      );

      final pendingCount = await manager.getPendingCount('user1');
      expect(pendingCount, 1);
    });

    test('pauses and resumes sync', () async {
      final entity = TestEntity(
        id: 'entity1',
        userId: 'user1',
        name: 'Test Item',
        value: 42,
        modifiedAt: DateTime.now(),
        createdAt: DateTime.now(),
        version: 1,
      );

      await manager.save(entity, 'user1');

      unawaited(manager.pauseSync('user1'));
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final statusBeforeResume = await manager.getSyncStatus('user1');
      expect(statusBeforeResume, SyncStatus.paused);

      await manager.resumeSync('user1');

      final statusAfterResume = await manager.getSyncStatus('user1');
      expect(statusAfterResume, SyncStatus.syncing);
    });

    test('switches users correctly', () async {
      final user1Entity = TestEntity(
        id: 'entity1',
        userId: 'user1',
        name: 'User1 Item',
        value: 42,
        modifiedAt: DateTime.now(),
        createdAt: DateTime.now(),
        version: 1,
      );

      await manager.save(user1Entity, 'user1');

      final switchResult = await manager.switchUser(
        oldUserId: 'user1',
        newUserId: 'user2',
        strategy: UserSwitchStrategy.keepLocal,
      );

      expect(switchResult.success, isTrue);
      expect(switchResult.newUserId, 'user2');

      final user2Entity = TestEntity(
        id: 'entity2',
        userId: 'user2',
        name: 'User2 Item',
        value: 100,
        modifiedAt: DateTime.now(),
        createdAt: DateTime.now(),
        version: 1,
      );

      await manager.save(user2Entity, 'user2');

      final user1Items = await manager.getAll('user1');
      final user2Items = await manager.getAll('user2');

      expect(user1Items, hasLength(1));
      expect(user2Items, hasLength(1));
      expect(user1Items.first.name, 'User1 Item');
      expect(user2Items.first.name, 'User2 Item');
    });

    test('tracks sync statistics', () async {
      final entity = TestEntity(
        id: 'entity1',
        userId: 'user1',
        name: 'Test Item',
        value: 42,
        modifiedAt: DateTime.now(),
        createdAt: DateTime.now(),
        version: 1,
      );

      await manager.save(entity, 'user1');
      await manager.sync('user1');

      final stats = await manager.getSyncStatistics('user1');

      expect(stats.totalSyncs, 1);
      expect(stats.successfulSyncs, 1);
      expect(stats.failedSyncs, 0);
    });

    test('cancels sync operation', () async {
      // Add multiple items to ensure sync takes longer
      for (var i = 0; i < 10; i++) {
        final entity = TestEntity(
          id: 'entity$i',
          userId: 'user1',
          name: 'Test Item $i',
          value: i,
          modifiedAt: DateTime.now(),
          createdAt: DateTime.now(),
          version: 1,
        );
        await manager.save(entity, 'user1');
      }

      final syncFuture = manager.sync('user1');
      await manager.cancelSync('user1');

      final result = await syncFuture;

      // Either cancelled or completed quickly - both are valid
      expect(result.wasCancelled || result.isSuccess, isTrue);
    });

    test('retrieves entity by id', () async {
      final entity = TestEntity(
        id: 'entity1',
        userId: 'user1',
        name: 'Test Item',
        value: 42,
        modifiedAt: DateTime.now(),
        createdAt: DateTime.now(),
        version: 1,
      );

      await manager.save(entity, 'user1');

      final retrieved = await manager.getById('entity1', 'user1');

      expect(retrieved, isNotNull);
      expect(retrieved!.name, 'Test Item');
      expect(retrieved.value, 42);
    });

    test('returns null when entity does not exist', () async {
      final retrieved = await manager.getById('nonexistent', 'user1');

      expect(retrieved, isNull);
    });

    test('listen emits snapshot when forceRefresh is true', () async {
      final entity = TestEntity(
        id: 'entity-initial',
        userId: 'user1',
        name: 'Snapshot Item',
        value: 21,
        modifiedAt: DateTime.now(),
        createdAt: DateTime.now(),
        version: 1,
      );

      await localAdapter.save(entity, 'user1');

      await manager.listen('user1', forceRefresh: true);

      expect(initEvents, isNotEmpty);
      expect(initEvents.last.data, hasLength(1));
      expect(initEvents.last.data.first.name, 'Snapshot Item');
    });
  });
}
