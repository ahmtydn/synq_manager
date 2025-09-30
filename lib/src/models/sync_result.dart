import 'package:meta/meta.dart';
import 'package:synq_manager/synq_manager.dart';

/// Result of a cloud synchronization operation containing synced data and conflicts.
@immutable
class SyncResult<T> {
  const SyncResult({
    required this.success,
    this.remoteData = const {},
    this.conflicts = const [],
    this.error,
    this.metadata = const {},
  });

  final bool success;
  final Map<String, SyncData<T>> remoteData;
  final List<DataConflict<T>> conflicts;
  final Object? error;
  final Map<String, dynamic> metadata;

  bool get hasConflicts => conflicts.isNotEmpty;
  bool get hasError => error != null;
}

/// Response from a cloud fetch operation including user identity information.
@immutable
class CloudFetchResponse<T> {
  const CloudFetchResponse({
    required this.data,
    this.cloudUserId,
    this.metadata = const {},
  });

  final Map<String, SyncData<T>> data;
  final String? cloudUserId;
  final Map<String, dynamic> metadata;

  bool get hasData => data.isNotEmpty;
  bool get hasUserId => cloudUserId != null;
}
