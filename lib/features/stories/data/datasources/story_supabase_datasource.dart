import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/supabase_auth_bridge.dart';
import '../../../../core/utils/date_parsing.dart';
import '../../domain/entities/story_entity.dart';
import '../models/story_model.dart';

abstract class StoryRemoteDataSource {
  Future<List<StoryModel>> getActiveStories(String currentUserId);
  Future<StoryModel> createStory({
    required String authorId,
    required String authorName,
    String? authorPhotoUrl,
    required String mediaUrl,
    required String mediaType,
    int? videoDurationSeconds,
    required StoryAudience audience,
  });

  /// Supprime une de mes stories. Lève si rien n'a été effacé.
  Future<void> deleteStory(String storyId);

  Future<void> markViewed(String storyId, String viewerId);

  /// Qui a vu cette story (§4). RLS ne renvoie des lignes que si l'appelant
  /// en est l'auteur (ou le spectateur lui-même) — pas de filtre côté app.
  Future<List<StoryViewerEntity>> getViewers(String storyId);

  /// Réactions visibles pour l'appelant (RLS : toutes si auteur, sinon
  /// seulement la sienne).
  Future<List<StoryReactionEntity>> getReactions(String storyId);

  /// Pose/change ma réaction (upsert, une par story et par utilisateur).
  Future<void> setReaction(String storyId, String userId, String emoji);

  /// Retire ma réaction (toggle : retaper le même emoji l'enlève).
  Future<void> removeReaction(String storyId, String userId);

  /// Mes deux listes (restreinte, masqué). La RLS n'en rend qu'à leur auteur.
  Future<List<StoryListMember>> getListMembers(String ownerId);

  /// Range [memberId] dans [kind], ou le retire de toute liste si [kind] est
  /// nul. Une personne n'est jamais dans les deux listes à la fois.
  Future<void> setListMember(
    String ownerId,
    String memberId,
    StoryListKind? kind,
  );
}

class StorySupabaseDataSource implements StoryRemoteDataSource {
  final SupabaseClient _supabase;

  StorySupabaseDataSource({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  Map<String, dynamic> _mapStory(
    Map<String, dynamic> row, {
    required Set<String> viewedIds,
    required Map<String, int> viewCounts,
  }) {
    return {
      'id': row['id'],
      'authorId': row['author_id'],
      'authorName': row['author_name'] ?? '',
      'authorPhotoUrl': row['author_photo_url'],
      'mediaUrl': row['media_url'] ?? '',
      'mediaType': row['media_type'] ?? 'image',
      'videoDurationSeconds': row['video_duration_seconds'],
      'createdAt': row['created_at'],
      'viewCount': viewCounts[row['id']] ?? 0,
      'isViewedByMe': viewedIds.contains(row['id']),
      'audience': row['audience'] ?? 'public',
    };
  }

  @override
  Future<List<StoryModel>> getActiveStories(String currentUserId) async {
    try {
      // La borne des 24 h est posée ICI aussi, pas seulement par la RLS :
      // `stories_manage_own` (FOR ALL) accordait à l'auteur la lecture de ses
      // stories sans limite de durée, et sa story du 3 août s'affichait
      // encore en septembre. La migration 20260912230000 corrige la policy ;
      // ce filtre couvre les bases où elle n'est pas encore appliquée.
      final depuis = DateTime.now().subtract(StoryEntity.lifetime);
      final rows = await _supabase
          .from('stories')
          .select()
          .gt('created_at', toIsoUtc(depuis))
          .order('created_at', ascending: false);
      final storyIds = rows.map((r) => r['id'] as String).toList();
      if (storyIds.isEmpty) return [];

      // Mes propres vues (pour l'anneau "déjà vu").
      final myViews = await _supabase
          .from('story_views')
          .select('story_id')
          .eq('viewer_id', currentUserId)
          .inFilter('story_id', storyIds);
      final viewedIds =
          myViews.map((r) => r['story_id'] as String).toSet();

      // Compteur de vues, seulement pour mes propres stories (RLS ne laisse
      // de toute façon voir les vues des autres que si on en est l'auteur).
      final myStoryIds = rows
          .where((r) => r['author_id'] == currentUserId)
          .map((r) => r['id'] as String)
          .toList();
      final viewCounts = <String, int>{};
      if (myStoryIds.isNotEmpty) {
        final viewRows = await _supabase
            .from('story_views')
            .select('story_id')
            .inFilter('story_id', myStoryIds);
        for (final r in viewRows) {
          final id = r['story_id'] as String;
          viewCounts[id] = (viewCounts[id] ?? 0) + 1;
        }
      }

      return rows
          .map(
            (row) => StoryModel.fromJson(
              _mapStory(row, viewedIds: viewedIds, viewCounts: viewCounts),
            ),
          )
          .toList();
    } catch (e) {
      throw ServerException('Impossible de charger les stories : $e');
    }
  }

  @override
  Future<StoryModel> createStory({
    required String authorId,
    required String authorName,
    String? authorPhotoUrl,
    required String mediaUrl,
    required String mediaType,
    int? videoDurationSeconds,
    required StoryAudience audience,
  }) async {
    if (!await SupabaseAuthBridge.instance.ensureAuthenticated()) {
      throw ServerException('Session non établie – reconnectez-vous');
    }
    Map<String, dynamic> ligne({required bool avecAudience}) => {
          'author_id': authorId,
          'author_name': authorName,
          'author_photo_url': authorPhotoUrl,
          'media_url': mediaUrl,
          'media_type': mediaType,
          if (videoDurationSeconds != null)
            'video_duration_seconds': videoDurationSeconds,
          if (avecAudience) 'audience': audience.dbValue,
        };
    try {
      final data = await _supabase
          .from('stories')
          .insert(ligne(avecAudience: true))
          .select()
          .single();
      return StoryModel.fromJson(
        _mapStory(data, viewedIds: const {}, viewCounts: const {}),
      );
    } on PostgrestException catch (e) {
      // Colonne `audience` absente (migration 20260912230000 pas encore
      // appliquée) : une story « Tout le monde » peut partir sans elle, c'est
      // la valeur par défaut. Une audience restreinte, JAMAIS — elle
      // partirait publique sans que personne ne le sache.
      final colonneAbsente =
          e.code == 'PGRST204' || e.message.contains('audience');
      if (colonneAbsente && audience == StoryAudience.everyone) {
        final data = await _supabase
            .from('stories')
            .insert(ligne(avecAudience: false))
            .select()
            .single();
        return StoryModel.fromJson(
          _mapStory(data, viewedIds: const {}, viewCounts: const {}),
        );
      }
      if (colonneAbsente) {
        throw ServerException(
          "L'audience restreinte n'est pas encore disponible : la story n'a "
          'pas été publiée.',
        );
      }
      throw ServerException(e.message);
    }
  }

  @override
  Future<void> deleteStory(String storyId) async {
    if (!await SupabaseAuthBridge.instance.ensureAuthenticated()) {
      throw ServerException('Session non établie – reconnectez-vous');
    }
    final List<dynamic> supprimees;
    try {
      // `.select()` : un refus RLS efface zéro ligne sans lever d'erreur.
      supprimees = await _supabase
          .from('stories')
          .delete()
          .eq('id', storyId)
          .select('id');
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    }
    if (supprimees.isEmpty) {
      throw ServerException("La story n'a pas été supprimée");
    }
    // Le média reste dans Firebase Storage (`stories/<id>/…`) : le chemin
    // d'upload utilise un identifiant temporaire, pas celui de la ligne, et
    // la règle Storage n'autorise pas la suppression par l'app. La story
    // n'est plus lisible par personne ; le fichier est orphelin.
  }

  @override
  Future<void> markViewed(String storyId, String viewerId) async {
    if (!await SupabaseAuthBridge.instance.ensureAuthenticated()) return;
    try {
      await _supabase.from('story_views').upsert(
        {'story_id': storyId, 'viewer_id': viewerId},
        onConflict: 'story_id,viewer_id',
      );
    } catch (_) {
      // Confort (compteur/anneau), pas critique : on n'interrompt pas la
      // lecture de la story si l'écriture échoue.
    }
  }

  @override
  Future<List<StoryViewerEntity>> getViewers(String storyId) async {
    try {
      final rows = await _supabase
          .from('story_views')
          .select('viewer_id, viewed_at')
          .eq('story_id', storyId)
          .order('viewed_at', ascending: false);
      return rows
          .map(
            (r) => StoryViewerEntity(
              viewerId: r['viewer_id'] as String,
              viewedAt: DateTime.parse(r['viewed_at'] as String).toLocal(),
            ),
          )
          .toList();
    } catch (e) {
      throw ServerException('Impossible de charger les vues : $e');
    }
  }

  @override
  Future<List<StoryReactionEntity>> getReactions(String storyId) async {
    try {
      final rows = await _supabase
          .from('story_reactions')
          .select('user_id, emoji, created_at')
          .eq('story_id', storyId);
      return rows
          .map(
            (r) => StoryReactionEntity(
              userId: r['user_id'] as String,
              emoji: r['emoji'] as String,
              createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
            ),
          )
          .toList();
    } catch (e) {
      throw ServerException('Impossible de charger les réactions : $e');
    }
  }

  @override
  Future<void> setReaction(String storyId, String userId, String emoji) async {
    if (!await SupabaseAuthBridge.instance.ensureAuthenticated()) return;
    try {
      await _supabase.from('story_reactions').upsert(
        {'story_id': storyId, 'user_id': userId, 'emoji': emoji},
        onConflict: 'story_id,user_id',
      );
    } catch (e) {
      throw ServerException('Impossible d\'envoyer la réaction : $e');
    }
  }

  @override
  Future<void> removeReaction(String storyId, String userId) async {
    if (!await SupabaseAuthBridge.instance.ensureAuthenticated()) return;
    try {
      await _supabase
          .from('story_reactions')
          .delete()
          .eq('story_id', storyId)
          .eq('user_id', userId);
    } catch (_) {
      // Confort, pas critique.
    }
  }

  @override
  Future<List<StoryListMember>> getListMembers(String ownerId) async {
    try {
      await SupabaseAuthBridge.instance.ensureAuthenticated();
      final rows = await _supabase
          .from('story_audience_members')
          .select('member_id, list')
          .eq('owner_id', ownerId);
      return [
        for (final r in rows)
          if (StoryListKind.fromDb(r['list'] as String?) case final kind?)
            StoryListMember(memberId: r['member_id'] as String, kind: kind),
      ];
    } on PostgrestException catch (e) {
      debugPrint('StorySupabaseDataSource.getListMembers: ${e.message}');
      throw ServerException(e.message);
    }
  }

  @override
  Future<void> setListMember(
    String ownerId,
    String memberId,
    StoryListKind? kind,
  ) async {
    if (!await SupabaseAuthBridge.instance.ensureAuthenticated()) {
      throw ServerException('Session non établie – reconnectez-vous');
    }
    try {
      if (kind == null) {
        await _supabase
            .from('story_audience_members')
            .delete()
            .eq('owner_id', ownerId)
            .eq('member_id', memberId);
        return;
      }
      // Clé (owner_id, member_id) : l'upsert DÉPLACE la personne d'une liste
      // à l'autre au lieu de l'y dupliquer.
      await _supabase.from('story_audience_members').upsert(
        {'owner_id': ownerId, 'member_id': memberId, 'list': kind.dbValue},
        onConflict: 'owner_id,member_id',
      );
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    }
  }
}
