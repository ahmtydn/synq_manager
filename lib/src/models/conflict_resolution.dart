import 'package:meta/meta.dart';
import 'package:synq_manager/src/models/sync_data.dart';

/// Strategy for resolving conflicts during synchronization
enum ConflictResolutionStrategy {
  /// Use the local version (client wins)
  useLocal,

  /// Use the remote version (server wins)
  useRemote,

  /// Use the version with the latest timestamp
  useLatestTimestamp,

  /// Use the version with the highest version number
  useHighestVersion,

  /// Merge the versions using custom logic
  merge,

  /// Manual resolution required
  manual,
}

/// Result of a conflict resolution operation
enum ConflictResolutionResult {
  /// Conflict was resolved automatically
  resolved,

  /// Conflict requires manual intervention
  requiresManual,

  /// Resolution failed
  failed,
}

/// Represents a conflict between local and remote data
@immutable
class DataConflict<T> {
  /// Creates a new data conflict
  DataConflict({
    required this.key,
    required this.localData,
    required this.remoteData,
    required this.strategy,
    this.customResolver,
    this.metadata = const {},
    DateTime? detectedAt,
  }) : detectedAt = detectedAt ?? DateTime.now();

  /// Creates instance from JSON
  factory DataConflict.fromJson(Map<String, dynamic> json) {
    return DataConflict<T>(
      key: json['key'] as String,
      localData:
          SyncData<T>.fromJson(json['localData'] as Map<String, dynamic>),
      remoteData:
          SyncData<T>.fromJson(json['remoteData'] as Map<String, dynamic>),
      strategy: ConflictResolutionStrategy.values.firstWhere(
        (e) => e.name == json['strategy'],
        orElse: () => ConflictResolutionStrategy.useLatestTimestamp,
      ),
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
      detectedAt:
          DateTime.fromMillisecondsSinceEpoch(json['detectedAt'] as int),
    );
  }

  /// Key that has conflicting data
  final String key;

  /// Local version of the data
  final SyncData<T> localData;

  /// Remote version of the data
  final SyncData<T> remoteData;

  /// Strategy to use for resolution
  final ConflictResolutionStrategy strategy;

  /// Custom resolver function for merge strategy
  final SyncData<T> Function(SyncData<T> local, SyncData<T> remote)?
      customResolver;

  /// Additional metadata about the conflict
  final Map<String, dynamic> metadata;

  /// When the conflict was detected
  final DateTime detectedAt;

  /// Resolves the conflict using the specified strategy
  ConflictResolution<T> resolve() {
    try {
      final resolvedData = _resolveData();
      return ConflictResolution<T>(
        conflict: this,
        resolvedData: resolvedData,
        result: ConflictResolutionResult.resolved,
        resolvedAt: DateTime.now(),
      );
    } catch (error) {
      return ConflictResolution<T>(
        conflict: this,
        result: ConflictResolutionResult.failed,
        error: error,
        resolvedAt: DateTime.now(),
      );
    }
  }

  SyncData<T> _resolveData() {
    switch (strategy) {
      case ConflictResolutionStrategy.useLocal:
        return localData;

      case ConflictResolutionStrategy.useRemote:
        return remoteData;

      case ConflictResolutionStrategy.useLatestTimestamp:
        return localData.timestamp >= remoteData.timestamp
            ? localData
            : remoteData;

      case ConflictResolutionStrategy.useHighestVersion:
        return localData.version >= remoteData.version ? localData : remoteData;

      case ConflictResolutionStrategy.merge:
        if (customResolver != null) {
          return customResolver!(localData, remoteData);
        }
        throw ArgumentError('Custom resolver required for merge strategy');

      case ConflictResolutionStrategy.manual:
        throw StateError('Manual resolution required');
    }
  }

  /// Creates a copy with updated values
  DataConflict<T> copyWith({
    String? key,
    SyncData<T>? localData,
    SyncData<T>? remoteData,
    ConflictResolutionStrategy? strategy,
    SyncData<T> Function(SyncData<T>, SyncData<T>)? customResolver,
    Map<String, dynamic>? metadata,
    DateTime? detectedAt,
  }) {
    return DataConflict<T>(
      key: key ?? this.key,
      localData: localData ?? this.localData,
      remoteData: remoteData ?? this.remoteData,
      strategy: strategy ?? this.strategy,
      customResolver: customResolver ?? this.customResolver,
      metadata: metadata ?? this.metadata,
      detectedAt: detectedAt ?? this.detectedAt,
    );
  }

  /// Converts to JSON for serialization
  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'localData': localData.toJson(),
      'remoteData': remoteData.toJson(),
      'strategy': strategy.name,
      'metadata': metadata,
      'detectedAt': detectedAt.millisecondsSinceEpoch,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DataConflict<T> &&
          runtimeType == other.runtimeType &&
          key == other.key &&
          localData == other.localData &&
          remoteData == other.remoteData &&
          strategy == other.strategy;

  @override
  int get hashCode =>
      key.hashCode ^
      localData.hashCode ^
      remoteData.hashCode ^
      strategy.hashCode;

  @override
  String toString() {
    return 'DataConflict<$T>(key: $key, strategy: $strategy, '
        'detectedAt: $detectedAt)';
  }
}

/// Result of conflict resolution
@immutable
class ConflictResolution<T> {
  /// Creates a new conflict resolution result
  ConflictResolution({
    required this.conflict,
    this.resolvedData,
    required this.result,
    this.error,
    DateTime? resolvedAt,
  }) : resolvedAt = resolvedAt ?? DateTime.now();

  /// Creates instance from JSON
  factory ConflictResolution.fromJson(Map<String, dynamic> json) {
    return ConflictResolution<T>(
      conflict:
          DataConflict<T>.fromJson(json['conflict'] as Map<String, dynamic>),
      resolvedData: json['resolvedData'] != null
          ? SyncData<T>.fromJson(json['resolvedData'] as Map<String, dynamic>)
          : null,
      result: ConflictResolutionResult.values.firstWhere(
        (e) => e.name == json['result'],
        orElse: () => ConflictResolutionResult.failed,
      ),
      error: json['error'],
      resolvedAt:
          DateTime.fromMillisecondsSinceEpoch(json['resolvedAt'] as int),
    );
  }

  /// Original conflict that was resolved
  final DataConflict<T> conflict;

  /// Data after resolution (if successful)
  final SyncData<T>? resolvedData;

  /// Result of the resolution attempt
  final ConflictResolutionResult result;

  /// Error information (if resolution failed)
  final Object? error;

  /// When the resolution was completed
  final DateTime resolvedAt;

  /// Whether the resolution was successful
  bool get isResolved => result == ConflictResolutionResult.resolved;

  /// Whether manual intervention is required
  bool get requiresManual => result == ConflictResolutionResult.requiresManual;

  /// Whether the resolution failed
  bool get hasFailed => result == ConflictResolutionResult.failed;

  /// Converts to JSON for serialization
  Map<String, dynamic> toJson() {
    return {
      'conflict': conflict.toJson(),
      'resolvedData': resolvedData?.toJson(),
      'result': result.name,
      'error': error?.toString(),
      'resolvedAt': resolvedAt.millisecondsSinceEpoch,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConflictResolution<T> &&
          runtimeType == other.runtimeType &&
          conflict == other.conflict &&
          resolvedData == other.resolvedData &&
          result == other.result;

  @override
  int get hashCode =>
      conflict.hashCode ^ resolvedData.hashCode ^ result.hashCode;

  @override
  String toString() {
    return 'ConflictResolution<$T>(result: $result, resolvedAt: $resolvedAt)';
  }
}
