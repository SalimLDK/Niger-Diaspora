import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/conversation_entity.dart';
import '../../domain/entities/message_entity.dart';

part 'conversation_model.freezed.dart';
part 'conversation_model.g.dart';

@freezed
class ConversationModel with _$ConversationModel {
  const ConversationModel._();

  const factory ConversationModel({
    required String id,
    @Default('individual') String type,
    String? name,
    String? imageUrl,
    String? groupId, // Add groupId for group conversations
    @Default([]) List<String> participantIds,
    @Default([]) List<String> adminIds,
    @Default([]) List<String> reportedBy,
    String? lastMessage,
    String? lastMessageSenderId,
    @Default(MessageStatus.sent) MessageStatus lastMessageStatus,
    DateTime? lastMessageAt,
    DateTime? createdAt,
    required String createdBy,
    @Default({}) Map<String, dynamic> unreadCount,
    @Default({}) Map<String, dynamic> mutedBy,
    @Default({}) Map<String, dynamic> archivedBy,
  }) = _ConversationModel;

  factory ConversationModel.fromJson(Map<String, dynamic> json) =>
      _$ConversationModelFromJson(json);

  factory ConversationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ConversationModel.fromJson({
      ...data,
      'id': doc.id,
      'createdAt': _timestampToIso(data['createdAt']),
      'lastMessageAt': _timestampToIso(data['lastMessageAt']),
      'unreadCount': _convertUnreadCount(data['unreadCount']),
      'mutedBy': _convertBoolMap(data['mutedBy']),
      'archivedBy': _convertBoolMap(data['archivedBy']),
      'lastMessageStatus': _parseMessageStatus(data['lastMessageStatus']),
      'adminIds': (data['adminIds'] as List<dynamic>?)?.cast<String>() ?? [],
      'reportedBy':
          (data['reportedBy'] as List<dynamic>?)?.cast<String>() ?? [],
    });
  }

  static String _parseMessageStatus(dynamic status) {
    if (status is String) return status;
    if (status is int && status < MessageStatus.values.length) {
      return MessageStatus.values[status].name;
    }
    return MessageStatus.sent.name;
  }

  static Map<String, dynamic> _convertBoolMap(dynamic data) {
    if (data == null) return {};
    if (data is! Map) return {};

    final Map<String, dynamic> result = {};
    data.forEach((key, value) {
      result[key.toString()] = value;
    });
    return result;
  }

  Map<String, dynamic> toFirestore() {
    final json = toJson();
    json.remove('id');
    json['createdAt'] = FieldValue.serverTimestamp();

    if (lastMessageAt != null) {
      json['lastMessageAt'] = Timestamp.fromDate(lastMessageAt!);
    }

    json['lastMessageStatus'] = lastMessageStatus.name;

    return json;
  }

  ConversationEntity toEntity() => ConversationEntity(
    id: id,
    type: _parseConversationType(type),
    name: name,
    imageUrl: imageUrl,
    groupId: groupId, // Include groupId
    participantIds: participantIds,
    adminIds: adminIds,
    reportedBy: reportedBy,
    lastMessage: lastMessage,
    lastMessageSenderId: lastMessageSenderId,
    lastMessageStatus: lastMessageStatus,
    lastMessageAt: lastMessageAt,
    createdAt: createdAt ?? DateTime.now(),
    createdBy: createdBy,
    unreadCount: _parseUnreadCount(unreadCount),
    mutedBy: _parseBoolMap(mutedBy),
    archivedBy: _parseBoolMap(archivedBy),
  );

  factory ConversationModel.fromEntity(ConversationEntity entity) =>
      ConversationModel(
        id: entity.id,
        type: entity.type.name,
        name: entity.name,
        imageUrl: entity.imageUrl,
        groupId: entity.groupId, // Include groupId
        participantIds: entity.participantIds,
        adminIds: entity.adminIds,
        reportedBy: entity.reportedBy,
        lastMessage: entity.lastMessage,
        lastMessageSenderId: entity.lastMessageSenderId,
        lastMessageStatus: entity.lastMessageStatus ?? MessageStatus.sent,
        lastMessageAt: entity.lastMessageAt,
        createdAt: entity.createdAt,
        createdBy: entity.createdBy,
        unreadCount: entity.unreadCount.map((k, v) => MapEntry(k, v)),
        mutedBy: entity.mutedBy.map((k, v) => MapEntry(k, v)),
        archivedBy: entity.archivedBy.map((k, v) => MapEntry(k, v)),
      );

  static ConversationType _parseConversationType(String value) {
    return ConversationType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ConversationType.individual,
    );
  }

  static Map<String, int> _parseUnreadCount(Map<String, dynamic> data) {
    final Map<String, int> result = {};
    data.forEach((key, value) {
      if (value is int) {
        result[key] = value;
      } else if (value is num) {
        result[key] = value.toInt();
      }
    });
    return result;
  }

  static String? _timestampToIso(dynamic timestamp) {
    if (timestamp == null) return null;
    if (timestamp is Timestamp) {
      return timestamp.toDate().toIso8601String();
    }
    if (timestamp is String) return timestamp;
    return null;
  }

  static Map<String, dynamic> _convertUnreadCount(dynamic data) {
    if (data == null) return {};
    if (data is! Map) return {};

    final Map<String, dynamic> result = {};
    data.forEach((key, value) {
      result[key.toString()] = value;
    });
    return result;
  }

  static Map<String, bool> _parseBoolMap(Map<String, dynamic> data) {
    final Map<String, bool> result = {};
    data.forEach((key, value) {
      if (value is bool) {
        result[key] = value;
      }
    });
    return result;
  }
}
