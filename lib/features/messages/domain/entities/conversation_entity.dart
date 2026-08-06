import 'package:equatable/equatable.dart';

import 'message_entity.dart';

enum ConversationType { individual, group }

/// Status of a message request for conversations with non-linked users
enum ConversationRequestStatus {
  /// Normal conversation (users have a link - friends or previous exchange)
  none,

  /// Request sent, waiting for recipient to accept
  pending,

  /// Request was accepted by recipient
  accepted,

  /// Request was declined by recipient
  declined,
}

class ConversationEntity extends Equatable {
  final String id;
  final ConversationType type;
  final String? name;
  final String? imageUrl;
  final String? groupId; // Add groupId for group conversations
  final List<String> participantIds;
  final List<String> adminIds;
  final List<String> reportedBy;
  final String? lastMessage;
  final String? lastMessageSenderId;
  final MessageStatus? lastMessageStatus;
  final MessageType? lastMessageType;
  final DateTime? lastMessageAt;
  final List<String> lastMessageReadBy;
  final List<String> lastMessageDeliveredTo;
  final DateTime createdAt;
  final String createdBy;
  final Map<String, int> unreadCount;
  final Map<String, int> unreadMentions;

  /// Map of userId to mute expiration time.
  /// null value = muted forever, DateTime = muted until that time, no entry = not muted
  final Map<String, DateTime?> mutedBy;
  final Map<String, bool> archivedBy;
  final Map<String, DateTime> pinnedBy;

  /// Auto-delete duration for ephemeral messages (in seconds)
  /// null = disabled, 86400 = 24h, 604800 = 7 days, 2592000 = 30 days
  final int? autoDeleteAfterSeconds;

  /// Message request status for conversations with non-linked users
  /// Defaults to 'none' for normal conversations
  final ConversationRequestStatus requestStatus;

  /// User ID who initiated the message request
  final String? requesterId;

  /// When the message request was created
  final DateTime? requestedAt;

  /// When the message request was accepted or declined
  final DateTime? respondedAt;

  const ConversationEntity({
    required this.id,
    required this.type,
    this.name,
    this.imageUrl,
    this.groupId, // Add to constructor
    required this.participantIds,
    this.adminIds = const [],
    this.reportedBy = const [],
    this.lastMessage,
    this.lastMessageSenderId,
    this.lastMessageStatus,
    this.lastMessageType,
    this.lastMessageAt,
    this.lastMessageReadBy = const [],
    this.lastMessageDeliveredTo = const [],
    required this.createdAt,
    required this.createdBy,
    this.unreadCount = const {},
    this.unreadMentions = const {},
    this.mutedBy = const {},
    this.archivedBy = const {},
    this.pinnedBy = const {},
    this.deletedBy = const {},
    this.autoDeleteAfterSeconds,
    this.requestStatus = ConversationRequestStatus.none,
    this.requesterId,
    this.requestedAt,
    this.respondedAt,
  });

  final Map<String, DateTime> deletedBy;

  /// Check if conversation is muted by user.
  /// Returns true if muted forever (null value) or muted until a future time.
  bool isMutedBy(String userId) {
    if (!mutedBy.containsKey(userId)) return false;
    final muteUntil = mutedBy[userId];
    if (muteUntil == null) return true; // Muted forever
    return muteUntil.isAfter(DateTime.now()); // Check if not expired
  }

  /// Get mute expiration time for user (null = forever, no entry = not muted)
  DateTime? getMuteExpirationFor(String userId) => mutedBy[userId];
  bool isArchivedBy(String userId) => archivedBy[userId] ?? false;
  bool isPinnedBy(String userId) => pinnedBy.containsKey(userId);
  DateTime? pinnedAtBy(String userId) => pinnedBy[userId];
  bool isDeletedFor(String userId) => deletedBy.containsKey(userId);

  bool get isGroup => type == ConversationType.group;
  bool get isIndividual => type == ConversationType.individual;

  /// « Mes notes » : conversation avec soi-même (unique participant = moi).
  /// Sert de brouillon/scratchpad ; chiffrée au repos avec la clé AES globale.
  ///
  /// Un GROUPE est exclu explicitement : « un seul participant, et c'est moi »
  /// est vrai aussi d'un groupe qu'on vient de créer et que personne n'a
  /// encore rejoint. Sans cette garde, un tel groupe était pris pour « Mes
  /// notes » — constaté sur appareil le 2026-08-05, avec quatre conséquences :
  /// il disparaissait de la liste des messages (`_filterConversations` le
  /// retirait comme doublon) tout en alimentant la tuile épinglée « Mes
  /// notes », qui affichait son dernier message ; il restait pourtant compté
  /// dans le « N groupes actifs » de l'en-tête, si bien que la liste
  /// contredisait son propre titre ; l'en-tête de la conversation affichait
  /// « Mes notes » à la place du nom du groupe ; et surtout ses messages
  /// partaient chiffrés en note vers soi (AES global) au lieu du chemin de
  /// groupe.
  ///
  /// `groupId == null` double la garde : une conversation peut porter un
  /// `group_id` sans que son `type` ait été posé à `group` (cf. la
  /// réconciliation de `ConversationScreen`, qui teste les deux).
  bool isSelfNotesFor(String userId) =>
      !isGroup &&
      groupId == null &&
      participantIds.length == 1 &&
      participantIds.first == userId;

  int getUnreadCountFor(String userId) => unreadCount[userId] ?? 0;
  bool hasUnreadFor(String userId) => getUnreadCountFor(userId) > 0;

  int getUnreadMentionsFor(String userId) => unreadMentions[userId] ?? 0;
  bool hasUnreadMentionFor(String userId) => getUnreadMentionsFor(userId) > 0;

  String getOtherParticipantId(String currentUserId) {
    return participantIds.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );
  }

  /// Check if ephemeral messages are enabled
  bool get hasAutoDelete => autoDeleteAfterSeconds != null;

  /// Get human-readable auto-delete duration
  String? get autoDeleteLabel {
    if (autoDeleteAfterSeconds == null) return null;
    if (autoDeleteAfterSeconds == 86400) return '24h';
    if (autoDeleteAfterSeconds == 604800) return '7d';
    if (autoDeleteAfterSeconds == 2592000) return '30d';
    return '${autoDeleteAfterSeconds}s';
  }

  /// Check if this is a pending message request
  bool get isPendingRequest =>
      requestStatus == ConversationRequestStatus.pending;

  /// Check if user is the requester (sender of the message request)
  bool isRequester(String userId) => requesterId == userId;

  /// Check if user is the recipient of the message request
  bool isRequestRecipient(String userId) =>
      isPendingRequest && requesterId != null && requesterId != userId;

  ConversationEntity copyWith({
    String? id,
    ConversationType? type,
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
    Map<String, int>? unreadCount,
    Map<String, int>? unreadMentions,
    Map<String, DateTime?>? mutedBy,
    Map<String, bool>? archivedBy,
    Map<String, DateTime>? pinnedBy,
    Map<String, DateTime>? deletedBy,
    int? autoDeleteAfterSeconds,
    ConversationRequestStatus? requestStatus,
    String? requesterId,
    DateTime? requestedAt,
    DateTime? respondedAt,
  }) {
    return ConversationEntity(
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
      lastMessageDeliveredTo:
          lastMessageDeliveredTo ?? this.lastMessageDeliveredTo,
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

  @override
  List<Object?> get props => [
    id,
    type,
    name,
    imageUrl,
    groupId,
    participantIds,
    adminIds,
    reportedBy,
    lastMessage,
    lastMessageSenderId,
    lastMessageStatus,
    lastMessageType,
    lastMessageAt,
    lastMessageReadBy,
    lastMessageDeliveredTo,
    createdAt,
    createdBy,
    unreadCount,
    unreadMentions,
    mutedBy,
    archivedBy,
    pinnedBy,
    deletedBy,
    autoDeleteAfterSeconds,
    requestStatus,
    requesterId,
    requestedAt,
    respondedAt,
  ];
}
