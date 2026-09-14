import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/dn_colors.dart';
import '../../../../core/theme/tinted_accent.dart';

/// Une teinte par pièce jointe, pour que le panneau « + » se lise d'un coup
/// d'œil.
///
/// Avant le 2026-09-14, les huit tuiles se partageaient **deux** valeurs :
/// `adaptivePrimaryColor` pour les médias, `adaptiveSecondaryColor` pour le
/// contenu interactif. Caméra, Galerie, Vidéos, Audio et Document sortaient
/// donc tous du même orange ; seul le libellé les distinguait. Et comme les
/// deux valeurs suivent l'accent du compte, un compte en thème Vert affichait
/// les huit tuiles en deux verts voisins.
///
/// Les deux surfaces du « + » lisent cette liste : le panneau ancré (appui
/// simple, grille 3×2) et l'ancien sheet complet (appui long, qui garde les
/// entrées Vidéos et Audio dédiées). Une pièce jointe ne change donc pas de
/// couleur selon la façon dont on a ouvert le menu.
///
/// Les rôles nommés par le guide de style sont repris tels quels — l'or pour
/// l'audio (« Or — audio / notes »), le bleu « officiel » pour le document, le
/// teal d'identité, le vert Niger ; le reste vient de la palette ④
/// (`DNColors`). Le prune de l'événement est `AppColors.prune`, la valeur que
/// porte aussi la tuile « Événements » de l'accueil : un événement garde sa
/// couleur, qu'on le crée depuis une discussion ou qu'on l'ouvre depuis la
/// grille des services.
class AttachmentAccents {
  AttachmentAccents._();

  /// Caméra — teal d'identité. Le guide n'en fixe pas de variante nocturne ;
  /// `#2D6E6A` plafonne à ~2,5:1 sur l'aplat sombre de la tuile, d'où cette
  /// version éclaircie, la même que l'Annuaire sur l'accueil.
  static const camera = TintedAccent(
    light: AppColors.identity,
    dark: AppColors.identityBright,
  );

  /// Galerie — orange d'action.
  static const gallery = TintedAccent(
    light: AppColors.primaryDark,
    dark: AppColors.primaryLight,
  );

  /// Vidéos — vert Niger.
  static const video = TintedAccent(
    light: AppColors.secondary,
    dark: AppColors.secondaryLight,
  );

  /// Audio — or du guide (« Or — audio / notes »).
  static const audio = TintedAccent.unique(AppColors.gold);

  /// Document — bleu « officiel / vérifié » du guide.
  static const document = TintedAccent(
    light: AppColors.info,
    dark: AppColors.infoDark,
  );

  /// Position — terracotta de la palette ④, la couleur d'une épingle de carte.
  static const location = TintedAccent(
    light: DNColors.terra,
    dark: DNColors.terraBright,
  );

  /// Sondage — vert feuille de la palette ④, distinct du vert Niger des
  /// vidéos (les deux ne se touchent dans aucune des deux dispositions).
  static const poll = TintedAccent(
    light: DNColors.leaf,
    dark: DNColors.leafBright,
  );

  /// Événement — prune, comme la tuile « Événements » de l'accueil.
  static const event = TintedAccent(
    light: AppColors.prune,
    dark: AppColors.pruneBright,
  );
}
