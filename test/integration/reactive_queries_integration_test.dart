import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:synq_manager/src/models/user_switch_strategy.dart';
import 'package:synq_manager/synq_manager.dart';

import '../mocks/mock_adapters.dart';
import '../mocks/mock_connectivity_checker.dart';
import '../mocks/test_entity.dart';

void main() {
  group('Reactive Queries Integration Tests', () {
    late SynqManager<TestEntity> manager;
    late MockLocalAdapter<TestEntity> localAdapter;
    late MockRemoteAdapter<TestEntity> remoteAdapter;
    late MockConnectivityChecker connectivityChecker;

    setUp(() async {
      localAdapter =
          MockLocalAdapter<TestEntity>(fromJson: TestEntity.fromJson);
      remoteAdapter =
          MockRemoteAdapter<TestEntity>(fromJson: TestEntity.fromJson);
      connectivityChecker = MockConnectivityChecker();

      manager = SynqManager<TestEntity>(
        localAdapter: localAdapter,
        remoteAdapter: remoteAdapter,
        synqConfig: const SynqConfig(),
        connectivity: connectivityChecker,
      );

      await manager.initialize();
    });

    tearDown(() async {
      await manager.dispose();
      await connectivityChecker.dispose();
    });

    test('watchAll emits updated lists on data changes', () async {
      final entity1 = TestEntity.create('entity1', 'user1', 'Item 1');
      final entity2 = TestEntity.create('entity2', 'user1', 'Item 2');

      final stream = manager.watchAll(userId: 'user1');

      final completer = Completer<List<List<TestEntity>>>();
      final receivedEvents = <List<TestEntity>>[];

      final subscription = stream.listen((items) {
        receivedEvents.add(items);
        if (receivedEvents.length == 4) {
          completer.complete(receivedEvents);
        }
      });

      await manager.push(entity1, 'user1');
      await manager.push(entity2, 'user1');
      await manager.delete(entity1.id, 'user1');

      final allEvents = await completer.future;

      expect(allEvents[0], isEmpty);
      expect(allEvents[1], hasLength(1));
      expect(allEvents[1].first.id, 'entity1');
      expect(allEvents[2], hasLength(2));
      expect(allEvents[3], hasLength(1));
      expect(allEvents[3].first.id, 'entity2');

      await subscription.cancel();
    });

    test('watchById emits updated entity and null on deletion', () async {
      final entity = TestEntity.create('entity1', 'user1', 'Item 1');
      final updatedEntity = entity.copyWith(name: 'Updated Item');

      final stream = manager.watchById('entity1', 'user1');

      final completer = Completer<List<TestEntity?>>();
      final receivedEvents = <TestEntity?>[];

      final subscription = stream.listen((item) {
        receivedEvents.add(item);
        if (receivedEvents.length == 4) {
          completer.complete(receivedEvents);
        }
      });

      await manager.push(entity, 'user1');
      await manager.push(updatedEntity, 'user1');
      await manager.delete(entity.id, 'user1');

      final allEvents = await completer.future;

      expect(allEvents[0], isNull);
      expect(allEvents[1]?.name, 'Item 1');
      expect(allEvents[2]?.name, 'Updated Item');
      expect(allEvents[3], isNull);

      await subscription.cancel();
    });

    test('watchAllPaginated emits updated paginated results', () async {
      final entities = List.generate(
        3,
        (i) => TestEntity.create('entity$i', 'user1', 'Item $i'),
      );

      const config = PaginationConfig(pageSize: 2);
      final stream = manager.watchAllPaginated(config, userId: 'user1');

      final completer = Completer<List<PaginatedResult<TestEntity>>>();
      final receivedEvents = <PaginatedResult<TestEntity>>[];

      final subscription = stream.listen((result) {
        receivedEvents.add(result);
        if (receivedEvents.length == 5) {
          completer.complete(receivedEvents);
        }
      });

      await manager.push(entities[0], 'user1');
      await manager.push(entities[1], 'user1');
      await manager.push(entities[2], 'user1');
      await manager.delete(entities[0].id, 'user1');

      final allEvents = await completer.future;

      expect(allEvents[0].items, isEmpty);
      expect(allEvents[1].items, hasLength(1));
      expect(allEvents[2].items, hasLength(2));
      expect(allEvents[2].hasMore, isFalse);
      expect(allEvents[3].items, hasLength(2));
      expect(allEvents[3].hasMore, isTrue);
      expect(allEvents[4].items, hasLength(2));
      expect(allEvents[4].hasMore, isFalse);

      await subscription.cancel();
    });

    test('watchQuery emits filtered lists on data changes', () async {
      final pendingEntity1 = TestEntity.create('pending1', 'user1', 'Pending');
      final completedEntity = TestEntity.create('completed1', 'user1', 'Done')
          .copyWith(completed: true);

      const query = SynqQuery({'completed': false});
      final stream = manager.watchQuery(query, userId: 'user1');

      final completer = Completer<List<List<TestEntity>>>();
      final receivedEvents = <List<TestEntity>>[];

      final subscription = stream.listen((items) {
        receivedEvents.add(items);
        if (receivedEvents.length == 4) {
          completer.complete(receivedEvents);
        }
      });

      await manager.push(pendingEntity1, 'user1');
      await manager.push(completedEntity, 'user1');
      await manager.push(pendingEntity1.copyWith(completed: true), 'user1');

      final allEvents = await completer.future;

      expect(allEvents[0], isEmpty);
      expect(allEvents[1], hasLength(1));
      expect(allEvents[2], hasLength(1));
      expect(allEvents[3], isEmpty);

      await subscription.cancel();
    });

    test('watchAll stream is user-specific and works after user switch',
        () async {
      final user1Entity = TestEntity.create('entity1', 'user1', 'User1 Item');

      final user1Stream = manager.watchAll(userId: 'user1');
      expect(
        user1Stream,
        emitsInOrder([
          isEmpty,
          (List<TestEntity> list) => list.first.name == 'User1 Item',
        ]),
      );

      await manager.push(user1Entity, 'user1');

      await manager.switchUser(
        oldUserId: 'user1',
        newUserId: 'user2',
        strategy: UserSwitchStrategy.keepLocal,
      );

      final user2Entity = TestEntity.create('entity2', 'user2', 'User2 Item');
      final user2Stream = manager.watchAll(userId: 'user2');
      expect(
        user2Stream,
        emitsInOrder([isEmpty, (List<TestEntity> list) => list.length == 1]),
      );
      await manager.push(user2Entity, 'user2');
    });
  });
}
