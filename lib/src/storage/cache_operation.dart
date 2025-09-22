import 'package:synq_manager/src/storage/cache_model.dart';

/// The CacheOperation interface, following your existing pattern
abstract class CacheOperation<T extends CacheModel> {
  /// Add an item to the cache
  void add(T item);

  /// Add all items to the cache
  void addAll(List<T> items);

  /// Remove an item from the cache by ID
  void remove(String id);

  /// Clear all cache
  void clear();

  /// Get all items from the cache
  List<T> getAll();

  /// Get an item from the cache by ID
  T? get(String id);

  /// Watch for changes to all items
  Stream<List<T>> watchAll();

  /// Watch for changes to a specific item
  Stream<T?> watch(String id);

  /// Close the cache operation
  void close();
}
