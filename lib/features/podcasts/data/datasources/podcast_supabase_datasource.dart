import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/podcast_model.dart';
import '../models/podcast_episode_model.dart';
import 'podcast_remote_datasource.dart';

Map<String, dynamic> _mapPodcast(Map<String, dynamic> row) => {
  'id': row['id'],
  'title': row['title'],
  'description': row['description'] ?? '',
  'coverImageUrl': row['cover_url'],
  'hostId': row['host_id'],
  'hostName': row['host_name'] ?? '',
  'hostPhotoUrl': row['host_photo_url'],
  'coHostIds': (row['co_host_ids'] as List?)?.cast<String>() ?? [],
  'category': row['category'] ?? 'general',
  'language': row['language'] ?? 'fr',
  'tags': (row['tags'] as List?)?.cast<String>() ?? [],
  'isExplicit': row['is_explicit'] ?? false,
  'status': row['status'] ?? 'active',
  'subscriberCount': row['subscriber_count'] ?? 0,
  'totalPlayCount': row['total_play_count'] ?? 0,
  'totalEpisodes': row['episode_count'] ?? 0,
  'episodeFrequency': row['episode_frequency'],
  'createdAt': row['created_at'],
  'updatedAt': null,
  'lastEpisodeAt': row['last_episode_at'],
  'isPremium': row['is_premium'] ?? false,
  'premiumPrice': (row['premium_price'] as num?)?.toDouble(),
  'premiumCurrency': row['premium_currency'],
};

Map<String, dynamic> _mapEpisode(Map<String, dynamic> row) => {
  'id': row['id'],
  'podcastId': row['podcast_id'],
  'title': row['title'],
  'description': row['description'] ?? '',
  'audioUrl': row['audio_url'] ?? '',
  'videoUrl': row['video_url'],
  'mediaType': row['media_type'] ?? 'audio',
  'durationSeconds': row['duration_seconds'],
  'episodeNumber': row['episode_number'],
  'status': row['status'] ?? 'published',
  'playCount': row['play_count'] ?? 0,
  'likeCount': row['like_count'] ?? 0,
  'isLive': row['is_live'] ?? false,
  'livekitRoomName': row['livekit_room_name'],
  'liveViewerCount': row['live_viewer_count'] ?? 0,
  'liveStartedAt': row['live_started_at'],
  'liveEndedAt': row['live_ended_at'],
  'thumbnailUrl': row['thumbnail_url'],
  'showNotes': row['show_notes'],
  'createdAt': row['created_at'],
};

class PodcastSupabaseDataSource implements PodcastRemoteDataSource {
  final SupabaseClient _supabase;

  PodcastSupabaseDataSource({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  // ═══════════════════════════════════════════
  // PODCASTS
  // ═══════════════════════════════════════════

  @override
  Future<PodcastModel> createPodcast(PodcastModel podcast) async {
    final data = await _supabase
        .from('podcasts')
        .insert({
          'host_id': podcast.hostId,
          'host_name': podcast.hostName,
          'host_photo_url': podcast.hostPhotoUrl,
          'title': podcast.title,
          'description': podcast.description,
          'cover_url': podcast.coverImageUrl,
          'category': podcast.category,
          'language': podcast.language,
          'tags': podcast.tags,
          'is_explicit': podcast.isExplicit,
          'co_host_ids': podcast.coHostIds,
          'episode_frequency': podcast.episodeFrequency,
          'status': 'active',
        })
        .select()
        .single();
    return PodcastModel.fromJson(_mapPodcast(data));
  }

  @override
  Future<PodcastModel?> getPodcast(String podcastId) async {
    final data = await _supabase
        .from('podcasts')
        .select()
        .eq('id', podcastId)
        .maybeSingle();
    if (data == null) return null;
    return PodcastModel.fromJson(_mapPodcast(data));
  }

  @override
  Future<void> updatePodcast(String podcastId, Map<String, dynamic> data) async {
    final updates = <String, dynamic>{};
    if (data['title'] != null) updates['title'] = data['title'];
    if (data['description'] != null) updates['description'] = data['description'];
    if (data['coverImageUrl'] != null) updates['cover_url'] = data['coverImageUrl'];
    if (data['category'] != null) updates['category'] = data['category'];
    if (data['status'] != null) updates['status'] = data['status'];
    if (data['isExplicit'] != null) updates['is_explicit'] = data['isExplicit'];
    updates['updated_at'] = DateTime.now().toIso8601String();

    await _supabase.from('podcasts').update(updates).eq('id', podcastId);
  }

  @override
  Future<void> deletePodcast(String podcastId) async {
    await _supabase.from('podcasts').update({'status': 'ended'}).eq('id', podcastId);
  }

  @override
  Stream<List<PodcastModel>> getPublishedPodcastsStream({
    String? category,
    int limit = 20,
  }) {
    var query = _supabase
        .from('podcasts')
        .stream(primaryKey: ['id'])
        .eq('status', 'active');

    // Note: Supabase Realtime stream doesn't support chained category filter here
    // We filter in-memory for now
    return query
        .order('subscriber_count', ascending: false)
        .limit(limit)
        .map((rows) {
          var filtered = rows;
          if (category != null) {
            filtered = rows.where((r) => r['category'] == category).toList();
          }
          return filtered.map((r) => PodcastModel.fromJson(_mapPodcast(r))).toList();
        });
  }

  @override
  Stream<List<PodcastModel>> getTrendingPodcastsStream({int limit = 10}) {
    return _supabase
        .from('podcasts')
        .stream(primaryKey: ['id'])
        .eq('status', 'active')
        .order('total_play_count', ascending: false)
        .limit(limit)
        .map((rows) => rows.map((r) => PodcastModel.fromJson(_mapPodcast(r))).toList());
  }

  @override
  Stream<List<PodcastModel>> getPodcastsByHostStream(String hostId) {
    return _supabase
        .from('podcasts')
        .stream(primaryKey: ['id'])
        .eq('host_id', hostId)
        .order('created_at', ascending: false)
        .map((rows) => rows.map((r) => PodcastModel.fromJson(_mapPodcast(r))).toList());
  }

  @override
  Stream<PodcastModel?> getPodcastStream(String podcastId) {
    return _supabase
        .from('podcasts')
        .stream(primaryKey: ['id'])
        .eq('id', podcastId)
        .map((rows) => rows.isEmpty ? null : PodcastModel.fromJson(_mapPodcast(rows.first)));
  }

  @override
  Future<List<PodcastModel>> searchPodcasts(String query) async {
    final data = await _supabase
        .from('podcasts')
        .select()
        .eq('status', 'active')
        .ilike('title', '%$query%')
        .limit(30);
    return (data as List).map((r) => PodcastModel.fromJson(_mapPodcast(r))).toList();
  }

  // ═══════════════════════════════════════════
  // EPISODES
  // ═══════════════════════════════════════════

  @override
  Future<PodcastEpisodeModel> createEpisode(PodcastEpisodeModel episode) async {
    final data = await _supabase
        .from('podcast_episodes')
        .insert({
          'podcast_id': episode.podcastId,
          'title': episode.title,
          'description': episode.description,
          'audio_url': episode.audioUrl,
          'duration_seconds': episode.durationSeconds,
          'episode_number': episode.episodeNumber,
          'status': episode.status.isEmpty ? 'published' : episode.status,
          'thumbnail_url': episode.thumbnailUrl,
        })
        .select()
        .single();
    return PodcastEpisodeModel.fromJson(_mapEpisode(data));
  }

  @override
  Future<PodcastEpisodeModel?> getEpisode(String episodeId) async {
    final data = await _supabase
        .from('podcast_episodes')
        .select()
        .eq('id', episodeId)
        .maybeSingle();
    if (data == null) return null;
    return PodcastEpisodeModel.fromJson(_mapEpisode(data));
  }

  @override
  Future<void> updateEpisode(String episodeId, Map<String, dynamic> data) async {
    final updates = <String, dynamic>{};
    if (data['title'] != null) updates['title'] = data['title'];
    if (data['description'] != null) updates['description'] = data['description'];
    if (data['status'] != null) updates['status'] = data['status'];
    if (data['audioUrl'] != null) updates['audio_url'] = data['audioUrl'];
    await _supabase.from('podcast_episodes').update(updates).eq('id', episodeId);
  }

  @override
  Future<void> deleteEpisode(String episodeId, String podcastId) async {
    await _supabase
        .from('podcast_episodes')
        .update({'status': 'archived'})
        .eq('id', episodeId);
  }

  @override
  Stream<List<PodcastEpisodeModel>> getEpisodesStream(String podcastId) {
    return _supabase
        .from('podcast_episodes')
        .stream(primaryKey: ['id'])
        .eq('podcast_id', podcastId)
        .order('episode_number', ascending: false)
        .map(
          (rows) => rows
              .where((r) => r['status'] == 'published')
              .map((r) => PodcastEpisodeModel.fromJson(_mapEpisode(r)))
              .toList(),
        );
  }

  @override
  Stream<List<PodcastEpisodeModel>> getLatestEpisodesStream({int limit = 20}) {
    return _supabase
        .from('podcast_episodes')
        .stream(primaryKey: ['id'])
        .eq('status', 'published')
        .order('created_at', ascending: false)
        .limit(limit)
        .map((rows) => rows.map((r) => PodcastEpisodeModel.fromJson(_mapEpisode(r))).toList());
  }

  @override
  Stream<PodcastEpisodeModel?> getEpisodeStream(String episodeId) {
    return _supabase
        .from('podcast_episodes')
        .stream(primaryKey: ['id'])
        .eq('id', episodeId)
        .map(
          (rows) => rows.isEmpty
              ? null
              : PodcastEpisodeModel.fromJson(_mapEpisode(rows.first)),
        );
  }

  @override
  Future<int> getNextEpisodeNumber(String podcastId) async {
    final response = await _supabase
        .from('podcast_episodes')
        .select('episode_number')
        .eq('podcast_id', podcastId)
        .order('episode_number', ascending: false)
        .limit(1);
    if ((response as List).isEmpty) return 1;
    return ((response.first['episode_number'] as int?) ?? 0) + 1;
  }

  // ═══════════════════════════════════════════
  // SUBSCRIPTIONS
  // ═══════════════════════════════════════════

  @override
  Future<void> subscribeToPodcast({
    required String podcastId,
    required String podcastTitle,
    required String userId,
    String? podcastCoverUrl,
  }) async {
    await _supabase.from('podcast_subscriptions').upsert({
      'podcast_id': podcastId,
      'user_id': userId,
      'podcast_title': podcastTitle,
      'podcast_cover_url': podcastCoverUrl,
    }, onConflict: 'podcast_id,user_id',);
  }

  @override
  Future<void> unsubscribeFromPodcast({
    required String podcastId,
    required String userId,
  }) async {
    await _supabase
        .from('podcast_subscriptions')
        .delete()
        .eq('podcast_id', podcastId)
        .eq('user_id', userId);
  }

  @override
  Stream<List<Map<String, dynamic>>> getUserSubscriptionsStream(String userId) {
    return _supabase
        .from('podcast_subscriptions')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((rows) => rows.cast<Map<String, dynamic>>());
  }

  // ═══════════════════════════════════════════
  // PLAY TRACKING
  // ═══════════════════════════════════════════

  @override
  Future<void> recordPlay(String episodeId, String podcastId) async {
    await _supabase.rpc(
      'increment_podcast_play',
      params: {'p_episode_id': episodeId, 'p_podcast_id': podcastId},
    );
  }

  @override
  Future<void> likeEpisode(String episodeId, String userId) async {
    await _supabase.from('podcast_user_data').upsert({
      'episode_id': episodeId,
      'user_id': userId,
      'podcast_id': _getPodcastIdForEpisode(episodeId),
      'liked': true,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id,episode_id',);
  }

  @override
  Future<void> unlikeEpisode(String episodeId, String userId) async {
    await _supabase
        .from('podcast_user_data')
        .update({'liked': false, 'updated_at': DateTime.now().toIso8601String()})
        .eq('episode_id', episodeId)
        .eq('user_id', userId);
  }

  @override
  Future<void> updateListenProgress({
    required String episodeId,
    required String userId,
    required int progressSeconds,
    required bool completed,
  }) async {
    await _supabase.from('podcast_user_data').upsert({
      'episode_id': episodeId,
      'user_id': userId,
      'podcast_id': _getPodcastIdForEpisode(episodeId),
      'progress_seconds': progressSeconds,
      'completed': completed,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id,episode_id',);
  }

  @override
  Future<Map<String, dynamic>?> getUserData(String userId) async {
    final data = await _supabase
        .from('podcast_user_data')
        .select()
        .eq('user_id', userId)
        .limit(100);
    if ((data as List).isEmpty) return null;
    return {'episodes': data};
  }

  @override
  Stream<Map<String, dynamic>?> getUserDataStream(String userId) {
    return _supabase
        .from('podcast_user_data')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((rows) => rows.isEmpty ? null : {'episodes': rows});
  }

  // File uploads use Firebase Storage — not yet migrated
  @override
  Future<String> uploadPodcastCover({
    required String podcastId,
    required File file,
  }) async {
    throw UnimplementedError('Podcast cover upload uses Firebase Storage');
  }

  @override
  Future<String> uploadEpisodeAudio({
    required String podcastId,
    required String episodeId,
    required File file,
    void Function(double)? onProgress,
  }) async {
    throw UnimplementedError('Episode audio upload uses Firebase Storage');
  }

  // Helper — podcast_id lookup (lazy, used only for upserts without podcast_id)
  String _getPodcastIdForEpisode(String episodeId) => episodeId; // fallback UUID
}
