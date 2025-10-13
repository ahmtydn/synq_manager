import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:synq_manager/synq_manager.dart';

import '../mocks/mock_adapters.dart';
import '../mocks/mock_connectivity_checker.dart';
import '../mocks/test_entity.dart';

class MockSynqObserver<T extends SyncableEntity> extends Mock
    implements SynqObserver<T> {}

void main() {
  group('SynqObserver Integration Tests', () {
    late SynqManager<TestEntity> manager;
    late MockLocalAdapter<TestEntity> localAdapter;
    late MockRemoteAdapter<TestEntity> remoteAdapter;
    late MockConnectivityChecker connectivityChecker;
    late MockSynqObserver<TestEntity> mockObserver;

    setUpAll(() {
      registerFallbackValue(TestEntity.create('fb', 'fb', 'fb'));
      registerFallbackValue(DataSource.local);
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
        SyncOperation<TestEntity>(
          id: 'fb',
          userId: 'fb',
          entityId: 'fb',
          type: SyncOperationType.create,
          timestamp: DateTime(0),
        ),
      );
      registerFallbackValue(StackTrace.empty);
      registerFallbackValue(
        ConflictContext(
          userId: 'fb',
          entityId: 'fb',
          type: ConflictType.bothModified,
          detectedAt: DateTime(0),
        ),
      );
      registerFallbackValue(ConflictResolution<TestEntity>.abort('fb'));
      registerFallbackValue(UserSwitchResult.success(newUserId: 'fb'));
    });

    setUp(() async {
      localAdapter =
          MockLocalAdapter<TestEntity>(fromJson: TestEntity.fromJson);
      remoteAdapter =
          MockRemoteAdapter<TestEntity>(fromJson: TestEntity.fromJson);
      connectivityChecker = MockConnectivityChecker();
      mockObserver = MockSynqObserver<TestEntity>();

      manager = SynqManager<TestEntity>(
        localAdapter: localAdapter,
        remoteAdapter: remoteAdapter,
        conflictResolver: LastWriteWinsResolver<TestEntity>(),
        synqConfig: const SynqConfig(maxRetries: 0),
        connectivity: connectivityChecker,
      );

      await manager.initialize();
      manager.addObserver(mockObserver);
    });

    tearDown(() async {
      await manager.dispose();
    });

    test('onSaveStart and onSaveEnd are called on push()', () async {
      final entity = TestEntity.create('obs-e1', 'user1', 'Observer Test');
      await manager.push(entity, 'user1');

      verify(
        () => mockObserver.onSaveStart(entity, 'user1', DataSource.local),
      ).called(1);
      verify(() => mockObserver.onPushEnd(entity, 'user1', DataSource.local))
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
      await manager.push(entity, 'user1');

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
      await manager.push(entity, 'user1');
      remoteAdapter.setFailedIds(['op-e2']); // Make remote push fail

      await manager.sync('user1');

      verifyNever(
        () => mockObserver.onOperationSuccess(any(), any()),
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
  });
}
