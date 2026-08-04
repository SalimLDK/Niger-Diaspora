import 'package:flutter/material.dart';

import '../theme/feed_text.dart';
import '../theme/feed_tokens.dart';

/// Onglets pleins des fiches 5b et 5d : deux pastilles de largeur égale,
/// l'active remplie à l'accent, gap 6, rayon 13.
///
/// Distinct de `FeedSegmentedControl` (pilule à contour unique avec icônes et
/// séparateur) que le reste du fil utilise — les fiches demandent ici deux
/// blocs séparés, sans icône, avec un compteur collé au libellé.
class FeedPillTabs extends StatelessWidget {
  final FeedTokens tokens;
  final int selected;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  const FeedPillTabs({
    super.key,
    required this.tokens,
    required this.selected,
    required this.labels,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(tokens.isDark ? tokens.radiusMd : 13);
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: Material(
              color: selected == i ? tokens.segmentActiveBg : tokens.surface,
              borderRadius: radius,
              child: InkWell(
                borderRadius: radius,
                onTap: () => onChanged(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    border:
                        selected == i && tokens.segmentActiveBorder != null
                            ? Border.all(color: tokens.segmentActiveBorder!)
                            : null,
                  ),
                  child: Text(
                    labels[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: FeedText.body(
                      tokens,
                      size: 13,
                      weight: selected == i ? FontWeight.w600 : FontWeight.w500,
                      color:
                          selected == i
                              ? tokens.segmentActiveFg
                              : tokens.actionLabel,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
