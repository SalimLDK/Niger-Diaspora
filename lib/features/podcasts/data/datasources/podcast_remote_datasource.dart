import 'dart:io';

import '../models/podcast_episode_model.dart';
import '../models/podcast_model.dart';

abstract class PodcastRemoteDataSource {
  Future<PodcastModel> createPodcast(PodcastModel podcast);
  Future<PodcastModel?> getPodcast(String podcastId);
  Future<void> updatePodcast(String podcastId, Map<String, dynamic> data);
  Future<void> deletePodcast(String podcastId);

  Stream<List<PodcastModel>> getPublishedPodcastsStream({
    String? category,
    int limit = 20,
  });
  Stream<List<PodcastModel>> getTrendingPodcastsStream({int limit = 10});
  Stream<List<PodcastModel>> getPodcastsByHostStream(String hostId);
  Stream<PodcastModel?> getPodcastStream(String podcastId);
  Future<List<PodcastModel>> searchPodcasts(String query);

  Future<PodcastEpisodeModel> createEpisode(PodcastEpisodeModel episode);
  Future<PodcastEpisodeModel?> getEpisode(String episodeId);
  Future<void> updateEpisode(String episodeId, Map<String, dynamic> data);
  Future<void> deleteEpisode(String episodeId, String podcastId);
  Stream<List<PodcastEpisodeModel>> getEpisodesStream(String podcastId);
  Stream<List<PodcastEpisodeModel>> getLatestEpisodesStream({int limit = 20});
  Stream<PodcastEpisodeModel?> getEpisodeStream(String episodeId);
  Future<int> getNextEpisodeNumber(String podcastId);

  Future<void> subscribeToPodcast({
    required String podcastId,
    required String podcastTitle,
    required String userId,
    String? podcastCoverUrl,
  });
  Future<void> unsubscribeFromPodcast({
    required String podcastId,
    required String userId,
  });
  Stream<List<Map<String, dynamic>>> getUserSubscriptionsStream(String userId);

  Future<void> recordPlay(String episodeId, String podcastId);
  Future<void> likeEpisode(String episodeId, String userId);
  Future<void> unlikeEpisode(String episodeId, String userId);
  Future<void> updateListenProgress({
    required String episodeId,
    required String userId,
    required int progressSeconds,
    required bool completed,
  });

  Future<Map<String, dynamic>?> getUserData(String userId);
  Stream<Map<String, dynamic>?> getUserDataStream(String userId);

  Future<String> uploadPodcastCover({
    required String podcastId,
    required File file,
  });
  Future<String> uploadEpisodeAudio({
    required String podcastId,
    required String episodeId,
    required File file,
    void Function(double)? onProgress,
  });
}
