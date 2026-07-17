import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;

  const Failure(this.message);

  @override
  List<Object> get props => [message];
}

class ServerFailure extends Failure {
  const ServerFailure(super.message);
}

class CacheFailure extends Failure {
  const CacheFailure(super.message);
}

class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

class AuthFailure extends Failure {
  final String? code;

  const AuthFailure(super.message, {this.code});

  @override
  List<Object> get props => [message, code ?? ''];
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

/// The requested resource genuinely does not exist (row absent).
/// À distinguer d'un [ServerFailure] : seul ce cas doit être présenté comme
/// « supprimé / n'existe plus ». Toute autre erreur est retryable.
class NotFoundFailure extends Failure {
  const NotFoundFailure(super.message);
}

/// E2EE permanent failure — not retryable (missing keys, uninitialized service, etc.)
class E2EEFailure extends Failure {
  const E2EEFailure(super.message);
}

// ============== Call-related Failures ==============

/// Failure specific to call operations
class CallFailure extends Failure {
  final String? code;
  const CallFailure(super.message, {this.code});

  @override
  List<Object> get props => [message, code ?? ''];
}

/// Exception thrown when trying to call a user who is already in a call
class BusyUserException implements Exception {
  final String userId;
  final String? userName;
  const BusyUserException(this.userId, {this.userName});

  @override
  String toString() =>
      'BusyUserException: User $userId${userName != null ? ' ($userName)' : ''} is already in a call';
}

/// Exception thrown when user is already in a call and tries to start another
class AlreadyInCallException implements Exception {
  final String currentCallId;
  const AlreadyInCallException(this.currentCallId);

  @override
  String toString() =>
      'AlreadyInCallException: Already in call $currentCallId';
}

/// Exception thrown when an invalid call state transition is attempted
class InvalidStateTransitionException implements Exception {
  final String fromStatus;
  final String toStatus;
  const InvalidStateTransitionException(this.fromStatus, this.toStatus);

  @override
  String toString() =>
      'InvalidStateTransitionException: Cannot transition from $fromStatus to $toStatus';
}

/// Exception thrown when media access fails (microphone/camera)
class MediaAccessException implements Exception {
  final String message;
  final String? deviceType; // 'microphone' or 'camera'
  const MediaAccessException(this.message, {this.deviceType});

  @override
  String toString() =>
      'MediaAccessException: $message${deviceType != null ? ' (device: $deviceType)' : ''}';
}

/// Exception thrown when WebRTC signaling fails
class SignalingException implements Exception {
  final String message;
  final String? operation; // 'offer', 'answer', 'candidate'
  const SignalingException(this.message, {this.operation});

  @override
  String toString() =>
      'SignalingException: $message${operation != null ? ' (operation: $operation)' : ''}';
}

/// Exception thrown when call times out
class CallTimeoutException implements Exception {
  final String callId;
  final String timeoutType; // 'ringing', 'connecting', 'ice_gathering'
  final Duration duration;
  const CallTimeoutException(this.callId, this.timeoutType, this.duration);

  @override
  String toString() =>
      'CallTimeoutException: Call $callId timed out during $timeoutType after ${duration.inSeconds}s';
}
