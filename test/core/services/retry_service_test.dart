import 'package:flutter_test/flutter_test.dart';
import 'package:diaspo_niger/core/services/retry_service.dart';
import 'package:diaspo_niger/core/errors/failures.dart';

void main() {
  group('RetryService', () {
    group('withRetry', () {
      test('should return Right on successful first attempt', () async {
        int attempts = 0;

        final result = await RetryService.withRetry<String>(
          action: () async {
            attempts++;
            return 'success';
          },
        );

        expect(result.isRight(), isTrue);
        result.fold(
          (_) => fail('Should be Right'),
          (value) => expect(value, equals('success')),
        );
        expect(attempts, equals(1));
      });

      test('should retry and succeed after initial failure', () async {
        int attempts = 0;

        final result = await RetryService.withRetry<String>(
          action: () async {
            attempts++;
            if (attempts < 2) {
              throw Exception('Temporary error');
            }
            return 'success after retry';
          },
          maxRetries: 3,
          initialDelay: const Duration(milliseconds: 10),
        );

        expect(result.isRight(), isTrue);
        result.fold(
          (_) => fail('Should be Right'),
          (value) => expect(value, equals('success after retry')),
        );
        expect(attempts, equals(2));
      });

      test('should return Left after max retries exhausted', () async {
        int attempts = 0;

        final result = await RetryService.withRetry<String>(
          action: () async {
            attempts++;
            throw Exception('Persistent error');
          },
          maxRetries: 3,
          initialDelay: const Duration(milliseconds: 10),
        );

        expect(result.isLeft(), isTrue);
        result.fold(
          (failure) => expect(failure, isA<Failure>()),
          (_) => fail('Should be Left'),
        );
        expect(attempts, equals(3));
      });

      test('should call onRetry callback', () async {
        final retryLogs = <int>[];

        final result = await RetryService.withRetry<String>(
          action: () async {
            if (retryLogs.length < 2) {
              throw Exception('Error');
            }
            return 'success';
          },
          maxRetries: 3,
          initialDelay: const Duration(milliseconds: 10),
          onRetry: (attempt, delayMs) {
            retryLogs.add(attempt);
          },
        );

        expect(result.isRight(), isTrue);
        expect(retryLogs, equals([1, 2]));
      });

      test('should not retry when shouldRetry returns false', () async {
        int attempts = 0;

        final result = await RetryService.withRetry<String>(
          action: () async {
            attempts++;
            throw Exception('Non-retryable error');
          },
          maxRetries: 3,
          shouldRetry: (error) => false,
        );

        expect(result.isLeft(), isTrue);
        expect(attempts, equals(1));
      });
    });

    group('withRetryNullable', () {
      test('should return value on success', () async {
        final result = await RetryService.withRetryNullable<String>(
          action: () async => 'success',
        );

        expect(result, equals('success'));
      });

      test('should return null on failure', () async {
        final result = await RetryService.withRetryNullable<String>(
          action: () async => throw Exception('Error'),
          maxRetries: 1,
          initialDelay: const Duration(milliseconds: 10),
        );

        expect(result, isNull);
      });
    });

    group('isRetryableError', () {
      test('should return true for network errors', () {
        expect(
          RetryService.isRetryableError(Exception('network error')),
          isTrue,
        );
        expect(
          RetryService.isRetryableError(Exception('socket exception')),
          isTrue,
        );
        expect(
          RetryService.isRetryableError(Exception('connection refused')),
          isTrue,
        );
      });

      test('should return true for temporary/unavailable errors', () {
        expect(
          RetryService.isRetryableError(Exception('temporary failure')),
          isTrue,
        );
        expect(
          RetryService.isRetryableError(Exception('service unavailable')),
          isTrue,
        );
        expect(
          RetryService.isRetryableError(Exception('503 Service Unavailable')),
          isTrue,
        );
      });

      test('should return false for permanent errors', () {
        expect(
          RetryService.isRetryableError(Exception('invalid input')),
          isFalse,
        );
        expect(RetryService.isRetryableError(Exception('not found')), isFalse);
      });
    });
  });
}
