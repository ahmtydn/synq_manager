import 'package:synq_manager/src/models/syncable_entity.dart';

/// Remote change notification payload emitted by real-time adapters.
class RemoteChangeEvent<T extends SyncableEntity> {
  const RemoteChangeEvent({
    required this.entityId,
    required this.userId,
    required this.changeType,
    required this.timestamp,
    this.data,
    this.sourceDeviceId,
  });
  final T? data;
  final String entityId;
  final String userId;
  final RemoteChangeType changeType;
  final DateTime timestamp;
  final String? sourceDeviceId;
}

enum RemoteChangeType {
  created,
  updated,
  deleted,
}
