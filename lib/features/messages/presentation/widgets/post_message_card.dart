import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
        decoration: BoxDecoration(
          color: isMe
              ? Colors.white.withValues(alpha: 0.15)
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isMe
                ? Colors.white.withValues(alpha: 0.3)
                : theme.dividerColor,
          ),
        ),
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
                      const Icon(
                        Icons.dynamic_feed_rounded,
                        size: 14,
                        color: Colors.teal,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '📌 $authorName',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.teal,
                            fontWeight: FontWeight.w600,
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
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isMe ? Colors.white70 : null,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    'Voir la publication →',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.teal,
                      decoration: TextDecoration.underline,
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
