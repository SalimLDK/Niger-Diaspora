import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/villes_service.dart';

export '../services/villes_service.dart' show Ville;

final villesServiceProvider = Provider<VillesService>((ref) => VillesService());

/// Ce qu'on cherche : un texte, dans un pays.
///
/// Une classe plutôt que deux arguments parce que `family` compare sa clé :
/// sans `==`, chaque frappe créerait un provider de plus, et aucun ne serait
/// jamais réutilisé.
@immutable
class RechercheVille {
  const RechercheVille({this.pays, this.texte = '', this.limite = 20});

  /// Nom du pays (« Canada ») ou son code hérité (« CA ») — la base sait lire
  /// les deux. `null` cherche dans le monde entier.
  final String? pays;
  final String texte;
  final int limite;

  @override
  bool operator ==(Object other) =>
      other is RechercheVille &&
      other.pays == pays &&
      other.texte == texte &&
      other.limite == limite;

  @override
  int get hashCode => Object.hash(pays, texte, limite);
}

/// Délai avant d'interroger la base. Une frappe moyenne dépose une lettre
/// toutes les ~150 ms : sans attente, « Montréal » ferait huit allers-retours
/// pour un seul résultat utile.
const Duration attenteAvantRecherche = Duration(milliseconds: 250);

/// Résultats de la recherche de ville.
///
/// `autoDispose` : la liste ne survit pas à la fermeture du champ. Ne pas la
/// lire au doigt levé depuis un `onPressed` (`ref.read(...).valueOrNull` y
/// serait nul au premier appui) — ce provider est fait pour être observé.
final rechercheVillesProvider =
    FutureProvider.autoDispose.family<List<Ville>, RechercheVille>((ref, critere) async {
  var abandonne = false;
  ref.onDispose(() => abandonne = true);

  await Future<void>.delayed(attenteAvantRecherche);
  if (abandonne) return const <Ville>[];

  return ref.read(villesServiceProvider).rechercher(
        pays: critere.pays,
        texte: critere.texte,
        limite: critere.limite,
      );
});

/// Coordonnées à rapprocher d'une ville de la liste.
@immutable
class PositionVille {
  const PositionVille({required this.latitude, required this.longitude, this.rayonKm = 50});

  final double latitude;
  final double longitude;
  final double rayonKm;

  @override
  bool operator ==(Object other) =>
      other is PositionVille &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.rayonKm == rayonKm;

  @override
  int get hashCode => Object.hash(latitude, longitude, rayonKm);
}

/// « Vous êtes à Montréal ? » — rend `null` si rien n'est dans le rayon,
/// ce qui est un résultat, pas une erreur.
final villeLaPlusProcheProvider =
    FutureProvider.autoDispose.family<Ville?, PositionVille>((ref, position) async {
  return ref.read(villesServiceProvider).laPlusProche(
        latitude: position.latitude,
        longitude: position.longitude,
        rayonKm: position.rayonKm,
      );
});
