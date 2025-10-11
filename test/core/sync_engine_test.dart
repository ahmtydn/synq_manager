import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rxdart/rxdart.dart';
import 'package:synq_manager/src/config/synq_config.dart';
import 'package:synq_manager/src/core/conflict_detector.dart';
import 'package:synq_manager/src/core/queue_manager.dart';
import 'package:synq_manager/src/core/sync_engine.dart';
import 'package:synq_manager/src/events/sync_event.dart';
import 'package:synq_manager/src/models/sync_result.dart';
import 'package:synq_manager/src/resolvers/last_write_wins_resolver.dart';
import 'package:synq_manager/src/utils/logger.dart';

import '../mocks/mock_adapters.dart';
import '../mocks/mock_connectivity_checker.dart';
import '../mocks/test_entity.dart';

void main() {
  group('SyncEngine', () {
    late MockLocalAdapter<TestEntity> localAdapter;
    late MockRemoteAdapter<TestEntity> remoteAdapter;
    late QueueManager<TestEntity> queueManager;
    late MockConnectivityChecker connectivity;
    late StreamController<SyncEvent<TestEntity>> eventController;
    late BehaviorSubject<SyncStatusSnapshot> statusSubject;
    late SyncEngine<TestEntity> syncEngine;

    setUp(() {
      localAdapter = MockLocalAdapter<TestEntity>();
      remoteAdapter = MockRemoteAdapter<TestEntity>();
      queueManager = QueueManager<TestEntity>(
        localAdapter: localAdapter,
        logger: SynqLogger(),
      );
      connectivity = MockConnectivityChecker();
      eventController = StreamController<SyncEvent<TestEntity>>.broadcast();
      statusSubject = BehaviorSubject<SyncStatusSnapshot>();

      syncEngine = SyncEngine<TestEntity>(
        localAdapter: localAdapter,
        remoteAdapter: remoteAdapter,
        conflictResolver: LastWriteWinsResolver<TestEntity>(),
        queueManager: queueManager,
        conflictDetector: ConflictDetector<TestEntity>(),
        logger: SynqLogger(),
        config: SynqConfig.defaultConfig(),
        connectivityChecker: connectivity,
        eventController: eventController,
        statusSubject: statusSubject,
        middlewares: const [],
      );
    });

    tearDown(() async {
      await queueManager.dispose();
      await eventController.close();
      await statusSubject.close();
      await connectivity.dispose();
    });

    test('restores remote data when remote is empty but local has entities',
        () async {
      final entity = TestEntity(
        id: 'entity-1',
        userId: 'user-1',
        name: 'Local Only',
        value: 1,
        modifiedAt: DateTime.now(),
        createdAt: DateTime.now(),
        version: 1,
      );

      await localAdapter.save(entity, 'user-1');

      final result = await syncEngine.synchronize('user-1');

      final remoteItems = await remoteAdapter.fetchAll('user-1');
      expect(remoteItems, contains(entity));

      final localItems = await localAdapter.getAll(userId: 'user-1');
      expect(localItems, contains(entity));

      expect(result.failedCount, 0);
    });
  });
}
