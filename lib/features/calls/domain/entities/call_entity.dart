import 'package:equatable/equatable.dart';

/// Type of call
enum CallType { audio, video }

/// Status of a call
enum CallStatus {
  /// Call is ringing
  ringing,

  /// Call is being connected
  connecting,

  /// Call is active
  connected,

  /// WebRTC connection lost, attempting to reconnect
  reconnecting,

  /// Call is on hold (user initiated)
  onHold,

  /// Call has ended normally
  ended,

  /// Call was declined by the callee
  declined,

  /// Call was missed (no answer)
  missed,

  /// Callee is busy with another call
  busy,

  /// Call failed due to an error
  error;

  /// Check if this status is a terminal state (call cannot continue)
  bool get isTerminal => [ended, declined, missed, busy, error].contains(this);

  /// Check if this status is an active state (call is in progress)
  bool get isActive => [ringing, connecting, connected, reconnecting, onHold].contains(this);

  /// Validate if a transition from this status to [target] is allowed
  /// Returns true if the transition is valid
  static bool canTransition(CallStatus from, CallStatus to) {
    // Terminal states cannot transition to anything
    if (from.isTerminal) return false;

    const validTransitions = <CallStatus, List<CallStatus>>{
      CallStatus.ringing: [
        CallStatus.connecting,
        CallStatus.declined,
        CallStatus.missed,
        CallStatus.busy,
        CallStatus.ended, // Caller cancels
        CallStatus.error,
      ],
      CallStatus.connecting: [
        CallStatus.connected,
        CallStatus.ended,
        CallStatus.error,
      ],
      CallStatus.connected: [
        CallStatus.reconnecting,
        CallStatus.onHold,
        CallStatus.ended,
        CallStatus.error,
      ],
      CallStatus.reconnecting: [
        CallStatus.connected, // Reconnection successful
        CallStatus.ended,
        CallStatus.error,
      ],
      CallStatus.onHold: [
        CallStatus.connected, // Resumed
        CallStatus.ended,
        CallStatus.error,
      ],
    };

    return validTransitions[from]?.contains(to) ?? false;
  }
}

/// Entity representing a 1:1 call between two users
class CallEntity extends Equatable {
  /// Unique identifier for the call
  final String id;

  /// ID of the user who initiated the call
  final String callerId;

  /// Display name of the caller
  final String callerName;

  /// Photo URL of the caller
  final String? callerPhotoUrl;

  /// ID of the user being called
  final String calleeId;

  /// Display name of the callee
  final String calleeName;

  /// Photo URL of the callee
  final String? calleePhotoUrl;

  /// Type of call (audio or video)
  final CallType type;

  /// Current status of the call
  final CallStatus status;

  /// When the call was initiated
  final DateTime createdAt;

  /// When the call was answered (null if not answered)
  final DateTime? answeredAt;

  /// When the call ended (null if still active)
  final DateTime? endedAt;

  /// Duration of the call in seconds (null if not ended)
  final int? durationSeconds;

  /// Reason for ending the call
  final String? endReason;

  const CallEntity({
    required this.id,
    required this.callerId,
    required this.callerName,
    this.callerPhotoUrl,
    required this.calleeId,
    required this.calleeName,
    this.calleePhotoUrl,
    required this.type,
    required this.status,
    required this.createdAt,
    this.answeredAt,
    this.endedAt,
    this.durationSeconds,
    this.endReason,
  });

  /// Whether the call is currently active (not in a terminal state)
  bool get isActive => status.isActive;

  /// Whether this is an incoming call for the given user
  bool isIncoming(String userId) => calleeId == userId;

  /// Whether this is an outgoing call for the given user
  bool isOutgoing(String userId) => callerId == userId;

  /// Get the other party's ID based on the current user
  String getOtherPartyId(String currentUserId) {
    return currentUserId == callerId ? calleeId : callerId;
  }

  /// Get the other party's name based on the current user
  String getOtherPartyName(String currentUserId) {
    return currentUserId == callerId ? calleeName : callerName;
  }

  /// Get the other party's photo URL based on the current user
  String? getOtherPartyPhotoUrl(String currentUserId) {
    return currentUserId == callerId ? calleePhotoUrl : callerPhotoUrl;
  }

  /// Format duration as mm:ss or hh:mm:ss
  String get formattedDuration {
    if (durationSeconds == null || durationSeconds == 0) {
      return '00:00';
    }

    final hours = durationSeconds! ~/ 3600;
    final minutes = (durationSeconds! % 3600) ~/ 60;
    final seconds = durationSeconds! % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Copy with new values
  CallEntity copyWith({
    String? id,
    String? callerId,
    String? callerName,
    String? callerPhotoUrl,
    String? calleeId,
    String? calleeName,
    String? calleePhotoUrl,
    CallType? type,
    CallStatus? status,
    DateTime? createdAt,
    DateTime? answeredAt,
    DateTime? endedAt,
    int? durationSeconds,
    String? endReason,
  }) {
    return CallEntity(
      id: id ?? this.id,
      callerId: callerId ?? this.callerId,
      callerName: callerName ?? this.callerName,
      callerPhotoUrl: callerPhotoUrl ?? this.callerPhotoUrl,
      calleeId: calleeId ?? this.calleeId,
      calleeName: calleeName ?? this.calleeName,
      calleePhotoUrl: calleePhotoUrl ?? this.calleePhotoUrl,
      type: type ?? this.type,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      answeredAt: answeredAt ?? this.answeredAt,
      endedAt: endedAt ?? this.endedAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      endReason: endReason ?? this.endReason,
    );
  }

  @override
  List<Object?> get props => [
        id,
        callerId,
        calleeId,
        type,
        status,
        createdAt,
        answeredAt,
        endedAt,
        durationSeconds,
      ];
}
