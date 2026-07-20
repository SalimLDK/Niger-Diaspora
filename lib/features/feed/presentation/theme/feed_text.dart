import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'feed_tokens.dart';

/// Feed typography — Nocturne uses Inter for both heading and body;
/// Organic uses the display font Caprasimo for headings and Figtree
/// for body, per each mockup's own `--font-heading`/`--font-body`.
class FeedText {
  FeedText._();

  static TextStyle heading(
    FeedTokens tokens, {
    double size = 20,
    Color? color,
  }) {
    final c = color ?? tokens.text;
    if (tokens.isDark) {
      return GoogleFonts.inter(
        fontSize: size,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.2,
        color: c,
      );
    }
    return GoogleFonts.caprasimo(fontSize: size, color: c);
  }

  static TextStyle body(
    FeedTokens tokens, {
    double size = 14.5,
    FontWeight weight = FontWeight.w400,
    Color? color,
  }) {
    final c = color ?? tokens.text;
    if (tokens.isDark) {
      return GoogleFonts.inter(fontSize: size, fontWeight: weight, color: c);
    }
    return GoogleFonts.figtree(fontSize: size, fontWeight: weight, color: c);
  }
}
