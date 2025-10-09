import 'package:flutter_test/flutter_test.dart';
import 'package:synq_manager/src/core/queue_manager.dart';
import 'package:synq_manager/src/models/sync_operation.dart';
import 'package:synq_manager/src/utils/logger.dart';

import '../mocks/mock_adapters.dart';
import '../mocks/test_entity.dart';

void main() {
  group('QueueManager', () {
    late QueueManager<TestEntity> queueManager;
    late MockLocalAdapter<TestEntity> localAdapter;
    late SynqLogger logger;

    setUp(() {
      localAdapter = MockLocalAdapter<TestEntity>();
      logger = SynqLogger();
      queueManager = QueueManager<TestEntity>(
        localAdapter: localAdapter,
        logger: logger,
      );
    });

    tearDown(() async {
      await queueManager.dispose();
    });

    test('initializes user queue from local adapter', () async {
      final operation = SyncOperation<TestEntity>(
        id: 'op1',
        userId: 'user1',
        type: SyncOperationType.create,
        entityId: 'entity1',
        timestamp: DateTime.now(),
        data: TestEntity(
          id: 'entity1',
          userId: 'user1',
          name: 'Test',
          value: 42,
          modifiedAt: DateTime.now(),
          createdAt: DateTime.now(),
          version: 'v1',
        ),
      );

      await localAdapter.addPendingOperation('user1', operation);
      await queueManager.initializeUser('user1');

      final pending = queueManager.getPending('user1');
      expect(pending, hasLength(1));
      expect(pending.first.id, 'op1');
    });

    test('enqueues operations and broadcasts updates', () async {
      await queueManager.initializeUser('user1');

      final operation = SyncOperation<TestEntity>(
        id: 'op1',
        userId: 'user1',
        type: SyncOperationType.create,
        entityId: 'entity1',
        timestamp: DateTime.now(),
        data: TestEntity(
          id: 'entity1',
          userId: 'user1',
          name: 'Test',
          value: 42,
          modifiedAt: DateTime.now(),
          createdAt: DateTime.now(),
          version: 'v1',
        ),
      );

      final stream = queueManager.watch('user1');
      final future = stream.first;

      await queueManager.enqueue('user1', operation);

      final emitted = await future;
      expect(emitted, hasLength(1));
      expect(emitted.first.id, 'op1');
    });

    test('marks operations as completed', () async {
      final operation = SyncOperation<TestEntity>(
        id: 'op1',
        userId: 'user1',
        type: SyncOperationType.create,
        entityId: 'entity1',
        timestamp: DateTime.now(),
      );

      await queueManager.initializeUser('user1');
      await queueManager.enqueue('user1', operation);

      expect(queueManager.getPending('user1'), hasLength(1));

      await queueManager.markCompleted('user1', 'op1');

      expect(queueManager.getPending('user1'), isEmpty);
    });

    test('clears user queue', () async {
      await queueManager.initializeUser('user1');
      await queueManager.enqueue(
        'user1',
        SyncOperation<TestEntity>(
          id: 'op1',
          userId: 'user1',
          type: SyncOperationType.create,
          entityId: 'entity1',
          timestamp: DateTime.now(),
        ),
      );

      await queueManager.clear('user1');

      expect(queueManager.getPending('user1'), isEmpty);
    });

    test('handles multiple users independently', () async {
      await queueManager.initializeUser('user1');
      await queueManager.initializeUser('user2');

      await queueManager.enqueue(
        'user1',
        SyncOperation<TestEntity>(
          id: 'op1',
          userId: 'user1',
          type: SyncOperationType.create,
          entityId: 'entity1',
          timestamp: DateTime.now(),
        ),
      );

      await queueManager.enqueue(
        'user2',
        SyncOperation<TestEntity>(
          id: 'op2',
          userId: 'user2',
          type: SyncOperationType.update,
          entityId: 'entity2',
          timestamp: DateTime.now(),
        ),
      );

      expect(queueManager.getPending('user1'), hasLength(1));
      expect(queueManager.getPending('user2'), hasLength(1));
      expect(queueManager.getPending('user1').first.id, 'op1');
      expect(queueManager.getPending('user2').first.id, 'op2');
    });

    test('does not reinitialize if already initialized', () async {
      await queueManager.initializeUser('user1');
      await queueManager.enqueue(
        'user1',
        SyncOperation<TestEntity>(
          id: 'op1',
          userId: 'user1',
          type: SyncOperationType.create,
          entityId: 'entity1',
          timestamp: DateTime.now(),
        ),
      );

      await queueManager.initializeUser('user1');

      expect(queueManager.getPending('user1'), hasLength(1));
    });
  });
}
