import 'package:synq_manager/src/models/exceptions.dart';

/// Strategy describing how the sync engine should behave on errors.
class ErrorRecoveryStrategy {
  /// Creates an error recovery strategy.
  const ErrorRecoveryStrategy({
    required this.shouldRetry,
    this.maxRetries = 3,
    this.backoffStrategy = const ExponentialBackoff(),
    this.onError,
  });
  
  /// Maximum number of retry attempts.
  final int maxRetries;
  
  /// Strategy for calculating delay between retries.
  final BackoffStrategy backoffStrategy;
  
  /// Determines if an error should trigger a retry.
  final bool Function(SynqException error) shouldRetry;
  
  /// Optional callback invoked when an error occurs.
  final Future<void> Function(SynqException error)? onError;
}

/// Abstract base class for retry backoff strategies.
abstract class BackoffStrategy {
  /// Calculates the delay for a given retry attempt.
  Duration getDelay(int attemptNumber);
}

/// Implements an exponential backoff retry strategy.
class ExponentialBackoff implements BackoffStrategy {
  /// Creates an exponential backoff strategy.
  const ExponentialBackoff({
    this.baseDelay = const Duration(seconds: 1),
    this.multiplier = 2.0,
    this.maxDelay = const Duration(minutes: 5),
  });
  
  /// Initial delay before first retry.
  final Duration baseDelay;
  
  /// Multiplier applied to each subsequent retry delay.
  final double multiplier;
  
  /// Maximum delay cap.
  final Duration maxDelay;

  @override
  Duration getDelay(int attemptNumber) {
    final delayMs = baseDelay.inMilliseconds * (multiplier * attemptNumber);
    final delay = Duration(milliseconds: delayMs.round());
    return delay < maxDelay ? delay : maxDelay;
  }
}

/// Implements a linear backoff retry strategy.
class LinearBackoff implements BackoffStrategy {
  /// Creates a linear backoff strategy.
  const LinearBackoff({this.increment = const Duration(seconds: 5)});
  
  /// Time increment added for each retry attempt.
  final Duration increment;

  @override
  Duration getDelay(int attemptNumber) => increment * attemptNumber;
}
