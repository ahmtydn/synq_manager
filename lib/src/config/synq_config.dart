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
    this.autoStartSync = false,
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 5),
    this.batchSize = 50,
    this.defaultUserSwitchStrategy = UserSwitchStrategy.promptIfUnsyncedData,
    this.syncTimeout = const Duration(minutes: 2),
    this.enableLogging = false,
    this.initialUserId,
  });

  /// Creates default configuration.
  factory SynqConfig.defaultConfig() => const SynqConfig();

  /// Interval between automatic sync operations.
  final Duration autoSyncInterval;

  /// Whether to automatically start auto-sync for all users on initialization.
  /// When true, auto-sync will start automatically for all users that have
  /// data in local storage after the manager is initialized.
  final bool autoStartSync;

  /// Maximum number of retry attempts for failed operations.
  final int maxRetries;

  /// Delay between retry attempts.
  final Duration retryDelay;

  /// Number of operations to sync in a single batch.
  final int batchSize;

  /// Default strategy for user switching.
  final UserSwitchStrategy defaultUserSwitchStrategy;

  /// Timeout for sync operations.
  final Duration syncTimeout;

  /// Whether to enable logging.
  final bool enableLogging;

  /// Optional initial user ID to set upon initialization.
  final String? initialUserId;

  /// Creates a copy with modified fields.
  SynqConfig copyWith({
    Duration? autoSyncInterval,
    bool? autoStartSync,
    int? maxRetries,
    Duration? retryDelay,
    int? batchSize,
    UserSwitchStrategy? defaultUserSwitchStrategy,
    Duration? syncTimeout,
    bool? enableLogging,
    String? initialUserId,
  }) {
    return SynqConfig(
      autoSyncInterval: autoSyncInterval ?? this.autoSyncInterval,
      autoStartSync: autoStartSync ?? this.autoStartSync,
      maxRetries: maxRetries ?? this.maxRetries,
      retryDelay: retryDelay ?? this.retryDelay,
      batchSize: batchSize ?? this.batchSize,
      defaultUserSwitchStrategy:
          defaultUserSwitchStrategy ?? this.defaultUserSwitchStrategy,
      syncTimeout: syncTimeout ?? this.syncTimeout,
      enableLogging: enableLogging ?? this.enableLogging,
      initialUserId: initialUserId ?? this.initialUserId,
    );
  }
}
