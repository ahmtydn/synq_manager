import 'package:synq_manager/src/models/syncable_entity.dart';

/// Base class for all events emitted by the synchronization system.
abstract class SyncEvent<T extends SyncableEntity> {
  const SyncEvent({required this.userId, required this.timestamp});
  final String userId;
  final DateTime timestamp;
}

class SyncStartedEvent<T extends SyncableEntity> extends SyncEvent<T> {
  SyncStartedEvent({
    required super.userId,
    required this.pendingOperations,
    DateTime? timestamp,
  }) : super(timestamp: timestamp ?? DateTime.now());
  final int pendingOperations;
}

class SyncProgressEvent<T extends SyncableEntity> extends SyncEvent<T> {
  SyncProgressEvent({
    required super.userId,
    required this.completed,
    required this.total,
    DateTime? timestamp,
  })  : progress = total == 0 ? 0 : completed / total,
        super(timestamp: timestamp ?? DateTime.now());
  final int completed;
  final int total;
  final double progress;
}

class SyncCompletedEvent<T extends SyncableEntity> extends SyncEvent<T> {
  SyncCompletedEvent({
    required super.userId,
    required this.synced,
    required this.failed,
    DateTime? timestamp,
  }) : super(timestamp: timestamp ?? DateTime.now());
  final int synced;
  final int failed;
}

class SyncErrorEvent<T extends SyncableEntity> extends SyncEvent<T> {
  SyncErrorEvent({
    required super.userId,
    required this.error,
    this.stackTrace,
    this.isRecoverable = true,
    DateTime? timestamp,
  }) : super(timestamp: timestamp ?? DateTime.now());
  final String error;
  final StackTrace? stackTrace;
  final bool isRecoverable;
}
