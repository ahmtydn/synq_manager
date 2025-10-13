import 'dart:async';
import 'dart:math';
import 'package:synq_manager/synq_manager.dart';

/// In-memory implementation of LocalAdapter for demonstration purposes.
/// In production, use Hive, SQLite, or other persistent storage.
class MemoryLocalAdapter<T extends SyncableEntity> implements LocalAdapter<T> {
  MemoryLocalAdapter({required this.fromJson});
  final Map<String, Map<String, T>> _storage = {};
  final Map<String, List<SyncOperation<T>>> _pendingOps = {};
  final Map<String, SyncMetadata> _metadata = {};
  final _changeController = StreamController<ChangeDetail<T>>.broadcast();
  int _schemaVersion = 0;

  final T Function(Map<String, dynamic>) fromJson;

  @override
  String get name => 'MemoryLocalAdapter';

  @override
  Future<void> initialize() async {
    // No initialization needed for in-memory storage
  }

  @override
  Future<List<T>> getAll({String? userId}) async {
    if (userId != null) {
      return _storage[userId]?.values.toList() ?? [];
    }
    return _storage.values.expand((map) => map.values).toList();
  }

  @override
  Future<T?> getById(String id, String userId) async {
    return _storage[userId]?[id];
  }

  @override
  Future<Map<String, T>> getByIds(List<String> ids, String userId) async {
    final userStorage = _storage[userId];
    if (userStorage == null) return {};

    final results = <String, T>{};
    for (final id in ids) {
      if (userStorage.containsKey(id)) results[id] = userStorage[id]!;
    }
    return results;
  }

  @override
  Future<void> push(T item, String userId) async {
    _storage.putIfAbsent(userId, () => {});
    _storage[userId]![item.id] = item;
    _changeController.add(
      ChangeDetail(
        entityId: item.id,
        userId: userId,
        type: SyncOperationType.update,
        timestamp: DateTime.now(),
        data: item,
      ),
    );
  }

  @override
  Future<T> patch(String id, String userId, Map<String, dynamic> delta) async {
    final existing = _storage[userId]?[id];
    if (existing == null) {
      throw Exception('Entity with id $id not found for user $userId.');
    }

    final json = existing.toMap()..addAll(delta);
    final patchedItem = fromJson(json);
    _storage.putIfAbsent(userId, () => {})[id] = patchedItem;

    _changeController.add(
      ChangeDetail(
        entityId: id,
        userId: userId,
        type: SyncOperationType.update,
        timestamp: DateTime.now(),
        data: patchedItem,
      ),
    );
    return patchedItem;
  }

  @override
  Future<bool> delete(String id, String userId) async {
    final item = _storage[userId]?.remove(id);
    if (item != null) {
      _changeController.add(
        ChangeDetail(
          entityId: id,
          userId: userId,
          type: SyncOperationType.delete,
          timestamp: DateTime.now(),
          data: item,
        ),
      );
      return true;
    }
    return false;
  }

  @override
  Future<List<SyncOperation<T>>> getPendingOperations(String userId) async {
    return _pendingOps[userId] ?? [];
  }

  @override
  Future<void> addPendingOperation(
    String userId,
    SyncOperation<T> operation,
  ) async {
    _pendingOps.putIfAbsent(userId, () => []);
    _pendingOps[userId]!.add(operation);
  }

  @override
  Future<void> markAsSynced(String operationId) async {
    for (final ops in _pendingOps.values) {
      ops.removeWhere((op) => op.id == operationId);
    }
  }

  @override
  Future<void> clearUserData(String userId) async {
    _storage.remove(userId);
    _pendingOps.remove(userId);
    _metadata.remove(userId);
  }

  @override
  Future<SyncMetadata?> getSyncMetadata(String userId) async {
    return _metadata[userId];
  }

  @override
  Future<void> updateSyncMetadata(
    SyncMetadata metadata,
    String userId,
  ) async {
    _metadata[userId] = metadata;
  }

  @override
  Future<void> dispose() async {
    _storage.clear();
    _pendingOps.clear();
    _metadata.clear();
    await _changeController.close();
  }

  @override
  Stream<ChangeDetail<T>>? changeStream() {
    return _changeController.stream;
  }

  @override
  Stream<int>? schemaVersionStream() {
    return null;
  }

  @override
  Stream<List<T>>? watchAll({String? userId}) {
    final stream = changeStream();
    if (stream == null) return null;

    final initialDataStream = Stream.fromFuture(getAll(userId: userId));
    final updateStream = stream
        .where((event) => userId == null || event.userId == userId)
        .asyncMap((_) => getAll(userId: userId));

    return Rx.concat([initialDataStream, updateStream]);
  }

  @override
  Stream<T?>? watchById(String id, String userId) {
    final stream = changeStream();
    if (stream == null) return null;

    final initialDataStream = Stream.fromFuture(getById(id, userId));
    final updateStream = stream
        .where((event) => event.entityId == id && event.userId == userId)
        .asyncMap((_) => getById(id, userId));

    return ConcatStream([initialDataStream, updateStream]);
  }

  @override
  Future<PaginatedResult<T>> getAllPaginated(
    PaginationConfig config, {
    String? userId,
  }) async {
    final allItems = await getAll(userId: userId);
    final totalCount = allItems.length;
    final totalPages = (totalCount / config.pageSize).ceil();
    final currentPage = config.currentPage ?? 1;

    final startIndex = (currentPage - 1) * config.pageSize;
    if (startIndex >= totalCount) {
      return PaginatedResult(
        items: [],
        totalCount: totalCount,
        currentPage: currentPage,
        totalPages: totalPages,
        hasMore: false,
      );
    }

    final endIndex = (startIndex + config.pageSize > totalCount)
        ? totalCount
        : startIndex + config.pageSize;
    final pageItems = allItems.sublist(startIndex, endIndex);

    return PaginatedResult(
      items: pageItems,
      totalCount: totalCount,
      currentPage: currentPage,
      totalPages: totalPages,
      hasMore: currentPage < totalPages,
    );
  }

  @override
  Stream<PaginatedResult<T>>? watchAllPaginated(
    PaginationConfig config, {
    String? userId,
  }) {
    final stream = changeStream();
    if (stream == null) return null;

    final initialDataStream =
        Stream.fromFuture(getAllPaginated(config, userId: userId));
    final updateStream = stream
        .where((event) => userId == null || event.userId == userId)
        .asyncMap((_) => getAllPaginated(config, userId: userId));

    return Rx.concat([initialDataStream, updateStream]);
  }

  @override
  Stream<List<T>>? watchQuery(SynqQuery query, {String? userId}) {
    final stream = changeStream();
    if (stream == null) return null;

    // Helper to apply query
    Future<List<T>> getFiltered() async {
      return applyQuery(await getAll(userId: userId), query);
    }

    final initialDataStream = Stream.fromFuture(getFiltered());
    final updateStream = stream.asyncMap((_) => getFiltered());

    return Rx.concat([initialDataStream, updateStream]);
  }

  @override
  Stream<int>? watchCount({SynqQuery? query, String? userId}) {
    final sourceStream = query != null
        ? watchQuery(query, userId: userId)
        : watchAll(userId: userId);

    return sourceStream?.map((list) => list.length);
  }

  @override
  Stream<T?>? watchFirst({SynqQuery? query, String? userId}) {
    final sourceStream = query != null
        ? watchQuery(query, userId: userId)
        : watchAll(userId: userId);

    return sourceStream?.map((list) => list.isNotEmpty ? list.first : null);
  }

  @override
  Future<R> transaction<R>(Future<R> Function() action) async {
    // This is a simplified mock transaction. It doesn't provide true rollback
    // for the in-memory map, but it allows testing the flow.
    final backupStorage = _storage.map<String, Map<String, T>>(
      (key, value) => MapEntry(key, Map<String, T>.from(value)),
    );
    try {
      return await action();
    } catch (e) {
      // Restore from backup on error
      _storage
        ..clear()
        ..addAll(backupStorage);
      rethrow;
    }
  }

  @override
  Future<int> getStoredSchemaVersion() async {
    return _schemaVersion;
  }

  @override
  Future<void> setStoredSchemaVersion(int version) async {
    _schemaVersion = version;
  }

  @override
  Future<List<Map<String, dynamic>>> getAllRawData({String? userId}) async {
    final items = await getAll(userId: userId);
    return items.map((item) => item.toMap()).toList();
  }

  @override
  Future<void> overwriteAllRawData(
    List<Map<String, dynamic>> data, {
    String? userId,
  }) async {
    if (userId != null) {
      _storage[userId]?.clear();
    } else {
      _storage.clear();
    }

    for (final rawItem in data) {
      final item = fromJson(rawItem);
      _storage.putIfAbsent(item.userId, () => {})[item.id] = item;
    }
  }

  // A helper function to apply query filters and sorting to a list of items.
  List<T> applyQuery(List<T> items, SynqQuery query) {
    var filteredItems = items.where((item) {
      final json = item.toMap();
      if (query.logicalOperator == LogicalOperator.and) {
        return query.filters.every((filter) => _matches(json, filter));
      } else {
        return query.filters.any((filter) => _matches(json, filter));
      }
    }).toList();

    if (query.sorting.isNotEmpty) {
      filteredItems.sort((a, b) {
        for (final sort in query.sorting) {
          final valA = a.toMap()[sort.field];
          final valB = b.toMap()[sort.field];

          if (valA == null && valB == null) continue;
          if (valA == null) {
            return sort.nullSortOrder == NullSortOrder.first ? -1 : 1;
          }
          if (valB == null) {
            return sort.nullSortOrder == NullSortOrder.first ? 1 : -1;
          }

          if (valA is Comparable && valB is Comparable) {
            final comparison = valA.compareTo(valB);
            if (comparison != 0) {
              return sort.descending ? -comparison : comparison;
            }
          }
        }
        return 0;
      });
    }

    if (query.offset != null) {
      filteredItems = filteredItems.skip(query.offset!).toList();
    }
    if (query.limit != null) {
      filteredItems = filteredItems.take(query.limit!).toList();
    }

    return filteredItems;
  }

  bool _matches(Map<String, dynamic> json, FilterCondition condition) {
    if (condition is Filter) {
      final value = json[condition.field];
      if (value == null && condition.operator != FilterOperator.isNull) {
        return false;
      }

      switch (condition.operator) {
        case FilterOperator.equals:
          return value == condition.value;
        case FilterOperator.notEquals:
          return value != condition.value;
        case FilterOperator.greaterThan:
          return value is Comparable && value.compareTo(condition.value) > 0;
        case FilterOperator.greaterThanOrEqual:
          return value is Comparable && value.compareTo(condition.value) >= 0;
        case FilterOperator.lessThan:
          return value is Comparable && value.compareTo(condition.value) < 0;
        case FilterOperator.lessThanOrEqual:
          return value is Comparable && value.compareTo(condition.value) <= 0;
        case FilterOperator.contains:
          return value is String && value.contains(condition.value as String);
        case FilterOperator.isIn:
          return condition.value is List &&
              (condition.value as List).contains(value);
        case FilterOperator.isNotIn:
          return condition.value is List &&
              !(condition.value as List).contains(value);
        case FilterOperator.isNull:
          return value == null;
        case FilterOperator.isNotNull:
          return value != null;
        case FilterOperator.containsIgnoreCase:
          return value is String &&
              condition.value is String &&
              value
                  .toLowerCase()
                  .contains((condition.value as String).toLowerCase());
        case FilterOperator.startsWith:
          return value is String &&
              condition.value is String &&
              value.startsWith(condition.value as String);
        case FilterOperator.endsWith:
          return value is String &&
              condition.value is String &&
              value.endsWith(condition.value as String);
        case FilterOperator.arrayContains:
          return value is List && value.contains(condition.value);
        case FilterOperator.arrayContainsAny:
          if (value is! List || condition.value is! List) return false;
          final valueSet = value.toSet();
          return (condition.value as List).any(valueSet.contains);
        case FilterOperator.matches:
          return value is String &&
              condition.value is String &&
              RegExp(condition.value as String).hasMatch(value);
        case FilterOperator.withinDistance:
          if (value is! Map || condition.value is! Map) return false;
          final point = value as Map<String, dynamic>;
          final params = condition.value as Map<String, dynamic>;
          final center = params['center'] as Map<String, double>?;
          final radius = params['radius'] as double?;
          if (point['latitude'] == null ||
              point['longitude'] == null ||
              center == null ||
              radius == null) {
            return false;
          }
          final distance = _haversineDistance(
            point['latitude'] as double,
            point['longitude'] as double,
            center['latitude']!,
            center['longitude']!,
          );
          return distance <= radius;
        case FilterOperator.between:
          if (value is! Comparable || condition.value is! List) return false;
          final bounds = condition.value as List;
          if (bounds.length != 2) return false;
          return value.compareTo(bounds[0]) >= 0 &&
              value.compareTo(bounds[1]) <= 0;
      }
    } else if (condition is CompositeFilter) {
      if (condition.operator == LogicalOperator.and) {
        return condition.conditions.every((c) => _matches(json, c));
      } else {
        return condition.conditions.any((c) => _matches(json, c));
      }
    }
    return false;
  }

  double _haversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const r = 6371e3; // Earth's radius in metres
    final phi1 = lat1 * pi / 180;
    final phi2 = lat2 * pi / 180;
    final deltaPhi = (lat2 - lat1) * pi / 180;
    final deltaLambda = (lon2 - lon1) * pi / 180;

    final a = sin(deltaPhi / 2) * sin(deltaPhi / 2) +
        cos(phi1) * cos(phi2) * sin(deltaLambda / 2) * sin(deltaLambda / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }
}
