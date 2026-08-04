import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entities/group_participant_entity.dart';

class GroupParticipantModel extends Equatable {
  final String oderId;
  final String displayName;
  final String? photoUrl;
  final String role;
  final String connectionState;
  final bool isMuted;
  final bool isCameraOff;
  final bool isSpeaking;
  final bool hasHandRaised;
  final bool isScreenSharing;
  final String videoQuality;
  final double audioLevel;
  final int networkQuality;
  final String joinedAt;
  final String? leftAt;

  const GroupParticipantModel({
    required this.oderId,
    required this.displayName,
    this.photoUrl,
    this.role = 'participant',
    this.connectionState = 'connecting',
    this.isMuted = false,
    this.isCameraOff = true,
    this.isSpeaking = false,
    this.hasHandRaised = false,
    this.isScreenSharing = false,
    this.videoQuality = 'medium',
    this.audioLevel = 0.0,
    this.networkQuality = 0,
    required this.joinedAt,
    this.leftAt,
  });

  factory GroupParticipantModel.fromJson(Map<String, dynamic> json) {
    return GroupParticipantModel(
      oderId: json['oderId'] as String? ?? json['userId'] as String? ?? '',
      displayName: json['displayName'] as String? ?? 'Unknown',
      photoUrl: json['photoUrl'] as String?,
      role: json['role'] as String? ?? 'participant',
      connectionState: json['connectionState'] as String? ?? 'connecting',
      isMuted: json['isMuted'] as bool? ?? false,
      isCameraOff: json['isCameraOff'] as bool? ?? true,
      isSpeaking: json['isSpeaking'] as bool? ?? false,
      hasHandRaised: json['hasHandRaised'] as bool? ?? false,
      isScreenSharing: json['isScreenSharing'] as bool? ?? false,
      videoQuality: json['videoQuality'] as String? ?? 'medium',
      audioLevel: (json['audioLevel'] as num?)?.toDouble() ?? 0.0,
      networkQuality: json['networkQuality'] as int? ?? 0,
      joinedAt: _timestampToString(json['joinedAt']) ?? DateTime.now().toUtc().toIso8601String(),
      leftAt: _timestampToString(json['leftAt']),
    );
  }
  factory GroupParticipantModel.fromFirestore(DocumentSnapshot doc) {
    final rawData = doc.data() as Map<String, dynamic>? ?? {};
    final data = <String, dynamic>{'id': doc.id};
    rawData.forEach((key, value) {
      if (value is Timestamp) {
        data[key] = value.toDate().toUtc().toIso8601String();
      } else {
        data[key] = value;
      }
    });
    return GroupParticipantModel.fromJson(data);
  }

  Map<String, dynamic> toJson() {
    return {
      'oderId': oderId,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'role': role,
      'connectionState': connectionState,
      'isMuted': isMuted,
      'isCameraOff': isCameraOff,
      'isSpeaking': isSpeaking,
      'hasHandRaised': hasHandRaised,
      'isScreenSharing': isScreenSharing,
      'videoQuality': videoQuality,
      'audioLevel': audioLevel,
      'networkQuality': networkQuality,
      'joinedAt': joinedAt,
      'leftAt': leftAt,
    };
  }
  factory GroupParticipantModel.fromRealtimeDb(String oderId, Map<dynamic, dynamic> data) {
    return GroupParticipantModel(
      oderId: oderId,
      displayName: data['displayName'] as String? ?? 'Unknown',
      photoUrl: data['photoUrl'] as String?,
      role: data['role'] as String? ?? 'participant',
      connectionState: data['connectionState'] as String? ?? 'connecting',
      isMuted: data['isMuted'] as bool? ?? false,
      isCameraOff: data['isCameraOff'] as bool? ?? true,
      isSpeaking: data['isSpeaking'] as bool? ?? false,
      hasHandRaised: data['hasHandRaised'] as bool? ?? false,
      isScreenSharing: data['isScreenSharing'] as bool? ?? false,
      videoQuality: data['videoQuality'] as String? ?? 'medium',
      audioLevel: (data['audioLevel'] as num?)?.toDouble() ?? 0.0,
      networkQuality: data['networkQuality'] as int? ?? 0,
      joinedAt: data['joinedAt'] as String? ?? DateTime.now().toUtc().toIso8601String(),
      leftAt: data['leftAt'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    final json = toJson();
    json.remove('oderId');
    return {
      ...json,
      'joinedAt': DateTime.parse(joinedAt),
      if (leftAt != null) 'leftAt': DateTime.parse(leftAt!),
    };
  }

  Map<String, dynamic> toRealtimeDb() {
    return {
      'displayName': displayName,
      'photoUrl': photoUrl,
      'role': role,
      'connectionState': connectionState,
      'isMuted': isMuted,
      'isCameraOff': isCameraOff,
      'isSpeaking': isSpeaking,
      'hasHandRaised': hasHandRaised,
      'isScreenSharing': isScreenSharing,
      'videoQuality': videoQuality,
      'audioLevel': audioLevel,
      'networkQuality': networkQuality,
      'joinedAt': joinedAt,
      if (leftAt != null) 'leftAt': leftAt,
    };
  }

  GroupParticipantEntity toEntity() {
    return GroupParticipantEntity(
      oderId: oderId,
      displayName: displayName,
      photoUrl: photoUrl,
      role: _parseRole(role),
      connectionState: _parseConnectionState(connectionState),
      isMuted: isMuted,
      isCameraOff: isCameraOff,
      isSpeaking: isSpeaking,
      hasHandRaised: hasHandRaised,
      isScreenSharing: isScreenSharing,
      videoQuality: _parseVideoQuality(videoQuality),
      audioLevel: audioLevel,
      networkQuality: networkQuality,
      joinedAt: DateTime.parse(joinedAt).toLocal(),
      leftAt: leftAt != null ? DateTime.parse(leftAt!).toLocal() : null,
    );
  }

  static GroupParticipantModel fromEntity(GroupParticipantEntity entity) {
    return GroupParticipantModel(
      oderId: entity.oderId,
      displayName: entity.displayName,
      photoUrl: entity.photoUrl,
      role: entity.role.name,
      connectionState: entity.connectionState.name,
      isMuted: entity.isMuted,
      isCameraOff: entity.isCameraOff,
      isSpeaking: entity.isSpeaking,
      hasHandRaised: entity.hasHandRaised,
      isScreenSharing: entity.isScreenSharing,
      videoQuality: entity.videoQuality.name,
      audioLevel: entity.audioLevel,
      networkQuality: entity.networkQuality,
      joinedAt: entity.joinedAt.toUtc().toIso8601String(),
      leftAt: entity.leftAt?.toUtc().toIso8601String(),
    );
  }

  GroupParticipantModel copyWith({
    String? oderId,
    String? displayName,
    String? photoUrl,
    String? role,
    String? connectionState,
    bool? isMuted,
    bool? isCameraOff,
    bool? isSpeaking,
    bool? hasHandRaised,
    bool? isScreenSharing,
    String? videoQuality,
    double? audioLevel,
    int? networkQuality,
    String? joinedAt,
    String? leftAt,
  }) {
    return GroupParticipantModel(
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

  static String? _timestampToString(dynamic timestamp) {
    if (timestamp == null) return null;
    if (timestamp is Timestamp) {
      return timestamp.toDate().toUtc().toIso8601String();
    }
    if (timestamp is String) return timestamp;
    return null;
  }

  static GroupParticipantRole _parseRole(String role) {
    return switch (role) {
      'host' => GroupParticipantRole.host,
      _ => GroupParticipantRole.participant,
    };
  }

  static ParticipantConnectionState _parseConnectionState(String state) {
    return switch (state) {
      'connected' => ParticipantConnectionState.connected,
      'reconnecting' => ParticipantConnectionState.reconnecting,
      'disconnected' => ParticipantConnectionState.disconnected,
      _ => ParticipantConnectionState.connecting,
    };
  }

  static VideoQuality _parseVideoQuality(String quality) {
    return switch (quality) {
      'low' => VideoQuality.low,
      'high' => VideoQuality.high,
      _ => VideoQuality.medium,
    };
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
        joinedAt,
      ];
}
