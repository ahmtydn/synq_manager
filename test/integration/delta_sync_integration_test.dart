import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:synq_manager/synq_manager.dart';

import '../mocks/mock_adapters.dart';
import '../mocks/mock_connectivity_checker.dart';
import '../mocks/test_entity.dart';

class MockedRemoteAdapter<T extends SyncableEntity> extends Mock
    implements RemoteAdapter<T> {}

void main() {
  group('Delta Sync Integration Tests', () {
    late SynqManager<TestEntity> manager;
    late MockLocalAdapter<TestEntity> localAdapter;
    late MockedRemoteAdapter<TestEntity> remoteAdapter;
    late MockConnectivityChecker connectivityChecker;

    setUpAll(() {
      registerFallbackValue(
        TestEntity.create('fb', 'fb', 'fb'),
      );
      registerFallbackValue(
        <String, dynamic>{},
      );
      registerFallbackValue(
        SyncMetadata(
          userId: 'fb',
          lastSyncTime: DateTime(0),
          dataHash: 'fb',
          itemCount: 0,
        ),
      );
    });

    setUp(() async {
      localAdapter =
          MockLocalAdapter<TestEntity>(fromJson: TestEntity.fromJson);
      remoteAdapter = MockedRemoteAdapter<TestEntity>();
      connectivityChecker = MockConnectivityChecker();

      manager = SynqManager<TestEntity>(
        localAdapter: localAdapter,
        remoteAdapter: remoteAdapter,
        synqConfig: const SynqConfig(),
        connectivity: connectivityChecker,
      );

      // Stub required methods for the mock remote adapter
      when(() => remoteAdapter.name).thenReturn('MockedRemoteAdapter');
      when(() => remoteAdapter.isConnected()).thenAnswer((_) async => true);

      // Stub the patch method for remote adapter
      when(() => remoteAdapter.patch(any(), any(), any())).thenAnswer(
        (inv) async =>
            TestEntity.create('patched', 'user1', 'Patched from remote'),
      );
      when(() => remoteAdapter.fetchAll(any(), scope: any(named: 'scope')))
          .thenAnswer((_) async => []);
      when(() => remoteAdapter.updateSyncMetadata(any(), any()))
          .thenAnswer((_) async {});

      await manager.initialize();
    });

    tearDown(() async {
      await manager.dispose();
    });

    test('uses delta sync (patch) for updates to minimize network traffic',
        () async {
      // 1. ARRANGE: Create and sync an initial entity.
      final initialEntity = TestEntity.create('delta-e1', 'user1', 'Initial');
      when(() => remoteAdapter.push(any(), any())).thenAnswer(
        (inv) async => inv.positionalArguments.first as TestEntity,
      );
      await manager.save(initialEntity, 'user1');
      await manager.sync('user1');

      // Verify it was pushed fully the first time.
      verify(() => remoteAdapter.push(any(), any())).called(1);
      expect(await manager.getPendingCount('user1'), 0);

      // 2. ACT: Update only one field of the entity and save it.
      final updatedEntity = initialEntity.copyWith(name: 'Updated Name');
      await manager.save(updatedEntity, 'user1');

      // Sync again.
      await manager.sync('user1');

      // 3. ASSERT: Verify that `patch` was called with only the changed field.
      final capturedDelta =
          verify(() => remoteAdapter.patch('delta-e1', 'user1', captureAny()))
              .captured
              .single as Map<String, dynamic>;

      // The delta should only contain the 'name' field.
      expect(capturedDelta, hasLength(1));
      expect(capturedDelta['name'], 'Updated Name');

      // Verify the queue is empty after the delta sync.
      expect(await manager.getPendingCount('user1'), 0);
    });
  });
}
