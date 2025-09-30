import 'package:meta/meta.dart';
import 'package:synq_manager/synq_manager.dart';

/// Types of conflicts that can occur during synchronization
enum ConflictType {
  /// Different user accounts detected
  userAccount,

  /// Data conflicts between local and remote versions
  dataConflict,

  /// Version mismatch conflicts
  versionMismatch,
}

/// Actions user can take for conflicts
enum ConflictAction {
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

  /// For user account conflicts: overwrite local data with cloud data
  useCloudData,

  /// For user account conflicts: keep local data and cancel sync
  keepLocalData,

  /// Cancel the operation entirely
  cancel,
}

/// Context information for conflict resolution
class ConflictContext<T> {
  const ConflictContext({
    required this.type,
    required this.key,
    this.localUserId,
    this.cloudUserId,
    this.localData,
    this.remoteData,
    this.hasLocalData = false,
    this.hasCloudData = false,
    this.metadata = const {},
  });

  /// Type of conflict
  final ConflictType type;

  /// Key or identifier for the conflicted item
  final String key;

  /// Local user ID (for user account conflicts)
  final String? localUserId;

  /// Cloud user ID (for user account conflicts)
  final String? cloudUserId;

  /// Local data (for data conflicts)
  final SyncData<T>? localData;

  /// Remote data (for data conflicts)
  final SyncData<T>? remoteData;

  /// Whether local data exists
  final bool hasLocalData;

  /// Whether cloud data exists
  final bool hasCloudData;

  /// Additional metadata
  final Map<String, dynamic> metadata;

  /// Whether this is a user account conflict
  bool get isUserAccountConflict => type == ConflictType.userAccount;

  /// Whether this is a data conflict
  bool get isDataConflict => type == ConflictType.dataConflict;

  /// Whether this is a version mismatch conflict
  bool get isVersionMismatch => type == ConflictType.versionMismatch;
}

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
  factory DataConflict.fromJson(
    Map<String, dynamic> json, {
    FromJsonFunction<T>? fromJson,
  }) {
    return DataConflict<T>(
      key: json['key'] as String,
      localData: SyncData<T>.fromJson(
        json['localData'] as Map<String, dynamic>,
        fromJson: fromJson,
      ),
      remoteData: SyncData<T>.fromJson(
        json['remoteData'] as Map<String, dynamic>,
        fromJson: fromJson,
      ),
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
  Map<String, dynamic> toJson({ToJsonFunction<T>? toJson}) {
    return {
      'key': key,
      'localData': localData.toJson(toJson: toJson),
      'remoteData': remoteData.toJson(toJson: toJson),
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
  factory ConflictResolution.fromJson(
    Map<String, dynamic> json, {
    FromJsonFunction<T>? fromJson,
  }) {
    return ConflictResolution<T>(
      conflict: DataConflict<T>.fromJson(
        json['conflict'] as Map<String, dynamic>,
        fromJson: fromJson,
      ),
      resolvedData: json['resolvedData'] != null
          ? SyncData<T>.fromJson(
              json['resolvedData'] as Map<String, dynamic>,
              fromJson: fromJson,
            )
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
  Map<String, dynamic> toJson({ToJsonFunction<T>? toJson}) {
    return {
      'conflict': conflict.toJson(toJson: toJson),
      'resolvedData': resolvedData?.toJson(toJson: toJson),
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
