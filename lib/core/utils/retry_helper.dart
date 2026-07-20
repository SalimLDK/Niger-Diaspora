import 'dart:async';
import 'package:flutter/foundation.dart';

/// Configuration pour le retry
class RetryConfig {
  final int maxAttempts;
  final Duration initialDelay;
  final double backoffFactor;
  final Duration maxDelay;
  final bool Function(Exception)? retryIf;

  const RetryConfig({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(seconds: 1),
    this.backoffFactor = 2.0,
    this.maxDelay = const Duration(seconds: 30),
    this.retryIf,
  });

  static const defaultConfig = RetryConfig();

  static const uploadConfig = RetryConfig(
    maxAttempts: 5,
    initialDelay: Duration(seconds: 2),
    backoffFactor: 1.5,
    maxDelay: Duration(minutes: 1),
  );
}

/// Helper pour les operations avec retry automatique
class RetryHelper {
  /// Executer une operation avec retry exponentiel
  static Future<T> withRetry<T>({
    required Future<T> Function() operation,
    RetryConfig config = RetryConfig.defaultConfig,
    void Function(int attempt, Exception error)? onRetry,
  }) async {
    int attempts = 0;
    Duration delay = config.initialDelay;

    while (true) {
      try {
        attempts++;
        return await operation();
      } on Exception catch (e) {
        // Verifier si on doit retry cette exception
        if (config.retryIf != null && !config.retryIf!(e)) {
          rethrow;
        }

        // Verifier si on a atteint le max d'essais
        if (attempts >= config.maxAttempts) {
          debugPrint('RetryHelper: Failed after $attempts attempts');
          rethrow;
        }

        // Notifier le callback
        onRetry?.call(attempts, e);

        debugPrint(
          'RetryHelper: Attempt $attempts failed, retrying in ${delay.inSeconds}s... Error: $e',
        );

        // Attendre avant de retry
        await Future.delayed(delay);

        // Calculer le prochain delai (avec cap)
        delay = Duration(
          milliseconds: (delay.inMilliseconds * config.backoffFactor).toInt(),
        );
        if (delay > config.maxDelay) {
          delay = config.maxDelay;
        }
      }
    }
  }

  /// Executer plusieurs operations en parallele avec retry individuel
  static Future<List<T>> withRetryAll<T>({
    required List<Future<T> Function()> operations,
    RetryConfig config = RetryConfig.defaultConfig,
  }) async {
    return Future.wait(
      operations.map((op) => withRetry(operation: op, config: config)),
    );
  }
}

/// Extension pour simplifier l'utilisation
extension RetryFuture<T> on Future<T> Function() {
  Future<T> withRetry({RetryConfig config = RetryConfig.defaultConfig}) {
    return RetryHelper.withRetry(operation: this, config: config);
  }
}
