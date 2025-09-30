import 'package:synq_manager/src/models/sync_data.dart';
import 'package:synq_manager/src/models/sync_result.dart';

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
