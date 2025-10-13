import 'package:flutter_test/flutter_test.dart';
import 'package:synq_manager/synq_manager.dart';

import '../mocks/test_entity.dart';

void main() {
  group('SyncEvent toString()', () {
    const userId = 'user-123';
    final timestamp = DateTime(2023, 1, 1, 10, 30);

    test('SyncEvent base class', () {
      // Abstract class, tested via a concrete implementation
      final event = SyncStartedEvent(
        userId: userId,
        pendingOperations: 5,
        timestamp: timestamp,
      );
      expect(
        event.toString(),
        contains('SyncEvent(userId: $userId, timestamp: $timestamp)'),
      );
    });

    test('SyncStartedEvent', () {
      final event = SyncStartedEvent(
        userId: userId,
        pendingOperations: 10,
        timestamp: timestamp,
      );
      expect(
        event.toString(),
        'SyncEvent(userId: $userId, timestamp: $timestamp): SyncStartedEvent(pendingOperations: 10)',
      );
    });

    test('SyncProgressEvent', () {
      final event = SyncProgressEvent(
        userId: userId,
        completed: 5,
        total: 10,
        timestamp: timestamp,
      );
      expect(
        event.toString(),
        'SyncEvent(userId: $userId, timestamp: $timestamp): SyncProgressEvent(completed: 5, total: 10, progress: 0.5)',
      );
    });

    test('SyncCompletedEvent', () {
      const result = SyncResult(
        userId: userId,
        syncedCount: 8,
        failedCount: 2,
        conflictsResolved: 0,
        pendingOperations: const [],
        duration: Duration.zero,
      );
      final event = SyncCompletedEvent(
        userId: userId,
        result: result,
        timestamp: timestamp,
      );
      expect(
        event.toString(),
        'SyncEvent(userId: $userId, timestamp: $timestamp): SyncCompletedEvent(result: $result)',
      );
    });

    test('SyncErrorEvent', () {
      final event = SyncErrorEvent(
        userId: userId,
        error: 'Network timeout',
        isRecoverable: false,
        timestamp: timestamp,
      );
      expect(
        event.toString(),
        'SyncEvent(userId: $userId, timestamp: $timestamp): SyncErrorEvent(error: Network timeout, stackTrace: null, isRecoverable: false)',
      );
    });

    test('UserSwitchedEvent', () {
      final event = UserSwitchedEvent<TestEntity>(
        previousUserId: 'user-old',
        newUserId: 'user-new',
        hadUnsyncedData: true,
        timestamp: timestamp,
      );
      expect(
        event.toString(),
        'SyncEvent(userId: user-new, timestamp: $timestamp): UserSwitchedEvent(previousUserId: user-old, newUserId: user-new, hadUnsyncedData: true)',
      );
    });

    test('DataChangeEvent', () {
      final entity = TestEntity(
        id: 'entity-1',
        userId: userId,
        name: 'Test',
        value: 1,
        modifiedAt: timestamp,
        createdAt: timestamp,
        version: 1,
      );
      final event = DataChangeEvent<TestEntity>(
        userId: userId,
        data: entity,
        changeType: ChangeType.created,
        source: DataSource.local,
        timestamp: timestamp,
      );
      expect(
        event.toString(),
        'SyncEvent(userId: $userId, timestamp: $timestamp): DataChangeEvent(data: $entity, changeType: ChangeType.created, source: DataSource.local)',
      );
    });

    test('InitialSyncEvent', () {
      final entity = TestEntity(
        id: 'entity-1',
        userId: userId,
        name: 'Test',
        value: 1,
        modifiedAt: timestamp,
        createdAt: timestamp,
        version: 1,
      );
      final event = InitialSyncEvent<TestEntity>(
        userId: userId,
        data: [entity],
        timestamp: timestamp,
      );
      expect(
        event.toString(),
        'SyncEvent(userId: $userId, timestamp: $timestamp): InitialSyncEvent(data: [$entity])',
      );
    });

    test('ConflictDetectedEvent', () {
      final context = ConflictContext(
        userId: userId,
        entityId: 'entity-1',
        type: ConflictType.bothModified,
        detectedAt: timestamp,
      );
      final event = ConflictDetectedEvent<TestEntity>(
        userId: userId,
        context: context,
        timestamp: timestamp,
      );
      expect(
        event.toString(),
        'SyncEvent(userId: $userId, timestamp: $timestamp): ConflictDetectedEvent(context: $context, localData: null, remoteData: null)',
      );
    });
  });
}
