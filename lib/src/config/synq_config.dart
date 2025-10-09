import 'package:synq_manager/src/resolvers/sync_conflict_resolver.dart';

/// Strategies available when switching between users.
enum UserSwitchStrategy {
  clearAndFetch,
  syncThenSwitch,
  promptIfUnsyncedData,
  keepLocal,
}

class SynqConfig {
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

  factory SynqConfig.defaultConfig() => const SynqConfig();
  final Duration autoSyncInterval;
  final bool autoSyncOnConnect;
  final int maxRetries;
  final Duration retryDelay;
  final int batchSize;
  final SyncConflictResolver<dynamic>? defaultConflictResolver;
  final UserSwitchStrategy defaultUserSwitchStrategy;
  final bool enableRealTimeSync;
  final Duration syncTimeout;
  final bool enableLogging;

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
