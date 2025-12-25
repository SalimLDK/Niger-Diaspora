import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Typographie premium Niger Diaspora
/// Display/Headlines: Playfair Display (elegant, serif)
/// Body/Labels: Inter (moderne, lisible)
class AppTextStyles {
  AppTextStyles._();

  // ============================================
  // DISPLAY - Playfair Display
  // ============================================

  /// Display Large - Hero, splash screens
  static TextStyle displayLarge = GoogleFonts.playfairDisplay(
    fontSize: 40,
    fontWeight: FontWeight.w700,
    height: 1.15,
    color: AppColors.textPrimary,
  );

  /// Display Medium - Section headers majeurs
  static TextStyle displayMedium = GoogleFonts.playfairDisplay(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.20,
    color: AppColors.textPrimary,
  );

  /// Display Small - Sub-headers
  static TextStyle displaySmall = GoogleFonts.playfairDisplay(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    height: 1.25,
    color: AppColors.textPrimary,
  );

  // ============================================
  // HEADLINE - Playfair Display
  // ============================================

  static TextStyle headlineLarge = GoogleFonts.playfairDisplay(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.30,
    color: AppColors.textPrimary,
  );

  static TextStyle headlineMedium = GoogleFonts.playfairDisplay(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    height: 1.35,
    color: AppColors.textPrimary,
  );

  static TextStyle headlineSmall = GoogleFonts.playfairDisplay(
    fontSize: 20,
    fontWeight: FontWeight.w500,
    height: 1.35,
    color: AppColors.textPrimary,
  );

  // ============================================
  // TITLE - Inter
  // ============================================

  static TextStyle titleLarge = GoogleFonts.inter(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.40,
    color: AppColors.textPrimary,
  );

  static TextStyle titleMedium = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.45,
    color: AppColors.textPrimary,
  );

  static TextStyle titleSmall = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.45,
    color: AppColors.textPrimary,
  );

  // ============================================
  // BODY - Inter
  // ============================================

  static TextStyle bodyLarge = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.55,
    color: AppColors.textSecondary,
  );

  static TextStyle bodyMedium = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.55,
    color: AppColors.textSecondary,
  );

  static TextStyle bodySmall = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.50,
    color: AppColors.textTertiary,
  );

  // ============================================
  // LABEL - Inter
  // ============================================

  static TextStyle labelLarge = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.40,
    color: AppColors.textPrimary,
  );

  static TextStyle labelMedium = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.35,
    color: AppColors.textSecondary,
  );

  static TextStyle labelSmall = GoogleFonts.inter(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    height: 1.30,
    color: AppColors.textTertiary,
  );

  // ============================================
  // BUTTON STYLES
  // ============================================

  static TextStyle buttonLarge = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.25,
    letterSpacing: 0.2,
  );

  static TextStyle buttonMedium = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.25,
    letterSpacing: 0.2,
  );

  static TextStyle buttonSmall = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.25,
    letterSpacing: 0.2,
  );

  // ============================================
  // SPECIAL STYLES
  // ============================================

  /// Style pour les liens
  static TextStyle link = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.40,
    color: AppColors.primary,
    decoration: TextDecoration.underline,
    decorationColor: AppColors.primary,
  );

  /// Style pour les prix/montants
  static TextStyle price = GoogleFonts.inter(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.20,
    color: AppColors.textPrimary,
  );

  /// Style pour les compteurs/stats
  static TextStyle stat = GoogleFonts.playfairDisplay(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.15,
    color: AppColors.primary,
  );

  /// Style pour les captions/hints
  static TextStyle caption = GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    height: 1.40,
    color: AppColors.textTertiary,
  );

  /// Style pour les erreurs
  static TextStyle error = GoogleFonts.inter(
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
