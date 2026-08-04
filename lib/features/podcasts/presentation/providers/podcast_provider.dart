import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/podcast_remote_datasource.dart';
import '../../data/datasources/podcast_supabase_datasource.dart';
import '../../data/models/podcast_episode_model.dart';
import '../../data/models/podcast_model.dart';
import '../../domain/entities/podcast_entity.dart';
import '../../domain/entities/podcast_episode_entity.dart';
import '../../domain/entities/podcast_user_data_entity.dart';

/// Provider for the podcast data source
final podcastDataSourceProvider = Provider<PodcastRemoteDataSource>((ref) {
  return PodcastSupabaseDataSource();
});

/// Stream of published podcasts
final publishedPodcastsProvider = StreamProvider<List<PodcastEntity>>((ref) {
  final dataSource = ref.watch(podcastDataSourceProvider);
  return dataSource
      .getPublishedPodcastsStream()
      .map((models) => models.map((m) => m.toEntity()).toList());
});

/// Stream of published podcasts with category filter
final publishedPodcastsByCategoryProvider =
    StreamProvider.family<List<PodcastEntity>, String?>((ref, category) {
  final dataSource = ref.watch(podcastDataSourceProvider);
  return dataSource
      .getPublishedPodcastsStream(category: category)
      .map((models) => models.map((m) => m.toEntity()).toList());
});

/// Stream of trending podcasts
final trendingPodcastsProvider = StreamProvider<List<PodcastEntity>>((ref) {
  final dataSource = ref.watch(podcastDataSourceProvider);
  return dataSource
      .getTrendingPodcastsStream()
      .map((models) => models.map((m) => m.toEntity()).toList());
});

/// Stream of user's podcasts (as host)
final myPodcastsProvider = StreamProvider<List<PodcastEntity>>((ref) {
  final userId = FirebaseAuth.instance.currentUser?.uid;
  if (userId == null) return Stream.value([]);

  final dataSource = ref.watch(podcastDataSourceProvider);
  return dataSource
      .getPodcastsByHostStream(userId)
      .map((models) => models.map((m) => m.toEntity()).toList());
});

/// Stream of a specific podcast
final podcastStreamProvider =
    StreamProvider.family<PodcastEntity?, String>((ref, podcastId) {
  final dataSource = ref.watch(podcastDataSourceProvider);
  return dataSource.getPodcastStream(podcastId).map((model) => model?.toEntity());
});

/// Stream of episodes for a podcast
final podcastEpisodesProvider =
    StreamProvider.family<List<PodcastEpisodeEntity>, String>((ref, podcastId) {
  final dataSource = ref.watch(podcastDataSourceProvider);
  return dataSource
      .getEpisodesStream(podcastId)
      .map((models) => models.map((m) => m.toEntity()).toList());
});

/// Stream of latest episodes
final latestEpisodesProvider = StreamProvider<List<PodcastEpisodeEntity>>((ref) {
  final dataSource = ref.watch(podcastDataSourceProvider);
  return dataSource
      .getLatestEpisodesStream()
      .map((models) => models.map((m) => m.toEntity()).toList());
});

/// Stream of a specific episode
final episodeProvider =
    StreamProvider.family<PodcastEpisodeEntity?, String>((ref, episodeId) {
  final dataSource = ref.watch(podcastDataSourceProvider);
  return dataSource.getEpisodeStream(episodeId).map((model) => model?.toEntity());
});

/// Stream of user's podcast data
final podcastUserDataProvider = StreamProvider<PodcastUserDataEntity?>((ref) {
  final userId = FirebaseAuth.instance.currentUser?.uid;
  if (userId == null) return Stream.value(null);

  final dataSource = ref.watch(podcastDataSourceProvider);
  return dataSource.getUserDataStream(userId).map((data) {
    if (data == null) return null;
    return PodcastUserDataEntity(
      userId: userId,
      subscribedPodcastIds: List<String>.from(data['subscribedPodcastIds'] ?? []),
      likedEpisodeIds: List<String>.from(data['likedEpisodeIds'] ?? []),
      downloadedEpisodeIds: List<String>.from(data['downloadedEpisodeIds'] ?? []),
      listenHistory: _parseListenHistory(data['listenHistory']),
      playbackSpeed: (data['playbackSpeed'] as num?)?.toDouble() ?? 1.0,
      preferredCategories: List<String>.from(data['preferredCategories'] ?? []),
    );
  });
});

List<PodcastListenHistoryEntry> _parseListenHistory(dynamic data) {
  if (data == null) return [];
  if (data is! List) return [];
  return data.map((e) {
    final map = Map<String, dynamic>.from(e as Map);
    return PodcastListenHistoryEntry(
      episodeId: map['episodeId'] as String,
      listenedAt: DateTime.parse(map['listenedAt'] as String).toLocal(),
      progressSeconds: map['progressSeconds'] as int,
      completed: map['completed'] as bool? ?? false,
    );
  }).toList();
}

/// Check if user is subscribed to a podcast (free or paid)
final isSubscribedProvider = Provider.family<bool, String>((ref, podcastId) {
  final userData = ref.watch(podcastUserDataProvider).valueOrNull;
  return userData?.isSubscribedTo(podcastId) ?? false;
});

/// Check if user has liked an episode
final hasLikedEpisodeProvider = Provider.family<bool, String>((ref, episodeId) {
  final userData = ref.watch(podcastUserDataProvider).valueOrNull;
  return userData?.hasLiked(episodeId) ?? false;
});

/// Provider for podcast notifier
final podcastNotifierProvider =
    AsyncNotifierProvider<PodcastNotifier, void>(PodcastNotifier.new);

/// Notifier for podcast actions
class PodcastNotifier extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  PodcastRemoteDataSource get _dataSource => ref.read(podcastDataSourceProvider);
  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  /// Create a new podcast
  Future<PodcastEntity?> createPodcast({
    required String title,
    String? description,
    required File coverImage,
    required PodcastCategory category,
    required String language,
    List<String> tags = const [],
    bool isExplicit = false,
    String? episodeFrequency,
  }) async {
    try {
      state = const AsyncLoading();

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Create initial podcast to get ID
      final tempModel = PodcastModel(
        id: '',
        title: title,
        description: description,
        coverImageUrl: '',
        hostId: user.uid,
        hostName: user.displayName ?? 'Unknown',
        hostPhotoUrl: user.photoURL,
        category: category.name,
        language: language,
        tags: tags,
        isExplicit: isExplicit,
        status: 'draft',
        episodeFrequency: episodeFrequency,
        createdAt: DateTime.now().toIso8601String(),
      );

      final createdModel = await _dataSource.createPodcast(tempModel);

      // Upload cover image
      final coverUrl = await _dataSource.uploadPodcastCover(
        podcastId: createdModel.id,
        file: coverImage,
      );

      // Update with cover URL and publish
      await _dataSource.updatePodcast(createdModel.id, {
        'coverImageUrl': coverUrl,
        'status': 'published',
      });

      state = const AsyncData(null);
      return createdModel.toEntity().copyWith(
            coverImageUrl: coverUrl,
            status: PodcastStatus.published,
          );
    } catch (e, st) {
      debugPrint('PodcastNotifier: Error creating podcast: $e');
      state = AsyncError(e, st);
      return null;
    }
  }

  /// Create a new episode (audio or video)
  Future<PodcastEpisodeEntity?> createEpisode({
    required String podcastId,
    required String title,
    String? description,
    required File audioFile,
    required int durationSeconds,
    File? coverImage,
    String? sourceRoomId,
    List<ChapterEntity> chapters = const [],
    bool isPremium = false,
    DateTime? scheduledPublishAt,
    String mediaType = 'audio',
    String? videoUrl,
    String? thumbnailUrl,
    /// Enregistre sans publier (§2d). Un brouillon n'obtient pas de date de
    /// publication : le datasource ne pose `published_at` que sur un épisode
    /// publié, et les statistiques de rythme n'ont donc rien à mesurer.
    bool asDraft = false,
  }) async {
    try {
      state = const AsyncLoading();

      if (_userId == null) throw Exception('User not authenticated');

      // Get next episode number
      final episodeNumber = await _dataSource.getNextEpisodeNumber(podcastId);

      // Generate temp ID for storage path
      final tempId = DateTime.now().millisecondsSinceEpoch.toString();

      // For video episodes there is no separate audio file to upload.
      final isVideoEpisode = mediaType == 'video' || mediaType == 'live_video';

      final audioUrl = isVideoEpisode
          ? ''
          : await _dataSource.uploadEpisodeAudio(
              podcastId: podcastId,
              episodeId: tempId,
              file: audioFile,
            );

      final fileSizeBytes =
          isVideoEpisode ? 0 : await audioFile.length();

      final episodeModel = PodcastEpisodeModel(
        id: '',
        podcastId: podcastId,
        episodeNumber: episodeNumber,
        title: title,
        description: description,
        audioUrl: audioUrl,
        durationSeconds: durationSeconds,
        fileSizeBytes: fileSizeBytes,
        sourceRoomId: sourceRoomId,
        chapters: chapters.map((c) => ChapterModel.fromEntity(c)).toList(),
        status:
            asDraft
                ? 'draft'
                : scheduledPublishAt != null
                ? 'scheduled'
                : 'published',
        scheduledPublishAt: scheduledPublishAt?.toIso8601String(),
        // Un brouillon n'est pas publié : pas de date de publication, sinon
        // il compterait dans le rythme de publication des statistiques.
        publishedAt: (asDraft || scheduledPublishAt != null)
            ? null
            : DateTime.now().toIso8601String(),
        createdAt: DateTime.now().toIso8601String(),
        isPremium: isPremium,
        mediaType: mediaType,
        videoUrl: videoUrl,
        thumbnailUrl: thumbnailUrl,
      );

      final createdEpisode = await _dataSource.createEpisode(episodeModel);

      state = const AsyncData(null);
      return createdEpisode.toEntity();
    } catch (e, st) {
      debugPrint('PodcastNotifier: Error creating episode: $e');
      state = AsyncError(e, st);
      return null;
    }
  }

  /// Subscribe to a free podcast
  Future<void> subscribe(PodcastEntity podcast) async {
    try {
      if (_userId == null) return;
      await _dataSource.subscribeToPodcast(
        podcastId: podcast.id,
        podcastTitle: podcast.title,
        userId: _userId!,
        podcastCoverUrl: podcast.coverImageUrl,
      );
      ref.invalidate(podcastUserDataProvider);
    } catch (e) {
      debugPrint('PodcastNotifier: Error subscribing: $e');
    }
  }

  /// Unsubscribe from a podcast
  Future<void> unsubscribe(String podcastId) async {
    try {
      if (_userId == null) return;
      await _dataSource.unsubscribeFromPodcast(
        podcastId: podcastId,
        userId: _userId!,
      );
      ref.invalidate(podcastUserDataProvider);
    } catch (e) {
      debugPrint('PodcastNotifier: Error unsubscribing: $e');
    }
  }

  /// Like an episode
  Future<void> likeEpisode(String episodeId) async {
    try {
      if (_userId == null) return;
      await _dataSource.likeEpisode(episodeId, _userId!);
      ref.invalidate(podcastUserDataProvider);
    } catch (e) {
      debugPrint('PodcastNotifier: Error liking: $e');
    }
  }

  /// Unlike an episode
  Future<void> unlikeEpisode(String episodeId) async {
    try {
      if (_userId == null) return;
      await _dataSource.unlikeEpisode(episodeId, _userId!);
      ref.invalidate(podcastUserDataProvider);
    } catch (e) {
      debugPrint('PodcastNotifier: Error unliking: $e');
    }
  }

  /// Record a play
  Future<void> recordPlay(String episodeId, String podcastId) async {
    try {
      await _dataSource.recordPlay(episodeId, podcastId);
    } catch (e) {
      debugPrint('PodcastNotifier: Error recording play: $e');
    }
  }

  /// Comptabilise un partage. Silencieux en cas d'échec : le partage lui-même
  /// a déjà eu lieu, ce n'est pas à la statistique de le faire échouer.
  Future<void> recordShare(String episodeId) async {
    try {
      await _dataSource.recordShare(episodeId);
    } catch (e) {
      debugPrint('PodcastNotifier: Error recording share: $e');
    }
  }

  /// Comptabilise un téléchargement, même logique.
  Future<void> recordDownload(String episodeId) async {
    try {
      await _dataSource.recordDownload(episodeId);
    } catch (e) {
      debugPrint('PodcastNotifier: Error recording download: $e');
    }
  }

  /// Update listen progress
  Future<void> updateProgress({
    required String episodeId,
    required int progressSeconds,
    required bool completed,
  }) async {
    try {
      if (_userId == null) return;
      await _dataSource.updateListenProgress(
        episodeId: episodeId,
        userId: _userId!,
        progressSeconds: progressSeconds,
        completed: completed,
      );
    } catch (e) {
      debugPrint('PodcastNotifier: Error updating progress: $e');
    }
  }

  /// Search podcasts
  Future<List<PodcastEntity>> search(String query) async {
    try {
      final results = await _dataSource.searchPodcasts(query);
      return results.map((m) => m.toEntity()).toList();
    } catch (e) {
      debugPrint('PodcastNotifier: Error searching: $e');
      return [];
    }
  }

  /// Delete a podcast
  Future<void> deletePodcast(String podcastId) async {
    try {
      state = const AsyncLoading();
      await _dataSource.deletePodcast(podcastId);
      ref.invalidate(myPodcastsProvider);
      state = const AsyncData(null);
    } catch (e, st) {
      debugPrint('PodcastNotifier: Error deleting: $e');
      state = AsyncError(e, st);
    }
  }

  /// Toggle podcast status (publish/pause)
  Future<void> togglePodcastStatus(String podcastId, PodcastStatus currentStatus) async {
    try {
      state = const AsyncLoading();
      final newStatus = currentStatus == PodcastStatus.published
          ? 'paused'
          : 'published';
      await _dataSource.updatePodcast(podcastId, {'status': newStatus});
      ref.invalidate(myPodcastsProvider);
      ref.invalidate(podcastStreamProvider(podcastId));
      state = const AsyncData(null);
    } catch (e, st) {
      debugPrint('PodcastNotifier: Error toggling status: $e');
      state = AsyncError(e, st);
    }
  }

  /// Delete an episode
  Future<void> deleteEpisode(String episodeId, String podcastId) async {
    try {
      state = const AsyncLoading();
      await _dataSource.deleteEpisode(episodeId, podcastId);
      ref.invalidate(podcastEpisodesProvider(podcastId));
      state = const AsyncData(null);
    } catch (e, st) {
      debugPrint('PodcastNotifier: Error deleting episode: $e');
      state = AsyncError(e, st);
    }
  }
}
