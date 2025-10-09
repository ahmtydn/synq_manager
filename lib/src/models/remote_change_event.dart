import 'package:synq_manager/src/models/syncable_entity.dart';

/// Remote change notification payload emitted by real-time adapters.
class RemoteChangeEvent<T extends SyncableEntity> {
  /// Creates a remote change event.
  const RemoteChangeEvent({
    required this.entityId,
    required this.userId,
    required this.changeType,
    required this.timestamp,
    this.data,
    this.sourceDeviceId,
  });

  /// The changed entity data.
  final T? data;

  /// ID of the changed entity.
  final String entityId;

  /// User ID associated with the change.
  final String userId;

  /// Type of change that occurred.
  final RemoteChangeType changeType;

  /// Timestamp when the change occurred.
  final DateTime timestamp;

  /// Optional device ID that originated the change.
  final String? sourceDeviceId;
}

/// Type of remote change.
enum RemoteChangeType {
  /// Entity was created.
  created,

  /// Entity was updated.
  updated,

  /// Entity was deleted.
  deleted,
}
