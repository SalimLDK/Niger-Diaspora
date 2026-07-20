import 'package:flutter/material.dart';

import '../../../../../core/theme/dn_colors.dart';
import '../../../../../core/theme/dn_text.dart';
import '../../../../../core/theme/dn_theme.dart';

/// Horizontal fundraising progress bar.
class CollectionProgressBar extends StatelessWidget {
  final double current;
  final double goal;
  final String beneficiary;
  final int contributors;

  const CollectionProgressBar({
    required this.current,
    required this.goal,
    required this.beneficiary,
    required this.contributors,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final dn = context.dn;
    final pct = goal > 0 ? (current / goal).clamp(0.0, 1.0) : 0.0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: dn.surfaceVariant,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '📦 Objectif ${goal.toStringAsFixed(0)} €',
                style: DNText.mono(size: 9, color: dn.onSurface3),
              ),
              Text(
                '${(pct * 100).round()}% · ${current.toStringAsFixed(0)} €',
                style: DNText.mono(size: 10, color: DNColors.leaf),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: dn.surface2,
              valueColor: const AlwaysStoppedAnimation(DNColors.leaf),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$beneficiary · $contributors contrib.',
            style: DNText.mono(size: 8, color: dn.onSurface3),
          ),
        ],
      ),
    );
  }
}
