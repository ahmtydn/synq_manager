import 'package:meta/meta.dart';

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
    this.errors = const [],
    this.syncedCount = 0,
    this.conflictsResolved = 0,
  });

  /// Creates an initial snapshot for a user.
  factory SyncStatusSnapshot.initial(String userId) {
    return SyncStatusSnapshot(
      userId: userId,
      status: SyncStatus.idle,
      pendingOperations: 0,
      completedOperations: 0,
      failedOperations: 0,
      progress: 0,
    );
  }

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

  /// Errors encountered during the sync.
  final List<Object> errors;

  /// Number of successfully synced operations in the current cycle.
  final int syncedCount;

  /// Number of conflicts resolved in the current cycle.
  final int conflictsResolved;

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
    List<Object>? errors,
    int? syncedCount,
    int? conflictsResolved,
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
      errors: errors ?? this.errors,
      syncedCount: syncedCount ?? this.syncedCount,
      conflictsResolved: conflictsResolved ?? this.conflictsResolved,
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
