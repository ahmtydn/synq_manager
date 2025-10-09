/// Logging levels.
enum LogLevel {
  /// Debug level logging.
  debug,

  /// Info level logging.
  info,

  /// Warning level logging.
  warn,

  /// Error level logging.
  error
}

/// Lightweight logger abstraction to avoid pulling in heavy dependencies.
class SynqLogger {
  /// Creates a logger instance.
  SynqLogger({this.enabled = false, this.minimumLevel = LogLevel.info});

  /// Whether logging is enabled.
  final bool enabled;

  /// Minimum level to log.
  final LogLevel minimumLevel;

  /// Logs a debug message.
  void debug(String message) => _log(LogLevel.debug, message);

  /// Logs an info message.
  void info(String message) => _log(LogLevel.info, message);

  /// Logs a warning message.
  void warn(String message) => _log(LogLevel.warn, message);

  /// Logs an error message with optional error object and stack trace.
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

  /// Creates a copy with modified properties.
  SynqLogger copyWith({bool? enabled, LogLevel? minimumLevel}) {
    return SynqLogger(
      enabled: enabled ?? this.enabled,
      minimumLevel: minimumLevel ?? this.minimumLevel,
    );
  }
}
