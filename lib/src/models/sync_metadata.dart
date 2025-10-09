/// Metadata describing the synchronization state for a specific user.
class SyncMetadata {
  const SyncMetadata({
    required this.userId,
    required this.lastSyncTime,
    required this.dataHash,
    required this.itemCount,
    this.deviceId,
    this.customMetadata,
  });

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
  final String userId;
  final DateTime lastSyncTime;
  final String dataHash;
  final int itemCount;
  final String? deviceId;
  final Map<String, dynamic>? customMetadata;

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

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'lastSyncTime': lastSyncTime.toIso8601String(),
        'dataHash': dataHash,
        'itemCount': itemCount,
        if (deviceId != null) 'deviceId': deviceId,
        if (customMetadata != null) 'customMetadata': customMetadata,
      };
}
