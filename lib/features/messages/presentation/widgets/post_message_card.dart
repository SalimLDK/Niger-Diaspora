import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'shared_card_palette.dart';

/// Carte affichée dans une bulle de message pour un post partagé.
/// postData structure: {postId, authorId, authorName, content, mediaUrl}
class PostMessageCard extends StatelessWidget {
  final Map<String, dynamic> postData;
  final bool isMe;

  const PostMessageCard({
    super.key,
    required this.postData,
    required this.isMe,
  });

  /// Le texte que le partage pose tout seul sous la carte (« 📌 Post de
  /// Salim L. ») : il sert à l'aperçu de la liste et aux notifications, mais
  /// dans la bulle il répète la carte. Un texte écrit par l'utilisateur, lui,
  /// reste affiché.
  static bool isDefaultCaption(String content, Map<String, dynamic> postData) {
    final auteur = postData['authorName'] as String? ?? '';
    final texte = content.trim();
    return texte == '📌 Post de $auteur' ||
        texte == '📌 $auteur' ||
        texte == '📌 Post partagé';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = SharedCardPalette.of(context, isMe: isMe);
    final authorName = postData['authorName'] as String? ?? 'Utilisateur';
    final content = postData['content'] as String? ?? '';
    final mediaUrl = postData['mediaUrl'] as String?;
    final postId = postData['postId'] as String?;

    final preview = content.length > 80
        ? '${content.substring(0, 80)}…'
        : content;

    return GestureDetector(
      onTap: postId != null ? () => context.push('/feed/$postId') : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        decoration: palette.decoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (mediaUrl != null)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(10),
                ),
                child: Image.network(
                  mediaUrl,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.dynamic_feed_rounded,
                        size: 15,
                        color: palette.accent,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          authorName,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: palette.accent,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (preview.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      preview,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: palette.body,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'Voir la publication →',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: palette.accent,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                      decorationColor: palette.accent,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
