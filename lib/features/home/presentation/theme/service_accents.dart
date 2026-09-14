import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../../../core/theme/dn_colors.dart';

/// Accent d'une tuile de service : une teinte en clair, une en nocturne.
///
/// La tuile ([QuickActionCard] dans « Tous les services », `_ServiceTile` sur
/// l'accueil) pose l'icône en pleine teinte sur un aplat de cette même teinte
/// à 10–15 % — une couleur trop foncée disparaît donc deux fois en nocturne,
/// sur l'aplat comme sur la surface. D'où la paire plutôt qu'une valeur
/// unique : les teintes que le guide ne décline pas sont éclaircies ici.
@immutable
class ServiceAccent {
  const ServiceAccent({required this.light, required this.dark});

  /// Même valeur dans les deux thèmes — le cas de l'or, que le guide donne
  /// déjà assez clair pour le nocturne.
  const ServiceAccent.unique(Color value) : light = value, dark = value;

  final Color light;
  final Color dark;

  Color of(BuildContext context) => context.isDarkMode ? dark : light;
}

/// Une teinte par service, pour que la grille se lise d'un coup d'œil.
///
/// Avant le 2026-09-14, les tuiles se partageaient trois valeurs
/// (`adaptivePrimaryColor`, `adaptiveSecondaryColor`, `primaryDark`) : le Fil
/// et les Amis avaient exactement la même couleur, l'Annuaire une variante
/// d'orange indiscernable du Fil, et l'accueil colorait l'Annuaire avec
/// `colorScheme.onPrimaryContainer` — un jeton de *texte*, presque noir.
/// Deux grilles montrent les mêmes services : elles lisent cette liste-ci,
/// pour qu'un service ne change pas de couleur d'un écran à l'autre.
///
/// Les rôles nommés par le guide de style sont repris tels quels (bleu
/// officiel pour les ambassades, or pour l'audio, teal d'identité, vert
/// Niger, orange d'action) ; les teintes des modules encore masqués viennent
/// de la palette ④ (`DNColors`), et le prune des événements est la seule
/// teinte hors guide — plus bas, sa raison d'être.
class ServiceAccents {
  ServiceAccents._();

  // ---- Services affichés ----

  /// Fil — orange d'action, l'accent de l'app.
  static const feed = ServiceAccent(
    light: AppColors.primaryDark,
    dark: AppColors.primaryLight,
  );

  /// Annuaire — teal d'identité. Le guide n'en fixe pas de variante nocturne ;
  /// `#2D6E6A` plafonne à ~2,5:1 sur l'aplat sombre de la tuile, d'où cette
  /// version éclaircie réservée à la grille.
  static const directory = ServiceAccent(
    light: AppColors.identity,
    dark: Color(0xFF58A9A3),
  );

  /// Ambassades — bleu « officiel / vérifié » du guide.
  static const embassies = ServiceAccent(
    light: AppColors.info,
    dark: AppColors.infoDark,
  );

  /// Événements — prune. Aucun rôle du guide ne restait libre ici : l'or, seul
  /// candidat, tombe à 2,1:1 sur son propre aplat en thème clair et revient
  /// plus bas habiller les salons audio, que le guide nomme explicitement.
  static const events = ServiceAccent(
    light: Color(0xFF6B4FA8),
    dark: Color(0xFFA992E6),
  );

  /// Amis — vert Niger.
  static const friends = ServiceAccent(
    light: AppColors.secondary,
    dark: AppColors.secondaryLight,
  );

  // ---- Modules masqués de la grille (entrées commentées) ----
  //
  // Ils portent déjà leur accent pour que la réactivation d'une tuile ne
  // reparte pas d'une couleur partagée. Si les quatre reviennent d'un coup,
  // arbitrer l'ambre des podcasts contre l'or des salons audio : ce sont les
  // deux seules teintes voisines de la liste.

  /// Transferts — vert feuille de la palette ④, distinct du vert Niger.
  static const transfers = ServiceAccent(
    light: DNColors.leaf,
    dark: Color(0xFF9DBE72),
  );

  /// Boutique — terracotta de la palette ④.
  static const marketplace = ServiceAccent(
    light: DNColors.terra,
    dark: Color(0xFFE08A6B),
  );

  /// Salons audio — or du guide (« Or — audio / notes »).
  static const audioRooms = ServiceAccent.unique(AppColors.gold);

  /// Podcasts — ambre.
  static const podcasts = ServiceAccent(
    light: AppColors.warning,
    dark: AppColors.warningDark,
  );
}
