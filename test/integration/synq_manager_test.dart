import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:synq_manager/synq_manager.dart';

import '../mocks/mock_connectivity_checker.dart';
import '../mocks/test_entity.dart';

// Create a true mock using mocktail's Mock class
class MockedLocalAdapter<T extends SyncableEntity> extends Mock
    implements LocalAdapter<T> {}

class MockedRemoteAdapter<T extends SyncableEntity> extends Mock
    implements RemoteAdapter<T> {}

void main() {
  late SynqManager<TestEntity> synqManager;
  late MockedLocalAdapter<TestEntity> mockLocalAdapter;
  // Use the new mocktail-compatible remote adapter
  late MockedRemoteAdapter<TestEntity> mockRemoteAdapter;
  late MockConnectivityChecker mockConnectivityChecker;

  setUpAll(() {
    // Register fallback values for custom types used with `any()` in mocktail.
    registerFallbackValue(
      TestEntity(
        id: 'fallback',
        userId: 'fallback',
        name: 'fallback',
        value: 0,
        modifiedAt: DateTime(0),
        createdAt: DateTime(0),
        version: 0,
      ),
    );
    registerFallbackValue(
      SyncOperation<TestEntity>(
        id: 'fallback',
        userId: 'fallback',
        entityId: 'fallback',
        type: SyncOperationType.create,
        timestamp: DateTime(0),
      ),
    );
    registerFallbackValue(
      SyncMetadata(
        userId: 'fb',
        lastSyncTime: _fallbackDate,
        dataHash: 'fb',
        itemCount: 0,
      ),
    );
  });

  setUp(() async {
    mockLocalAdapter = MockedLocalAdapter<TestEntity>();
    mockRemoteAdapter = MockedRemoteAdapter<TestEntity>();
    mockConnectivityChecker = MockConnectivityChecker();

    // Mock default behaviors
    when(() => mockLocalAdapter.initialize()).thenAnswer((_) async {});
    when(() => mockLocalAdapter.dispose()).thenAnswer((_) async {});
    when(() => mockLocalAdapter.save(any(), any())).thenAnswer((_) async {});
    when(() => mockLocalAdapter.delete(any(), any()))
        .thenAnswer((_) async => true);
    when(() => mockLocalAdapter.getById(any(), any()))
        .thenAnswer((_) async => null);
    when(() => mockLocalAdapter.getByIds(any(), any()))
        .thenAnswer((_) async => {});
    when(() => mockLocalAdapter.getAll(userId: any(named: 'userId')))
        .thenAnswer((_) async => []);
    when(() => mockLocalAdapter.getPendingOperations(any()))
        .thenAnswer((_) async => []);
    when(() => mockLocalAdapter.addPendingOperation(any(), any()))
        .thenAnswer((_) async {});
    when(() => mockLocalAdapter.updateSyncMetadata(any(), any()))
        .thenAnswer((_) async {});
    when(() => mockRemoteAdapter.updateSyncMetadata(any(), any()))
        .thenAnswer((_) async {});
    when(() => mockLocalAdapter.clearUserData(any())).thenAnswer((_) async {});
    when(() => mockLocalAdapter.changeStream())
        .thenAnswer((_) => const Stream.empty());
    when(() => mockRemoteAdapter.changeStream)
        .thenAnswer((_) => const Stream.empty());
    when(() => mockRemoteAdapter.isConnected()).thenAnswer((_) async => true);

    when(() => mockLocalAdapter.watchCount(
        query: any(named: 'query'),
        userId: any(named: 'userId'),),).thenAnswer((_) => Stream.value(0));
    when(() => mockLocalAdapter.watchFirst(
        query: any(named: 'query'),
        userId: any(named: 'userId'),),).thenAnswer((_) => Stream.value(null));
    when(() => mockRemoteAdapter.fetchAll(any(), scope: any(named: 'scope')))
        .thenAnswer((_) async => []);
    when(() => mockLocalAdapter.name).thenReturn('MockedLocalAdapter');
    when(() => mockRemoteAdapter.name).thenReturn('MockedRemoteAdapter');
    when(() => mockLocalAdapter.getSyncMetadata(any()))
        .thenAnswer((_) async => null);
    when(() => mockRemoteAdapter.getSyncMetadata(any()))
        .thenAnswer((_) async => null);

    synqManager = SynqManager<TestEntity>(
      localAdapter: mockLocalAdapter,
      remoteAdapter: mockRemoteAdapter,
      connectivity: mockConnectivityChecker,
      synqConfig: const SynqConfig(),
    );
    await synqManager.initialize();
  });

  tearDown(() async {
    await synqManager.dispose();
  });

  group('SynqManager', () {
    test('initialize() should initialize adapters', () async {
      await synqManager.initialize();
      verify(() => mockLocalAdapter.initialize()).called(1);
    });

    test('save() creates a new entity, queues operation, and emits event',
        () async {
      await synqManager.initialize();
      final now = DateTime.now();
      final entity = TestEntity(
        id: 'test1',
        userId: 'user1',
        name: 'data',
        value: 1,
        modifiedAt: now,
        createdAt: now,
        version: 1,
      );

      // Expect a DataChangeEvent
      final eventFuture = synqManager.onDataChange.first;

      // Mock getById to simulate creation
      when(() => mockLocalAdapter.getById(entity.id, 'user1'))
          .thenAnswer((_) async => null);

      await synqManager.save(entity, 'user1');

      // Verify save was called
      verify(() => mockLocalAdapter.save(entity, 'user1')).called(1);

      // Verify an operation was queued
      verify(
        () => mockLocalAdapter.addPendingOperation(
          'user1',
          any(
            that: isA<SyncOperation<TestEntity>>().having(
              (op) => op.type,
              'type',
              SyncOperationType.create,
            ),
          ),
        ),
      ).called(1);

      // Verify event was emitted
      final event = await eventFuture;
      expect(event.changeType, ChangeType.created);
      expect(event.data.id, entity.id);
    });

    test('save() updates an existing entity and queues operation', () async {
      await synqManager.initialize();
      final now = DateTime.now();
      final entity = TestEntity(
        id: 'test1',
        userId: 'user1',
        name: 'data',
        value: 1,
        modifiedAt: now,
        createdAt: now,
        version: 1,
      );

      // Mock getById to simulate update
      when(() => mockLocalAdapter.getById(entity.id, 'user1'))
          .thenAnswer((_) async => entity);

      await synqManager.save(entity, 'user1');

      // Verify an update operation was queued
      verify(
        () => mockLocalAdapter.addPendingOperation(
          'user1',
          any(
            that: isA<SyncOperation<TestEntity>>().having(
              (op) => op.type,
              'type',
              SyncOperationType.update,
            ),
          ),
        ),
      ).called(1);
    });

    test('delete() removes an entity, queues operation, and emits event',
        () async {
      await synqManager.initialize();
      final now = DateTime.now();
      final entity = TestEntity(
        id: 'test1',
        userId: 'user1',
        name: 'data',
        value: 1,
        modifiedAt: now,
        createdAt: now,
        version: 1,
      );

      // Expect a DataChangeEvent
      final eventFuture = synqManager.onDataChange.first;

      // Mock getById to simulate existence
      when(() => mockLocalAdapter.getById(entity.id, 'user1'))
          .thenAnswer((_) async => entity);

      await synqManager.delete(entity.id, 'user1');

      // Verify delete was called
      verify(() => mockLocalAdapter.delete(entity.id, 'user1')).called(1);

      // Verify a delete operation was queued
      verify(
        () => mockLocalAdapter.addPendingOperation(
          'user1',
          any(
            that: isA<SyncOperation<TestEntity>>().having(
              (op) => op.type,
              'type',
              SyncOperationType.delete,
            ),
          ),
        ),
      ).called(1);

      // Verify event was emitted
      final event = await eventFuture;
      expect(event.changeType, ChangeType.deleted);
      expect(event.data.id, entity.id);
    });

    group('switchUser()', () {
      const oldUserId = 'user1';
      const newUserId = 'user2';

      setUp(() async {
        await synqManager.initialize();
      });

      test('with clearAndFetch strategy clears new user data', () async {
        final result = await synqManager.switchUser(
          oldUserId: oldUserId,
          newUserId: newUserId,
          strategy: UserSwitchStrategy.clearAndFetch,
        );

        expect(result.success, isTrue);
        verify(() => mockLocalAdapter.clearUserData(newUserId)).called(1);
      });

      test('with promptIfUnsyncedData fails if unsynced data exists', () async {
        // Mock unsynced data for old user
        final pendingOp = SyncOperation<TestEntity>(
          id: 'op1',
          userId: oldUserId,
          entityId: 'entity1',
          type: SyncOperationType.create,
          timestamp: DateTime.now(),
        );
        when(() => mockLocalAdapter.getPendingOperations(oldUserId))
            .thenAnswer((_) async => [pendingOp]);

        final result = await synqManager.switchUser(
          oldUserId: oldUserId,
          newUserId: newUserId,
          strategy: UserSwitchStrategy.promptIfUnsyncedData,
        );

        expect(result.success, isFalse);
        expect(result.errorMessage, contains('Unsynced data present'));
      });

      test('with promptIfUnsyncedData succeeds if no unsynced data', () async {
        // Mock no unsynced data
        when(() => mockLocalAdapter.getPendingOperations(oldUserId))
            .thenAnswer((_) async => []);

        final result = await synqManager.switchUser(
          oldUserId: oldUserId,
          newUserId: newUserId,
          strategy: UserSwitchStrategy.promptIfUnsyncedData,
        );

        expect(result.success, isTrue);
      });

      test('with keepLocal strategy succeeds without clearing data', () async {
        final result = await synqManager.switchUser(
          oldUserId: oldUserId,
          newUserId: newUserId,
          strategy: UserSwitchStrategy.keepLocal,
        );
        expect(result.success, isTrue);
        verifyNever(() => mockLocalAdapter.clearUserData(newUserId));
      });

      test('with clearAndFetch does not clear old user data', () async {
        await synqManager.switchUser(
          oldUserId: oldUserId,
          newUserId: newUserId,
          strategy: UserSwitchStrategy.clearAndFetch,
        );
        verifyNever(() => mockLocalAdapter.clearUserData(oldUserId));
      });

      test('emits UserSwitchedEvent on a successful switch', () async {
        final eventFuture = synqManager.onUserSwitched.first;

        final result = await synqManager.switchUser(
          oldUserId: oldUserId,
          newUserId: newUserId,
          strategy: UserSwitchStrategy.keepLocal,
        );

        expect(result.success, isTrue);
        final event = await eventFuture;
        expect(event.previousUserId, oldUserId);
        expect(event.newUserId, newUserId);
      });

      test('does NOT emit UserSwitchedEvent on a failed switch', () async {
        // Arrange: Mock a failure condition
        when(() => mockLocalAdapter.getPendingOperations(oldUserId)).thenAnswer(
          (_) async => <SyncOperation<TestEntity>>[
            SyncOperation<TestEntity>(
              id: 'op1',
              userId: oldUserId,
              entityId: 'entity1',
              type: SyncOperationType.update,
              timestamp: DateTime.now(),
            ),
          ],
        );

        // Use a completer to detect if an event is emitted within a short time
        final completer = Completer<void>();
        final subscription =
            synqManager.onUserSwitched.listen((_) => completer.complete());

        // Act: Perform the switch that is expected to fail
        final failResult = await synqManager.switchUser(
          oldUserId: oldUserId,
          newUserId: newUserId,
          strategy: UserSwitchStrategy.promptIfUnsyncedData,
        );

        // Assert: The switch failed and the completer was NOT completed
        expect(failResult.success, isFalse);
        expect(
          completer.isCompleted,
          isFalse,
          reason: 'No event should be emitted on failure.',
        );

        await subscription.cancel();
      });

      test('switchUser throws if newUserId is empty', () async {
        expect(
          () => synqManager.switchUser(
            oldUserId: oldUserId,
            newUserId: '',
          ),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('SynqConfig Defaults', () {
      test(
          'uses defaultConflictResolver from SynqConfig during sync if not overridden',
          () async {
        // 1. Setup with a custom default resolver
        final localWinsResolver = LocalPriorityResolver<TestEntity>();
        final managerWithDefaultResolver = SynqManager<TestEntity>(
          localAdapter: mockLocalAdapter,
          remoteAdapter: mockRemoteAdapter,
          connectivity: mockConnectivityChecker,
          synqConfig: SynqConfig<TestEntity>(
            defaultConflictResolver: localWinsResolver,
          ),
        );
        await managerWithDefaultResolver.initialize();

        // 2. Create a conflict scenario
        final baseTime = DateTime.now();
        final localEntity = TestEntity(
          id: 'conflict-1',
          userId: 'user1',
          name: 'Local Wins',
          value: 1,
          modifiedAt: baseTime.add(const Duration(seconds: 1)),
          createdAt: baseTime,
          version: 2,
        );
        final remoteEntity = TestEntity(
          id: 'conflict-1',
          userId: 'user1',
          name: 'Remote Loses',
          value: 2,
          modifiedAt: baseTime,
          createdAt: baseTime,
          version: 1,
        );

        // Setup mocks for the sync process
        when(() => mockLocalAdapter.getById('conflict-1', 'user1'))
            .thenAnswer((_) async => localEntity);
        when(() => mockLocalAdapter.getByIds(['conflict-1'], 'user1'))
            .thenAnswer((_) async => {'conflict-1': localEntity});
        when(
          () => mockRemoteAdapter.fetchAll('user1', scope: any(named: 'scope')),
        ).thenAnswer((_) async => [remoteEntity]);
        when(() => mockLocalAdapter.getPendingOperations('user1'))
            .thenAnswer((_) async => []);
        when(() => mockLocalAdapter.getAll(userId: 'user1'))
            .thenAnswer((_) async => [localEntity]);
        when(() => mockRemoteAdapter.push(any(), any()))
            .thenAnswer((_) async => remoteEntity);

        // 3. Act
        final result = await managerWithDefaultResolver.sync('user1');

        // 4. Assert
        expect(result.conflictsResolved, 1);

        // Verify that the remote was updated with the local version,
        // proving LocalPriorityResolver was used.
        final captured =
            verify(() => mockRemoteAdapter.push(captureAny(), 'user1'))
                .captured
                .last as TestEntity;
        expect(captured.name, 'Local Wins');

        await managerWithDefaultResolver.dispose();
      });

      test(
          'uses defaultSyncDirection from SynqConfig during sync if not overridden',
          () async {
        // 1. Setup with pullThenPush direction
        final managerWithPullFirst = SynqManager<TestEntity>(
          localAdapter: mockLocalAdapter,
          remoteAdapter: mockRemoteAdapter,
          connectivity: mockConnectivityChecker,
          synqConfig: const SynqConfig(
            defaultSyncDirection: SyncDirection.pullThenPush,
          ),
        );
        await managerWithPullFirst.initialize();

        // 2. Create a scenario with a pending local change
        final pendingOp = SyncOperation<TestEntity>(
          id: 'op1',
          userId: 'user1',
          entityId: 'e1',
          type: SyncOperationType.create,
          timestamp: DateTime.now(),
          data: TestEntity(
            id: 'e1',
            userId: 'user1',
            name: 'data',
            value: 1,
            modifiedAt: DateTime.now(),
            createdAt: DateTime.now(),
            version: 1,
          ),
        );
        when(() => mockLocalAdapter.getPendingOperations('user1'))
            .thenAnswer((_) async => [pendingOp]);
        when(
          () => mockRemoteAdapter.fetchAll('user1', scope: any(named: 'scope')),
        ).thenAnswer((_) async => []);

        // 3. Act
        await managerWithPullFirst.sync('user1');

        // 4. Assert the order of remote adapter calls
        verifyInOrder([
          () => mockRemoteAdapter.fetchAll('user1', scope: null),
          () => mockRemoteAdapter.push(any(), 'user1'),
        ]);

        await managerWithPullFirst.dispose();
      });
      test('deleteAndSync passes options to sync call', () async {
        // 1. Arrange
        final entity = TestEntity.create('e1', 'user1', 'delete-and-sync');
        when(() => mockLocalAdapter.getById(entity.id, 'user1'))
            .thenAnswer((_) async => entity);
        when(() => mockRemoteAdapter.deleteRemote(entity.id, 'user1'))
            .thenAnswer((_) async {});

        // 2. Act
        await synqManager.deleteAndSync(
          entity.id,
          'user1',
          options: const SyncOptions(forceFullSync: true),
        );

        // 3. Assert
        // The key is that the sync call inside deleteAndSync receives the options.
        // We can verify this by checking if fetchAll was called, which is triggered by forceFullSync.
        verify(() => mockRemoteAdapter.fetchAll('user1', scope: null))
            .called(1);
      });
    });

    group('Advanced Watchers', () {
      test('watchCount emits correct count of items', () async {
        // Arrange
        when(() => mockLocalAdapter.watchCount(userId: 'user1'))
            .thenAnswer((_) => Stream.fromIterable([0, 1, 2, 1]));

        // Act & Assert
        final stream = synqManager.watchCount(userId: 'user1');
        await expectLater(stream, emitsInOrder([0, 1, 2, 1]));
      });

      test('watchCount with query emits correct filtered count', () async {
        // Arrange
        const query = SynqQuery({'completed': true});
        when(() => mockLocalAdapter.watchCount(query: query, userId: 'user1'))
            .thenAnswer((_) => Stream.fromIterable([0, 1]));

        // Act & Assert
        final stream = synqManager.watchCount(query: query, userId: 'user1');
        await expectLater(stream, emitsInOrder([0, 1]));
      });

      test('watchFirst emits the first matching item and null', () async {
        // Arrange
        final entity = TestEntity.create('e1', 'user1', 'First Item');
        when(() => mockLocalAdapter.watchFirst(userId: 'user1'))
            .thenAnswer((_) => Stream.fromIterable([null, entity, null]));

        // Act & Assert
        final stream = synqManager.watchFirst(userId: 'user1');
        await expectLater(
          stream,
          emitsInOrder(
            [
              null,
              isA<TestEntity>().having((e) => e.id, 'id', 'e1'),
              null,
            ],
          ),
        );
      });

      test('watchExists emits true when items exist, false otherwise',
          () async {
        // Arrange
        // This test verifies the logic within SynqManager, so we mock the
        // underlying watchCount stream it depends on.
        when(() => mockLocalAdapter.watchCount(userId: 'user1'))
            .thenAnswer((_) => Stream.fromIterable([0, 1, 5, 0]));

        // Act & Assert
        final stream = synqManager.watchExists(userId: 'user1');
        await expectLater(stream, emitsInOrder([false, true, true, false]));
      });

      test('watchExists with query emits correct boolean stream', () async {
        // Arrange
        const query = SynqQuery({'isPriority': true});
        when(() => mockLocalAdapter.watchCount(query: query, userId: 'user1'))
            .thenAnswer((_) => Stream.fromIterable([0, 1, 0]));

        // Act & Assert
        final stream = synqManager.watchExists(query: query, userId: 'user1');
        await expectLater(stream, emitsInOrder([false, true, false]));
      });

      test('watch methods return default stream if adapter returns null',
          () async {
        // Arrange
        when(() => mockLocalAdapter.watchCount(userId: 'user1'))
            .thenReturn(null);

        // Act & Assert
        await expectLater(synqManager.watchCount(userId: 'user1'), emits(0));
      });
    });
  });
}

final _fallbackDate = DateTime(2024);
