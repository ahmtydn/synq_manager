import 'package:synq_manager/src/models/syncable_entity.dart';

/// Configuration for paginated queries.
class PaginationConfig {
  /// Creates pagination configuration.
  const PaginationConfig({
    this.pageSize = 50,
    this.currentPage,
    this.cursor,
  });

  /// Number of items per page.
  final int pageSize;

  /// Current page number (for offset-based pagination).
  final int? currentPage;

  /// Cursor for cursor-based pagination.
  final String? cursor;
}

/// Result of a paginated query.
class PaginatedResult<T extends SyncableEntity> {
  /// Creates a paginated result.
  const PaginatedResult({
    required this.items,
    required this.totalCount,
    required this.currentPage,
    required this.totalPages,
    required this.hasMore,
    this.nextCursor,
  });

  /// Items in the current page.
  final List<T> items;

  /// Total number of items across all pages.
  final int totalCount;

  /// Current page number.
  final int currentPage;

  /// Total number of pages.
  final int totalPages;

  /// Cursor for the next page (cursor-based pagination).
  final String? nextCursor;

  /// Whether there are more items available.
  final bool hasMore;
}
