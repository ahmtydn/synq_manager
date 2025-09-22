/// Overall status of the synchronization system
class SyncSystemStatus {
  const SyncSystemStatus({
    required this.isOnline,
    required this.lastSyncTime,
    required this.pendingCount,
    required this.conflictCount,
    this.error,
    this.isBackgroundSyncEnabled = true,
  });

  /// Whether the device is online and can sync
  final bool isOnline;

  /// Last successful sync timestamp
  final DateTime? lastSyncTime;

  /// Number of entities pending sync
  final int pendingCount;

  /// Number of unresolved conflicts
  final int conflictCount;

  /// Current sync error, if any
  final String? error;

  /// Whether background sync is enabled
  final bool isBackgroundSyncEnabled;

  /// Whether sync is needed
  bool get needsSync => pendingCount > 0;

  /// Whether there are issues requiring attention
  bool get hasIssues => conflictCount > 0 || error != null;

  /// Copy with new values
  SyncSystemStatus copyWith({
    bool? isOnline,
    DateTime? lastSyncTime,
    int? pendingCount,
    int? conflictCount,
    String? error,
    bool? isBackgroundSyncEnabled,
  }) {
    return SyncSystemStatus(
      isOnline: isOnline ?? this.isOnline,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      pendingCount: pendingCount ?? this.pendingCount,
      conflictCount: conflictCount ?? this.conflictCount,
      error: error ?? this.error,
      isBackgroundSyncEnabled:
          isBackgroundSyncEnabled ?? this.isBackgroundSyncEnabled,
    );
  }
}
