import 'package:meta/meta.dart';
import 'package:synq_manager/src/models/conflict_resolution.dart';
import 'package:synq_manager/src/models/sync_operation.dart';
import 'package:synq_manager/src/models/syncable_entity.dart';

/// Snapshot describing the current sync state for a user.
@immutable
class SyncStatusSnapshot {
  /// Creates a sync status snapshot.
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

  /// User ID for this snapshot.
  final String userId;

  /// Current sync status.
  final SyncStatus status;

  /// Number of operations waiting to sync.
  final int pendingOperations;

  /// Number of completed operations.
  final int completedOperations;

  /// Number of failed operations.
  final int failedOperations;

  /// Progress percentage (0.0 to 1.0).
  final double progress;

  /// When the last sync started.
  final DateTime? lastStartedAt;

  /// When the last sync completed.
  final DateTime? lastCompletedAt;

  /// Whether there is unsynced data.
  bool get hasUnsyncedData => pendingOperations > 0;

  /// Whether there are any failures.
  bool get hasFailures => failedOperations > 0;

  /// Creates a copy with modified fields.
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
  /// No sync currently running.
  idle,

  /// Sync is actively running.
  syncing,

  /// Sync was paused by user.
  paused,

  /// Sync was cancelled by user.
  cancelled,

  /// Sync failed with errors.
  failed,

  /// Sync completed successfully.
  completed,
}

/// Configuration passed when triggering manual synchronization.
class SyncOptions {
  /// Creates sync options.
  const SyncOptions({
    this.includeDeletes = true,
    this.resolveConflicts = true,
    this.forceFullSync = false,
    this.overrideBatchSize,
    this.timeout,
  });

  /// Whether to include delete operations.
  final bool includeDeletes;

  /// Whether to automatically resolve conflicts.
  final bool resolveConflicts;

  /// Whether to force a full sync.
  final bool forceFullSync;

  /// Custom batch size override.
  final int? overrideBatchSize;

  /// Timeout for sync operations.
  final Duration? timeout;
}

/// Result produced after a sync cycle finishes.
@immutable
class SyncResult {
  /// Creates a sync result.
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

  /// User ID for this sync result.
  final String userId;

  /// Number of successfully synced operations.
  final int syncedCount;

  /// Number of failed operations.
  final int failedCount;

  /// Number of conflicts that were resolved.
  final int conflictsResolved;

  /// Operations still pending.
  final List<SyncOperation<SyncableEntity>> pendingOperations;

  /// Duration of the sync operation.
  final Duration duration;

  /// List of errors encountered.
  final List<Object> errors;

  /// Whether the sync was cancelled.
  final bool wasCancelled;

  /// Whether the sync was successful.
  bool get isSuccess => failedCount == 0 && !wasCancelled;
}

/// Aggregated statistics about multiple sync cycles.
class SyncStatistics {
  /// Creates sync statistics.
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

  /// Total number of sync operations.
  final int totalSyncs;

  /// Number of successful syncs.
  final int successfulSyncs;

  /// Number of failed syncs.
  final int failedSyncs;

  /// Number of conflicts detected.
  final int conflictsDetected;

  /// Number of automatically resolved conflicts.
  final int conflictsAutoResolved;

  /// Number of user-resolved conflicts.
  final int conflictsUserResolved;

  /// Average duration of sync operations.
  final Duration averageDuration;

  /// Total duration of all syncs.
  final Duration totalSyncDuration;

  /// Creates a copy with modified fields.
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
  /// Creates a conflict summary.
  const SyncConflictSummary({
    required this.resolution,
    required this.entityId,
  });

  /// How the conflict was resolved.
  final ConflictResolution<T> resolution;

  /// ID of the entity involved in the conflict.
  final String entityId;
}
