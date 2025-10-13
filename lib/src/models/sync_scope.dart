/// Defines the order of operations during a synchronization cycle.
enum SyncDirection {
  /// Push local changes first, then pull remote changes. This is the default.
  pushThenPull,

  /// Pull remote changes first, then push local changes.
  pullThenPush,

  /// Only push local changes to the remote.
  pushOnly,

  /// Only pull remote changes to local.
  pullOnly,
}

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
