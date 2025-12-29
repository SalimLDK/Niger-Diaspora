import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Typographie premium Diaspo Niger
/// Display/Headlines: Playfair Display (elegant, serif)
/// Body/Labels: Inter (moderne, lisible)
///
/// Note: All styles use getters with error handling to gracefully fallback
/// to system fonts if Google Fonts fail to load (e.g., on OnePlus devices
/// or in poor network conditions).
class AppTextStyles {
  AppTextStyles._();

  // Helper to safely get Playfair Display font
  static TextStyle _playfairDisplay({
    required double fontSize,
    required FontWeight fontWeight,
    required double height,
    required Color color,
  }) {
    try {
      return GoogleFonts.playfairDisplay(
        fontSize: fontSize,
        fontWeight: fontWeight,
        height: height,
        color: color,
      );
    } catch (e) {
      return TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        height: height,
        color: color,
        fontFamily: 'serif',
      );
    }
  }

  // Helper to safely get Inter font
  static TextStyle _inter({
    required double fontSize,
    required FontWeight fontWeight,
    required double height,
    Color? color,
    TextDecoration? decoration,
    Color? decorationColor,
    double? letterSpacing,
  }) {
    try {
      return GoogleFonts.inter(
        fontSize: fontSize,
        fontWeight: fontWeight,
        height: height,
        color: color,
        decoration: decoration,
        decorationColor: decorationColor,
        letterSpacing: letterSpacing,
      );
    } catch (e) {
      return TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        height: height,
        color: color,
        decoration: decoration,
        decorationColor: decorationColor,
        letterSpacing: letterSpacing,
      );
    }
  }

  // ============================================
  // DISPLAY - Playfair Display
  // ============================================

  /// Display Large - Hero, splash screens
  static TextStyle get displayLarge => _playfairDisplay(
    fontSize: 40,
    fontWeight: FontWeight.w700,
    height: 1.15,
    color: AppColors.textPrimary,
  );

  /// Display Medium - Section headers majeurs
  static TextStyle get displayMedium => _playfairDisplay(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.20,
    color: AppColors.textPrimary,
  );

  /// Display Small - Sub-headers
  static TextStyle get displaySmall => _playfairDisplay(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    height: 1.25,
    color: AppColors.textPrimary,
  );

  // ============================================
  // HEADLINE - Playfair Display
  // ============================================

  static TextStyle get headlineLarge => _playfairDisplay(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.30,
    color: AppColors.textPrimary,
  );

  static TextStyle get headlineMedium => _playfairDisplay(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    height: 1.35,
    color: AppColors.textPrimary,
  );

  static TextStyle get headlineSmall => _playfairDisplay(
    fontSize: 20,
    fontWeight: FontWeight.w500,
    height: 1.35,
    color: AppColors.textPrimary,
  );

  // ============================================
  // TITLE - Inter
  // ============================================

  static TextStyle get titleLarge => _inter(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.40,
    color: AppColors.textPrimary,
  );

  static TextStyle get titleMedium => _inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.45,
    color: AppColors.textPrimary,
  );

  static TextStyle get titleSmall => _inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.45,
    color: AppColors.textPrimary,
  );

  // ============================================
  // BODY - Inter
  // ============================================

  static TextStyle get bodyLarge => _inter(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.55,
    color: AppColors.textSecondary,
  );

  static TextStyle get bodyMedium => _inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.55,
    color: AppColors.textSecondary,
  );

  static TextStyle get bodySmall => _inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.50,
    color: AppColors.textTertiary,
  );

  // ============================================
  // LABEL - Inter
  // ============================================

  static TextStyle get labelLarge => _inter(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.40,
    color: AppColors.textPrimary,
  );

  static TextStyle get labelMedium => _inter(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.35,
    color: AppColors.textSecondary,
  );

  static TextStyle get labelSmall => _inter(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    height: 1.30,
    color: AppColors.textTertiary,
  );

  // ============================================
  // BUTTON STYLES
  // ============================================

  static TextStyle get buttonLarge => _inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.25,
    letterSpacing: 0.2,
  );

  static TextStyle get buttonMedium => _inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.25,
    letterSpacing: 0.2,
  );

  static TextStyle get buttonSmall => _inter(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.25,
    letterSpacing: 0.2,
  );

  // ============================================
  // SPECIAL STYLES
  // ============================================

  /// Style pour les liens
  static TextStyle get link => _inter(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.40,
    color: AppColors.primary,
    decoration: TextDecoration.underline,
    decorationColor: AppColors.primary,
  );

  /// Style pour les prix/montants
  static TextStyle get price => _inter(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.20,
    color: AppColors.textPrimary,
  );

  /// Style pour les compteurs/stats
  static TextStyle get stat => _playfairDisplay(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.15,
    color: AppColors.primary,
  );

  /// Style pour les captions/hints
  static TextStyle get caption => _inter(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    height: 1.40,
    color: AppColors.textTertiary,
  );

  /// Style pour les erreurs
  static TextStyle get error => _inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.40,
    color: AppColors.error,
  );

  // ============================================
  // DARK THEME VARIANTS
  // ============================================

  /// Obtenir le style avec la couleur du theme dark
  static TextStyle withDarkColor(TextStyle style) {
    final color = style.color;
    if (color == AppColors.textPrimary) {
      return style.copyWith(color: AppColors.textPrimaryDark);
    } else if (color == AppColors.textSecondary) {
      return style.copyWith(color: AppColors.textSecondaryDark);
    } else if (color == AppColors.textTertiary) {
      return style.copyWith(color: AppColors.textTertiaryDark);
    }
    return style;
  }

  // ============================================
  // LEGACY ALIASES (pour compatibilite)
  // ============================================

  @Deprecated('Utiliser textPrimary de AppColors')
  static const Color textDark = AppColors.textPrimary;

  @Deprecated('Utiliser textSecondary de AppColors')
  static const Color textMedium = AppColors.textSecondary;

  @Deprecated('Utiliser textTertiary de AppColors')
  static const Color textLight = AppColors.textTertiary;
}
