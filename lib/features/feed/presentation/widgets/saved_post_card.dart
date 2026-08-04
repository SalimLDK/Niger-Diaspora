import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:diaspo_niger/shared/widgets/app_icon.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../domain/entities/post_entity.dart';
import '../theme/feed_text.dart';
import '../theme/feed_tokens.dart';

/// Carte d'un post enregistré (fiche 5c) : vignette 72×72 à gauche, ligne
/// d'auteur, texte clampé à deux lignes, puis « Retirer » / « Partager ».
///
/// Distincte de la carte du fil : ici on survole une liste de rappels, pas un
/// flux — d'où le format court et les deux seules actions utiles.
class SavedPostCard extends StatelessWidget {
  final PostEntity post;
  final VoidCallback onRemove;
  final VoidCallback onShare;

  const SavedPostCard({
    super.key,
    required this.post,
    required this.onRemove,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = FeedTokens.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(tokens.compactCardRadius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Preview(tokens: tokens, post: post),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AuthorLine(tokens: tokens, post: post),
                const SizedBox(height: 6),
                Text(
                  post.content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: FeedText.body(
                    tokens,
                    size: 14,
                    color: tokens.textStrong,
                  ).copyWith(height: 1.45),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _Action(
                      tokens: tokens,
                      label: 'Retirer',
                      color: tokens.accent,
                      weight: FontWeight.w600,
                      onTap: onRemove,
                    ),
                    const SizedBox(width: 12),
                    _Action(
                      tokens: tokens,
                      label: 'Partager',
                      color: tokens.actionLabel,
                      weight: FontWeight.w500,
                      onTap: onShare,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Vignette 72×72 : le média s'il y en a un, sinon une pastille au glyphe du
/// type de contenu (sondage, lieu, texte).
class _Preview extends StatelessWidget {
  final FeedTokens tokens;
  final PostEntity post;

  const _Preview({required this.tokens, required this.post});

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(
      tokens.isDark ? tokens.radiusMd : 16,
    );
    final url =
        post.mediaType == PostMediaType.video
            ? post.videoThumbnailUrl
            : (post.mediaUrls.isNotEmpty ? post.mediaUrls.first : null);

    if (url != null && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: radius,
        child: CachedNetworkImage(
          imageUrl: url,
          width: 72,
          height: 72,
          fit: BoxFit.cover,
          placeholder: (_, __) => _placeholder(radius, null),
          errorWidget: (_, __, ___) => _placeholder(radius, AppIcon.image),
        ),
      );
    }

    return _placeholder(
      radius,
      post.hasLocation ? AppIcon.location : null,
      iconColor: post.hasLocation ? tokens.accent2 : tokens.mutedText,
      fallback: post.hasLocation ? null : Icons.notes_rounded,
    );
  }

  Widget _placeholder(
    BorderRadius radius,
    String? svgIcon, {
    Color? iconColor,
    IconData? fallback,
  }) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(color: tokens.bg, borderRadius: radius),
      alignment: Alignment.center,
      child:
          svgIcon != null
              ? AppIcon(svgIcon, size: 24, color: iconColor ?? tokens.mutedText)
              : Icon(
                fallback ?? Icons.image_outlined,
                size: 24,
                color: iconColor ?? tokens.mutedText,
              ),
    );
  }
}

class _AuthorLine extends StatelessWidget {
  final FeedTokens tokens;
  final PostEntity post;

  const _AuthorLine({required this.tokens, required this.post});

  @override
  Widget build(BuildContext context) {
    final initial =
        post.authorName.trim().isNotEmpty
            ? post.authorName.trim()[0].toUpperCase()
            : '?';

    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: tokens.avatarBg,
          ),
          clipBehavior: Clip.antiAlias,
          child:
              (post.authorPhotoUrl?.isNotEmpty ?? false)
                  ? CachedNetworkImage(
                    imageUrl: post.authorPhotoUrl!,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _initial(initial),
                  )
                  : _initial(initial),
        ),
        const SizedBox(width: 7),
        Flexible(
          child: GestureDetector(
            onTap: () => context.push('/profile/${post.authorId}'),
            child: Text(
              post.authorName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: FeedText.body(tokens, size: 13, weight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          '· ${DateFormatter.timeAgoShort(post.createdAt)}',
          style: FeedText.body(tokens, size: 11.5, color: tokens.mutedText),
        ),
      ],
    );
  }

  Widget _initial(String initial) => Center(
    child: Text(
      initial,
      style: FeedText.body(
        tokens,
        size: 10,
        weight: FontWeight.w600,
        color: tokens.avatarFg,
      ),
    ),
  );
}

class _Action extends StatelessWidget {
  final FeedTokens tokens;
  final String label;
  final Color color;
  final FontWeight weight;
  final VoidCallback onTap;

  const _Action({
    required this.tokens,
    required this.label,
    required this.color,
    required this.weight,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        // La maquette pose deux libellés nus ; ce rembourrage vertical leur
        // donne une cible tactile décente sans les décaler visuellement.
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          label,
          style: FeedText.body(tokens, size: 12, weight: weight, color: color),
        ),
      ),
    );
  }
}
