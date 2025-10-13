import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:synq_manager/src/models/user_switch_strategy.dart';
import 'package:synq_manager/synq_manager.dart';

import '../mocks/mock_adapters.dart';
import '../mocks/mock_connectivity_checker.dart';
import '../mocks/test_entity.dart';

class MockSynqObserver<T extends SyncableEntity> extends Mock
    implements SynqObserver<T> {}

void main() {
  group('User Switch Integration Tests', () {
    late SynqManager<TestEntity> manager;
    late MockLocalAdapter<TestEntity> localAdapter;
    late MockRemoteAdapter<TestEntity> remoteAdapter;
    late MockConnectivityChecker connectivityChecker;
    late MockSynqObserver<TestEntity> mockObserver;

    setUpAll(() {
      registerFallbackValue(UserSwitchResult.success(newUserId: 'fb'));
    });

    setUp(() async {
      localAdapter =
          MockLocalAdapter<TestEntity>(fromJson: TestEntity.fromJson);
      remoteAdapter =
          MockRemoteAdapter<TestEntity>(fromJson: TestEntity.fromJson);
      connectivityChecker = MockConnectivityChecker();
      mockObserver = MockSynqObserver<TestEntity>();

      manager = SynqManager<TestEntity>(
        localAdapter: localAdapter,
        remoteAdapter: remoteAdapter,
        synqConfig: const SynqConfig(),
        connectivity: connectivityChecker,
      );

      await manager.initialize();
      manager.addObserver(mockObserver);
    });

    tearDown(() async {
      await manager.dispose();
    });

    test('switches users correctly with keepLocal strategy', () async {
      final user1Entity = TestEntity.create('entity1', 'user1', 'User1 Item');
      await manager.push(user1Entity, 'user1');

      final switchResult = await manager.switchUser(
        oldUserId: 'user1',
        newUserId: 'user2',
        strategy: UserSwitchStrategy.keepLocal,
      );

      expect(switchResult.success, isTrue);
      expect(switchResult.newUserId, 'user2');

      final user2Entity = TestEntity.create('entity2', 'user2', 'User2 Item');
      await manager.push(user2Entity, 'user2');

      final user1Items = await manager.getAll(userId: 'user1');
      final user2Items = await manager.getAll(userId: 'user2');

      expect(user1Items, hasLength(1));
      expect(user2Items, hasLength(1));
      expect(user1Items.first.name, 'User1 Item');
      expect(user2Items.first.name, 'User2 Item');

      verify(
        () => mockObserver.onUserSwitchStart(
          'user1',
          'user2',
          UserSwitchStrategy.keepLocal,
        ),
      ).called(1);
      verify(
        () => mockObserver.onUserSwitchEnd(
          any(
            that: isA<UserSwitchResult>()
                .having((r) => r.success, 'success', true),
          ),
        ),
      ).called(1);
    });

    test('switchUser with syncThenSwitch syncs old user data', () async {
      final user1Entity =
          TestEntity.create('entity1', 'user1', 'User1 Item to Sync');
      await manager.push(user1Entity, 'user1');
      expect(await manager.getPendingCount('user1'), 1);

      final switchResult = await manager.switchUser(
        oldUserId: 'user1',
        newUserId: 'user2',
        strategy: UserSwitchStrategy.syncThenSwitch,
      );

      expect(switchResult.success, isTrue);
      final remoteItems = await remoteAdapter.fetchAll('user1');
      expect(remoteItems, hasLength(1));
      expect(await manager.getPendingCount('user1'), 0);
    });

    test('switchUser with clearAndFetch clears new user data', () async {
      final localUser2Entity =
          TestEntity.create('local-entity', 'user2', 'Local User2 Item');
      await manager.push(localUser2Entity, 'user2');
      expect(await manager.getAll(userId: 'user2'), hasLength(1));

      final switchResult = await manager.switchUser(
        oldUserId: 'user1',
        newUserId: 'user2',
        strategy: UserSwitchStrategy.clearAndFetch,
      );

      expect(switchResult.success, isTrue);
      final user2Items = await manager.getAll(userId: 'user2');
      expect(user2Items, isEmpty);
    });

    test(
        'switchUser with promptIfUnsyncedData fails if data is unsynced and calls observer',
        () async {
      final user1Entity = TestEntity.create('entity1', 'user1', 'Unsynced');
      await manager.push(user1Entity, 'user1');

      final switchResult = await manager.switchUser(
        oldUserId: 'user1',
        newUserId: 'user2',
        strategy: UserSwitchStrategy.promptIfUnsyncedData,
      );

      expect(switchResult.success, isFalse);
      expect(switchResult.errorMessage, contains('Unsynced data present'));

      verify(
        () => mockObserver.onUserSwitchStart(
          'user1',
          'user2',
          UserSwitchStrategy.promptIfUnsyncedData,
        ),
      ).called(1);
      verify(
        () => mockObserver.onUserSwitchEnd(
          any(
            that: isA<UserSwitchResult>()
                .having((r) => r.success, 'success', false),
          ),
        ),
      ).called(1);
    });

    test('onUserSwitchEnd is called on failure', () async {
      // Arrange for failure
      final entity = TestEntity.create('e1', 'user1', 'unsynced');
      await manager.push(entity, 'user1');

      // Act
      await manager.switchUser(
        oldUserId: 'user1',
        newUserId: 'user2',
        strategy: UserSwitchStrategy.promptIfUnsyncedData,
      );

      // Assert
      verify(
        () => mockObserver.onUserSwitchEnd(
          any(
            that: isA<UserSwitchResult>()
                .having((r) => r.success, 'success', false)
                .having((r) => r.errorMessage, 'errorMessage', isNotNull),
          ),
        ),
      ).called(1);
    });
  });
}
