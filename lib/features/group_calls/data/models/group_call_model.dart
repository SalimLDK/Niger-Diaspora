import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entities/group_call_entity.dart';

class GroupCallModel extends Equatable {
  final String id;
  final String name;
  final String hostId;
  final String hostName;
  final String? hostPhotoUrl;
  final List<String> participantIds;
  final int participantCount;
  final int maxParticipants;
  final String type;
  final String status;
  final String mode;
  final bool isE2EEEnabled;
  final String? e2eeKeyId;
  final String createdAt;
  final String? startedAt;
  final String? endedAt;
  final int? durationSeconds;
  final String? livekitRoomName;
  final String? groupId;
  final String? conversationId;

  const GroupCallModel({
    required this.id,
    required this.name,
    required this.hostId,
    required this.hostName,
    this.hostPhotoUrl,
    this.participantIds = const [],
    this.participantCount = 0,
    this.maxParticipants = 10,
    this.type = 'audio',
    this.status = 'waiting',
    this.mode = 'mesh',
    this.isE2EEEnabled = true,
    this.e2eeKeyId,
    required this.createdAt,
    this.startedAt,
    this.endedAt,
    this.durationSeconds,
    this.livekitRoomName,
    this.groupId,
    this.conversationId,
  });

  factory GroupCallModel.fromJson(Map<String, dynamic> json) {
    return GroupCallModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      hostId: json['hostId'] as String? ?? '',
      hostName: json['hostName'] as String? ?? '',
      hostPhotoUrl: json['hostPhotoUrl'] as String?,
      participantIds: List<String>.from(json['participantIds'] ?? []),
      participantCount: json['participantCount'] as int? ?? 0,
      maxParticipants: json['maxParticipants'] as int? ?? 10,
      type: json['type'] as String? ?? 'audio',
      status: json['status'] as String? ?? 'waiting',
      mode: json['mode'] as String? ?? 'mesh',
      isE2EEEnabled: json['isE2EEEnabled'] as bool? ?? true,
      e2eeKeyId: json['e2eeKeyId'] as String?,
      createdAt: _timestampToString(json['createdAt']) ?? DateTime.now().toIso8601String(),
      startedAt: _timestampToString(json['startedAt']),
      endedAt: _timestampToString(json['endedAt']),
      durationSeconds: json['durationSeconds'] as int?,
      livekitRoomName: json['livekitRoomName'] as String?,
      groupId: json['groupId'] as String?,
      conversationId: json['conversationId'] as String?,
    );
  }
  factory GroupCallModel.fromFirestore(DocumentSnapshot doc) {
    final rawData = doc.data() as Map<String, dynamic>? ?? {};
    final data = <String, dynamic>{'id': doc.id};
    rawData.forEach((key, value) {
      if (value is Timestamp) {
        data[key] = value.toDate().toIso8601String();
      } else {
        data[key] = value;
      }
    });
    return GroupCallModel.fromJson(data);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'hostId': hostId,
      'hostName': hostName,
      'hostPhotoUrl': hostPhotoUrl,
      'participantIds': participantIds,
      'participantCount': participantCount,
      'maxParticipants': maxParticipants,
      'type': type,
      'status': status,
      'mode': mode,
      'isE2EEEnabled': isE2EEEnabled,
      'e2eeKeyId': e2eeKeyId,
      'createdAt': createdAt,
      'startedAt': startedAt,
      'endedAt': endedAt,
      'durationSeconds': durationSeconds,
      'livekitRoomName': livekitRoomName,
      'groupId': groupId,
      'conversationId': conversationId,
    };
  }
  Map<String, dynamic> toFirestore() {
    final json = toJson();
    json.remove('id');
    return {
      ...json,
      'createdAt': FieldValue.serverTimestamp(),
      if (startedAt != null) 'startedAt': DateTime.parse(startedAt!),
      if (endedAt != null) 'endedAt': DateTime.parse(endedAt!),
    };
  }

  GroupCallEntity toEntity() {
    return GroupCallEntity(
      id: id,
      name: name,
      hostId: hostId,
      hostName: hostName,
      hostPhotoUrl: hostPhotoUrl,
      participantIds: participantIds,
      participantCount: participantCount,
      maxParticipants: maxParticipants,
      type: _parseCallType(type),
      status: _parseStatus(status),
      mode: _parseMode(mode),
      isE2EEEnabled: isE2EEEnabled,
      e2eeKeyId: e2eeKeyId,
      createdAt: DateTime.parse(createdAt).toLocal(),
      startedAt: startedAt != null ? DateTime.parse(startedAt!).toLocal() : null,
      endedAt: endedAt != null ? DateTime.parse(endedAt!).toLocal() : null,
      durationSeconds: durationSeconds,
      livekitRoomName: livekitRoomName,
      groupId: groupId,
      conversationId: conversationId,
    );
  }

  static GroupCallModel fromEntity(GroupCallEntity entity) {
    return GroupCallModel(
      id: entity.id,
      name: entity.name,
      hostId: entity.hostId,
      hostName: entity.hostName,
      hostPhotoUrl: entity.hostPhotoUrl,
      participantIds: entity.participantIds,
      participantCount: entity.participantCount,
      maxParticipants: entity.maxParticipants,
      type: entity.type.name,
      status: entity.status.name,
      mode: entity.mode.name,
      isE2EEEnabled: entity.isE2EEEnabled,
      e2eeKeyId: entity.e2eeKeyId,
      createdAt: entity.createdAt.toIso8601String(),
      startedAt: entity.startedAt?.toIso8601String(),
      endedAt: entity.endedAt?.toIso8601String(),
      durationSeconds: entity.durationSeconds,
      livekitRoomName: entity.livekitRoomName,
      groupId: entity.groupId,
      conversationId: entity.conversationId,
    );
  }

  GroupCallModel copyWith({
    String? id,
    String? name,
    String? hostId,
    String? hostName,
    String? hostPhotoUrl,
    List<String>? participantIds,
    int? participantCount,
    int? maxParticipants,
    String? type,
    String? status,
    String? mode,
    bool? isE2EEEnabled,
    String? e2eeKeyId,
    String? createdAt,
    String? startedAt,
    String? endedAt,
    int? durationSeconds,
    String? livekitRoomName,
    String? groupId,
    String? conversationId,
  }) {
    return GroupCallModel(
      id: id ?? this.id,
      name: name ?? this.name,
      hostId: hostId ?? this.hostId,
      hostName: hostName ?? this.hostName,
      hostPhotoUrl: hostPhotoUrl ?? this.hostPhotoUrl,
      participantIds: participantIds ?? this.participantIds,
      participantCount: participantCount ?? this.participantCount,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      type: type ?? this.type,
      status: status ?? this.status,
      mode: mode ?? this.mode,
      isE2EEEnabled: isE2EEEnabled ?? this.isE2EEEnabled,
      e2eeKeyId: e2eeKeyId ?? this.e2eeKeyId,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      livekitRoomName: livekitRoomName ?? this.livekitRoomName,
      groupId: groupId ?? this.groupId,
      conversationId: conversationId ?? this.conversationId,
    );
  }

  static String? _timestampToString(dynamic timestamp) {
    if (timestamp == null) return null;
    if (timestamp is Timestamp) {
      return timestamp.toDate().toIso8601String();
    }
    if (timestamp is String) return timestamp;
    return null;
  }

  static GroupCallType _parseCallType(String type) {
    return switch (type) {
      'video' => GroupCallType.video,
      _ => GroupCallType.audio,
    };
  }

  static GroupCallStatus _parseStatus(String status) {
    return switch (status) {
      'active' => GroupCallStatus.active,
      'ended' => GroupCallStatus.ended,
      _ => GroupCallStatus.waiting,
    };
  }

  static GroupCallMode _parseMode(String mode) {
    return switch (mode) {
      'sfu' => GroupCallMode.sfu,
      _ => GroupCallMode.mesh,
    };
  }

  @override
  List<Object?> get props => [
        id,
        name,
        hostId,
        participantIds,
        participantCount,
        type,
        status,
        mode,
        createdAt,
      ];
}
