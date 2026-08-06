import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:diaspo_niger/shared/widgets/app_icon.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../providers/feed_provider.dart';
import '../theme/feed_text.dart';
import '../theme/feed_tokens.dart';
import 'my_posts_screen.dart' show userPostsCountProvider;
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'saved_posts_screen.dart' show bookmarkedPostsCountProvider;

/// Hub « Mon espace » (fiche 5a) — point d'entrée = avatar de l'en-tête du fil.
///
/// Bloc identité, trois cases de stats (Publications / Abonnés / Abonnements),
/// une carte de navigation à cinq lignes séparées par un filet, puis la carte
/// isolée « Brouillons ».
class MonEspaceScreen extends ConsumerWidget {
  const MonEspaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = FeedTokens.of(context);
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;
    final profile =
        uid != null ? ref.watch(profileNotifierProvider(uid)).valueOrNull : null;

    final name = _displayName(profile?.displayName, user?.displayName);
    final handle =
        (profile?.handle != null && profile!.handle!.isNotEmpty)
            ? '@${profile.handle}'
            : '@${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}';
    // « @moussa · Niamey → Paris » : la trajectoire n'apparaît que si les deux
    // villes sont renseignées, sinon la ligne se réduit à la poignée.
    final origin = profile?.originCity?.trim();
    final current = profile?.currentCity?.trim();
    final subtitle =
        (origin != null &&
                origin.isNotEmpty &&
                current != null &&
                current.isNotEmpty)
            ? '$handle · $origin → $current'
            : handle;

    return Scaffold(
      backgroundColor: tokens.bg,
      body: SafeArea(
        child: Column(
          children: [
            _Header(tokens: tokens),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                children: [
                  _IdentityBlock(
                    tokens: tokens,
                    name: name,
                    subtitle: subtitle,
                    photoUrl: profile?.photoUrl ?? user?.photoURL,
                  ),
                  const SizedBox(height: 18),
                  _StatsRow(tokens: tokens, uid: uid),
                  const SizedBox(height: 20),
                  _NavCard(tokens: tokens),
                  const SizedBox(height: 16),
                  _DraftsCard(tokens: tokens),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _displayName(String? fromProfile, String? fromAuth) {
    for (final candidate in [fromProfile, fromAuth]) {
      final value = candidate?.trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return 'Vous';
  }
}

// ---------------------------------------------------------------------------
// En-tête
// ---------------------------------------------------------------------------

/// En-tête de la fiche 5a : hauteur 52, padding horizontal 16, flèche 24 et
/// gap 10 avant le titre. Un `AppBar` ne donne pas ces valeurs (son bouton
/// d'icône impose ses propres marges de 48×48), d'où la ligne sur mesure.
class _Header extends StatelessWidget {
  final FeedTokens tokens;

  const _Header({required this.tokens});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap:
                  () => context.canPop() ? context.pop() : context.go('/feed'),
              child: SizedBox(
                // Cible tactile confortable sans décaler l'icône : la boîte
                // déborde en hauteur, pas en largeur.
                height: 52,
                width: 24,
                child: Center(
                  child: AppIcon(AppIcon.arrowBack, size: 24, color: tokens.text),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Mon espace',
                style: FeedText.heading(tokens, size: 22),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Identité
// ---------------------------------------------------------------------------

class _IdentityBlock extends StatelessWidget {
  final FeedTokens tokens;
  final String name;
  final String subtitle;
  final String? photoUrl;

  const _IdentityBlock({
    required this.tokens,
    required this.name,
    required this.subtitle,
    required this.photoUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: tokens.avatarBg,
          ),
          clipBehavior: Clip.antiAlias,
          child:
              (photoUrl != null && photoUrl!.isNotEmpty)
                  ? CachedNetworkImage(
                    imageUrl: photoUrl!,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _initial(),
                  )
                  : _initial(),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: FeedText.body(
                  tokens,
                  size: 18,
                  weight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: FeedText.body(tokens, size: 13, color: tokens.mutedText),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _initial() => Center(
    child: Text(
      name.isNotEmpty ? name[0].toUpperCase() : '?',
      style: FeedText.body(
        tokens,
        size: 24,
        weight: FontWeight.w600,
        color: tokens.avatarFg,
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Trois cases de stats
// ---------------------------------------------------------------------------

class _StatsRow extends ConsumerWidget {
  final FeedTokens tokens;
  final String? uid;

  const _StatsRow({required this.tokens, required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final posts = ref.watch(userPostsCountProvider).valueOrNull;
    final followers =
        uid != null ? ref.watch(followersCountProvider(uid!)).valueOrNull : null;
    final following =
        uid != null ? ref.watch(followingCountProvider(uid!)).valueOrNull : null;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            tokens: tokens,
            value: posts,
            label: l10n.profileStatPosts,
            onTap: () => context.push('/profile/my-posts'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            tokens: tokens,
            value: followers,
            label: l10n.followersTitle,
            onTap: () => context.push('/profile/follows?tab=0'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            tokens: tokens,
            value: following,
            label: l10n.followingTab,
            onTap: () => context.push('/profile/follows?tab=1'),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final FeedTokens tokens;
  final int? value;
  final String label;
  final VoidCallback onTap;

  const _StatCard({
    required this.tokens,
    required this.value,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(tokens.statCardRadius);
    return Material(
      color: tokens.surface,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          child: Column(
            children: [
              Text(
                value?.toString() ?? '—',
                style: FeedText.body(
                  tokens,
                  size: 20,
                  weight: FontWeight.w600,
                ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: FeedText.body(
                  tokens,
                  size: 11.5,
                  weight: FontWeight.w500,
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

// ---------------------------------------------------------------------------
// Carte de navigation (5 lignes)
// ---------------------------------------------------------------------------

class _NavCard extends ConsumerWidget {
  final FeedTokens tokens;

  const _NavCard({required this.tokens});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final posts = ref.watch(userPostsCountProvider).valueOrNull;
    final reposts = ref.watch(myRepostsProvider).valueOrNull?.length;
    final saved = ref.watch(bookmarkedPostsCountProvider).valueOrNull;
    final hashtags = ref.watch(followedHashtagsProvider).length;

    final rows = <Widget>[
      _NavRow(
        tokens: tokens,
        icon: Icons.edit_note_rounded,
        iconColor: tokens.accent,
        label: l10n.myPostsTitle,
        count: posts,
        onTap: () => context.push('/profile/my-posts'),
      ),
      _NavRow(
        tokens: tokens,
        icon: Icons.repeat_rounded,
        iconColor: tokens.accent2,
        label: l10n.repostsTitle,
        count: reposts,
        // §5b, onglet Repartages actif — et non l'ancien écran dédié.
        onTap: () => context.push('/profile/my-posts?tab=1'),
      ),
      _NavRow(
        tokens: tokens,
        icon: Icons.bookmark_rounded,
        iconColor: tokens.accent,
        label: l10n.audioRoomHeritageSaved,
        count: saved,
        onTap: () => context.push('/profile/saved-posts'),
      ),
      _NavRow(
        tokens: tokens,
        iconWidget: AppIcon(
          AppIcon.people,
          size: 19,
          color: tokens.actionLabel,
        ),
        label: l10n.followTitle,
        onTap: () => context.push('/profile/follows'),
      ),
      _NavRow(
        tokens: tokens,
        icon: Icons.tag_rounded,
        iconColor: tokens.hashtagColor,
        label: 'Hashtags suivis',
        count: hashtags,
        onTap: () => context.push('/feed/space/hashtags'),
      ),
    ];

    return _CardShell(
      tokens: tokens,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          rows[i],
          if (i != rows.length - 1)
            Divider(height: 1, thickness: 1, color: tokens.hairline),
        ],
      ],
    );
  }
}

/// Coque commune aux deux cartes : fond [FeedTokens.surface], rayon 22 et
/// découpe pour que les vagues d'encre des lignes restent dans le rayon.
class _CardShell extends StatelessWidget {
  final FeedTokens tokens;
  final List<Widget> children;

  const _CardShell({required this.tokens, required this.children});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: tokens.surface,
      borderRadius: BorderRadius.circular(tokens.listCardRadius),
      clipBehavior: Clip.antiAlias,
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

class _NavRow extends StatelessWidget {
  final FeedTokens tokens;
  final IconData? icon;
  final Color? iconColor;
  final Widget? iconWidget;
  final String label;
  final String? subtitle;
  final int? count;
  final VoidCallback onTap;

  const _NavRow({
    required this.tokens,
    required this.label,
    required this.onTap,
    this.icon,
    this.iconColor,
    this.iconWidget,
    this.subtitle,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: tokens.bg,
                borderRadius: BorderRadius.circular(tokens.iconTileRadius),
              ),
              alignment: Alignment.center,
              // Les glyphes Material de la maquette font 24px ; seule l'icône
              // SVG `people` y est posée à 19px.
              child: iconWidget ?? Icon(icon, size: 24, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: FeedText.body(
                      tokens,
                      size: 14.5,
                      weight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: FeedText.body(
                        tokens,
                        size: 12,
                        color: tokens.mutedText,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 8),
              Text(
                '$count',
                style: FeedText.body(
                  tokens,
                  size: 13,
                  weight: FontWeight.w500,
                  color: tokens.mutedText,
                ),
              ),
            ],
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 20, color: tokens.actionMuted),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Carte « Brouillons » isolée
// ---------------------------------------------------------------------------

class _DraftsCard extends ConsumerWidget {
  final FeedTokens tokens;

  const _DraftsCard({required this.tokens});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drafts = ref.watch(postDraftsProvider);
    // Pas de carte plutôt qu'une carte à « 0 » : rien à reprendre, rien à
    // montrer.
    if (drafts.isEmpty) return const SizedBox.shrink();

    final plural = drafts.length > 1 ? 's' : '';
    return _CardShell(
      tokens: tokens,
      children: [
        _NavRow(
          tokens: tokens,
          icon: Icons.drafts_rounded,
          iconColor: tokens.mutedText,
          label: 'Brouillons',
          subtitle: '${drafts.length} publication$plural non envoyée$plural',
          // Un seul brouillon : on ouvre directement l'éditeur dessus. À
          // plusieurs, il faut choisir — c'est la liste de Mes publications
          // (§5b) qui porte les cartes brouillon.
          onTap:
              () =>
                  drafts.length == 1
                      ? context.push('/feed/create?draft=${drafts.first.id}')
                      : context.push('/profile/my-posts'),
        ),
      ],
    );
  }
}
