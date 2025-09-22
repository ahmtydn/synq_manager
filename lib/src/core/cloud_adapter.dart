import 'package:synq_manager/src/domain/sync_entity.dart';

/// Abstract interface for cloud backend adapters
/// Provides a standardized way to sync with different cloud services
abstract class CloudAdapter<T extends SyncEntity> {
  /// Initialize the cloud adapter
  Future<void> initialize();

  /// Push a newly created entity to the cloud
  Future<T> pushCreate(T entity);

  /// Push an updated entity to the cloud
  Future<T> pushUpdate(T entity);

  /// Push a delete operation to the cloud
  Future<void> pushDelete(String id, {int? version});

  /// Fetch all entities from the cloud
  Future<List<T>> fetchAll();

  /// Fetch entities modified since a specific timestamp
  Future<List<T>> fetchSince(DateTime since);

  /// Fetch a specific entity by ID
  Future<T?> fetchById(String id);

  /// Batch push multiple entities
  Future<List<T>> pushBatch(List<T> entities);

  /// Check if the adapter supports batch operations
  bool get supportsBatchOperations => false;

  /// Check if the adapter supports real-time updates
  bool get supportsRealTimeUpdates => false;

  /// Subscribe to real-time updates (if supported)
  Stream<T>? subscribeToUpdates() => null;

  /// Get the adapter name for logging
  String get adapterName;

  /// Test connectivity to the cloud service
  Future<bool> testConnection();

  /// Clean up resources
  Future<void> dispose();
}
