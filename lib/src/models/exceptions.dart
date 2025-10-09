/// Base class for all SynqManager-specific exceptions.
abstract class SynqException implements Exception {
  /// Creates a SynqException with a message and optional stack trace.
  SynqException(this.message, [this.stackTrace]);

  /// The error message.
  final String message;
  
  /// Optional stack trace.
  final StackTrace? stackTrace;

  @override
  String toString() => '$runtimeType: $message';
}

/// Exception thrown when network-related errors occur.
class NetworkException extends SynqException {
  /// Creates a network exception.
  NetworkException(super.message, [super.stackTrace]);
}

/// Exception thrown when a data conflict is detected.
class ConflictException extends SynqException {
  /// Creates a conflict exception with context.
  ConflictException(this.context, String message, [StackTrace? stackTrace])
      : super(message, stackTrace);

  /// Context object related to the conflict.
  final Object context;
}

/// Exception thrown by adapters during data operations.
class AdapterException extends SynqException {
  /// Creates an adapter exception.
  AdapterException(this.adapterType, String message, [StackTrace? stackTrace])
      : super(message, stackTrace);

  /// Type of adapter that threw the exception.
  final String adapterType;
}

/// Exception thrown during user switching operations.
class UserSwitchException extends SynqException {
  /// Creates a user switch exception.
  UserSwitchException(
    this.oldUserId,
    this.newUserId,
    String message, [
    StackTrace? stackTrace,
  ]) : super(message, stackTrace);

  /// Previous user ID.
  final String? oldUserId;
  
  /// New user ID.
  final String newUserId;
}

/// Exception thrown when data validation fails.
class ValidationException extends SynqException {
  /// Creates a validation exception with optional validation errors.
  ValidationException(
    super.message, [
    this.validationErrors,
    super.stackTrace,
  ]);

  /// Map of field names to validation error messages.
  final Map<String, dynamic>? validationErrors;
}
