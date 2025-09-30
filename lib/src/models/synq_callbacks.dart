import 'package:synq_manager/synq_manager.dart';

/// Function type for creating T from JSON
typedef FromJsonFunction<T> = T Function(Map<String, dynamic> json);

/// Function type for converting T to JSON
typedef ToJsonFunction<T> = Map<String, dynamic> Function(T object);

/// Function signature for pushing local changes to cloud storage.
typedef CloudSyncFunction<T> = Future<SyncResult<T>> Function(
  Map<String, SyncData<T>> localChanges,
  Map<String, String> headers,
);

/// Function signature for fetching remote changes from cloud storage.
typedef CloudFetchFunction<T> = Future<CloudFetchResponse<T>> Function(
  int lastSyncTimestamp,
  Map<String, String> headers,
);

/// Returns the action user wants to take for this conflict
typedef ConflictResolutionCallback<T> = Future<ConflictAction> Function(
  ConflictContext<T> context,
);

/// Collection of all callback functions used by SynqManager
class SynqCallbacks<T extends DocumentSerializable> {
  const SynqCallbacks({
    required this.cloudSyncFunction,
    required this.cloudFetchFunction,
    this.conflictResolutionCallback,
    this.fromJson,
    this.toJson,
  });

  /// Function to push data to cloud storage
  final CloudSyncFunction<T> cloudSyncFunction;

  /// Function to fetch data from cloud storage
  final CloudFetchFunction<T> cloudFetchFunction;

  /// Callback for handling conflicts (user account and data conflicts)
  final ConflictResolutionCallback? conflictResolutionCallback;

  /// Function to deserialize T from JSON
  final FromJsonFunction<T>? fromJson;

  /// Function to serialize T to JSON
  final ToJsonFunction<T>? toJson;

  /// Creates a copy with updated values
  SynqCallbacks<T> copyWith({
    CloudSyncFunction<T>? cloudSyncFunction,
    CloudFetchFunction<T>? cloudFetchFunction,
    ConflictResolutionCallback? conflictResolutionCallback,
    FromJsonFunction<T>? fromJson,
    ToJsonFunction<T>? toJson,
  }) {
    return SynqCallbacks<T>(
      cloudSyncFunction: cloudSyncFunction ?? this.cloudSyncFunction,
      cloudFetchFunction: cloudFetchFunction ?? this.cloudFetchFunction,
      conflictResolutionCallback:
          conflictResolutionCallback ?? this.conflictResolutionCallback,
      fromJson: fromJson ?? this.fromJson,
      toJson: toJson ?? this.toJson,
    );
  }
}
