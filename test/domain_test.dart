import 'package:flutter_test/flutter_test.dart';
import 'package:synq_manager/synq_manager.dart';

void main() {
  group('SyncEntity', () {
    test('should mark entity as dirty', () {
      final entity = TestSyncEntity(
        id: '1',
        updatedAt: DateTime.now(),
        version: 1,
        isDeleted: false,
        isDirty: false,
        name: 'Test',
      );

      final dirtyEntity = entity.markAsDirty() as TestSyncEntity;

      expect(dirtyEntity.isDirty, isTrue);
      expect(dirtyEntity.updatedAt.isAfter(entity.updatedAt), isTrue);
    });

    test('should mark entity as deleted', () {
      final entity = TestSyncEntity(
        id: '1',
        updatedAt: DateTime.now(),
        version: 1,
        isDeleted: false,
        isDirty: false,
        name: 'Test',
      );

      final deletedEntity = entity.markAsDeleted() as TestSyncEntity;

      expect(deletedEntity.isDeleted, isTrue);
      expect(deletedEntity.isDirty, isTrue);
      expect(deletedEntity.updatedAt.isAfter(entity.updatedAt), isTrue);
    });

    test('should mark entity as synced', () {
      final entity = TestSyncEntity(
        id: '1',
        updatedAt: DateTime.now(),
        version: 1,
        isDeleted: false,
        isDirty: true,
        name: 'Test',
      );

      final syncedEntity = entity.markAsSynced(newVersion: 2) as TestSyncEntity;

      expect(syncedEntity.isDirty, isFalse);
      expect(syncedEntity.version, equals(2));
    });
  });

  group('SyncResult', () {
    test('should create success result', () {
      final entity = TestSyncEntity(
        id: '1',
        updatedAt: DateTime.now(),
        version: 1,
        isDeleted: false,
        isDirty: false,
        name: 'Test',
      );

      final result = SyncResult.success(entity);

      expect(result.isSuccess, isTrue);
      expect(result.hasConflict, isFalse);
      expect(result.hasError, isFalse);
      expect(result.entity, equals(entity));
    });

    test('should create conflict result', () {
      final local = TestSyncEntity(
        id: '1',
        updatedAt: DateTime.now(),
        version: 1,
        isDeleted: false,
        isDirty: false,
        name: 'Local',
      );

      final remote = TestSyncEntity(
        id: '1',
        updatedAt: DateTime.now(),
        version: 2,
        isDeleted: false,
        isDirty: false,
        name: 'Remote',
      );

      final result = SyncResult.conflict(local, remote);

      expect(result.isSuccess, isFalse);
      expect(result.hasConflict, isTrue);
      expect(result.hasError, isFalse);
      expect(result.entity, equals(local));
      expect(result.conflictedEntity, equals(remote));
    });

    test('should create error result', () {
      const errorMessage = 'Network error';
      final result = SyncResult<TestSyncEntity>.error(errorMessage);

      expect(result.isSuccess, isFalse);
      expect(result.hasConflict, isFalse);
      expect(result.hasError, isTrue);
      expect(result.error, equals(errorMessage));
    });
  });

  group('SyncPolicy', () {
    test('should create default policy', () {
      const policy = SyncPolicy();

      expect(policy.autoSyncInterval, equals(const Duration(minutes: 15)));
      expect(policy.pushOnEveryLocalChange, isTrue);
      expect(policy.fetchOnStart, isTrue);
      expect(policy.mergeGuestOnUpgrade, isTrue);
      expect(policy.maxRetryAttempts, equals(3));
      expect(policy.backgroundSyncEnabled, isTrue);
    });

    test('should create conservative policy', () {
      const policy = SyncPolicy.conservative;

      expect(policy.autoSyncInterval, equals(const Duration(hours: 1)));
      expect(policy.pushOnEveryLocalChange, isFalse);
      expect(policy.fetchOnStart, isTrue);
      expect(policy.mergeGuestOnUpgrade, isFalse);
    });

    test('should create realtime policy', () {
      const policy = SyncPolicy.realtime;

      expect(policy.autoSyncInterval, equals(const Duration(minutes: 5)));
      expect(policy.pushOnEveryLocalChange, isTrue);
      expect(policy.fetchOnStart, isTrue);
      expect(policy.mergeGuestOnUpgrade, isTrue);
    });
  });
}

/// Test implementation of SyncEntity
class TestSyncEntity extends SyncEntity {
  TestSyncEntity({
    required this.id,
    required this.updatedAt,
    required this.version,
    required this.isDeleted,
    required this.isDirty,
    required this.name,
  });

  @override
  final String id;

  @override
  final DateTime updatedAt;

  @override
  final int version;

  @override
  final bool isDeleted;

  @override
  final bool isDirty;

  final String name;

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'updatedAt': updatedAt.toIso8601String(),
      'version': version,
      'isDeleted': isDeleted,
      'isDirty': isDirty,
      'name': name,
    };
  }

  @override
  SyncEntity copyWithSyncData({
    DateTime? updatedAt,
    int? version,
    bool? isDeleted,
    bool? isDirty,
    String? guestId,
  }) {
    return TestSyncEntity(
      id: id,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
      isDeleted: isDeleted ?? this.isDeleted,
      isDirty: isDirty ?? this.isDirty,
      name: name,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TestSyncEntity &&
        other.id == id &&
        other.name == name &&
        other.version == version;
  }

  @override
  int get hashCode => Object.hash(id, name, version);
}
