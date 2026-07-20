import 'package:flutter/material.dart';

import 'package:diaspo_niger/shared/widgets/shimmer_loading.dart';

/// Skeleton de chargement qui imite la structure réelle d'une [PostCard]
/// (avatar + nom, lignes de contenu, bloc média, barre d'actions).
///
/// Tout l'arbre est enveloppé dans un seul [ShimmerLoading] pour qu'un balayage
/// cohérent traverse la carte. Les blocs sont de simples conteneurs colorés
/// (et non des [ShimmerLine], qui réanimeraient chacun de leur côté).
class PostCardSkeleton extends StatelessWidget {
  const PostCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final box = theme.colorScheme.surfaceContainerHighest;

    Widget bar({double? width, double height = 12, double radius = 4}) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: box,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: ShimmerLoading(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: box, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      bar(width: 120, height: 12),
                      const SizedBox(height: 6),
                      bar(width: 80, height: 10),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              bar(height: 12),
              const SizedBox(height: 8),
              bar(width: 220, height: 12),
              const SizedBox(height: 12),
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: box,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  bar(width: 48, height: 14),
                  const SizedBox(width: 16),
                  bar(width: 48, height: 14),
                  const SizedBox(width: 16),
                  bar(width: 24, height: 14),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Liste défilante de [PostCardSkeleton], utilisée comme état de chargement
/// plein écran du feed. Reprend le padding vertical (8) du vrai feed.
class PostCardListSkeleton extends StatelessWidget {
  final int itemCount;

  const PostCardListSkeleton({super.key, this.itemCount = 5});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: itemCount,
      itemBuilder: (_, __) => const PostCardSkeleton(),
    );
  }
}
