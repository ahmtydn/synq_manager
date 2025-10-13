import 'package:synq_manager/src/events/sync_event.dart';
import 'package:synq_manager/src/models/syncable_entity.dart';

/// Event emitted whenever local or remote data changes.
class DataChangeEvent<T extends SyncableEntity> extends SyncEvent<T> {
  /// Creates a data change event.
  DataChangeEvent({
    required super.userId,
    required this.data,
    required this.changeType,
    required this.source,
    DateTime? timestamp,
  }) : super(timestamp: timestamp ?? DateTime.now());

  /// The changed data.
  final T data;

  /// Type of change that occurred.
  final ChangeType changeType;

  /// Source of the change.
  final DataSource source;

  @override
  String toString() =>
      '${super.toString()}: DataChangeEvent(data: $data, changeType: $changeType, source: $source)';
}

/// Type of data change.
enum ChangeType {
  /// Data was created.
  created,

  /// Data was updated.
  updated,

  /// Data was deleted.
  deleted
}

/// Source of data change.
enum DataSource {
  /// Change originated locally.
  local,

  /// Change came from remote source.
  remote,

  /// Change is a result of merging.
  merged
}
