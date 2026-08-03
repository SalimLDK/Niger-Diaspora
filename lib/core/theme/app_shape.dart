import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Rayons et ombres du « Guide de style », section « Composants récurrents ».
///
/// Le guide fixe une échelle de quatre rayons de conteneur et trois niveaux
/// d'ombre — rien d'autre. Tout ce qui n'y figure pas (le rayon 14 des champs
/// et boutons de `design_kit.dart`, hérité des maquettes 14a→16g) reste une
/// valeur locale et n'a pas à être aligné de force.

/// Échelle de rayons.
class AppRadii {
  AppRadii._();

  /// 11 px — pastilles d'icône, petits conteneurs.
  static const double small = 11;

  /// 16 px — carte standard.
  static const double card = 16;

  /// 20 px — carte large, feuille modale.
  static const double cardLarge = 20;

  /// Rayon des boutons rectangulaires du guide.
  static const double button = 13;

  /// Rayon des badges et pastilles de statut.
  static const double badge = 8;

  /// Avatars et pilules : « 50 % », donc un rayon assez grand pour saturer
  /// n'importe quelle hauteur de contrôle.
  static const double pill = 999;

  static const BorderRadius smallRadius = BorderRadius.all(
    Radius.circular(small),
  );
  static const BorderRadius cardRadius = BorderRadius.all(
    Radius.circular(card),
  );
  static const BorderRadius cardLargeRadius = BorderRadius.all(
    Radius.circular(cardLarge),
  );
  static const BorderRadius buttonRadius = BorderRadius.all(
    Radius.circular(button),
  );
  static const BorderRadius badgeRadius = BorderRadius.all(
    Radius.circular(badge),
  );
  static const BorderRadius pillRadius = BorderRadius.all(
    Radius.circular(pill),
  );
}

/// Les trois niveaux d'ombre du guide, teintés sur l'encre `#1C1815` plutôt
/// que sur du noir pur.
///
/// Règle nocturne du guide : « Aucune ombre portée : les surfaces se
/// distinguent par bordure et rayon, pas par élévation. » C'est pourquoi les
/// accesseurs [of] et [BuildContext.cardShadow] rendent une liste vide en
/// thème sombre — ne pas les court-circuiter en posant une ombre en dur.
class AppShadows {
  AppShadows._();

  /// Ombre de carte posée (`0 4px 14px rgba(28,24,21,.10)`).
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x1A1C1815), blurRadius: 14, offset: Offset(0, 4)),
  ];

  /// Ombre d'élément flottant — FAB, carte tirée (`0 14px 34px …/.20`).
  static const List<BoxShadow> raised = [
    BoxShadow(color: Color(0x331C1815), blurRadius: 34, offset: Offset(0, 14)),
  ];

  /// Ombre de surface superposée — feuille modale, dialogue
  /// (`0 24px 60px …/.28`).
  static const List<BoxShadow> overlay = [
    BoxShadow(color: Color(0x471C1815), blurRadius: 60, offset: Offset(0, 24)),
  ];

  /// Rend l'ombre demandée en thème clair, et rien en nocturne.
  static List<BoxShadow> of(BuildContext context, List<BoxShadow> level) =>
      Theme.of(context).brightness == Brightness.dark ? const [] : level;
}

/// Raccourcis sur `BuildContext`, alignés sur `adaptive_colors.dart`.
extension AppShapeContext on BuildContext {
  /// Ombre de carte, absente en nocturne.
  List<BoxShadow> get cardShadow => AppShadows.of(this, AppShadows.card);

  /// Ombre d'élément flottant, absente en nocturne.
  List<BoxShadow> get raisedShadow => AppShadows.of(this, AppShadows.raised);

  /// Ombre de surface superposée, absente en nocturne.
  List<BoxShadow> get overlayShadow => AppShadows.of(this, AppShadows.overlay);

  /// Carte du guide : surface, rayon 16, bordure fine, ombre douce en clair —
  /// bordure seule en nocturne.
  BoxDecoration get guideCardDecoration {
    final isDark = Theme.of(this).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark ? AppColors.surfaceDark : AppColors.surface,
      borderRadius: AppRadii.cardRadius,
      border: Border.all(
        color: isDark ? AppColors.borderDark : AppColors.border,
      ),
      boxShadow: isDark ? null : AppShadows.card,
    );
  }
}
