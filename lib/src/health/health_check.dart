import 'package:synq_manager/src/models/sync_operation.dart';
import 'package:synq_manager/src/models/syncable_entity.dart';

class HealthCheck {
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
  final bool isLocalStorageHealthy;
  final bool isRemoteConnected;
  final bool hasPendingOperations;
  final int pendingOperationCount;
  final bool hasFailedOperations;
  final int failedOperationCount;
  final DateTime? lastSuccessfulSync;
  final List<String> warnings;
  final List<String> errors;

  bool get isHealthy =>
      isLocalStorageHealthy && !hasFailedOperations && errors.isEmpty;

  HealthStatus get status {
    if (!isHealthy) return HealthStatus.critical;
    if (warnings.isNotEmpty || hasPendingOperations) {
      return HealthStatus.warning;
    }
    return HealthStatus.healthy;
  }
}

enum HealthStatus { healthy, warning, critical }

class SyncStatusDetails<T extends SyncableEntity> {
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
  final String userId;
  final bool isSyncing;
  final DateTime? lastSyncTime;
  final DateTime? lastSuccessfulSync;
  final int pendingOperations;
  final int failedOperations;
  final List<SyncOperation<T>>? currentBatch;
  final double? progress;
  final SyncHealth health;

  bool get hasUnsyncedData => pendingOperations > 0;
  bool get hasFailures => failedOperations > 0;

  Duration? get timeSinceLastSync =>
      lastSyncTime != null ? DateTime.now().difference(lastSyncTime!) : null;
}

enum SyncHealth { healthy, syncing, pending, degraded, offline, error }
