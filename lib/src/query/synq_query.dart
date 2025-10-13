/// Defines a query for filtering items from a local data source.
///
/// This is used with `watchQuery` to reactively observe a subset of data.
class SynqQuery {
  /// Creates a query with a map of filter criteria.
  ///
  /// The interpretation of these filters is up to the `LocalAdapter`
  /// implementation.
  const SynqQuery(this.filters);

  /// A map of filter keys to their corresponding values.
  final Map<String, dynamic> filters;
}
