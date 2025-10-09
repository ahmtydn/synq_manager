import 'package:meta/meta.dart';
import 'package:synq_manager/src/models/conflict_resolution.dart';
import 'package:synq_manager/src/models/sync_operation.dart';
import 'package:synq_manager/src/models/syncable_entity.dart';

/// Snapshot describing the current sync state for a user.
@immutable
class SyncStatusSnapshot {
  const SyncStatusSnapshot({
    required this.userId,
    required this.status,
    required this.pendingOperations,
    required this.completedOperations,
    required this.failedOperations,
    required this.progress,
    this.lastStartedAt,
    this.lastCompletedAt,
  });
  final String userId;
  final SyncStatus status;
  final int pendingOperations;
  final int completedOperations;
  final int failedOperations;
  final double progress;
  final DateTime? lastStartedAt;
  final DateTime? lastCompletedAt;

  bool get hasUnsyncedData => pendingOperations > 0;
  bool get hasFailures => failedOperations > 0;

  SyncStatusSnapshot copyWith({
    SyncStatus? status,
    int? pendingOperations,
    int? completedOperations,
    int? failedOperations,
    double? progress,
    DateTime? lastStartedAt,
    DateTime? lastCompletedAt,
  }) {
    return SyncStatusSnapshot(
      userId: userId,
      status: status ?? this.status,
      pendingOperations: pendingOperations ?? this.pendingOperations,
      completedOperations: completedOperations ?? this.completedOperations,
      failedOperations: failedOperations ?? this.failedOperations,
      progress: progress ?? this.progress,
      lastStartedAt: lastStartedAt ?? this.lastStartedAt,
      lastCompletedAt: lastCompletedAt ?? this.lastCompletedAt,
    );
  }
}

/// High level states for synchronization.
enum SyncStatus {
  idle,
  syncing,
  paused,
  cancelled,
  failed,
  completed,
}

/// Configuration passed when triggering manual synchronization.
class SyncOptions {
  const SyncOptions({
    this.includeDeletes = true,
    this.resolveConflicts = true,
    this.forceFullSync = false,
    this.overrideBatchSize,
    this.timeout,
  });
  final bool includeDeletes;
  final bool resolveConflicts;
  final bool forceFullSync;
  final int? overrideBatchSize;
  final Duration? timeout;
}

/// Result produced after a sync cycle finishes.
@immutable
class SyncResult {
  const SyncResult({
    required this.userId,
    required this.syncedCount,
    required this.failedCount,
    required this.conflictsResolved,
    required this.pendingOperations,
    required this.duration,
    this.errors = const [],
    this.wasCancelled = false,
  });
  final String userId;
  final int syncedCount;
  final int failedCount;
  final int conflictsResolved;
  final List<SyncOperation<SyncableEntity>> pendingOperations;
  final Duration duration;
  final List<Object> errors;
  final bool wasCancelled;

  bool get isSuccess => failedCount == 0 && !wasCancelled;
}

/// Aggregated statistics about multiple sync cycles.
class SyncStatistics {
  const SyncStatistics({
    this.totalSyncs = 0,
    this.successfulSyncs = 0,
    this.failedSyncs = 0,
    this.conflictsDetected = 0,
    this.conflictsAutoResolved = 0,
    this.conflictsUserResolved = 0,
    this.averageDuration = Duration.zero,
    this.totalSyncDuration = Duration.zero,
  });
  final int totalSyncs;
  final int successfulSyncs;
  final int failedSyncs;
  final int conflictsDetected;
  final int conflictsAutoResolved;
  final int conflictsUserResolved;
  final Duration averageDuration;
  final Duration totalSyncDuration;

  SyncStatistics copyWith({
    int? totalSyncs,
    int? successfulSyncs,
    int? failedSyncs,
    int? conflictsDetected,
    int? conflictsAutoResolved,
    int? conflictsUserResolved,
    Duration? averageDuration,
    Duration? totalSyncDuration,
  }) {
    return SyncStatistics(
      totalSyncs: totalSyncs ?? this.totalSyncs,
      successfulSyncs: successfulSyncs ?? this.successfulSyncs,
      failedSyncs: failedSyncs ?? this.failedSyncs,
      conflictsDetected: conflictsDetected ?? this.conflictsDetected,
      conflictsAutoResolved:
          conflictsAutoResolved ?? this.conflictsAutoResolved,
      conflictsUserResolved:
          conflictsUserResolved ?? this.conflictsUserResolved,
      averageDuration: averageDuration ?? this.averageDuration,
      totalSyncDuration: totalSyncDuration ?? this.totalSyncDuration,
    );
  }
}

/// Description of a conflict encountered during a sync.
class SyncConflictSummary<T extends SyncableEntity> {
  const SyncConflictSummary({
    required this.resolution,
    required this.entityId,
  });
  final ConflictResolution<T> resolution;
  final String entityId;
}
