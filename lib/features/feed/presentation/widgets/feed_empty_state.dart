import 'package:flutter/material.dart';

import '../theme/feed_text.dart';
import '../theme/feed_tokens.dart';

/// Amorce d'action affichée sous l'illustration d'un état vide (une ligne
/// cliquable : pastille d'icône + libellé + chevron).
class FeedEmptySeed {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const FeedEmptySeed({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}

/// État vide « écran, pas message » (handoff tours 5e/5g/5h) :
/// cercle 104 px + icône accent → titre 21 px sur deux lignes → explication
/// 14,5 px → une à trois amorces cliquables → CTA plein. Une [note] discrète
/// (ex. « visibles que par vous ») peut coiffer le pied.
class FeedEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final List<FeedEmptySeed> seeds;
  final String? ctaLabel;
  final IconData? ctaIcon;
  final VoidCallback? onCta;
  final String? note;

  const FeedEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.seeds = const [],
    this.ctaLabel,
    this.ctaIcon,
    this.onCta,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = FeedTokens.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Cercle 104 px + icône accent.
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                color: tokens.accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 46, color: tokens.accent),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: FeedText.heading(tokens, size: 21),
            ),
            const SizedBox(height: 10),
            Text(
              body,
              textAlign: TextAlign.center,
              style: FeedText.body(
                tokens,
                size: 14.5,
                color: tokens.mutedText,
              ).copyWith(height: 1.55),
            ),
            if (seeds.isNotEmpty) ...[
              const SizedBox(height: 20),
              _SeedList(seeds: seeds, tokens: tokens),
            ],
            if (ctaLabel != null && onCta != null) ...[
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: tokens.accent,
                    foregroundColor: tokens.onAccent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(tokens.radiusMd),
                    ),
                  ),
                  onPressed: onCta,
                  icon: Icon(ctaIcon ?? Icons.add_rounded, size: 20),
                  label: Text(
                    ctaLabel!,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
            if (note != null) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 14,
                    color: tokens.mutedText,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      note!,
                      textAlign: TextAlign.center,
                      style: FeedText.body(
                        tokens,
                        size: 12.5,
                        color: tokens.mutedText,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SeedList extends StatelessWidget {
  final List<FeedEmptySeed> seeds;
  final FeedTokens tokens;

  const _SeedList({required this.seeds, required this.tokens});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(tokens.radiusMd),
        border: Border.all(color: tokens.hairline),
      ),
      child: Column(
        children: [
          for (var i = 0; i < seeds.length; i++) ...[
            if (i > 0) Container(height: 1, color: tokens.hairline),
            _SeedRow(seed: seeds[i], tokens: tokens),
          ],
        ],
      ),
    );
  }
}

class _SeedRow extends StatelessWidget {
  final FeedEmptySeed seed;
  final FeedTokens tokens;

  const _SeedRow({required this.seed, required this.tokens});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: seed.onTap,
      borderRadius: BorderRadius.circular(tokens.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: tokens.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(seed.icon, size: 20, color: tokens.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                seed.label,
                style: FeedText.body(
                  tokens,
                  size: 14,
                  weight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: tokens.mutedText,
            ),
          ],
        ),
      ),
    );
  }
}
