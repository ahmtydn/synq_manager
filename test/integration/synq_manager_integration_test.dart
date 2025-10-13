import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:synq_manager/src/models/user_switch_strategy.dart';
import 'package:synq_manager/synq_manager.dart';

import '../mocks/mock_adapters.dart';
import '../mocks/mock_connectivity_checker.dart';
import '../mocks/test_entity.dart';

class MockSynqObserver<T extends SyncableEntity> extends Mock
    implements SynqObserver<T> {}

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
        DataSource.local,
      );
      registerFallbackValue(
        const SyncResult(
          userId: 'fb',
          syncedCount: 0,
          failedCount: 0,
          conflictsResolved: 0,
          pendingOperations: [],
          duration: Duration.zero,
        ),
      );
      registerFallbackValue(
        UserSwitchResult.success(newUserId: 'fb'),
      );
      registerFallbackValue(
        ConflictContext(
          userId: 'fb',
          entityId: 'fb',
          type: ConflictType.bothModified,
          detectedAt: DateTime(0),
        ),
      );
      registerFallbackValue(ConflictResolution<TestEntity>.abort('fb'));
      registerFallbackValue(
        SyncOperation<TestEntity>(
          id: 'fb',
          userId: 'fb',
          entityId: 'fb',
          type: SyncOperationType.create,
          timestamp: DateTime(0),
        ),
      );
      registerFallbackValue(StackTrace.empty);
    });

    setUp(() async {
      localAdapter =
          MockLocalAdapter<TestEntity>(fromJson: TestEntity.fromJson);
      remoteAdapter = MockRemoteAdapter<TestEntity>();
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

      await manager.save(entity, 'user1');

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

      await manager.save(entity, 'user1');

      final result = await manager.sync('user1');

      expect(result.isSuccess, isTrue);
      expect(result.syncedCount, 1);
      expect(result.failedCount, 0);

      final remoteItems = await remoteAdapter.fetchAll('user1');
      expect(remoteItems, hasLength(1));
      expect(remoteItems.first.name, 'Test Item');

      final remoteMetadata = remoteAdapter.metadataFor('user1');
      expect(remoteMetadata, isNotNull);
      expect(remoteMetadata!.itemCount, 1);
      expect(remoteMetadata.dataHash.isNotEmpty, isTrue);

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

      await localAdapter.save(localEntity, 'user1');
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

      await manager.save(entity, 'user1');
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

      final user1Items = await manager.getAll(userId: 'user1');
      final user2Items = await manager.getAll(userId: 'user2');

      expect(user1Items, hasLength(1));
      expect(user2Items, hasLength(1));
      expect(user1Items.first.name, 'User1 Item');
      expect(user2Items.first.name, 'User2 Item');
    });

    test('switchUser with syncThenSwitch syncs old user data', () async {
      // 1. Create unsynced data for user1
      final user1Entity = TestEntity(
        id: 'entity1',
        userId: 'user1',
        name: 'User1 Item to Sync',
        value: 1,
        modifiedAt: DateTime.now(),
        createdAt: DateTime.now(),
        version: 1,
      );
      await manager.save(user1Entity, 'user1');
      expect(await manager.getPendingCount('user1'), 1);
      expect(await remoteAdapter.fetchAll('user1'), isEmpty);

      // 2. Switch to user2 with syncThenSwitch strategy
      final switchResult = await manager.switchUser(
        oldUserId: 'user1',
        newUserId: 'user2',
        strategy: UserSwitchStrategy.syncThenSwitch,
      );

      // 3. Assertions
      expect(switchResult.success, isTrue);
      expect(switchResult.newUserId, 'user2');

      // Verify user1's data was synced to remote
      final remoteItems = await remoteAdapter.fetchAll('user1');
      expect(remoteItems, hasLength(1));
      expect(remoteItems.first.name, 'User1 Item to Sync');

      // Verify user1's pending queue is now empty
      expect(await manager.getPendingCount('user1'), 0);
    });

    test('switchUser with clearAndFetch clears new user data', () async {
      // 1. Add some local data for user2
      final localUser2Entity = TestEntity(
        id: 'local-entity',
        userId: 'user2',
        name: 'Local User2 Item',
        value: 1,
        modifiedAt: DateTime.now(),
        createdAt: DateTime.now(),
        version: 1,
      );
      await manager.save(localUser2Entity, 'user2');
      expect(await manager.getAll(userId: 'user2'), hasLength(1));

      // 2. Switch from user1 to user2 with clearAndFetch strategy
      final switchResult = await manager.switchUser(
        oldUserId: 'user1',
        newUserId: 'user2',
        strategy: UserSwitchStrategy.clearAndFetch,
      );

      // 3. Assertions
      expect(switchResult.success, isTrue);

      // Verify local data for user2 was cleared
      final user2Items = await manager.getAll(userId: 'user2');
      expect(user2Items, isEmpty);
    });

    test(
        'switchUser with promptIfUnsyncedData throws error if data is unsynced',
        () async {
      // 1. Create unsynced data for user1
      final user1Entity = TestEntity(
        id: 'entity1',
        userId: 'user1',
        name: 'Unsynced Item',
        value: 1,
        modifiedAt: DateTime.now(),
        createdAt: DateTime.now(),
        version: 1,
      );
      await manager.save(user1Entity, 'user1');
      expect(await manager.getPendingCount('user1'), 1);

      // 2. Attempt to switch with prompt strategy
      final switchResult = await manager.switchUser(
        oldUserId: 'user1',
        newUserId: 'user2',
        strategy: UserSwitchStrategy.promptIfUnsyncedData,
      );

      // 3. Assertions
      expect(switchResult.success, isFalse);
      expect(switchResult.errorMessage, contains('Unsynced data present'));

      // Verify data for user1 is still present and unsynced
      expect(await manager.getPendingCount('user1'), 1);
      final user1Items = await manager.getAll(userId: 'user1');
      expect(user1Items, hasLength(1));
      expect(user1Items.first.name, 'Unsynced Item');

      // Verify we haven't switched to user2's context implicitly
      expect(await manager.getAll(userId: 'user2'), isEmpty);
    });

    group('SynqObserver', () {
      late MockSynqObserver<TestEntity> mockObserver;

      setUp(() async {
        mockObserver = MockSynqObserver<TestEntity>();
        // Re-initialize manager with no retries for observer tests
        manager = SynqManager<TestEntity>(
          localAdapter: localAdapter,
          remoteAdapter: remoteAdapter,
          conflictResolver: LastWriteWinsResolver<TestEntity>(),
          synqConfig: const SynqConfig(maxRetries: 0),
          connectivity: connectivityChecker,
        );
        // We must re-initialize and re-add listeners
        // because we created a new manager instance.
        await manager.initialize();
        manager.eventStream.listen(events.add);
        manager.onInit.listen(initEvents.add);

        manager.addObserver(mockObserver);
      });

      test('onSaveStart and onSaveEnd are called on save()', () async {
        final entity = TestEntity.create('obs-e1', 'user1', 'Observer Test');
        await manager.save(entity, 'user1');

        verify(
          () => mockObserver.onSaveStart(entity, 'user1', DataSource.local),
        ).called(1);
        verify(() => mockObserver.onSaveEnd(entity, 'user1', DataSource.local))
            .called(1);
      });

      test('onDeleteStart and onDeleteEnd are called on successful delete()',
          () async {
        final entity = TestEntity.create('obs-e2', 'user1', 'Observer Delete');
        localAdapter.addLocalItem('user1', entity);

        await manager.delete(entity.id, 'user1');

        verify(() => mockObserver.onDeleteStart(entity.id, 'user1')).called(1);
        verify(
          () => mockObserver.onDeleteEnd(entity.id, 'user1', success: true),
        ).called(1);
      });

      test('onSyncStart and onSyncEnd are called during sync', () async {
        await manager.sync('user1');

        verify(() => mockObserver.onSyncStart('user1')).called(1);
        verify(
          () => mockObserver.onSyncEnd('user1', any(that: isA<SyncResult>())),
        ).called(1);
      });

      test(
          'onOperationStart and onOperationSuccess are called for successful sync op',
          () async {
        final entity = TestEntity.create('op-e1', 'user1', 'Op Success');
        await manager.save(entity, 'user1');

        await manager.sync('user1');

        verify(
          () => mockObserver.onOperationStart(
            any(
              that: isA<SyncOperation<TestEntity>>()
                  .having((op) => op.entityId, 'entityId', 'op-e1'),
            ),
          ),
        ).called(1);
        verify(
          () => mockObserver.onOperationSuccess(
            any(
              that: isA<SyncOperation<TestEntity>>()
                  .having((op) => op.entityId, 'entityId', 'op-e1'),
            ),
            any(that: isA<TestEntity>()),
          ),
        ).called(1);
      });

      test('onOperationFailure is called for a failed sync op', () async {
        final entity = TestEntity.create('op-e2', 'user1', 'Op Failure');
        await manager.save(entity, 'user1');
        remoteAdapter.setFailedIds(['op-e2']); // Make remote push fail

        await manager.sync('user1');

        // With maxRetries = 0, the operation fails immediately.
        // We verify that onOperationSuccess was NOT called.
        verifyNever(
          () => mockObserver.onOperationSuccess(
            any(),
            any(),
          ),
        );

        verify(
          () => mockObserver.onOperationFailure(
            any(
              that: isA<SyncOperation<TestEntity>>()
                  .having((op) => op.entityId, 'entityId', 'op-e2'),
            ),
            any(that: isA<NetworkException>()),
            any(that: isA<StackTrace>()),
          ),
        ).called(1);
      });

      test('onConflictDetected and onConflictResolved are called', () async {
        final baseTime = DateTime.now();
        final local = TestEntity(
          id: 'conflict-1',
          userId: 'user1',
          name: 'Local',
          value: 1,
          modifiedAt: baseTime,
          createdAt: baseTime,
          version: 1,
        );
        final remote = local.copyWith(
          name: 'Remote',
          modifiedAt: baseTime.add(const Duration(seconds: 1)),
          version: 2,
        );

        localAdapter.addLocalItem('user1', local);
        remoteAdapter.addRemoteItem('user1', remote);

        await manager.sync('user1');

        verify(
          () => mockObserver.onConflictDetected(
            any(that: isA<ConflictContext>()),
            local,
            remote,
          ),
        ).called(1);

        verify(
          () => mockObserver.onConflictResolved(
            any(that: isA<ConflictContext>()),
            any(that: isA<ConflictResolution<TestEntity>>()),
          ),
        ).called(1);
      });

      test('onUserSwitchStart and onUserSwitchEnd are called', () async {
        await manager.switchUser(
          oldUserId: 'user1',
          newUserId: 'user2',
          strategy: UserSwitchStrategy.keepLocal,
        );

        verify(
          () => mockObserver.onUserSwitchStart(
            'user1',
            'user2',
            UserSwitchStrategy.keepLocal,
          ),
        ).called(1);

        verify(
          () => mockObserver.onUserSwitchEnd(
            any(
              that: isA<UserSwitchResult>()
                  .having((r) => r.success, 'success', true)
                  .having((r) => r.newUserId, 'newUserId', 'user2'),
            ),
          ),
        ).called(1);
      });

      test('onUserSwitchEnd is called on failure', () async {
        // Arrange for failure
        final entity = TestEntity.create('e1', 'user1', 'unsynced');
        await manager.save(entity, 'user1');

        // Act
        await manager.switchUser(
          oldUserId: 'user1',
          newUserId: 'user2',
          strategy: UserSwitchStrategy.promptIfUnsyncedData,
        );

        // Assert
        verify(
          () => mockObserver.onUserSwitchEnd(
            any(
              that: isA<UserSwitchResult>()
                  .having((r) => r.success, 'success', false)
                  .having((r) => r.errorMessage, 'errorMessage', isNotNull),
            ),
          ),
        ).called(1);
      });
    });

    test('watchAll stream is user-specific and works after user switch',
        () async {
      // 1. Setup data and stream for user1
      final user1Entity = TestEntity.create('entity1', 'user1', 'User1 Item');

      final user1Stream = manager.watchAll(userId: 'user1');
      expect(
        user1Stream,
        emitsInOrder([
          isEmpty, // Initial empty list
          (List<TestEntity> list) => list.first.name == 'User1 Item',
        ]),
      );

      await manager.save(user1Entity, 'user1');

      // 2. Switch user
      await manager.switchUser(
        oldUserId: 'user1',
        newUserId: 'user2',
        strategy: UserSwitchStrategy.keepLocal,
      );

      // 3. Setup data and stream for user2
      final user2Entity = TestEntity.create('entity2', 'user2', 'User2 Item');
      final user2Stream = manager.watchAll(userId: 'user2');
      expect(
        user2Stream,
        emitsInOrder([isEmpty, (List<TestEntity> list) => list.length == 1]),
      );
      await manager.save(user2Entity, 'user2');
    });

    test('sync with scope performs a partial sync', () async {
      // 1. Setup remote data with two items
      final remoteEntity1 =
          TestEntity.create('remote1', 'user1', 'Recent Item');
      final remoteEntity2 = remoteEntity1.copyWith(
        id: 'remote2',
        modifiedAt: DateTime.now().subtract(const Duration(days: 40)),
      );
      remoteAdapter
        ..addRemoteItem('user1', remoteEntity1)
        ..addRemoteItem('user1', remoteEntity2);

      // 2. Add a local-only item that should not be deleted
      final localOnlyEntity =
          TestEntity.create('local-only', 'user1', 'Local Only Item');
      await manager.save(localOnlyEntity, 'user1');

      // 3. Perform a partial sync with a scope for recent items
      final thirtyDaysAgo =
          DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
      final scope = SyncScope({'minModifiedDate': thirtyDaysAgo});
      await manager.sync('user1', scope: scope);

      // 4. Assertions
      final localItems = await manager.getAll(userId: 'user1');
      expect(localItems, hasLength(2)); // Recent remote item + local-only item

      // Check that the recent item was synced
      expect(
        localItems.any((item) => item.id == 'remote1'),
        isTrue,
        reason: 'Recent remote item should be synced',
      );

      // Check that the old item was NOT synced
      expect(
        localItems.any((item) => item.id == 'remote2'),
        isFalse,
        reason: 'Old remote item should be out of scope',
      );

      // Check that the local-only item was NOT deleted
      expect(
        localItems.any((item) => item.id == 'local-only'),
        isTrue,
        reason: 'Local-only item should not be deleted during partial sync',
      );
    });

    test('per-operation retry logic increments retry count on failure',
        () async {
      // 1. Setup two entities to sync, one of which will fail
      final successEntity =
          TestEntity.create('success1', 'user1', 'Will Succeed');
      final failEntity = TestEntity.create('fail1', 'user1', 'Will Fail');
      await manager.save(successEntity, 'user1');
      await manager.save(failEntity, 'user1');

      // 2. Configure remote adapter to fail one of the pushes
      remoteAdapter.setFailedIds(['fail1']);

      // 3. Perform sync
      final result = await manager.sync('user1');

      // 4. Assertions
      expect(result.syncedCount, 1); // The successful one
      expect(
        result.failedCount,
        0,
      ); // Retryable error doesn't count as hard fail
      expect(result.pendingOperations, hasLength(1)); // The failed one remains

      // Verify the successful item is on the remote
      final remoteItems = await remoteAdapter.fetchAll('user1');
      expect(remoteItems, hasLength(1));
      expect(remoteItems.first.id, 'success1');

      // Verify the failed operation is still in the queue with an increased retry count
      final pendingOps = await localAdapter.getPendingOperations('user1');
      expect(pendingOps, hasLength(1));
      expect(pendingOps.first.entityId, 'fail1');
      expect(pendingOps.first.retryCount, 1);

      // 5. Second sync attempt (now succeeding)
      remoteAdapter.setFailedIds([]); // Allow it to succeed now
      final secondResult = await manager.sync('user1');

      // Assert that the second sync cleared the queue
      expect(secondResult.syncedCount, 1);
      expect(secondResult.pendingOperations, isEmpty);
      expect(await manager.getPendingCount('user1'), 0);
      expect(await remoteAdapter.fetchAll('user1'), hasLength(2));
    });

    test('tracks sync statistics', () async {
      final entity = TestEntity.create('entity1', 'user1', 'Test Item');

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
        final entity = TestEntity.create('entity$i', 'user1', 'Test Item $i');
        await manager.save(entity, 'user1');
      }

      final syncFuture = manager.sync('user1');
      await manager.cancelSync('user1');

      final result = await syncFuture;

      // Either cancelled or completed quickly - both are valid
      expect(result.wasCancelled || result.isSuccess, isTrue);
    });

    test('retrieves entity by id', () async {
      final entity = TestEntity.create('entity1', 'user1', 'Test Item');
      await manager.save(entity, 'user1');

      final retrieved = await manager.getById('entity1', 'user1');

      expect(retrieved, isNotNull);
      expect(retrieved!.name, 'Test Item');
    });

    test('returns null when entity does not exist', () async {
      final retrieved = await manager.getById('nonexistent', 'user1');

      expect(retrieved, isNull);
    });

    test('watchAll emits updated lists on data changes', () async {
      final entity1 = TestEntity.create('entity1', 'user1', 'Item 1');
      final entity2 = TestEntity.create('entity2', 'user1', 'Item 2');

      final stream = manager.watchAll(userId: 'user1');

      // Use a Completer to capture stream events without blocking
      final completer = Completer<List<List<TestEntity>>>();
      final receivedEvents = <List<TestEntity>>[];

      final subscription = stream.listen((items) {
        receivedEvents.add(items);
        if (receivedEvents.length == 4) {
          completer.complete(receivedEvents);
        }
      });

      // Initial state (empty)
      await manager.save(entity1, 'user1'); // Add one
      await manager.save(entity2, 'user1'); // Add another
      await manager.delete(entity1.id, 'user1'); // Delete one

      final allEvents = await completer.future;

      expect(allEvents[0], isEmpty); // 1. Initial empty list
      expect(allEvents[1], hasLength(1)); // 2. After adding entity1
      expect(allEvents[1].first.id, 'entity1');
      expect(allEvents[2], hasLength(2)); // 3. After adding entity2
      expect(allEvents[3], hasLength(1)); // 4. After deleting entity1
      expect(allEvents[3].first.id, 'entity2');

      await subscription.cancel();
    });

    test('watchById emits updated entity and null on deletion', () async {
      final entity = TestEntity.create('entity1', 'user1', 'Item 1');
      final updatedEntity = entity.copyWith(name: 'Updated Item');

      final stream = manager.watchById('entity1', 'user1');

      final completer = Completer<List<TestEntity?>>();
      final receivedEvents = <TestEntity?>[];

      final subscription = stream.listen((item) {
        receivedEvents.add(item);
        if (receivedEvents.length == 4) {
          completer.complete(receivedEvents);
        }
      });

      // Sequence of operations
      await manager.save(entity, 'user1');
      await manager.save(updatedEntity, 'user1');
      await manager.delete(entity.id, 'user1');

      final allEvents = await completer.future;

      expect(allEvents[0], isNull); // 1. Initial state (null)
      expect(allEvents[1]?.name, 'Item 1'); // 2. After creation
      expect(allEvents[2]?.name, 'Updated Item'); // 3. After update
      expect(allEvents[3], isNull); // 4. After deletion

      await subscription.cancel();
    });

    test('watchAllPaginated emits updated paginated results', () async {
      // Create 3 entities
      final entities = List.generate(
        3,
        (i) => TestEntity.create('entity$i', 'user1', 'Item $i'),
      );

      const config = PaginationConfig(pageSize: 2);
      final stream = manager.watchAllPaginated(config, userId: 'user1');

      final completer = Completer<List<PaginatedResult<TestEntity>>>();
      final receivedEvents = <PaginatedResult<TestEntity>>[];

      final subscription = stream.listen((result) {
        receivedEvents.add(result);
        // We expect 5 states: initial, add 1, add 2, add 3, delete 1
        if (receivedEvents.length == 5) {
          completer.complete(receivedEvents);
        }
      });

      // Sequence of operations
      await manager.save(entities[0], 'user1');
      await manager.save(entities[1], 'user1');
      await manager.save(entities[2], 'user1');
      await manager.delete(entities[0].id, 'user1');

      final allEvents = await completer.future;

      // 1. Initial state
      expect(allEvents[0].items, isEmpty);
      expect(allEvents[0].totalCount, 0);

      // 2. After adding first item
      expect(allEvents[1].items, hasLength(1));
      expect(allEvents[1].totalCount, 1);

      // 3. After adding second item (fills the page)
      expect(allEvents[2].items, hasLength(2));
      expect(allEvents[2].totalCount, 2);
      expect(allEvents[2].hasMore, isFalse);

      // 4. After adding third item (creates a second page)
      expect(allEvents[3].items, hasLength(2));
      expect(allEvents[3].totalCount, 3);
      expect(allEvents[3].hasMore, isTrue);

      // 5. After deleting first item
      expect(allEvents[4].items, hasLength(2));
      expect(allEvents[4].totalCount, 2);
      expect(allEvents[4].hasMore, isFalse);

      await subscription.cancel();
    });

    test('getByIds fetches multiple items correctly', () async {
      final entity1 = TestEntity.create('e1', 'user1', 'Item 1');
      final entity2 = TestEntity.create('e2', 'user1', 'Item 2');
      await localAdapter.save(entity1, 'user1');
      await localAdapter.save(entity2, 'user1');

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
          await localAdapter.save(entity1, 'user1');
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

    test('watchQuery emits filtered lists on data changes', () async {
      // 1. Create entities with different 'completed' states
      final pendingEntity1 = TestEntity.create('pending1', 'user1', 'Pending');
      final completedEntity = TestEntity.create('completed1', 'user1', 'Done')
          .copyWith(completed: true);

      // 2. Define a query to watch only pending items
      const query = SynqQuery({'completed': false});
      final stream = manager.watchQuery(query, userId: 'user1');

      final completer = Completer<List<List<TestEntity>>>();
      final receivedEvents = <List<TestEntity>>[];

      final subscription = stream.listen((items) {
        receivedEvents.add(items);
        // Expect 4 states: initial, add pending, add completed, update pending
        if (receivedEvents.length == 4) {
          completer.complete(receivedEvents);
        }
      });

      // 3. Sequence of operations
      await manager.save(pendingEntity1, 'user1');
      await manager.save(completedEntity, 'user1');
      await manager.save(pendingEntity1.copyWith(completed: true), 'user1');

      final allEvents = await completer.future;

      // 4. Assertions
      // Initial state is empty
      expect(allEvents[0], isEmpty);
      // After adding a pending item, list has 1
      expect(allEvents[1], hasLength(1));
      expect(allEvents[1].first.id, 'pending1');
      // After adding a completed item, list is unchanged (still 1)
      expect(allEvents[2], hasLength(1));
      // After updating the pending item to completed, list becomes empty
      expect(allEvents[3], isEmpty);

      await subscription.cancel();
    });
  });
}
