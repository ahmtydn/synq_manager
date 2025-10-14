import 'package:flutter_test/flutter_test.dart';
import 'package:synq_manager/src/models/sync_metadata.dart';

void main() {
  group('SyncMetadata', () {
    final now = DateTime.now().toUtc();
    final metadata = SyncMetadata(
      userId: 'user-123',
      lastSyncTime: now, // Use UTC time for consistent testing
      entityName: 'tasks',
      dataHash: 'hash123',
      itemCount: 10,
      deviceId: 'device-abc',
      entityCounts: const {'tasks': 10, 'projects': 2},
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
        itemCount: 5,
      );
      final map = minimalMetadata.toMap();

      // Act
      final fromMap = SyncMetadata.fromJson(map);

      // Assert
      expect(fromMap.userId, 'user-456');
      expect(fromMap.itemCount, 5);
      expect(fromMap.entityName, isNull);
      expect(fromMap.dataHash, isNull);
      expect(fromMap.deviceId, isNull);
      expect(fromMap.entityCounts, isNull);
      expect(fromMap.customMetadata, isNull);
    });

    test('copyWith creates a correct copy with new values', () {
      // Arrange
      final newTime = now.add(const Duration(minutes: 5));

      // Act
      final copied = metadata.copyWith(
        entityName: 'notes',
        itemCount: 20,
        lastSyncTime: newTime,
        entityCounts: const {'notes': 20},
      );

      // Assert
      expect(copied.userId, metadata.userId);
      expect(copied.entityName, 'notes');
      expect(copied.itemCount, 20);
      expect(copied.lastSyncTime, newTime);
      expect(copied.entityCounts, const {'notes': 20});
      expect(copied.dataHash, metadata.dataHash); // Should remain unchanged
    });

    test('equality operator (==) works correctly', () {
      // Arrange
      final same = SyncMetadata(
        userId: 'user-123',
        lastSyncTime: now,
        entityName: 'tasks',
        dataHash: 'hash123',
        itemCount: 10,
        deviceId: 'device-abc',
        entityCounts: const {'tasks': 10, 'projects': 2},
        customMetadata: const {'isPremium': true},
      );
      final different = metadata.copyWith(itemCount: 11);

      // Assert
      expect(metadata == same, isTrue);
      expect(metadata == different, isFalse);
    });

    test('hashCode is consistent with equality', () {
      // Arrange
      final same = metadata.copyWith();
      final different = metadata.copyWith(itemCount: 11);

      // Assert
      expect(metadata.hashCode, same.hashCode);
      expect(metadata.hashCode, isNot(different.hashCode));
    });
  });
}
