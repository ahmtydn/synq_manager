import 'package:meta/meta.dart';
import 'package:synq_manager/src/events/event_types.dart';
import 'package:synq_manager/src/models/sync_data.dart';

/// Event emitted during synchronization operations
@immutable
class SynqEvent<T> {
  /// Creates a new sync event
  const SynqEvent({
    required this.type,
    required this.key,
    this.data,
    this.error,
    int? timestamp,
    this.metadata = const {},
  }) : timestamp = timestamp ?? 0;

  /// Creates a data creation event
  factory SynqEvent.create({
    required String key,
    required SyncData<T> data,
    Map<String, dynamic> metadata = const {},
  }) {
    return SynqEvent<T>(
      type: SynqEventType.create,
      key: key,
      data: data,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      metadata: metadata,
    );
  }

  /// Creates a data update event
  factory SynqEvent.update({
    required String key,
    required SyncData<T> data,
    Map<String, dynamic> metadata = const {},
  }) {
    return SynqEvent<T>(
      type: SynqEventType.update,
      key: key,
      data: data,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      metadata: metadata,
    );
  }

  /// Creates a data deletion event
  factory SynqEvent.delete({
    required String key,
    SyncData<T>? data,
    Map<String, dynamic> metadata = const {},
  }) {
    return SynqEvent<T>(
      type: SynqEventType.delete,
      key: key,
      data: data,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      metadata: metadata,
    );
  }

  /// Creates a sync start event
  factory SynqEvent.syncStart({
    required String key,
    Map<String, dynamic> metadata = const {},
  }) {
    return SynqEvent<T>(
      type: SynqEventType.syncStart,
      key: key,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      metadata: metadata,
    );
  }

  /// Creates a sync complete event
  factory SynqEvent.syncComplete({
    required String key,
    Map<String, dynamic> metadata = const {},
  }) {
    return SynqEvent<T>(
      type: SynqEventType.syncComplete,
      key: key,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      metadata: metadata,
    );
  }

  /// Creates a sync error event
  factory SynqEvent.syncError({
    required String key,
    required Object error,
    Map<String, dynamic> metadata = const {},
  }) {
    return SynqEvent<T>(
      type: SynqEventType.syncError,
      key: key,
      error: error,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      metadata: metadata,
    );
  }

  /// Creates a conflict event
  factory SynqEvent.conflict({
    required String key,
    required SyncData<T> data,
    Map<String, dynamic> metadata = const {},
  }) {
    return SynqEvent<T>(
      type: SynqEventType.conflict,
      key: key,
      data: data,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      metadata: metadata,
    );
  }

  /// Creates a connection event
  factory SynqEvent.connected({
    String key = '__connection__',
    Map<String, dynamic> metadata = const {},
  }) {
    return SynqEvent<T>(
      type: SynqEventType.connected,
      key: key,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      metadata: metadata,
    );
  }

  /// Creates a disconnection event
  factory SynqEvent.disconnected({
    String key = '__connection__',
    Object? error,
    Map<String, dynamic> metadata = const {},
  }) {
    return SynqEvent<T>(
      type: SynqEventType.disconnected,
      key: key,
      error: error,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      metadata: metadata,
    );
  }

  /// Creates instance from JSON
  factory SynqEvent.fromJson(Map<String, dynamic> json) {
    return SynqEvent<T>(
      type: SynqEventType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => SynqEventType.update,
      ),
      key: json['key'] as String,
      data: json['data'] != null
          ? SyncData<T>.fromJson(json['data'] as Map<String, dynamic>)
          : null,
      error: json['error'],
      timestamp:
          json['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
    );
  }

  /// Type of the event
  final SynqEventType type;

  /// Key associated with the event
  final String key;

  /// Data associated with the event (if applicable)
  final SyncData<T>? data;

  /// Error information (if applicable)
  final Object? error;

  /// Timestamp when the event occurred (UTC milliseconds since epoch)
  final int timestamp;

  /// Additional event metadata
  final Map<String, dynamic> metadata;

  /// Converts to JSON for serialization
  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'key': key,
      'data': data?.toJson(),
      'error': error?.toString(),
      'timestamp': timestamp,
      'metadata': metadata,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SynqEvent<T> &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          key == other.key &&
          data == other.data &&
          timestamp == other.timestamp;

  @override
  int get hashCode =>
      type.hashCode ^ key.hashCode ^ data.hashCode ^ timestamp.hashCode;

  @override
  String toString() {
    return 'SynqEvent<$T>(type: $type, key: $key, data: $data, '
        'timestamp: $timestamp)';
  }
}
