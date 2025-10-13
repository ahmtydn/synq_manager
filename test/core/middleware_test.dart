import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:synq_manager/synq_manager.dart';

import '../mocks/mock_connectivity_checker.dart';
import '../mocks/test_entity.dart';

class MockMiddleware<T extends SyncableEntity> extends Mock
    implements SynqMiddleware<T> {}

// Use mocktail mocks for both adapters to allow `when` and `verify`.
class MockedLocalAdapter<T extends SyncableEntity> extends Mock
    implements LocalAdapter<T> {}

class MockedRemoteAdapter<T extends SyncableEntity> extends Mock
    implements RemoteAdapter<T> {}

void main() {
  group('SynqMiddleware', () {
    late SynqManager<TestEntity> manager;
    late MockedLocalAdapter<TestEntity> localAdapter;
    late MockedRemoteAdapter<TestEntity> remoteAdapter;
    late MockMiddleware<TestEntity> middleware;

    const userId = 'user1';
    final now = DateTime.now();
    final entity = TestEntity(
      id: 'e1',
      userId: userId,
      name: 'Test',
      value: 0,
      modifiedAt: now,
      createdAt: now,
      version: 1,
    );

    setUpAll(() {
      // Register fallback values for custom types used with `any()` in mocktail.
      registerFallbackValue(
        TestEntity(
          id: 'fb',
          userId: 'fb',
          name: 'fb',
          value: 0,
          modifiedAt: now,
          createdAt: now,
          version: 1,
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
        const SyncResult(
          userId: 'fallback',
          syncedCount: 0,
          failedCount: 0,
          conflictsResolved: 0,
          pendingOperations: [],
          duration: Duration.zero,
        ),
      );

      registerFallbackValue(NetworkException('fallback'));

      registerFallbackValue(
        ConflictContext(
          userId: 'fallback',
          entityId: 'fallback',
          type: ConflictType.bothModified,
          detectedAt: DateTime(0),
        ),
      );

      registerFallbackValue(
        SyncMetadata(
          userId: 'fallback',
          lastSyncTime: DateTime(0),
          dataHash: 'fallback',
          itemCount: 0,
        ),
      );
    });

    setUp(() async {
      localAdapter = MockedLocalAdapter<TestEntity>();
      remoteAdapter = MockedRemoteAdapter<TestEntity>();
      middleware = MockMiddleware<TestEntity>();

      // General stubs for adapters
      when(() => localAdapter.initialize()).thenAnswer((_) async {});
      when(() => localAdapter.dispose()).thenAnswer((_) async {});
      when(() => localAdapter.save(any(), any())).thenAnswer((_) async {});
      when(() => localAdapter.getByIds(any(), any()))
          .thenAnswer((_) async => {});
      when(() => localAdapter.getAll(userId: any(named: 'userId')))
          .thenAnswer((_) async => []);
      when(() => localAdapter.getPendingOperations(any()))
          .thenAnswer((_) async => []);
      when(() => localAdapter.addPendingOperation(any(), any()))
          .thenAnswer((_) async {});
      when(() => localAdapter.markAsSynced(any())).thenAnswer((_) async {});
      when(() => localAdapter.changeStream())
          .thenAnswer((_) => const Stream.empty());
      when(() => localAdapter.name).thenReturn('MockedLocalAdapter');

      when(() => remoteAdapter.changeStream)
          .thenAnswer((_) => const Stream.empty());
      when(() => remoteAdapter.fetchAll(any(), scope: any(named: 'scope')))
          .thenAnswer((_) async => []);
      when(() => remoteAdapter.isConnected()).thenAnswer((_) async => true);

      // Add stubs for metadata methods to prevent null-future errors
      when(() => remoteAdapter.name).thenReturn('MockedRemoteAdapter');
      when(() => localAdapter.getSyncMetadata(any()))
          .thenAnswer((_) async => null);
      when(() => remoteAdapter.getSyncMetadata(any()))
          .thenAnswer((_) async => null);

      // Stub middleware after adapters
      when(() => middleware.transformBeforeSave(any())).thenAnswer(
        (inv) async => inv.positionalArguments.first as TestEntity,
      );
      when(() => middleware.transformAfterFetch(any())).thenAnswer(
        (inv) async => inv.positionalArguments.first as TestEntity,
      );
      when(() => middleware.afterSync(any(), any())).thenAnswer((_) async {});
      when(() => middleware.afterOperation(any(), any()))
          .thenAnswer((_) async {});
      when(() => middleware.onOperationError(any(), any()))
          .thenAnswer((_) async {});
      when(() => middleware.onConflict(any(), any(), any()))
          .thenAnswer((_) async {});
      when(() => middleware.beforeSync(any())).thenAnswer((_) async {});
      when(() => middleware.beforeOperation(any())).thenAnswer((_) async {});

      manager = SynqManager<TestEntity>(
        localAdapter: localAdapter,
        remoteAdapter: remoteAdapter,
        conflictResolver: LastWriteWinsResolver<TestEntity>(),
        connectivity: MockConnectivityChecker(),
        synqConfig:
            const SynqConfig(maxRetries: 0), // Disable retries for tests
      )..addMiddleware(middleware);

      // Stub the metadata update calls as well, as they are part of the sync flow
      when(() => localAdapter.updateSyncMetadata(any(), any()))
          .thenAnswer((_) async {});
      when(() => remoteAdapter.updateSyncMetadata(any(), any()))
          .thenAnswer((_) async {});
      await manager.initialize();
    });

    tearDown(() async {
      await manager.dispose();
    });

    test('transformBeforeSave is called on save()', () async {
      when(() => localAdapter.getById(any(), any()))
          .thenAnswer((_) async => null);
      await manager.save(entity, userId);

      verify(() => middleware.transformBeforeSave(entity)).called(1);
    });

    test('transformAfterFetch is called on getById()', () async {
      when(() => localAdapter.getById(entity.id, userId))
          .thenAnswer((_) async => entity);

      await manager.getById(entity.id, userId);

      verify(() => middleware.transformAfterFetch(entity)).called(1);
    });

    test('transformAfterFetch is called on getAll()', () async {
      when(() => localAdapter.getAll(userId: userId))
          .thenAnswer((_) async => [entity]);
      when(() => localAdapter.getAll(userId: null))
          .thenAnswer((_) async => [entity]);

      await manager.getAll(userId: userId);

      verify(() => middleware.transformAfterFetch(entity)).called(1);
    });

    test('beforeSync and afterSync are called during sync', () async {
      await manager.sync(userId);

      verify(() => middleware.beforeSync(userId)).called(1);
      verify(() => middleware.afterSync(userId, any(that: isA<SyncResult>())))
          .called(1);
    });

    test(
        'beforeOperation and afterOperation are called for successful operation',
        () async {
      when(() => localAdapter.getById(any(), any()))
          .thenAnswer((_) async => null);
      when(() => remoteAdapter.push(any(), any())).thenAnswer(
        (inv) async => inv.positionalArguments.first as TestEntity,
      );
      // 1. Save an item to create a pending operation
      await manager.save(entity, userId);

      // 2. Run sync
      await manager.sync(userId);

      // 3. Verify hooks
      verify(
        () => middleware.beforeOperation(
          any(
            that: isA<SyncOperation<TestEntity>>()
                .having((op) => op.entityId, 'entityId', entity.id),
          ),
        ),
      ).called(1);

      verify(
        () => middleware.afterOperation(
          any(
            that: isA<SyncOperation<TestEntity>>()
                .having((op) => op.entityId, 'entityId', entity.id),
          ),
          any(that: isA<TestEntity>()),
        ),
      ).called(1);
    });

    test('onOperationError is called for a failed operation', () async {
      when(() => localAdapter.getById(any(), any()))
          .thenAnswer((_) async => null);
      // 1. Save an item to create a pending operation
      await manager.save(entity, userId);

      // 2. Make the remote push fail
      when(() => remoteAdapter.push(any(), any())).thenThrow(
        NetworkException('Simulated push failure'),
      );

      // 3. Run sync
      await manager.sync(userId);

      // 4. Verify error hook was called
      verify(
        () => middleware.onOperationError(
          any(
            that: isA<SyncOperation<TestEntity>>()
                .having((op) => op.entityId, 'entityId', entity.id),
          ),
          any(that: isA<SynqException>()),
        ),
      ).called(1);

      // Verify success hook was NOT called
      verifyNever(() => middleware.afterOperation(any(), any()));
    });

    test('onConflict is called when a conflict is detected', () async {
      // 1. Create a conflict scenario
      final local = entity.copyWith(version: 2, name: 'Local Edit');
      final remote = entity.copyWith(version: 3, name: 'Remote Edit');

      // Arrange: No pending operations, just different versions on local/remote.
      when(() => localAdapter.getPendingOperations(userId))
          .thenAnswer((_) async => []);
      when(() => remoteAdapter.fetchAll(userId, scope: any(named: 'scope')))
          .thenAnswer((_) async => [remote]);
      when(() => localAdapter.getByIds([remote.id], userId))
          .thenAnswer((_) async => {remote.id: local});
      // Stub the save call that happens inside conflict resolution
      when(() => localAdapter.save(remote, userId)).thenAnswer((_) async {});

      // 2. Run sync
      await manager.sync(userId);

      // 3. Verify the conflict hook was called as expected.
      verify(
        () => middleware.onConflict(
          any(
            that: isA<ConflictContext>()
                .having((c) => c.entityId, 'entityId', entity.id),
          ),
          local,
          remote,
        ),
      ).called(1);
    });

    test('Middleware can transform data on save', () async {
      // Arrange: Middleware adds a prefix to the name
      when(() => localAdapter.getById(any(), any()))
          .thenAnswer((_) async => null);
      final original = TestEntity(
        id: 'e1',
        userId: userId,
        name: 'Original',
        value: 0,
        modifiedAt: now,
        createdAt: now,
        version: 1,
      );
      when(() => middleware.transformBeforeSave(any())).thenAnswer((inv) async {
        final item = inv.positionalArguments.first as TestEntity;
        return item.copyWith(name: 'Transformed: ${item.name}');
      });

      // Act
      await manager.save(original, userId);

      // Assert: Verify that the transformed item was passed to the adapter
      final captured =
          verify(() => localAdapter.save(captureAny(), userId)).captured;
      expect(captured.single, isA<TestEntity>());
      expect((captured.single as TestEntity).name, 'Transformed: Original');
    });

    test('Middleware can transform data on fetch', () async {
      // Arrange: Middleware adds a suffix to the name on fetch
      final stored = TestEntity(
        id: 'e1',
        userId: userId,
        name: 'Stored',
        value: 0,
        modifiedAt: now,
        createdAt: now,
        version: 1,
      );
      when(() => localAdapter.getById(stored.id, userId))
          .thenAnswer((_) async => stored);

      when(() => middleware.transformAfterFetch(any())).thenAnswer((inv) async {
        final item = inv.positionalArguments.first as TestEntity;
        return item.copyWith(name: '${item.name} - Fetched');
      });

      // Act
      final result = await manager.getById(stored.id, userId);

      // Assert
      expect(result, isNotNull);
      expect(result!.name, 'Stored - Fetched');
    });
  });
}
