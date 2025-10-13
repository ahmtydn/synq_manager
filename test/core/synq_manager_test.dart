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
      // Stub for migration check during initialization
      when(() => localAdapter.transaction(any()))
          .thenAnswer((invocation) async {
        final action = invocation.positionalArguments.first as Function;
        return await action();
      });

      manager = SynqManager<TestEntity>(
        localAdapter: localAdapter,
        remoteAdapter: remoteAdapter,
        connectivity: connectivityChecker,
        // Use a schema version to match other tests and ensure migration logic runs
        synqConfig: const SynqConfig(schemaVersion: 1),
      );

      await manager.initialize();
    });

    tearDown(() async {
      await manager.dispose();
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

        // Act & Assert
        expect(
          manager.watchSyncStatistics(),
          emitsInOrder([
            isA<SyncStatistics>().having((s) => s.totalSyncs, 'totalSyncs', 0),
            isA<SyncStatistics>().having((s) => s.totalSyncs, 'totalSyncs', 1),
          ]),
        );

        await manager.sync(userId);
      });
    });
  });
}
