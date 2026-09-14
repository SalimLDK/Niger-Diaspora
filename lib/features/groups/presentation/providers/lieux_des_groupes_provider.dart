import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/supabase_auth_bridge.dart';
import '../../domain/entities/group_entity.dart';
import 'group_provider.dart';

/// Où poser un groupe sur la carte des groupes.
class LieuDeGroupe {
  const LieuDeGroupe({
    required this.groupId,
    required this.latitude,
    required this.longitude,
    required this.estUneVille,
    this.villeNom,
  });

  final String groupId;
  final double latitude;
  final double longitude;

  /// Vrai quand les coordonnées sont celles de la ville du groupe. Faux quand
  /// elles viennent de la plus grande ville de son pays — un repli, que la
  /// carte n'utilise que faute de centroïde.
  final bool estUneVille;

  /// Nom de la ville, pour l'étiquette du marqueur. `null` pour un groupe de
  /// pays : la carte a déjà le pays dans le groupe.
  final String? villeNom;
}

/// Coordonnées de tous les groupes visibles, en un aller-retour.
///
/// La carte posait chaque groupe sur une table de 32 centroïdes de pays
/// écrite en dur, et SAUTAIT celui dont le pays n'y figure pas. Sur les cinq
/// groupes officiels de la base, deux étaient dans ce cas — Angola et
/// Cap-Vert : invisibles, sans le moindre message. Le référentiel des villes
/// connaît les 197 pays.
final lieuxDesGroupesProvider =
    FutureProvider.autoDispose<Map<String, LieuDeGroupe>>((ref) async {
  // `groupsNotifierProvider` est un `Notifier` dont l'état EST un
  // `AsyncValue` : pas de `.future` à attendre. `valueOrNull` plutôt que
  // `.value`, qui relance l'erreur en Riverpod 2 — une liste de groupes en
  // échec ferait tomber la carte au lieu de la laisser vide.
  final groupes = ref.watch(groupsNotifierProvider).valueOrNull ?? const [];

  // La fonction prend des `uuid[]` : un identifiant hérité de Firestore, que
  // certains groupes portent encore, ferait échouer la requête entière.
  final ids = groupes
      .map((GroupEntity g) => g.id)
      .where(_estUuid)
      .toList(growable: false);
  if (ids.isEmpty) return const {};

  if (!await SupabaseAuthBridge.instance.ensureAuthenticated()) {
    return const {};
  }

  final dynamic brut = await Supabase.instance.client
      .rpc('coordonnees_des_groupes', params: {'p_group_ids': ids});
  if (brut is! List) return const {};

  final lieux = <String, LieuDeGroupe>{};
  for (final ligne in brut.whereType<Map<String, dynamic>>()) {
    final id = ligne['group_id'] as String?;
    final lat = (ligne['latitude'] as num?)?.toDouble();
    final lon = (ligne['longitude'] as num?)?.toDouble();
    if (id == null || lat == null || lon == null) continue;
    lieux[id] = LieuDeGroupe(
      groupId: id,
      latitude: lat,
      longitude: lon,
      estUneVille: ligne['source'] == 'ville',
      villeNom: ligne['ville_nom'] as String?,
    );
  }
  return lieux;
});

final RegExp _uuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

bool _estUuid(String valeur) => _uuid.hasMatch(valeur);

/// Villes ayant un groupe dans [pays] — la seconde marche du filtre Découvrir.
///
/// Tirée des lieux que la base rend pour la carte plutôt que d'une colonne de
/// plus sur `GroupEntity` : c'est la même question (« où est ce groupe ? ») et
/// il n'y a pas de raison d'y répondre deux fois.
///
/// Rend une liste vide tant que [lieux] n'est pas chargé : la rangée de villes
/// n'apparaît donc pas avant de savoir quoi y mettre, plutôt que d'apparaître
/// vide puis de sauter.
List<String> villesDuPays(
  List<GroupEntity> groupes,
  String? pays,
  Map<String, LieuDeGroupe>? lieux,
) {
  if (pays == null || lieux == null || lieux.isEmpty) return const [];
  final noms = <String>{};
  for (final g in groupes) {
    if (g.country != pays) continue;
    final lieu = lieux[g.id];
    if (lieu != null && lieu.estUneVille && lieu.villeNom != null) {
      noms.add(lieu.villeNom!);
    }
  }
  return noms.toList()..sort();
}

/// Ne garde que les groupes de [ville].
///
/// **Tant que [lieux] n'est pas chargé, ne filtre rien.** Un filtre qui répond
/// « aucun groupe » parce qu'il ne sait pas encore où ils sont vide l'onglet
/// le temps d'un aller-retour, sans rien dire — et cet écran a déjà eu trois
/// causes indistinguables d'écran blanc.
List<GroupEntity> filtrerParVille(
  List<GroupEntity> groupes,
  String? ville,
  Map<String, LieuDeGroupe>? lieux,
) {
  if (ville == null || lieux == null || lieux.isEmpty) return groupes;
  return groupes
      .where((g) => lieux[g.id]?.villeNom == ville)
      .toList(growable: false);
}
