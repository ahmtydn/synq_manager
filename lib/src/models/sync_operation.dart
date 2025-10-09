import 'package:meta/meta.dart';
import 'package:synq_manager/src/models/syncable_entity.dart';

/// Type of operation recorded in the sync queue.
enum SyncOperationType { create, update, delete }

/// Current status of a queued operation.
enum SyncOperationStatus { pending, inProgress, completed, failed }

/// Representation of a local operation that needs to be synchronized remotely.
@immutable
class SyncOperation<T extends SyncableEntity> {
  /// Creates a sync operation.
  const SyncOperation({
    required this.id,
    required this.userId,
    required this.type,
    required this.entityId,
    required this.timestamp,
    this.data,
    this.retryCount = 0,
    this.status = SyncOperationStatus.pending,
  });

  /// Unique identifier for the operation.
  final String id;

  /// ID of the user who initiated the operation.
  final String userId;

  /// Type of sync operation (create, update, delete).
  final SyncOperationType type;

  /// The entity data (null for delete operations).
  final T? data;

  /// ID of the entity being synchronized.
  final String entityId;

  /// Timestamp when the operation was created.
  final DateTime timestamp;

  /// Number of retry attempts.
  final int retryCount;

  /// Current status of the operation.
  final SyncOperationStatus status;

  /// Creates a copy with modified fields.
  SyncOperation<T> copyWith({
    String? id,
    String? userId,
    SyncOperationType? type,
    T? data,
    String? entityId,
    DateTime? timestamp,
    int? retryCount,
    SyncOperationStatus? status,
  }) {
    return SyncOperation<T>(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      data: data ?? this.data,
      entityId: entityId ?? this.entityId,
      timestamp: timestamp ?? this.timestamp,
      retryCount: retryCount ?? this.retryCount,
      status: status ?? this.status,
    );
  }

  /// Converts the operation to JSON format.
  Map<String, dynamic> toJson(Map<String, dynamic> Function(T)? serializer) {
    return {
      'id': id,
      'userId': userId,
      'type': type.name,
      'entityId': entityId,
      'timestamp': timestamp.toIso8601String(),
      'retryCount': retryCount,
      'status': status.name,
      if (data != null && serializer != null) 'data': serializer(data!),
    };
  }

  /// Creates a SyncOperation from JSON data.
  static SyncOperation<T> fromJson<T extends SyncableEntity>(
    Map<String, dynamic> json,
    T? Function(Map<String, dynamic>)? deserializer,
  ) {
    return SyncOperation<T>(
      id: json['id'] as String,
      userId: json['userId'] as String,
      type: SyncOperationType.values.firstWhere(
        (value) => value.name == json['type'],
        orElse: () => SyncOperationType.update,
      ),
      data: json['data'] != null && deserializer != null
          ? deserializer(json['data'] as Map<String, dynamic>)
          : null,
      entityId: json['entityId'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      retryCount: json['retryCount'] as int? ?? 0,
      status: SyncOperationStatus.values.firstWhere(
        (value) => value.name == json['status'],
        orElse: () => SyncOperationStatus.pending,
      ),
    );
  }
}
