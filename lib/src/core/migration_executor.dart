import 'package:synq_manager/src/adapters/local_adapter.dart';
import 'package:synq_manager/src/core/synq_observer.dart';
import 'package:synq_manager/src/migration/migration.dart';
import 'package:synq_manager/src/models/exceptions.dart';
import 'package:synq_manager/src/models/syncable_entity.dart';
import 'package:synq_manager/src/utils/logger.dart';

/// Executes schema migrations on the local database.
class MigrationExecutor<T extends SyncableEntity> {
  /// Creates a [MigrationExecutor].
  MigrationExecutor({
    required this.localAdapter,
    required this.migrations,
    required this.targetVersion,
    required this.logger,
    required this.observers,
  });

  /// The local adapter to perform migrations on.
  final LocalAdapter<T> localAdapter;

  /// The list of all available migrations.
  final List<Migration> migrations;

  /// The target schema version from the config.
  final int targetVersion;

  /// The logger instance.
  final SynqLogger logger;

  /// List of observers to notify of migration events.
  final List<SynqObserver<T>> observers;

  /// Checks if a migration is needed.
  Future<bool> needsMigration() async {
    final storedVersion = await localAdapter.getStoredSchemaVersion();
    return storedVersion < targetVersion;
  }

  /// Executes the migration process.
  Future<void> execute() async {
    var currentVersion = await localAdapter.getStoredSchemaVersion();
    logger.info(
      'Starting schema migration from version $currentVersion '
      'to $targetVersion...',
    );
    notifyObservers((o) => o.onMigrationStart(currentVersion, targetVersion));

    // If this is a fresh install (version 0), just set the version and return.
    // No data exists to be migrated.
    if (currentVersion == 0) {
      await localAdapter.setStoredSchemaVersion(targetVersion);
      logger
          .info('Initialized fresh database to schema version $targetVersion.');
      notifyObservers((o) => o.onMigrationEnd(targetVersion));
      return;
    }

    while (currentVersion < targetVersion) {
      final migration = _findNextMigration(currentVersion);

      logger.info(
        'Applying migration from v${migration.fromVersion} '
        'to v${migration.toVersion}...',
      );

      await localAdapter.transaction(() async {
        final allRawData = await localAdapter.getAllRawData();
        final migratedData =
            allRawData.map(migration.migrate).toList(growable: false);

        await localAdapter.overwriteAllRawData(migratedData);
        await localAdapter.setStoredSchemaVersion(migration.toVersion);
      });

      currentVersion = migration.toVersion;
      logger.info(
        'Successfully migrated to schema version $currentVersion.',
      );
    }

    logger.info('Schema migration completed successfully.');
    notifyObservers((o) => o.onMigrationEnd(targetVersion));
  }

  Migration _findNextMigration(int fromVersion) {
    // Find a migration that starts from the current version.
    // Use orElse to handle the case where no migration is found,
    // avoiding catching a StateError.
    final migration = migrations.firstWhere(
      (m) => m.fromVersion == fromVersion,
      orElse: () => throw MigrationException(
        'Migration path not found. '
        'Cannot migrate from schema version $fromVersion to $targetVersion. '
        'Missing a migration that starts at version $fromVersion.',
      ),
    );

    // Ensure the migration moves forward.
    if (migration.toVersion <= fromVersion) {
      throw MigrationException(
        'Invalid migration found: toVersion (${migration.toVersion}) must be '
        'greater than fromVersion ($fromVersion).',
      );
    }
    return migration;
  }

  /// Notifies all registered observers of an event.
  void notifyObservers(void Function(SynqObserver<T> observer) action) {
    for (final observer in observers) {
      try {
        action(observer);
      } on Object catch (e, stack) {
        logger.error('Observer ${observer.runtimeType} threw an error', stack);
      }
    }
  }
}
