import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:synq_manager/synq_manager.dart';

import '../mocks/mock_adapters.dart';
import '../mocks/mock_connectivity_checker.dart';

class MockedRemoteAdapter<T extends SyncableEntity> extends Mock
    implements RemoteAdapter<T> {}

void main() {
  group('ExcludableEntity Integration Tests', () {
    late SynqManager<ExcludableEntity> manager;
    late MockLocalAdapter<ExcludableEntity> localAdapter;
    late MockedRemoteAdapter<ExcludableEntity> remoteAdapter;
    late MockConnectivityChecker connectivityChecker;

    setUpAll(() {
      registerFallbackValue(
        ExcludableEntity(
          id: 'fb',
          userId: 'fb',
          name: 'fb',
          modifiedAt: DateTime(0),
          createdAt: DateTime(0),
          version: 0,
        ),
      );
      registerFallbackValue(<String, dynamic>{});
      registerFallbackValue(
        SyncMetadata(
          userId: 'fb',
          lastSyncTime: DateTime(0),
          dataHash: 'fb',
        ),
      );
    });

    setUp(() async {
      localAdapter = MockLocalAdapter(fromJson: ExcludableEntity.fromJson);
      remoteAdapter = MockedRemoteAdapter<ExcludableEntity>();
      connectivityChecker = MockConnectivityChecker()
        ..triggerStatusChange(isConnected: true);

      when(() => remoteAdapter.name).thenReturn('MockedRemoteAdapter');
      when(() => remoteAdapter.isConnected()).thenAnswer((_) async => true);

      manager = SynqManager<ExcludableEntity>(
        localAdapter: localAdapter,
        remoteAdapter: remoteAdapter,
        connectivity: connectivityChecker,
      );

      await manager.initialize();
    });

    group('Unit Tests', () {
      test('fromJson creates a correct object', () {
        final json = {
          'id': 'e1',
          'userId': 'u1',
          'name': 'Test',
          'modifiedAt': DateTime(2023).toIso8601String(),
          'createdAt': DateTime(2023).toIso8601String(),
          'version': 1,
          'isDeleted': false,
          'localOnlyFields': {'local': 'abc'},
          'remoteOnlyFields': {'remote': 'xyz'},
        };

        final entity = ExcludableEntity.fromJson(json);

        expect(entity.id, 'e1');
        expect(entity.name, 'Test');
        expect(entity.localOnlyFields, containsPair('local', 'abc'));
        expect(entity.remoteOnlyFields, containsPair('remote', 'xyz'));
      });

      test('toMap respects MapTarget', () {
        final entity = ExcludableEntity(
          id: 'e1',
          userId: 'u1',
          name: 'Test',
          modifiedAt: DateTime(2023),
          createdAt: DateTime(2023),
          version: 1,
          localOnlyFields: const {'local': 'abc'},
          remoteOnlyFields: const {'remote': 'xyz'},
        );

        final localMap = entity.toMap();
        expect(localMap, containsPair('local', 'abc'));
        expect(localMap.containsKey('remote'), isFalse);

        final remoteMap = entity.toMap(target: MapTarget.remote);
        expect(remoteMap, containsPair('remote', 'xyz'));
        expect(remoteMap.containsKey('local'), isFalse);
      });

      test('copyWith creates a correct copy', () {
        final original = ExcludableEntity(
          id: 'e1',
          userId: 'u1',
          name: 'Original',
          modifiedAt: DateTime(2023),
          createdAt: DateTime(2023),
          version: 1,
          localOnlyFields: const {'local': 'a'},
          remoteOnlyFields: const {'remote': 'b'},
        );

        final updated = original.copyWith(
          name: 'Updated',
          version: 2,
          localOnlyFields: const {'local': 'c'},
        );

        expect(updated.id, original.id);
        expect(updated.name, 'Updated');
        expect(updated.version, 2);
        expect(updated.localOnlyFields, containsPair('local', 'c'));
        expect(updated.remoteOnlyFields, original.remoteOnlyFields);
      });

      test('diff includes remoteOnlyFields changes', () {
        final initial = ExcludableEntity(
          id: 'e1',
          userId: 'u1',
          name: 'Initial',
          modifiedAt: DateTime.now(),
          createdAt: DateTime.now(),
          version: 1,
          remoteOnlyFields: const {'remoteKey': 'value-abc'},
        );
        final updated = initial.copyWith(
          remoteOnlyFields: const {'remoteKey': 'value-xyz'},
          name: 'Updated',
        );

        final delta = updated.diff(initial);

        expect(delta, isNotNull);
        // Verify that remote-only fields are in the diff.
        expect(delta!.containsKey('remoteKey'), isTrue);
        expect(delta['remoteKey'], 'value-xyz');
        expect(delta.containsKey('name'), isTrue);
        expect(delta['name'], 'Updated');
      });
    });

    test('localOnlyFields are not included in remote patch delta', () async {
      final initial = ExcludableEntity(
        id: 'e1',
        userId: 'u1',
        name: 'Initial',
        modifiedAt: DateTime.now(),
        createdAt: DateTime.now(),
        version: 1,
        localOnlyFields: const {'localCacheKey': 'cache-abc'},
      );
      await manager.push(initial, 'u1');
      final updated = initial.copyWith(
        localOnlyFields: const {'localCacheKey': 'cache-xyz'},
        name: 'Updated',
      );

      final delta = updated.diff(initial);

      expect(delta, isNotNull);
      // Verify that none of the local-only fields are in the diff.
      expect(delta!.containsKey('localCacheKey'), isFalse);
      expect(delta.containsKey('name'), isTrue);
      expect(delta['name'], 'Updated');
    });

    test('remoteOnlyFields are included in remote push and patch', () async {
      // Arrange
      when(() => remoteAdapter.push(any(), any())).thenAnswer(
        (inv) async => inv.positionalArguments.first as ExcludableEntity,
      );
      when(() => remoteAdapter.patch(any(), any(), any())).thenAnswer(
        (inv) async => ExcludableEntity.fromJson(
          inv.positionalArguments[2] as Map<String, dynamic>,
        ),
      );

      // 1. Test push (create)
      final initial = ExcludableEntity(
        id: 'e2',
        userId: 'u1',
        name: 'Remote Test',
        modifiedAt: DateTime.now(),
        createdAt: DateTime.now(),
        version: 1,
        remoteOnlyFields: const {'sessionToken': 'token-123'},
      );
      await manager.push(initial, 'u1');

      // Assert that the map sent to the local adapter for the pending op includes the remote field
      final pendingOp = localAdapter.getPending('u1').first;
      final remoteMap = pendingOp.data!.toMap(target: MapTarget.remote);

      // The remote-only fields should be present in the remote map.
      expect(remoteMap, containsPair('sessionToken', 'token-123'));
      // The local-only fields should NOT be present.
      expect(remoteMap.containsKey('localCacheKey'), isFalse);
    });

    test('remoteOnlyFields are included in remote patch delta', () async {
      // Arrange
      when(() => remoteAdapter.push(any(), any())).thenAnswer(
        (inv) async => inv.positionalArguments.first as ExcludableEntity,
      );
      when(() => remoteAdapter.patch(any(), any(), any())).thenAnswer(
        (inv) async => ExcludableEntity.fromJson(
          inv.positionalArguments[2] as Map<String, dynamic>,
        ),
      );
      when(() => remoteAdapter.fetchAll(any(), scope: any(named: 'scope')))
          .thenAnswer((_) async => []);
      when(() => remoteAdapter.updateSyncMetadata(any(), any()))
          .thenAnswer((_) async {});

      // 1. Create and sync an initial entity
      final initial = ExcludableEntity(
        id: 'e-patch',
        userId: 'u1',
        name: 'Initial',
        modifiedAt: DateTime.now(),
        createdAt: DateTime.now(),
        version: 1,
      );
      await manager.push(initial, 'u1');
      await manager.sync('u1');

      // 2. Update the entity with a remote-only field and sync again
      final updated = initial.copyWith(
        remoteOnlyFields: const {'sessionToken': 'token-456'},
      );
      await manager.push(updated, 'u1');
      await manager.sync('u1');

      // Assert that the map sent to the remote adapter for the patch includes the remote field
      final captured = verify(
        () => remoteAdapter.patch('e-patch', 'u1', captureAny()),
      ).captured.single as Map<String, dynamic>;

      expect(captured, containsPair('sessionToken', 'token-456'));
    });

    test('localOnlyFields are saved locally but not sent to remote', () async {
      // Arrange
      when(() => remoteAdapter.push(any(), any())).thenAnswer(
        (inv) async => inv.positionalArguments.first as ExcludableEntity,
      );
      when(() => remoteAdapter.fetchAll(any(), scope: any(named: 'scope')))
          .thenAnswer((_) async => []);
      when(() => remoteAdapter.updateSyncMetadata(any(), any()))
          .thenAnswer((_) async {});

      final entity = ExcludableEntity(
        id: 'e3',
        userId: 'u1',
        name: 'Local Only Test',
        modifiedAt: DateTime.now(),
        createdAt: DateTime.now(),
        version: 1,
        localOnlyFields: const {'localCacheKey': 'cache-data'},
      );

      // Act
      await manager.push(entity, 'u1');
      await manager.sync('u1');

      // Assert: The data saved to the local adapter should contain the field.
      final localData = await localAdapter.getById('e3', 'u1');
      expect(localData!.localOnlyFields,
          containsPair('localCacheKey', 'cache-data'),);

      // Assert: The data pushed to the remote adapter should NOT contain the field.
      final captured =
          verify(() => remoteAdapter.push(captureAny(), 'u1')).captured;
      expect(
          (captured.first as ExcludableEntity).toMap(target: MapTarget.remote),
          isNot(contains('localCacheKey')),);
    });
  });
}
