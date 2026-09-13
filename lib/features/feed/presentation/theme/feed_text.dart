import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'feed_tokens.dart';

/// Feed typography — Caprasimo for headings, Figtree for body, in BOTH
/// themes.
///
/// Nocturne utilisait Inter partout (fiche 6a). Depuis le 2026-09-13 le fil
/// sombre reprend la typographie du clair : sur deux téléphones, l'un en
/// clair et l'autre en sombre, « Le fil. » n'avait plus la même allure
/// (voir `FeedTokens`).
class FeedText {
  FeedText._();

  static TextStyle heading(
    FeedTokens tokens, {
    double size = 20,
    Color? color,
  }) {
    return GoogleFonts.caprasimo(fontSize: size, color: color ?? tokens.text);
  }

  static TextStyle body(
    FeedTokens tokens, {
    double size = 14.5,
    FontWeight weight = FontWeight.w400,
    Color? color,
  }) {
    return GoogleFonts.figtree(
      fontSize: size,
      fontWeight: weight,
      color: color ?? tokens.text,
    );
  }
}
