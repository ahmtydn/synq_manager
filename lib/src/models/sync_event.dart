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
    required this.data,
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
    required SyncData<T> data,
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
      data: SyncData.empty(),
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
      data: SyncData.empty(),
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
      data: SyncData.empty(),
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
      data: SyncData.empty(),
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
      data: SyncData.empty(),
      type: SynqEventType.disconnected,
      key: key,
      error: error,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      metadata: metadata,
    );
  }

  /// Creates a cloud sync start event
  factory SynqEvent.cloudSyncStart({
    required String key,
    Map<String, dynamic> metadata = const {},
  }) {
    return SynqEvent<T>(
      data: SyncData.empty(),
      type: SynqEventType.cloudSyncStart,
      key: key,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      metadata: metadata,
    );
  }

  /// Creates a cloud sync success event
  factory SynqEvent.cloudSyncSuccess({
    required String key,
    Map<String, dynamic> metadata = const {},
  }) {
    return SynqEvent<T>(
      data: SyncData.empty(),
      type: SynqEventType.cloudSyncSuccess,
      key: key,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      metadata: metadata,
    );
  }

  /// Creates a cloud sync error event
  factory SynqEvent.cloudSyncError({
    required String key,
    required Object error,
    Map<String, dynamic> metadata = const {},
  }) {
    return SynqEvent<T>(
      data: SyncData.empty(),
      type: SynqEventType.cloudSyncError,
      key: key,
      error: error,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      metadata: metadata,
    );
  }

  /// Creates a cloud fetch start event
  factory SynqEvent.cloudFetchStart({
    required String key,
    Map<String, dynamic> metadata = const {},
  }) {
    return SynqEvent<T>(
      data: SyncData.empty(),
      type: SynqEventType.cloudFetchStart,
      key: key,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      metadata: metadata,
    );
  }

  /// Creates a cloud fetch success event
  factory SynqEvent.cloudFetchSuccess({
    required String key,
    Map<String, dynamic> metadata = const {},
  }) {
    return SynqEvent<T>(
      data: SyncData.empty(),
      type: SynqEventType.cloudFetchSuccess,
      key: key,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      metadata: metadata,
    );
  }

  /// Creates a cloud fetch error event
  factory SynqEvent.cloudFetchError({
    required String key,
    required Object error,
    Map<String, dynamic> metadata = const {},
  }) {
    return SynqEvent<T>(
      data: SyncData.empty(),
      type: SynqEventType.cloudFetchError,
      key: key,
      error: error,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      metadata: metadata,
    );
  }

  /// Type of the event
  final SynqEventType type;

  /// Key associated with the event
  final String key;

  /// Data associated with the event
  final SyncData<T> data;

  /// Error information (if applicable)
  final Object? error;

  /// Timestamp when the event occurred (UTC milliseconds since epoch)
  final int timestamp;

  /// Additional event metadata
  final Map<String, dynamic> metadata;

  /// Converts to JSON for serialization
  Map<String, dynamic> toJson({ToJsonFunction<T>? toJson}) {
    return {
      'type': type.name,
      'key': key,
      'data': data.toJson(toJson: toJson),
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
