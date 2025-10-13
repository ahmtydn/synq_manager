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
    when(() => mockLocalAdapter.getPendingOperations(any()))
        .thenAnswer((_) async => []);
    when(() => mockLocalAdapter.addPendingOperation(any(), any()))
        .thenAnswer((_) async {});
    when(() => mockLocalAdapter.clearUserData(any())).thenAnswer((_) async {});
    when(() => mockLocalAdapter.changeStream())
        .thenAnswer((_) => const Stream.empty());
    when(() => mockRemoteAdapter.changeStream)
        .thenAnswer((_) => const Stream.empty());
    when(() => mockLocalAdapter.name).thenReturn('MockedLocalAdapter');
    when(() => mockRemoteAdapter.name).thenReturn('MockedRemoteAdapter');

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
        expect(completer.isCompleted, isFalse,
            reason: 'No event should be emitted on failure.',);

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
  });
}
