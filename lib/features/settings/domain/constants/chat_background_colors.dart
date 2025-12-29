import 'package:flutter/material.dart';

/// Predefined chat background colors that don't conflict with message bubbles
class ChatBackgroundColors {
  ChatBackgroundColors._();

  // Light mode backgrounds
  static const Color beigeLight = Color(0xFFFFF8F0);
  static const Color bluePaleLight = Color(0xFFF0F8FF);
  static const Color pinkPaleLight = Color(0xFFFFF0F5);
  static const Color mintLight = Color(0xFFF0FFF4);

  // Dark mode backgrounds
  static const Color blueNightDark = Color(0xFF0A1929);
  static const Color greenDarkest = Color(0xFF0D1F1A);
  static const Color purpleDark = Color(0xFF1A0D29);
  static const Color slateDark = Color(0xFF1A1D29);

  /// Get all predefined colors for light mode
  static List<Color> getLightModeColors() => [
    beigeLight,
    bluePaleLight,
    pinkPaleLight,
    mintLight,
  ];

  /// Get all predefined colors for dark mode
  static List<Color> getDarkModeColors() => [
    blueNightDark,
    greenDarkest,
    purpleDark,
    slateDark,
  ];

  /// Get all predefined colors based on current theme
  static List<Color> getColors(bool isDarkMode) =>
      isDarkMode ? getDarkModeColors() : getLightModeColors();
}
