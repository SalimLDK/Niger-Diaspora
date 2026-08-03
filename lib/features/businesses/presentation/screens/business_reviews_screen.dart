import 'package:flutter/material.dart';
import '../../../../core/theme/design_kit.dart';
import '../../../../core/theme/adaptive_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/widgets/app_icon.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/business_entity.dart';
import '../../domain/entities/review_entity.dart';
import '../providers/review_provider.dart';
import '../widgets/review_card.dart';
import '../widgets/review_form_modal.dart';
import '../widgets/star_rating_input.dart';

class BusinessReviewsScreen extends ConsumerWidget {
  final String businessId;
  final BusinessEntity? business;

  const BusinessReviewsScreen({
    super.key,
    required this.businessId,
    this.business,
  });

  void _showReviewForm(BuildContext context, WidgetRef ref, {ReviewEntity? existingReview}) {
    final currentUser = ref.read(currentUserProvider).valueOrNull;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vous devez etre connecte pour laisser un avis')),
      );
      return;
    }

    ReviewFormModal.show(
      context,
      businessId: businessId,
      userId: currentUser.id,
      userDisplayName: currentUser.displayName ?? 'Utilisateur',
      userPhotoUrl: currentUser.photoUrl,
      existingReview: existingReview,
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, ReviewEntity review) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer l\'avis'),
        content: const Text('Voulez-vous vraiment supprimer cet avis ? Cette action est irreversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await ref
                  .read(reviewActionsNotifierProvider.notifier)
                  .deleteReview(review.id, businessId);
              if (context.mounted && success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Avis supprime')),
                );
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  /// Réponse du gérant à un avis (§18c) — réutilise updateReview.
  void _showReplyDialog(BuildContext context, WidgetRef ref, ReviewEntity review) {
    final controller = TextEditingController(text: review.ownerReply ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Répondre à l\'avis'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          maxLength: 500,
          decoration: const InputDecoration(
            hintText: 'Votre réponse en tant que gérant…',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () async {
              final text = controller.text.trim();
              Navigator.pop(ctx);
              final updated = review.copyWith(
                ownerReply: text.isEmpty ? null : text,
                ownerReplyAt: text.isEmpty ? null : DateTime.now(),
              );
              final ok = await ref
                  .read(reviewActionsNotifierProvider.notifier)
                  .updateReview(updated);
              if (ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      text.isEmpty ? 'Réponse supprimée' : 'Réponse publiée',
                    ),
                  ),
                );
              }
            },
            child: const Text('Publier'),
          ),
        ],
      ),
    );
  }

  void _showReportDialog(BuildContext context, WidgetRef ref, String reviewId) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Signaler cet avis'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Raison du signalement',
            hintText: 'Pourquoi signalez-vous cet avis ?',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Veuillez indiquer une raison')),
                );
                return;
              }
              Navigator.pop(context);
              final success = await ref
                  .read(reviewActionsNotifierProvider.notifier)
                  .reportReview(reviewId, reasonController.text.trim(), businessId);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Avis signale' : 'Erreur lors du signalement'),
                  ),
                );
              }
            },
            child: const Text('Signaler'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final reviewsAsync = ref.watch(businessReviewsNotifierProvider(businessId));
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final userReviewAsync = ref.watch(userBusinessReviewNotifierProvider(businessId));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: context.backgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: DesignTitle(business?.name ?? 'Avis', size: 22),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref
            .read(businessReviewsNotifierProvider(businessId).notifier)
            .refresh(businessId),
        child: reviewsAsync.when(
          data: (reviews) {
            if (reviews.isEmpty) {
              return _EmptyState(
                onWriteReview: () => _showReviewForm(context, ref),
              );
            }

            return CustomScrollView(
              slivers: [
                // Stats header
                SliverToBoxAdapter(
                  child: _ReviewsHeader(
                    reviews: reviews,
                    business: business,
                  ),
                ),

                // User's existing review notice
                if (userReviewAsync.valueOrNull != null)
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          AppIcon(
                            AppIcon.checkCircle,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Vous avez deja laisse un avis',
                              style: TextStyle(color: theme.colorScheme.primary),
                            ),
                          ),
                          TextButton(
                            onPressed: () => _showReviewForm(
                              context,
                              ref,
                              existingReview: userReviewAsync.valueOrNull,
                            ),
                            child: const Text('Modifier'),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Reviews list
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final review = reviews[index];
                        final isOwner = currentUser?.id == review.userId;
                        final hasMarkedHelpful = review.helpfulByUserIds.contains(currentUser?.id);
                        final isBusinessOwner = business != null &&
                            currentUser?.id == business!.ownerId;

                        return ReviewCard(
                          review: review,
                          isOwner: isOwner,
                          hasMarkedHelpful: hasMarkedHelpful,
                          onEdit: isOwner
                              ? () => _showReviewForm(context, ref, existingReview: review)
                              : null,
                          onDelete: isOwner
                              ? () => _confirmDelete(context, ref, review)
                              : null,
                          onMarkHelpful: currentUser != null && !isOwner
                              ? () => ref
                                  .read(reviewActionsNotifierProvider.notifier)
                                  .toggleHelpful(review.id, businessId, hasMarkedHelpful)
                              : null,
                          onReport: currentUser != null && !isOwner
                              ? () => _showReportDialog(context, ref, review.id)
                              : null,
                          // Le gérant de l'entreprise peut répondre (§18c).
                          canReply: isBusinessOwner,
                          onReply: isBusinessOwner
                              ? () => _showReplyDialog(context, ref, review)
                              : null,
                        );
                      },
                      childCount: reviews.length,
                    ),
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _ErrorState(
            error: error.toString(),
            onRetry: () => ref
                .read(businessReviewsNotifierProvider(businessId).notifier)
                .refresh(businessId),
          ),
        ),
      ),
      floatingActionButton: userReviewAsync.valueOrNull == null
          ? FloatingActionButton.extended(
              onPressed: () => _showReviewForm(context, ref),
              icon: const Icon(Icons.edit),
              label: const Text('Ecrire un avis'),
            )
          : null,
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onWriteReview;

  const _EmptyState({required this.onWriteReview});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.rate_review_outlined,
              size: 80,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 24),
            Text(
              'Aucun avis pour le moment',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Soyez le premier a partager votre experience !',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onWriteReview,
              icon: const Icon(Icons.edit),
              label: const Text('Ecrire un avis'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppIcon(
              AppIcon.error,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Erreur de chargement',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const AppIcon(AppIcon.refresh),
              label: const Text('Reessayer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewsHeader extends StatelessWidget {
  final List<ReviewEntity> reviews;
  final BusinessEntity? business;

  const _ReviewsHeader({required this.reviews, this.business});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Calculate stats
    final totalReviews = reviews.length;
    final averageRating = business?.averageRating ??
        (reviews.isNotEmpty
            ? reviews.map((r) => r.rating).reduce((a, b) => a + b) / totalReviews
            : 0.0);

    // Rating distribution
    final ratingCounts = List.generate(5, (i) {
      return reviews.where((r) => r.rating == i + 1).length;
    });

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Average rating
              Column(
                children: [
                  Text(
                    averageRating.toStringAsFixed(1),
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  StarRatingDisplay(
                    rating: averageRating,
                    size: 20,
                    showValue: false,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$totalReviews avis',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 32),
              // Distribution bars
              Expanded(
                child: Column(
                  children: List.generate(5, (i) {
                    final starNum = 5 - i;
                    final count = ratingCounts[starNum - 1];
                    final percentage = totalReviews > 0 ? count / totalReviews : 0.0;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Text(
                            '$starNum',
                            style: theme.textTheme.bodySmall,
                          ),
                          const AppIcon(AppIcon.star, size: 12, color: Colors.amber),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: percentage,
                                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                minHeight: 8,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 24,
                            child: Text(
                              '$count',
                              style: theme.textTheme.bodySmall,
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
        ],
      ),
    );
  }
}
