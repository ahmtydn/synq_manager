import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:synq_manager/synq_manager.dart';

import '../mocks/mock_adapters.dart';
import '../mocks/test_entity.dart';

class MockObserver extends Mock implements SynqObserver<TestEntity> {}

void main() {
  group('SynqManager External Change Handling', () {
    late MockLocalAdapter<TestEntity> localAdapter;
    late MockRemoteAdapter<TestEntity> remoteAdapter;
    late SynqManager<TestEntity> manager;
    late MockObserver observer;

    const userId = 'user-1';
    final now = DateTime.now();
    final entity = TestEntity(
      id: 'entity-1',
      userId: userId,
      name: 'Initial',
      value: 1,
      modifiedAt: now,
      createdAt: now,
      version: 1,
    );

    setUpAll(() {
      // Register a fallback value for TestEntity to be used with `any()`
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
      localAdapter =
          MockLocalAdapter<TestEntity>(fromJson: TestEntity.fromJson);
      remoteAdapter =
          MockRemoteAdapter<TestEntity>(fromJson: TestEntity.fromJson);
      observer = MockObserver();

      manager = SynqManager<TestEntity>(
        localAdapter: localAdapter,
        remoteAdapter: remoteAdapter,
        synqConfig: const SynqConfig<TestEntity>(),
      )..addObserver(observer);

      // Register the mocktail fallback for ChangeDetail
      registerFallbackValue(
        ChangeDetail<TestEntity>(
          type: SyncOperationType.create,
          entityId: '',
          userId: '',
          timestamp: DateTime.now(),
        ),
      );
      registerFallbackValue(DataSource.local);
    });

    tearDown(() async {
      await manager.dispose();
    });

    test(
        'remote create change is saved locally but NOT re-queued for remote push',
        () async {
      // Arrange
      await manager.initialize();
      final remoteChange = ChangeDetail(
        // Use a fixed timestamp to ensure the changeKey is identical.
        timestamp: DateTime(2023),
        type: SyncOperationType.create,
        entityId: entity.id,
        userId: userId,
        data: entity,
      );

      // Act: Simulate a change from the remote adapter's stream
      remoteAdapter.emitChange(remoteChange);
      await Future<void>.delayed(
        const Duration(milliseconds: 100),
      ); // Process stream

      // Assert: Verify it was saved locally
      final localCopy = await localAdapter.getById(entity.id, userId);
      expect(localCopy, isNotNull);
      expect(localCopy?.name, 'Initial');

      // Assert: Verify it was NOT added to the pending queue
      final pendingOps = manager.getPendingOperations(userId);
      expect(pendingOps, isEmpty);

      // Assert: Verify observer was called with the correct source
      verify(
        () => observer.onExternalChange(
          any(),
          DataSource.remote,
        ),
      ).called(1);
    });

    test('remote delete change is applied locally but NOT re-queued', () async {
      // Arrange: Start with an item in local storage
      await localAdapter.push(entity, userId);
      await manager.initialize();

      // Silence adapters to prevent echo events during the test
      localAdapter.silent = true;
      remoteAdapter.silent = true;

      final deleteChange = ChangeDetail<TestEntity>(
        type: SyncOperationType.delete,
        entityId: entity.id,
        userId: userId,
        timestamp: DateTime.now(),
      );

      // Act: Simulate a delete event from remote
      remoteAdapter.emitChange(deleteChange);
      await Future<void>.delayed(
        const Duration(milliseconds: 100),
      ); // Process stream

      // Assert: Verify it was deleted locally
      final localCopy = await localAdapter.getById(entity.id, userId);
      expect(localCopy, isNull);

      // Assert: Verify no delete operation was queued
      final pendingOps = manager.getPendingOperations(userId);
      expect(pendingOps, isEmpty);

      // Assert: Verify observer was called
      verify(
        () => observer.onExternalChange(
          any(
            that: predicate<ChangeDetail<TestEntity>>(
              (d) => d.entityId == entity.id,
            ),
          ),
          DataSource.remote,
        ),
      ).called(1);
    });

    test('duplicate remote changes are processed only once', () async {
      // Arrange
      await manager.initialize();
      // Silence adapters to prevent echo events during the test
      localAdapter.silent = true;
      remoteAdapter.silent = true;

      final remoteChange = ChangeDetail(
        type: SyncOperationType.create,
        entityId: entity.id,
        userId: userId,
        timestamp: DateTime(2023), // Use a fixed timestamp for deduplication
        data: entity,
      );

      // Act: Simulate the exact same change arriving twice
      remoteAdapter
        ..emitChange(remoteChange)
        ..emitChange(remoteChange);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Assert: The observer is called for each incoming event, even duplicates,
      // as it fires before deduplication logic.
      verify(
        () => observer.onExternalChange(
          any(),
          DataSource.remote,
        ),
      ).called(2);

      // Assert: The push method (which applies the change) should only be called once
      // We can check this by looking at the observer for the save operation.
      verify(() => observer.onSaveStart(any(), userId, any())).called(1);
    });

    test('local adapter changes are processed with correct source', () async {
      // Arrange
      await manager.initialize();
      // Silence adapters to prevent echo events during the test
      localAdapter.silent = true;
      remoteAdapter.silent = true;

      final localChange = ChangeDetail(
        type: SyncOperationType.create,
        entityId: entity.id,
        userId: userId,
        timestamp: DateTime.now(),
        data: entity,
      );

      // Act: Simulate a change from the local adapter's stream
      localAdapter.emitChange(localChange);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Assert: Verify observer was called with the correct source
      verify(
        () => observer.onExternalChange(any(), DataSource.local),
      ).called(1);
    });
  });
}
