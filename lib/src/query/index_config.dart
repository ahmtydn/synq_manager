import 'package:synq_manager/src/models/syncable_entity.dart';

abstract class IndexConfig<T extends SyncableEntity> {
  List<String Function(T)> get indexedFields;

  List<List<String Function(T)>> get compositeIndexes => const [];
}
