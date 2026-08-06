import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../admin/presentation/providers/app_settings_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/heritage_recording_model.dart';
import '../../domain/entities/heritage_recording_entity.dart';

/// Provider for Supabase client
final heritageSupabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Parameters for heritage recordings query
class HeritageRecordingsParams {
  final HeritageContentType? contentType;
  final String? language;
  final String? region;
  final int limit;

  const HeritageRecordingsParams({
    this.contentType,
    this.language,
    this.region,
    this.limit = 20,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HeritageRecordingsParams &&
          runtimeType == other.runtimeType &&
          contentType == other.contentType &&
          language == other.language &&
          region == other.region &&
          limit == other.limit;

  @override
  int get hashCode =>
      contentType.hashCode ^
      language.hashCode ^
      region.hashCode ^
      limit.hashCode;
}

/// Provider to fetch approved heritage recordings
final heritageRecordingsProvider = StreamProvider.family<
  List<HeritageRecordingEntity>,
  HeritageRecordingsParams
>((ref, params) {
  final supabase = ref.watch(heritageSupabaseProvider);

  // Build a filtered stream; additional filters are applied client-side
  // because supabase_flutter's .stream() supports only a single .eq() filter.
  return supabase
      .from('heritage_recordings')
      .stream(primaryKey: ['id'])
      .eq('status', 'approved')
      .order('createdAt', ascending: false)
      .map((rows) {
        var result = rows.where((r) => r['status'] == 'approved');

        if (params.contentType != null) {
          result = result.where((r) => r['contentType'] == params.contentType!.name);
        }
        if (params.language != null) {
          result = result.where((r) => r['language'] == params.language);
        }
        if (params.region != null) {
          result = result.where((r) => r['region'] == params.region);
        }

        return result
            .take(params.limit)
            .map((r) => HeritageRecordingModel.fromJson(r).toEntity())
            .toList();
      });
});

/// Provider for featured/popular heritage recordings
final featuredHeritageRecordingsProvider =
    StreamProvider<List<HeritageRecordingEntity>>((ref) {
      final supabase = ref.watch(heritageSupabaseProvider);

      return supabase
          .from('heritage_recordings')
          .stream(primaryKey: ['id'])
          .eq('status', 'approved')
          .order('playCount', ascending: false)
          .map((rows) => rows
              .where((r) => r['status'] == 'approved')
              .take(10)
              .map((r) => HeritageRecordingModel.fromJson(r).toEntity())
              .toList(),);
    });

/// Provider for a single heritage recording
final heritageRecordingProvider =
    StreamProvider.family<HeritageRecordingEntity?, String>((ref, recordingId) {
      final supabase = ref.watch(heritageSupabaseProvider);

      return supabase
          .from('heritage_recordings')
          .stream(primaryKey: ['id'])
          .eq('id', recordingId)
          .map((rows) => rows.isEmpty
              ? null
              : HeritageRecordingModel.fromJson(rows.first).toEntity(),);
    });

/// Parameters for heritage collections query
class HeritageCollectionsParams {
  final bool featuredOnly;
  final int limit;

  const HeritageCollectionsParams({this.featuredOnly = false, this.limit = 20});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HeritageCollectionsParams &&
          runtimeType == other.runtimeType &&
          featuredOnly == other.featuredOnly &&
          limit == other.limit;

  @override
  int get hashCode => featuredOnly.hashCode ^ limit.hashCode;
}

/// Provider for heritage collections
final heritageCollectionsProvider = StreamProvider.family<
  List<HeritageCollectionEntity>,
  HeritageCollectionsParams
>((ref, params) {
  final supabase = ref.watch(heritageSupabaseProvider);

  return supabase
      .from('heritage_recordings') // collections stored separately; adjust table if needed
      .stream(primaryKey: ['id'])
      .eq('isPublic', true)
      .order('createdAt', ascending: false)
      .map((rows) {
        var result = rows.where((r) => r['isPublic'] == true);
        if (params.featuredOnly) {
          result = result.where((r) => r['isFeatured'] == true);
        }
        return result
            .take(params.limit)
            .map((r) => HeritageCollectionModel.fromJson(r).toEntity())
            .toList();
      });
});

/// Provider for user's heritage data (liked, saved, history)
final heritageUserDataProvider = StreamProvider<HeritageUserDataEntity?>((
  ref,
) async* {
  final supabase = ref.watch(heritageSupabaseProvider);
  final currentUser = await ref.watch(currentUserAsyncProvider.future);

  if (currentUser == null) {
    yield null;
    return;
  }

  yield* supabase
      .from('heritage_user_data')
      .stream(primaryKey: ['userId'])
      .eq('userId', currentUser.id)
      .map((rows) {
        if (rows.isEmpty) {
          return HeritageUserDataEntity(userId: currentUser.id);
        }
        final data = rows.first;
        return HeritageUserDataEntity(
          userId: currentUser.id,
          likedRecordingIds: List<String>.from(data['likedRecordingIds'] ?? []),
          savedRecordingIds: List<String>.from(data['savedRecordingIds'] ?? []),
          followedCollectionIds: List<String>.from(
            data['followedCollectionIds'] ?? [],
          ),
          listenHistory:
              (data['listenHistory'] as List<dynamic>?)
                  ?.map(
                    (e) => HeritageListenHistoryEntry(
                      recordingId: e['recordingId'] as String,
                      listenedAt: DateTime.parse(e['listenedAt'] as String).toLocal(),
                      progressSeconds: e['progressSeconds'] as int? ?? 0,
                      completed: e['completed'] as bool? ?? false,
                    ),
                  )
                  .toList() ??
              [],
          preferredLanguages: List<String>.from(
            data['preferredLanguages'] ?? [],
          ),
          preferredRegions: List<String>.from(data['preferredRegions'] ?? []),
          preferredContentTypes:
              (data['preferredContentTypes'] as List<dynamic>?)
                  ?.map(
                    (e) => HeritageContentType.values.firstWhere(
                      (t) => t.name == e,
                      orElse: () => HeritageContentType.other,
                    ),
                  )
                  .toList() ??
              [],
        );
      });
});

/// State class for heritage management
class HeritageState {
  final bool isLoading;
  final String? error;
  final HeritageRecordingEntity? currentRecording;
  final int currentProgress;
  final bool isPlaying;

  const HeritageState({
    this.isLoading = false,
    this.error,
    this.currentRecording,
    this.currentProgress = 0,
    this.isPlaying = false,
  });

  HeritageState copyWith({
    bool? isLoading,
    String? error,
    HeritageRecordingEntity? currentRecording,
    int? currentProgress,
    bool? isPlaying,
  }) {
    return HeritageState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      currentRecording: currentRecording ?? this.currentRecording,
      currentProgress: currentProgress ?? this.currentProgress,
      isPlaying: isPlaying ?? this.isPlaying,
    );
  }
}

/// Notifier for heritage recording management
final heritageNotifierProvider =
    NotifierProvider<HeritageNotifier, HeritageState>(HeritageNotifier.new);

class HeritageNotifier extends Notifier<HeritageState> {
  SupabaseClient get _supabase => ref.read(heritageSupabaseProvider);

  @override
  HeritageState build() => const HeritageState();

  // ---------------------------------------------------------------------------
  // User-data upsert helper
  // ---------------------------------------------------------------------------

  Future<void> _upsertUserData(String userId, Map<String, dynamic> data) async {
    await _supabase
        .from('heritage_user_data')
        .upsert({'userId': userId, ...data}, onConflict: 'userId');
  }

  // ---------------------------------------------------------------------------
  // Array helpers for user-data lists
  // ---------------------------------------------------------------------------

  Future<void> _addToUserList(
    String userId,
    String column,
    String value,
  ) async {
    final row = await _supabase
        .from('heritage_user_data')
        .select(column)
        .eq('userId', userId)
        .maybeSingle();
    final list = List<String>.from((row?[column] as List?) ?? []);
    if (!list.contains(value)) list.add(value);
    await _upsertUserData(userId, {column: list});
  }

  Future<void> _removeFromUserList(
    String userId,
    String column,
    String value,
  ) async {
    final row = await _supabase
        .from('heritage_user_data')
        .select(column)
        .eq('userId', userId)
        .maybeSingle();
    final list = List<String>.from((row?[column] as List?) ?? [])
      ..remove(value);
    await _upsertUserData(userId, {column: list});
  }

  // ---------------------------------------------------------------------------
  // Counter helper
  // ---------------------------------------------------------------------------

  Future<void> _increment(String recordingId, String column, int delta) async {
    final row = await _supabase
        .from('heritage_recordings')
        .select(column)
        .eq('id', recordingId)
        .single();
    final current = (row[column] as int?) ?? 0;
    await _supabase
        .from('heritage_recordings')
        .update({column: current + delta}).eq('id', recordingId);
  }

  // ---------------------------------------------------------------------------
  // Public actions
  // ---------------------------------------------------------------------------

  /// Like a recording
  Future<void> likeRecording(String recordingId) async {
    final currentUser = await ref.read(currentUserAsyncProvider.future);
    if (currentUser == null) {
      state = state.copyWith(error: 'Utilisateur non connecte');
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      await _addToUserList(currentUser.id, 'likedRecordingIds', recordingId);
      await _increment(recordingId, 'likeCount', 1);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Erreur: $e');
    }
  }

  /// Unlike a recording
  Future<void> unlikeRecording(String recordingId) async {
    final currentUser = await ref.read(currentUserAsyncProvider.future);
    if (currentUser == null) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      await _removeFromUserList(currentUser.id, 'likedRecordingIds', recordingId);
      await _increment(recordingId, 'likeCount', -1);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Erreur: $e');
    }
  }

  /// Save a recording for offline
  Future<void> saveRecording(String recordingId) async {
    final currentUser = await ref.read(currentUserAsyncProvider.future);
    if (currentUser == null) return;

    try {
      await _addToUserList(currentUser.id, 'savedRecordingIds', recordingId);
    } catch (e) {
      state = state.copyWith(error: 'Erreur: $e');
    }
  }

  /// Remove saved recording
  Future<void> unsaveRecording(String recordingId) async {
    final currentUser = await ref.read(currentUserAsyncProvider.future);
    if (currentUser == null) return;

    try {
      await _removeFromUserList(currentUser.id, 'savedRecordingIds', recordingId);
    } catch (e) {
      state = state.copyWith(error: 'Erreur: $e');
    }
  }

  /// Record play and update history
  Future<void> recordPlay(String recordingId) async {
    final currentUser = await ref.read(currentUserAsyncProvider.future);

    try {
      // Increment play count
      await _increment(recordingId, 'playCount', 1);

      // Update user history if logged in
      if (currentUser != null) {
        final row = await _supabase
            .from('heritage_user_data')
            .select('listenHistory')
            .eq('userId', currentUser.id)
            .maybeSingle();

        List<Map<String, dynamic>> history = List<Map<String, dynamic>>.from(
          (row?['listenHistory'] as List?)
                  ?.map((e) => Map<String, dynamic>.from(e as Map)) ??
              [],
        );

        // Remove old entry for this recording if exists
        history.removeWhere((e) => e['recordingId'] == recordingId);

        // Add new entry at the beginning
        history.insert(0, {
          'recordingId': recordingId,
          'listenedAt': DateTime.now().toUtc().toIso8601String(),
          'progressSeconds': 0,
          'completed': false,
        });

        // Keep only last 100 entries
        if (history.length > 100) {
          history = history.take(100).toList();
        }

        await _upsertUserData(currentUser.id, {'listenHistory': history});
      }
    } catch (e) {
      // Silent fail for analytics
    }
  }

  /// Update listening progress
  Future<void> updateProgress(
    String recordingId,
    int progressSeconds,
    bool completed,
  ) async {
    final currentUser = await ref.read(currentUserAsyncProvider.future);
    if (currentUser == null) return;

    state = state.copyWith(currentProgress: progressSeconds);

    // Only update periodically (every 30 seconds)
    if (progressSeconds % 30 != 0 && !completed) return;

    try {
      final row = await _supabase
          .from('heritage_user_data')
          .select('listenHistory')
          .eq('userId', currentUser.id)
          .maybeSingle();

      if (row == null) return;

      final history = List<Map<String, dynamic>>.from(
        (row['listenHistory'] as List?)
                ?.map((e) => Map<String, dynamic>.from(e as Map)) ??
            [],
      );

      final index = history.indexWhere((e) => e['recordingId'] == recordingId);
      if (index >= 0) {
        history[index]['progressSeconds'] = progressSeconds;
        history[index]['completed'] = completed;

        await _supabase
            .from('heritage_user_data')
            .update({'listenHistory': history}).eq('userId', currentUser.id);
      }
    } catch (e) {
      // Silent fail
    }
  }

  /// Share recording and increment share count
  Future<void> shareRecording(String recordingId) async {
    try {
      await _increment(recordingId, 'shareCount', 1);
    } catch (e) {
      // Silent fail
    }
  }

  /// Follow a collection
  Future<void> followCollection(String collectionId) async {
    final currentUser = await ref.read(currentUserAsyncProvider.future);
    if (currentUser == null) return;

    try {
      await _addToUserList(currentUser.id, 'followedCollectionIds', collectionId);
      await _supabase.rpc('increment_column', params: {
        'p_table': 'heritage_collections',
        'p_id': collectionId,
        'p_column': 'followerCount',
        'p_delta': 1,
      },);
    } catch (e) {
      state = state.copyWith(error: 'Erreur: $e');
    }
  }

  /// Unfollow a collection
  Future<void> unfollowCollection(String collectionId) async {
    final currentUser = await ref.read(currentUserAsyncProvider.future);
    if (currentUser == null) return;

    try {
      await _removeFromUserList(currentUser.id, 'followedCollectionIds', collectionId);
      await _supabase.rpc('increment_column', params: {
        'p_table': 'heritage_collections',
        'p_id': collectionId,
        'p_column': 'followerCount',
        'p_delta': -1,
      },);
    } catch (e) {
      state = state.copyWith(error: 'Erreur: $e');
    }
  }

  /// Set playing state
  void setPlaying(HeritageRecordingEntity? recording, bool isPlaying) {
    state = state.copyWith(
      currentRecording: recording,
      isPlaying: isPlaying,
      currentProgress: isPlaying ? state.currentProgress : 0,
    );
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Provider for available heritage languages from settings
final heritageLanguagesProvider = Provider<List<String>>((ref) {
  final settings = ref.watch(appSettingsNotifierProvider).valueOrNull;
  return settings?.audioRooms.heritageLanguages ??
      ['Hausa', 'Zarma', 'Fulfulde', 'Tamashek', 'Kanuri', 'Arabic', 'French'];
});

/// Provider for available heritage regions from settings
final heritageRegionsProvider = Provider<List<String>>((ref) {
  final settings = ref.watch(appSettingsNotifierProvider).valueOrNull;
  return settings?.audioRooms.heritageRegions ??
      [
        'Niamey',
        'Zinder',
        'Maradi',
        'Tahoua',
        'Agadez',
        'Dosso',
        'Diffa',
        'Tillaberi',
      ];
});

/// Provider to check if heritage content is enabled
final isHeritageEnabledProvider = Provider<bool>((ref) {
  final settings = ref.watch(appSettingsNotifierProvider).valueOrNull;
  return settings?.audioRooms.allowHeritageContent ?? true;
});

/// Provider to check if heritage requires moderation
final heritageRequiresModerationProvider = Provider<bool>((ref) {
  final settings = ref.watch(appSettingsNotifierProvider).valueOrNull;
  return settings?.audioRooms.requireHeritageModeration ?? true;
});

/// Provider for recordings by content type
final recordingsByTypeProvider = StreamProvider.family<
  List<HeritageRecordingEntity>,
  HeritageContentType
>((ref, type) {
  final supabase = ref.watch(heritageSupabaseProvider);

  return supabase
      .from('heritage_recordings')
      .stream(primaryKey: ['id'])
      .eq('status', 'approved')
      .order('createdAt', ascending: false)
      .map((rows) => rows
          .where((r) =>
              r['status'] == 'approved' && r['contentType'] == type.name,)
          .take(20)
          .map((r) => HeritageRecordingModel.fromJson(r).toEntity())
          .toList(),);
});

/// Provider for user's saved recordings
final savedRecordingsProvider = StreamProvider<List<HeritageRecordingEntity>>((
  ref,
) async* {
  final supabase = ref.watch(heritageSupabaseProvider);
  final userData = ref.watch(heritageUserDataProvider).valueOrNull;

  if (userData == null || userData.savedRecordingIds.isEmpty) {
    yield [];
    return;
  }

  // Fetch recordings in batches of 10 (Supabase .in_() limit mirrors Firestore)
  final recordings = <HeritageRecordingEntity>[];
  final ids = userData.savedRecordingIds;

  for (var i = 0; i < ids.length; i += 10) {
    final batchIds = ids.skip(i).take(10).toList();
    final rows = await supabase
        .from('heritage_recordings')
        .select()
        .inFilter('id', batchIds);

    recordings.addAll(
      (rows as List).map(
        (r) => HeritageRecordingModel.fromJson(r as Map<String, dynamic>).toEntity(),
      ),
    );
  }

  yield recordings;
});

/// Provider for search in heritage recordings
final searchHeritageRecordingsProvider = FutureProvider.family<
  List<HeritageRecordingEntity>,
  String
>((ref, query) async {
  if (query.trim().isEmpty) return [];

  final supabase = ref.read(heritageSupabaseProvider);
  final queryLower = query.toLowerCase();

  // Fetch recent approved recordings and filter client-side
  // (for full-text search, wire up pgvector/pg_trgm or an external search service)
  final rows = await supabase
      .from('heritage_recordings')
      .select()
      .eq('status', 'approved')
      .order('createdAt', ascending: false)
      .limit(50);

  return (rows as List)
      .map((r) =>
          HeritageRecordingModel.fromJson(r as Map<String, dynamic>).toEntity(),)
      .where(
        (r) =>
            r.title.toLowerCase().contains(queryLower) ||
            (r.description?.toLowerCase().contains(queryLower) ?? false) ||
            r.tags.any((t) => t.toLowerCase().contains(queryLower)),
      )
      .take(20)
      .toList();
});
