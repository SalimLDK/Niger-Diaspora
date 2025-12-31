import 'package:flutter/material.dart';

/// Systeme de spacing et dimensions unifie
/// Basee sur une echelle de 4px
class AppSpacing {
  AppSpacing._();

  // ============================================
  // SPACING (multiples de 4)
  // ============================================

  static const double spacing2 = 2;
  static const double spacing4 = 4;
  static const double spacing6 = 6;
  static const double spacing8 = 8;
  static const double spacing12 = 12;
  static const double spacing16 = 16;
  static const double spacing20 = 20;
  static const double spacing24 = 24;
  static const double spacing32 = 32;
  static const double spacing40 = 40;
  static const double spacing48 = 48;
  static const double spacing64 = 64;

  // ============================================
  // PADDING PRESETS
  // ============================================

  /// Padding pour les ecrans
  static const EdgeInsets screenPadding = EdgeInsets.all(spacing20);

  /// Padding horizontal ecran
  static const EdgeInsets screenHorizontal = EdgeInsets.symmetric(
    horizontal: spacing20,
  );

  /// Padding pour les cards
  static const EdgeInsets cardPadding = EdgeInsets.all(spacing16);

  /// Padding large pour les cards
  static const EdgeInsets cardPaddingLarge = EdgeInsets.all(spacing20);

  /// Padding pour les boutons
  static const EdgeInsets buttonPadding = EdgeInsets.symmetric(
    horizontal: spacing24,
    vertical: spacing16,
  );

  /// Padding pour les inputs
  static const EdgeInsets inputPadding = EdgeInsets.symmetric(
    horizontal: spacing16,
    vertical: spacing16,
  );

  /// Padding pour les chips/badges
  static const EdgeInsets chipPadding = EdgeInsets.symmetric(
    horizontal: spacing12,
    vertical: spacing6,
  );

  // ============================================
  // BORDER RADIUS
  // ============================================

  /// Extra small - tags, petits badges
  static const double radiusXS = 4;

  /// Small - chips, small buttons
  static const double radiusSM = 8;

  /// Medium - inputs, standard buttons
  static const double radiusMD = 12;

  /// Large - cards, containers
  static const double radiusLG = 16;

  /// Extra large - large cards, images
  static const double radiusXL = 20;

  /// 2X Large - modals, bottom sheets
  static const double radius2XL = 24;

  /// Full - pills, avatars
  static const double radiusFull = 999;

  // BorderRadius objects
  static const BorderRadius borderRadiusXS = BorderRadius.all(
    Radius.circular(radiusXS),
  );
  static const BorderRadius borderRadiusSM = BorderRadius.all(
    Radius.circular(radiusSM),
  );
  static const BorderRadius borderRadiusMD = BorderRadius.all(
    Radius.circular(radiusMD),
  );
  static const BorderRadius borderRadiusLG = BorderRadius.all(
    Radius.circular(radiusLG),
  );
  static const BorderRadius borderRadiusXL = BorderRadius.all(
    Radius.circular(radiusXL),
  );
  static const BorderRadius borderRadius2XL = BorderRadius.all(
    Radius.circular(radius2XL),
  );
  static const BorderRadius borderRadiusFull = BorderRadius.all(
    Radius.circular(radiusFull),
  );

  /// Top corners only (pour bottom sheets)
  static const BorderRadius borderRadiusTop = BorderRadius.only(
    topLeft: Radius.circular(radius2XL),
    topRight: Radius.circular(radius2XL),
  );

  // ============================================
  // ELEVATIONS
  // ============================================

  static const double elevationNone = 0;
  static const double elevationXS = 1;
  static const double elevationSM = 2;
  static const double elevationMD = 4;
  static const double elevationLG = 8;
  static const double elevationXL = 16;

  // ============================================
  // ICON SIZES
  // ============================================

  static const double iconSizeXS = 12;
  static const double iconSizeSM = 16;
  static const double iconSizeMD = 20;
  static const double iconSize = 24;
  static const double iconSizeLG = 28;
  static const double iconSizeXL = 32;
  static const double iconSize2XL = 40;
  static const double iconSize3XL = 48;

  // ============================================
  // COMPONENT SIZES
  // ============================================

  /// Hauteur minimale des boutons
  static const double buttonHeight = 52;

  /// Hauteur minimale des inputs
  static const double inputHeight = 56;

  /// Hauteur de l'AppBar
  static const double appBarHeight = 56;

  /// Hauteur de la bottom navigation
  static const double bottomNavHeight = 64;

  /// Taille des avatars
  static const double avatarSizeSM = 32;
  static const double avatarSizeMD = 40;
  static const double avatarSize = 48;
  static const double avatarSizeLG = 64;
  static const double avatarSizeXL = 80;
  static const double avatarSize2XL = 120;

  // ============================================
  // BORDER WIDTHS
  // ============================================

  static const double borderWidth = 1;
  static const double borderWidthMedium = 1.5;
  static const double borderWidthThick = 2;

  // ============================================
  // GAPS (pour Row/Column)
  // ============================================

  static const SizedBox gapH4 = SizedBox(width: spacing4);
  static const SizedBox gapH8 = SizedBox(width: spacing8);
  static const SizedBox gapH12 = SizedBox(width: spacing12);
  static const SizedBox gapH16 = SizedBox(width: spacing16);
  static const SizedBox gapH20 = SizedBox(width: spacing20);
  static const SizedBox gapH24 = SizedBox(width: spacing24);
  static const SizedBox gapH32 = SizedBox(width: spacing32);

  static const SizedBox gapV4 = SizedBox(height: spacing4);
  static const SizedBox gapV8 = SizedBox(height: spacing8);
  static const SizedBox gapV12 = SizedBox(height: spacing12);
  static const SizedBox gapV16 = SizedBox(height: spacing16);
  static const SizedBox gapV20 = SizedBox(height: spacing20);
  static const SizedBox gapV24 = SizedBox(height: spacing24);
  static const SizedBox gapV32 = SizedBox(height: spacing32);
  static const SizedBox gapV48 = SizedBox(height: spacing48);

  // ============================================
  // TABLET SPECIFIC SIZES
  // ============================================

  /// Largeur du panneau latéral sur tablette
  static const double tabletSidePanelWidth = 320;

  /// Largeur du panneau master (master-detail)
  static const double tabletMasterWidth = 350;

  /// Largeur maximale du contenu sur tablette
  static const double tabletMaxContentWidth = 600;

  /// Padding écran tablette
  static const EdgeInsets tabletScreenPadding = EdgeInsets.all(spacing32);

  /// Padding horizontal écran tablette
  static const EdgeInsets tabletScreenHorizontal = EdgeInsets.symmetric(
    horizontal: spacing32,
  );

  /// Padding pour les cards sur tablette
  static const EdgeInsets tabletCardPadding = EdgeInsets.all(spacing24);

  // ============================================
  // RESPONSIVE HELPERS
  // ============================================

  /// Retourne le padding écran adapté selon la largeur
  static EdgeInsets getScreenPadding(double screenWidth) {
    if (screenWidth >= 600) return tabletScreenPadding;
    return screenPadding;
  }

  /// Retourne le padding carte adapté selon la largeur
  static EdgeInsets getCardPadding(double screenWidth) {
    if (screenWidth >= 600) return tabletCardPadding;
    return cardPadding;
  }

  /// Retourne le nombre de colonnes de grille adapté
  static int getGridColumns(double screenWidth) {
    if (screenWidth < 600) return 2;
    if (screenWidth < 900) return 3;
    if (screenWidth < 1200) return 4;
    return 6;
  }
}
