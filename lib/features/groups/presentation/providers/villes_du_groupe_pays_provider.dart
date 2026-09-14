import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/supabase_auth_bridge.dart';

/// Une ville rattachée à un groupe de pays, vue depuis sa fiche.
class VilleDuGroupePays {
  const VilleDuGroupePays({
    required this.groupId,
    required this.nom,
    required this.memberCount,
  });

  final String groupId;
  final String nom;
  final int memberCount;
}

/// Les villes d'un groupe de pays : « Montréal · 12, Toronto · 5 ».
///
/// Le rattachement n'est stocké nulle part — le groupe parent d'un groupe de
/// ville est le groupe officiel de même pays sans `ville_id`, et
/// `villes_du_groupe_pays` le déduit à la lecture. Rien à tenir à jour, rien
/// qui puisse diverger.
///
/// Appelable sur n'importe quel groupe : la fonction SQL exige
/// `parent.ville_id IS NULL`, donc un groupe de VILLE rend une liste vide.
/// La fiche n'a pas à savoir de quel genre de groupe elle parle — elle
/// affiche la section si elle a quelque chose à montrer.
final villesDuGroupePaysProvider = FutureProvider.autoDispose
    .family<List<VilleDuGroupePays>, String>((ref, groupId) async {
  // La fonction prend un `uuid` : un identifiant hérité de Firestore, que
  // certains groupes portent encore, ferait échouer la requête.
  if (!_uuid.hasMatch(groupId)) return const [];
  if (!await SupabaseAuthBridge.instance.ensureAuthenticated()) {
    return const [];
  }
  final dynamic brut = await Supabase.instance.client
      .rpc('villes_du_groupe_pays', params: {'p_group_id': groupId});
  return lireVillesDuGroupePays(brut);
});

/// Décode ce que rend `villes_du_groupe_pays`.
///
/// Isolé pour être vérifiable : une clé mal nommée ferait lever le décodage,
/// la section deviendrait une `AsyncError`, et `valueOrNull` la ferait
/// DISPARAÎTRE sans un mot. Une ligne abîmée est ignorée, les autres passent.
List<VilleDuGroupePays> lireVillesDuGroupePays(dynamic brut) {
  if (brut is! List) return const [];
  final villes = <VilleDuGroupePays>[];
  for (final ligne in brut.whereType<Map<String, dynamic>>()) {
    final id = ligne['group_id'];
    final nom = ligne['nom'];
    if (id is! String || nom is! String || nom.isEmpty) continue;
    villes.add(
      VilleDuGroupePays(
        groupId: id,
        nom: nom,
        memberCount: (ligne['member_count'] as num?)?.toInt() ?? 0,
      ),
    );
  }
  return villes;
}

final RegExp _uuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);
