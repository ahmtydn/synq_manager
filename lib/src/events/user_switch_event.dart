import 'package:synq_manager/src/events/sync_event.dart';
import 'package:synq_manager/src/models/syncable_entity.dart';

/// Event emitted when the active user is changed in the manager.
class UserSwitchedEvent<T extends SyncableEntity> extends SyncEvent<T> {
  /// Creates a user switched event.
  UserSwitchedEvent({
    required this.previousUserId,
    required this.newUserId,
    required this.hadUnsyncedData,
    DateTime? timestamp,
  }) : super(userId: newUserId, timestamp: timestamp ?? DateTime.now());

  /// Previous user ID.
  final String? previousUserId;

  /// New user ID.
  final String newUserId;

  /// Whether the previous user had unsynced data.
  final bool hadUnsyncedData;

  @override
  String toString() =>
      '${super.toString()}: UserSwitchedEvent(previousUserId: $previousUserId, newUserId: $newUserId, hadUnsyncedData: $hadUnsyncedData)';
}
