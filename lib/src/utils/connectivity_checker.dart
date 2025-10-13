import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Wrapper around connectivity_plus to make it mockable.
class ConnectivityChecker {
  /// Creates a connectivity checker.
  ConnectivityChecker({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  /// Checks if device is connected to the internet.
  Future<bool> get isConnected async {
    final result = await _connectivity.checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  /// Stream of connectivity status changes.
  Stream<bool> get onStatusChange {
    return _connectivity.onConnectivityChanged.map(
      (event) => !event.contains(ConnectivityResult.none),
    );
  }
}
