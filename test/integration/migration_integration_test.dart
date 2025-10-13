import 'package:flutter_test/flutter_test.dart';

import 'package:synq_manager/synq_manager.dart';

import '../mocks/mock_adapters.dart';
import '../mocks/test_entity.dart';

// --- Test Migrations ---

/// Renames 'name' to 'title' and adds a 'priority' field.
class V1toV2 extends Migration {
  @override
  int get fromVersion => 1;
  @override
  int get toVersion => 2;

  @override
  Map<String, dynamic> migrate(Map<String, dynamic> oldData) {
    final newData = Map<String, dynamic>.from(oldData);
    newData['title'] = newData.remove('name'); // Rename field
    newData['priority'] = 'medium'; // Add new field with default value
    return newData;
  }
}

/// Changes 'priority' from a string to an integer.
class V2toV3 extends Migration {
  @override
  int get fromVersion => 2;
  @override
  int get toVersion => 3;

  @override
  Map<String, dynamic> migrate(Map<String, dynamic> oldData) {
    final newData = Map<String, dynamic>.from(oldData);
    switch (newData['priority']) {
      case 'high':
        newData['priority'] = 1;
      case 'medium':
        newData['priority'] = 2;
      default:
        newData['priority'] = 3;
    }
    return newData;
  }
}

void main() {
  group('Schema Migration Integration Tests', () {
    late MockLocalAdapter<TestEntity> localAdapter;
    late MockRemoteAdapter<TestEntity> remoteAdapter;

    setUp(() {
      // The fromJson for TestEntity won't work for migrated data,
      // so we use a mock that can handle dynamic maps.
      localAdapter = MockLocalAdapter<TestEntity>(
        fromJson: TestEntity.fromJson,
      );
      remoteAdapter = MockRemoteAdapter<TestEntity>();
    });

    Future<SynqManager<TestEntity>> createManager({
      required int schemaVersion,
      required List<Migration> migrations,
    }) async {
      final manager = SynqManager<TestEntity>(
        localAdapter: localAdapter,
        remoteAdapter: remoteAdapter,
        synqConfig: SynqConfig(
          schemaVersion: schemaVersion,
          migrations: migrations,
        ),
      );
      // Initialization triggers the migration
      await manager.initialize();
      return manager;
    }

    test('runs a single migration successfully (v1 -> v2)', () async {
      // 1. Setup: Pre-populate with V1 data and set stored version to 1.
      final v1Data = {
        'id': 'entity1',
        'userId': 'user1',
        'name': 'V1 Name', // Field to be renamed
        'value': 10,
        'modifiedAt': DateTime.now().toIso8601String(),
        'createdAt': DateTime.now().toIso8601String(),
        'version': 1,
      };
      await localAdapter.overwriteAllRawData([v1Data]);
      await localAdapter.setStoredSchemaVersion(1);

      // 2. Act: Initialize manager with target version 2 and the V1->V2 migration.
      await createManager(schemaVersion: 2, migrations: [V1toV2()]);

      // 3. Assert: Check that data is now in V2 format.
      final migratedData = await localAdapter.getAllRawData();
      expect(migratedData, hasLength(1));
      expect(migratedData.first['name'], isNull); // 'name' field is gone
      expect(migratedData.first['title'], 'V1 Name'); // 'title' field exists
      expect(migratedData.first['priority'], 'medium'); // 'priority' was added

      // Verify schema version was updated in the adapter.
      final storedVersion = await localAdapter.getStoredSchemaVersion();
      expect(storedVersion, 2);
    });

    test('runs a multi-step migration successfully (v1 -> v3)', () async {
      // 1. Setup: Pre-populate with V1 data and set stored version to 1.
      final v1Data = {
        'id': 'entity1',
        'userId': 'user1',
        'name': 'V1 Name',
        'value': 10,
        'modifiedAt': DateTime.now().toIso8601String(),
        'createdAt': DateTime.now().toIso8601String(),
        'version': 1,
      };
      await localAdapter.overwriteAllRawData([v1Data]);
      await localAdapter.setStoredSchemaVersion(1);

      // 2. Act: Initialize with target version 3 and both migrations.
      await createManager(
        schemaVersion: 3,
        migrations: [V1toV2(), V2toV3()],
      );

      // 3. Assert: Check that data is now in V3 format.
      final migratedData = await localAdapter.getAllRawData();
      expect(migratedData, hasLength(1));
      expect(migratedData.first['name'], isNull);
      expect(migratedData.first['title'], 'V1 Name');
      expect(migratedData.first['priority'], 2); // 'medium' became 2

      final storedVersion = await localAdapter.getStoredSchemaVersion();
      expect(storedVersion, 3);
    });

    test('throws MigrationException if migration path is not found', () async {
      // 1. Setup: Stored version is 1.
      await localAdapter.setStoredSchemaVersion(1);

      // 2. Act & Assert: Try to migrate to version 3 with only a V2->V3 migration.
      // The manager will look for a migration starting from version 1 and fail.
      expect(
        () => createManager(schemaVersion: 3, migrations: [V2toV3()]),
        throwsA(
          isA<MigrationException>().having(
            (e) => e.message,
            'message',
            contains('Migration path not found'),
          ),
        ),
      );
    });

    test('does not run migration if schema version is already current',
        () async {
      // 1. Setup: Pre-populate with V1 data and set stored version to 2.
      final v1Data = {'id': 'entity1', 'name': 'V1 Name'};
      await localAdapter.overwriteAllRawData([v1Data]);
      await localAdapter.setStoredSchemaVersion(2);

      // 2. Act: Initialize with target version 2.
      await createManager(schemaVersion: 2, migrations: [V1toV2()]);

      // 3. Assert: Check that data was NOT migrated.
      final rawData = await localAdapter.getAllRawData();
      expect(rawData.first['name'], 'V1 Name'); // Still has 'name'
      expect(rawData.first['title'], isNull); // Does not have 'title'

      final storedVersion = await localAdapter.getStoredSchemaVersion();
      expect(storedVersion, 2);
    });

    test('onMigrationError callback is invoked on migration failure', () async {
      // 1. Arrange: Setup a scenario for failure (missing migration path from v1).
      await localAdapter.setStoredSchemaVersion(1);

      var callbackWasCalled = false;
      Object? capturedError;

      Future<void> errorHandler(Object error, StackTrace stack) async {
        callbackWasCalled = true;
        capturedError = error;
      }

      // 2. Act: Create a manager with the error handler and initialize it.
      // This should NOT throw an exception because the handler catches it.
      final manager = SynqManager<TestEntity>(
        localAdapter: localAdapter,
        remoteAdapter: remoteAdapter,
        synqConfig: SynqConfig(
          schemaVersion: 3, // Target version that cannot be reached
          migrations: [V2toV3()], // Missing V1->V2 migration
          onMigrationError: errorHandler,
        ),
      );
      await manager.initialize();

      // 3. Assert: Verify the callback was called with the correct error.
      expect(
        callbackWasCalled,
        isTrue,
        reason: 'onMigrationError should have been called.',
      );
      expect(capturedError, isA<MigrationException>());
      // Use a `having` matcher for a combined type and property check.
      expect(
        capturedError,
        isA<MigrationException>().having(
          (e) => e.message,
          'message',
          contains('Migration path not found'),
        ),
      );
    });
  });
}
