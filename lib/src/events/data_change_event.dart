import 'package:synq_manager/src/events/sync_event.dart';
import 'package:synq_manager/src/models/syncable_entity.dart';

/// Event emitted whenever local or remote data changes.
class DataChangeEvent<T extends SyncableEntity> extends SyncEvent<T> {
  DataChangeEvent({
    required super.userId,
    required this.data,
    required this.changeType,
    required this.source,
    DateTime? timestamp,
  }) : super(timestamp: timestamp ?? DateTime.now());
  final T data;
  final ChangeType changeType;
  final DataSource source;
}

enum ChangeType { created, updated, deleted }

enum DataSource { local, remote, merged }
