import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/supabase_auth_bridge.dart';
import '../models/poll_model.dart';
import 'poll_remote_datasource.dart';

Map<String, dynamic> _mapPoll(
  Map<String, dynamic> row,
  List<Map<String, dynamic>> options, {
  List<String> votedOptionIds = const [],
}) {
  final sortedOptions = List<Map<String, dynamic>>.from(options)
    ..sort((a, b) => (a['position'] as int? ?? 0).compareTo(b['position'] as int? ?? 0));

  final creator = row['creator'] as Map<String, dynamic>?;

  return {
    'id': row['id'],
    'contextType': row['post_id'] != null
        ? 'post'
        : row['group_id'] != null
            ? 'group'
            : 'conversation',
    'contextId': row['post_id'] ?? row['group_id'] ?? row['conversation_id'],
    'question': row['question'],
    'options': sortedOptions
        .map((o) => {
              'id': o['id'],
              'label': o['label'],
              'voteCount': o['vote_count'] ?? 0,
              'position': o['position'] ?? 0,
            })
        .toList(),
    'allowMultiple': row['allow_multiple'] ?? false,
    'endsAt': row['ends_at'],
    'totalVotes': row['total_votes'] ?? 0,
    'createdBy': row['created_by'],
    'createdByName': creator?['display_name'],
    'createdAt': row['created_at'],
    'votedOptionIds': votedOptionIds,
  };
}

/// Ce que `.stream()` ne sait pas porter : le nom du createur (pas de
/// jointure) et le vote du lecteur (autre table).
class _PollSideData {
  final Map<String, dynamic>? creator;
  final List<String> votedOptionIds;

  const _PollSideData({this.creator, this.votedOptionIds = const []});
}

class PollSupabaseDataSource implements PollRemoteDataSource {
  final SupabaseClient _supabase;

  PollSupabaseDataSource({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  Future<List<String>> _votedOptionIds(String pollId, String? userId) async {
    if (userId == null) return [];
    final votes = await _supabase
        .from('post_poll_votes')
        .select('option_id')
        .eq('poll_id', pollId)
        .eq('user_id', userId);
    return (votes as List).map((v) => v['option_id'] as String).toList();
  }

  @override
  Future<PollModel> createPoll({
    required String contextType,
    required String contextId,
    required String question,
    required List<String> optionLabels,
    required bool allowMultiple,
    DateTime? endsAt,
    String? userId,
  }) async {
    if (!await SupabaseAuthBridge.instance.ensureAuthenticated()) {
      throw ServerException('Session non établie – reconnectez-vous');
    }

    final pollRow = await _supabase
        .from('post_polls')
        .insert({
          if (contextType == 'post') 'post_id': contextId,
          if (contextType == 'group') 'group_id': contextId,
          if (contextType == 'conversation') 'conversation_id': contextId,
          // Renseigne aussi pour un sondage de post : la policy d'INSERT
          // regarde l'auteur du post, pas cette colonne, mais la laisser vide
          // privait la carte du fil du nom de son auteur — et l'ecran de
          // resultats de la seule personne autorisee a voir les votants.
          'created_by': userId,
          'question': question,
          'allow_multiple': allowMultiple,
          'ends_at': endsAt?.toUtc().toIso8601String(),
        })
        .select()
        .single();

    final pollId = pollRow['id'] as String;

    // Un sondage sans option n'est pas un sondage : si la seconde ecriture
    // echoue (RLS, reseau), on retire la question plutot que de laisser une
    // coquille vide en base — six d'entre elles y ont sejourne le temps que
    // la politique INSERT manquante sur post_poll_options soit posee.
    final List<dynamic> optionsData;
    try {
      optionsData = await _supabase
          .from('post_poll_options')
          .insert([
            for (var i = 0; i < optionLabels.length; i++)
              {'poll_id': pollId, 'label': optionLabels[i], 'position': i},
          ])
          .select();
    } catch (_) {
      try {
        await _supabase.from('post_polls').delete().eq('id', pollId);
      } catch (_) {
        // Le nettoyage est un bonus : l'echec d'origine reste la vraie cause.
      }
      rethrow;
    }

    return PollModel.fromJson(
      _mapPoll(pollRow, optionsData.cast<Map<String, dynamic>>()),
    );
  }

  @override
  Future<PollModel> getPoll(String pollId, {String? currentUserId}) async {
    final pollRow = await _supabase
        .from('post_polls')
        .select('*, creator:users!created_by(display_name)')
        .eq('id', pollId)
        .single();
    final optionsData = await _supabase
        .from('post_poll_options')
        .select()
        .eq('poll_id', pollId)
        .order('position');
    final voted = await _votedOptionIds(pollId, currentUserId);

    return PollModel.fromJson(
      _mapPoll(
        pollRow,
        (optionsData as List).cast<Map<String, dynamic>>(),
        votedOptionIds: voted,
      ),
    );
  }

  @override
  Future<List<PollModel>> getPollsByContext(
    String contextType,
    String contextId, {
    String? currentUserId,
  }) async {
    final column = switch (contextType) {
      'post' => 'post_id',
      'conversation' => 'conversation_id',
      _ => 'group_id',
    };
    final pollsData = await _supabase
        .from('post_polls')
        .select('*, creator:users!created_by(display_name), post_poll_options(*)')
        .eq(column, contextId)
        .order('created_at', ascending: false);

    final rows = (pollsData as List).cast<Map<String, dynamic>>();
    if (rows.isEmpty) return [];

    final pollIds = rows.map((r) => r['id'] as String).toList();
    final votesByPoll = <String, List<String>>{};
    if (currentUserId != null) {
      final votes = await _supabase
          .from('post_poll_votes')
          .select('poll_id, option_id')
          .eq('user_id', currentUserId)
          .inFilter('poll_id', pollIds);
      for (final v in (votes as List)) {
        votesByPoll.putIfAbsent(v['poll_id'] as String, () => []).add(v['option_id'] as String);
      }
    }

    return rows.map((row) {
      final options = (row['post_poll_options'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      return PollModel.fromJson(
        _mapPoll(
          row,
          options,
          votedOptionIds: votesByPoll[row['id']] ?? const [],
        ),
      );
    }).toList();
  }

  /// Le sondage en direct : question et compteurs suivent `post_polls` /
  /// `post_poll_options` en temps reel.
  ///
  /// Deux choses que `.stream()` ne sait pas faire, et qu'il faut donc relire
  /// une fois a l'abonnement :
  ///
  /// - **joindre** : sans `creator`, la carte affichait un auteur vide des que
  ///   le flux remplacait le chargement initial ;
  /// - **lire une autre table** : sans les votes du lecteur, tout sondage
  ///   arrivait « jamais vote ». La carte d'une bulle de discussion restait
  ///   donc en mode vote apres le vote — sans pourcentages, sans marquer le
  ///   choix — et le badge « Votre choix » de l'ecran de resultats ne
  ///   s'affichait jamais pour personne.
  ///
  /// L'abonnement attend d'abord la session Supabase : sans elle la lecture
  /// part en `anon`, la RLS ne rend aucune ligne, et un flux vide se lit
  /// exactement comme un sondage supprime.
  @override
  Stream<PollModel?> getPollStream(String pollId, {String? currentUserId}) {
    Future<_PollSideData>? side;

    return Rx.fromCallable(
      () => SupabaseAuthBridge.instance.ensureAuthenticated(),
      reusable: true,
    ).switchMap((authentifie) {
      if (!authentifie) {
        return Stream<PollModel?>.error(
          ServerException('Session Supabase non établie – reconnectez-vous'),
        );
      }
      final pollStream = _supabase
          .from('post_polls')
          .stream(primaryKey: ['id']).eq('id', pollId);
      final optionsStream = _supabase
          .from('post_poll_options')
          .stream(primaryKey: ['id']).eq('poll_id', pollId);

      return Rx.combineLatest2<List<Map<String, dynamic>>,
          List<Map<String, dynamic>>, List<List<Map<String, dynamic>>>>(
        pollStream,
        optionsStream,
        (pollRows, optionRows) => [pollRows, optionRows],
      ).asyncMap((rows) async {
        final pollRows = rows[0];
        final optionRows = rows[1];
        if (pollRows.isEmpty) return null;

        final row = pollRows.first;
        side ??= _loadSideData(
          pollId,
          row['created_by'] as String?,
          currentUserId,
        );
        final data = await side!;

        return PollModel.fromJson(
          _mapPoll(
            {...row, 'creator': data.creator},
            optionRows,
            votedOptionIds: data.votedOptionIds,
          ),
        );
      });
    });
  }

  Future<_PollSideData> _loadSideData(
    String pollId,
    String? createdBy,
    String? currentUserId,
  ) async {
    Map<String, dynamic>? creator;
    if (createdBy != null) {
      try {
        creator = await _supabase
            .from('users')
            .select('display_name')
            .eq('id', createdBy)
            .maybeSingle();
      } catch (_) {
        // Un auteur illisible ne doit pas emporter le sondage avec lui.
      }
    }
    List<String> voted = const [];
    try {
      voted = await _votedOptionIds(pollId, currentUserId);
    } catch (_) {
      // Idem : mieux vaut un sondage sans son propre vote qu'une carte vide.
    }
    return _PollSideData(creator: creator, votedOptionIds: voted);
  }

  /// Vote, ou retrait du vote quand [optionIds] est vide.
  ///
  /// Passe par `cast_poll_vote`, qui fait le remplacement en une transaction
  /// et verifie cote serveur ce que seul l'ecran verifiait : sondage encore
  /// ouvert, options du bon sondage, une seule reponse si le sondage est a
  /// choix unique. L'ancien chemin effacait d'abord et reinserait ensuite :
  /// un echec entre les deux perdait le vote precedent et decrementait les
  /// compteurs.
  @override
  Future<void> vote(String pollId, List<String> optionIds, {String? userId}) async {
    if (!await SupabaseAuthBridge.instance.ensureAuthenticated()) {
      throw ServerException('Session non établie – reconnectez-vous');
    }
    if (userId == null) {
      throw ServerException('Utilisateur non authentifié');
    }

    try {
      await _supabase.rpc('cast_poll_vote', params: {
        'p_poll_id': pollId,
        'p_option_ids': optionIds,
      });
      return;
    } on PostgrestException catch (e) {
      // PGRST202 = fonction absente du cache de schema, donc migration pas
      // encore appliquee sur ce projet. Tout autre refus est une vraie cause,
      // qui doit remonter a l'ecran.
      if (e.code != 'PGRST202') rethrow;
      if (kDebugMode) {
        debugPrint(
          '[sondage] cast_poll_vote absente : repli sur delete+insert. '
          'Appliquer la migration 20260914 pour un vote transactionnel.',
        );
      }
    }

    await _supabase
        .from('post_poll_votes')
        .delete()
        .eq('poll_id', pollId)
        .eq('user_id', userId);

    if (optionIds.isEmpty) return;

    await _supabase.from('post_poll_votes').insert([
      for (final optionId in optionIds)
        {'poll_id': pollId, 'option_id': optionId, 'user_id': userId},
    ]);
  }

  /// Votants par option.
  ///
  /// La policy SELECT de `post_poll_votes` est `firebase_uid() = user_id` : une
  /// lecture directe ne rend que son propre vote, y compris pour l'auteur du
  /// sondage. L'ecran de resultats affichait donc « Aucun vote pour le
  /// moment » sous des options qui en avaient — un echec muet, la requete
  /// reussissant a vide. `poll_option_voters` (SECURITY DEFINER) rend la
  /// liste au seul auteur du sondage, ce que l'ecran promet deja.
  @override
  Future<Map<String, List<Map<String, dynamic>>>> getPollVoters(
    String pollId,
  ) async {
    if (!await SupabaseAuthBridge.instance.ensureAuthenticated()) {
      throw ServerException('Session Supabase non établie – reconnectez-vous');
    }
    final rows = await _supabase.rpc(
      'poll_option_voters',
      params: {'p_poll_id': pollId},
    );

    final parVote = <String, List<Map<String, dynamic>>>{};
    for (final row in (rows as List? ?? const [])) {
      final vote = (row as Map).cast<String, dynamic>();
      final optionId = vote['option_id'] as String?;
      if (optionId == null) continue;
      parVote.putIfAbsent(optionId, () => []).add(vote);
    }
    return parVote;
  }

  @override
  Future<void> deletePoll(String pollId) async {
    if (!await SupabaseAuthBridge.instance.ensureAuthenticated()) {
      throw ServerException('Session non établie – reconnectez-vous');
    }
    await _supabase.from('post_polls').delete().eq('id', pollId);
  }
}
