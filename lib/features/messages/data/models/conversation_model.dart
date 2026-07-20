import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/conversation_entity.dart';
import '../../domain/entities/message_entity.dart';

/// Model de conversation pour la couche data
/// Converti depuis/vers Firestore
final class ConversationModel {
  final String id;
  final String type;
  final String? name;
  final String? imageUrl;
  final String? groupId;
  final List<String> participantIds;
  final List<String> adminIds;
  final List<String> reportedBy;
  final String? lastMessage;
  final String? lastMessageSenderId;
  final MessageStatus lastMessageStatus;
  final MessageType? lastMessageType;
  final DateTime? lastMessageAt;
  final List<String> lastMessageReadBy;
  final List<String> lastMessageDeliveredTo;
  final DateTime? createdAt;
  final String createdBy;
  final Map<String, dynamic> unreadCount;
  final Map<String, dynamic> unreadMentions;
  final Map<String, dynamic> mutedBy;
  final Map<String, dynamic> archivedBy;
  final Map<String, dynamic> pinnedBy;
  final Map<String, dynamic> deletedBy;
  final int? autoDeleteAfterSeconds;

  /// Message request status: 'none', 'pending', 'accepted', 'declined'
  final String requestStatus;

  /// User ID who initiated the message request
  final String? requesterId;

  /// When the message request was created
  final DateTime? requestedAt;

  /// When the message request was accepted or declined
  final DateTime? respondedAt;

  const ConversationModel({
    required this.id,
    this.type = 'individual',
    this.name,
    this.imageUrl,
    this.groupId,
    this.participantIds = const [],
    this.adminIds = const [],
    this.reportedBy = const [],
    this.lastMessage,
    this.lastMessageSenderId,
    this.lastMessageStatus = MessageStatus.sent,
    this.lastMessageType,
    this.lastMessageAt,
    this.lastMessageReadBy = const [],
    this.lastMessageDeliveredTo = const [],
    this.createdAt,
    required this.createdBy,
    this.unreadCount = const {},
    this.unreadMentions = const {},
    this.mutedBy = const {},
    this.archivedBy = const {},
    this.pinnedBy = const {},
    this.deletedBy = const {},
    this.autoDeleteAfterSeconds,
    this.requestStatus = 'none',
    this.requesterId,
    this.requestedAt,
    this.respondedAt,
  });

  /// Creer depuis JSON
  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'individual',
      name: json['name'] as String?,
      imageUrl: json['imageUrl'] as String?,
      groupId: json['groupId'] as String?,
      participantIds: _parseStringList(json['participantIds']),
      adminIds: _parseStringList(json['adminIds']),
      reportedBy: _parseStringList(json['reportedBy']),
      lastMessage: json['lastMessage'] as String?,
      lastMessageSenderId: json['lastMessageSenderId'] as String?,
      lastMessageStatus: _parseMessageStatusFromJson(json['lastMessageStatus']),
      lastMessageType: _parseMessageTypeFromJson(json['lastMessageType']),
      lastMessageAt: _parseDateTime(json['lastMessageAt']),
      lastMessageReadBy: _parseStringList(json['lastMessageReadBy']),
      lastMessageDeliveredTo: _parseStringList(json['lastMessageDeliveredTo']),
      createdAt: _parseDateTime(json['createdAt']),
      createdBy: json['createdBy'] as String? ?? '',
      unreadCount: _parseMap(json['unreadCount']),
      unreadMentions: _parseMap(json['unreadMentions']),
      mutedBy: _parseMap(json['mutedBy']),
      archivedBy: _parseMap(json['archivedBy']),
      pinnedBy: _parseMap(json['pinnedBy']),
      deletedBy: _parseMap(json['deletedBy']),
      autoDeleteAfterSeconds: json['autoDeleteAfterSeconds'] as int?,
      requestStatus: json['requestStatus'] as String? ?? 'none',
      requesterId: json['requesterId'] as String?,
      requestedAt: _parseDateTime(json['requestedAt']),
      respondedAt: _parseDateTime(json['respondedAt']),
    );
  }
  factory ConversationModel.fromFirestore(DocumentSnapshot doc) {
    final rawData = doc.data() as Map<String, dynamic>? ?? {};
    final data = <String, dynamic>{'id': doc.id};
    rawData.forEach((key, value) {
      if (value is Timestamp) {
        data[key] = value.toDate().toIso8601String();
      } else {
        data[key] = value;
      }
    });
    return ConversationModel.fromJson(data);
  }

  /// Convertir en JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      if (name != null) 'name': name,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (groupId != null) 'groupId': groupId,
      'participantIds': participantIds,
      if (adminIds.isNotEmpty) 'adminIds': adminIds,
      if (reportedBy.isNotEmpty) 'reportedBy': reportedBy,
      if (lastMessage != null) 'lastMessage': lastMessage,
      if (lastMessageSenderId != null) 'lastMessageSenderId': lastMessageSenderId,
      'lastMessageStatus': lastMessageStatus.name,
      if (lastMessageType != null) 'lastMessageType': lastMessageType!.name,
      if (lastMessageAt != null) 'lastMessageAt': lastMessageAt!.toIso8601String(),
      if (lastMessageReadBy.isNotEmpty) 'lastMessageReadBy': lastMessageReadBy,
      if (lastMessageDeliveredTo.isNotEmpty) 'lastMessageDeliveredTo': lastMessageDeliveredTo,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      'createdBy': createdBy,
      if (unreadCount.isNotEmpty) 'unreadCount': unreadCount,
      if (unreadMentions.isNotEmpty) 'unreadMentions': unreadMentions,
      if (mutedBy.isNotEmpty) 'mutedBy': mutedBy,
      if (archivedBy.isNotEmpty) 'archivedBy': archivedBy,
      if (pinnedBy.isNotEmpty) 'pinnedBy': pinnedBy,
      if (deletedBy.isNotEmpty) 'deletedBy': deletedBy,
      if (autoDeleteAfterSeconds != null)
        'autoDeleteAfterSeconds': autoDeleteAfterSeconds,
      'requestStatus': requestStatus,
      if (requesterId != null) 'requesterId': requesterId,
      if (requestedAt != null) 'requestedAt': requestedAt!.toIso8601String(),
      if (respondedAt != null) 'respondedAt': respondedAt!.toIso8601String(),
    };
  }

  /// Creer depuis un DocumentSnapshot Firestore
  /// Convertir pour Firestore
  Map<String, dynamic> toFirestore() {
    final json = toJson();
    json.remove('id');
    json['createdAt'] = FieldValue.serverTimestamp();

    if (lastMessageAt != null) {
      json['lastMessageAt'] = lastMessageAt!.toIso8601String();
    }

    json['lastMessageStatus'] = lastMessageStatus.name;

    // Handle request timestamps
    if (requestedAt != null) {
      json['requestedAt'] = requestedAt!.toIso8601String();
    }
    if (respondedAt != null) {
      json['respondedAt'] = respondedAt!.toIso8601String();
    }

    return json;
  }

  /// Convertir en entite de domaine
  ConversationEntity toEntity() => ConversationEntity(
    id: id,
    type: _parseConversationType(type),
    name: name,
    imageUrl: imageUrl,
    groupId: groupId,
    participantIds: participantIds,
    adminIds: adminIds,
    reportedBy: reportedBy,
    lastMessage: lastMessage,
    lastMessageSenderId: lastMessageSenderId,
    lastMessageStatus: lastMessageStatus,
    lastMessageType: lastMessageType,
    lastMessageAt: lastMessageAt,
    lastMessageReadBy: lastMessageReadBy,
    lastMessageDeliveredTo: lastMessageDeliveredTo,
    createdAt: createdAt ?? DateTime.now(),
    createdBy: createdBy,
    unreadCount: _parseUnreadCount(unreadCount),
    unreadMentions: _parseUnreadCount(unreadMentions),
    mutedBy: _parseMutedByMap(mutedBy),
    archivedBy: _parseBoolMap(archivedBy),
    pinnedBy: _parseDateTimeMap(pinnedBy),
    deletedBy: _parseDateTimeMap(deletedBy),
    autoDeleteAfterSeconds: autoDeleteAfterSeconds,
    requestStatus: _parseRequestStatus(requestStatus),
    requesterId: requesterId,
    requestedAt: requestedAt,
    respondedAt: respondedAt,
  );

  /// Creer depuis une entite de domaine
  factory ConversationModel.fromEntity(ConversationEntity entity) =>
      ConversationModel(
        id: entity.id,
        type: entity.type.name,
        name: entity.name,
        imageUrl: entity.imageUrl,
        groupId: entity.groupId,
        participantIds: entity.participantIds,
        adminIds: entity.adminIds,
        reportedBy: entity.reportedBy,
        lastMessage: entity.lastMessage,
        lastMessageSenderId: entity.lastMessageSenderId,
        lastMessageStatus: entity.lastMessageStatus ?? MessageStatus.sent,
        lastMessageType: entity.lastMessageType,
        lastMessageAt: entity.lastMessageAt,
        lastMessageReadBy: entity.lastMessageReadBy,
        lastMessageDeliveredTo: entity.lastMessageDeliveredTo,
        createdAt: entity.createdAt,
        createdBy: entity.createdBy,
        unreadCount: entity.unreadCount.map((k, v) => MapEntry(k, v)),
        unreadMentions: entity.unreadMentions.map((k, v) => MapEntry(k, v)),
        mutedBy: entity.mutedBy.map((k, v) => MapEntry(k, v?.toIso8601String() ?? 'forever')),
        archivedBy: entity.archivedBy.map((k, v) => MapEntry(k, v)),
        pinnedBy: entity.pinnedBy.map(
          (k, v) => MapEntry(k, v.toIso8601String()),
        ),
        deletedBy: entity.deletedBy.map(
          (k, v) => MapEntry(k, v.toIso8601String()),
        ),
        autoDeleteAfterSeconds: entity.autoDeleteAfterSeconds,
        requestStatus: entity.requestStatus.name,
        requesterId: entity.requesterId,
        requestedAt: entity.requestedAt,
        respondedAt: entity.respondedAt,
      );

  /// Copier avec modifications
  ConversationModel copyWith({
    String? id,
    String? type,
    String? name,
    String? imageUrl,
    String? groupId,
    List<String>? participantIds,
    List<String>? adminIds,
    List<String>? reportedBy,
    String? lastMessage,
    String? lastMessageSenderId,
    MessageStatus? lastMessageStatus,
    MessageType? lastMessageType,
    DateTime? lastMessageAt,
    List<String>? lastMessageReadBy,
    List<String>? lastMessageDeliveredTo,
    DateTime? createdAt,
    String? createdBy,
    Map<String, dynamic>? unreadCount,
    Map<String, dynamic>? unreadMentions,
    Map<String, dynamic>? mutedBy,
    Map<String, dynamic>? archivedBy,
    Map<String, dynamic>? pinnedBy,
    Map<String, dynamic>? deletedBy,
    int? autoDeleteAfterSeconds,
    String? requestStatus,
    String? requesterId,
    DateTime? requestedAt,
    DateTime? respondedAt,
  }) {
    return ConversationModel(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      groupId: groupId ?? this.groupId,
      participantIds: participantIds ?? this.participantIds,
      adminIds: adminIds ?? this.adminIds,
      reportedBy: reportedBy ?? this.reportedBy,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      lastMessageStatus: lastMessageStatus ?? this.lastMessageStatus,
      lastMessageType: lastMessageType ?? this.lastMessageType,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastMessageReadBy: lastMessageReadBy ?? this.lastMessageReadBy,
      lastMessageDeliveredTo: lastMessageDeliveredTo ?? this.lastMessageDeliveredTo,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      unreadCount: unreadCount ?? this.unreadCount,
      unreadMentions: unreadMentions ?? this.unreadMentions,
      mutedBy: mutedBy ?? this.mutedBy,
      archivedBy: archivedBy ?? this.archivedBy,
      pinnedBy: pinnedBy ?? this.pinnedBy,
      deletedBy: deletedBy ?? this.deletedBy,
      autoDeleteAfterSeconds:
          autoDeleteAfterSeconds ?? this.autoDeleteAfterSeconds,
      requestStatus: requestStatus ?? this.requestStatus,
      requesterId: requesterId ?? this.requesterId,
      requestedAt: requestedAt ?? this.requestedAt,
      respondedAt: respondedAt ?? this.respondedAt,
    );
  }

  // ============ Helpers de parsing ============

  static List<String> _parseStringList(dynamic data) {
    if (data == null) return [];
    if (data is List) {
      return data.map((e) => e.toString()).toList();
    }
    return [];
  }

  static Map<String, dynamic> _parseMap(dynamic data) {
    if (data == null) return {};
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return {};
  }

  static DateTime? _parseDateTime(dynamic data) {
    if (data == null) return null;
    if (data is DateTime) return data;
    if (data is String) {
      return DateTime.tryParse(data);
    }
    if (data is Timestamp) {
      return data.toDate();
    }
    return null;
  }

  static MessageStatus _parseMessageStatusFromJson(dynamic status) {
    if (status == null) return MessageStatus.sent;
    if (status is String) {
      return MessageStatus.values.firstWhere(
        (e) => e.name == status,
        orElse: () => MessageStatus.sent,
      );
    }
    if (status is int && status < MessageStatus.values.length) {
      return MessageStatus.values[status];
    }
    return MessageStatus.sent;
  }

  static MessageType? _parseMessageTypeFromJson(dynamic type) {
    if (type == null) return null;
    if (type is String) {
      if (type == 'voiceNote') return MessageType.voiceNote;
      if (type == 'audioFile') return MessageType.audio;
      // Backward compatibility: legacy voice messages used 'audio'.
      if (type == 'audio') return MessageType.voiceNote;
      return MessageType.values.firstWhere(
        (e) => e.name == type,
        orElse: () => MessageType.text,
      );
    }
    if (type is int && type < MessageType.values.length) {
      return MessageType.values[type];
    }
    return null;
  }
  static ConversationType _parseConversationType(String value) {
    return ConversationType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ConversationType.individual,
    );
  }

  static ConversationRequestStatus _parseRequestStatus(String value) {
    return ConversationRequestStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ConversationRequestStatus.none,
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
  static Map<String, bool> _parseBoolMap(Map<String, dynamic> data) {
    final Map<String, bool> result = {};
    data.forEach((key, value) {
      if (value is bool) {
        result[key] = value;
      }
    });
    return result;
  }

  /// Parse mutedBy map - supports both old format (bool) and new format (DateTime?)
  /// Old: { "userId": true } -> muted forever
  /// New: { "userId": "2024-03-15T22:00:00.000Z" } -> muted until date
  /// New: { "userId": null } or { "userId": "forever" } -> muted forever
  static Map<String, DateTime?> _parseMutedByMap(Map<String, dynamic> data) {
    final Map<String, DateTime?> result = {};
    data.forEach((key, value) {
      if (value == true || value == null || value == 'forever') {
        // Muted forever
        result[key] = null;
      } else if (value == false) {
        // Not muted - don't add to map
      } else if (value is Timestamp) {
        result[key] = value.toDate();
      } else if (value is String) {
        final dt = DateTime.tryParse(value);
        if (dt != null) {
          result[key] = dt;
        } else {
          // Invalid date string, treat as forever
          result[key] = null;
        }
      }
    });
    return result;
  }

  static Map<String, DateTime> _parseDateTimeMap(Map<String, dynamic> data) {
    final Map<String, DateTime> result = {};
    data.forEach((key, value) { if (value is String) {
        final dt = DateTime.tryParse(value);
        if (dt != null) result[key] = dt;
      }
    });
    return result;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConversationModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          type == other.type &&
          createdBy == other.createdBy;

  @override
  int get hashCode => Object.hash(id, type, createdBy);

  @override
  String toString() => 'ConversationModel(id: $id, type: $type, name: $name)';
}
