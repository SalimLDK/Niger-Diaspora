import 'package:flutter/material.dart';

import '../theme/feed_tokens.dart';

/// Bottom-center pill toast matching the mockup's `showToast` behavior
/// (save/unsave, publish confirmations). Auto-dismisses after ~1.8s.
void showFeedToast(BuildContext context, String text) {
  final tokens = FeedTokens.of(context);
  final overlay = Overlay.of(context);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => Positioned(
      left: 0,
      right: 0,
      bottom: 110,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: tokens.accent,
              borderRadius: BorderRadius.circular(999),
              boxShadow: tokens.fabShadow,
            ),
            child: Text(
              text,
              style: TextStyle(
                color: tokens.onAccent,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    ),
  );

  overlay.insert(entry);
  Future.delayed(const Duration(milliseconds: 1800), () {
    entry.remove();
  });
}
