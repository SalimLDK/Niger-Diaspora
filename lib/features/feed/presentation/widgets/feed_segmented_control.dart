import 'package:flutter/material.dart';

import '../theme/feed_tokens.dart';

class FeedSegment<T> {
  final T value;

  /// Builds the segment's leading icon for the given (state-dependent) color.
  final Widget Function(Color color) icon;
  final String label;

  const FeedSegment({
    required this.value,
    required this.icon,
    required this.label,
  });
}

/// Pill segmented control matching the mockups' `.seg`/`.seg-opt`: an
/// outlined rounded container whose active segment is either outlined
/// (Nocturne) or filled (Organic), per `tokens.segmentActive*`.
class FeedSegmentedControl<T> extends StatelessWidget {
  final List<FeedSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;
  final FeedTokens tokens;

  /// Segments de largeur égale occupant toute la largeur disponible
  /// (refonte tour 4 : `Expanded` au lieu d'un groupe compact à gauche).
  final bool fullWidth;

  const FeedSegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
    required this.tokens,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(tokens.radiusMd),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: tokens.divider),
          borderRadius: BorderRadius.circular(tokens.radiusMd),
        ),
        child: Row(
          mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
          children: [
            for (var i = 0; i < segments.length; i++) ...[
              if (i > 0) Container(width: 1, height: 32, color: tokens.divider),
              if (fullWidth)
                Expanded(
                  child: _SegmentOption<T>(
                    segment: segments[i],
                    isActive: segments[i].value == selected,
                    tokens: tokens,
                    fill: true,
                    onTap: () => onChanged(segments[i].value),
                  ),
                )
              else
                _SegmentOption<T>(
                  segment: segments[i],
                  isActive: segments[i].value == selected,
                  tokens: tokens,
                  onTap: () => onChanged(segments[i].value),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SegmentOption<T> extends StatelessWidget {
  final FeedSegment<T> segment;
  final bool isActive;
  final FeedTokens tokens;
  final VoidCallback onTap;

  /// Occupe toute la largeur du segment (mode `fullWidth` : contenu centré).
  final bool fill;

  const _SegmentOption({
    required this.segment,
    required this.isActive,
    required this.tokens,
    required this.onTap,
    this.fill = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = isActive ? tokens.segmentActiveFg : tokens.mutedText;
    return InkWell(
      onTap: onTap,
      child: Container(
        width: fill ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? tokens.segmentActiveBg : Colors.transparent,
          border:
              isActive && tokens.segmentActiveBorder != null
                  // 1.5 px : la fiche 6a décrit l'onglet actif du fil nocturne
                  // comme « un contour 1.5px » — à 1 px il se confondait avec
                  // le filet du conteneur.
                  ? Border.all(color: tokens.segmentActiveBorder!, width: 1.5)
                  : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment:
              fill ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            SizedBox(width: 16, height: 16, child: segment.icon(fg)),
            const SizedBox(width: 6),
            Text(
              segment.label,
              style: TextStyle(
                fontSize: 13,
                color: fg,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
