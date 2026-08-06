import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/message_entity.dart';
import 'message_provider.dart';

part 'media_gallery_provider.g.dart';

/// State for media gallery pagination
class MediaGalleryState {
  final List<MessageEntity> images;
  final List<MessageEntity> videos;
  final List<MessageEntity> files;
  final bool isLoading;
  final bool hasMore;
  final String? lastMessageId;
  final String? error;

  const MediaGalleryState({
    this.images = const [],
    this.videos = const [],
    this.files = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.lastMessageId,
    this.error,
  });

  MediaGalleryState copyWith({
    List<MessageEntity>? images,
    List<MessageEntity>? videos,
    List<MessageEntity>? files,
    bool? isLoading,
    bool? hasMore,
    String? lastMessageId,
    String? error,
  }) {
    return MediaGalleryState(
      images: images ?? this.images,
      videos: videos ?? this.videos,
      files: files ?? this.files,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      lastMessageId: lastMessageId ?? this.lastMessageId,
      error: error,
    );
  }

  int get totalCount => images.length + videos.length + files.length;
  bool get isEmpty => images.isEmpty && videos.isEmpty && files.isEmpty;
}

/// Provider for fetching media (images and files) from a conversation
/// Excludes audio messages
@riverpod
class ConversationMedia extends _$ConversationMedia {
  static const int _pageSize = 50;

  @override
  MediaGalleryState build(String conversationId) {
    // Charger les médias immédiatement
    _loadInitial();
    return const MediaGalleryState(isLoading: true);
  }

  Future<void> _loadInitial() async {
    try {
      final result = await ref.read(messageRepositoryProvider).getMediaMessages(
            conversationId: conversationId,
            limit: _pageSize,
          );

      result.fold(
        (failure) {
          state = MediaGalleryState(error: failure.message, isLoading: false);
        },
        (messages) {
          final images = messages
              .where((m) => m.type == MessageType.image)
              .toList();
          final videos = messages
              .where((m) => m.type == MessageType.video)
              .toList();
          final files = messages
              .where((m) => m.type == MessageType.file)
              .toList();

          state = MediaGalleryState(
            images: images,
            videos: videos,
            files: files,
            hasMore: messages.length >= _pageSize,
            lastMessageId: messages.isNotEmpty ? messages.last.id : null,
            isLoading: false,
          );
        },
      );
    } catch (e) {
      state = MediaGalleryState(error: e.toString(), isLoading: false);
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
          final newVideos = messages
              .where((m) => m.type == MessageType.video)
              .toList();
          final newFiles = messages
              .where((m) => m.type == MessageType.file)
              .toList();

          state = state.copyWith(
            images: [...state.images, ...newImages],
            videos: [...state.videos, ...newVideos],
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
  final currentUser = await ref.read(currentUserAsyncProvider.future);
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
/// Returns the conversation ID if a conversation exists with the given group ID
@riverpod
Future<String?> groupConversationId(Ref ref, String groupId) async {
  final currentUser = await ref.read(currentUserAsyncProvider.future);
  if (currentUser == null) return null;

  final result = await ref
      .read(messageRepositoryProvider)
      .findGroupConversationByGroupId(
        groupId: groupId,
        userId: currentUser.id,
      );

  return result.fold(
    (failure) => null,
    (conversationId) => conversationId,
  );
}
