import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/rich_text_parser.dart';
import '../../domain/entities/post_draft.dart';
import '../../domain/entities/post_entity.dart';
import '../providers/feed_provider.dart';
import '../theme/feed_text.dart';
import '../theme/feed_tokens.dart';

/// Rayon de la vignette média 56×56 (détail interne de la carte, pas une
/// forme partagée — d'où la constante locale).
const double _thumbRadiusLight = 14;

/// Carte d'une publication à soi (fiche 5b) : pas d'en-tête d'auteur — la
/// liste ne contient que ses propres posts —, une ligne de méta, le corps,
/// une vignette média à droite, puis la barre d'engagement avec « Modifier ».
class MyPostCard extends ConsumerWidget {
  final PostEntity post;
  final VoidCallback onEdit;
  final VoidCallback onMore;

  const MyPostCard({
    super.key,
    required this.post,
    required this.onEdit,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = FeedTokens.of(context);
    final isLiked = ref.watch(
      feedNotifierProvider.select((s) => s.likedPostIds.contains(post.id)),
    );
    final thumbUrl =
        post.mediaType == PostMediaType.video
            ? post.videoThumbnailUrl
            : (post.mediaUrls.isNotEmpty ? post.mediaUrls.first : null);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(tokens.compactCardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      // Toutes les publications sont publiques : le modèle
                      // n'a pas de portée. Afficher « Abonnés » comme la
                      // maquette serait inventer une audience qui n'existe pas.
                      '${DateFormatter.formatPostMeta(post.createdAt)} · Public',
                      style: FeedText.body(
                        tokens,
                        size: 12,
                        color: tokens.mutedText,
                      ),
                    ),
                    const SizedBox(height: 5),
                    RichTextWidget(
                      text: post.content,
                      style: FeedText.body(
                        tokens,
                        size: 14.5,
                        color: tokens.textStrong,
                      ).copyWith(height: 1.5),
                      mentionColor: tokens.hashtagColor,
                      hashtagColor: tokens.hashtagColor,
                      onHashtagTap: (tag) => context.push('/feed?hashtag=$tag'),
                    ),
                  ],
                ),
              ),
              if (thumbUrl != null) ...[
                const SizedBox(width: 10),
                _Thumbnail(tokens: tokens, url: thumbUrl),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, thickness: 1, color: tokens.hairline),
          const SizedBox(height: 10),
          Row(
            children: [
              _Metric(
                tokens: tokens,
                icon: isLiked ? Icons.favorite : Icons.favorite_border,
                iconColor: isLiked ? tokens.accent : tokens.actionLabel,
                value: post.likeCount,
                emphasised: isLiked,
              ),
              const SizedBox(width: 14),
              _Metric(
                tokens: tokens,
                icon: Icons.chat_bubble_outline_rounded,
                iconColor: tokens.actionLabel,
                value: post.commentCount,
              ),
              // La maquette n'affiche la ligne de repartage que lorsqu'il y en
              // a (le post 2 de la fiche n'en a aucun et l'icône disparaît).
              if (post.shareCount > 0) ...[
                const SizedBox(width: 14),
                _Metric(
                  tokens: tokens,
                  icon: Icons.repeat_rounded,
                  iconColor: tokens.actionLabel,
                  value: post.shareCount,
                ),
              ],
              const Spacer(),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onEdit,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'Modifier',
                    style: FeedText.body(
                      tokens,
                      size: 12.5,
                      weight: FontWeight.w600,
                      color: tokens.accent,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onMore,
                child: Icon(
                  Icons.more_horiz,
                  size: 20,
                  color: tokens.mutedText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final FeedTokens tokens;
  final String url;

  const _Thumbnail({required this.tokens, required this.url});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(
        tokens.isDark ? tokens.radiusSm : _thumbRadiusLight,
      ),
      child: CachedNetworkImage(
        imageUrl: url,
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(width: 56, height: 56, color: tokens.bg),
        errorWidget:
            (_, __, ___) => Container(
              width: 56,
              height: 56,
              color: tokens.bg,
              child: Icon(
                Icons.image_outlined,
                size: 20,
                color: tokens.mutedText,
              ),
            ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final FeedTokens tokens;
  final IconData icon;
  final Color iconColor;
  final int value;
  final bool emphasised;

  const _Metric({
    required this.tokens,
    required this.icon,
    required this.iconColor,
    required this.value,
    this.emphasised = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 5),
        Text(
          '$value',
          style: FeedText.body(
            tokens,
            size: 12.5,
            weight: emphasised ? FontWeight.w600 : FontWeight.w500,
            color: tokens.actionLabel,
          ),
        ),
      ],
    );
  }
}

/// Carte d'un brouillon local dans la liste (fiche 5b) : voilée à 75 %,
/// badge « BROUILLON », et les deux actions Reprendre / Supprimer.
class MyDraftCard extends StatelessWidget {
  final PostDraft draft;
  final VoidCallback onResume;
  final VoidCallback onDelete;

  const MyDraftCard({
    super.key,
    required this.draft,
    required this.onResume,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = FeedTokens.of(context);

    return Opacity(
      opacity: 0.75,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(tokens.compactCardRadius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.drafts_rounded, size: 14, color: tokens.mutedText),
                const SizedBox(width: 7),
                Text(
                  'BROUILLON',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.66,
                    color: tokens.mutedText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              draft.preview(),
              style: FeedText.body(
                tokens,
                size: 14.5,
                color: tokens.textStrong,
              ).copyWith(height: 1.5),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Divider(height: 1, thickness: 1, color: tokens.hairline),
            const SizedBox(height: 10),
            Row(
              children: [
                _DraftAction(
                  tokens: tokens,
                  label: 'Reprendre',
                  filled: true,
                  onTap: onResume,
                ),
                const SizedBox(width: 10),
                _DraftAction(
                  tokens: tokens,
                  label: 'Supprimer',
                  filled: false,
                  onTap: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DraftAction extends StatelessWidget {
  final FeedTokens tokens;
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _DraftAction({
    required this.tokens,
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(tokens.isDark ? tokens.radiusSm : 11);
    return InkWell(
      borderRadius: radius,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: filled ? tokens.accent : Colors.transparent,
          borderRadius: radius,
          border: filled ? null : Border.all(color: tokens.divider),
        ),
        child: Text(
          label,
          style: FeedText.body(
            tokens,
            size: 12.5,
            weight: FontWeight.w600,
            color: filled ? tokens.onAccent : tokens.actionLabel,
          ),
        ),
      ),
    );
  }
}
