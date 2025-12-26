import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/message_entity.dart';
import 'message_provider.dart';

part 'media_gallery_provider.g.dart';

/// State for media gallery pagination
class MediaGalleryState {
  final List<MessageEntity> images;
  final List<MessageEntity> files;
  final bool isLoading;
  final bool hasMore;
  final String? lastMessageId;
  final String? error;

  const MediaGalleryState({
    this.images = const [],
    this.files = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.lastMessageId,
    this.error,
  });

  MediaGalleryState copyWith({
    List<MessageEntity>? images,
    List<MessageEntity>? files,
    bool? isLoading,
    bool? hasMore,
    String? lastMessageId,
    String? error,
  }) {
    return MediaGalleryState(
      images: images ?? this.images,
      files: files ?? this.files,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      lastMessageId: lastMessageId ?? this.lastMessageId,
      error: error,
    );
  }

  int get totalCount => images.length + files.length;
  bool get isEmpty => images.isEmpty && files.isEmpty;
}

/// Provider for fetching media (images and files) from a conversation
/// Excludes audio messages
@riverpod
class ConversationMedia extends _$ConversationMedia {
  static const int _pageSize = 50;

  @override
  MediaGalleryState build(String conversationId) {
    // Load initial media after widget builds
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (state.isLoading || state.images.isNotEmpty || state.files.isNotEmpty) {
        return;
      }
      _loadInitial();
    });

    return const MediaGalleryState(isLoading: true);
  }

  Future<void> _loadInitial() async {
    state = const MediaGalleryState(isLoading: true);

    try {
      final result = await ref.read(messageRepositoryProvider).getMediaMessages(
            conversationId: conversationId,
            limit: _pageSize,
          );

      result.fold(
        (failure) {
          state = MediaGalleryState(error: failure.message);
        },
        (messages) {
          final images = messages
              .where((m) => m.type == MessageType.image)
              .toList();
          final files = messages
              .where((m) => m.type == MessageType.file)
              .toList();

          state = MediaGalleryState(
            images: images,
            files: files,
            hasMore: messages.length >= _pageSize,
            lastMessageId: messages.isNotEmpty ? messages.last.id : null,
          );
        },
      );
    } catch (e) {
      state = MediaGalleryState(error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;

    state = state.copyWith(isLoading: true);

    try {
      final result = await ref.read(messageRepositoryProvider).getMediaMessages(
            conversationId: conversationId,
            limit: _pageSize,
            beforeMessageId: state.lastMessageId,
          );

      result.fold(
        (failure) {
          state = state.copyWith(isLoading: false, error: failure.message);
        },
        (messages) {
          final newImages = messages
              .where((m) => m.type == MessageType.image)
              .toList();
          final newFiles = messages
              .where((m) => m.type == MessageType.file)
              .toList();

          state = state.copyWith(
            images: [...state.images, ...newImages],
            files: [...state.files, ...newFiles],
            hasMore: messages.length >= _pageSize,
            lastMessageId: messages.isNotEmpty ? messages.last.id : null,
            isLoading: false,
          );
        },
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() async {
    await _loadInitial();
  }
}

/// Provider to get the conversation ID for a user (for profile media section)
/// Returns the conversation ID if a conversation exists with the given user
@riverpod
Future<String?> userConversationId(Ref ref, String otherUserId) async {
  final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
  if (currentUser == null) return null;

  final result = await ref
      .read(messageRepositoryProvider)
      .findConversationWithUser(
        currentUserId: currentUser.id,
        otherUserId: otherUserId,
      );

  return result.fold(
    (failure) => null,
    (conversationId) => conversationId,
  );
}

/// Provider to get the conversation ID for a group (for group media section)
/// Returns the conversation ID if a conversation exists with the given group name
@riverpod
Future<String?> groupConversationId(Ref ref, String groupName) async {
  final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
  if (currentUser == null) return null;

  final result = await ref
      .read(messageRepositoryProvider)
      .findGroupConversationByName(
        groupName: groupName,
        userId: currentUser.id,
      );

  return result.fold(
    (failure) => null,
    (conversationId) => conversationId,
  );
}
