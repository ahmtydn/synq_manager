import 'package:synq_manager/src/models/sync_operation.dart';
import 'package:synq_manager/src/models/syncable_entity.dart';

/// Health check result for the sync system.
class HealthCheck {
  /// Creates a health check result.
  const HealthCheck({
    required this.isLocalStorageHealthy,
    required this.isRemoteConnected,
    required this.hasPendingOperations,
    required this.pendingOperationCount,
    required this.hasFailedOperations,
    required this.failedOperationCount,
    this.lastSuccessfulSync,
    this.warnings = const [],
    this.errors = const [],
  });

  /// Whether local storage is functioning properly.
  final bool isLocalStorageHealthy;

  /// Whether remote connection is available.
  final bool isRemoteConnected;

  /// Whether there are pending operations.
  final bool hasPendingOperations;

  /// Number of pending operations.
  final int pendingOperationCount;

  /// Whether there are failed operations.
  final bool hasFailedOperations;

  /// Number of failed operations.
  final int failedOperationCount;

  /// Timestamp of last successful sync.
  final DateTime? lastSuccessfulSync;

  /// List of warning messages.
  final List<String> warnings;

  /// List of error messages.
  final List<String> errors;

  /// Whether the system is healthy overall.
  bool get isHealthy =>
      isLocalStorageHealthy && !hasFailedOperations && errors.isEmpty;

  /// Current health status.
  HealthStatus get status {
    if (!isHealthy) return HealthStatus.critical;
    if (warnings.isNotEmpty || hasPendingOperations) {
      return HealthStatus.warning;
    }
    return HealthStatus.healthy;
  }

  @override
  String toString() {
    return 'HealthCheck(isLocalStorageHealthy: $isLocalStorageHealthy, isRemoteConnected: $isRemoteConnected, hasPendingOperations: $hasPendingOperations, pendingOperationCount: $pendingOperationCount, hasFailedOperations: $hasFailedOperations, failedOperationCount: $failedOperationCount, lastSuccessfulSync: $lastSuccessfulSync, warnings: $warnings, errors: $errors)';
  }
}

/// Overall health status levels.
enum HealthStatus {
  /// System is healthy.
  healthy,

  /// System has warnings.
  warning,

  /// System has critical issues.
  critical
}

/// Detailed status information for sync operations.
class SyncStatusDetails<T extends SyncableEntity> {
  /// Creates sync status details.
  const SyncStatusDetails({
    required this.userId,
    required this.isSyncing,
    required this.pendingOperations,
    required this.failedOperations,
    required this.health,
    this.lastSyncTime,
    this.lastSuccessfulSync,
    this.currentBatch,
    this.progress,
  });

  /// User ID for this status.
  final String userId;

  /// Whether a sync is currently in progress.
  final bool isSyncing;

  /// Timestamp of last sync attempt.
  final DateTime? lastSyncTime;

  /// Timestamp of last successful sync.
  final DateTime? lastSuccessfulSync;

  /// Number of pending operations.
  final int pendingOperations;

  /// Number of failed operations.
  final int failedOperations;

  /// Current batch being processed.
  final List<SyncOperation<T>>? currentBatch;

  /// Progress percentage (0.0 to 1.0).
  final double? progress;

  /// Current health status.
  final SyncHealth health;

  /// Whether there is unsynced data.
  bool get hasUnsyncedData => pendingOperations > 0;

  /// Whether there are failures.
  bool get hasFailures => failedOperations > 0;

  /// Time elapsed since last sync.
  Duration? get timeSinceLastSync =>
      lastSyncTime != null ? DateTime.now().difference(lastSyncTime!) : null;

  @override
  String toString() {
    return 'SyncStatusDetails(userId: $userId, isSyncing: $isSyncing, lastSyncTime: $lastSyncTime, lastSuccessfulSync: $lastSuccessfulSync, pendingOperations: $pendingOperations, failedOperations: $failedOperations, currentBatch: $currentBatch, progress: $progress, health: $health)';
  }
}

/// Sync health status levels.
enum SyncHealth {
  /// System is healthy.
  healthy,

  /// Currently syncing.
  syncing,

  /// Operations are pending.
  pending,

  /// System performance is degraded.
  degraded,

  /// System is offline.
  offline,

  /// System has errors.
  error
}
