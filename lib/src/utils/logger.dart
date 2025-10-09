enum LogLevel { debug, info, warn, error }

/// Lightweight logger abstraction to avoid pulling in heavy dependencies.
class SynqLogger {
  SynqLogger({this.enabled = false, this.minimumLevel = LogLevel.info});

  final bool enabled;
  final LogLevel minimumLevel;

  void debug(String message) => _log(LogLevel.debug, message);
  void info(String message) => _log(LogLevel.info, message);
  void warn(String message) => _log(LogLevel.warn, message);
  void error(String message, [Object? error, StackTrace? stackTrace]) =>
      _log(LogLevel.error, message, error: error, stackTrace: stackTrace);

  void _log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!enabled || level.index < minimumLevel.index) return;

    final buffer =
        StringBuffer('[SynqManager][${level.name.toUpperCase()}] $message');
    if (error != null) {
      buffer.write(' | error=$error');
    }
    if (stackTrace != null) {
      buffer.write('\n$stackTrace');
    }
    print(buffer);
  }

  SynqLogger copyWith({bool? enabled, LogLevel? minimumLevel}) {
    return SynqLogger(
      enabled: enabled ?? this.enabled,
      minimumLevel: minimumLevel ?? this.minimumLevel,
    );
  }
}
