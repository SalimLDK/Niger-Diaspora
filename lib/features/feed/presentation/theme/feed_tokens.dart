import 'package:flutter/material.dart';

/// Feed design tokens, transcribed from the Claude Design "Feed Prototype"
/// mockups: [nocturne] (dark — indigo accent, tight radii) and [organic]
/// (light — terracotta accent, generous rounded radii). Mirrors the
/// feature-scoped token pattern already used by Audio Rooms (`DNColors`).
///
/// Usage: `final tokens = FeedTokens.of(context);`
@immutable
class FeedTokens {
  const FeedTokens({
    required this.isDark,
    required this.bg,
    required this.surface,
    required this.text,
    required this.mutedText,
    required this.accent,
    required this.accent2,
    required this.divider,
    required this.onAccent,
    required this.avatarBg,
    required this.avatarFg,
    required this.hashtagColor,
    required this.tagAccentBg,
    required this.tagAccentFg,
    required this.tagAccent2Bg,
    required this.tagAccent2Fg,
    required this.tagNeutralBg,
    required this.tagNeutralFg,
    required this.space1,
    required this.space2,
    required this.space3,
    required this.space4,
    required this.space6,
    required this.space8,
    required this.radiusSm,
    required this.radiusMd,
    required this.radiusLg,
    required this.cardRadius,
    required this.fabBg,
    required this.fabFg,
    required this.fabBorder,
    required this.fabShadow,
    required this.segmentActiveBg,
    required this.segmentActiveFg,
    required this.segmentActiveBorder,
  });

  final bool isDark;

  final Color bg;
  final Color surface;
  final Color text;
  final Color mutedText;
  final Color accent;
  final Color accent2;
  final Color divider;

  /// Text/icon color to use on top of a solid [accent] fill.
  final Color onAccent;

  final Color avatarBg;
  final Color avatarFg;

  /// Mention/hashtag inline text color (accent-300 on dark, accent-700 on
  /// light — each system's own contrast pick for accent text on its own bg).
  final Color hashtagColor;

  final Color tagAccentBg;
  final Color tagAccentFg;
  final Color tagAccent2Bg;
  final Color tagAccent2Fg;
  final Color tagNeutralBg;
  final Color tagNeutralFg;

  final double space1;
  final double space2;
  final double space3;
  final double space4;
  final double space6;
  final double space8;

  final double radiusSm;
  final double radiusMd;
  final double radiusLg;

  /// Card corner radius — Organic overrides its own `--radius-lg` with a
  /// "rounded frame" rule (`radius-lg * 1.15`); Nocturne cards use `radius-md`.
  final double cardRadius;

  final Color fabBg;
  final Color fabFg;
  final Color? fabBorder;
  final List<BoxShadow> fabShadow;

  final Color segmentActiveBg;
  final Color segmentActiveFg;
  final Color? segmentActiveBorder;

  static const nocturne = FeedTokens(
    isDark: true,
    bg: Color(0xFF161826),
    surface: Color(0xFF232532),
    text: Color(0xFFE9E9ED),
    mutedText: Color(0xFF9397AB),
    accent: Color(0xFF9184D9),
    accent2: Color(0xFFA7A1DB),
    divider: Color(0x29E9E9ED),
    onAccent: Color(0xFFFFFFFF),
    avatarBg: Color(0xFF423A6A),
    avatarFg: Color(0xFFF5F4FF),
    hashtagColor: Color(0xFFD2CEFD),
    tagAccentBg: Color(0xFF423A6A),
    tagAccentFg: Color(0xFFF5F4FF),
    tagAccent2Bg: Color(0xFF423E5D),
    tagAccent2Fg: Color(0xFFF5F4FF),
    tagNeutralBg: Color(0xFF3F424D),
    tagNeutralFg: Color(0xFFF3F5FE),
    space1: 2.8,
    space2: 5.6,
    space3: 8.4,
    space4: 11.2,
    space6: 16.8,
    space8: 22.4,
    radiusSm: 4,
    radiusMd: 8,
    radiusLg: 14,
    cardRadius: 8,
    fabBg: Colors.transparent,
    fabFg: Color(0xFF9184D9),
    fabBorder: Color(0xFF9184D9),
    fabShadow: [
      BoxShadow(color: Color(0xFF9397AB), blurRadius: 0, spreadRadius: 1),
      BoxShadow(
        color: Color(0xA6000000),
        blurRadius: 40,
        offset: Offset(0, 16),
      ),
    ],
    segmentActiveBg: Colors.transparent,
    segmentActiveFg: Color(0xFF9184D9),
    segmentActiveBorder: Color(0xFF9184D9),
  );

  static const organic = FeedTokens(
    isDark: false,
    bg: Color(0xFFF5EAD8),
    surface: Color(0xFFEBDDC5),
    text: Color(0xFF201E1D),
    mutedText: Color(0xFF82796A),
    accent: Color(0xFFC67139),
    accent2: Color(0xFF7A8A5E),
    divider: Color(0x29201E1D),
    onAccent: Color(0xFFF5EAD8),
    avatarBg: Color(0xFF643312),
    avatarFg: Color(0xFFFFF2EB),
    hashtagColor: Color(0xFF8C491A),
    tagAccentBg: Color(0xFFFFF2EB),
    tagAccentFg: Color(0xFF643312),
    tagAccent2Bg: Color(0xFFF0FAE1),
    tagAccent2Fg: Color(0xFF3D472B),
    tagNeutralBg: Color(0xFFF9F4ED),
    tagNeutralFg: Color(0xFF474238),
    space1: 4.4,
    space2: 8.8,
    space3: 13.2,
    space4: 17.6,
    space6: 26.4,
    space8: 35.2,
    radiusSm: 8,
    radiusMd: 16,
    radiusLg: 28,
    cardRadius: 32,
    fabBg: Color(0xFFC67139),
    fabFg: Color(0xFFF5EAD8),
    fabBorder: null,
    fabShadow: [
      BoxShadow(
        color: Color(0x382E2B25),
        blurRadius: 32,
        offset: Offset(0, 12),
      ),
    ],
    segmentActiveBg: Color(0xFFC67139),
    segmentActiveFg: Color(0xFFF5EAD8),
    segmentActiveBorder: null,
  );

  static FeedTokens of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? nocturne : organic;
}
