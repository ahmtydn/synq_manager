import 'package:synq_manager/src/utils/connectivity_checker.dart';

class MockConnectivityChecker implements ConnectivityChecker {
  bool connected = true;

  @override
  Future<bool> get isConnected async => connected;

  @override
  Stream<bool> get onStatusChange => Stream.value(connected);
}
