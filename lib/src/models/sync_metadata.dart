import 'package:flutter/foundation.dart';

/// Metadata describing the synchronization state for a specific user.
@immutable
class SyncMetadata {
  /// Creates sync metadata.
  const SyncMetadata({
    required this.userId,
    required this.lastSyncTime,
    this.entityName,
    this.dataHash,
    this.itemCount = 0,
    this.deviceId,
    this.customMetadata,
    this.entityCounts,
  });

  /// Creates SyncMetadata from JSON.
  factory SyncMetadata.fromJson(Map<String, dynamic> json) {
    return SyncMetadata(
      userId: json['userId'] as String,
      lastSyncTime: DateTime.parse(json['lastSyncTime'] as String),
      entityName: json['entityName'] as String?,
      dataHash: json['dataHash'] as String?,
      itemCount: json['itemCount'] as int? ?? 0,
      deviceId: json['deviceId'] as String?,
      customMetadata: json['customMetadata'] as Map<String, dynamic>?,
      entityCounts: json['entityCounts'] != null
          ? Map<String, int>.from(
              json['entityCounts'] as Map,
            )
          : null,
    );
  }

  /// User ID for this metadata.
  final String userId;

  /// Timestamp of last synchronization.
  final DateTime lastSyncTime;

  /// The name of the primary entity type this metadata describes (e.g., "tasks").
  final String? entityName;

  /// Hash of the data for integrity checking.
  final String? dataHash;

  /// Number of items for the primary entity type.
  final int itemCount;

  /// Optional device identifier.
  final String? deviceId;

  /// Custom metadata fields.
  final Map<String, dynamic>? customMetadata;

  /// A map of counts for different entity types, allowing tracking of multiple
  /// "tables" or data collections.
  /// Example: `{'tasks': 102, 'projects': 5}`
  final Map<String, int>? entityCounts;

  /// Creates a copy with modified fields.
  SyncMetadata copyWith({
    String? entityName,
    DateTime? lastSyncTime,
    String? dataHash,
    int? itemCount,
    String? deviceId,
    Map<String, dynamic>? customMetadata,
    Map<String, int>? entityCounts,
  }) {
    return SyncMetadata(
      userId: userId,
      entityName: entityName ?? this.entityName,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      dataHash: dataHash ?? this.dataHash,
      itemCount: itemCount ?? this.itemCount,
      deviceId: deviceId ?? this.deviceId,
      customMetadata: customMetadata ?? this.customMetadata,
      entityCounts: entityCounts ?? this.entityCounts,
    );
  }

  /// Converts to a map.
  Map<String, dynamic> toMap() => {
        'userId': userId,
        'lastSyncTime': lastSyncTime.toUtc().toIso8601String(),
        if (entityName != null) 'entityName': entityName,
        if (dataHash != null) 'dataHash': dataHash,
        'itemCount': itemCount,
        if (deviceId != null) 'deviceId': deviceId,
        if (customMetadata != null) 'customMetadata': customMetadata,
        if (entityCounts != null) 'entityCounts': entityCounts,
      };

  @override
  String toString() {
    return 'SyncMetadata(userId: $userId, lastSyncTime: $lastSyncTime, entityName: $entityName, dataHash: $dataHash, itemCount: $itemCount, deviceId: $deviceId, customMetadata: $customMetadata, entityCounts: $entityCounts)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is SyncMetadata &&
        other.userId == userId &&
        other.entityName == entityName &&
        other.lastSyncTime == lastSyncTime &&
        other.dataHash == dataHash &&
        other.itemCount == itemCount &&
        other.deviceId == deviceId &&
        mapEquals(other.entityCounts, entityCounts) &&
        mapEquals(other.customMetadata, customMetadata);
  }

  @override
  int get hashCode {
    return Object.hash(
      userId,
      entityName,
      lastSyncTime,
      dataHash,
      itemCount,
      deviceId,
      customMetadata,
      entityCounts,
    );
  }
}
