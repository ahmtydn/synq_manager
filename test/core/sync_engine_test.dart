import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:synq_manager/synq_manager.dart';

import '../mocks/test_entity.dart';

class MockedLocalAdapter<T extends SyncableEntity> extends Mock
    implements LocalAdapter<T> {}

class MockedRemoteAdapter<T extends SyncableEntity> extends Mock
    implements RemoteAdapter<T> {}

class MockedConnectivityChecker extends Mock implements ConnectivityChecker {}

void main() {
  group('SyncEngine', () {
    late MockedLocalAdapter<TestEntity> localAdapter;
    late MockedRemoteAdapter<TestEntity> remoteAdapter;
    late QueueManager<TestEntity> queueManager;
    late MockedConnectivityChecker connectivity;
    late StreamController<SyncEvent<TestEntity>> eventController;
    late BehaviorSubject<SyncStatusSnapshot> statusSubject;
    late BehaviorSubject<SyncMetadata> metadataSubject;
    late SyncEngine<TestEntity> syncEngine;

    setUpAll(() {
      registerFallbackValue(
        SyncMetadata(
          userId: 'fb',
          lastSyncTime: DateTime(0),
          dataHash: 'fb',
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
    });
    setUp(() {
      localAdapter = MockedLocalAdapter<TestEntity>();
      remoteAdapter = MockedRemoteAdapter<TestEntity>();
      queueManager = QueueManager<TestEntity>(
        localAdapter: localAdapter,
        logger: SynqLogger(),
      );
      connectivity = MockedConnectivityChecker();
      eventController = StreamController<SyncEvent<TestEntity>>.broadcast();
      statusSubject = BehaviorSubject<SyncStatusSnapshot>();
      metadataSubject = BehaviorSubject<SyncMetadata>();

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
        metadataSubject: metadataSubject,
        middlewares: const [],
        observers: const [],
      );

      when(() => localAdapter.updateSyncMetadata(any(), any()))
          .thenAnswer((_) async {});
      when(() => remoteAdapter.updateSyncMetadata(any(), any()))
          .thenAnswer((_) async {});

      // Add default stubs for methods called during sync
      when(() => localAdapter.getSyncMetadata(any()))
          .thenAnswer((_) async => null);
      when(() => remoteAdapter.getSyncMetadata(any()))
          .thenAnswer((_) async => null);
      when(() => connectivity.isConnected).thenAnswer((_) async => true);
      when(() => remoteAdapter.isConnected()).thenAnswer((_) async => true);
      when(() => localAdapter.getPendingOperations(any()))
          .thenAnswer((_) async => []);
      when(() => remoteAdapter.fetchAll(any(), scope: any(named: 'scope')))
          .thenAnswer((_) async => []);
      when(() => localAdapter.getByIds(any(), any()))
          .thenAnswer((_) async => {});
      when(() => localAdapter.getAll(userId: any(named: 'userId')))
          .thenAnswer((_) async => []);
      when(() => remoteAdapter.push(any(), any()))
          .thenAnswer((i) async => i.positionalArguments.first as TestEntity);
      when(() => localAdapter.push(any(), any())).thenAnswer((_) async {});
    });

    tearDown(() async {
      await queueManager.dispose();
      await eventController.close();
      await statusSubject.close();
      await metadataSubject.close();
    });

    test(
        'does not push anything if remote is empty and there are no pending ops',
        () async {
      // Arrange: Local adapter has an item, but it's not in the pending queue.
      // Remote is empty.
      final localEntity = TestEntity.create('e1', 'user-1', 'Local Only');
      when(() => localAdapter.getAll(userId: 'user-1'))
          .thenAnswer((_) async => [localEntity]);
      when(() => remoteAdapter.fetchAll('user-1', scope: any(named: 'scope')))
          .thenAnswer((_) async => []);

      // Act
      final result = await syncEngine.synchronize('user-1');

      // Assert: Nothing should be pushed because there are no pending operations.
      // The engine's job is to sync the queue, not discover discrepancies.
      verifyNever(() => remoteAdapter.push(any(), any()));
      verifyNever(() => remoteAdapter.patch(any(), any(), any()));

      // The sync should still be "successful" as it completed without errors.
      expect(result.failedCount, 0);
      expect(result.syncedCount, 0);
    });

    test('emits SyncMetadata on successful sync', () async {
      // Arrange
      final entity = TestEntity.create('e1', 'user-1', 'Metadata Test');
      when(() => localAdapter.getAll(userId: 'user-1'))
          .thenAnswer((_) async => [entity]);

      final futureMetadata = metadataSubject.stream.first;

      // Act
      await syncEngine.synchronize('user-1');

      // Assert
      final metadata = await futureMetadata;
      expect(metadata, isA<SyncMetadata>());
      expect(metadata.userId, 'user-1');
      expect(
        metadata.itemCount,
        1,
        reason:
            'Metadata should reflect the item count from localAdapter.getAll',
      );
      expect(metadata.dataHash, isNotEmpty);
      expect(
        metadata.lastSyncTime
            .isAfter(DateTime.now().subtract(const Duration(seconds: 5))),
        isTrue,
        reason: 'lastSyncTime should be recent',
      );
    });
  });
}
