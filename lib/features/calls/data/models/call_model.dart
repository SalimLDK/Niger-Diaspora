import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entities/call_entity.dart';

/// Modele de donnees pour un appel
class CallModel extends Equatable {
  final String id;
  final String callerId;
  final String callerName;
  final String? callerPhotoUrl;
  final String calleeId;
  final String calleeName;
  final String? calleePhotoUrl;
  final String type;
  final String status;
  final String createdAt;
  final String? answeredAt;
  final String? endedAt;
  final int? durationSeconds;
  final String? endReason;

  const CallModel({
    required this.id,
    required this.callerId,
    required this.callerName,
    this.callerPhotoUrl,
    required this.calleeId,
    required this.calleeName,
    this.calleePhotoUrl,
    this.type = 'audio',
    this.status = 'ringing',
    required this.createdAt,
    this.answeredAt,
    this.endedAt,
    this.durationSeconds,
    this.endReason,
  });

  factory CallModel.fromJson(Map<String, dynamic> json) {
    return CallModel(
      id: json['id'] as String? ?? '',
      callerId: json['callerId'] as String? ?? '',
      callerName: json['callerName'] as String? ?? '',
      callerPhotoUrl: json['callerPhotoUrl'] as String?,
      calleeId: json['calleeId'] as String? ?? '',
      calleeName: json['calleeName'] as String? ?? '',
      calleePhotoUrl: json['calleePhotoUrl'] as String?,
      type: json['type'] as String? ?? 'audio',
      status: json['status'] as String? ?? 'ringing',
      createdAt: _parseTimestamp(json['createdAt']),
      answeredAt: json['answeredAt'] != null
          ? _parseTimestamp(json['answeredAt'])
          : null,
      endedAt:
          json['endedAt'] != null ? _parseTimestamp(json['endedAt']) : null,
      durationSeconds: json['durationSeconds'] as int?,
      endReason: json['endReason'] as String?,
    );
  }
  factory CallModel.fromFirestore(DocumentSnapshot doc) {
    final rawData = doc.data() as Map<String, dynamic>? ?? {};
    final data = <String, dynamic>{'id': doc.id};
    rawData.forEach((key, value) {
      if (value is Timestamp) {
        data[key] = value.toDate().toIso8601String();
      } else {
        data[key] = value;
      }
    });
    return CallModel.fromJson(data);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'callerId': callerId,
      'callerName': callerName,
      'callerPhotoUrl': callerPhotoUrl,
      'calleeId': calleeId,
      'calleeName': calleeName,
      'calleePhotoUrl': calleePhotoUrl,
      'type': type,
      'status': status,
      'createdAt': createdAt,
      'answeredAt': answeredAt,
      'endedAt': endedAt,
      'durationSeconds': durationSeconds,
      'endReason': endReason,
    };
  }

  /// Create from Firestore document
  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'callerId': callerId,
      'callerName': callerName,
      'callerPhotoUrl': callerPhotoUrl,
      'calleeId': calleeId,
      'calleeName': calleeName,
      'calleePhotoUrl': calleePhotoUrl,
      'type': type,
      'status': status,
      'createdAt': FieldValue.serverTimestamp(),
      if (answeredAt != null) 'answeredAt': DateTime.parse(answeredAt!),
      if (endedAt != null) 'endedAt': DateTime.parse(endedAt!),
      if (durationSeconds != null) 'durationSeconds': durationSeconds,
      if (endReason != null) 'endReason': endReason,
    };
  }

  /// Convert to domain entity
  CallEntity toEntity() {
    return CallEntity(
      id: id,
      callerId: callerId,
      callerName: callerName,
      callerPhotoUrl: callerPhotoUrl,
      calleeId: calleeId,
      calleeName: calleeName,
      calleePhotoUrl: calleePhotoUrl,
      type: _parseCallType(type),
      status: _parseCallStatus(status),
      createdAt: DateTime.parse(createdAt),
      answeredAt: answeredAt != null ? DateTime.parse(answeredAt!) : null,
      endedAt: endedAt != null ? DateTime.parse(endedAt!) : null,
      durationSeconds: durationSeconds,
      endReason: endReason,
    );
  }

  /// Create from domain entity
  factory CallModel.fromEntity(CallEntity entity) {
    return CallModel(
      id: entity.id,
      callerId: entity.callerId,
      callerName: entity.callerName,
      callerPhotoUrl: entity.callerPhotoUrl,
      calleeId: entity.calleeId,
      calleeName: entity.calleeName,
      calleePhotoUrl: entity.calleePhotoUrl,
      type: entity.type.name,
      status: entity.status.name,
      createdAt: entity.createdAt.toIso8601String(),
      answeredAt: entity.answeredAt?.toIso8601String(),
      endedAt: entity.endedAt?.toIso8601String(),
      durationSeconds: entity.durationSeconds,
      endReason: entity.endReason,
    );
  }

  CallModel copyWith({
    String? id,
    String? callerId,
    String? callerName,
    String? callerPhotoUrl,
    String? calleeId,
    String? calleeName,
    String? calleePhotoUrl,
    String? type,
    String? status,
    String? createdAt,
    String? answeredAt,
    String? endedAt,
    int? durationSeconds,
    String? endReason,
  }) {
    return CallModel(
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

  static String _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) {
      return DateTime.now().toIso8601String();
    }
    if (timestamp is Timestamp) {
      return timestamp.toDate().toIso8601String();
    }
    if (timestamp is String) {
      return timestamp;
    }
    return DateTime.now().toIso8601String();
  }

  static CallType _parseCallType(String type) {
    switch (type) {
      case 'video':
        return CallType.video;
      case 'audio':
      default:
        return CallType.audio;
    }
  }

  static CallStatus _parseCallStatus(String status) {
    switch (status) {
      case 'ringing':
        return CallStatus.ringing;
      case 'connecting':
        return CallStatus.connecting;
      case 'connected':
        return CallStatus.connected;
      case 'ended':
        return CallStatus.ended;
      case 'declined':
        return CallStatus.declined;
      case 'missed':
        return CallStatus.missed;
      case 'busy':
        return CallStatus.busy;
      default:
        return CallStatus.ringing;
    }
  }

  @override
  List<Object?> get props => [
        id,
        callerId,
        callerName,
        callerPhotoUrl,
        calleeId,
        calleeName,
        calleePhotoUrl,
        type,
        status,
        createdAt,
        answeredAt,
        endedAt,
        durationSeconds,
        endReason,
      ];
}
