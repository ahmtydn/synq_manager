/// Defines a scope or filter for a synchronization operation.
///
/// This allows for partial synchronization of data, such as fetching only
/// items modified within a certain date range or matching specific criteria.
class SyncScope {
  /// Creates a sync scope with a map of filter criteria.
  ///
  /// The interpretation of these filters is up to the `RemoteAdapter`
  /// implementation.
  const SyncScope(this.filters);

  /// A map of filter keys to their corresponding values.
  /// For example: `{'status': 'active', 'minDate': '2023-01-01'}`.
  final Map<String, dynamic> filters;
}
