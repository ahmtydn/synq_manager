/// Tracks metrics and statistics for sync operations.
class SynqMetrics {
  /// Creates sync metrics.
  SynqMetrics({
    this.totalSyncOperations = 0,
    this.successfulSyncs = 0,
    this.failedSyncs = 0,
    this.averageSyncDuration = Duration.zero,
    this.conflictsDetected = 0,
    this.conflictsResolvedAuto = 0,
    this.conflictsRequiringUser = 0,
    this.bytesUploaded = 0,
    this.bytesDownloaded = 0,
    Set<String>? activeUsers,
    this.userSwitchCount = 0,
  }) : activeUsers = activeUsers ?? <String>{};

  /// Total number of sync operations performed.
  int totalSyncOperations;

  /// Number of successful syncs.
  int successfulSyncs;

  /// Number of failed syncs.
  int failedSyncs;

  /// Average duration of sync operations.
  Duration averageSyncDuration;

  /// Number of conflicts detected.
  int conflictsDetected;

  /// Number of conflicts resolved automatically.
  int conflictsResolvedAuto;

  /// Number of conflicts requiring user intervention.
  int conflictsRequiringUser;

  /// Total bytes uploaded.
  int bytesUploaded;

  /// Total bytes downloaded.
  int bytesDownloaded;

  /// Set of active user IDs.
  final Set<String> activeUsers;

  /// Number of user switches performed.
  int userSwitchCount;

  /// Converts metrics to a map.
  Map<String, dynamic> toMap() => {
        'total_sync_operations': totalSyncOperations,
        'successful_syncs': successfulSyncs,
        'failed_syncs': failedSyncs,
        'average_sync_duration_ms': averageSyncDuration.inMilliseconds,
        'conflicts_detected': conflictsDetected,
        'conflicts_resolved_auto': conflictsResolvedAuto,
        'conflicts_requiring_user': conflictsRequiringUser,
        'bytes_uploaded': bytesUploaded,
        'bytes_downloaded': bytesDownloaded,
        'active_users_count': activeUsers.length,
        'user_switch_count': userSwitchCount,
      };
}
