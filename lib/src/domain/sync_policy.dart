/// Configuration for sync behavior
class SyncPolicy {
  const SyncPolicy({
    this.autoSyncInterval = const Duration(minutes: 15),
    this.pushOnEveryLocalChange = true,
    this.fetchOnStart = true,
    this.mergeGuestOnUpgrade = true,
    this.maxRetryAttempts = 3,
    this.retryBackoffMultiplier = 2.0,
    this.conflictResolutionTimeout = const Duration(minutes: 5),
    this.backgroundSyncEnabled = true,
  });

  /// How often to run automatic sync in the background
  final Duration autoSyncInterval;

  /// Whether to immediately sync when local changes are made
  final bool pushOnEveryLocalChange;

  /// Whether to fetch remote changes when the app starts
  final bool fetchOnStart;

  /// Whether to merge guest data when user logs in
  final bool mergeGuestOnUpgrade;

  /// Maximum number of retry attempts for failed sync operations
  final int maxRetryAttempts;

  /// Multiplier for exponential backoff between retries
  final double retryBackoffMultiplier;

  /// How long to wait for conflict resolution before timing out
  final Duration conflictResolutionTimeout;

  /// Whether background sync is enabled
  final bool backgroundSyncEnabled;

  /// Default conservative policy
  static const conservative = SyncPolicy(
    autoSyncInterval: Duration(hours: 1),
    pushOnEveryLocalChange: false,
    mergeGuestOnUpgrade: false,
  );

  /// Default aggressive policy for real-time apps
  static const realtime = SyncPolicy(
    autoSyncInterval: Duration(minutes: 5),
  );

  /// Copy with new values
  SyncPolicy copyWith({
    Duration? autoSyncInterval,
    bool? pushOnEveryLocalChange,
    bool? fetchOnStart,
    bool? mergeGuestOnUpgrade,
    int? maxRetryAttempts,
    double? retryBackoffMultiplier,
    Duration? conflictResolutionTimeout,
    bool? backgroundSyncEnabled,
  }) {
    return SyncPolicy(
      autoSyncInterval: autoSyncInterval ?? this.autoSyncInterval,
      pushOnEveryLocalChange:
          pushOnEveryLocalChange ?? this.pushOnEveryLocalChange,
      fetchOnStart: fetchOnStart ?? this.fetchOnStart,
      mergeGuestOnUpgrade: mergeGuestOnUpgrade ?? this.mergeGuestOnUpgrade,
      maxRetryAttempts: maxRetryAttempts ?? this.maxRetryAttempts,
      retryBackoffMultiplier:
          retryBackoffMultiplier ?? this.retryBackoffMultiplier,
      conflictResolutionTimeout:
          conflictResolutionTimeout ?? this.conflictResolutionTimeout,
      backgroundSyncEnabled:
          backgroundSyncEnabled ?? this.backgroundSyncEnabled,
    );
  }
}
