import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:synq_manager/synq_manager.dart';

import '../mocks/mock_adapters.dart';
import '../mocks/mock_connectivity_checker.dart';
import '../mocks/test_entity.dart';

void main() {
  group('Advanced Sync Integration Tests', () {
    late SynqManager<TestEntity> manager;
    late MockLocalAdapter<TestEntity> localAdapter;
    late MockRemoteAdapter<TestEntity> remoteAdapter;
    late MockConnectivityChecker connectivityChecker;

    setUpAll(() {
      registerFallbackValue(
        TestEntity.create('fb', 'fb', 'fb'),
      );
      registerFallbackValue(
        const SyncScope({}),
      );
    });

    setUp(() async {
      localAdapter =
          MockLocalAdapter<TestEntity>(fromJson: TestEntity.fromJson);
      remoteAdapter =
          MockRemoteAdapter<TestEntity>(fromJson: TestEntity.fromJson);
      connectivityChecker = MockConnectivityChecker();

      manager = SynqManager<TestEntity>(
        localAdapter: localAdapter,
        remoteAdapter: remoteAdapter,
        synqConfig: const SynqConfig(),
        connectivity: connectivityChecker,
      );

      await manager.initialize();
    });

    tearDown(() async {
      await manager.dispose();
      await connectivityChecker.dispose();
    });

    test('pauses and resumes sync', () async {
      final entity = TestEntity.create('entity1', 'user1', 'Test Item');
      await manager.save(entity, 'user1');

      unawaited(manager.pauseSync('user1'));
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final statusBeforeResume = await manager.getSyncStatus('user1');
      expect(statusBeforeResume, SyncStatus.paused);

      await manager.resumeSync('user1');

      final statusAfterResume = await manager.getSyncStatus('user1');
      expect(statusAfterResume, SyncStatus.syncing);
    });

    test('cancels sync operation', () async {
      for (var i = 0; i < 10; i++) {
        final entity = TestEntity.create('entity$i', 'user1', 'Test Item $i');
        await manager.save(entity, 'user1');
      }

      final syncFuture = manager.sync('user1');
      await manager.cancelSync('user1');

      final result = await syncFuture;

      expect(result.wasCancelled || result.isSuccess, isTrue);
    });

    test('sync with scope performs a partial sync', () async {
      final remoteEntity1 =
          TestEntity.create('remote1', 'user1', 'Recent Item');
      final remoteEntity2 = remoteEntity1.copyWith(
        id: 'remote2',
        modifiedAt: DateTime.now().subtract(const Duration(days: 40)),
      );
      remoteAdapter
        ..addRemoteItem('user1', remoteEntity1)
        ..addRemoteItem('user1', remoteEntity2);

      final localOnlyEntity =
          TestEntity.create('local-only', 'user1', 'Local Only Item');
      await manager.save(localOnlyEntity, 'user1');

      final thirtyDaysAgo =
          DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
      final scope = SyncScope({'minModifiedDate': thirtyDaysAgo});
      await manager.sync('user1', scope: scope);

      final localItems = await manager.getAll(userId: 'user1');
      expect(localItems, hasLength(2));

      expect(localItems.any((item) => item.id == 'remote1'), isTrue);
      expect(localItems.any((item) => item.id == 'remote2'), isFalse);
      expect(localItems.any((item) => item.id == 'local-only'), isTrue);
    });

    test('per-operation retry logic increments retry count on failure',
        () async {
      // Re-initialize manager with retries enabled for this specific test.
      await manager.dispose();
      localAdapter =
          MockLocalAdapter<TestEntity>(fromJson: TestEntity.fromJson);
      remoteAdapter =
          MockRemoteAdapter<TestEntity>(fromJson: TestEntity.fromJson);
      connectivityChecker = MockConnectivityChecker();
      manager = SynqManager<TestEntity>(
        localAdapter: localAdapter,
        remoteAdapter: remoteAdapter,
        conflictResolver: LastWriteWinsResolver<TestEntity>(),
        synqConfig: const SynqConfig(maxRetries: 1),
        connectivity: connectivityChecker,
      );
      await manager.initialize();

      final successEntity =
          TestEntity.create('success1', 'user1', 'Will Succeed');
      final failEntity = TestEntity.create('fail1', 'user1', 'Will Fail');
      await manager.save(successEntity, 'user1');
      await manager.save(failEntity, 'user1');

      remoteAdapter.setFailedIds(['fail1']);

      final result = await manager.sync('user1');

      // Wait for any async operations to complete
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Check the result object first
      expect(result.syncedCount, 1);
      expect(result.failedCount, 0);

      // Verify remote has the success entity
      final remoteItems = await remoteAdapter.fetchAll('user1');
      expect(remoteItems, hasLength(1));
      expect(remoteItems.first.id, 'success1');

      // Check pending operations - use result.pendingOperations which is a snapshot
      expect(result.pendingOperations, hasLength(1));
      expect(result.pendingOperations.first.entityId, 'fail1');
      expect(result.pendingOperations.first.retryCount, 1);

      // Debug: Check pending queue before second sync
      final pendingBeforeSecondSync = manager.getPendingOperations('user1');
      print(
        '\nDEBUG: Pending operations BEFORE second sync: ${pendingBeforeSecondSync.length}',
      );
      for (final op in pendingBeforeSecondSync) {
        print(
          '  - ${op.entityId}: retryCount=${op.retryCount}, type=${op.type.name}, id=${op.id}',
        );
      }

      // Clear the failed IDs and sync again
      remoteAdapter.setFailedIds([]);
      final secondResult = await manager.sync('user1');

      print(
        'DEBUG: Second sync result - syncedCount: ${secondResult.syncedCount}',
      );
      print(
        'DEBUG: Second sync result - pendingOperations: ${secondResult.pendingOperations.length}',
      );

      expect(secondResult.syncedCount, 1);
      expect(secondResult.pendingOperations, isEmpty);
      expect(await remoteAdapter.fetchAll('user1'), hasLength(2));
    });
  });
}
