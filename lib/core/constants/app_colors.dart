import 'package:flutter/material.dart';

/// Charte graphique premium Niger Diaspora
/// Palette inspiree du drapeau nigerien et des tons saheliens
class AppColors {
  AppColors._();

  // ============================================
  // PRIMARY COLORS - ORANGE SAHELIEN
  // ============================================

  /// Orange terre cuite principal - Sahel Orange
  static const Color primary = Color(0xFFE07B39);

  /// Version claire - Sunset Glow
  static const Color primaryLight = Color(0xFFF4A574);

  /// Version tres claire - Dawn Mist (backgrounds)
  static const Color primaryLighter = Color(0xFFFCEADE);

  /// Version foncee - Terracotta
  static const Color primaryDark = Color(0xFFB85E24);

  /// Version tres foncee - Burnt Sienna
  static const Color primaryDarker = Color(0xFF8B4513);

  // ============================================
  // SECONDARY COLORS - VERT NIGER
  // ============================================

  /// Vert foret principal - Niger Green
  static const Color secondary = Color(0xFF2D7D46);

  /// Version claire - Sahel Grass
  static const Color secondaryLight = Color(0xFF5BA674);

  /// Version tres claire - Oasis Mist (backgrounds)
  static const Color secondaryLighter = Color(0xFFE3F2E8);

  /// Version foncee - Forest Deep
  static const Color secondaryDark = Color(0xFF1B5E32);

  /// Version tres foncee - Jungle Night
  static const Color secondaryDarker = Color(0xFF0F3D20);

  // ============================================
  // NEUTRAL COLORS - LIGHT THEME
  // ============================================

  /// Fond principal - Sand (sable chaud)
  static const Color background = Color(0xFFFAF7F2);

  /// Surface cards/modals - Blanc pur
  static const Color surface = Color(0xFFFFFFFF);

  /// Surface elevee
  static const Color surfaceElevated = Color(0xFFFFFFFF);

  /// Surface variante - Ivory
  static const Color surfaceVariant = Color(0xFFF5F0E8);

  /// Bordure subtile - Dune
  static const Color border = Color(0xFFE8DFD4);

  /// Bordure marquee - Clay
  static const Color borderStrong = Color(0xFFC9BBAB);

  // ============================================
  // NEUTRAL COLORS - DARK THEME
  // ============================================

  /// Fond principal dark - Ebene chaud
  static const Color backgroundDark = Color(0xFF0F0D0A);

  /// Surface cards dark - Brun profond
  static const Color surfaceDark = Color(0xFF1A1714);

  /// Surface elevee dark
  static const Color surfaceElevatedDark = Color(0xFF252119);

  /// Surface variante dark
  static const Color surfaceVariantDark = Color(0xFF2D2820);

  /// Bordure dark
  static const Color borderDark = Color(0xFF3D352C);

  /// Bordure marquee dark
  static const Color borderStrongDark = Color(0xFF544A3D);

  // ============================================
  // TEXT COLORS - LIGHT THEME
  // ============================================

  /// Texte principal - Quasi-noir chaud
  static const Color textPrimary = Color(0xFF1C1815);

  /// Texte secondaire
  static const Color textSecondary = Color(0xFF4A443C);

  /// Texte tertiaire
  static const Color textTertiary = Color(0xFF847A6E);

  /// Texte desactive
  static const Color textDisabled = Color(0xFFB8AFA3);

  /// Texte inverse (sur fond colore)
  static const Color textInverse = Color(0xFFFFFFFF);

  // ============================================
  // TEXT COLORS - DARK THEME
  // ============================================

  /// Texte principal dark - Creme
  static const Color textPrimaryDark = Color(0xFFF5F2EE);

  /// Texte secondaire dark
  static const Color textSecondaryDark = Color(0xFFC4BDB3);

  /// Texte tertiaire dark
  static const Color textTertiaryDark = Color(0xFF8A8177);

  /// Texte desactive dark
  static const Color textDisabledDark = Color(0xFF5C564E);

  /// Texte inverse dark
  static const Color textInverseDark = Color(0xFF1C1815);

  // ============================================
  // SEMANTIC COLORS
  // ============================================

  // Success
  static const Color success = Color(0xFF2D7D46);
  static const Color successLight = Color(0xFF5BA674);
  static const Color successBackground = Color(0xFFE3F2E8);
  static const Color successDark = Color(0xFF5BA674);
  static const Color successBackgroundDark = Color(0xFF1A2B1F);

  // Error
  static const Color error = Color(0xFFC53030);
  static const Color errorLight = Color(0xFFF87171);
  static const Color errorBackground = Color(0xFFFEE2E2);
  static const Color errorDark = Color(0xFFF87171);
  static const Color errorBackgroundDark = Color(0xFF2D1A1A);

  // Warning
  static const Color warning = Color(0xFFC78522);
  static const Color warningLight = Color(0xFFFBBF24);
  static const Color warningBackground = Color(0xFFFEF3C7);
  static const Color warningDark = Color(0xFFFBBF24);
  static const Color warningBackgroundDark = Color(0xFF2D2510);

  // Info
  static const Color info = Color(0xFF2563EB);
  static const Color infoLight = Color(0xFF60A5FA);
  static const Color infoBackground = Color(0xFFDBEAFE);
  static const Color infoDark = Color(0xFF60A5FA);
  static const Color infoBackgroundDark = Color(0xFF1A2235);

  // ============================================
  // BASE COLORS
  // ============================================

  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color transparent = Colors.transparent;

  // ============================================
  // GRADIENTS
  // ============================================

  /// Gradient hero principal
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Gradient hero dark mode
  static const LinearGradient primaryGradientDark = LinearGradient(
    colors: [primaryLight, primary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Gradient secondaire
  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [secondary, secondaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Gradient subtil pour backgrounds
  static const LinearGradient subtleGradient = LinearGradient(
    colors: [background, surfaceVariant],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Gradient Niger (drapeau)
  static const LinearGradient nigerGradient = LinearGradient(
    colors: [primary, white, secondary],
    stops: [0.0, 0.5, 1.0],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ============================================
  // LEGACY ALIASES (pour compatibilite)
  // ============================================

  @Deprecated('Utiliser primary a la place')
  static const Color orangePrimary = primary;

  @Deprecated('Utiliser primaryLight a la place')
  static const Color orangeLight = primaryLight;

  @Deprecated('Utiliser primaryDark a la place')
  static const Color orangeDark = primaryDark;

  @Deprecated('Utiliser secondary a la place')
  static const Color greenPrimary = secondary;

  @Deprecated('Utiliser secondaryLight a la place')
  static const Color greenLight = secondaryLight;

  @Deprecated('Utiliser secondaryDark a la place')
  static const Color greenDark = secondaryDark;

  @Deprecated('Utiliser border a la place')
  static const Color beige = border;

  @Deprecated('Utiliser surfaceVariant a la place')
  static const Color beigeLight = surfaceVariant;

  @Deprecated('Utiliser borderStrong a la place')
  static const Color beigeDark = borderStrong;

  @Deprecated('Utiliser textPrimary a la place')
  static const Color textDark = textPrimary;

  @Deprecated('Utiliser textSecondary a la place')
  static const Color textMedium = textSecondary;

  @Deprecated('Utiliser textTertiary a la place')
  static const Color textLight = textTertiary;

  @Deprecated('Utiliser primaryGradient a la place')
  static const LinearGradient orangeGradient = primaryGradient;

  @Deprecated('Utiliser secondaryGradient a la place')
  static const LinearGradient greenGradient = secondaryGradient;
}
