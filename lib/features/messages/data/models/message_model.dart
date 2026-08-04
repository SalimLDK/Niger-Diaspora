import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/message_entity.dart'
    show MessageEntity, MessageEncryptionLevel, MessageStatus, MessageType;
import '../../../feed/domain/entities/post_entity.dart' show MentionedUser;

/// Model de message pour la couche data
/// Converti depuis/vers Firestore et RTDB
final class MessageModel {
  final String id;
  final String senderId;
  final String senderName;
  final String? senderPhotoUrl;
  final bool senderIsVerified;
  final String content;
  final String type;
  final String status;
  final String? fileUrl;
  final String? fileName;
  final int? fileSize;
  final String? mimeType;
  final int? audioDuration;
  final List<double> audioWaveform;
  final String? thumbnailUrl;
  final int? videoDuration;
  final String? blurhash;
  final List<String> readBy;
  final Map<String, dynamic> readAt;
  final List<String> deliveredTo;
  final Map<String, dynamic> deliveredAt;
  final DateTime? createdAt;
  final List<String> deletedFor;
  final bool deletedForEveryone;
  final DateTime? deletedAt;
  final List<String> reportedBy;
  final List<String> reactions;
  final String? replyToId;
  final Map<String, dynamic>? replyToMessageData;
  final Map<String, dynamic>? productData;
  final Map<String, dynamic>? postData;
  final Map<String, dynamic>? eventData;
  final List<String> sentWhileBlockedBy;
  // Call message fields
  final String? callType;
  final String? callStatus;
  final int? callDuration;
  final String? callId;
  final String? callerId;
  final String? calleeId;
  // Link preview fields
  final Map<String, dynamic>? linkPreviewData;
  // Forward fields
  final bool isForwarded;
  // Starred messages
  final List<String> starredBy;
  // Editing fields
  final DateTime? editedAt;
  final List<Map<String, dynamic>>? editHistory;
  // Ephemeral message fields
  final DateTime? expiresAt;
  // Media TTL fields
  final DateTime? mediaExpiresAt;
  final bool mediaExpired;
  // Location sharing fields
  final double? latitude;
  final double? longitude;
  final String? locationAddress;
  // Sticker fields
  final String? stickerPackId;
  final String? stickerId;
  final bool isAnimatedSticker;

  // Mention fields
  final List<Map<String, String>> mentionedUsers;

  final String? clientMessageId;
  final String encryptionLevel; // 'aes' | 'e2ee'

  const MessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.senderPhotoUrl,
    this.senderIsVerified = false,
    required this.content,
    this.type = 'text',
    this.status = 'sent',
    this.fileUrl,
    this.fileName,
    this.fileSize,
    this.mimeType,
    this.audioDuration,
    this.audioWaveform = const [],
    this.thumbnailUrl,
    this.videoDuration,
    this.blurhash,
    this.readBy = const [],
    this.readAt = const {},
    this.deliveredTo = const [],
    this.deliveredAt = const {},
    this.createdAt,
    this.deletedFor = const [],
    this.deletedForEveryone = false,
    this.deletedAt,
    this.reportedBy = const [],
    this.reactions = const [],
    this.replyToId,
    this.replyToMessageData,
    this.productData,
    this.postData,
    this.eventData,
    this.sentWhileBlockedBy = const [],
    this.callType,
    this.callStatus,
    this.callDuration,
    this.callId,
    this.callerId,
    this.calleeId,
    this.linkPreviewData,
    this.isForwarded = false,
    this.starredBy = const [],
    this.editedAt,
    this.editHistory,
    this.expiresAt,
    this.mediaExpiresAt,
    this.mediaExpired = false,
    this.latitude,
    this.longitude,
    this.locationAddress,
    this.stickerPackId,
    this.stickerId,
    this.isAnimatedSticker = false,
    this.mentionedUsers = const [],
    this.clientMessageId,
    this.encryptionLevel = 'aes',
  });

  /// Creer depuis JSON
  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] as String? ?? '',
      senderId: json['senderId'] as String? ?? '',
      senderName: json['senderName'] as String? ?? '',
      senderPhotoUrl: json['senderPhotoUrl'] as String?,
      senderIsVerified: json['senderIsVerified'] as bool? ?? false,
      content: json['content'] as String? ?? '',
      type: json['type'] as String? ?? 'text',
      status: json['status'] as String? ?? 'sent',
      fileUrl: json['fileUrl'] as String?,
      fileName: json['fileName'] as String?,
      fileSize: json['fileSize'] as int?,
      mimeType: json['mimeType'] as String?,
      audioDuration: json['audioDuration'] as int?,
      audioWaveform: _parseDoubleList(json['audioWaveform']),
      thumbnailUrl: json['thumbnailUrl'] as String?,
      videoDuration: json['videoDuration'] as int?,
      blurhash: json['blurhash'] as String?,
      readBy: _parseStringList(json['readBy']),
      readAt: _parseMap(json['readAt']),
      deliveredTo: _parseStringList(json['deliveredTo']),
      deliveredAt: _parseMap(json['deliveredAt']),
      createdAt: _parseDateTime(json['createdAt']),
      deletedFor: _parseStringList(json['deletedFor']),
      deletedForEveryone: json['deletedForEveryone'] as bool? ?? false,
      deletedAt: _parseDateTime(json['deletedAt']),
      reportedBy: _parseStringList(json['reportedBy']),
      reactions: _parseStringList(json['reactions']),
      replyToId: json['replyToId'] as String?,
      replyToMessageData: json['replyToMessageData'] as Map<String, dynamic>?,
      productData: json['productData'] as Map<String, dynamic>?,
      postData: json['postData'] as Map<String, dynamic>?,
      eventData: json['eventData'] as Map<String, dynamic>?,
      sentWhileBlockedBy: _parseStringList(json['sentWhileBlockedBy']),
      callType: json['callType'] as String?,
      callStatus: json['callStatus'] as String?,
      callDuration: json['callDuration'] as int?,
      callId: json['callId'] as String?,
      callerId: json['callerId'] as String?,
      calleeId: json['calleeId'] as String?,
      linkPreviewData: json['linkPreviewData'] as Map<String, dynamic>?,
      isForwarded: json['isForwarded'] as bool? ?? false,
      starredBy: _parseStringList(json['starredBy']),
      editedAt: _parseDateTime(json['editedAt']),
      editHistory: _parseEditHistory(json['editHistory']),
      expiresAt: _parseDateTime(json['expiresAt']),
      mediaExpiresAt: _parseDateTime(json['mediaExpiresAt']),
      mediaExpired: json['mediaExpired'] as bool? ?? false,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      locationAddress: json['locationAddress'] as String?,
      stickerPackId: json['stickerPackId'] as String?,
      stickerId: json['stickerId'] as String?,
      isAnimatedSticker: json['isAnimatedSticker'] as bool? ?? false,
      mentionedUsers: _parseMentionedUsers(json['mentionedUsers']),
      clientMessageId: json['clientMessageId'] as String?,
      encryptionLevel: json['encryptionLevel'] as String? ?? 'aes',
    );
  }
  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    final rawData = doc.data() as Map<String, dynamic>? ?? {};
    final data = <String, dynamic>{'id': doc.id};
    rawData.forEach((key, value) {
      if (value is Timestamp) {
        data[key] = value.toDate().toUtc().toIso8601String();
      } else {
        data[key] = value;
      }
    });
    return MessageModel.fromJson(data);
  }

  /// Convertir en JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'senderName': senderName,
      if (senderPhotoUrl != null) 'senderPhotoUrl': senderPhotoUrl,
      if (senderIsVerified) 'senderIsVerified': senderIsVerified,
      'content': content,
      'type': type,
      'status': status,
      if (fileUrl != null) 'fileUrl': fileUrl,
      if (fileName != null) 'fileName': fileName,
      if (fileSize != null) 'fileSize': fileSize,
      if (mimeType != null) 'mimeType': mimeType,
      if (audioDuration != null) 'audioDuration': audioDuration,
      if (audioWaveform.isNotEmpty) 'audioWaveform': audioWaveform,
      if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
      if (videoDuration != null) 'videoDuration': videoDuration,
      if (blurhash != null) 'blurhash': blurhash,
      if (readBy.isNotEmpty) 'readBy': readBy,
      if (readAt.isNotEmpty) 'readAt': readAt,
      if (deliveredTo.isNotEmpty) 'deliveredTo': deliveredTo,
      if (deliveredAt.isNotEmpty) 'deliveredAt': deliveredAt,
      if (createdAt != null) 'createdAt': createdAt!.toUtc().toIso8601String(),
      if (deletedFor.isNotEmpty) 'deletedFor': deletedFor,
      'deletedForEveryone': deletedForEveryone,
      if (deletedAt != null) 'deletedAt': deletedAt!.toUtc().toIso8601String(),
      if (reportedBy.isNotEmpty) 'reportedBy': reportedBy,
      if (reactions.isNotEmpty) 'reactions': reactions,
      if (replyToId != null) 'replyToId': replyToId,
      if (replyToMessageData != null) 'replyToMessageData': replyToMessageData,
      if (productData != null) 'productData': productData,
      if (postData != null) 'postData': postData,
      if (eventData != null) 'eventData': eventData,
      if (sentWhileBlockedBy.isNotEmpty) 'sentWhileBlockedBy': sentWhileBlockedBy,
      if (callType != null) 'callType': callType,
      if (callStatus != null) 'callStatus': callStatus,
      if (callDuration != null) 'callDuration': callDuration,
      if (callId != null) 'callId': callId,
      if (callerId != null) 'callerId': callerId,
      if (calleeId != null) 'calleeId': calleeId,
      if (linkPreviewData != null) 'linkPreviewData': linkPreviewData,
      'isForwarded': isForwarded,
      if (starredBy.isNotEmpty) 'starredBy': starredBy,
      if (editedAt != null) 'editedAt': editedAt!.toUtc().toIso8601String(),
      if (editHistory != null && editHistory!.isNotEmpty) 'editHistory': editHistory,
      if (expiresAt != null) 'expiresAt': expiresAt!.toUtc().toIso8601String(),
      if (mediaExpiresAt != null) 'mediaExpiresAt': mediaExpiresAt!.toUtc().toIso8601String(),
      if (mediaExpired) 'mediaExpired': mediaExpired,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (locationAddress != null) 'locationAddress': locationAddress,
      if (stickerPackId != null) 'stickerPackId': stickerPackId,
      if (stickerId != null) 'stickerId': stickerId,
      if (isAnimatedSticker) 'isAnimatedSticker': isAnimatedSticker,
      if (mentionedUsers.isNotEmpty) 'mentionedUsers': mentionedUsers,
      if (clientMessageId != null) 'clientMessageId': clientMessageId,
      'encryptionLevel': encryptionLevel,
    };
  }

  /// Creer depuis un DocumentSnapshot Firestore
  /// Convertir pour Firestore
  Map<String, dynamic> toFirestore() {
    final json = toJson();
    json.remove('id');
    json['createdAt'] = FieldValue.serverTimestamp();

    // Convertir readAt en Timestamps avec gestion d'erreurs
    if (readAt.isNotEmpty) {
      final Map<String, dynamic> readAtTimestamps = {};
      readAt.forEach((key, value) {
        try {
          if (value is DateTime) {
            readAtTimestamps[key] = value.toUtc().toIso8601String();
          } else if (value is String) {
            readAtTimestamps[key] = value;
          }
        } catch (_) {
          // Ignorer les timestamps invalides
        }
      });
      if (readAtTimestamps.isNotEmpty) {
        json['readAt'] = readAtTimestamps;
      }
    }

    // Convertir deliveredAt en Timestamps avec gestion d'erreurs
    if (deliveredAt.isNotEmpty) {
      final Map<String, dynamic> deliveredAtTimestamps = {};
      deliveredAt.forEach((key, value) {
        try {
          if (value is DateTime) {
            deliveredAtTimestamps[key] = value.toUtc().toIso8601String();
          } else if (value is String) {
            deliveredAtTimestamps[key] = value;
          }
        } catch (_) {
          // Ignorer les timestamps invalides
        }
      });
      if (deliveredAtTimestamps.isNotEmpty) {
        json['deliveredAt'] = deliveredAtTimestamps;
      }
    }

    return json;
  }

  /// Convertir en entite de domaine
  MessageEntity toEntity() => MessageEntity(
    id: id,
    senderId: senderId,
    senderName: senderName,
    senderPhotoUrl: senderPhotoUrl,
    senderIsVerified: senderIsVerified,
    content: content,
    type: _parseMessageType(type),
    status: _parseMessageStatus(status),
    fileUrl: fileUrl,
    fileName: fileName,
    fileSize: fileSize,
    mimeType: mimeType,
    audioDuration: audioDuration,
    audioWaveform: audioWaveform.isNotEmpty ? audioWaveform : null,
    thumbnailUrl: thumbnailUrl,
    videoDuration: videoDuration,
    blurhash: blurhash,
    readBy: readBy,
    readAt: _parseReadAt(readAt),
    deliveredTo: deliveredTo,
    deliveredAt: _parseReadAt(deliveredAt),
    createdAt: createdAt ?? DateTime.now(),
    deletedFor: deletedFor,
    deletedForEveryone: deletedForEveryone,
    deletedAt: deletedAt,
    reportedBy: reportedBy,
    reactions: reactions,
    replyToId: replyToId,
    replyToMessageData: replyToMessageData,
    productData: productData,
    postData: postData,
    eventData: eventData,
    sentWhileBlockedBy: sentWhileBlockedBy,
    callType: callType,
    callStatus: callStatus,
    callDuration: callDuration,
    callId: callId,
    callerId: callerId,
    calleeId: calleeId,
    linkPreviewData: linkPreviewData,
    isForwarded: isForwarded,
    starredBy: starredBy,
    editedAt: editedAt,
    editHistory: editHistory,
    expiresAt: expiresAt,
    mediaExpiresAt: mediaExpiresAt,
    mediaExpired: mediaExpired,
    latitude: latitude,
    longitude: longitude,
    locationAddress: locationAddress,
    stickerPackId: stickerPackId,
    stickerId: stickerId,
    isAnimatedSticker: isAnimatedSticker,
    mentionedUsers: mentionedUsers
        .map((m) => MentionedUser(id: m['id'] ?? '', name: m['name'] ?? ''))
        .toList(),
    clientMessageId: clientMessageId,
    encryptionLevel: encryptionLevel == 'e2ee'
        ? MessageEncryptionLevel.e2ee
        : MessageEncryptionLevel.aes,
  );

  /// Creer depuis une entite de domaine
  factory MessageModel.fromEntity(MessageEntity entity) => MessageModel(
    id: entity.id,
    senderId: entity.senderId,
    senderName: entity.senderName,
    senderPhotoUrl: entity.senderPhotoUrl,
    senderIsVerified: entity.senderIsVerified,
    content: entity.content,
    type: entity.type.name,
    status: entity.status.name,
    fileUrl: entity.fileUrl,
    fileName: entity.fileName,
    fileSize: entity.fileSize,
    mimeType: entity.mimeType,
    audioDuration: entity.audioDuration,
    audioWaveform: entity.audioWaveform ?? [],
    thumbnailUrl: entity.thumbnailUrl,
    videoDuration: entity.videoDuration,
    blurhash: entity.blurhash,
    readBy: entity.readBy,
    readAt: entity.readAt.map((k, v) => MapEntry(k, v.toUtc().toIso8601String())),
    deliveredTo: entity.deliveredTo,
    deliveredAt: entity.deliveredAt.map((k, v) => MapEntry(k, v.toUtc().toIso8601String())),
    createdAt: entity.createdAt,
    deletedFor: entity.deletedFor,
    deletedForEveryone: entity.deletedForEveryone,
    deletedAt: entity.deletedAt,
    reportedBy: entity.reportedBy,
    reactions: entity.reactions,
    replyToId: entity.replyToId,
    replyToMessageData: entity.replyToMessageData,
    productData: entity.productData,
    postData: entity.postData,
    eventData: entity.eventData,
    sentWhileBlockedBy: entity.sentWhileBlockedBy,
    callType: entity.callType,
    callStatus: entity.callStatus,
    callDuration: entity.callDuration,
    callId: entity.callId,
    callerId: entity.callerId,
    calleeId: entity.calleeId,
    linkPreviewData: entity.linkPreviewData,
    isForwarded: entity.isForwarded,
    starredBy: entity.starredBy,
    editedAt: entity.editedAt,
    editHistory: entity.editHistory,
    expiresAt: entity.expiresAt,
    mediaExpiresAt: entity.mediaExpiresAt,
    mediaExpired: entity.mediaExpired,
    latitude: entity.latitude,
    longitude: entity.longitude,
    locationAddress: entity.locationAddress,
    stickerPackId: entity.stickerPackId,
    stickerId: entity.stickerId,
    isAnimatedSticker: entity.isAnimatedSticker,
    mentionedUsers: entity.mentionedUsers
        .map((m) => {'id': m.id, 'name': m.name})
        .toList(),
    clientMessageId: entity.clientMessageId,
    encryptionLevel: entity.encryptionLevel == MessageEncryptionLevel.e2ee
        ? 'e2ee'
        : 'aes',
  );

  /// Copier avec modifications
  MessageModel copyWith({
    String? id,
    String? senderId,
    String? senderName,
    String? senderPhotoUrl,
    bool? senderIsVerified,
    String? content,
    String? type,
    String? status,
    String? fileUrl,
    String? fileName,
    int? fileSize,
    String? mimeType,
    int? audioDuration,
    List<double>? audioWaveform,
    String? thumbnailUrl,
    int? videoDuration,
    String? blurhash,
    List<String>? readBy,
    Map<String, dynamic>? readAt,
    List<String>? deliveredTo,
    Map<String, dynamic>? deliveredAt,
    DateTime? createdAt,
    List<String>? deletedFor,
    bool? deletedForEveryone,
    DateTime? deletedAt,
    List<String>? reportedBy,
    List<String>? reactions,
    String? replyToId,
    Map<String, dynamic>? replyToMessageData,
    Map<String, dynamic>? productData,
    Map<String, dynamic>? postData,
    Map<String, dynamic>? eventData,
    List<String>? sentWhileBlockedBy,
    String? callType,
    String? callStatus,
    int? callDuration,
    String? callId,
    String? callerId,
    String? calleeId,
    Map<String, dynamic>? linkPreviewData,
    bool? isForwarded,
    List<String>? starredBy,
    DateTime? editedAt,
    List<Map<String, dynamic>>? editHistory,
    DateTime? expiresAt,
    DateTime? mediaExpiresAt,
    bool? mediaExpired,
    String? stickerPackId,
    String? stickerId,
    bool? isAnimatedSticker,
    List<Map<String, String>>? mentionedUsers,
  }) {
    return MessageModel(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderPhotoUrl: senderPhotoUrl ?? this.senderPhotoUrl,
      senderIsVerified: senderIsVerified ?? this.senderIsVerified,
      content: content ?? this.content,
      type: type ?? this.type,
      status: status ?? this.status,
      fileUrl: fileUrl ?? this.fileUrl,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      mimeType: mimeType ?? this.mimeType,
      audioDuration: audioDuration ?? this.audioDuration,
      audioWaveform: audioWaveform ?? this.audioWaveform,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      videoDuration: videoDuration ?? this.videoDuration,
      blurhash: blurhash ?? this.blurhash,
      readBy: readBy ?? this.readBy,
      readAt: readAt ?? this.readAt,
      deliveredTo: deliveredTo ?? this.deliveredTo,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      createdAt: createdAt ?? this.createdAt,
      deletedFor: deletedFor ?? this.deletedFor,
      deletedForEveryone: deletedForEveryone ?? this.deletedForEveryone,
      deletedAt: deletedAt ?? this.deletedAt,
      reportedBy: reportedBy ?? this.reportedBy,
      reactions: reactions ?? this.reactions,
      replyToId: replyToId ?? this.replyToId,
      replyToMessageData: replyToMessageData ?? this.replyToMessageData,
      productData: productData ?? this.productData,
      postData: postData ?? this.postData,
      eventData: eventData ?? this.eventData,
      sentWhileBlockedBy: sentWhileBlockedBy ?? this.sentWhileBlockedBy,
      callType: callType ?? this.callType,
      callStatus: callStatus ?? this.callStatus,
      callDuration: callDuration ?? this.callDuration,
      callId: callId ?? this.callId,
      callerId: callerId ?? this.callerId,
      calleeId: calleeId ?? this.calleeId,
      linkPreviewData: linkPreviewData ?? this.linkPreviewData,
      isForwarded: isForwarded ?? this.isForwarded,
      starredBy: starredBy ?? this.starredBy,
      editedAt: editedAt ?? this.editedAt,
      editHistory: editHistory ?? this.editHistory,
      expiresAt: expiresAt ?? this.expiresAt,
      mediaExpiresAt: mediaExpiresAt ?? this.mediaExpiresAt,
      mediaExpired: mediaExpired ?? this.mediaExpired,
      stickerPackId: stickerPackId ?? this.stickerPackId,
      stickerId: stickerId ?? this.stickerId,
      isAnimatedSticker: isAnimatedSticker ?? this.isAnimatedSticker,
      mentionedUsers: mentionedUsers ?? this.mentionedUsers,
    );
  }

  // ============ Helpers de parsing ============

  static List<Map<String, String>> _parseMentionedUsers(dynamic data) {
    if (data == null) return [];
    if (data is List) {
      return data.whereType<Map>().map((e) => {
        'id': (e['id'] ?? '').toString(),
        'name': (e['name'] ?? '').toString(),
      },).toList();
    }
    return [];
  }

  static List<String> _parseStringList(dynamic data) {
    if (data == null) return [];
    if (data is List) {
      return data.map((e) => e.toString()).toList();
    }
    return [];
  }

  static List<double> _parseDoubleList(dynamic data) {
    if (data == null) return [];
    if (data is List) {
      return data.map((e) {
        if (e is num) return e.toDouble();
        if (e is String) return double.tryParse(e) ?? 0.0;
        return 0.0;
      }).toList();
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
    if (data is DateTime) return data.toLocal();
    if (data is String) {
      return DateTime.tryParse(data)?.toLocal();
    }
    if (data is Timestamp) {
      return data.toDate().toLocal();
    }
    return null;
  }

  static MessageType _parseMessageType(String value) {
    if (value == 'voiceNote') return MessageType.voiceNote;
    if (value == 'audioFile') return MessageType.audio;
    // Backward compatibility: legacy voice messages were stored as 'audio'.
    if (value == 'audio') return MessageType.voiceNote;
    return MessageType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => MessageType.text,
    );
  }

  static MessageStatus _parseMessageStatus(String value) {
    return MessageStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => MessageStatus.sent,
    );
  }

  static Map<String, DateTime> _parseReadAt(Map<String, dynamic> data) {
    final Map<String, DateTime> result = {};
    data.forEach((key, value) {
      try {
        if (value is String) {
          result[key] = DateTime.parse(value).toLocal();
        } else if (value is DateTime) {
          result[key] = value.toLocal();
        }
      } catch (_) {
        // Ignorer les timestamps invalides
      }
    });
    return result;
  }
  static List<Map<String, dynamic>>? _parseEditHistory(dynamic data) {
    if (data == null) return null;
    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return null;
  }
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MessageModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          senderId == other.senderId &&
          content == other.content &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(id, senderId, content, createdAt);

  @override
  String toString() => 'MessageModel(id: $id, senderId: $senderId, type: $type)';
}
