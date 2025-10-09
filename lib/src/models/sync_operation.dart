import 'package:meta/meta.dart';
import 'package:synq_manager/src/models/syncable_entity.dart';

/// Type of operation recorded in the sync queue.
enum SyncOperationType { create, update, delete }

/// Current status of a queued operation.
enum SyncOperationStatus { pending, inProgress, completed, failed }

/// Representation of a local operation that needs to be synchronized remotely.
@immutable
class SyncOperation<T extends SyncableEntity> {
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
  final String id;
  final String userId;
  final SyncOperationType type;
  final T? data;
  final String entityId;
  final DateTime timestamp;
  final int retryCount;
  final SyncOperationStatus status;

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
