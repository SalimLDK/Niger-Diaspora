import 'package:equatable/equatable.dart';

import '../../domain/entities/participant_entity.dart';

/// Model representing a participant in an audio room
class ParticipantModel extends Equatable {
  final String oderId;
  final String userName;
  final String? photoUrl;
  final String role;
  final String connectionState;
  final bool isMuted;
  final bool isSpeaking;
  final double? audioLevel;
  final String joinedAt;
  final bool hasHandRaised;
  final String? handRaisedAt;
  final bool isCameraOn;
  final bool isGhostMode;

  const ParticipantModel({
    required this.oderId,
    required this.userName,
    this.photoUrl,
    required this.role,
    this.connectionState = 'connected',
    this.isMuted = false,
    this.isSpeaking = false,
    this.audioLevel,
    required this.joinedAt,
    this.hasHandRaised = false,
    this.handRaisedAt,
    this.isCameraOn = false,
    this.isGhostMode = false,
  });

  factory ParticipantModel.fromJson(Map<String, dynamic> json) {
    return ParticipantModel(
      oderId: json['oderId'] as String? ?? json['userId'] as String? ?? '',
      userName: json['userName'] as String? ?? 'Utilisateur',
      photoUrl: json['photoUrl'] as String?,
      role: json['role'] as String? ?? 'listener',
      connectionState: json['connectionState'] as String? ?? 'connected',
      isMuted: json['isMuted'] as bool? ?? false,
      isSpeaking: json['isSpeaking'] as bool? ?? false,
      audioLevel: (json['audioLevel'] as num?)?.toDouble(),
      joinedAt: json['joinedAt'] as String? ?? DateTime.now().toIso8601String(),
      hasHandRaised: json['hasHandRaised'] as bool? ?? false,
      handRaisedAt: json['handRaisedAt'] as String?,
      isCameraOn: json['isCameraOn'] as bool? ?? false,
      isGhostMode: json['isGhostMode'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'oderId': oderId,
      'userName': userName,
      'photoUrl': photoUrl,
      'role': role,
      'connectionState': connectionState,
      'isMuted': isMuted,
      'isSpeaking': isSpeaking,
      'audioLevel': audioLevel,
      'joinedAt': joinedAt,
      'hasHandRaised': hasHandRaised,
      'handRaisedAt': handRaisedAt,
      'isCameraOn': isCameraOn,
      'isGhostMode': isGhostMode,
    };
  }

  /// Convert to entity
  ParticipantEntity toEntity() {
    return ParticipantEntity(
      userId: oderId,
      userName: userName,
      photoUrl: photoUrl,
      role: _parseRole(role),
      connectionState: _parseConnectionState(connectionState),
      isMuted: isMuted,
      isSpeaking: isSpeaking,
      audioLevel: audioLevel,
      joinedAt: DateTime.parse(joinedAt).toLocal(),
      hasHandRaised: hasHandRaised,
      handRaisedAt: handRaisedAt != null ? DateTime.parse(handRaisedAt!).toLocal() : null,
      isCameraOn: isCameraOn,
      isGhostMode: isGhostMode,
    );
  }

  /// Create from entity
  factory ParticipantModel.fromEntity(ParticipantEntity entity) {
    return ParticipantModel(
      oderId: entity.userId,
      userName: entity.userName,
      photoUrl: entity.photoUrl,
      role: entity.role.name,
      connectionState: entity.connectionState.name,
      isMuted: entity.isMuted,
      isSpeaking: entity.isSpeaking,
      audioLevel: entity.audioLevel,
      joinedAt: entity.joinedAt.toIso8601String(),
      hasHandRaised: entity.hasHandRaised,
      handRaisedAt: entity.handRaisedAt?.toIso8601String(),
      isCameraOn: entity.isCameraOn,
      isGhostMode: entity.isGhostMode,
    );
  }

  /// Create from RTDB data
  factory ParticipantModel.fromRTDB(String oderId, Map<String, dynamic> data) {
    return ParticipantModel(
      oderId: oderId,
      userName: data['userName'] as String? ?? 'Utilisateur',
      photoUrl: data['photoUrl'] as String?,
      role: data['role'] as String? ?? 'listener',
      connectionState: data['connectionState'] as String? ?? 'connected',
      isMuted: data['isMuted'] as bool? ?? false,
      isSpeaking: data['isSpeaking'] as bool? ?? false,
      audioLevel: (data['audioLevel'] as num?)?.toDouble(),
      joinedAt: data['joinedAt'] as String? ?? DateTime.now().toIso8601String(),
      hasHandRaised: data['hasHandRaised'] as bool? ?? false,
      handRaisedAt: data['handRaisedAt'] as String?,
      isCameraOn: data['isCameraOn'] as bool? ?? false,
      isGhostMode: data['isGhostMode'] as bool? ?? false,
    );
  }

  /// Convert to RTDB data
  Map<String, dynamic> toRTDB() {
    return {
      'userName': userName,
      'photoUrl': photoUrl,
      'role': role,
      'connectionState': connectionState,
      'isMuted': isMuted,
      'isSpeaking': isSpeaking,
      'audioLevel': audioLevel,
      'joinedAt': joinedAt,
      'hasHandRaised': hasHandRaised,
      'handRaisedAt': handRaisedAt,
      'isCameraOn': isCameraOn,
      'isGhostMode': isGhostMode,
    };
  }

  ParticipantModel copyWith({
    String? oderId,
    String? userName,
    String? photoUrl,
    String? role,
    String? connectionState,
    bool? isMuted,
    bool? isSpeaking,
    double? audioLevel,
    String? joinedAt,
    bool? hasHandRaised,
    String? handRaisedAt,
    bool? isCameraOn,
    bool? isGhostMode,
  }) {
    return ParticipantModel(
      oderId: oderId ?? this.oderId,
      userName: userName ?? this.userName,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      connectionState: connectionState ?? this.connectionState,
      isMuted: isMuted ?? this.isMuted,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      audioLevel: audioLevel ?? this.audioLevel,
      joinedAt: joinedAt ?? this.joinedAt,
      hasHandRaised: hasHandRaised ?? this.hasHandRaised,
      handRaisedAt: handRaisedAt ?? this.handRaisedAt,
      isCameraOn: isCameraOn ?? this.isCameraOn,
      isGhostMode: isGhostMode ?? this.isGhostMode,
    );
  }

  static ParticipantRole _parseRole(String role) {
    switch (role) {
      case 'host':
        return ParticipantRole.host;
      case 'coHost':
        return ParticipantRole.coHost;
      case 'speaker':
        return ParticipantRole.speaker;
      case 'moderator':
        return ParticipantRole.moderator;
      case 'listener':
      default:
        return ParticipantRole.listener;
    }
  }

  static ParticipantConnectionState _parseConnectionState(String state) {
    switch (state) {
      case 'connecting':
        return ParticipantConnectionState.connecting;
      case 'connected':
        return ParticipantConnectionState.connected;
      case 'disconnected':
        return ParticipantConnectionState.disconnected;
      case 'failed':
        return ParticipantConnectionState.failed;
      default:
        return ParticipantConnectionState.connected;
    }
  }

  @override
  List<Object?> get props => [
        oderId,
        userName,
        photoUrl,
        role,
        connectionState,
        isMuted,
        isSpeaking,
        audioLevel,
        joinedAt,
        hasHandRaised,
        handRaisedAt,
        isCameraOn,
        isGhostMode,
      ];
}
