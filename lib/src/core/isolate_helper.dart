import 'dart:async';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// A command to compute a data hash.
class _HashCommand {
  _HashCommand(this.itemMaps);
  final List<Map<String, dynamic>> itemMaps;
}

/// A message wrapper for isolate communication.
class _IsolateMessage {
  _IsolateMessage(this.replyTo, this.command);
  final SendPort replyTo;
  final _HashCommand command;
}

/// Manages a long-lived isolate for CPU-intensive computations.
class IsolateHelper {
  /// A flag to disable isolate creation during tests.
  static bool disableForTests = false;

  SendPort? _sendPort;
  Isolate? _isolate;
  final _receivePort = ReceivePort();

  /// Spawns the isolate and sets up communication channels.
  Future<void> initialize() async {
    // If disabled for tests, do not spawn the isolate.
    if (disableForTests) return;

    if (_isolate != null) return; // Already initialized

    _isolate = await Isolate.spawn(_isolateEntryPoint, _receivePort.sendPort);
    // Wait for the isolate to send back its SendPort.
    final completer = Completer<SendPort>();
    _receivePort.listen((message) {
      if (message is SendPort) {
        completer.complete(message);
      }
    });
    _sendPort = await completer.future;
  }

  /// Computes a data hash in the background isolate.
  Future<String> computeDataHash(List<Map<String, dynamic>> itemMaps) async {
    // If disabled for tests, compute directly on the main thread.
    if (disableForTests) {
      return compute(_computeDataHash, itemMaps);
    }

    if (_sendPort == null) {
      throw StateError('Isolate helper not initialized.');
    }
    final responsePort = ReceivePort();
    _sendPort!.send(
      _IsolateMessage(responsePort.sendPort, _HashCommand(itemMaps)),
    );
    // Wait for the result from the isolate.
    return await responsePort.first as String;
  }

  /// Terminates the background isolate.
  void dispose() {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _receivePort.close();
  }
}

/// The entry point for the long-lived isolate.
void _isolateEntryPoint(SendPort mainSendPort) {
  final isolateReceivePort = ReceivePort();
  mainSendPort.send(isolateReceivePort.sendPort);

  isolateReceivePort.listen((message) {
    if (message is _IsolateMessage) {
      final result = _computeDataHash(message.command.itemMaps);
      message.replyTo.send(result);
    }
  });
}

/// Computes a stable hash of data content.
String _computeDataHash(List<Map<String, dynamic>> itemMaps) {
  if (itemMaps.isEmpty) return '';
  final contentToHash = itemMaps.map((e) => e.toString()).join(',');
  return sha1.convert(contentToHash.codeUnits).toString();
}
