import 'package:equatable/equatable.dart';

enum MessageStatus {
  sending, // Message en cours d'envoi
  sent, // Message envoyé avec succès
  failed, // Échec d'envoi
}

enum MessageType { text, image, file }

class MessageEntity extends Equatable {
  final String id;
  final String senderId;
  final String senderName;
  final String? senderPhotoUrl;
  final String content;
  final MessageType type;
  final MessageStatus status;
  final String? fileUrl;
  final String? fileName;
  final int? fileSize;
  final String? mimeType;
  final List<String> readBy;
  final Map<String, DateTime> readAt;
  final DateTime createdAt;

  const MessageEntity({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.senderPhotoUrl,
    required this.content,
    required this.type,
    this.status = MessageStatus.sent, // Par défaut: envoyé
    this.fileUrl,
    this.fileName,
    this.fileSize,
    this.mimeType,
    this.readBy = const [],
    this.readAt = const {},
    required this.createdAt,
  });

  bool get isText => type == MessageType.text;
  bool get isImage => type == MessageType.image;
  bool get isFile => type == MessageType.file;

  bool isReadBy(String userId) => readBy.contains(userId);

  String get fileSizeFormatted {
    if (fileSize == null) return '';
    if (fileSize! < 1024) return '$fileSize B';
    if (fileSize! < 1024 * 1024) {
      return '${(fileSize! / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSize! / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  List<Object?> get props => [
    id,
    senderId,
    senderName,
    senderPhotoUrl,
    content,
    type,
    status,
    fileUrl,
    fileName,
    fileSize,
    mimeType,
    readBy,
    readAt,
    createdAt,
  ];
}
