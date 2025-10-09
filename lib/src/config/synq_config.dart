import 'package:synq_manager/src/resolvers/sync_conflict_resolver.dart';

/// Strategies available when switching between users.
enum UserSwitchStrategy {
  /// Clear local data and fetch fresh from remote.
  clearAndFetch,

  /// Sync current user's data before switching.
  syncThenSwitch,

  /// Prompt the user if there's unsynced data.
  promptIfUnsyncedData,

  /// Keep local data as-is.
  keepLocal,
}

/// Configuration for SynqManager behavior.
class SynqConfig {
  /// Creates a sync configuration.
  const SynqConfig({
    this.autoSyncInterval = const Duration(minutes: 5),
    this.autoSyncOnConnect = true,
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 5),
    this.batchSize = 50,
    this.defaultConflictResolver,
    this.defaultUserSwitchStrategy = UserSwitchStrategy.promptIfUnsyncedData,
    this.enableRealTimeSync = false,
    this.syncTimeout = const Duration(minutes: 2),
    this.enableLogging = false,
  });

  /// Creates default configuration.
  factory SynqConfig.defaultConfig() => const SynqConfig();

  /// Interval between automatic sync operations.
  final Duration autoSyncInterval;

  /// Whether to automatically sync when connectivity is restored.
  final bool autoSyncOnConnect;

  /// Maximum number of retry attempts for failed operations.
  final int maxRetries;

  /// Delay between retry attempts.
  final Duration retryDelay;

  /// Number of operations to sync in a single batch.
  final int batchSize;

  /// Default conflict resolution strategy.
  final SyncConflictResolver<dynamic>? defaultConflictResolver;

  /// Default strategy for user switching.
  final UserSwitchStrategy defaultUserSwitchStrategy;

  /// Whether to enable real-time synchronization.
  final bool enableRealTimeSync;

  /// Timeout for sync operations.
  final Duration syncTimeout;

  /// Whether to enable logging.
  final bool enableLogging;

  /// Creates a copy with modified fields.
  SynqConfig copyWith({
    Duration? autoSyncInterval,
    bool? autoSyncOnConnect,
    int? maxRetries,
    Duration? retryDelay,
    int? batchSize,
    SyncConflictResolver<dynamic>? defaultConflictResolver,
    UserSwitchStrategy? defaultUserSwitchStrategy,
    bool? enableRealTimeSync,
    Duration? syncTimeout,
    bool? enableLogging,
  }) {
    return SynqConfig(
      autoSyncInterval: autoSyncInterval ?? this.autoSyncInterval,
      autoSyncOnConnect: autoSyncOnConnect ?? this.autoSyncOnConnect,
      maxRetries: maxRetries ?? this.maxRetries,
      retryDelay: retryDelay ?? this.retryDelay,
      batchSize: batchSize ?? this.batchSize,
      defaultConflictResolver:
          defaultConflictResolver ?? this.defaultConflictResolver,
      defaultUserSwitchStrategy:
          defaultUserSwitchStrategy ?? this.defaultUserSwitchStrategy,
      enableRealTimeSync: enableRealTimeSync ?? this.enableRealTimeSync,
      syncTimeout: syncTimeout ?? this.syncTimeout,
      enableLogging: enableLogging ?? this.enableLogging,
    );
  }
}
