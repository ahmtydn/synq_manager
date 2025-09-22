import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Network connectivity checker
class NetworkChecker {
  NetworkChecker() : _connectivity = Connectivity();

  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  final StreamController<bool> _connectivityController =
      StreamController<bool>.broadcast();

  bool _isConnected = false;

  /// Initialize the network checker
  Future<void> initialize() async {
    _isConnected = await isConnected;

    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final connected = _hasActiveConnection(results);
      if (connected != _isConnected) {
        _isConnected = connected;
        _connectivityController.add(_isConnected);
      }
    });
  }

  /// Check if device is currently connected
  Future<bool> get isConnected async {
    final results = await _connectivity.checkConnectivity();
    return _hasActiveConnection(results);
  }

  /// Stream of connectivity changes
  Stream<bool> get connectivityStream => _connectivityController.stream;

  /// Check if any of the connectivity results indicate an active connection
  bool _hasActiveConnection(List<ConnectivityResult> results) {
    return results.any(
      (result) =>
          result != ConnectivityResult.none &&
          result != ConnectivityResult.bluetooth,
    );
  }

  /// Dispose of resources
  Future<void> dispose() async {
    await _subscription?.cancel();
    await _connectivityController.close();
  }
}
