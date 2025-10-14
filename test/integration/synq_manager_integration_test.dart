import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:synq_manager/synq_manager.dart';

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

    setUpAll(() {
      registerFallbackValue(
        TestEntity(
          id: 'fb',
          userId: 'fb',
          name: 'fb',
          value: 0,
          modifiedAt: DateTime(0),
          createdAt: DateTime(0),
          version: 1,
        ),
      );
      registerFallbackValue(
        <String, dynamic>{},
      );
      registerFallbackValue(
        SyncOperation<TestEntity>(
          id: 'fb',
          userId: 'fb',
          entityId: 'fb',
          type: SyncOperationType.create,
          timestamp: DateTime(0),
        ),
      );
    });

    setUp(() async {
      localAdapter =
          MockLocalAdapter<TestEntity>(fromJson: TestEntity.fromJson);
      remoteAdapter =
          MockRemoteAdapter<TestEntity>(fromJson: TestEntity.fromJson);
      connectivityChecker = MockConnectivityChecker();
      events.clear();
      initEvents.clear();

      manager = SynqManager<TestEntity>(
        localAdapter: localAdapter,
        remoteAdapter: remoteAdapter,
        conflictResolver: LastWriteWinsResolver<TestEntity>(),
        synqConfig: const SynqConfig(), // Use default config
        connectivity: connectivityChecker,
      );

      await manager.initialize();

      manager.eventStream.listen(events.add);
      manager.onInit.listen(initEvents.add);

      // Wait for initial event to be emitted
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });

    tearDown(() async {
      await manager.dispose();
      await connectivityChecker.dispose();
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

      await manager.push(entity, 'user1');

      final localItems = await localAdapter.getAll(userId: 'user1');
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

      await manager.push(entity, 'user1');

      final result = await manager.sync('user1');

      expect(result.isSuccess, isTrue);
      expect(result.syncedCount, 1);
      expect(result.failedCount, 0);

      final remoteItems = await remoteAdapter.fetchAll('user1');
      expect(remoteItems, hasLength(1));
      expect(remoteItems.first.name, 'Test Item');

      final remoteMetadata = remoteAdapter.metadataFor('user1');
      expect(remoteMetadata, isNotNull);
      expect(remoteMetadata!.entityCounts, isNotNull);
      expect(remoteMetadata.entityCounts!['TestEntity'], isNotNull);
      expect(remoteMetadata.entityCounts!['TestEntity']!.count, 1);
      expect(remoteMetadata.entityCounts!['TestEntity']!.hash, isNotEmpty);

      expect(remoteMetadata.dataHash?.isNotEmpty, isTrue);

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

      final localItems = await manager.getAll(userId: 'user1');
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

      await localAdapter.push(localEntity, 'user1');
      remoteAdapter.addRemoteItem('user1', remoteEntity);

      final result = await manager.sync('user1');

      expect(result.isSuccess, isTrue);
      expect(result.conflictsResolved, greaterThan(0));

      final localItems = await manager.getAll(userId: 'user1');
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

      await manager.push(entity, 'user1');
      await manager.sync('user1');

      expect(await remoteAdapter.fetchAll('user1'), hasLength(1));

      await manager.delete('entity1', 'user1');

      expect(await manager.getAll(userId: 'user1'), isEmpty);

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

      await manager.push(entity, 'user1');

      remoteAdapter.connected = false;
      connectivityChecker.connected = false;

      expect(
        () => manager.sync('user1'),
        throwsA(isA<Exception>()),
      );

      final pendingCount = await manager.getPendingCount('user1');
      expect(pendingCount, 1);
    });

    test('tracks sync statistics', () async {
      final entity = TestEntity.create('entity1', 'user1', 'Test Item');

      await manager.push(entity, 'user1');
      await manager.sync('user1');

      final stats = await manager.getSyncStatistics('user1');

      expect(stats.totalSyncs, 1);
      expect(stats.successfulSyncs, 1);
      expect(stats.failedSyncs, 0);
    });

    test('retrieves entity by id', () async {
      final entity = TestEntity.create('entity1', 'user1', 'Test Item');
      await manager.push(entity, 'user1');

      final retrieved = await manager.getById('entity1', 'user1');

      expect(retrieved, isNotNull);
      expect(retrieved!.name, 'Test Item');
    });

    test('returns null when entity does not exist', () async {
      final retrieved = await manager.getById('nonexistent', 'user1');

      expect(retrieved, isNull);
    });

    test('getByIds fetches multiple items correctly', () async {
      final entity1 = TestEntity.create('e1', 'user1', 'Item 1');
      final entity2 = TestEntity.create('e2', 'user1', 'Item 2');
      await localAdapter.push(entity1, 'user1');
      await localAdapter.push(entity2, 'user1');

      final result = await localAdapter.getByIds(['e1', 'e2', 'e3'], 'user1');

      expect(result, isA<Map<String, TestEntity>>());
      expect(result.length, 2);
      expect(result.containsKey('e1'), isTrue);
      expect(result.containsKey('e2'), isTrue);
      expect(result.containsKey('e3'), isFalse);
      expect(result['e1']!.name, 'Item 1');
    });

    test('transaction rolls back on error', () async {
      final entity1 = TestEntity.create('tx1', 'user1', 'TX Item 1');
      // Attempt a transaction that will fail
      await expectLater(
        localAdapter.transaction(() async {
          await localAdapter.push(entity1, 'user1');
          // This should be present inside the transaction
          expect(await localAdapter.getById('tx1', 'user1'), isNotNull);
          throw Exception('Simulated transaction failure');
        }),
        throwsA(isA<Exception>()),
      );

      // Verify that the save was rolled back
      final retrieved = await localAdapter.getById('tx1', 'user1');
      expect(retrieved, isNull);
    });
  });
}
