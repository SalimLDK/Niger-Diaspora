import 'package:flutter/material.dart';

/// Utility class for generating consistent colors for users in group chats
class UserColorUtils {
  UserColorUtils._();

  /// Palette of vibrant, high-contrast colors optimized for readability
  /// on both light and dark message bubbles
  static const List<Color> _userColors = [
    Color(0xFFE91E63), // Pink
    Color(0xFF9C27B0), // Purple
    Color(0xFF673AB7), // Deep Purple
    Color(0xFF3F51B5), // Indigo
    Color(0xFF2196F3), // Blue
    Color(0xFF00BCD4), // Cyan
    Color(0xFF009688), // Teal
    Color(0xFF4CAF50), // Green
    Color(0xFFFF9800), // Orange
    Color(0xFFFF5722), // Deep Orange
    Color(0xFF795548), // Brown
    Color(0xFF607D8B), // Blue Grey
  ];

  /// Generate a consistent color for a user based on their userId
  ///
  /// The same userId will always return the same color across all sessions,
  /// ensuring visual consistency in group chats.
  ///
  /// Example:
  /// ```dart
  /// final color = UserColorUtils.getUserColor(message.senderId);
  /// ```
  static Color getUserColor(String userId) {
    // Generate a hash from the userId
    int hash = _hashString(userId);

    // Use modulo to get an index within the color palette
    int colorIndex = hash.abs() % _userColors.length;

    return _userColors[colorIndex];
  }

  /// Simple hash function for strings
  static int _hashString(String str) {
    int hash = 0;
    for (int i = 0; i < str.length; i++) {
      hash = ((hash << 5) - hash) + str.codeUnitAt(i);
      hash = hash & hash; // Convert to 32bit integer
    }
    return hash;
  }
}
