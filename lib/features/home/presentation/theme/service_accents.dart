import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/dn_colors.dart';
import '../../../../core/theme/tinted_accent.dart';

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
  static const feed = TintedAccent(
    light: AppColors.primaryDark,
    dark: AppColors.primaryLight,
  );

  /// Annuaire — teal d'identité. Le guide n'en fixe pas de variante nocturne ;
  /// `#2D6E6A` plafonne à ~2,5:1 sur l'aplat sombre de la tuile, d'où cette
  /// version éclaircie réservée à la grille.
  static const directory = TintedAccent(
    light: AppColors.identity,
    dark: AppColors.identityBright,
  );

  /// Ambassades — bleu « officiel / vérifié » du guide.
  static const embassies = TintedAccent(
    light: AppColors.info,
    dark: AppColors.infoDark,
  );

  /// Événements — prune. Aucun rôle du guide ne restait libre ici : l'or, seul
  /// candidat, tombe à 2,1:1 sur son propre aplat en thème clair et revient
  /// plus bas habiller les salons audio, que le guide nomme explicitement.
  static const events = TintedAccent(
    light: AppColors.prune,
    dark: AppColors.pruneBright,
  );

  /// Amis — vert Niger.
  static const friends = TintedAccent(
    light: AppColors.secondary,
    dark: AppColors.secondaryLight,
  );

  // ---- Modules masqués de la grille (entrées commentées) ----
  //
  // Ils portent déjà leur accent pour que la réactivation d'une tuile ne
  // reparte pas d'une couleur partagée. Si les quatre reviennent d'un coup,
  // arbitrer l'ambre des podcasts contre l'or des salons audio : voisins au
  // départ, ils le sont devenus plus encore depuis que l'or est assombri en
  // thème clair.

  /// Transferts — vert feuille de la palette ④, distinct du vert Niger.
  static const transfers = TintedAccent(
    light: DNColors.leaf,
    dark: DNColors.leafBright,
  );

  /// Boutique — terracotta de la palette ④.
  static const marketplace = TintedAccent(
    light: DNColors.terra,
    dark: DNColors.terraBright,
  );

  /// Salons audio — or du guide (« Or — audio / notes »), assombri en clair
  /// comme la pièce jointe Audio, pour la même raison de lisibilité.
  static const audioRooms = TintedAccent(
    light: AppColors.goldDeep,
    dark: AppColors.gold,
  );

  /// Podcasts — ambre.
  static const podcasts = TintedAccent(
    light: AppColors.warning,
    dark: AppColors.warningDark,
  );
}
