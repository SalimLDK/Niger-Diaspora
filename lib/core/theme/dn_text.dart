import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'dn_colors.dart';

/// Sahel typography — Audio Rooms feature tokens.
///
/// Families:
///  - serif  → Instrument Serif (titles, key numbers)
///  - sans   → Instrument Sans (body, UI controls)
///  - mono   → IBM Plex Mono (labels uppercase, timestamps)
class DNText {
  DNText._();

  /// Hero / titles — Instrument Serif.
  static TextStyle serif({
    double size = 24,
    FontWeight w = FontWeight.w400,
    bool italic = false,
    Color? color,
  }) =>
      GoogleFonts.instrumentSerif(
        fontSize: size,
        fontWeight: w,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
        color: color ?? DNColors.ink,
        height: 1.05,
        letterSpacing: -0.3,
      );

  /// Body / controls — Instrument Sans.
  static TextStyle sans({
    double size = 14,
    FontWeight w = FontWeight.w400,
    Color? color,
  }) =>
      GoogleFonts.instrumentSans(
        fontSize: size,
        fontWeight: w,
        color: color ?? DNColors.ink,
        height: 1.35,
      );

  /// Labels uppercase / timestamps — IBM Plex Mono.
  static TextStyle mono({
    double size = 10,
    Color? color,
    bool upper = false,
  }) =>
      GoogleFonts.ibmPlexMono(
        fontSize: size,
        color: color ?? DNColors.ink3,
        letterSpacing: 0.4,
      );
}
