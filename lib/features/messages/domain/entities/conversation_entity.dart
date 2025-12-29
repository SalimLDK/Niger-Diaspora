import 'package:equatable/equatable.dart';

import 'message_entity.dart';

enum ConversationType { individual, group }

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
  final DateTime? lastMessageAt;
  final DateTime createdAt;
  final String createdBy;
  final Map<String, int> unreadCount;
  final Map<String, bool> mutedBy;
  final Map<String, bool> archivedBy;

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
    this.lastMessageAt,
    required this.createdAt,
    required this.createdBy,
    this.unreadCount = const {},
    this.mutedBy = const {},
    this.archivedBy = const {},
    this.deletedBy = const {},
  });

  final Map<String, DateTime> deletedBy;

  bool isMutedBy(String userId) => mutedBy[userId] ?? false;
  bool isArchivedBy(String userId) => archivedBy[userId] ?? false;
  bool isDeletedFor(String userId) => deletedBy.containsKey(userId);

  bool get isGroup => type == ConversationType.group;
  bool get isIndividual => type == ConversationType.individual;

  int getUnreadCountFor(String userId) => unreadCount[userId] ?? 0;

  bool hasUnreadFor(String userId) => getUnreadCountFor(userId) > 0;

  String getOtherParticipantId(String currentUserId) {
    return participantIds.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );
  }

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
    DateTime? lastMessageAt,
    DateTime? createdAt,
    String? createdBy,
    Map<String, int>? unreadCount,
    Map<String, bool>? mutedBy,
    Map<String, bool>? archivedBy,
    Map<String, DateTime>? deletedBy,
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
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      unreadCount: unreadCount ?? this.unreadCount,
      mutedBy: mutedBy ?? this.mutedBy,
      archivedBy: archivedBy ?? this.archivedBy,
      deletedBy: deletedBy ?? this.deletedBy,
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
    lastMessageAt,
    createdAt,
    createdBy,
    unreadCount,
    mutedBy,
    archivedBy,
    deletedBy,
  ];
}
