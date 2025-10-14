import 'package:flutter/foundation.dart';

/// Describes the synchronization state for a single entity type.
@immutable
class EntitySyncDetails {
  /// Creates details for an entity's sync state.
  const EntitySyncDetails({
    required this.count,
    this.hash,
  });

  /// Creates [EntitySyncDetails] from a map (JSON).
  factory EntitySyncDetails.fromJson(Map<String, dynamic> json) {
    return EntitySyncDetails(
      count: json['count'] as int,
      hash: json['hash'] as String?,
    );
  }

  /// The total number of items for this entity.
  final int count;

  /// An optional hash of this entity's data for integrity checking.
  final String? hash;

  /// Converts to a map for JSON serialization.
  Map<String, dynamic> toMap() => {
        'count': count,
        if (hash != null) 'hash': hash,
      };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is EntitySyncDetails &&
        other.count == count &&
        other.hash == hash;
  }

  @override
  int get hashCode => Object.hash(count, hash);

  @override
  String toString() => 'EntitySyncDetails(count: $count, hash: $hash)';
}

/// Metadata describing the synchronization state for a specific user.
@immutable
class SyncMetadata {
  /// Creates sync metadata.
  const SyncMetadata({
    required this.userId,
    required this.lastSyncTime,
    this.dataHash,
    this.deviceId,
    this.customMetadata,
    this.entityCounts,
  });

  /// Creates SyncMetadata from JSON.
  factory SyncMetadata.fromJson(Map<String, dynamic> json) {
    return SyncMetadata(
      userId: json['userId'] as String,
      lastSyncTime: DateTime.parse(json['lastSyncTime'] as String),
      dataHash: json['dataHash'] as String?,
      deviceId: json['deviceId'] as String?,
      customMetadata: json['customMetadata'] as Map<String, dynamic>?,
      entityCounts: json['entityCounts'] != null
          ? (json['entityCounts'] as Map<String, dynamic>).map(
              (key, value) => MapEntry(
                key,
                EntitySyncDetails.fromJson(value as Map<String, dynamic>),
              ),
            )
          : null,
    );
  }

  /// User ID for this metadata.
  final String userId;

  /// Timestamp of last synchronization.
  final DateTime lastSyncTime;

  /// An optional global hash of all data for high-level integrity checking.
  final String? dataHash;

  /// Optional device identifier.
  final String? deviceId;

  /// Custom metadata fields.
  final Map<String, dynamic>? customMetadata;

  /// A map of counts for different entity types, allowing tracking of multiple
  /// "tables" or data collections.
  /// Example: `{'tasks': EntitySyncDetails(count: 102, hash: 'abc'), 'projects': EntitySyncDetails(count: 5, hash: 'def')}`
  final Map<String, EntitySyncDetails>? entityCounts;

  /// Creates a copy with modified fields.
  SyncMetadata copyWith({
    DateTime? lastSyncTime,
    String? dataHash,
    String? deviceId,
    Map<String, dynamic>? customMetadata,
    Map<String, EntitySyncDetails>? entityCounts,
  }) {
    return SyncMetadata(
      userId: userId,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      dataHash: dataHash ?? this.dataHash,
      deviceId: deviceId ?? this.deviceId,
      customMetadata: customMetadata ?? this.customMetadata,
      entityCounts: entityCounts ?? this.entityCounts,
    );
  }

  /// Converts to a map.
  Map<String, dynamic> toMap() => {
        'userId': userId,
        'lastSyncTime': lastSyncTime.toUtc().toIso8601String(),
        if (dataHash != null) 'dataHash': dataHash,
        if (deviceId != null) 'deviceId': deviceId,
        if (customMetadata != null) 'customMetadata': customMetadata,
        if (entityCounts != null)
          'entityCounts':
              entityCounts!.map((key, value) => MapEntry(key, value.toMap())),
      };

  @override
  String toString() {
    return 'SyncMetadata(userId: $userId, lastSyncTime: $lastSyncTime, dataHash: $dataHash, deviceId: $deviceId, customMetadata: $customMetadata, entityCounts: $entityCounts)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is SyncMetadata &&
        other.userId == userId &&
        other.lastSyncTime == lastSyncTime &&
        other.dataHash == dataHash &&
        other.deviceId == deviceId &&
        mapEquals(other.entityCounts, entityCounts) &&
        mapEquals(other.customMetadata, customMetadata);
  }

  @override
  int get hashCode {
    return Object.hash(
      userId,
      lastSyncTime,
      dataHash,
      deviceId,
      customMetadata,
      entityCounts,
    );
  }
}
