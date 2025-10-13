import 'package:flutter/foundation.dart';
import 'package:synq_manager/synq_manager.dart';

/// Base class for all synchronization-related events.
@immutable
abstract class SyncEvent<T extends SyncableEntity> {
  /// Creates a base sync event.
  SyncEvent({required this.userId, DateTime? timestamp})
      : timestamp = timestamp ?? DateTime.now();

  /// The user ID associated with this event.
  final String userId;

  /// The time at which the event occurred.
  final DateTime timestamp;

  @override
  String toString() => 'SyncEvent(userId: $userId, timestamp: $timestamp)';
}

/// Event fired when a synchronization cycle starts.
class SyncStartedEvent<T extends SyncableEntity> extends SyncEvent<T> {
  /// Creates a sync started event.
  SyncStartedEvent({
    required super.userId,
    this.pendingOperations = 0,
    super.timestamp,
  });

  /// The number of pending operations to be synced.
  final int pendingOperations;

  @override
  String toString() =>
      '${super.toString()}: SyncStartedEvent(pendingOperations: $pendingOperations)';
}

/// Event fired to report synchronization progress.
class SyncProgressEvent<T extends SyncableEntity> extends SyncEvent<T> {
  /// Creates a sync progress event.
  SyncProgressEvent({
    required super.userId,
    required this.completed,
    required this.total,
    super.timestamp,
  });

  /// The number of operations completed so far.
  final int completed;

  /// The total number of operations in this sync cycle.
  final int total;

  /// The progress of the sync as a value between 0.0 and 1.0.
  double get progress => total > 0 ? completed / total : 0.0;

  @override
  String toString() =>
      '${super.toString()}: SyncProgressEvent(completed: $completed, total: $total, progress: $progress)';
}

/// Event fired when a synchronization cycle completes.
class SyncCompletedEvent<T extends SyncableEntity> extends SyncEvent<T> {
  /// Creates a sync completed event.
  SyncCompletedEvent({
    required super.userId,
    required this.result,
    super.timestamp,
  });

  /// The result of the completed synchronization cycle.
  final SyncResult result;

  @override
  String toString() =>
      '${super.toString()}: SyncCompletedEvent(result: $result)';
}

/// Event fired when an error occurs during synchronization.
class SyncErrorEvent<T extends SyncableEntity> extends SyncEvent<T> {
  /// Creates a sync error event.
  SyncErrorEvent({
    required super.userId,
    required this.error,
    this.stackTrace,
    this.isRecoverable = true,
    super.timestamp,
  });

  /// The error object or message.
  final Object error;

  /// The stack trace associated with the error, if available.
  final StackTrace? stackTrace;

  /// Whether the error is considered recoverable.
  final bool isRecoverable;

  @override
  String toString() =>
      '${super.toString()}: SyncErrorEvent(error: $error, stackTrace: $stackTrace, isRecoverable: $isRecoverable)';
}
