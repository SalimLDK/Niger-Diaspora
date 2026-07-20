import 'package:flutter/material.dart';

import 'dn_colors.dart';

/// Theme-aware resolver for DNColors tokens.
/// Usage: `final dn = context.dn;` then `dn.surface`, `dn.onSurface`, etc.
class DNTheme {
  final bool isDark;
  const DNTheme(this.isDark);

  Color get surface        => isDark ? const Color(0xFF1A1714) : DNColors.paper;
  Color get surface2       => isDark ? const Color(0xFF2A201A) : DNColors.paper2;
  Color get surfaceVariant => isDark ? const Color(0xFF3D342A) : DNColors.sand;
  Color get onSurface      => isDark ? const Color(0xFFF5ECD7) : DNColors.ink;
  Color get onSurface2     => isDark ? const Color(0xFFD4C4A8) : DNColors.ink2;
  Color get onSurface3     => isDark ? const Color(0xFF9E8E78) : DNColors.ink3;
  Color get onSurface4     => isDark ? const Color(0xFF5A4F44) : DNColors.ink4;
}

extension DNThemeExt on BuildContext {
  DNTheme get dn => DNTheme(Theme.of(this).brightness == Brightness.dark);
}
