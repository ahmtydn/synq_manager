/// Result of a synchronization operation
class SyncResult<T> {
  const SyncResult({
    required this.status,
    this.entity,
    this.error,
    this.conflictedEntity,
  });

  /// Factory constructor for successful sync
  factory SyncResult.success(T entity) {
    return SyncResult(
      status: SyncStatus.success,
      entity: entity,
    );
  }

  /// Factory constructor for conflict detection
  factory SyncResult.conflict(T local, T remote) {
    return SyncResult(
      status: SyncStatus.conflict,
      entity: local,
      conflictedEntity: remote,
    );
  }

  /// Factory constructor for error cases
  factory SyncResult.error(String error, [T? entity]) {
    return SyncResult(
      status: SyncStatus.error,
      entity: entity,
      error: error,
    );
  }

  /// The status of the sync operation
  final SyncStatus status;

  /// The entity that was synced (or attempted to sync)
  final T? entity;

  /// Error message if sync failed
  final String? error;

  /// The conflicting entity from remote (if conflict occurred)
  final T? conflictedEntity;

  /// Whether the sync was successful
  bool get isSuccess => status == SyncStatus.success;

  /// Whether a conflict was detected
  bool get hasConflict => status == SyncStatus.conflict;

  /// Whether an error occurred
  bool get hasError => status == SyncStatus.error;
}

/// Status of a sync operation
enum SyncStatus {
  /// Sync completed successfully
  success,

  /// Conflict detected between local and remote versions
  conflict,

  /// Error occurred during sync
  error,

  /// Sync is in progress
  inProgress,

  /// Sync is pending (queued)
  pending,
}
