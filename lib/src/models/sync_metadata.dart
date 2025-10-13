import 'package:flutter/foundation.dart';

/// Metadata describing the synchronization state for a specific user.
@immutable
class SyncMetadata {
  /// Creates sync metadata.
  const SyncMetadata({
    required this.userId,
    required this.lastSyncTime,
    required this.dataHash,
    required this.itemCount,
    this.deviceId,
    this.customMetadata,
  });

  /// Creates SyncMetadata from JSON.
  factory SyncMetadata.fromJson(Map<String, dynamic> json) {
    return SyncMetadata(
      userId: json['userId'] as String,
      lastSyncTime: DateTime.parse(json['lastSyncTime'] as String),
      dataHash: json['dataHash'] as String,
      itemCount: json['itemCount'] as int,
      deviceId: json['deviceId'] as String?,
      customMetadata: json['customMetadata'] as Map<String, dynamic>?,
    );
  }

  /// User ID for this metadata.
  final String userId;

  /// Timestamp of last synchronization.
  final DateTime lastSyncTime;

  /// Hash of the data for integrity checking.
  final String dataHash;

  /// Number of items in the dataset.
  final int itemCount;

  /// Optional device identifier.
  final String? deviceId;

  /// Custom metadata fields.
  final Map<String, dynamic>? customMetadata;

  /// Creates a copy with modified fields.
  SyncMetadata copyWith({
    DateTime? lastSyncTime,
    String? dataHash,
    int? itemCount,
    String? deviceId,
    Map<String, dynamic>? customMetadata,
  }) {
    return SyncMetadata(
      userId: userId,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      dataHash: dataHash ?? this.dataHash,
      itemCount: itemCount ?? this.itemCount,
      deviceId: deviceId ?? this.deviceId,
      customMetadata: customMetadata ?? this.customMetadata,
    );
  }

  /// Converts to a map.
  Map<String, dynamic> toMap() => {
        'userId': userId,
        'lastSyncTime': lastSyncTime.toUtc().toIso8601String(),
        'dataHash': dataHash,
        'itemCount': itemCount,
        if (deviceId != null) 'deviceId': deviceId,
        if (customMetadata != null) 'customMetadata': customMetadata,
      };

  @override
  String toString() {
    return 'SyncMetadata(userId: $userId, lastSyncTime: $lastSyncTime, dataHash: $dataHash, itemCount: $itemCount, deviceId: $deviceId, customMetadata: $customMetadata)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is SyncMetadata &&
        other.userId == userId &&
        other.lastSyncTime == lastSyncTime &&
        other.dataHash == dataHash &&
        other.itemCount == itemCount &&
        other.deviceId == deviceId &&
        mapEquals(other.customMetadata, customMetadata);
  }

  @override
  int get hashCode {
    return Object.hash(
      userId,
      lastSyncTime,
      dataHash,
      itemCount,
      deviceId,
    );
  }
}
