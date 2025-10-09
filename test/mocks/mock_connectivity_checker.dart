import 'package:synq_manager/src/utils/connectivity_checker.dart';

class MockConnectivityChecker implements ConnectivityChecker {
  bool _connected = true;

  void setConnected(bool connected) => _connected = connected;

  @override
  Future<bool> get isConnected async => _connected;

  @override
  Stream<bool> get onStatusChange => Stream.value(_connected);
}
