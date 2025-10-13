import 'package:synq_manager/src/models/syncable_entity.dart';

/// Base exception for all SynqManager related errors.
abstract class SynqException implements Exception {
  /// A descriptive message for the exception.
  String get message;
}

/// Exception thrown for network-related issues.
class NetworkException extends SynqException {
  /// Creates a [NetworkException].
  NetworkException(this.message);

  @override
  final String message;

  @override
  String toString() => 'NetworkException: $message';
}

/// Exception thrown when a schema migration fails.
class MigrationException extends SynqException {
  /// Creates a [MigrationException].
  MigrationException(this.message);

  @override
  final String message;

  @override
  String toString() => 'MigrationException: $message';
}

/// Exception thrown when a user switch operation is rejected by a strategy.
class UserSwitchException<T extends SyncableEntity> extends SynqException {
  /// Creates a [UserSwitchException].
  UserSwitchException(this.oldUserId, this.newUserId, this.message);

  /// The user ID being switched from.
  final String? oldUserId;

  /// The user ID being switched to.
  final String newUserId;

  @override
  final String message;

  @override
  String toString() => 'UserSwitchException: $message';
}

/// Exception thrown by adapters during their operations.
class AdapterException extends SynqException {
  /// Creates an [AdapterException].
  AdapterException(this.adapterName, this.message, [this.stackTrace]);

  /// The name of the adapter that threw the exception.
  final String adapterName;

  @override
  final String message;

  /// The stack trace associated with the error, if available.
  final StackTrace? stackTrace;

  @override
  String toString() => 'AdapterException($adapterName): $message';
}
