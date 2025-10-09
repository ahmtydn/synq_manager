import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Wrapper around connectivity_plus to make it mockable.
class ConnectivityChecker {
  ConnectivityChecker({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  Future<bool> get isConnected async {
    final result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }

  Stream<bool> get onStatusChange {
    return _connectivity.onConnectivityChanged
        .map((event) => event != ConnectivityResult.none);
  }
}
