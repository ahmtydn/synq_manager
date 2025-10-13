import 'package:synq_manager/synq_manager.dart';

/// Configuration passed when triggering manual synchronization.
class SyncOptions<T extends SyncableEntity> {
  /// Creates sync options.
  const SyncOptions({
    this.includeDeletes = true,
    this.resolveConflicts = true,
    this.forceFullSync = false,
    this.overrideBatchSize,
    this.timeout,
    this.direction,
    this.conflictResolver,
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

  /// The order of synchronization operations.
  final SyncDirection? direction;

  /// A conflict resolver to override the default for this sync only.
  final SyncConflictResolver<T>? conflictResolver;
}
