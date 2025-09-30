/// Event types for real-time data synchronization
enum SynqEventType {
  /// Data was created
  create,

  /// Data was updated
  update,

  /// Data was deleted
  delete,

  /// Synchronization started
  syncStart,

  /// Synchronization completed successfully
  syncComplete,

  /// Synchronization failed
  syncError,

  /// Cloud sync operation started
  cloudSyncStart,

  /// Cloud sync operation completed successfully
  cloudSyncSuccess,

  /// Cloud sync operation failed
  cloudSyncError,

  /// Cloud fetch operation started
  cloudFetchStart,

  /// Cloud fetch operation completed successfully
  cloudFetchSuccess,

  /// Cloud fetch operation failed
  cloudFetchError,

  /// Connection established
  connected,

  /// Connection lost
  disconnected,

  /// Conflict detected during sync
  conflict,

  /// Conflict resolved
  conflictResolved,

  /// Sync progress update
  syncProgress,
}

/// Priority levels for synchronization operations
enum SyncPriority {
  /// Low priority, sync when convenient
  low,

  /// Normal priority, sync in regular intervals
  normal,

  /// High priority, sync as soon as possible
  high,

  /// Critical priority, sync immediately
  critical,
}

/// Status of a sync operation
enum SyncStatus {
  /// Operation is pending
  pending,

  /// Operation is in progress
  inProgress,

  /// Operation completed successfully
  completed,

  /// Operation failed
  failed,

  /// Operation was cancelled
  cancelled,
}

/// Network connectivity status
enum ConnectivityStatus {
  /// Device is online
  online,

  /// Device is offline
  offline,

  /// Connection status is unknown
  unknown,
}
