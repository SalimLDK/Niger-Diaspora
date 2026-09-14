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
