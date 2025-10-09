import 'package:synq_manager/src/events/sync_event.dart';
import 'package:synq_manager/src/models/syncable_entity.dart';

/// Event emitted when the active user is changed in the manager.
class UserSwitchedEvent<T extends SyncableEntity> extends SyncEvent<T> {
  UserSwitchedEvent({
    required this.previousUserId,
    required this.newUserId,
    required this.hadUnsyncedData,
    DateTime? timestamp,
  }) : super(userId: newUserId, timestamp: timestamp ?? DateTime.now());
  final String? previousUserId;
  final String newUserId;
  final bool hadUnsyncedData;
}
