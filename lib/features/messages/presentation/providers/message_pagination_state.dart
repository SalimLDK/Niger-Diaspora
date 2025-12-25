import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/message_entity.dart';

part 'message_pagination_state.freezed.dart';

@freezed
class MessagePaginationState with _$MessagePaginationState {
  const MessagePaginationState._();

  const factory MessagePaginationState({
    @Default([]) List<MessageEntity> messages,
    @Default(false) bool isLoadingInitial,
    @Default(false) bool isLoadingMore,
    @Default(true) bool hasMore,
    String? lastMessageId,
    DateTime? oldestMessageTimestamp,
    String? error,
    @Default(false) bool isOffline,
  }) = _MessagePaginationState;

  bool get isEmpty => messages.isEmpty && !isLoadingInitial;
  bool get canLoadMore => hasMore && !isLoadingMore && !isLoadingInitial;

  MessagePaginationState addNewMessage(MessageEntity message) {
    return copyWith(
      messages: [...messages, message],
    );
  }

  MessagePaginationState prependOlderMessages(List<MessageEntity> olderMessages) {
    return copyWith(
      messages: [...olderMessages, ...messages],
      lastMessageId: olderMessages.isNotEmpty ? olderMessages.first.id : lastMessageId,
      oldestMessageTimestamp: olderMessages.isNotEmpty
          ? olderMessages.first.createdAt
          : oldestMessageTimestamp,
    );
  }
}
