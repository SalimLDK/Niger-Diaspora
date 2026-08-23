import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'package:diaspo_niger/core/utils/mention_handle.dart';
import 'package:diaspo_niger/core/utils/rich_text_parser.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../domain/entities/comment_entity.dart';
import '../theme/feed_tokens.dart';
import 'feed_avatar.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';

String _formatTimeAgo(DateTime dt, BuildContext context) {
  final locale = Localizations.localeOf(context).languageCode;
  if (locale == 'fr') {
    timeago.setLocaleMessages('fr', timeago.FrMessages());
    return timeago.format(dt, locale: 'fr');
  }
  return timeago.format(dt);
}

/// Affiche un commentaire (racine ou réponse). Les réponses elles-mêmes sont
/// rendues par l'écran de détail ; ce widget expose seulement le toggle
/// « voir N réponses » via [onToggleReplies].
class CommentTile extends ConsumerWidget {
  final CommentEntity comment;
  final String currentUserId;
  final void Function(String commentId)? onDelete;

  /// true pour une réponse (avatar réduit + indentation).
  final bool isReply;
  final bool isLiked;
  final VoidCallback? onToggleLike;
  final VoidCallback? onReply;

  /// Toggle d'affichage des réponses (affiché si le commentaire a des réponses).
  final bool repliesExpanded;
  final VoidCallback? onToggleReplies;

  const CommentTile({
    super.key,
    required this.comment,
    required this.currentUserId,
    this.onDelete,
    this.isReply = false,
    this.isLiked = false,
    this.onToggleLike,
    this.onReply,
    this.repliesExpanded = false,
    this.onToggleReplies,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final tokens = FeedTokens.of(context);
    final isOwner = comment.authorId == currentUserId;
    // Réponse : avatar réduit à 30 px (r15), indentées à 42 px (§13).
    final avatarRadius = isReply ? 15.0 : 16.0;
    final isDeletedAuthor = comment.authorName.trim().isEmpty;
    final authorHandle =
        isDeletedAuthor
            ? null
            : ref
                .watch(profileNotifierProvider(comment.authorId))
                .valueOrNull
                ?.handle;
    final metaLine =
        (authorHandle != null && authorHandle.isNotEmpty)
            ? '@$authorHandle · ${_formatTimeAgo(comment.createdAt, context)}'
            : _formatTimeAgo(comment.createdAt, context);

    return Padding(
      padding: EdgeInsets.only(
        left: isReply ? 42 : 12,
        right: 12,
        top: 8,
        bottom: 8,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FeedAvatar(
            name: isDeletedAuthor ? '?' : comment.authorName,
            photoUrl: comment.authorPhotoUrl,
            radius: avatarRadius,
            tokens: tokens,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        isDeletedAuthor ? l10n.deletedUser : comment.authorName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        metaLine,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: tokens.mutedText),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                RichTextWidget(
                  text: comment.content,
                  mentionColor: tokens.hashtagColor,
                  hashtagColor: tokens.hashtagColor,
                  onMentionTap: (handle, _) {
                    // Même repli que dans post_card : un commentaire ancien
                    // porte le pseudo ASCII, un récent le pseudo accentué.
                    final uid = comment.mentionedUsers
                        .where((m) => mentionHandleMatches(m.name, handle))
                        .map((m) => m.id)
                        .firstOrNull;
                    if (uid != null) context.push('/profile/$uid');
                  },
                  onHashtagTap: (tag) => context.push('/feed?hashtag=$tag'),
                ),
                _ActionRow(
                  l10n: l10n,
                  isLiked: isLiked,
                  likeCount: comment.likeCount,
                  onToggleLike: onToggleLike,
                  onReply: onReply,
                ),
                if (!isReply && comment.replyCount > 0 && onToggleReplies != null)
                  GestureDetector(
                    onTap: onToggleReplies,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        repliesExpanded
                            ? l10n.hideReplies
                            : l10n.viewReplies(comment.replyCount),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: tokens.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (isOwner && onDelete != null)
            IconButton(
              icon: AppIcon(AppIcon.delete, color: isLiked ? tokens.accent : tokens.mutedText, size: 16),
              color: tokens.mutedText,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(l10n.deleteComment),
                    content: Text(l10n.confirmDeleteComment),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(l10n.cancel),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(
                          l10n.delete,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) onDelete!(comment.id);
              },
            ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final AppLocalizations l10n;
  final bool isLiked;
  final int likeCount;
  final VoidCallback? onToggleLike;
  final VoidCallback? onReply;

  const _ActionRow({
    required this.l10n,
    required this.isLiked,
    required this.likeCount,
    required this.onToggleLike,
    required this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = FeedTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          if (onToggleLike != null)
            InkWell(
              onTap: onToggleLike,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, anim) =>
                          ScaleTransition(scale: anim, child: child),
                      child:
                          isLiked
                              ? AppIcon(
                                AppIcon.heart,
                                key: ValueKey<bool>(isLiked),
                                size: 15,
                                color: tokens.accent,
                              )
                              : AppIcon(
                                AppIcon.favoriteBorder,
                                key: ValueKey<bool>(isLiked),
                                size: 15,
                                color: tokens.mutedText,
                              ),
                    ),
                    const SizedBox(width: 4),
                    // Action nommée « J'aime · 4 » plutôt qu'un simple nombre.
                    Text(
                      likeCount > 0 ? '${l10n.likes} · $likeCount' : l10n.likes,
                      style: TextStyle(
                        color: isLiked ? tokens.accent : tokens.mutedText,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (onReply != null) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: onReply,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  l10n.reply,
                  style: TextStyle(
                    color: tokens.mutedText,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
