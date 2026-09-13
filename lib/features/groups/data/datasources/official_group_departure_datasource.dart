import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/supabase_auth_bridge.dart';
import '../../../../core/utils/date_parsing.dart';

/// Départ du groupe officiel de l'ancien pays, en attente de la réponse de
/// l'utilisateur.
///
/// Changer de pays ne sort de rien. Six mois plus tard, la tâche quotidienne
/// `proposer_departs_groupes_officiels` (migration
/// `20260913050000_depart_groupe_officiel_avec_consentement.sql`) avertit
/// l'utilisateur et passe la ligne à `a_confirmer`. Seule sa réponse, sur la
/// fiche du groupe, peut l'en faire sortir.
class OfficialGroupDeparture {
  final String groupId;

  /// Pays du groupe, que le profil n'indique plus.
  final String formerCountry;

  /// Date à laquelle le profil a changé de pays.
  final DateTime changedAt;

  const OfficialGroupDeparture({
    required this.groupId,
    required this.formerCountry,
    required this.changedAt,
  });
}

class OfficialGroupDepartureDataSource {
  final SupabaseClient? _client;

  OfficialGroupDepartureDataSource({SupabaseClient? supabase})
      : _client = supabase;

  // Résolu à l'usage : un double de test peut hériter de cette classe sans
  // Supabase initialisé.
  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  /// Le départ à confirmer pour [groupId], ou `null` s'il n'y en a pas.
  ///
  /// La RLS ne rend que les lignes de l'utilisateur connecté.
  Future<OfficialGroupDeparture?> pendingFor(String groupId) async {
    if (!await SupabaseAuthBridge.instance.ensureAuthenticated()) return null;
    final row = await _supabase
        .from('departs_groupe_officiel')
        .select('group_id, ancien_pays, change_le')
        .eq('group_id', groupId)
        .eq('statut', 'a_confirmer')
        .maybeSingle();
    if (row == null) return null;
    final changedAt = tryParseLocalDate(row['change_le']);
    if (changedAt == null) return null;
    return OfficialGroupDeparture(
      groupId: row['group_id'] as String,
      formerCountry: row['ancien_pays'] as String,
      changedAt: changedAt,
    );
  }

  /// Transmet le choix de l'utilisateur. Rend `'quitte'`, `'reste'`, ou
  /// `null` si plus rien n'était à décider (déjà répondu ailleurs, ou retour
  /// dans ce pays entre-temps).
  Future<String?> answer(String groupId, {required bool leave}) async {
    if (!await SupabaseAuthBridge.instance.ensureAuthenticated()) {
      throw ServerException('Session Supabase non établie – reconnectez-vous');
    }
    final result = await _supabase.rpc(
      'repondre_depart_groupe_officiel',
      params: {'p_group_id': groupId, 'p_quitter': leave},
    );
    return result as String?;
  }
}
