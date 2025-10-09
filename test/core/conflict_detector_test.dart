import 'package:flutter_test/flutter_test.dart';
import 'package:synq_manager/src/core/conflict_detector.dart';
import 'package:synq_manager/src/models/conflict_context.dart';
import 'package:synq_manager/src/models/sync_metadata.dart';

import '../mocks/test_entity.dart';

void main() {
  group('ConflictDetector', () {
    late ConflictDetector<TestEntity> detector;

    setUp(() {
      detector = ConflictDetector<TestEntity>();
    });

    test('detects no conflict when both items are null', () {
      final context = detector.detect(
        localItem: null,
        remoteItem: null,
        userId: 'user1',
      );

      expect(context, isNull);
    });

    test('detects no conflict when only remote exists', () {
      final remote = TestEntity(
        id: 'entity1',
        userId: 'user1',
        name: 'Remote',
        value: 42,
        modifiedAt: DateTime.now(),
        createdAt: DateTime.now(),
        version: 'v1',
      );

      final context = detector.detect(
        localItem: null,
        remoteItem: remote,
        userId: 'user1',
      );

      expect(context, isNull);
    });

    test('detects no conflict when only local exists', () {
      final local = TestEntity(
        id: 'entity1',
        userId: 'user1',
        name: 'Local',
        value: 42,
        modifiedAt: DateTime.now(),
        createdAt: DateTime.now(),
        version: 'v1',
      );

      final context = detector.detect(
        localItem: local,
        remoteItem: null,
        userId: 'user1',
      );

      expect(context, isNull);
    });

    test('detects user mismatch conflict', () {
      final local = TestEntity(
        id: 'entity1',
        userId: 'user1',
        name: 'Local',
        value: 42,
        modifiedAt: DateTime.now(),
        createdAt: DateTime.now(),
        version: 'v1',
      );

      final remote = TestEntity(
        id: 'entity1',
        userId: 'user2',
        name: 'Remote',
        value: 42,
        modifiedAt: DateTime.now(),
        createdAt: DateTime.now(),
        version: 'v1',
      );

      final context = detector.detect(
        localItem: local,
        remoteItem: remote,
        userId: 'user1',
      );

      expect(context, isNotNull);
      expect(context!.type, ConflictType.userMismatch);
      expect(context.entityId, 'entity1');
    });

    test('detects deletion conflict when one is deleted', () {
      final local = TestEntity(
        id: 'entity1',
        userId: 'user1',
        name: 'Local',
        value: 42,
        modifiedAt: DateTime.now(),
        createdAt: DateTime.now(),
        version: 'v1',
      );

      final remote = TestEntity(
        id: 'entity1',
        userId: 'user1',
        name: 'Remote',
        value: 42,
        modifiedAt: DateTime.now(),
        createdAt: DateTime.now(),
        version: 'v1',
        isDeleted: true,
      );

      final context = detector.detect(
        localItem: local,
        remoteItem: remote,
        userId: 'user1',
      );

      expect(context, isNotNull);
      expect(context!.type, ConflictType.deletionConflict);
    });

    test('detects both-modified conflict with different versions', () {
      final baseTime = DateTime.now();
      final local = TestEntity(
        id: 'entity1',
        userId: 'user1',
        name: 'Local',
        value: 42,
        modifiedAt: baseTime.add(const Duration(seconds: 10)),
        createdAt: baseTime,
        version: 'v2',
      );

      final remote = TestEntity(
        id: 'entity1',
        userId: 'user1',
        name: 'Remote',
        value: 100,
        modifiedAt: baseTime.add(const Duration(seconds: 20)),
        createdAt: baseTime,
        version: 'v3',
      );

      final context = detector.detect(
        localItem: local,
        remoteItem: remote,
        userId: 'user1',
      );

      expect(context, isNotNull);
      expect(context!.type, ConflictType.bothModified);
    });

    test('no conflict when same version despite time difference', () {
      final baseTime = DateTime.now();
      final local = TestEntity(
        id: 'entity1',
        userId: 'user1',
        name: 'Local',
        value: 42,
        modifiedAt: baseTime.add(const Duration(seconds: 10)),
        createdAt: baseTime,
        version: 'v2',
      );

      final remote = TestEntity(
        id: 'entity1',
        userId: 'user1',
        name: 'Remote',
        value: 42,
        modifiedAt: baseTime.add(const Duration(seconds: 20)),
        createdAt: baseTime,
        version: 'v2',
      );

      final context = detector.detect(
        localItem: local,
        remoteItem: remote,
        userId: 'user1',
      );

      expect(context, isNull);
    });

    test('includes metadata in conflict context', () {
      final baseTime = DateTime.now();
      final local = TestEntity(
        id: 'entity1',
        userId: 'user1',
        name: 'Local',
        value: 42,
        modifiedAt: baseTime.add(const Duration(seconds: 10)),
        createdAt: baseTime,
        version: 'v2',
      );

      final remote = TestEntity(
        id: 'entity1',
        userId: 'user1',
        name: 'Remote',
        value: 100,
        modifiedAt: baseTime.add(const Duration(seconds: 20)),
        createdAt: baseTime,
        version: 'v3',
      );

      final localMetadata = SyncMetadata(
        userId: 'user1',
        lastSyncTime: baseTime,
        dataHash: 'hash1',
        itemCount: 1,
      );

      final remoteMetadata = SyncMetadata(
        userId: 'user1',
        lastSyncTime: baseTime.add(const Duration(minutes: 1)),
        dataHash: 'hash2',
        itemCount: 1,
      );

      final context = detector.detect(
        localItem: local,
        remoteItem: remote,
        userId: 'user1',
        localMetadata: localMetadata,
        remoteMetadata: remoteMetadata,
      );

      expect(context, isNotNull);
      expect(context!.localMetadata, equals(localMetadata));
      expect(context.remoteMetadata, equals(remoteMetadata));
    });
  });
}
