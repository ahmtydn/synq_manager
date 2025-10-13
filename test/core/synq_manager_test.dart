import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:synq_manager/synq_manager.dart';

import '../mocks/test_entity.dart';

// Use proper mocktail mocks for adapters
class MockLocalAdapter<T extends SyncableEntity> extends Mock
    implements LocalAdapter<T> {}

class MockRemoteAdapter<T extends SyncableEntity> extends Mock
    implements RemoteAdapter<T> {}

class MockConnectivityChecker extends Mock implements ConnectivityChecker {}

void main() {
  group('SynqManager', () {
    late SynqManager<TestEntity> manager;
    late MockLocalAdapter<TestEntity> localAdapter;
    late MockRemoteAdapter<TestEntity> remoteAdapter;
    late MockConnectivityChecker connectivityChecker;

    const userId = 'test-user';

    setUpAll(() {
      registerFallbackValue(
        SyncMetadata(
          userId: 'fallback',
          lastSyncTime: DateTime(0),
          dataHash: 'fallback',
          itemCount: 0,
        ),
      );
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
      localAdapter = MockLocalAdapter<TestEntity>();
      remoteAdapter = MockRemoteAdapter<TestEntity>();
      connectivityChecker = MockConnectivityChecker();

      // Default stubs for initialization
      when(() => localAdapter.initialize()).thenAnswer((_) async {});
      when(() => localAdapter.name).thenReturn('MockLocalAdapter');
      when(() => remoteAdapter.name).thenReturn('MockRemoteAdapter');
      when(() => localAdapter.getStoredSchemaVersion())
          .thenAnswer((_) async => 1);
      when(() => localAdapter.changeStream())
          .thenAnswer((_) => const Stream.empty());
      when(() => remoteAdapter.changeStream)
          .thenAnswer((_) => const Stream.empty());
      when(() => localAdapter.getPendingOperations(any()))
          .thenAnswer((_) async => []);
      when(() => localAdapter.getSyncMetadata(any()))
          .thenAnswer((_) async => null);
      when(() => remoteAdapter.getSyncMetadata(any()))
          .thenAnswer((_) async => null);
      when(() => connectivityChecker.isConnected).thenAnswer((_) async => true);
      when(() => remoteAdapter.isConnected()).thenAnswer((_) async => true);
      when(() => remoteAdapter.fetchAll(any(), scope: any(named: 'scope')))
          .thenAnswer((_) async => []);
      when(() => localAdapter.getByIds(any(), any(that: isA<String>())))
          .thenAnswer((_) async => {});
      when(() => localAdapter.getAll(userId: any(named: 'userId')))
          .thenAnswer((_) async => []);
      // Stub for migration check during initialization
      when(() => localAdapter.transaction(any()))
          .thenAnswer((invocation) async {
        final action =
            invocation.positionalArguments.first as Future<dynamic> Function();
        return action();
      });
      when(() => localAdapter.updateSyncMetadata(any(), any()))
          .thenAnswer((_) async {});
      when(() => remoteAdapter.updateSyncMetadata(any(), any()))
          .thenAnswer((_) async {});
      when(() => localAdapter.markAsSynced(any())).thenAnswer((_) async {});

      manager = SynqManager<TestEntity>(
        localAdapter: localAdapter,
        remoteAdapter: remoteAdapter,
        connectivity: connectivityChecker,
        // Use a schema version to match other tests and ensure migration logic runs
        synqConfig: const SynqConfig(),
      );

      await manager.initialize();
    });

    tearDown(() async {
      await manager.dispose();
    });

    group('onSyncProgress', () {
      test('emits progress events during sync', () async {
        // Arrange
        final op1 = SyncOperation<TestEntity>(
          id: 'op1',
          userId: userId,
          entityId: 'e1',
          type: SyncOperationType.create,
          timestamp: DateTime.now(),
          data: TestEntity.create('e1', userId, 'Test 1'),
        );
        final op2 = SyncOperation<TestEntity>(
          id: 'op2',
          userId: userId,
          entityId: 'e2',
          type: SyncOperationType.create,
          timestamp: DateTime.now(),
          data: TestEntity.create('e2', userId, 'Test 2'),
        );

        when(() => localAdapter.getPendingOperations(userId))
            .thenAnswer((_) async => [op1, op2]);
        when(() => remoteAdapter.push(any(), any())).thenAnswer(
          (i) async => i.positionalArguments.first as TestEntity,
        );
        when(() => localAdapter.markAsSynced(any())).thenAnswer((_) async {});
        when(() => localAdapter.getByIds(any(), any()))
            .thenAnswer((_) async => {});
        when(() => localAdapter.getAll(userId: any(named: 'userId')))
            .thenAnswer((_) async => []);
        when(() => localAdapter.updateSyncMetadata(any(), any()))
            .thenAnswer((_) async {});
        when(() => remoteAdapter.updateSyncMetadata(any(), any()))
            .thenAnswer((_) async {});

        // Act
        final stream = manager.onSyncProgress;

        // Assert
        expect(
          stream,
          emitsInOrder([
            isA<SyncProgressEvent>()
                .having((e) => e.progress, 'progress', 0.5)
                .having((e) => e.completed, 'completed', 1)
                .having((e) => e.total, 'total', 2),
            isA<SyncProgressEvent>()
                .having((e) => e.progress, 'progress', 1.0)
                .having((e) => e.completed, 'completed', 2)
                .having((e) => e.total, 'total', 2),
          ]),
        );

        // Trigger a sync
        await manager.sync(userId);
      });
    });

    group('watchSyncStatus', () {
      test('emits initial idle status and then syncing status', () async {
        // Arrange stubs for the sync() call
        when(() => remoteAdapter.fetchAll(any(), scope: any(named: 'scope')))
            .thenAnswer((_) async => []);
        when(() => localAdapter.getAll(userId: any(named: 'userId')))
            .thenAnswer((_) async => []);
        when(() => localAdapter.getByIds(any(), any()))
            .thenAnswer((_) async => {});
        when(() => localAdapter.updateSyncMetadata(any(), any()))
            .thenAnswer((_) async {});
        when(() => remoteAdapter.updateSyncMetadata(any(), any()))
            .thenAnswer((_) async {});

        // Act
        final stream = manager.watchSyncStatus(userId);

        // Assert
        // Expect the initial 'idle' status first
        expect(
          stream,
          emitsInOrder([
            isA<SyncStatusSnapshot>()
                .having((s) => s.status, 'status', SyncStatus.idle),
            isA<SyncStatusSnapshot>()
                .having((s) => s.status, 'status', SyncStatus.syncing),
            isA<SyncStatusSnapshot>()
                .having((s) => s.status, 'status', SyncStatus.idle),
          ]),
        );

        // Trigger a sync to change the status
        await manager.sync(userId);
      });

      test('emits detailed status updates during sync', () async {
        // Arrange
        final op1 = SyncOperation<TestEntity>(
          id: 'op1',
          userId: userId,
          entityId: 'e1',
          type: SyncOperationType.create,
          timestamp: DateTime.now(),
          data: TestEntity.create('e1', userId, 'Test 1'),
        );
        when(() => localAdapter.getPendingOperations(userId))
            .thenAnswer((_) async => [op1]);
        when(() => remoteAdapter.push(any(), any())).thenAnswer(
          (i) async => i.positionalArguments.first as TestEntity,
        );
        when(() => localAdapter.markAsSynced(any())).thenAnswer((_) async {});
        // Stub the pull phase to avoid errors, even though we are testing push
        when(() => localAdapter.getAll(userId: any(named: 'userId')))
            .thenAnswer((_) async => []);
        when(() => localAdapter.getByIds(any(), any()))
            .thenAnswer((_) async => {});
        when(() => localAdapter.updateSyncMetadata(any(), any()))
            .thenAnswer((_) async {});
        when(() => remoteAdapter.updateSyncMetadata(any(), any()))
            .thenAnswer((_) async {});

        // Act
        final stream = manager.watchSyncStatus(userId);

        // Assert
        expect(
          stream,
          emitsInOrder([
            // 1. Initial idle state
            isA<SyncStatusSnapshot>()
                .having((s) => s.status, 'status', SyncStatus.idle)
                .having((s) => s.progress, 'progress', 0.0),
            // 2. Syncing starts
            isA<SyncStatusSnapshot>()
                .having((s) => s.status, 'status', SyncStatus.syncing)
                // Progress is still 0 before the first op is processed
                .having((s) => s.progress, 'progress', 0.0)
                .having((s) => s.syncedCount, 'syncedCount', 0),
            // 3. After one operation is processed, syncedCount is updated first
            isA<SyncStatusSnapshot>()
                .having((s) => s.status, 'status', SyncStatus.syncing)
                .having(
                  (s) => s.progress,
                  'progress',
                  0.0,
                ) // Progress not yet updated
                .having((s) => s.syncedCount, 'syncedCount', 1),
            // 4. Then, progress is updated in a separate emission
            isA<SyncStatusSnapshot>()
                .having((s) => s.status, 'status', SyncStatus.syncing)
                .having((s) => s.progress, 'progress', 1.0)
                // syncedCount is now 1
                .having((s) => s.syncedCount, 'syncedCount', 1),
            // 5. Sync finishes and returns to idle
            isA<SyncStatusSnapshot>()
                .having((s) => s.status, 'status', SyncStatus.idle)
                // Progress is reset to 0, syncedCount is now 1
                .having((s) => s.progress, 'progress', 0.0)
                .having((s) => s.syncedCount, 'syncedCount', 1),
          ]),
        );

        // Trigger a sync
        await manager.sync(userId);
      });

      test('does not emit for other users', () async {
        // Arrange
        const otherUserId = 'other-user';
        when(() => remoteAdapter.fetchAll(any(), scope: any(named: 'scope')))
            .thenAnswer((_) async => []);
        when(() => localAdapter.getAll(userId: any(named: 'userId')))
            .thenAnswer((_) async => []);
        when(() => localAdapter.getByIds(any(), any()))
            .thenAnswer((_) async => {});
        when(() => localAdapter.updateSyncMetadata(any(), any()))
            .thenAnswer((_) async {});
        when(() => remoteAdapter.updateSyncMetadata(any(), any()))
            .thenAnswer((_) async {});

        // Act
        final stream = manager.watchSyncStatus(otherUserId);
        final events = <SyncStatusSnapshot>[];
        stream.listen(events.add);

        // Trigger a sync for the main user
        await manager.sync(userId);
        await Future<void>.delayed(
          const Duration(milliseconds: 10),
        ); // Allow stream to emit

        // Assert
        // The stream for 'other-user' should only receive its initial 'idle' state.
        expect(events, hasLength(1));
        expect(events.first.status, SyncStatus.idle);
        expect(events.first.userId, otherUserId);
      });
    });

    group('watchSyncStatistics', () {
      test('emits initial stats and updated stats after a sync', () async {
        // Arrange stubs for the sync() call
        final op1 = SyncOperation<TestEntity>(
          id: 'op1',
          userId: userId,
          entityId: 'e1',
          type: SyncOperationType.create,
          timestamp: DateTime.now(),
          data: TestEntity.create('e1', userId, 'Test 1'),
        );
        when(() => localAdapter.getPendingOperations(userId))
            .thenAnswer((_) async => [op1]);
        when(() => remoteAdapter.fetchAll(any(), scope: any(named: 'scope')))
            .thenAnswer((_) async => []);
        when(() => localAdapter.getAll(userId: any(named: 'userId')))
            .thenAnswer((_) async => []);
        when(() => localAdapter.getByIds(any(), any(that: isA<String>())))
            .thenAnswer((_) async => {});
        when(() => remoteAdapter.push(any(), any())).thenAnswer(
          (i) async => i.positionalArguments.first as TestEntity,
        );
        when(() => localAdapter.markAsSynced(any())).thenAnswer((_) async {});
        when(() => localAdapter.updateSyncMetadata(any(), any()))
            .thenAnswer((_) async {});
        when(() => remoteAdapter.updateSyncMetadata(any(), any()))
            .thenAnswer((_) async {});
        when(() => localAdapter.getAll(userId: any(named: 'userId')))
            .thenAnswer((_) async => []);

        // Act & Assert
        expect(
          manager.watchSyncStatistics(),
          emitsInOrder([
            // Initial state
            isA<SyncStatistics>().having((s) => s.totalSyncs, 'totalSyncs', 0),
            // After one successful sync
            isA<SyncStatistics>().having((s) => s.totalSyncs, 'totalSyncs', 1),
          ]),
        );

        await manager.sync(userId);
      });

      test('emits updated stats after a failed sync', () async {
        // Arrange
        final op1 = SyncOperation<TestEntity>(
          id: 'op1',
          userId: userId,
          entityId: 'e1',
          type: SyncOperationType.create,
          timestamp: DateTime.now(),
          data: TestEntity.create('e1', userId, 'Test 1'),
        );
        when(() => localAdapter.getPendingOperations(userId))
            .thenAnswer((_) async => [op1]);
        when(() => remoteAdapter.push(any(), any()))
            .thenThrow(Exception('Sync failed'));
        // Add stubs for the pull phase, which still runs even if push fails.
        when(() => remoteAdapter.fetchAll(any(), scope: any(named: 'scope')))
            .thenAnswer((_) async => []);
        when(() => localAdapter.getByIds(any(), any()))
            .thenAnswer((_) async => {});
        when(() => localAdapter.getAll(userId: any(named: 'userId')))
            .thenAnswer((_) async => []);
        when(() => localAdapter.updateSyncMetadata(any(), any()))
            .thenAnswer((_) async {});
        when(() => remoteAdapter.updateSyncMetadata(any(), any()))
            .thenAnswer((_) async {});

        // Act & Assert
        expect(
          manager.watchSyncStatistics(),
          emitsInOrder([
            // Initial state
            isA<SyncStatistics>()
                .having((s) => s.totalSyncs, 'totalSyncs', 0)
                .having((s) => s.failedSyncs, 'failedSyncs', 0),
            // After one failed sync
            isA<SyncStatistics>()
                .having((s) => s.totalSyncs, 'totalSyncs', 1)
                .having((s) => s.successfulSyncs, 'successfulSyncs', 0)
                .having((s) => s.failedSyncs, 'failedSyncs', 1),
          ]),
        );

        // The sync method should complete, not throw, but return a result
        // indicating failure.
        final result = await manager.sync(userId);
        expect(result.isSuccess, isFalse);
        expect(result.failedCount, 1);
        expect(result.pendingOperations, hasLength(1));
      });

      test('emits updated stats after a sync with conflicts', () async {
        // Arrange
        final remoteItem = TestEntity.create('e1', userId, 'Remote')
            .copyWith(version: 2, modifiedAt: DateTime.now());
        final localItem = TestEntity.create('e1', userId, 'Local')
            .copyWith(version: 1, modifiedAt: DateTime.now());

        when(() => localAdapter.getPendingOperations(userId))
            .thenAnswer((_) async => []);
        when(() => remoteAdapter.fetchAll(userId, scope: any(named: 'scope')))
            .thenAnswer((_) async => [remoteItem]);
        when(() => localAdapter.getByIds([remoteItem.id], userId))
            .thenAnswer((_) async => {remoteItem.id: localItem});
        when(() => localAdapter.push(any(), any())).thenAnswer((_) async {});
        when(() => localAdapter.getAll(userId: any(named: 'userId')))
            .thenAnswer((_) async => []);
        when(() => localAdapter.updateSyncMetadata(any(), any()))
            .thenAnswer((_) async {});
        when(() => remoteAdapter.updateSyncMetadata(any(), any()))
            .thenAnswer((_) async {});

        // Act & Assert
        expect(
          manager.watchSyncStatistics(),
          emitsInOrder([
            // Initial state
            isA<SyncStatistics>()
                .having((s) => s.conflictsDetected, 'conflictsDetected', 0),
            // After one sync with a conflict
            isA<SyncStatistics>()
                .having((s) => s.totalSyncs, 'totalSyncs', 1)
                .having((s) => s.successfulSyncs, 'successfulSyncs', 1)
                .having((s) => s.conflictsDetected, 'conflictsDetected', 1)
                .having(
                  (s) => s.conflictsAutoResolved,
                  'conflictsAutoResolved',
                  1,
                ),
          ]),
        );

        await manager.sync(userId);
      });

      test('does not emit stats for other managers', () async {
        // Arrange
        final otherManager = SynqManager<TestEntity>(
          localAdapter: localAdapter,
          remoteAdapter: remoteAdapter,
          connectivity: connectivityChecker,
          synqConfig: const SynqConfig(),
        );
        await otherManager.initialize();

        final stats = <SyncStatistics>[];
        otherManager.watchSyncStatistics().listen(stats.add);

        // Act
        await manager.sync(userId);
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // Assert
        expect(stats.length, 1); // Only the initial event
        expect(stats.first.totalSyncs, 0);
      });
    });

    group('Event Streams', () {
      group('onDataChange', () {
        test('emits DataChangeEvent on push (create)', () async {
          // Arrange
          final entity = TestEntity.create('e1', userId, 'New Item');
          when(() => localAdapter.getById(entity.id, userId))
              .thenAnswer((_) async => null);
          when(() => localAdapter.push(any(), any())).thenAnswer((_) async {});
          when(() => localAdapter.addPendingOperation(any(), any()))
              .thenAnswer((_) async {});

          // Act & Assert
          expect(
            manager.onDataChange,
            emits(
              isA<DataChangeEvent<TestEntity>>()
                  .having((e) => e.changeType, 'changeType', ChangeType.created)
                  .having((e) => e.data.id, 'data.id', entity.id)
                  .having((e) => e.source, 'source', DataSource.local),
            ),
          );

          await manager.push(entity, userId);
        });

        test('emits DataChangeEvent on push (update)', () async {
          // Arrange
          final existingEntity = TestEntity.create('e1', userId, 'Old Item');
          final updatedEntity = existingEntity.copyWith(name: 'Updated Item');
          when(() => localAdapter.getById(existingEntity.id, userId))
              .thenAnswer((_) async => existingEntity);
          when(() => localAdapter.patch(any(), any(), any()))
              .thenAnswer((_) async => updatedEntity);
          when(() => localAdapter.addPendingOperation(any(), any()))
              .thenAnswer((_) async {});

          // Act & Assert
          expect(
            manager.onDataChange,
            emits(
              isA<DataChangeEvent<TestEntity>>()
                  .having(
                    (e) => e.changeType,
                    'changeType',
                    ChangeType.updated,
                  )
                  .having((e) => e.data.id, 'data.id', updatedEntity.id)
                  .having((e) => e.source, 'source', DataSource.local),
            ),
          );

          await manager.push(updatedEntity, userId);
        });

        test('emits DataChangeEvent on delete', () async {
          // Arrange
          final entity = TestEntity.create('e1', userId, 'To be deleted');
          when(() => localAdapter.getById(entity.id, userId))
              .thenAnswer((_) async => entity);
          when(() => localAdapter.delete(entity.id, userId))
              .thenAnswer((_) async => true);
          when(() => localAdapter.addPendingOperation(any(), any()))
              .thenAnswer((_) async {});

          // Act & Assert
          expect(
            manager.onDataChange,
            emits(
              isA<DataChangeEvent<TestEntity>>()
                  .having(
                    (e) => e.changeType,
                    'changeType',
                    ChangeType.deleted,
                  )
                  .having((e) => e.data.id, 'data.id', entity.id),
            ),
          );

          await manager.delete(entity.id, userId);
        });
      });

      group('onSyncStarted / onSyncCompleted', () {
        test('emits start and completed events for a successful sync',
            () async {
          // Arrange
          when(() => localAdapter.getPendingOperations(userId))
              .thenAnswer((_) async => []);
          when(() => localAdapter.getAll(userId: any(named: 'userId')))
              .thenAnswer((_) async => []);
          when(() => localAdapter.getByIds(any(), any()))
              .thenAnswer((_) async => {});
          when(() => localAdapter.updateSyncMetadata(any(), any()))
              .thenAnswer((_) async {});
          when(() => remoteAdapter.updateSyncMetadata(any(), any()))
              .thenAnswer((_) async {});

          // Act & Assert
          final startedFuture = manager.onSyncStarted.first;
          final completedFuture = manager.onSyncCompleted.first;

          await manager.sync(userId);

          final startedEvent = await startedFuture;
          final completedEvent = await completedFuture;

          expect(startedEvent.userId, userId);
          expect(completedEvent.userId, userId);
          expect(completedEvent.result.isSuccess, isTrue);
        });
      });

      group('onConflict', () {
        test('emits ConflictDetectedEvent when a conflict occurs', () async {
          // Arrange
          final remoteItem = TestEntity.create('e1', userId, 'Remote')
              .copyWith(version: 2, modifiedAt: DateTime.now());
          final localItem = TestEntity.create('e1', userId, 'Local')
              .copyWith(version: 1, modifiedAt: DateTime.now());

          when(() => localAdapter.getPendingOperations(userId))
              .thenAnswer((_) async => []);
          when(() => remoteAdapter.fetchAll(userId, scope: any(named: 'scope')))
              .thenAnswer((_) async => [remoteItem]);
          when(() => localAdapter.getByIds([remoteItem.id], userId))
              .thenAnswer((_) async => {remoteItem.id: localItem});
          when(() => localAdapter.push(any(), any())).thenAnswer((_) async {});
          when(() => localAdapter.getAll(userId: any(named: 'userId')))
              .thenAnswer((_) async => []);
          when(() => localAdapter.updateSyncMetadata(any(), any()))
              .thenAnswer((_) async {});
          when(() => remoteAdapter.updateSyncMetadata(any(), any()))
              .thenAnswer((_) async {});

          // Act & Assert
          expect(
            manager.onConflict,
            emits(
              isA<ConflictDetectedEvent<TestEntity>>()
                  .having((e) => e.context.entityId, 'entityId', 'e1')
                  .having(
                    (e) => e.context.type,
                    'type',
                    ConflictType.bothModified,
                  ),
            ),
          );

          await manager.sync(userId);
        });
      });

      group('onUserSwitched', () {
        test('emits UserSwitchedEvent on successful user switch', () async {
          // Arrange
          const newUserId = 'new-user';
          when(() => localAdapter.getPendingOperations(any()))
              .thenAnswer((_) async => []);

          // Act & Assert
          expect(
            manager.onUserSwitched,
            emits(
              isA<UserSwitchedEvent<TestEntity>>()
                  .having((e) => e.previousUserId, 'previousUserId', userId)
                  .having((e) => e.newUserId, 'newUserId', newUserId),
            ),
          );

          await manager.switchUser(
            oldUserId: userId,
            newUserId: newUserId,
            strategy: UserSwitchStrategy.keepLocal,
          );
        });
      });

      group('onError', () {
        test('emits SyncErrorEvent on initialization failure', () async {
          // This requires creating a new manager instance that will fail.
          final failingLocalAdapter = MockLocalAdapter<TestEntity>();
          when(failingLocalAdapter.initialize)
              .thenThrow(Exception('DB connection failed'));
          when(() => failingLocalAdapter.name).thenReturn('FailingAdapter');

          final errorManager = SynqManager<TestEntity>(
            localAdapter: failingLocalAdapter,
            remoteAdapter: remoteAdapter,
          );

          expect(
            errorManager.onError,
            emits(
              isA<SyncErrorEvent>()
                  .having((e) => e.error, 'error', contains('Initialization')),
            ),
          );

          await expectLater(
            errorManager.initialize(),
            throwsA(isA<Exception>()),
          );
        });
      });

      group('Concurrency', () {
        test('handles concurrent push calls correctly', () async {
          // Arrange
          final entities = List.generate(
            // Using a smaller number for faster tests
            5,
            (i) => TestEntity.create('e$i', userId, 'Item $i'),
          );

          when(() => localAdapter.getById(any(), any()))
              .thenAnswer((_) async => null);
          when(() => localAdapter.push(any(), any())).thenAnswer((_) async {});
          when(() => localAdapter.addPendingOperation(any(), any()))
              .thenAnswer((_) async {});

          // Act: Fire all push calls concurrently without awaiting each one
          final futures = entities.map((e) => manager.push(e, userId)).toList();
          await Future.wait(futures);

          // Assert
          // Verify that push was called for each entity
          verify(() => localAdapter.push(any(), userId)).called(5);
          // Verify that an operation was enqueued for each entity
          verify(() => localAdapter.addPendingOperation(userId, any()))
              .called(5);
        });

        test('handles concurrent pushSync calls correctly', () async {
          // Arrange
          final entities = List.generate(
            5,
            (i) => TestEntity.create('e$i', userId, 'Item $i'),
          );

          // Mocks for the 'push' part
          when(() => localAdapter.getById(any(), any()))
              .thenAnswer((_) async => null);
          when(() => localAdapter.push(any(), any())).thenAnswer((_) async {});
          when(() => localAdapter.addPendingOperation(any(), any()))
              .thenAnswer((_) async {});

          // Mocks for the 'sync' part
          when(() => remoteAdapter.push(any(), any())).thenAnswer(
            (i) async => i.positionalArguments.first as TestEntity,
          );

          // Act: Fire all pushSync calls concurrently
          final futures =
              entities.map((e) => manager.pushAndSync(e, userId)).toList();
          await Future.wait(futures);

          // Assert
          // Verify that local push was called for each entity
          verify(() => localAdapter.push(any(), userId)).called(5);
          // Verify that remote push was called for each entity
          verify(() => remoteAdapter.push(any(), userId)).called(5);
          // Verify that all operations were marked as synced
          verify(() => localAdapter.markAsSynced(any())).called(5);
        });

        test('handles concurrent deleteSync calls correctly', () async {
          // Arrange
          final entities = List.generate(
            5,
            (i) => TestEntity.create('e$i', userId, 'Item $i'),
          );
          for (final e in entities) {
            // Pre-populate local and remote storage
            when(() => localAdapter.getById(e.id, userId))
                .thenAnswer((_) async => e);
          }
          when(() => localAdapter.delete(any(), any()))
              .thenAnswer((_) async => true);
          when(() => localAdapter.addPendingOperation(any(), any()))
              .thenAnswer((_) async {});
          when(() => remoteAdapter.deleteRemote(any(), any()))
              .thenAnswer((_) async {});

          // Act: Fire all deleteSync calls concurrently
          final futures =
              entities.map((e) => manager.deleteAndSync(e.id, userId)).toList();
          await Future.wait(futures);

          // Assert
          verify(() => localAdapter.delete(any(), userId)).called(5);
          verify(() => remoteAdapter.deleteRemote(any(), userId)).called(5);
          verify(() => localAdapter.markAsSynced(any())).called(5);
        });
      });
    });
  });
}
