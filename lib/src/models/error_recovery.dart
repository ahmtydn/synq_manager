import 'package:synq_manager/src/models/exceptions.dart';

/// Strategy describing how the sync engine should behave on errors.
class ErrorRecoveryStrategy {
  const ErrorRecoveryStrategy({
    required this.shouldRetry,
    this.maxRetries = 3,
    this.backoffStrategy = const ExponentialBackoff(),
    this.onError,
  });
  final int maxRetries;
  final BackoffStrategy backoffStrategy;
  final bool Function(SynqException error) shouldRetry;
  final Future<void> Function(SynqException error)? onError;
}

abstract class BackoffStrategy {
  Duration getDelay(int attemptNumber);
}

class ExponentialBackoff implements BackoffStrategy {
  const ExponentialBackoff({
    this.baseDelay = const Duration(seconds: 1),
    this.multiplier = 2.0,
    this.maxDelay = const Duration(minutes: 5),
  });
  final Duration baseDelay;
  final double multiplier;
  final Duration maxDelay;

  @override
  Duration getDelay(int attemptNumber) {
    final delayMs = baseDelay.inMilliseconds * (multiplier * attemptNumber);
    final delay = Duration(milliseconds: delayMs.round());
    return delay < maxDelay ? delay : maxDelay;
  }
}

class LinearBackoff implements BackoffStrategy {
  const LinearBackoff({this.increment = const Duration(seconds: 5)});
  final Duration increment;

  @override
  Duration getDelay(int attemptNumber) => increment * attemptNumber;
}
