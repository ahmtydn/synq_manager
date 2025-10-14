import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:synq_manager/src/core/isolate_helper.dart';
import 'package:synq_manager/synq_manager.dart';

import '../mocks/test_entity.dart';

class MockedLocalAdapter<T extends SyncableEntity> extends Mock
    implements LocalAdapter<T> {}

class MockedRemoteAdapter<T extends SyncableEntity> extends Mock
    implements RemoteAdapter<T> {}

class MockedConnectivityChecker extends Mock implements ConnectivityChecker {}

class MockedIsolateHelper extends Mock implements IsolateHelper {}

void main() {
  group('SyncEngine', () {
    late MockedLocalAdapter<TestEntity> localAdapter;
    late MockedRemoteAdapter<TestEntity> remoteAdapter;
    late QueueManager<TestEntity> queueManager;
    late MockedConnectivityChecker connectivity;
    late StreamController<SyncEvent<TestEntity>> eventController;
    late BehaviorSubject<SyncStatusSnapshot> statusSubject;
    late BehaviorSubject<SyncMetadata> metadataSubject;
    late MockedIsolateHelper isolateHelper;
    late SyncEngine<TestEntity> syncEngine;

    setUpAll(() {
      registerFallbackValue(
        SyncMetadata(
          userId: 'fb',
          lastSyncTime: DateTime(0),
          dataHash: 'fb',
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
      isolateHelper = MockedIsolateHelper();

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
        isolateHelper: isolateHelper,
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
      when(() => isolateHelper.computeDataHash(any()))
          .thenAnswer((_) async => 'testhash');
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
      expect(metadata.entityCounts, isNotNull);
      expect(metadata.entityCounts!['TestEntity'], isNotNull);
      expect(
        metadata.entityCounts!['TestEntity']!.count,
        1,
        reason:
            'Metadata should reflect the item count from localAdapter.getAll',
      );
      expect(
        metadata.entityCounts!['TestEntity']!.hash,
        isNotEmpty,
        reason: 'Entity-specific hash should be generated',
      );

      expect(metadata.dataHash, isNotEmpty);
      expect(
        metadata.lastSyncTime
            .isAfter(DateTime.now().subtract(const Duration(seconds: 5))),
        isTrue,
        reason: 'lastSyncTime should be recent',
      );
    });

    test('correctly updates SyncMetadata after a pull operation', () async {
      // Arrange: Remote has one item, local has none.
      final remoteEntity = TestEntity.create('e1', 'user-1', 'Remote Item');
      when(() => remoteAdapter.fetchAll('user-1', scope: any(named: 'scope')))
          .thenAnswer((_) async => [remoteEntity]);

      // After the pull, localAdapter.getAll will be called to generate metadata.
      // It should now return the newly pulled item.
      when(() => localAdapter.getAll(userId: 'user-1'))
          .thenAnswer((_) async => [remoteEntity]);

      // Act
      await syncEngine.synchronize('user-1');

      // Assert: Check the captured metadata.
      // Capture the metadata that is saved to both local and remote adapters.
      final capturedLocalMeta =
          verify(() => localAdapter.updateSyncMetadata(captureAny(), 'user-1'))
              .captured;
      final capturedRemoteMeta =
          verify(() => remoteAdapter.updateSyncMetadata(captureAny(), 'user-1'))
              .captured;

      // It should be called once for local and once for remote.
      expect(capturedLocalMeta, hasLength(1));
      expect(capturedRemoteMeta, hasLength(1));

      final finalMetadata = capturedLocalMeta.first as SyncMetadata;
      expect(finalMetadata.userId, 'user-1');
      expect(finalMetadata.entityCounts, isNotNull);

      final entityDetails = finalMetadata.entityCounts!['TestEntity'];
      expect(entityDetails, isNotNull);
      expect(
        entityDetails!.count,
        1,
        reason: 'Metadata count should be 1 after pulling one item.',
      );
      expect(
        entityDetails.hash,
        'testhash',
        reason: 'A new hash should be computed based on the new local state.',
      );
    });
  });
}
