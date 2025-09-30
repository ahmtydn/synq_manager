import 'package:meta/meta.dart';
import 'package:synq_manager/synq_manager.dart';

/// Configuration for synchronization operations
@immutable
class SyncConfig {
  /// Creates a new sync configuration
  const SyncConfig({
    this.syncInterval = const Duration(minutes: 5),
    this.retryAttempts = 3,
    this.retryDelay = const Duration(seconds: 2),
    this.batchSize = 50,
    this.encryptionKey,
    this.priority = SyncPriority.normal,
    this.enableBackgroundSync = true,
    this.enableAutoRetry = true,
    this.enableConflictResolution = true,
    this.maxStorageSize = 100,
    this.compressionEnabled = true,
    this.customHeaders = const {},
  });

  /// Creates a high-priority configuration
  factory SyncConfig.highPriority({
    String? encryptionKey,
    Map<String, String> customHeaders = const {},
  }) {
    return SyncConfig(
      syncInterval: const Duration(minutes: 1),
      retryAttempts: 5,
      retryDelay: const Duration(seconds: 1),
      priority: SyncPriority.high,
      encryptionKey: encryptionKey,
      customHeaders: customHeaders,
    );
  }

  /// Creates a low-priority configuration
  factory SyncConfig.lowPriority({
    String? encryptionKey,
    Map<String, String> customHeaders = const {},
  }) {
    return SyncConfig(
      syncInterval: const Duration(hours: 1),
      retryAttempts: 2,
      retryDelay: const Duration(seconds: 5),
      priority: SyncPriority.low,
      encryptionKey: encryptionKey,
      customHeaders: customHeaders,
    );
  }

  /// Creates a configuration optimized for mobile devices
  factory SyncConfig.mobile({
    String? encryptionKey,
    Map<String, String> customHeaders = const {},
  }) {
    return SyncConfig(
      syncInterval: const Duration(minutes: 15),
      retryDelay: const Duration(seconds: 3),
      batchSize: 25,
      maxStorageSize: 50,
      encryptionKey: encryptionKey,
      customHeaders: customHeaders,
    );
  }

  /// Creates instance from JSON
  factory SyncConfig.fromJson(Map<String, dynamic> json) {
    return SyncConfig(
      syncInterval:
          Duration(milliseconds: json['syncInterval'] as int? ?? 300000),
      retryAttempts: json['retryAttempts'] as int? ?? 3,
      retryDelay: Duration(milliseconds: json['retryDelay'] as int? ?? 2000),
      batchSize: json['batchSize'] as int? ?? 50,
      encryptionKey: json['encryptionKey'] as String?,
      priority: SyncPriority.values.firstWhere(
        (e) => e.name == json['priority'],
        orElse: () => SyncPriority.normal,
      ),
      enableBackgroundSync: json['enableBackgroundSync'] as bool? ?? true,
      enableAutoRetry: json['enableAutoRetry'] as bool? ?? true,
      enableConflictResolution:
          json['enableConflictResolution'] as bool? ?? true,
      maxStorageSize: json['maxStorageSize'] as int? ?? 100,
      compressionEnabled: json['compressionEnabled'] as bool? ?? true,
      customHeaders:
          Map<String, String>.from(json['customHeaders'] as Map? ?? {}),
    );
  }

  /// Interval between automatic synchronization attempts
  final Duration syncInterval;

  /// Number of retry attempts for failed operations
  final int retryAttempts;

  /// Delay between retry attempts
  final Duration retryDelay;

  /// Maximum number of items to sync in a single batch
  final int batchSize;

  /// Encryption key for secure storage
  final String? encryptionKey;

  /// Priority level for sync operations
  final SyncPriority priority;

  /// Whether to enable background synchronization
  final bool enableBackgroundSync;

  /// Whether to automatically retry failed operations
  final bool enableAutoRetry;

  /// Whether to enable automatic conflict resolution
  final bool enableConflictResolution;

  /// Maximum storage size in MB
  final int maxStorageSize;

  /// Whether to enable data compression
  final bool compressionEnabled;

  /// Custom headers to include with sync requests
  final Map<String, String> customHeaders;

  /// Creates a copy with updated values
  SyncConfig copyWith({
    Duration? syncInterval,
    int? retryAttempts,
    Duration? retryDelay,
    int? batchSize,
    String? encryptionKey,
    SyncPriority? priority,
    bool? enableBackgroundSync,
    bool? enableAutoRetry,
    bool? enableConflictResolution,
    int? maxStorageSize,
    bool? compressionEnabled,
    Map<String, String>? customHeaders,
  }) {
    return SyncConfig(
      syncInterval: syncInterval ?? this.syncInterval,
      retryAttempts: retryAttempts ?? this.retryAttempts,
      retryDelay: retryDelay ?? this.retryDelay,
      batchSize: batchSize ?? this.batchSize,
      encryptionKey: encryptionKey ?? this.encryptionKey,
      priority: priority ?? this.priority,
      enableBackgroundSync: enableBackgroundSync ?? this.enableBackgroundSync,
      enableAutoRetry: enableAutoRetry ?? this.enableAutoRetry,
      enableConflictResolution:
          enableConflictResolution ?? this.enableConflictResolution,
      maxStorageSize: maxStorageSize ?? this.maxStorageSize,
      compressionEnabled: compressionEnabled ?? this.compressionEnabled,
      customHeaders: customHeaders ?? this.customHeaders,
    );
  }

  /// Converts to JSON for serialization
  Map<String, dynamic> toJson() {
    return {
      'syncInterval': syncInterval.inMilliseconds,
      'retryAttempts': retryAttempts,
      'retryDelay': retryDelay.inMilliseconds,
      'batchSize': batchSize,
      'encryptionKey': encryptionKey,
      'priority': priority.name,
      'enableBackgroundSync': enableBackgroundSync,
      'enableAutoRetry': enableAutoRetry,
      'enableConflictResolution': enableConflictResolution,
      'maxStorageSize': maxStorageSize,
      'compressionEnabled': compressionEnabled,
      'customHeaders': customHeaders,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncConfig &&
          runtimeType == other.runtimeType &&
          syncInterval == other.syncInterval &&
          retryAttempts == other.retryAttempts &&
          retryDelay == other.retryDelay &&
          batchSize == other.batchSize &&
          encryptionKey == other.encryptionKey &&
          priority == other.priority &&
          enableBackgroundSync == other.enableBackgroundSync &&
          enableAutoRetry == other.enableAutoRetry &&
          enableConflictResolution == other.enableConflictResolution &&
          maxStorageSize == other.maxStorageSize &&
          compressionEnabled == other.compressionEnabled;

  @override
  int get hashCode =>
      syncInterval.hashCode ^
      retryAttempts.hashCode ^
      retryDelay.hashCode ^
      batchSize.hashCode ^
      encryptionKey.hashCode ^
      priority.hashCode ^
      enableBackgroundSync.hashCode ^
      enableAutoRetry.hashCode ^
      enableConflictResolution.hashCode ^
      maxStorageSize.hashCode ^
      compressionEnabled.hashCode;

  @override
  String toString() {
    return 'SyncConfig(syncInterval: $syncInterval, retryAttempts: $retryAttempts, '
        'priority: $priority, enableBackgroundSync: $enableBackgroundSync)';
  }
}
