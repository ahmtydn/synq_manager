import 'package:meta/meta.dart';
import 'package:synq_manager/src/models/conflict_resolution.dart';
import 'package:synq_manager/src/models/sync_operation.dart';
import 'package:synq_manager/src/models/sync_status.dart';
import 'package:synq_manager/src/models/syncable_entity.dart';

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

  /// Creates a [SyncResult] from a [SyncStatusSnapshot].
  factory SyncResult.fromSnapshot(
    SyncStatusSnapshot snapshot, {
    required Duration duration,
    List<SyncOperation<SyncableEntity>>? pendingOperations,
    List<Object>? errors,
  }) {
    return SyncResult(
      userId: snapshot.userId,
      syncedCount: snapshot.syncedCount,
      failedCount: snapshot.failedOperations, // Corrected from failedCount
      conflictsResolved: snapshot.conflictsResolved,
      pendingOperations: pendingOperations ??
          List.filled(
            snapshot.pendingOperations,
            SyncOperation(
              id: '',
              userId: '',
              entityId: '',
              type: SyncOperationType.create,
              timestamp: DateTime(0),
            ),
          ),
      duration: duration,
      errors: errors ?? snapshot.errors,
    );
  }

  /// Creates a result for a skipped sync cycle.
  factory SyncResult.skipped(String userId, int pendingOperations) =>
      SyncResult(
        userId: userId,
        syncedCount: 0,
        failedCount: 0,
        conflictsResolved: 0,
        pendingOperations: List.filled(
          pendingOperations,
          SyncOperation(
            id: '',
            userId: '',
            entityId: '',
            type: SyncOperationType.create,
            timestamp: DateTime(0),
          ),
        ),
        duration: Duration.zero,
      );

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
