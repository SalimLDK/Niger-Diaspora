import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/message_entity.dart';

part 'message_model.freezed.dart';
part 'message_model.g.dart';

@freezed
class MessageModel with _$MessageModel {
  const MessageModel._();

  const factory MessageModel({
    required String id,
    required String senderId,
    required String senderName,
    String? senderPhotoUrl,
    required String content,
    @Default('text') String type,
    String? fileUrl,
    String? fileName,
    int? fileSize,
    String? mimeType,
    @Default([]) List<String> readBy,
    @Default({}) Map<String, dynamic> readAt,
    DateTime? createdAt,
  }) = _MessageModel;

  factory MessageModel.fromJson(Map<String, dynamic> json) =>
      _$MessageModelFromJson(json);

  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MessageModel.fromJson({
      ...data,
      'id': doc.id,
      'createdAt': _timestampToIso(data['createdAt']),
      'readAt': _convertReadAtTimestamps(data['readAt']),
    });
  }

  Map<String, dynamic> toFirestore() {
    final json = toJson();
    json.remove('id');
    json['createdAt'] = FieldValue.serverTimestamp();

    // Convertir readAt en Timestamps
    if (readAt.isNotEmpty) {
      final Map<String, dynamic> readAtTimestamps = {};
      readAt.forEach((key, value) {
        if (value is DateTime) {
          readAtTimestamps[key] = Timestamp.fromDate(value);
        } else if (value is String) {
          readAtTimestamps[key] = Timestamp.fromDate(DateTime.parse(value));
        }
      });
      json['readAt'] = readAtTimestamps;
    }

    return json;
  }

  MessageEntity toEntity() => MessageEntity(
        id: id,
        senderId: senderId,
        senderName: senderName,
        senderPhotoUrl: senderPhotoUrl,
        content: content,
        type: _parseMessageType(type),
        fileUrl: fileUrl,
        fileName: fileName,
        fileSize: fileSize,
        mimeType: mimeType,
        readBy: readBy,
        readAt: _parseReadAt(readAt),
        createdAt: createdAt ?? DateTime.now(),
      );

  factory MessageModel.fromEntity(MessageEntity entity) => MessageModel(
        id: entity.id,
        senderId: entity.senderId,
        senderName: entity.senderName,
        senderPhotoUrl: entity.senderPhotoUrl,
        content: entity.content,
        type: entity.type.name,
        fileUrl: entity.fileUrl,
        fileName: entity.fileName,
        fileSize: entity.fileSize,
        mimeType: entity.mimeType,
        readBy: entity.readBy,
        readAt: entity.readAt.map((k, v) => MapEntry(k, v.toIso8601String())),
        createdAt: entity.createdAt,
      );

  static MessageType _parseMessageType(String value) {
    return MessageType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => MessageType.text,
    );
  }

  static Map<String, DateTime> _parseReadAt(Map<String, dynamic> data) {
    final Map<String, DateTime> result = {};
    data.forEach((key, value) {
      if (value is String) {
        result[key] = DateTime.parse(value);
      } else if (value is DateTime) {
        result[key] = value;
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

  static Map<String, dynamic> _convertReadAtTimestamps(dynamic data) {
    if (data == null) return {};
    if (data is! Map) return {};

    final Map<String, dynamic> result = {};
    data.forEach((key, value) {
      if (value is Timestamp) {
        result[key.toString()] = value.toDate().toIso8601String();
      } else if (value is String) {
        result[key.toString()] = value;
      }
    });
    return result;
  }
}
