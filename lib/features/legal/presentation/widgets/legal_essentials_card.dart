import 'package:flutter/material.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

import '../../../../core/theme/adaptive_colors.dart';

/// Encart « L'essentiel » (§26c) : trois garanties clés en tête de chaque
/// document légal, avant le texte complet.
class LegalEssentialsCard extends StatelessWidget {
  final List<String> guarantees;

  const LegalEssentialsCard({super.key, required this.guarantees});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.adaptivePrimaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: context.adaptivePrimaryColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.legalEssentialsTitle,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: context.adaptivePrimaryColor,
            ),
          ),
          const SizedBox(height: 10),
          for (final g in guarantees)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 16,
                    color: context.adaptivePrimaryColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      g,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.4,
                        color: context.textPrimaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Estimation grossière du temps de lecture (~200 mots/min), jamais < 1 min.
/// Prend directement les contenus textuels pour rester indépendant du type
/// de section (modèle ou entité, mêmes champs mais classes distinctes).
String legalReadingTimeLabel(Iterable<String> sectionContents, AppLocalizations l10n) {
  final wordCount = sectionContents.fold<int>(
    0,
    (sum, content) => sum + content.trim().split(RegExp(r'\s+')).length,
  );
  final minutes = (wordCount / 200).ceil().clamp(1, 999);
  return l10n.legalReadingTime(minutes);
}
