import 'package:equatable/equatable.dart';

/// Role of a participant in an audio room
enum ParticipantRole {
  /// The creator and main moderator of the room
  host,

  /// A co-moderator with moderation rights
  coHost,

  /// A user who can speak in the room
  speaker,

  /// A user who can only listen
  listener,

  /// An invisible admin moderator (ghost mode)
  moderator,
}

/// Connection state of a participant
enum ParticipantConnectionState {
  /// Participant is connecting
  connecting,

  /// Participant is connected
  connected,

  /// Participant is disconnected
  disconnected,

  /// Connection failed
  failed,
}

/// Entity representing a participant in an audio room
class ParticipantEntity extends Equatable {
  /// User ID
  final String userId;

  /// Display name
  final String userName;

  /// Photo URL
  final String? photoUrl;

  /// Role in the room
  final ParticipantRole role;

  /// Connection state
  final ParticipantConnectionState connectionState;

  /// Whether the participant is muted
  final bool isMuted;

  /// Whether the participant is currently speaking (based on audio level)
  final bool isSpeaking;

  /// When the participant joined the room
  final DateTime joinedAt;

  /// Current audio level (0.0 to 1.0) for visual indicator
  final double? audioLevel;

  /// Whether the participant has raised their hand
  final bool hasHandRaised;

  /// When the hand was raised (if raised)
  final DateTime? handRaisedAt;

  /// Whether the participant's camera is on (for video rooms)
  final bool isCameraOn;

  /// Whether this participant is in ghost mode (invisible moderator)
  final bool isGhostMode;

  const ParticipantEntity({
    required this.userId,
    required this.userName,
    this.photoUrl,
    required this.role,
    required this.connectionState,
    this.isMuted = false,
    this.isSpeaking = false,
    required this.joinedAt,
    this.audioLevel,
    this.hasHandRaised = false,
    this.handRaisedAt,
    this.isCameraOn = false,
    this.isGhostMode = false,
  });

  /// Whether this participant can be muted by a host/co-host
  bool get canBeMutedByHost => role != ParticipantRole.host;

  /// Whether this participant can be promoted to speaker
  bool get canBePromoted => role == ParticipantRole.listener;

  /// Whether this participant can be demoted to listener
  bool get canBeDemoted =>
      role == ParticipantRole.speaker || role == ParticipantRole.coHost;

  /// Whether this participant can speak
  bool get canSpeak =>
      (role == ParticipantRole.host ||
          role == ParticipantRole.coHost ||
          role == ParticipantRole.speaker) &&
      !isMuted;

  /// Whether this participant is connected
  bool get isConnected =>
      connectionState == ParticipantConnectionState.connected;

  /// Get role display label in French
  String get roleLabel {
    switch (role) {
      case ParticipantRole.host:
        return 'Hôte';
      case ParticipantRole.coHost:
        return 'Co-hôte';
      case ParticipantRole.speaker:
        return 'Speaker';
      case ParticipantRole.listener:
        return 'Listener';
      case ParticipantRole.moderator:
        return 'Modérateur';
    }
  }

  /// Copy with new values
  ParticipantEntity copyWith({
    String? userId,
    String? userName,
    String? photoUrl,
    ParticipantRole? role,
    ParticipantConnectionState? connectionState,
    bool? isMuted,
    bool? isSpeaking,
    DateTime? joinedAt,
    double? audioLevel,
    bool? hasHandRaised,
    DateTime? handRaisedAt,
    bool? isCameraOn,
    bool? isGhostMode,
  }) {
    return ParticipantEntity(
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      connectionState: connectionState ?? this.connectionState,
      isMuted: isMuted ?? this.isMuted,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      joinedAt: joinedAt ?? this.joinedAt,
      audioLevel: audioLevel ?? this.audioLevel,
      hasHandRaised: hasHandRaised ?? this.hasHandRaised,
      handRaisedAt: handRaisedAt ?? this.handRaisedAt,
      isCameraOn: isCameraOn ?? this.isCameraOn,
      isGhostMode: isGhostMode ?? this.isGhostMode,
    );
  }

  @override
  List<Object?> get props => [
        userId,
        role,
        connectionState,
        isMuted,
        isSpeaking,
        hasHandRaised,
        isCameraOn,
        isGhostMode,
      ];
}
