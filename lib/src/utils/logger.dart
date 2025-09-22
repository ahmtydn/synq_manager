import 'package:flutter/foundation.dart';

/// Logger for sync operations
class SyncLogger {
  SyncLogger({this.level = LogLevel.info});

  final LogLevel level;

  void debug(String message) {
    if (level.index <= LogLevel.debug.index) {
      _log('DEBUG', message);
    }
  }

  void info(String message) {
    if (level.index <= LogLevel.info.index) {
      _log('INFO', message);
    }
  }

  void warning(String message) {
    if (level.index <= LogLevel.warning.index) {
      _log('WARNING', message);
    }
  }

  void error(String message, [StackTrace? stackTrace]) {
    if (level.index <= LogLevel.error.index) {
      _log('ERROR', message);
      if (stackTrace != null) {
        _log('STACK', stackTrace.toString());
      }
    }
  }

  void _log(String level, String message) {
    final timestamp = DateTime.now().toIso8601String();
    final logMessage = '[$timestamp] [$level] [SynqManager] $message';

    if (kDebugMode) {
      print(logMessage);
    }
  }
}

enum LogLevel {
  debug,
  info,
  warning,
  error,
}
