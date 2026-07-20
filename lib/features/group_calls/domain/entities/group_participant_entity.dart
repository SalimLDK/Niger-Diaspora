import 'package:equatable/equatable.dart';

/// Role of a participant in a group call
enum GroupParticipantRole {
  /// The user who started the call
  host,

  /// Regular participant
  participant,
}

/// Connection state of a participant
enum ParticipantConnectionState {
  /// Connecting to the call
  connecting,

  /// Connected and active
  connected,

  /// Reconnecting after connection loss
  reconnecting,

  /// Disconnected from the call
  disconnected,
}

/// Quality level for video streaming
enum VideoQuality {
  /// Low quality (180p) - for poor network
  low,

  /// Medium quality (360p) - default
  medium,

  /// High quality (720p) - for good network
  high,
}

/// Entity representing a participant in a group call
class GroupParticipantEntity extends Equatable {
  /// User ID of the participant
  final String oderId;

  /// Display name of the participant
  final String displayName;

  /// Photo URL of the participant
  final String? photoUrl;

  /// Role in the call (host or participant)
  final GroupParticipantRole role;

  /// Connection state
  final ParticipantConnectionState connectionState;

  /// Whether the participant's microphone is muted
  final bool isMuted;

  /// Whether the participant's camera is off
  final bool isCameraOff;

  /// Whether the participant is speaking (audio activity)
  final bool isSpeaking;

  /// Whether the participant has raised hand
  final bool hasHandRaised;

  /// Whether the participant's screen is being shared
  final bool isScreenSharing;

  /// Video quality being received from this participant
  final VideoQuality videoQuality;

  /// Audio level (0.0 to 1.0) for visualizing speaking
  final double audioLevel;

  /// Network quality (0-5, 0 = unknown, 5 = excellent)
  final int networkQuality;

  /// When the participant joined the call
  final DateTime joinedAt;

  /// When the participant left the call (null if still in call)
  final DateTime? leftAt;

  const GroupParticipantEntity({
    required this.oderId,
    required this.displayName,
    this.photoUrl,
    required this.role,
    this.connectionState = ParticipantConnectionState.connecting,
    this.isMuted = false,
    this.isCameraOff = true,
    this.isSpeaking = false,
    this.hasHandRaised = false,
    this.isScreenSharing = false,
    this.videoQuality = VideoQuality.medium,
    this.audioLevel = 0.0,
    this.networkQuality = 0,
    required this.joinedAt,
    this.leftAt,
  });

  /// Whether the participant is the host
  bool get isHost => role == GroupParticipantRole.host;

  /// Whether the participant is currently connected
  bool get isConnected => connectionState == ParticipantConnectionState.connected;

  /// Whether the participant has left the call
  bool get hasLeft => leftAt != null;

  /// Whether video should be shown for this participant
  bool get shouldShowVideo => !isCameraOff && isConnected;

  /// Get a label for the network quality
  String get networkQualityLabel => switch (networkQuality) {
        0 => 'Inconnu',
        1 => 'Mauvais',
        2 => 'Faible',
        3 => 'Correct',
        4 => 'Bon',
        5 => 'Excellent',
        _ => 'Inconnu',
      };

  /// Get a label for the video quality
  String get videoQualityLabel => switch (videoQuality) {
        VideoQuality.low => '180p',
        VideoQuality.medium => '360p',
        VideoQuality.high => '720p',
      };

  /// Copy with new values
  GroupParticipantEntity copyWith({
    String? oderId,
    String? displayName,
    String? photoUrl,
    GroupParticipantRole? role,
    ParticipantConnectionState? connectionState,
    bool? isMuted,
    bool? isCameraOff,
    bool? isSpeaking,
    bool? hasHandRaised,
    bool? isScreenSharing,
    VideoQuality? videoQuality,
    double? audioLevel,
    int? networkQuality,
    DateTime? joinedAt,
    DateTime? leftAt,
  }) {
    return GroupParticipantEntity(
      oderId: oderId ?? this.oderId,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      connectionState: connectionState ?? this.connectionState,
      isMuted: isMuted ?? this.isMuted,
      isCameraOff: isCameraOff ?? this.isCameraOff,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      hasHandRaised: hasHandRaised ?? this.hasHandRaised,
      isScreenSharing: isScreenSharing ?? this.isScreenSharing,
      videoQuality: videoQuality ?? this.videoQuality,
      audioLevel: audioLevel ?? this.audioLevel,
      networkQuality: networkQuality ?? this.networkQuality,
      joinedAt: joinedAt ?? this.joinedAt,
      leftAt: leftAt ?? this.leftAt,
    );
  }

  @override
  List<Object?> get props => [
        oderId,
        displayName,
        role,
        connectionState,
        isMuted,
        isCameraOff,
        isSpeaking,
        hasHandRaised,
        isScreenSharing,
        videoQuality,
        networkQuality,
        joinedAt,
        leftAt,
      ];
}
