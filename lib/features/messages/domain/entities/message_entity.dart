import 'package:equatable/equatable.dart';

import '../../../feed/domain/entities/post_entity.dart' show MentionedUser;

enum MessageStatus {
  sending, // Message en cours d'envoi
  sent, // Message envoyé avec succès
  failed, // Échec d'envoi
}

enum MessageType { text, image, file, audio, video, system, call, location, sticker, voiceNote }

/// Encryption level of a message, written to RTDB and surfaced in the UI.
enum MessageEncryptionLevel {
  /// AES-256-GCM with a shared server key (legacy / fallback).
  aes,
  /// Signal Protocol per-session (X3DH + Double Ratchet). Truly E2EE.
  e2ee,
}

/// Type d'appel pour les messages de type call
enum CallMessageType {
  incoming,   // Appel entrant
  outgoing,   // Appel sortant
  missed,     // Appel manqué
  declined,   // Appel refusé
}

class MessageEntity extends Equatable {
  final String id;
  final String senderId;
  final String senderName;
  final String? senderPhotoUrl;
  final bool senderIsVerified;
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
  final String? blurhash; // Blurhash placeholder for images/videos
  final List<String> readBy;
  final Map<String, DateTime> readAt;
  final List<String> deliveredTo; // User IDs who received the notification
  final Map<String, DateTime> deliveredAt; // Delivery timestamps per user
  final DateTime createdAt;
  final List<String>
  deletedFor; // List of user IDs who deleted this message for themselves
  final bool
  deletedForEveryone; // If true, message is deleted for all participants
  final DateTime? deletedAt; // When the message was deleted for everyone
  final List<String> reportedBy;
  final Map<String, String>
  reactions; // Une réaction par personne : userId -> emoji

  // Reply fields
  final String? replyToId; // ID of the message being replied to
  final Map<String, dynamic>?
  replyToMessageData; // Snapshot of replied message (to avoid needing to fetch)

  // Product attachment (for marketplace contact)
  final Map<String, dynamic>?
  productData; // Product info: {id, title, price, currency, imageUrl, sellerId, sellerName}

  // Post share attachment (for feed post sharing)
  final Map<String, dynamic>?
  postData; // Post info: {postId, authorId, authorName, content, mediaUrl}

  // Event attachment (bulle événement créée depuis une discussion ou un groupe)
  final Map<String, dynamic>?
  eventData; // Event info: {eventId, title, startDate, location, isOnline}

  // Blocked message tracking - list of user IDs who had blocked the sender when this message was sent
  // Messages with this field set should be hidden from those users even after unblocking
  final List<String> sentWhileBlockedBy;

  // Call message fields
  final String? callType; // 'audio' ou 'video'
  final String? callStatus; // 'missed', 'declined', 'ended'
  final int? callDuration; // Durée en secondes
  final String? callId; // ID de l'appel associé
  final String? callerId; // ID de l'appelant original
  final String? calleeId; // ID de l'appelé original

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
  final DateTime? mediaExpiresAt; // When the Storage file will be deleted (15 days)
  final bool mediaExpired; // true = file deleted from Storage

  // Location sharing fields
  final double? latitude;
  final double? longitude;
  final String? locationAddress;

  // Sticker fields
  final String? stickerPackId;
  final String? stickerId;
  final bool isAnimatedSticker;

  // Mention fields
  final List<MentionedUser> mentionedUsers;

  // Client-generated UUID set before send; stored in RTDB for deterministic
  // optimistic-update matching. Null on messages received from other users.
  final String? clientMessageId;

  /// Chemin du fichier local d'un média pas encore téléversé.
  ///
  /// Purement local : jamais sérialisé, jamais reçu du serveur. Il permet de
  /// RENVOYER un message vocal en échec — sans lui, `retryFailedMessage`
  /// n'avait plus rien à téléverser et se contentait de faire disparaître la
  /// bulle.
  final String? localFilePath;

  /// How the message content is encrypted. Exposed to the UI so it can show
  /// a lock icon that accurately reflects the security level.
  final MessageEncryptionLevel encryptionLevel;

  const MessageEntity({
    this.localFilePath,
    required this.id,
    required this.senderId,
    required this.senderName,
    this.senderPhotoUrl,
    this.senderIsVerified = false,
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
    this.blurhash,
    this.readBy = const [],
    this.readAt = const {},
    this.deliveredTo = const [],
    this.deliveredAt = const {},
    required this.createdAt,
    this.deletedFor = const [],
    this.deletedForEveryone = false,
    this.deletedAt,
    this.reportedBy = const [],
    this.reactions = const {},
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
    this.encryptionLevel = MessageEncryptionLevel.aes,
  });

  bool get hasMentions => mentionedUsers.isNotEmpty;

  bool get isText => type == MessageType.text;
  bool get isImage => type == MessageType.image;
  bool get isFile => type == MessageType.file;
  bool get isAudio => type == MessageType.audio;
  bool get isVoiceNote => type == MessageType.voiceNote;
  bool get isVideo => type == MessageType.video;
  bool get isSystem => type == MessageType.system;
  bool get isCall => type == MessageType.call;
  bool get isLocation => type == MessageType.location;
  bool get isSticker => type == MessageType.sticker;

  /// Check if message has been edited
  bool get isEdited => editedAt != null;

  /// Check if message is ephemeral (has expiration date)
  bool get isEphemeral => expiresAt != null;

  /// Check if the media file has been deleted from Storage
  bool get isMediaExpired => mediaExpired;

  /// Remaining days before Storage file is deleted (null if no TTL)
  int? get mediaExpiryDaysLeft {
    if (mediaExpiresAt == null || mediaExpired) return null;
    final diff = mediaExpiresAt!.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  /// Check if ephemeral message has expired
  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

  /// Get remaining time until expiration
  Duration? get remainingTime {
    if (expiresAt == null) return null;
    final remaining = expiresAt!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Check if current user can edit this message (sender only, text only, within 25 min)
  bool canEdit(String currentUserId, {Duration timeLimit = const Duration(minutes: 25)}) {
    if (senderId != currentUserId) return false;
    if (type != MessageType.text) return false;
    if (deletedForEveryone) return false;
    return DateTime.now().difference(createdAt) <= timeLimit;
  }

  /// Formatage de la durée d'appel
  String get callDurationFormatted {
    if (callDuration == null || callDuration == 0) return '';
    final minutes = callDuration! ~/ 60;
    final seconds = callDuration! % 60;
    if (minutes > 0) {
      return '$minutes min ${seconds.toString().padLeft(2, '0')} s';
    }
    return '$seconds s';
  }

  /// Vérifie si c'est un appel vidéo
  bool get isVideoCall => callType == 'video';

  /// Vérifie si c'est un appel manqué
  bool get isMissedCall => callStatus == 'missed';

  /// Vérifie si c'est un appel refusé
  bool get isDeclinedCall => callStatus == 'declined';

  String get audioDurationFormatted {
    if (audioDuration == null) return '0:00';
    final minutes = audioDuration! ~/ 60;
    final seconds = audioDuration! % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  bool isReadBy(String userId) => readBy.contains(userId);

  /// Check if message was delivered to a specific user
  bool isDeliveredTo(String userId) => deliveredTo.contains(userId);

  /// Check if message was delivered to at least one recipient (excluding sender)
  bool get isDelivered => deliveredTo.length > 1;

  /// Check if message was delivered to all recipients
  bool isDeliveredToAll(List<String> recipientIds) {
    return recipientIds.every((id) => deliveredTo.contains(id));
  }

  /// Check if message was read by all recipients
  bool isReadByAll(List<String> recipientIds) {
    return recipientIds.every((id) => readBy.contains(id));
  }

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

  /// Check if this message is a shared feed post
  bool get hasPost => postData != null && postData!.isNotEmpty;

  /// Check if this message is a shared event
  bool get hasEvent => eventData != null && eventData!.isNotEmpty;

  /// Check if message is starred by a specific user
  bool isStarredBy(String userId) => starredBy.contains(userId);

  /// L'emoji posé par cet utilisateur sur ce message, s'il y en a un.
  /// Une seule réaction par personne et par message.
  String? myReaction(String userId) => reactions[userId];

  /// Link preview getters
  bool get hasLinkPreview => linkPreviewData != null && linkPreviewData!.isNotEmpty;
  String? get linkPreviewUrl => linkPreviewData?['url'] as String?;
  String? get linkPreviewTitle => linkPreviewData?['title'] as String?;
  String? get linkPreviewDescription => linkPreviewData?['description'] as String?;
  String? get linkPreviewImage => linkPreviewData?['imageUrl'] as String?;
  String? get linkPreviewSiteName => linkPreviewData?['siteName'] as String?;

  MessageEntity copyWith({
    String? localFilePath,
    String? id,
    String? senderId,
    String? senderName,
    String? senderPhotoUrl,
    bool? senderIsVerified,
    String? content,
    MessageType? type,
    MessageStatus? status,
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
    Map<String, DateTime>? readAt,
    List<String>? deliveredTo,
    Map<String, DateTime>? deliveredAt,
    DateTime? createdAt,
    List<String>? deletedFor,
    bool? deletedForEveryone,
    DateTime? deletedAt,
    List<String>? reportedBy,
    Map<String, String>? reactions,
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
    double? latitude,
    double? longitude,
    String? locationAddress,
    String? stickerPackId,
    String? stickerId,
    bool? isAnimatedSticker,
    List<MentionedUser>? mentionedUsers,
    String? clientMessageId,
    MessageEncryptionLevel? encryptionLevel,
  }) {
    return MessageEntity(
      localFilePath: localFilePath ?? this.localFilePath,
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
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationAddress: locationAddress ?? this.locationAddress,
      stickerPackId: stickerPackId ?? this.stickerPackId,
      stickerId: stickerId ?? this.stickerId,
      isAnimatedSticker: isAnimatedSticker ?? this.isAnimatedSticker,
      mentionedUsers: mentionedUsers ?? this.mentionedUsers,
      clientMessageId: clientMessageId ?? this.clientMessageId,
      encryptionLevel: encryptionLevel ?? this.encryptionLevel,
    );
  }

  @override
  List<Object?> get props => [
    localFilePath,
    id,
    senderId,
    senderName,
    senderPhotoUrl,
    senderIsVerified,
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
    blurhash,
    readBy,
    readAt,
    deliveredTo,
    deliveredAt,
    createdAt,
    deletedFor,
    deletedForEveryone,
    deletedAt,
    reportedBy,
    reactions,
    replyToId,
    replyToMessageData,
    productData,
    postData,
    eventData,
    sentWhileBlockedBy,
    callType,
    callStatus,
    callDuration,
    callId,
    callerId,
    calleeId,
    linkPreviewData,
    isForwarded,
    starredBy,
    editedAt,
    editHistory,
    expiresAt,
    mediaExpiresAt,
    mediaExpired,
    latitude,
    longitude,
    locationAddress,
    stickerPackId,
    stickerId,
    isAnimatedSticker,
    mentionedUsers,
  ];
}
