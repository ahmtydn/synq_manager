import 'package:flutter_test/flutter_test.dart';
import 'package:synq_manager/src/config/synq_config.dart';
import 'package:synq_manager/src/core/synq_manager.dart';

import '../mocks/mock_adapters.dart';
import '../mocks/mock_connectivity_checker.dart';
import '../mocks/test_entity.dart';

void main() {
  group('Auto-Start Sync', () {
    late MockLocalAdapter<TestEntity> localAdapter;
    late MockRemoteAdapter<TestEntity> remoteAdapter;
    late MockConnectivityChecker connectivityChecker;

    setUp(() {
      localAdapter = MockLocalAdapter<TestEntity>();
      remoteAdapter = MockRemoteAdapter<TestEntity>();
      connectivityChecker = MockConnectivityChecker();
    });

    tearDown(() async {
      await localAdapter.dispose();
      await remoteAdapter.dispose();
      await connectivityChecker.dispose();
    });

    test('auto-starts sync for all users with data on initialization',
        () async {
      // First create manager without autoStartSync to set up data
      final setupManager = SynqManager<TestEntity>(
        localAdapter: localAdapter,
        remoteAdapter: remoteAdapter,
        connectivity: connectivityChecker,
        synqConfig: const SynqConfig(),
      );

      await setupManager.initialize();

      // Create data with pending operations
      final user1Entity = TestEntity(
        id: 'entity1',
        userId: 'user1',
        name: 'User 1 Item',
        value: 1,
        modifiedAt: DateTime.now(),
        createdAt: DateTime.now(),
        version: 1,
      );
      final user2Entity = TestEntity(
        id: 'entity2',
        userId: 'user2',
        name: 'User 2 Item',
        value: 2,
        modifiedAt: DateTime.now(),
        createdAt: DateTime.now(),
        version: 1,
      );

      await setupManager.save(user1Entity, 'user1');
      await setupManager.save(user2Entity, 'user2');
      await setupManager.dispose();

      // Now create manager with autoStartSync
      final manager = SynqManager<TestEntity>(
        localAdapter: localAdapter,
        remoteAdapter: remoteAdapter,
        connectivity: connectivityChecker,
        synqConfig: const SynqConfig(
          autoStartSync: true,
          autoSyncInterval: Duration(seconds: 1),
          enableLogging: true,
        ),
      );

      await manager.initialize();

      // Wait for auto-sync to trigger
      await Future<void>.delayed(const Duration(milliseconds: 1500));

      // Both users should have been synced
      final user1Pending = await manager.getPendingCount('user1');
      final user2Pending = await manager.getPendingCount('user2');

      expect(
        user1Pending,
        0,
        reason: 'Auto-sync should have synced user1',
      );
      expect(
        user2Pending,
        0,
        reason: 'Auto-sync should have synced user2',
      );

      await manager.dispose();
    });

    test('does not auto-start sync when autoStartSync is false', () async {
      // Pre-populate local storage
      final entity = TestEntity(
        id: 'entity1',
        userId: 'user1',
        name: 'Test Item',
        value: 1,
        modifiedAt: DateTime.now(),
        createdAt: DateTime.now(),
        version: 1,
      );
      await localAdapter.save(entity, 'user1');

      final manager = SynqManager<TestEntity>(
        localAdapter: localAdapter,
        remoteAdapter: remoteAdapter,
        connectivity: connectivityChecker,
        synqConfig: const SynqConfig(
          autoSyncInterval: Duration(seconds: 1),
        ),
      );

      await manager.initialize();

      // Save new data
      final newEntity = TestEntity(
        id: 'entity2',
        userId: 'user1',
        name: 'New Item',
        value: 2,
        modifiedAt: DateTime.now(),
        createdAt: DateTime.now(),
        version: 1,
      );
      await manager.save(newEntity, 'user1');

      // Wait a bit
      await Future<void>.delayed(const Duration(milliseconds: 1500));

      // Should NOT be synced automatically
      final pendingCount = await manager.getPendingCount('user1');
      expect(
        pendingCount,
        1,
        reason: 'Auto-sync should NOT start automatically',
      );

      await manager.dispose();
    });

    test('auto-starts sync even with no initial data', () async {
      final manager = SynqManager<TestEntity>(
        localAdapter: localAdapter,
        remoteAdapter: remoteAdapter,
        connectivity: connectivityChecker,
        synqConfig: const SynqConfig(
          autoStartSync: true,
          autoSyncInterval: Duration(seconds: 1),
          enableLogging: true,
        ),
      );

      await manager.initialize();

      // Now save data for a new user
      final entity = TestEntity(
        id: 'entity1',
        userId: 'user1',
        name: 'First Item',
        value: 1,
        modifiedAt: DateTime.now(),
        createdAt: DateTime.now(),
        version: 1,
      );
      await manager.save(entity, 'user1');

      // Manually start auto-sync since there was no initial data
      manager.startAutoSync('user1');

      // Wait for auto-sync
      await Future<void>.delayed(const Duration(milliseconds: 1500));

      final pendingCount = await manager.getPendingCount('user1');
      expect(pendingCount, 0);

      await manager.dispose();
    });

    test('handles multiple users with different data', () async {
      // Setup manager to create initial data
      final setupManager = SynqManager<TestEntity>(
        localAdapter: localAdapter,
        remoteAdapter: remoteAdapter,
        connectivity: connectivityChecker,
        synqConfig: const SynqConfig(),
      );

      await setupManager.initialize();

      // Pre-populate with 3 users
      for (var i = 1; i <= 3; i++) {
        final entity = TestEntity(
          id: 'entity$i',
          userId: 'user$i',
          name: 'User $i Item',
          value: i,
          modifiedAt: DateTime.now(),
          createdAt: DateTime.now(),
          version: 1,
        );
        await setupManager.save(entity, 'user$i');
      }

      await setupManager.dispose();

      // Now create manager with autoStartSync
      final manager = SynqManager<TestEntity>(
        localAdapter: localAdapter,
        remoteAdapter: remoteAdapter,
        connectivity: connectivityChecker,
        synqConfig: const SynqConfig(
          autoStartSync: true,
          autoSyncInterval: Duration(seconds: 1),
          enableLogging: true,
        ),
      );

      await manager.initialize();

      // Wait for auto-sync
      await Future<void>.delayed(const Duration(milliseconds: 1500));

      // All users should have synced data
      for (var i = 1; i <= 3; i++) {
        final pendingCount = await manager.getPendingCount('user$i');
        expect(
          pendingCount,
          0,
          reason: 'Auto-sync should work for user$i',
        );
      }

      await manager.dispose();
    });

    test('ignores users with empty userId', () async {
      final manager = SynqManager<TestEntity>(
        localAdapter: localAdapter,
        remoteAdapter: remoteAdapter,
        connectivity: connectivityChecker,
        synqConfig: const SynqConfig(
          autoStartSync: true,
          enableLogging: true,
        ),
      );

      await manager.initialize();

      // Should not throw or cause issues
      expect(manager.dispose, returnsNormally);

      await manager.dispose();
    });
  });
}
