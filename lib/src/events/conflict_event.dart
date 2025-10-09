import 'package:synq_manager/src/events/sync_event.dart';
import 'package:synq_manager/src/models/conflict_context.dart';
import 'package:synq_manager/src/models/syncable_entity.dart';

/// Event emitted when the engine detects a
/// conflict between local and remote data.
class ConflictDetectedEvent<T extends SyncableEntity> extends SyncEvent<T> {
  ConflictDetectedEvent({
    required super.userId,
    required this.context,
    this.localData,
    this.remoteData,
    DateTime? timestamp,
  }) : super(timestamp: timestamp ?? DateTime.now());
  final ConflictContext context;
  final T? localData;
  final T? remoteData;
}
