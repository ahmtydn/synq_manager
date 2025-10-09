import 'package:synq_manager/src/models/syncable_entity.dart';

/// Configuration for database indexes on syncable entities.
abstract class IndexConfig<T extends SyncableEntity> {
  /// List of fields that should be indexed.
  List<String Function(T)> get indexedFields;

  /// List of composite indexes (multi-field indexes).
  List<List<String Function(T)>> get compositeIndexes => const [];
}
