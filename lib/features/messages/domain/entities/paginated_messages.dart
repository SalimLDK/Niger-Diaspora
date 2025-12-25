import 'package:equatable/equatable.dart';

import 'message_entity.dart';

class PaginatedMessages extends Equatable {
  final List<MessageEntity> messages;
  final bool hasMore;
  final String? lastMessageId;
  final DateTime? oldestMessageTimestamp;

  const PaginatedMessages({
    required this.messages,
    required this.hasMore,
    this.lastMessageId,
    this.oldestMessageTimestamp,
  });

  const PaginatedMessages.empty()
      : messages = const [],
        hasMore = false,
        lastMessageId = null,
        oldestMessageTimestamp = null;

  PaginatedMessages copyWith({
    List<MessageEntity>? messages,
    bool? hasMore,
    String? lastMessageId,
    DateTime? oldestMessageTimestamp,
  }) {
    return PaginatedMessages(
      messages: messages ?? this.messages,
      hasMore: hasMore ?? this.hasMore,
      lastMessageId: lastMessageId ?? this.lastMessageId,
      oldestMessageTimestamp:
          oldestMessageTimestamp ?? this.oldestMessageTimestamp,
    );
  }

  PaginatedMessages prependMessages(List<MessageEntity> olderMessages) {
    return PaginatedMessages(
      messages: [...olderMessages, ...messages],
      hasMore: hasMore,
      lastMessageId: olderMessages.isNotEmpty ? olderMessages.first.id : lastMessageId,
      oldestMessageTimestamp: olderMessages.isNotEmpty
          ? olderMessages.first.createdAt
          : oldestMessageTimestamp,
    );
  }

  PaginatedMessages appendMessage(MessageEntity newMessage) {
    return PaginatedMessages(
      messages: [...messages, newMessage],
      hasMore: hasMore,
      lastMessageId: lastMessageId,
      oldestMessageTimestamp: oldestMessageTimestamp,
    );
  }

  @override
  List<Object?> get props => [messages, hasMore, lastMessageId, oldestMessageTimestamp];
}
