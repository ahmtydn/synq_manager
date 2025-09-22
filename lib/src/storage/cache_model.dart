import 'package:synq_manager/src/domain/sync_entity.dart';

/// Interface for cache model, similar to your existing CacheModel
mixin CacheModel {
  /// Get the unique identifier of the cache model
  String get id;

  /// Convert the cache model from JSON
  CacheModel fromJson(dynamic json);

  /// Convert the cache model to JSON
  Map<String, dynamic> toJson();
}

/// Base class for sync entities that can be cached
/// Combines SyncEntity with CacheModel for local storage
abstract class SyncCacheModel extends SyncEntity with CacheModel {
  SyncCacheModel();

  @override
  SyncCacheModel fromJson(dynamic json);

  @override
  Map<String, dynamic> toJson();

  /// Create a copy with updated sync metadata
  @override
  SyncCacheModel copyWithSyncData({
    DateTime? updatedAt,
    int? version,
    bool? isDeleted,
    bool? isDirty,
    String? guestId,
  });
}
