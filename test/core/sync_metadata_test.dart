import 'package:flutter_test/flutter_test.dart';
import 'package:synq_manager/src/models/sync_metadata.dart';

void main() {
  group('EntitySyncDetails', () {
    const details = EntitySyncDetails(count: 10, hash: 'hash123');

    test('toMap and fromJson work correctly', () {
      final map = details.toMap();
      final fromMap = EntitySyncDetails.fromJson(map);
      expect(fromMap, details);
    });

    test('equality works correctly', () {
      const same = EntitySyncDetails(count: 10, hash: 'hash123');
      const differentCount = EntitySyncDetails(count: 11, hash: 'hash123');
      const differentHash = EntitySyncDetails(count: 10, hash: 'hash456');
      expect(details, same);
      expect(details == differentCount, isFalse);
      expect(details == differentHash, isFalse);
    });
  });

  group('SyncMetadata', () {
    final now = DateTime.now().toUtc();
    final metadata = SyncMetadata(
      userId: 'user-123',
      lastSyncTime: now, // Use UTC time for consistent testing
      dataHash: 'hash123',
      deviceId: 'device-abc',
      entityCounts: const {
        'tasks': EntitySyncDetails(count: 10, hash: 'task_hash'),
        'projects': EntitySyncDetails(count: 2, hash: 'project_hash'),
      },
      customMetadata: const {'isPremium': true},
    );

    test('toMap and fromJson work correctly', () {
      // Arrange
      final map = metadata.toMap();

      // Act
      final fromMap = SyncMetadata.fromJson(map);

      // Assert
      expect(fromMap, metadata);
    });

    test('toMap and fromJson handle null values', () {
      // Arrange
      final minimalMetadata = SyncMetadata(
        userId: 'user-456',
        lastSyncTime: now, // Use UTC time for consistent testing
      );
      final map = minimalMetadata.toMap();

      // Act
      final fromMap = SyncMetadata.fromJson(map);

      // Assert
      expect(fromMap.userId, 'user-456');
      expect(fromMap.lastSyncTime.toIso8601String(), now.toIso8601String());
      expect(fromMap.dataHash, isNull);
      expect(fromMap.deviceId, isNull);
      expect(fromMap.entityCounts, isNull);
      expect(fromMap.customMetadata, isNull);
    });

    test('copyWith creates a correct copy with new values', () {
      // Arrange
      final newTime = now.add(const Duration(minutes: 5));
      const newEntityCounts = {'notes': EntitySyncDetails(count: 20)};

      // Act
      final copied = metadata.copyWith(
        lastSyncTime: newTime,
        entityCounts: newEntityCounts,
      );

      // Assert
      expect(copied.userId, metadata.userId);
      expect(copied.lastSyncTime, newTime);
      expect(copied.entityCounts, newEntityCounts);
      expect(copied.dataHash, metadata.dataHash); // Should remain unchanged
    });

    test('copyWith correctly updates a single entity in entityCounts', () {
      // Arrange
      final updatedCounts = Map<String, EntitySyncDetails>.from(
        metadata.entityCounts!,
      );
      updatedCounts['tasks'] =
          const EntitySyncDetails(count: 15, hash: 'new_task_hash');

      // Act
      final copied = metadata.copyWith(entityCounts: updatedCounts);

      // Assert
      expect(copied.entityCounts, isNotNull);
      expect(copied.entityCounts!.length, 2);
      // Check that 'tasks' was updated
      expect(
        copied.entityCounts!['tasks'],
        const EntitySyncDetails(count: 15, hash: 'new_task_hash'),
      );
      // Check that 'projects' remains unchanged
      expect(
          copied.entityCounts!['projects'], metadata.entityCounts!['projects'],);
    });

    test('equality operator (==) works correctly', () {
      // Arrange
      final same = SyncMetadata(
        userId: 'user-123',
        lastSyncTime: now,
        dataHash: 'hash123',
        deviceId: 'device-abc',
        entityCounts: const {
          'tasks': EntitySyncDetails(count: 10, hash: 'task_hash'),
          'projects': EntitySyncDetails(count: 2, hash: 'project_hash'),
        },
        customMetadata: const {'isPremium': true},
      );
      final different = metadata.copyWith(dataHash: 'different-hash');

      // Assert
      expect(metadata == same, isTrue);
      expect(metadata == different, isFalse);
    });

    test('equality is false if entityCounts have different details', () {
      // Arrange
      final differentCounts = metadata.copyWith(
        entityCounts: {
          'tasks': const EntitySyncDetails(count: 10, hash: 'task_hash'),
          'projects':
              const EntitySyncDetails(count: 3, hash: 'different_project_hash'),
        },
      );

      // Assert
      expect(metadata == differentCounts, isFalse);
    });

    test('hashCode is consistent with equality', () {
      // Arrange
      final same = metadata.copyWith();
      final different = metadata.copyWith(dataHash: 'different-hash');

      // Assert
      expect(metadata.hashCode, same.hashCode);
      expect(metadata.hashCode, isNot(different.hashCode));
    });
  });
}
