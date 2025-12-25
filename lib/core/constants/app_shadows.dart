import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Systeme de shadows pour les themes light et dark
/// Le dark mode inclut un glow orange subtil pour un effet premium
class AppShadows {
  AppShadows._();

  // ============================================
  // LIGHT THEME SHADOWS
  // ============================================

  /// Shadow subtile - leger lift
  static const List<BoxShadow> shadowSubtle = [
    BoxShadow(
      color: Color(0x08000000), // 3% opacity
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  /// Shadow medium - cards au repos
  static const List<BoxShadow> shadowMedium = [
    BoxShadow(
      color: Color(0x0F000000), // 6% opacity
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];

  /// Shadow prominent - elements flottants
  static const List<BoxShadow> shadowProminent = [
    BoxShadow(
      color: Color(0x1A000000), // 10% opacity
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];

  /// Shadow elevated - modals, dropdowns
  static const List<BoxShadow> shadowElevated = [
    BoxShadow(
      color: Color(0x24000000), // 14% opacity
      blurRadius: 32,
      offset: Offset(0, 12),
    ),
  ];

  // ============================================
  // DARK THEME SHADOWS (avec glow orange)
  // ============================================

  /// Shadow subtile dark
  static const List<BoxShadow> shadowSubtleDark = [
    BoxShadow(
      color: Color(0x40000000), // 25% opacity
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  /// Shadow medium dark avec glow orange subtil
  static List<BoxShadow> shadowMediumDark = [
    const BoxShadow(
      color: Color(0x4D000000), // 30% opacity
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
    BoxShadow(
      color: AppColors.primary.withValues(alpha: 0.06), // Glow orange 6%
      blurRadius: 24,
      offset: Offset.zero,
    ),
  ];

  /// Shadow prominent dark avec glow orange
  static List<BoxShadow> shadowProminentDark = [
    const BoxShadow(
      color: Color(0x66000000), // 40% opacity
      blurRadius: 32,
      offset: Offset(0, 12),
    ),
    BoxShadow(
      color: AppColors.primary.withValues(alpha: 0.08), // Glow orange 8%
      blurRadius: 40,
      offset: Offset.zero,
    ),
  ];

  /// Shadow elevated dark avec glow orange prononce
  static List<BoxShadow> shadowElevatedDark = [
    const BoxShadow(
      color: Color(0x80000000), // 50% opacity
      blurRadius: 48,
      offset: Offset(0, 16),
    ),
    BoxShadow(
      color: AppColors.primary.withValues(alpha: 0.10), // Glow orange 10%
      blurRadius: 56,
      offset: Offset.zero,
    ),
  ];

  // ============================================
  // SPECIAL SHADOWS
  // ============================================

  /// Shadow pour bottom navigation
  static const List<BoxShadow> shadowBottomNav = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 16,
      offset: Offset(0, -4),
    ),
  ];

  /// Shadow pour bottom navigation dark
  static List<BoxShadow> shadowBottomNavDark = [
    const BoxShadow(
      color: Color(0x40000000),
      blurRadius: 16,
      offset: Offset(0, -4),
    ),
    BoxShadow(
      color: AppColors.primary.withValues(alpha: 0.04),
      blurRadius: 24,
      offset: Offset.zero,
    ),
  ];

  /// Shadow pour FAB
  static const List<BoxShadow> shadowFab = [
    BoxShadow(
      color: Color(0x33000000),
      blurRadius: 16,
      offset: Offset(0, 6),
    ),
  ];

  /// Shadow pour FAB dark avec glow
  static List<BoxShadow> shadowFabDark = [
    const BoxShadow(
      color: Color(0x66000000),
      blurRadius: 16,
      offset: Offset(0, 6),
    ),
    BoxShadow(
      color: AppColors.primary.withValues(alpha: 0.20),
      blurRadius: 24,
      offset: Offset.zero,
    ),
  ];

  /// Shadow pour input focus
  static List<BoxShadow> shadowInputFocus = [
    BoxShadow(
      color: AppColors.primary.withValues(alpha: 0.15),
      blurRadius: 8,
      offset: Offset.zero,
    ),
  ];

  /// Shadow pour input focus dark
  static List<BoxShadow> shadowInputFocusDark = [
    BoxShadow(
      color: AppColors.primaryLight.withValues(alpha: 0.20),
      blurRadius: 12,
      offset: Offset.zero,
    ),
  ];

  // ============================================
  // HELPER METHODS
  // ============================================

  /// Retourne les shadows appropriees selon le theme
  static List<BoxShadow> getShadow({
    required bool isDark,
    ShadowLevel level = ShadowLevel.medium,
  }) {
    switch (level) {
      case ShadowLevel.subtle:
        return isDark ? shadowSubtleDark : shadowSubtle;
      case ShadowLevel.medium:
        return isDark ? shadowMediumDark : shadowMedium;
      case ShadowLevel.prominent:
        return isDark ? shadowProminentDark : shadowProminent;
      case ShadowLevel.elevated:
        return isDark ? shadowElevatedDark : shadowElevated;
    }
  }
}

/// Niveaux de shadow disponibles
enum ShadowLevel {
  subtle,
  medium,
  prominent,
  elevated,
}
