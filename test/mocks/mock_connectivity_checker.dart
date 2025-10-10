import 'dart:async';

import 'package:synq_manager/src/utils/connectivity_checker.dart';

class MockConnectivityChecker implements ConnectivityChecker {
  MockConnectivityChecker() {
    _controller = StreamController<bool>.broadcast();
  }

  bool connected = true;
  late StreamController<bool> _controller;

  @override
  Future<bool> get isConnected async => connected;

  @override
  Stream<bool> get onStatusChange => _controller.stream;

  /// Triggers a connectivity status change event.
  void triggerStatusChange({required bool isConnected}) {
    connected = isConnected;
    _controller.add(isConnected);
  }

  /// Closes the stream controller.
  Future<void> dispose() async {
    await _controller.close();
  }
}
