import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:diaspo_niger/core/utils/rich_text_parser.dart';
import '../../domain/entities/post_entity.dart';
import '../../domain/entities/repost_ref.dart';
import '../providers/feed_personalization_provider.dart';
import '../providers/feed_provider.dart';
import '../theme/feed_tokens.dart';
import 'feed_avatar.dart';
import 'feed_image_viewer.dart';
import 'follow_button.dart';
import 'feed_toast.dart';
import 'feed_video_player.dart';
import 'heart_burst_overlay.dart';
import 'share_post_sheet.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';

String _formatTimeAgo(DateTime dt, BuildContext context) {
  final locale = Localizations.localeOf(context).languageCode;
  if (locale == 'fr') {
    timeago.setLocaleMessages('fr', timeago.FrMessages());
    return timeago.format(dt, locale: 'fr');
  }
  return timeago.format(dt);
}

class PostCard extends ConsumerWidget {
  final PostEntity post;
  final bool isDetail;

  /// Si non-null, affiche le bandeau « X a repartagé » au-dessus de la carte.
  final RepostRef? repost;

  const PostCard({
    super.key,
    required this.post,
    this.isDetail = false,
    this.repost,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final tokens = FeedTokens.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(tokens.cardRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isDetail
            ? null
            : () => context.push('/feed/${post.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (repost != null) _RepostBanner(repost: repost!),
              _PostHeader(post: post, l10n: l10n),
              if (post.content.isNotEmpty) ...[
                const SizedBox(height: 10),
                RichTextWidget(
                  text: post.content,
                  style: theme.textTheme.bodyMedium,
                  mentionColor: tokens.hashtagColor,
                  hashtagColor: tokens.hashtagColor,
                  onMentionTap: (handle, _) {
                    final uid = post.mentionedUsers
                        .where((m) => m.name == handle)
                        .map((m) => m.id)
                        .firstOrNull;
                    if (uid != null) context.push('/profile/$uid');
                  },
                  onHashtagTap: (tag) => context.push('/feed?hashtag=$tag'),
                ),
              ],
              if (post.mediaUrls.isNotEmpty) ...[
                const SizedBox(height: 10),
                _MediaGrid(post: post),
              ],
              if (isDetail) ...[
                const SizedBox(height: 8),
                Divider(height: 1, color: tokens.divider),
              ],
              const SizedBox(height: 4),
              _ActionBar(post: post, l10n: l10n, isDetail: isDetail),
              if (isDetail) ...[
                const SizedBox(height: 4),
                Divider(height: 1, color: tokens.divider),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RepostBanner extends StatelessWidget {
  final RepostRef repost;

  const _RepostBanner({required this.repost});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = FeedTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.repeat_rounded, size: 14, color: tokens.mutedText),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${repost.reposterName} a repartagé',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: tokens.mutedText,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (repost.hasComment) ...[
          const SizedBox(height: 6),
          Text(repost.comment!, style: theme.textTheme.bodyMedium),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}

class _PostHeader extends StatelessWidget {
  final PostEntity post;
  final AppLocalizations l10n;

  const _PostHeader({required this.post, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final tokens = FeedTokens.of(context);
    final isAuthor = FirebaseAuth.instance.currentUser?.uid == post.authorId;
    // Auteur au compte effacé : nom vide dénormalisé — affichage neutre,
    // pas de navigation profil ni de bouton suivre.
    final isDeletedAuthor = post.authorName.trim().isEmpty;
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: isDeletedAuthor
                ? null
                : () => context.push('/profile/${post.authorId}'),
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                FeedAvatar(
                    name: isDeletedAuthor ? '?' : post.authorName,
                    photoUrl: post.authorPhotoUrl,
                    tokens: tokens),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isDeletedAuthor ? l10n.deletedUser : post.authorName,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        _formatTimeAgo(post.createdAt, context),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: tokens.mutedText),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!isAuthor && !isDeletedAuthor) ...[
          const SizedBox(width: 8),
          FollowButton(targetUserId: post.authorId),
        ],
        _PostMenu(post: post, l10n: l10n),
      ],
    );
  }
}

class _PostMenu extends ConsumerWidget {
  final PostEntity post;
  final AppLocalizations l10n;

  const _PostMenu({required this.post, required this.l10n});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isAuthor = currentUserId != null && currentUserId == post.authorId;
    final isBookmarked = ref.watch(
      feedNotifierProvider.select((s) => s.bookmarkedPostIds.contains(post.id)),
    );

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_horiz),
      onSelected: (value) async {
        if (value == 'delete') {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(l10n.deletePost),
              content: Text(l10n.confirmDeletePost),
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
          if (confirmed == true && context.mounted) {
            await ref.read(feedNotifierProvider.notifier).deletePost(post.id);
            if (context.mounted && context.canPop()) context.pop();
          }
        } else if (value == 'bookmark') {
          ref.read(feedNotifierProvider.notifier).toggleBookmark(post.id);
        } else if (value == 'edit') {
          context.push('/feed/${post.id}/edit', extra: post);
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'bookmark',
          child: Row(
            children: [
              Icon(
                isBookmarked ? Icons.bookmark : Icons.bookmark_outline,
                color: isBookmarked ? FeedTokens.of(context).accent : null,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                isBookmarked ? 'Retirer le signet' : 'Sauvegarder',
              ),
            ],
          ),
        ),
        if (isAuthor)
          PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                const Icon(Icons.edit_outlined, size: 18),
                const SizedBox(width: 8),
                Text(l10n.editPost),
              ],
            ),
          ),
        if (isAuthor)
          PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                const AppIcon(AppIcon.delete, color: Colors.red, size: 18),
                const SizedBox(width: 8),
                Text(l10n.deletePost, style: const TextStyle(color: Colors.red)),
              ],
            ),
          ),
      ],
    );
  }
}

class _MediaGrid extends ConsumerStatefulWidget {
  final PostEntity post;

  const _MediaGrid({required this.post});

  @override
  ConsumerState<_MediaGrid> createState() => _MediaGridState();
}

class _MediaGridState extends ConsumerState<_MediaGrid> {
  final _heartKey = GlobalKey<HeartBurstState>();

  void _handleDoubleTap() {
    final post = widget.post;
    // Sémantique Instagram : double-tap ne fait que liker, jamais dé-liker.
    final liked = ref.read(feedNotifierProvider).likedPostIds.contains(post.id);
    _heartKey.currentState?.play();
    if (!liked) {
      ref.read(feedNotifierProvider.notifier).toggleLike(post.id);
      if (post.hashtags.isNotEmpty) {
        recordHashtagInteraction(post.hashtags);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaUrls = widget.post.mediaUrls;
    if (widget.post.mediaType == PostMediaType.video && mediaUrls.isNotEmpty) {
      return FeedVideoPlayer(
        videoUrl: mediaUrls.first,
        thumbnailUrl: widget.post.videoThumbnailUrl,
        durationSeconds: widget.post.videoDurationSeconds,
        postId: widget.post.id,
      );
    }
    return Stack(
      alignment: Alignment.center,
      children: [
        if (mediaUrls.length == 1)
          _image(mediaUrls, 0, height: 200, width: double.infinity)
        else
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
            children: [
              for (var i = 0; i < mediaUrls.take(4).length; i++)
                _image(mediaUrls, i),
            ],
          ),
        Positioned.fill(child: HeartBurst(key: _heartKey)),
      ],
    );
  }

  Widget _image(
    List<String> mediaUrls,
    int index, {
    double? height,
    double? width,
  }) {
    return GestureDetector(
      onTap: () => FeedImageViewer.show(
        context,
        mediaUrls: mediaUrls,
        initialIndex: index,
        heroTagPrefix: widget.post.id,
      ),
      onDoubleTap: _handleDoubleTap,
      child: Hero(
        tag: '${widget.post.id}_$index',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(FeedTokens.of(context).radiusMd),
          child: CachedNetworkImage(
            imageUrl: mediaUrls[index],
            height: height,
            width: width,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

class _ActionBar extends ConsumerWidget {
  final PostEntity post;
  final AppLocalizations l10n;
  final bool isDetail;

  const _ActionBar({required this.post, required this.l10n, this.isDetail = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = FeedTokens.of(context);
    final isLiked = ref.watch(
      feedNotifierProvider.select((s) => s.likedPostIds.contains(post.id)),
    );
    final isBookmarked = ref.watch(
      feedNotifierProvider.select((s) => s.bookmarkedPostIds.contains(post.id)),
    );
    final isReposted = ref.watch(
      feedNotifierProvider.select((s) => s.repostedPostIds.contains(post.id)),
    );

    return Row(
      children: [
        _ActionButton(
          icon: isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          iconColor: isLiked ? tokens.accent : null,
          label: post.likeCount > 0 ? '${post.likeCount}' : '',
          onTap: () {
            ref.read(feedNotifierProvider.notifier).toggleLike(post.id);
            if (post.hashtags.isNotEmpty) {
              recordHashtagInteraction(post.hashtags);
            }
          },
        ),
        const SizedBox(width: 8),
        _ActionButton(
          icon: Icons.chat_bubble_outline_rounded,
          label: post.commentCount > 0 ? '${post.commentCount}' : '',
          onTap: isDetail ? null : () => context.push('/feed/${post.id}'),
        ),
        if (!isDetail) ...[
          const SizedBox(width: 8),
          _ActionButton(
            icon: Icons.repeat_rounded,
            iconColor: isReposted ? tokens.accent2 : null,
            label: post.shareCount > 0 ? '${post.shareCount}' : '',
            onTap: () => _showRepostSheet(context, ref, post, isReposted),
          ),
        ],
        const Spacer(),
        if (!isDetail) ...[
          _ActionButton(
            icon: Icons.send_outlined,
            label: '',
            onTap: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Theme.of(context).colorScheme.surface,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              builder: (_) => SharePostSheet(post: post),
            ),
          ),
          const SizedBox(width: 8),
        ],
        _ActionButton(
          icon: isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
          iconColor: isBookmarked ? tokens.accent : null,
          label: '',
          onTap: () {
            final willBeSaved = !isBookmarked;
            ref.read(feedNotifierProvider.notifier).toggleBookmark(post.id);
            showFeedToast(
              context,
              willBeSaved ? 'Publication enregistrée' : 'Retiré des enregistrements',
            );
          },
        ),
      ],
    );
  }
}

/// Feuille d'actions de repartage : repost simple (toggle) ou avec citation.
void _showRepostSheet(
  BuildContext context,
  WidgetRef ref,
  PostEntity post,
  bool isReposted,
) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                Icons.repeat_rounded,
                color: isReposted ? Colors.green : null,
              ),
              title: Text(isReposted ? 'Annuler le repartage' : 'Reposter'),
              onTap: () {
                Navigator.pop(sheetContext);
                ref.read(feedNotifierProvider.notifier).toggleRepost(post.id);
              },
            ),
            ListTile(
              leading: const Icon(Icons.format_quote_rounded),
              title: const Text('Reposter avec commentaire'),
              onTap: () {
                Navigator.pop(sheetContext);
                _showQuoteDialog(context, ref, post);
              },
            ),
          ],
        ),
      );
    },
  );
}

void _showQuoteDialog(BuildContext context, WidgetRef ref, PostEntity post) {
  final controller = TextEditingController();
  showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Reposter avec commentaire'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 3,
              maxLength: 280,
              decoration: const InputDecoration(
                hintText: 'Ajoutez votre commentaire…',
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${post.authorName} · ${post.content}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              Navigator.pop(dialogContext);
              final notifier = ref.read(feedNotifierProvider.notifier);
              if (text.isEmpty) {
                notifier.toggleRepost(post.id);
              } else {
                notifier.repostWithComment(post.id, text);
              }
            },
            child: const Text('Reposter'),
          ),
        ],
      );
    },
  );
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? iconColor;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? FeedTokens.of(context).mutedText;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: Icon(
                icon,
                key: ValueKey<String>(
                  '${icon.codePoint}_${color.toARGB32()}',
                ),
                size: 18,
                color: color,
              ),
            ),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(label, style: TextStyle(color: color, fontSize: 13)),
            ],
          ],
        ),
      ),
    );
  }
}
