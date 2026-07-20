import 'package:flutter/material.dart';

import '../theme/feed_tokens.dart';

enum FeedTagVariant { accent, accent2, neutral, outline }

/// Small pill chip (`.tag` in the mockups) used for post category tags and
/// the composer's "Public" visibility tag.
class FeedTag extends StatelessWidget {
  final String label;
  final FeedTokens tokens;
  final FeedTagVariant variant;

  const FeedTag({
    super.key,
    required this.label,
    required this.tokens,
    this.variant = FeedTagVariant.accent,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    BoxBorder? border;
    switch (variant) {
      case FeedTagVariant.accent:
        bg = tokens.tagAccentBg;
        fg = tokens.tagAccentFg;
      case FeedTagVariant.accent2:
        bg = tokens.tagAccent2Bg;
        fg = tokens.tagAccent2Fg;
      case FeedTagVariant.neutral:
        bg = tokens.tagNeutralBg;
        fg = tokens.tagNeutralFg;
      case FeedTagVariant.outline:
        bg = Colors.transparent;
        fg = tokens.accent;
        border = Border.all(color: tokens.accent);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        border: border,
        borderRadius: BorderRadius.circular(tokens.radiusMd * 0.75),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          letterSpacing: 0.2,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
