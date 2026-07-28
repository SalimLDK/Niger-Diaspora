import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../../shared/widgets/app_icon.dart';
import '../../domain/entities/review_entity.dart';
import 'star_rating_input.dart';

class ReviewCard extends StatelessWidget {
  final ReviewEntity review;
  final bool isOwner;
  final bool hasMarkedHelpful;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onMarkHelpful;
  final VoidCallback? onReport;
  final VoidCallback? onImageTap;

  /// Vrai si l'utilisateur courant est le gérant de l'entreprise : il peut
  /// alors répondre à l'avis (§18c).
  final bool canReply;
  final VoidCallback? onReply;

  const ReviewCard({
    super.key,
    required this.review,
    this.isOwner = false,
    this.hasMarkedHelpful = false,
    this.onEdit,
    this.onDelete,
    this.onMarkHelpful,
    this.onReport,
    this.onImageTap,
    this.canReply = false,
    this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User info row
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: review.userPhotoUrl != null
                      ? CachedNetworkImageProvider(review.userPhotoUrl!)
                      : null,
                  child: review.userPhotoUrl == null
                      ? Text(
                          review.userDisplayName.isNotEmpty
                              ? review.userDisplayName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.userDisplayName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (review.createdAt != null)
                        Text(
                          dateFormat.format(review.createdAt!),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                    ],
                  ),
                ),
                // Menu for owner or report for others
                if (isOwner)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) {
                      if (value == 'edit') onEdit?.call();
                      if (value == 'delete') onDelete?.call();
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 20),
                            SizedBox(width: 8),
                            Text('Modifier'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            AppIcon(AppIcon.delete, size: 20, color: Colors.red),
                            const SizedBox(width: 8),
                            const Text('Supprimer', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  )
                else if (onReport != null)
                  IconButton(
                    icon: const AppIcon(AppIcon.flag, size: 20),
                    onPressed: onReport,
                    tooltip: 'Signaler',
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Star rating
            StarRatingDisplay(
              rating: review.rating.toDouble(),
              size: 18,
              showValue: false,
            ),
            const SizedBox(height: 8),

            // Title if present
            if (review.title != null && review.title!.isNotEmpty) ...[
              Text(
                review.title!,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
            ],

            // Content
            Text(
              review.content,
              style: theme.textTheme.bodyMedium,
            ),

            // Images if present
            if (review.imageUrls.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: review.imageUrls.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: onImageTap,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: review.imageUrls[index],
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              width: 80,
                              height: 80,
                              color: theme.colorScheme.surfaceContainerHighest,
                              child: const Center(
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              width: 80,
                              height: 80,
                              color: theme.colorScheme.surfaceContainerHighest,
                              child: const AppIcon(AppIcon.error),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],

            // Réponse du gérant en encart bordé à gauche (§18c)
            if (review.ownerReply != null &&
                review.ownerReply!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border(
                    left: BorderSide(color: theme.colorScheme.primary, width: 3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.storefront_outlined,
                          size: 15,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Réponse du gérant',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (review.ownerReplyAt != null) ...[
                          const Spacer(),
                          Text(
                            dateFormat.format(review.ownerReplyAt!),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(review.ownerReply!, style: theme.textTheme.bodyMedium),
                    if (canReply && onReply != null) ...[
                      const SizedBox(height: 2),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: onReply,
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 32),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Modifier la réponse'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ] else if (canReply && onReply != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: onReply,
                  icon: const Icon(Icons.reply, size: 18),
                  label: const Text('Répondre'),
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Helpful button
            Row(
              children: [
                TextButton.icon(
                  onPressed: onMarkHelpful,
                  icon: Icon(
                    hasMarkedHelpful ? Icons.thumb_up : Icons.thumb_up_outlined,
                    size: 18,
                    color: hasMarkedHelpful ? theme.colorScheme.primary : null,
                  ),
                  label: Text(
                    review.helpfulCount > 0
                        ? 'Utile (${review.helpfulCount})'
                        : 'Utile',
                    style: TextStyle(
                      color: hasMarkedHelpful ? theme.colorScheme.primary : null,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
