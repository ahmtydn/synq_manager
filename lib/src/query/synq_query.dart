/// Defines a query for filtering and sorting items from a data source.
///
/// This is used with `watchQuery` and other query methods to retrieve a subset
/// of data. It's recommended to build queries using the [SynqQueryBuilder] for
/// a more expressive and type-safe API.
///
/// Example:
/// ```dart
/// final query = SynqQueryBuilder<Task>()
///   .where('completed', isEqualTo: false)
///   .where('priority', isGreaterThan: 2)
///   .or([
///     Filter('status', FilterOperator.equals, 'urgent'),
///     Filter('dueDate', FilterOperator.lessThan, DateTime.now()),
///   ])
///   .whereNull('deletedAt')
///   .orderBy('createdAt', descending: true)
///   .limit(10)
///   .build();
/// ```
class SynqQuery {
  /// Creates a query with a list of filters and sorting criteria.
  const SynqQuery({
    this.filters = const [],
    this.sorting = const [],
    this.limit,
    this.offset,
    this.logicalOperator = LogicalOperator.and,
  });

  /// A list of filter conditions to apply.
  final List<FilterCondition> filters;

  /// A list of sorting descriptors to apply.
  final List<SortDescriptor> sorting;

  /// The maximum number of items to return.
  final int? limit;

  /// The number of items to skip from the beginning of the result set.
  final int? offset;

  /// The logical operator to combine filters (AND/OR).
  final LogicalOperator logicalOperator;

  /// Creates a copy of this query with updated fields.
  SynqQuery copyWith({
    List<FilterCondition>? filters,
    List<SortDescriptor>? sorting,
    int? limit,
    int? offset,
    LogicalOperator? logicalOperator,
  }) {
    return SynqQuery(
      filters: filters ?? this.filters,
      sorting: sorting ?? this.sorting,
      limit: limit ?? this.limit,
      offset: offset ?? this.offset,
      logicalOperator: logicalOperator ?? this.logicalOperator,
    );
  }
}

/// Represents a filter condition (can be simple or composite).
abstract class FilterCondition {
  /// Creates a new instance of [FilterCondition].
  const FilterCondition();
}

/// Represents a single filter condition in a [SynqQuery].
class Filter extends FilterCondition {
  /// Creates a filter condition.
  const Filter(this.field, this.operator, this.value);

  /// The field to filter on. Supports dot notation for nested fields.
  /// Example: 'user.profile.name'
  final String field;

  /// The comparison operator.
  final FilterOperator operator;

  /// The value to compare against.
  final dynamic value;

  @override
  String toString() => 'Filter($field ${operator.name} $value)';
}

/// Represents a composite filter with AND/OR logic.
class CompositeFilter extends FilterCondition {
  /// Creates a composite filter.
  const CompositeFilter(this.conditions, this.operator);

  /// The list of conditions to combine.
  final List<FilterCondition> conditions;

  /// The logical operator to combine conditions.
  final LogicalOperator operator;

  @override
  String toString() => 'CompositeFilter(${operator.name}: $conditions)';
}

/// Defines logical operators for combining filters.
enum LogicalOperator {
  /// All conditions must be true (default).
  and,

  /// At least one condition must be true.
  or,
}

/// Defines the available comparison operators for filters.
enum FilterOperator {
  /// Equal to
  equals,

  /// Not equal to
  notEquals,

  /// Greater than
  greaterThan,

  /// Greater than or equal to
  greaterThanOrEqual,

  /// Less than
  lessThan,

  /// Less than or equal to
  lessThanOrEqual,

  /// Contains the substring (case-sensitive).
  contains,

  /// Contains the substring (case-insensitive).
  containsIgnoreCase,

  /// Starts with the prefix.
  startsWith,

  /// Ends with the suffix.
  endsWith,

  /// Value is in the provided list.
  isIn,

  /// Value is not in the provided list.
  isNotIn,

  /// Value is null.
  isNull,

  /// Value is not null.
  isNotNull,

  /// Array contains the value.
  arrayContains,

  /// Array contains any of the values.
  arrayContainsAny,

  /// Matches a regular expression pattern.
  matches,

  /// For geographical queries - within distance.
  withinDistance,

  /// Between two values (inclusive).
  between,
}

/// Defines sorting for a field in a [SynqQuery].
class SortDescriptor {
  /// Creates a sort descriptor.
  const SortDescriptor(
    this.field, {
    this.descending = false,
    this.nullSortOrder = NullSortOrder.last,
  });

  /// The field to sort by. Supports dot notation for nested fields.
  final String field;

  /// Whether to sort in descending order.
  final bool descending;

  /// How to handle null values in sorting.
  final NullSortOrder nullSortOrder;

  @override
  String toString() =>
      'SortDescriptor($field, ${descending ? "DESC" : "ASC"}, nulls: ${nullSortOrder.name})';
}

/// Defines how null values are sorted.
enum NullSortOrder {
  /// Null values appear first.
  first,

  /// Null values appear last (default).
  last,
}

/// A fluent builder for creating [SynqQuery] objects with type-safe field access.
class SynqQueryBuilder<T> {
  final List<FilterCondition> _filters = [];
  final List<SortDescriptor> _sorting = [];
  int? _limit;
  int? _offset;

  /// The logical operator for combining filters at the root level.
  LogicalOperator logicalOperator = LogicalOperator.and;

  /// Adds a filter condition to the query.
  ///
  /// Supports dot notation for nested fields: 'user.profile.name'
  ///
  /// Example: `.where('age', isGreaterThan: 18)`
  void where(
    String field, {
    dynamic isEqualTo,
    dynamic isNotEqualTo,
    dynamic isGreaterThan,
    dynamic isGreaterThanOrEqualTo,
    dynamic isLessThan,
    dynamic isLessThanOrEqualTo,
    String? contains,
    String? containsIgnoreCase,
    String? startsWith,
    String? endsWith,
    List<dynamic>? isIn,
    List<dynamic>? isNotIn,
    dynamic arrayContains,
    List<dynamic>? arrayContainsAny,
    String? matches,
    List<dynamic>? between,
  }) {
    if (isEqualTo != null) {
      _filters.add(Filter(field, FilterOperator.equals, isEqualTo));
    }
    if (isNotEqualTo != null) {
      _filters.add(Filter(field, FilterOperator.notEquals, isNotEqualTo));
    }
    if (isGreaterThan != null) {
      _filters.add(Filter(field, FilterOperator.greaterThan, isGreaterThan));
    }
    if (isGreaterThanOrEqualTo != null) {
      _filters.add(
        Filter(
          field,
          FilterOperator.greaterThanOrEqual,
          isGreaterThanOrEqualTo,
        ),
      );
    }
    if (isLessThan != null) {
      _filters.add(Filter(field, FilterOperator.lessThan, isLessThan));
    }
    if (isLessThanOrEqualTo != null) {
      _filters.add(
        Filter(field, FilterOperator.lessThanOrEqual, isLessThanOrEqualTo),
      );
    }
    if (contains != null) {
      _filters.add(Filter(field, FilterOperator.contains, contains));
    }
    if (containsIgnoreCase != null) {
      _filters.add(
        Filter(field, FilterOperator.containsIgnoreCase, containsIgnoreCase),
      );
    }
    if (startsWith != null) {
      _filters.add(Filter(field, FilterOperator.startsWith, startsWith));
    }
    if (endsWith != null) {
      _filters.add(Filter(field, FilterOperator.endsWith, endsWith));
    }
    if (isIn != null) {
      _filters.add(Filter(field, FilterOperator.isIn, isIn));
    }
    if (isNotIn != null) {
      _filters.add(Filter(field, FilterOperator.isNotIn, isNotIn));
    }
    if (arrayContains != null) {
      _filters.add(Filter(field, FilterOperator.arrayContains, arrayContains));
    }
    if (arrayContainsAny != null) {
      _filters.add(
        Filter(field, FilterOperator.arrayContainsAny, arrayContainsAny),
      );
    }
    if (matches != null) {
      _filters.add(Filter(field, FilterOperator.matches, matches));
    }
    if (between != null) {
      assert(between.length == 2, 'between requires exactly 2 values');
      _filters.add(Filter(field, FilterOperator.between, between));
    }
  }

  /// Adds a null check filter.
  void whereNull(String field) {
    _filters.add(Filter(field, FilterOperator.isNull, null));
  }

  /// Adds a not-null check filter.
  void whereNotNull(String field) {
    _filters.add(Filter(field, FilterOperator.isNotNull, null));
  }

  /// Adds a geographical distance filter.
  ///
  /// [center] should be a map with 'latitude' and 'longitude' keys.
  /// [radiusInMeters] is the maximum distance from the center.
  void whereWithinDistance(
    String field,
    Map<String, double> center,
    double radiusInMeters,
  ) {
    _filters.add(
      Filter(
        field,
        FilterOperator.withinDistance,
        {'center': center, 'radius': radiusInMeters},
      ),
    );
  }

  /// Adds a composite OR filter.
  ///
  /// Example:
  /// ```dart
  /// .or([
  ///   Filter('status', FilterOperator.equals, 'urgent'),
  ///   Filter('priority', FilterOperator.greaterThan, 5),
  /// ])
  /// ```
  void or(List<FilterCondition> conditions) {
    _filters.add(CompositeFilter(conditions, LogicalOperator.or));
  }

  /// Adds a composite AND filter (explicit grouping).
  ///
  /// Useful when you need explicit grouping within OR conditions.
  void and(List<FilterCondition> conditions) {
    _filters.add(CompositeFilter(conditions, LogicalOperator.and));
  }

  /// Adds a raw filter condition.
  ///
  /// Useful for custom filter types or when migrating from other query systems.
  void whereRaw(FilterCondition condition) {
    _filters.add(condition);
  }

  /// Adds a sorting condition to the query.
  ///
  /// Supports dot notation for nested fields: 'user.profile.createdAt'
  void orderBy(
    String field, {
    bool descending = false,
    NullSortOrder nullSortOrder = NullSortOrder.last,
  }) {
    _sorting.add(
      SortDescriptor(
        field,
        descending: descending,
        nullSortOrder: nullSortOrder,
      ),
    );
  }

  /// Sets the maximum number of items to return.
  void limit(int count) {
    assert(count > 0, 'limit must be positive');
    _limit = count;
  }

  /// Sets the number of items to skip.
  void offset(int count) {
    assert(count >= 0, 'offset must be non-negative');
    _offset = count;
  }

  /// Clears all filters.
  void clearFilters() {
    _filters.clear();
  }

  /// Clears all sorting.
  void clearSorting() {
    _sorting.clear();
  }

  /// Resets the entire query.
  void reset() {
    _filters.clear();
    _sorting.clear();
    _limit = null;
    _offset = null;
    logicalOperator = LogicalOperator.and;
  }

  /// Builds and returns the final [SynqQuery] object.
  SynqQuery build() {
    return SynqQuery(
      filters: List.unmodifiable(_filters),
      sorting: List.unmodifiable(_sorting),
      limit: _limit,
      offset: _offset,
      logicalOperator: logicalOperator,
    );
  }
}

/// Extension methods for creating type-safe queries with custom fields.
///
/// Example usage:
/// ```dart
/// class TaskFields {
///   static const title = 'title';
///   static const completed = 'completed';
///   static const priority = 'priority';
///   static const assignee = 'assignee.name';
/// }
///
/// final query = SynqQueryBuilder<Task>()
///   .where(TaskFields.completed, isEqualTo: false)
///   .where(TaskFields.priority, isGreaterThan: 2)
///   .orderBy(TaskFields.title)
///   .build();
/// ```
extension QueryExtensions<T> on SynqQueryBuilder<T> {
  /// Creates a paginated query with cursor-based pagination.
  void paginate({
    required int pageSize,
    int page = 1,
  }) {
    limit(pageSize);
    offset((page - 1) * pageSize);
  }
}

/// Helper class for building complex queries with custom field definitions.
///
/// Example:
/// ```dart
/// class TaskQuery extends CustomFieldQuery<Task> {
///   static const title = 'title';
///   static const completed = 'completed';
///   static const tags = 'tags';
///
///   TaskQuery whereCompleted(bool value) {
///     return this..where(completed, isEqualTo: value);
///   }
///
///   TaskQuery whereHasTag(String tag) {
///     return this..where(tags, arrayContains: tag);
///   }
/// }
/// ```
abstract class CustomFieldQuery<T> extends SynqQueryBuilder<T> {
  /// Creates a new instance of [CustomFieldQuery].
  CustomFieldQuery() : super();
}
