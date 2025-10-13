import 'package:synq_manager/src/migration/migration.dart';
import 'package:synq_manager/src/models/user_switch_strategy.dart';
import 'package:synq_manager/synq_manager.dart';

/// A handler for migration errors.
typedef MigrationErrorHandler = Future<void> Function(
    Object error, StackTrace stackTrace,);

/// Configuration for [SynqManager].
class SynqConfig<T extends SyncableEntity> {
  /// Creates a configuration object for [SynqManager].
  const SynqConfig({
    this.autoSyncInterval = const Duration(minutes: 15),
    this.autoStartSync = false,
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 30),
    this.batchSize = 50,
    this.defaultConflictResolver,
    this.defaultUserSwitchStrategy = UserSwitchStrategy.syncThenSwitch,
    this.syncTimeout = const Duration(minutes: 2),
    this.enableLogging = false,
    this.initialUserId,
    this.defaultSyncDirection = SyncDirection.pushThenPull,
    this.schemaVersion = 1,
    this.migrations = const [],
    this.onMigrationError,
  });

  /// A default configuration with sensible production values.
  factory SynqConfig.defaultConfig() => const SynqConfig();

  /// The interval for automatic background synchronization.
  final Duration autoSyncInterval;

  /// Whether to automatically start auto-sync for all users with local data
  /// upon initialization.
  final bool autoStartSync;

  /// The maximum number of times a failed sync operation will be retried.
  final int maxRetries;

  /// The base delay before retrying a failed operation.
  /// The actual delay may increase with exponential backoff.
  final Duration retryDelay;

  /// The number of operations to process in a single batch during sync.
  final int batchSize;

  /// The default conflict resolver to use if none is provided per-operation.
  /// If null, [LastWriteWinsResolver] is used.
  final SyncConflictResolver<T>? defaultConflictResolver;

  /// The default strategy to use when switching users.
  final UserSwitchStrategy defaultUserSwitchStrategy;

  /// The maximum duration for a single sync cycle before it times out.
  final Duration syncTimeout;

  /// Whether to enable detailed logging.
  final bool enableLogging;

  /// The user ID to target for the initial auto-sync if [autoStartSync] is
  /// true. If null, SynqManager will discover all users with local data.
  final String? initialUserId;

  /// The default direction for synchronization.
  final SyncDirection defaultSyncDirection;

  /// The current version of the data schema.
  ///
  /// When the app is initialized, this version is compared against the version
  /// stored in the local database. If the config version is higher, the
  /// provided [migrations] will be run.
  final int schemaVersion;

  /// A list of [Migration] classes to be run when the [schemaVersion] is
  /// incremented.
  ///
  /// The manager will automatically find the correct migration path from the
  /// stored version to the target [schemaVersion].
  final List<Migration> migrations;

  /// A callback to handle failures during schema migration.
  ///
  /// If a migration fails, this handler is invoked. If null, the error is
  /// rethrown, which will likely crash the application, preventing it from
  /// running with a corrupted database. You can provide a handler to
  /// implement a custom recovery strategy, like clearing all local data.
  final MigrationErrorHandler? onMigrationError;

  /// Creates a copy of this config but with the given fields replaced with
  /// the new values.
  SynqConfig<T> copyWith({
    Duration? autoSyncInterval,
    bool? autoStartSync,
    int? maxRetries,
    Duration? retryDelay,
    int? batchSize,
    SyncConflictResolver<T>? defaultConflictResolver,
    UserSwitchStrategy? defaultUserSwitchStrategy,
    Duration? syncTimeout,
    bool? enableLogging,
    String? initialUserId,
    SyncDirection? defaultSyncDirection,
    int? schemaVersion,
    List<Migration>? migrations,
    MigrationErrorHandler? onMigrationError,
  }) {
    return SynqConfig<T>(
      autoSyncInterval: autoSyncInterval ?? this.autoSyncInterval,
      autoStartSync: autoStartSync ?? this.autoStartSync,
      maxRetries: maxRetries ?? this.maxRetries,
      retryDelay: retryDelay ?? this.retryDelay,
      batchSize: batchSize ?? this.batchSize,
      defaultConflictResolver:
          defaultConflictResolver ?? this.defaultConflictResolver,
      defaultUserSwitchStrategy:
          defaultUserSwitchStrategy ?? this.defaultUserSwitchStrategy,
      syncTimeout: syncTimeout ?? this.syncTimeout,
      enableLogging: enableLogging ?? this.enableLogging,
      initialUserId: initialUserId ?? this.initialUserId,
      defaultSyncDirection: defaultSyncDirection ?? this.defaultSyncDirection,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      migrations: migrations ?? this.migrations,
      onMigrationError: onMigrationError ?? this.onMigrationError,
    );
  }
}
