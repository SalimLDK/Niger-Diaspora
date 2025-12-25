import 'dart:async';
import 'dart:math';

import 'package:dartz/dartz.dart';

import '../errors/failures.dart';

class RetryService {
  static final _random = Random();

  static Future<Either<Failure, T>> withRetry<T>({
    required Future<T> Function() action,
    int maxRetries = 3,
    Duration initialDelay = const Duration(seconds: 1),
    double backoffMultiplier = 2.0,
    double jitterFactor = 0.1,
    void Function(int attempt, int delayMs)? onRetry,
    bool Function(Object error)? shouldRetry,
  }) async {
    int attempt = 0;
    Duration currentDelay = initialDelay;

    while (true) {
      try {
        final result = await action();
        return Right(result);
      } catch (e) {
        attempt++;

        if (attempt >= maxRetries) {
          return Left(_errorToFailure(e));
        }

        if (shouldRetry != null && !shouldRetry(e)) {
          return Left(_errorToFailure(e));
        }

        final jitter = (currentDelay.inMilliseconds * jitterFactor * (_random.nextDouble() - 0.5)).round();
        final delayMs = currentDelay.inMilliseconds + jitter;

        onRetry?.call(attempt, delayMs);

        await Future.delayed(Duration(milliseconds: delayMs));

        currentDelay = Duration(
          milliseconds: (currentDelay.inMilliseconds * backoffMultiplier).round(),
        );
      }
    }
  }

  static Future<T?> withRetryNullable<T>({
    required Future<T> Function() action,
    int maxRetries = 3,
    Duration initialDelay = const Duration(seconds: 1),
    void Function(int attempt, int delayMs)? onRetry,
  }) async {
    final result = await withRetry<T>(
      action: action,
      maxRetries: maxRetries,
      initialDelay: initialDelay,
      onRetry: onRetry,
    );
    return result.fold((_) => null, (value) => value);
  }

  static Failure _errorToFailure(Object error) {
    final message = error.toString();

    if (_isNetworkError(message)) {
      if (message.toLowerCase().contains('timeout')) {
        return NetworkFailure('Connection timed out: $message');
      }
      return NetworkFailure(message);
    }

    if (_isAuthError(message)) {
      return AuthFailure(message);
    }

    return ServerFailure(message);
  }

  static bool _isNetworkError(String message) {
    final lowerMessage = message.toLowerCase();
    return lowerMessage.contains('network') ||
        lowerMessage.contains('socket') ||
        lowerMessage.contains('connection') ||
        lowerMessage.contains('timeout') ||
        lowerMessage.contains('unreachable') ||
        lowerMessage.contains('no internet') ||
        lowerMessage.contains('failed host lookup');
  }

  static bool _isAuthError(String message) {
    final lowerMessage = message.toLowerCase();
    return lowerMessage.contains('permission') ||
        lowerMessage.contains('unauthorized') ||
        lowerMessage.contains('unauthenticated') ||
        lowerMessage.contains('sign in') ||
        lowerMessage.contains('login');
  }

  static bool isRetryableError(Object error) {
    final message = error.toString().toLowerCase();
    return _isNetworkError(message) ||
        message.contains('temporary') ||
        message.contains('unavailable') ||
        message.contains('503') ||
        message.contains('504');
  }
}
