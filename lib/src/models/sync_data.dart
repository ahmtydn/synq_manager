import 'package:meta/meta.dart';

/// Generic data container for synchronization operations
@immutable
class SyncData<T> {
  /// Creates a new sync data instance
  const SyncData({
    required this.key,
    required this.value,
    required this.timestamp,
    this.version = 1,
    this.metadata = const {},
    this.deleted = false,
  });

  /// Creates instance from JSON
  factory SyncData.fromJson(Map<String, dynamic> json) {
    return SyncData<T>(
      key: json['key'] as String,
      value: json['value'] as T?,
      timestamp: json['timestamp'] as int,
      version: json['version'] as int? ?? 1,
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
      deleted: json['deleted'] as bool? ?? false,
    );
  }

  /// Unique identifier for this data
  final String key;

  /// The actual data payload
  final T? value;

  /// Timestamp when this data was last modified (UTC milliseconds since epoch)
  final int timestamp;

  /// Version number for conflict resolution
  final int version;

  /// Additional metadata for the data
  final Map<String, dynamic> metadata;

  /// Whether this data has been deleted
  final bool deleted;

  /// Creates a copy with updated values
  SyncData<T> copyWith({
    String? key,
    T? value,
    int? timestamp,
    int? version,
    Map<String, dynamic>? metadata,
    bool? deleted,
  }) {
    return SyncData<T>(
      key: key ?? this.key,
      value: value ?? this.value,
      timestamp: timestamp ?? this.timestamp,
      version: version ?? this.version,
      metadata: metadata ?? this.metadata,
      deleted: deleted ?? this.deleted,
    );
  }

  /// Creates a new version with incremented version number
  SyncData<T> incrementVersion({
    T? newValue,
    int? newTimestamp,
    Map<String, dynamic>? newMetadata,
    bool? isDeleted,
  }) {
    return copyWith(
      value: newValue ?? value,
      timestamp: newTimestamp ?? DateTime.now().millisecondsSinceEpoch,
      version: version + 1,
      metadata: newMetadata ?? metadata,
      deleted: isDeleted ?? deleted,
    );
  }

  /// Converts to JSON for serialization
  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'value': value,
      'timestamp': timestamp,
      'version': version,
      'metadata': metadata,
      'deleted': deleted,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncData<T> &&
          runtimeType == other.runtimeType &&
          key == other.key &&
          value == other.value &&
          timestamp == other.timestamp &&
          version == other.version &&
          deleted == other.deleted;

  @override
  int get hashCode =>
      key.hashCode ^
      value.hashCode ^
      timestamp.hashCode ^
      version.hashCode ^
      deleted.hashCode;

  @override
  String toString() {
    return 'SyncData<$T>(key: $key, value: $value, timestamp: $timestamp, '
        'version: $version, deleted: $deleted)';
  }
}
