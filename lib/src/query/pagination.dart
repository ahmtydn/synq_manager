import 'package:synq_manager/src/models/syncable_entity.dart';

class PaginationConfig {
  const PaginationConfig({
    this.pageSize = 50,
    this.currentPage,
    this.cursor,
  });
  final int pageSize;
  final int? currentPage;
  final String? cursor;
}

class PaginatedResult<T extends SyncableEntity> {
  const PaginatedResult({
    required this.items,
    required this.totalCount,
    required this.currentPage,
    required this.totalPages,
    required this.hasMore,
    this.nextCursor,
  });
  final List<T> items;
  final int totalCount;
  final int currentPage;
  final int totalPages;
  final String? nextCursor;
  final bool hasMore;
}
