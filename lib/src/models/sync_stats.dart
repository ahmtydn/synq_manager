import 'package:meta/meta.dart';
import 'package:synq_manager/synq_manager.dart';

/// Comprehensive statistics about the current sync state.
@immutable
class SyncStats {
  const SyncStats({
    required this.lastSyncTimestamp,
    required this.pendingChangesCount,
    required this.activeConflictsCount,
    required this.connectivityStatus,
    required this.isSyncing,
  });

  final int lastSyncTimestamp;
  final int pendingChangesCount;
  final int activeConflictsCount;
  final ConnectivityStatus connectivityStatus;
  final bool isSyncing;

  Duration get timeSinceLastSync {
    if (lastSyncTimestamp == 0) return Duration.zero;
    return Duration(
      milliseconds: DateTime.now().millisecondsSinceEpoch - lastSyncTimestamp,
    );
  }

  bool get hasNeverSynced => lastSyncTimestamp == 0;
  bool get hasPendingChanges => pendingChangesCount > 0;
  bool get hasConflicts => activeConflictsCount > 0;
  bool get isOnline => connectivityStatus == ConnectivityStatus.online;

  @override
  String toString() => 'SyncStats('
      'lastSync: ${DateTime.fromMillisecondsSinceEpoch(lastSyncTimestamp)}, '
      'pending: $pendingChangesCount, '
      'conflicts: $activeConflictsCount, '
      'status: $connectivityStatus, '
      'syncing: $isSyncing)';
}
