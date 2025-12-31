import 'package:equatable/equatable.dart';

enum MessageStatus {
  sending, // Message en cours d'envoi
  sent, // Message envoyé avec succès
  failed, // Échec d'envoi
}

enum MessageType { text, image, file, audio, video, system }

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
  final int? audioDuration; // Duration in seconds for audio messages
  final List<double>? audioWaveform; // Waveform data for audio visualization
  final String? thumbnailUrl;
  final int? videoDuration;
  final List<String> readBy;
  final Map<String, DateTime> readAt;
  final DateTime createdAt;
  final List<String>
  deletedFor; // List of user IDs who deleted this message for themselves
  final bool
  deletedForEveryone; // If true, message is deleted for all participants
  final DateTime? deletedAt; // When the message was deleted for everyone
  final List<String> reportedBy;
  final List<String>
  reactions; // List of emoji reactions (e.g., ['❤️', '👍', '😂'])

  // Reply fields
  final String? replyToId; // ID of the message being replied to
  final Map<String, dynamic>?
  replyToMessageData; // Snapshot of replied message (to avoid needing to fetch)

  // Product attachment (for marketplace contact)
  final Map<String, dynamic>?
  productData; // Product info: {id, title, price, currency, imageUrl, sellerId, sellerName}

  // Blocked message tracking - list of user IDs who had blocked the sender when this message was sent
  // Messages with this field set should be hidden from those users even after unblocking
  final List<String> sentWhileBlockedBy;

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
    this.audioDuration,
    this.audioWaveform,
    this.thumbnailUrl,
    this.videoDuration,
    this.readBy = const [],
    this.readAt = const {},
    required this.createdAt,
    this.deletedFor = const [],
    this.deletedForEveryone = false,
    this.deletedAt,
    this.reportedBy = const [],
    this.reactions = const [],
    this.replyToId,
    this.replyToMessageData,
    this.productData,
    this.sentWhileBlockedBy = const [],
  });

  bool get isText => type == MessageType.text;
  bool get isImage => type == MessageType.image;
  bool get isFile => type == MessageType.file;
  bool get isAudio => type == MessageType.audio;
  bool get isVideo => type == MessageType.video;
  bool get isSystem => type == MessageType.system;

  String get audioDurationFormatted {
    if (audioDuration == null) return '0:00';
    final minutes = audioDuration! ~/ 60;
    final seconds = audioDuration! % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  bool isReadBy(String userId) => readBy.contains(userId);

  /// Check if this message is deleted for a specific user
  bool isDeletedFor(String userId) =>
      deletedForEveryone || deletedFor.contains(userId);

  /// Check if current user can delete for everyone (only sender, within time limit)
  bool canDeleteForEveryone(
    String currentUserId, {
    Duration timeLimit = const Duration(hours: 1),
  }) {
    if (senderId != currentUserId) return false;
    if (deletedForEveryone) return false;
    return DateTime.now().difference(createdAt) <= timeLimit;
  }

  String get fileSizeFormatted {
    if (fileSize == null) return '';
    if (fileSize! < 1024) return '$fileSize B';
    if (fileSize! < 1024 * 1024) {
      return '${(fileSize! / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSize! / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Check if this message has a product attachment
  bool get hasProduct => productData != null && productData!.isNotEmpty;

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
    audioDuration,
    audioWaveform,
    thumbnailUrl,
    videoDuration,
    readBy,
    readAt,
    createdAt,
    deletedFor,
    deletedForEveryone,
    deletedAt,
    reportedBy,
    reactions,
    replyToId,
    replyToMessageData,
    productData,
    sentWhileBlockedBy,
  ];
}
