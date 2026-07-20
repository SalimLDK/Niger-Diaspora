import 'package:equatable/equatable.dart';

/// Entry in the user's listen history
class PodcastListenHistoryEntry extends Equatable {
  /// Episode ID
  final String episodeId;

  /// When the episode was listened to
  final DateTime listenedAt;

  /// Progress in seconds
  final int progressSeconds;

  /// Whether the episode was completed
  final bool completed;

  const PodcastListenHistoryEntry({
    required this.episodeId,
    required this.listenedAt,
    required this.progressSeconds,
    this.completed = false,
  });

  PodcastListenHistoryEntry copyWith({
    String? episodeId,
    DateTime? listenedAt,
    int? progressSeconds,
    bool? completed,
  }) {
    return PodcastListenHistoryEntry(
      episodeId: episodeId ?? this.episodeId,
      listenedAt: listenedAt ?? this.listenedAt,
      progressSeconds: progressSeconds ?? this.progressSeconds,
      completed: completed ?? this.completed,
    );
  }

  @override
  List<Object?> get props => [episodeId, listenedAt, progressSeconds, completed];
}

/// Entity representing user-specific podcast data
class PodcastUserDataEntity extends Equatable {
  /// User ID
  final String userId;

  /// List of subscribed podcast IDs
  final List<String> subscribedPodcastIds;

  /// List of liked episode IDs
  final List<String> likedEpisodeIds;

  /// List of downloaded episode IDs
  final List<String> downloadedEpisodeIds;

  /// Listen history (last 100 entries)
  final List<PodcastListenHistoryEntry> listenHistory;

  /// Preferred playback speed (0.5 - 2.0)
  final double playbackSpeed;

  /// Preferred categories
  final List<String> preferredCategories;

  const PodcastUserDataEntity({
    required this.userId,
    this.subscribedPodcastIds = const [],
    this.likedEpisodeIds = const [],
    this.downloadedEpisodeIds = const [],
    this.listenHistory = const [],
    this.playbackSpeed = 1.0,
    this.preferredCategories = const [],
  });

  /// Check if user is subscribed to a podcast
  bool isSubscribedTo(String podcastId) => subscribedPodcastIds.contains(podcastId);

  /// Check if user has liked an episode
  bool hasLiked(String episodeId) => likedEpisodeIds.contains(episodeId);

  /// Check if an episode is downloaded
  bool isDownloaded(String episodeId) => downloadedEpisodeIds.contains(episodeId);

  /// Get progress for an episode
  PodcastListenHistoryEntry? getProgress(String episodeId) {
    try {
      return listenHistory.firstWhere((entry) => entry.episodeId == episodeId);
    } catch (_) {
      return null;
    }
  }

  /// Get episodes in progress (started but not completed)
  List<PodcastListenHistoryEntry> get inProgressEpisodes {
    return listenHistory
        .where((entry) => !entry.completed && entry.progressSeconds > 0)
        .toList();
  }

  /// Copy with new values
  PodcastUserDataEntity copyWith({
    String? userId,
    List<String>? subscribedPodcastIds,
    List<String>? likedEpisodeIds,
    List<String>? downloadedEpisodeIds,
    List<PodcastListenHistoryEntry>? listenHistory,
    double? playbackSpeed,
    List<String>? preferredCategories,
  }) {
    return PodcastUserDataEntity(
      userId: userId ?? this.userId,
      subscribedPodcastIds: subscribedPodcastIds ?? this.subscribedPodcastIds,
      likedEpisodeIds: likedEpisodeIds ?? this.likedEpisodeIds,
      downloadedEpisodeIds: downloadedEpisodeIds ?? this.downloadedEpisodeIds,
      listenHistory: listenHistory ?? this.listenHistory,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      preferredCategories: preferredCategories ?? this.preferredCategories,
    );
  }

  @override
  List<Object?> get props => [
        userId,
        subscribedPodcastIds,
        likedEpisodeIds,
        downloadedEpisodeIds,
        playbackSpeed,
      ];
}
