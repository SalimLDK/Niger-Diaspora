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
    'contextType': row['post_id'] != null ? 'post' : 'group',
    'contextId': row['post_id'] ?? row['group_id'],
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
      throw ServerException('Session Supabase non établie – reconnectez-vous');
    }

    final pollRow = await _supabase
        .from('post_polls')
        .insert({
          if (contextType == 'post') 'post_id': contextId,
          if (contextType == 'group') 'group_id': contextId,
          if (contextType == 'group') 'created_by': userId,
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
    final column = contextType == 'post' ? 'post_id' : 'group_id';
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

  @override
  Stream<PollModel?> getPollStream(String pollId) {
    final pollStream =
        _supabase.from('post_polls').stream(primaryKey: ['id']).eq('id', pollId);
    final optionsStream = _supabase
        .from('post_poll_options')
        .stream(primaryKey: ['id']).eq('poll_id', pollId);

    return Rx.combineLatest2<List<Map<String, dynamic>>, List<Map<String, dynamic>>,
        PollModel?>(pollStream, optionsStream, (pollRows, optionRows) {
      if (pollRows.isEmpty) return null;
      return PollModel.fromJson(_mapPoll(pollRows.first, optionRows));
    });
  }

  @override
  Future<void> vote(String pollId, List<String> optionIds, {String? userId}) async {
    if (!await SupabaseAuthBridge.instance.ensureAuthenticated()) {
      throw ServerException('Session Supabase non établie – reconnectez-vous');
    }
    if (userId == null) {
      throw ServerException('Utilisateur non authentifié');
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

  @override
  Future<List<Map<String, dynamic>>> getOptionVoters(
    String pollId,
    String optionId,
  ) async {
    final data = await _supabase
        .from('post_poll_votes')
        .select('user_id, voter:users(display_name, avatar_url)')
        .eq('poll_id', pollId)
        .eq('option_id', optionId);
    return (data as List).cast<Map<String, dynamic>>();
  }

  @override
  Future<void> deletePoll(String pollId) async {
    if (!await SupabaseAuthBridge.instance.ensureAuthenticated()) {
      throw ServerException('Session Supabase non établie – reconnectez-vous');
    }
    await _supabase.from('post_polls').delete().eq('id', pollId);
  }
}
