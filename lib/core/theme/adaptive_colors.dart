import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Extension sur BuildContext pour accéder aux couleurs adaptatives
/// selon le thème actuel (light/dark mode)
extension AdaptiveColors on BuildContext {
  /// Vérifie si le thème actuel est dark mode
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  // ============================================
  // BACKGROUNDS & SURFACES
  // ============================================

  /// Couleur de fond principale (scaffold)
  Color get backgroundColor =>
      isDarkMode ? AppColors.backgroundDark : AppColors.background;

  /// Couleur des surfaces (cards, modals)
  Color get surfaceColor =>
      isDarkMode ? AppColors.surfaceDark : AppColors.surface;

  /// Couleur des surfaces élevées
  Color get surfaceElevatedColor =>
      isDarkMode ? AppColors.surfaceElevatedDark : AppColors.surfaceElevated;

  /// Couleur des surfaces variantes
  Color get surfaceVariantColor =>
      isDarkMode ? AppColors.surfaceVariantDark : AppColors.surfaceVariant;

  /// Couleur sur surface (texte/icônes)
  Color get onSurfaceColor =>
      isDarkMode ? AppColors.white : AppColors.textPrimary;

  /// Couleur sur primaire (texte/icônes)
  Color get onPrimaryColor => isDarkMode ? AppColors.black : AppColors.white;

  /// Couleur sur secondaire (texte/icônes)
  Color get onSecondaryColor => isDarkMode ? AppColors.black : AppColors.white;

  // ============================================
  // BORDERS
  // ============================================

  /// Couleur de bordure standard
  Color get borderColor => isDarkMode ? AppColors.borderDark : AppColors.border;

  /// Couleur de bordure forte/marquée
  Color get borderStrongColor =>
      isDarkMode ? AppColors.borderStrongDark : AppColors.borderStrong;

  /// Couleur de contour (pour les inputs, etc)
  Color get outlineColor => borderColor;

  // ============================================
  // TEXT COLORS
  // ============================================

  /// Couleur de texte principale
  Color get textPrimaryColor =>
      isDarkMode ? AppColors.textPrimaryDark : AppColors.textPrimary;

  /// Couleur de texte secondaire
  Color get textSecondaryColor =>
      isDarkMode ? AppColors.textSecondaryDark : AppColors.textSecondary;

  /// Couleur de texte tertiaire
  Color get textTertiaryColor =>
      isDarkMode ? AppColors.textTertiaryDark : AppColors.textTertiary;

  /// Couleur de texte désactivé
  Color get textDisabledColor =>
      isDarkMode ? AppColors.textDisabledDark : AppColors.textDisabled;

  /// Couleur de texte inverse (sur fond coloré)
  Color get textInverseColor =>
      isDarkMode ? AppColors.textInverseDark : AppColors.textInverse;

  // ============================================
  // SEMANTIC COLORS
  // ============================================

  /// Couleur de succès
  Color get successColor =>
      isDarkMode ? AppColors.successDark : AppColors.success;

  /// Fond de succès
  Color get successBackgroundColor =>
      isDarkMode
          ? AppColors.successBackgroundDark
          : AppColors.successBackground;

  /// Couleur d'erreur
  Color get errorColor => isDarkMode ? AppColors.errorDark : AppColors.error;

  /// Fond d'erreur
  Color get errorBackgroundColor =>
      isDarkMode ? AppColors.errorBackgroundDark : AppColors.errorBackground;

  /// Couleur d'avertissement
  Color get warningColor =>
      isDarkMode ? AppColors.warningDark : AppColors.warning;

  /// Fond d'avertissement
  Color get warningBackgroundColor =>
      isDarkMode
          ? AppColors.warningBackgroundDark
          : AppColors.warningBackground;

  /// Couleur d'information
  Color get infoColor => isDarkMode ? AppColors.infoDark : AppColors.info;

  /// Fond d'information
  Color get infoBackgroundColor =>
      isDarkMode ? AppColors.infoBackgroundDark : AppColors.infoBackground;

  // ============================================
  // PRIMARY COLORS (adapté pour dark mode)
  // ============================================

  /// Couleur primaire adaptée (plus claire en dark mode)
  Color get adaptivePrimaryColor =>
      isDarkMode ? AppColors.primaryLight : AppColors.primary;

  /// Couleur primaire légère adaptée
  Color get adaptivePrimaryLightColor =>
      isDarkMode ? AppColors.primary : AppColors.primaryLight;

  /// Fond primaire léger
  Color get primaryBackgroundColor =>
      isDarkMode ? const Color(0xFF2D2014) : AppColors.primaryLighter;

  // ============================================
  // SECONDARY COLORS (adapté pour dark mode)
  // ============================================

  /// Couleur secondaire adaptée
  Color get adaptiveSecondaryColor =>
      isDarkMode ? AppColors.secondaryLight : AppColors.secondary;

  /// Fond secondaire léger
  Color get secondaryBackgroundColor =>
      isDarkMode ? const Color(0xFF1A3322) : AppColors.secondaryLighter;

  // ============================================
  // GRADIENTS
  // ============================================

  /// Gradient primaire adaptatif
  LinearGradient get adaptivePrimaryGradient =>
      isDarkMode ? AppColors.primaryGradientDark : AppColors.primaryGradient;

  // ============================================
  // SHADOWS & OVERLAYS
  // ============================================

  /// Couleur d'ombre adaptative
  Color get shadowColor =>
      isDarkMode
          ? Colors.black.withValues(alpha: 0.3)
          : Colors.black.withValues(alpha: 0.08);

  /// Overlay subtil pour les états hover/pressed
  Color get overlayColor =>
      isDarkMode
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.black.withValues(alpha: 0.05);

  // ============================================
  // ICON COLORS
  // ============================================

  /// Couleur d'icône principale
  Color get iconPrimaryColor =>
      isDarkMode ? AppColors.textPrimaryDark : AppColors.textPrimary;

  /// Couleur d'icône secondaire
  Color get iconSecondaryColor =>
      isDarkMode ? AppColors.textSecondaryDark : AppColors.textSecondary;

  /// Couleur d'icône tertiaire
  Color get iconTertiaryColor =>
      isDarkMode ? AppColors.textTertiaryDark : AppColors.textTertiary;

  // ============================================
  // DIVIDERS
  // ============================================

  /// Couleur de diviseur
  Color get dividerColor =>
      isDarkMode ? AppColors.borderDark : AppColors.border;

  // ============================================
  // CARD DECORATION HELPER
  // ============================================

  /// Décoration standard pour les cartes
  BoxDecoration get cardDecoration => BoxDecoration(
    color: surfaceColor,
    borderRadius: BorderRadius.circular(16),
    border:
        isDarkMode ? Border.all(color: AppColors.borderDark, width: 1) : null,
    boxShadow:
        isDarkMode
            ? null
            : [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
  );

  /// Décoration élevée pour les cartes
  BoxDecoration get elevatedCardDecoration => BoxDecoration(
    color: surfaceElevatedColor,
    borderRadius: BorderRadius.circular(16),
    border:
        isDarkMode ? Border.all(color: AppColors.borderDark, width: 1) : null,
    boxShadow: [
      BoxShadow(
        color: shadowColor,
        blurRadius: isDarkMode ? 12 : 16,
        offset: const Offset(0, 4),
      ),
    ],
  );

  /// Décoration pour les champs de saisie
  BoxDecoration get inputDecoration => BoxDecoration(
    color: surfaceVariantColor,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: borderColor, width: 1),
  );
}

/// Classe utilitaire pour les couleurs adaptatives sans contexte
/// (à utiliser uniquement quand nécessaire)
class AdaptiveColorsHelper {
  static Color getBackgroundColor(bool isDark) =>
      isDark ? AppColors.backgroundDark : AppColors.background;

  static Color getSurfaceColor(bool isDark) =>
      isDark ? AppColors.surfaceDark : AppColors.surface;

  static Color getTextPrimaryColor(bool isDark) =>
      isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;

  static Color getTextSecondaryColor(bool isDark) =>
      isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;

  static Color getBorderColor(bool isDark) =>
      isDark ? AppColors.borderDark : AppColors.border;
}
