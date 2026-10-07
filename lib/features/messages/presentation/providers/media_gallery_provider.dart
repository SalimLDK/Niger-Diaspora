import 'dart:async';

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

  /// Date du plus ancien média chargé : avec [lastMessageId], le curseur
  /// `(created_at, id)` de la page suivante.
  final DateTime? lastCreatedAt;
  final String? error;

  const MediaGalleryState({
    this.images = const [],
    this.videos = const [],
    this.files = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.lastMessageId,
    this.lastCreatedAt,
    this.error,
  });

  MediaGalleryState copyWith({
    List<MessageEntity>? images,
    List<MessageEntity>? videos,
    List<MessageEntity>? files,
    bool? isLoading,
    bool? hasMore,
    String? lastMessageId,
    DateTime? lastCreatedAt,
    String? error,
  }) {
    return MediaGalleryState(
      images: images ?? this.images,
      videos: videos ?? this.videos,
      files: files ?? this.files,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      lastMessageId: lastMessageId ?? this.lastMessageId,
      lastCreatedAt: lastCreatedAt ?? this.lastCreatedAt,
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
    unawaited(_loadInitial());
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
            lastCreatedAt: messages.isNotEmpty ? messages.last.createdAt : null,
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
            beforeCreatedAt: state.lastCreatedAt,
          );

      result.fold(
        (failure) {
          state = state.copyWith(isLoading: false, error: failure.message);
        },
        (page) {
          // Un média déjà affiché ne revient pas : la page suivante part du
          // curseur, mais un ex-aequo de date ou une entrée du cache peut se
          // présenter deux fois.
          final dejaVus = {
            for (final m in [...state.images, ...state.videos, ...state.files])
              m.id,
          };
          final messages = [
            for (final m in page)
              if (!dejaVus.contains(m.id)) m,
          ];
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
            // Une page sans aucun média neuf est la dernière, quoi qu'en dise
            // sa taille : sinon « charger plus » tournerait sur place.
            hasMore: page.length >= _pageSize && messages.isNotEmpty,
            lastMessageId:
                messages.isNotEmpty ? messages.last.id : state.lastMessageId,
            lastCreatedAt: messages.isNotEmpty
                ? messages.last.createdAt
                : state.lastCreatedAt,
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
