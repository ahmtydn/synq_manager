import 'package:flutter/foundation.dart';
import 'package:synq_manager/src/models/sync_operation.dart';
import 'package:synq_manager/src/models/syncable_entity.dart';

/// Represents a change that occurred in the data source.
/// This is used to notify about external changes in cloud or remote adapters.
@immutable
class ChangeDetail<T extends SyncableEntity> {
  /// Creates a change detail.
  const ChangeDetail({
    required this.type,
    required this.entityId,
    required this.userId,
    required this.timestamp,
    this.data,
    this.sourceId,
  });

  /// Type of change operation.
  final SyncOperationType type;

  /// ID of the entity that changed.
  final String entityId;

  /// ID of the user who owns the entity.
  final String userId;

  /// The changed entity data (null for delete operations).
  final T? data;

  /// When the change occurred.
  final DateTime timestamp;

  /// Optional identifier for the source of the change
  /// (e.g., device ID, session ID).
  /// This can be used to avoid processing changes
  /// that originated from this instance.
  final String? sourceId;

  /// Creates a copy with modified fields.
  ChangeDetail<T> copyWith({
    SyncOperationType? type,
    String? entityId,
    String? userId,
    T? data,
    DateTime? timestamp,
    String? sourceId,
  }) {
    return ChangeDetail<T>(
      type: type ?? this.type,
      entityId: entityId ?? this.entityId,
      userId: userId ?? this.userId,
      data: data ?? this.data,
      timestamp: timestamp ?? this.timestamp,
      sourceId: sourceId ?? this.sourceId,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ChangeDetail<T> &&
        other.type == type &&
        other.entityId == entityId &&
        other.userId == userId &&
        other.timestamp == timestamp &&
        other.sourceId == sourceId;
  }

  @override
  int get hashCode {
    return Object.hash(
      type,
      entityId,
      userId,
      timestamp,
      sourceId,
    );
  }

  @override
  String toString() {
    return 'ChangeDetail(type: $type, entityId: $entityId, userId: '
        '$userId, timestamp: $timestamp, sourceId: $sourceId)';
  }
}
