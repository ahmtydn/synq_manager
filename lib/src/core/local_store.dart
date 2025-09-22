import 'package:synq_manager/src/domain/sync_entity.dart';

/// Abstract interface for local storage operations
/// Provides a generic way to store and retrieve entities locally
abstract class LocalStore<T extends SyncEntity> {
  /// Initialize the local store
  Future<void> initialize();

  /// Save an entity to local storage
  Future<void> save(T entity);

  /// Save multiple entities to local storage
  Future<void> saveAll(List<T> entities);

  /// Delete an entity by ID
  Future<void> delete(String id);

  /// Get an entity by ID
  Future<T?> get(String id);

  /// Get all entities
  Future<List<T>> getAll();

  /// Get entities that need to be synced (dirty entities)
  Future<List<T>> getDirtyEntities();

  /// Get entities that have been deleted locally
  Future<List<T>> getDeletedEntities();

  /// Watch for changes to all entities
  /// This stream should emit whenever entities are added, updated, or deleted
  Stream<List<T>> watchAll();

  /// Watch for changes to a specific entity
  Stream<T?> watch(String id);

  /// Clear all entities from local storage
  Future<void> clear();

  /// Get the count of entities
  Future<int> count();

  /// Get entities modified since a specific timestamp
  Future<List<T>> getModifiedSince(DateTime timestamp);

  /// Mark entities as synced (clear dirty flag)
  Future<void> markAsSynced(List<String> ids);

  /// Close the local store and free resources
  Future<void> close();
}
