import 'dart:convert';

import 'package:synq_manager/synq_manager.dart';

/// Represents a single operation (create, update, delete) to be synchronized.
class SyncOperation<T extends SyncableEntity> {
  /// Creates a [SyncOperation] from a map.
  ///
  /// Requires a `fromJsonT` function to deserialize the nested entity data.
  factory SyncOperation.fromMap(
    Map<String, dynamic> map,
    T Function(Map<String, dynamic> json) fromJsonT,
  ) {
    return SyncOperation<T>(
      id: map['id'] as String,
      userId: map['userId'] as String,
      entityId: map['entityId'] as String,
      type: SyncOperationType.values.byName(map['type'] as String),
      data: map['data'] != null
          ? fromJsonT(map['data'] as Map<String, dynamic>)
          : null,
      delta: map['delta'] != null
          ? Map<String, dynamic>.from(map['delta'] as Map<String, dynamic>)
          : null,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      retryCount: map['retryCount'] as int? ?? 0,
    );
  }

  /// Creates a [SyncOperation] from a JSON string.
  factory SyncOperation.fromJson(
    String source,
    T Function(Map<String, dynamic> json) fromJsonT,
  ) =>
      SyncOperation.fromMap(
        json.decode(source) as Map<String, dynamic>,
        fromJsonT,
      );

  /// Creates a [SyncOperation].
  const SyncOperation({
    required this.id,
    required this.userId,
    required this.entityId,
    required this.type,
    required this.timestamp,
    this.data,
    this.delta,
    this.retryCount = 0,
  }) : assert(retryCount >= 0, 'retryCount cannot be negative');

  /// A unique identifier for this operation.
  final String id;

  /// The ID of the user this operation belongs to.
  final String userId;

  /// The ID of the entity this operation targets.
  final String entityId;

  /// The type of operation (create, update, delete).
  final SyncOperationType type;

  /// The full data payload of the entity.
  ///
  /// For `create` and `update`, this holds the complete entity state.
  /// For `delete`, this may be null.
  final T? data;

  /// A map of only the fields that have changed for an `update` operation.
  ///
  /// If this is not null, the [SyncEngine] will attempt a partial "patch"
  /// update instead of pushing the full entity.
  final Map<String, dynamic>? delta;

  /// The timestamp when the operation was created.
  final DateTime timestamp;

  /// The number of times this operation has been retried.
  final int retryCount;

  /// Creates a copy of this operation with updated fields.
  SyncOperation<T> copyWith({
    String? id,
    String? userId,
    String? entityId,
    SyncOperationType? type,
    T? data,
    Map<String, dynamic>? delta,
    DateTime? timestamp,
    int? retryCount,
  }) {
    return SyncOperation<T>(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      entityId: entityId ?? this.entityId,
      type: type ?? this.type,
      data: data ?? this.data,
      delta: delta ?? this.delta,
      timestamp: timestamp ?? this.timestamp,
      retryCount: retryCount ?? this.retryCount,
    );
  }

  /// Logs the creation of the operation for debugging purposes.
  void logCreation(SynqLogger logger, String source) {
    logger.debug(
      '[$source] Created SyncOperation $id for entity $entityId. '
      'Initial retryCount: $retryCount',
    );
  }

  @override
  String toString() {
    return 'SyncOperation(id: $id, type: ${type.name}, entityId: $entityId, userId: $userId, retryCount: $retryCount)';
  }

  /// Converts the operation to a map representation.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'userId': userId,
      'entityId': entityId,
      'type': type.name,
      'data': data?.toMap(),
      'delta': delta,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'retryCount': retryCount,
    };
  }

  /// Converts the operation to a JSON string.
  String toJson() => json.encode(toMap());
}

/// The type of a synchronization operation.
enum SyncOperationType {
  /// A new entity was created.
  create,

  /// An existing entity was updated.
  update,

  /// An entity was deleted.
  delete,
}
