/// Base class for all SynqManager-specific exceptions.
abstract class SynqException implements Exception {
  SynqException(this.message, [this.stackTrace]);

  final String message;
  final StackTrace? stackTrace;

  @override
  String toString() => '$runtimeType: $message';
}

class NetworkException extends SynqException {
  NetworkException(super.message, [super.stackTrace]);
}

class ConflictException extends SynqException {
  ConflictException(this.context, String message, [StackTrace? stackTrace])
      : super(message, stackTrace);

  final Object context;
}

class AdapterException extends SynqException {
  AdapterException(this.adapterType, String message, [StackTrace? stackTrace])
      : super(message, stackTrace);

  final String adapterType;
}

class UserSwitchException extends SynqException {
  UserSwitchException(
    this.oldUserId,
    this.newUserId,
    String message, [
    StackTrace? stackTrace,
  ]) : super(message, stackTrace);

  final String? oldUserId;
  final String newUserId;
}

class ValidationException extends SynqException {
  ValidationException(
    super.message, [
    this.validationErrors,
    super.stackTrace,
  ]);

  final Map<String, dynamic>? validationErrors;
}
