import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:diaspo_niger/shared/widgets/app_icon.dart';
import '../providers/feed_provider.dart';
import '../theme/feed_text.dart';
import '../theme/feed_tokens.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

/// Hashtags suivis (§5a « Mon espace ») : liste locale, sans modèle serveur.
/// Se remplit depuis le bouton « Suivre » du bandeau de filtre par hashtag
/// (`_HashtagBanner` de `feed_screen.dart`).
class FollowedHashtagsScreen extends ConsumerWidget {
  const FollowedHashtagsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = FeedTokens.of(context);
    final hashtags = ref.watch(followedHashtagsProvider);

    return Scaffold(
      backgroundColor: tokens.bg,
      appBar: AppBar(
        backgroundColor: tokens.bg,
        elevation: 0,
        leading: IconButton(
          icon: AppIcon(AppIcon.arrowBack, color: tokens.text),
          onPressed: () => context.pop(),
        ),
        title: Text(
          l10n.feedFollowedHashtags,
          style: FeedText.heading(tokens, size: 20),
        ),
      ),
      body:
          hashtags.isEmpty
              ? _EmptyState(tokens: tokens)
              : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children:
                        hashtags
                            .map(
                              (tag) => _HashtagChip(
                                tokens: tokens,
                                tag: tag,
                                onTap:
                                    () => context.push('/feed?hashtag=$tag'),
                                onUnfollow:
                                    () => ref
                                        .read(followedHashtagsProvider.notifier)
                                        .unfollow(tag),
                              ),
                            )
                            .toList(),
                  ),
                ],
              ),
    );
  }
}

class _HashtagChip extends StatelessWidget {
  final FeedTokens tokens;
  final String tag;
  final VoidCallback onTap;
  final VoidCallback onUnfollow;

  const _HashtagChip({
    required this.tokens,
    required this.tag,
    required this.onTap,
    required this.onUnfollow,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: tokens.surface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.tag_rounded, size: 16, color: tokens.hashtagColor),
              const SizedBox(width: 4),
              Text(
                tag,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: tokens.text,
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onUnfollow,
                child: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: tokens.mutedText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final FeedTokens tokens;

  const _EmptyState({required this.tokens});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tokens.accent.withValues(alpha: 0.12),
              ),
              child: Icon(Icons.tag_rounded, size: 44, color: tokens.accent),
            ),
            const SizedBox(height: 20),
            Text(
              'Aucun hashtag suivi',
              textAlign: TextAlign.center,
              style: FeedText.heading(tokens, size: 19),
            ),
            const SizedBox(height: 8),
            Text(
              'Ouvrez un hashtag depuis le fil et appuyez sur « Suivre » '
              'pour le retrouver ici.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: tokens.mutedText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
