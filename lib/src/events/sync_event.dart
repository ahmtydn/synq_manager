import 'package:synq_manager/src/models/syncable_entity.dart';

/// Base class for all events emitted by the synchronization system.
abstract class SyncEvent<T extends SyncableEntity> {
  /// Creates a sync event.
  const SyncEvent({required this.userId, required this.timestamp});

  /// User ID associated with the event.
  final String userId;

  /// Timestamp when the event occurred.
  final DateTime timestamp;

  @override
  String toString() => 'SyncEvent(userId: $userId, timestamp: $timestamp)';
}

/// Event emitted when a sync operation starts.
class SyncStartedEvent<T extends SyncableEntity> extends SyncEvent<T> {
  /// Creates a sync started event.
  SyncStartedEvent({
    required super.userId,
    required this.pendingOperations,
    DateTime? timestamp,
  }) : super(timestamp: timestamp ?? DateTime.now());

  /// Number of operations pending sync.
  final int pendingOperations;

  @override
  String toString() =>
      'SyncStartedEvent(pendingOperations: $pendingOperations)';
}

/// Event emitted during sync to report progress.
class SyncProgressEvent<T extends SyncableEntity> extends SyncEvent<T> {
  /// Creates a sync progress event.
  SyncProgressEvent({
    required super.userId,
    required this.completed,
    required this.total,
    DateTime? timestamp,
  })  : progress = total == 0 ? 0 : completed / total,
        super(timestamp: timestamp ?? DateTime.now());

  /// Number of completed operations.
  final int completed;

  /// Total number of operations.
  final int total;

  /// Progress as a fraction (0.0 to 1.0).
  final double progress;

  @override
  String toString() =>
      'SyncProgressEvent(completed: $completed, total: $total, progress: $progress)';
}

/// Event emitted when a sync operation completes.
class SyncCompletedEvent<T extends SyncableEntity> extends SyncEvent<T> {
  /// Creates a sync completed event.
  SyncCompletedEvent({
    required super.userId,
    required this.synced,
    required this.failed,
    DateTime? timestamp,
  }) : super(timestamp: timestamp ?? DateTime.now());

  /// Number of successfully synced operations.
  final int synced;

  /// Number of failed operations.
  final int failed;

  @override
  String toString() => 'SyncCompletedEvent(synced: $synced, failed: $failed)';
}

/// Event emitted when a sync error occurs.
class SyncErrorEvent<T extends SyncableEntity> extends SyncEvent<T> {
  /// Creates a sync error event.
  SyncErrorEvent({
    required super.userId,
    required this.error,
    this.stackTrace,
    this.isRecoverable = true,
    DateTime? timestamp,
  }) : super(timestamp: timestamp ?? DateTime.now());

  /// Error message.
  final String error;

  /// Stack trace if available.
  final StackTrace? stackTrace;

  /// Whether the error is recoverable.
  final bool isRecoverable;

  @override
  String toString() =>
      'SyncErrorEvent(error: $error, stackTrace: $stackTrace, isRecoverable: $isRecoverable)';
}
