import 'package:equatable/equatable.dart';

enum ConversationType { individual, group }

class ConversationEntity extends Equatable {
  final String id;
  final ConversationType type;
  final String? name;
  final String? imageUrl;
  final List<String> participantIds;
  final String? lastMessage;
  final String? lastMessageSenderId;
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
    required this.participantIds,
    this.lastMessage,
    this.lastMessageSenderId,
    this.lastMessageAt,
    required this.createdAt,
    required this.createdBy,
    this.unreadCount = const {},
    this.mutedBy = const {},
    this.archivedBy = const {},
  });

  bool isMutedBy(String userId) => mutedBy[userId] ?? false;
  bool isArchivedBy(String userId) => archivedBy[userId] ?? false;

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
    List<String>? participantIds,
    String? lastMessage,
    String? lastMessageSenderId,
    DateTime? lastMessageAt,
    DateTime? createdAt,
    String? createdBy,
    Map<String, int>? unreadCount,
    Map<String, bool>? mutedBy,
    Map<String, bool>? archivedBy,
  }) {
    return ConversationEntity(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      participantIds: participantIds ?? this.participantIds,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      unreadCount: unreadCount ?? this.unreadCount,
      mutedBy: mutedBy ?? this.mutedBy,
      archivedBy: archivedBy ?? this.archivedBy,
    );
  }

  @override
  List<Object?> get props => [
        id,
        type,
        name,
        imageUrl,
        participantIds,
        lastMessage,
        lastMessageSenderId,
        lastMessageAt,
        createdAt,
        createdBy,
        unreadCount,
        mutedBy,
        archivedBy,
      ];
}
