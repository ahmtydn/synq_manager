class SynqMetrics {
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
  int totalSyncOperations;
  int successfulSyncs;
  int failedSyncs;
  Duration averageSyncDuration;
  int conflictsDetected;
  int conflictsResolvedAuto;
  int conflictsRequiringUser;
  int bytesUploaded;
  int bytesDownloaded;
  final Set<String> activeUsers;
  int userSwitchCount;

  Map<String, dynamic> toJson() => {
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
