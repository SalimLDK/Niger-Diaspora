import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';
import '../../../profile/domain/entities/profile_entity.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../providers/feed_provider.dart';
import '../theme/feed_text.dart';
import '../theme/feed_tokens.dart';
import '../widgets/feed_avatar.dart';
import '../widgets/feed_empty_state.dart';
import '../widgets/feed_pill_tabs.dart';
import '../widgets/follow_button.dart';

/// Écran « Mon réseau » (fiche 5d, route `/profile/follows`).
///
/// Deux onglets pleins avec compteur permanent, une recherche qui filtre la
/// liste affichée, et — sous Abonnements — les hashtags suivis à la suite des
/// comptes.
class FollowsScreen extends ConsumerStatefulWidget {
  /// Utilisateur dont on affiche les abonnés/abonnements. Par défaut,
  /// l'utilisateur connecté.
  final String? userId;

  /// Onglet initial : 0 = abonnés, 1 = abonnements.
  final int initialTab;

  const FollowsScreen({super.key, this.userId, this.initialTab = 0});

  @override
  ConsumerState<FollowsScreen> createState() => _FollowsScreenState();
}

class _FollowsScreenState extends ConsumerState<FollowsScreen> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  late int _tab = widget.initialTab.clamp(0, 1);
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = FeedTokens.of(context);
    final targetId =
        widget.userId ?? FirebaseAuth.instance.currentUser?.uid ?? '';

    final followersCount =
        ref.watch(followersCountProvider(targetId)).valueOrNull;
    final followingCount =
        ref.watch(followingCountProvider(targetId)).valueOrNull;

    String withCount(String label, int? n) => n == null ? label : '$label · $n';

    return Scaffold(
      backgroundColor: tokens.bg,
      body: SafeArea(
        child: Column(
          children: [
            _Header(tokens: tokens),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: FeedPillTabs(
                tokens: tokens,
                selected: _tab,
                labels: [
                  withCount(l10n.followersTitle, followersCount),
                  withCount(l10n.followingTab, followingCount),
                ],
                onChanged: (v) => setState(() => _tab = v),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _SearchField(
                tokens: tokens,
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v.toLowerCase()),
              ),
            ),
            Expanded(
              child:
                  _tab == 0
                      ? _FollowList(
                        usersAsync: ref.watch(followersProvider(targetId)),
                        query: _query,
                        // Sous l'onglet Abonnés, tout le monde me suit par
                        // définition : la mention se déduit de l'onglet, elle
                        // n'a pas besoin d'une requête de réciprocité.
                        relation: 'vous suit',
                        emptyIcon: Icons.people_outline_rounded,
                        emptyTitle: l10n.followersEmptyTitle,
                        emptyBody: l10n.followersEmptyBody,
                        ctaLabel: l10n.exploreFeed,
                        onCta: () => context.push('/feed'),
                      )
                      : _FollowList(
                        usersAsync: ref.watch(followingProvider(targetId)),
                        query: _query,
                        relation: 'vous suivez',
                        emptyIcon: Icons.person_add_alt_1_outlined,
                        emptyTitle: l10n.followingEmptyTitle,
                        emptyBody: l10n.followingEmptyBody,
                        ctaLabel: l10n.exploreFeed,
                        onCta: () => context.push('/feed'),
                        // Les hashtags suivis ne concernent que mon propre
                        // réseau : sur le profil d'un tiers, ils n'existent pas.
                        showHashtags:
                            widget.userId == null ||
                            widget.userId ==
                                FirebaseAuth.instance.currentUser?.uid,
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// En-tête et recherche
// ---------------------------------------------------------------------------

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
                  () =>
                      context.canPop()
                          ? context.pop()
                          : context.go('/feed/space'),
              child: SizedBox(
                height: 52,
                width: 24,
                child: Center(
                  child: AppIcon(
                    AppIcon.arrowBack,
                    size: 24,
                    color: tokens.text,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Mon réseau',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: FeedText.heading(tokens, size: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final FeedTokens tokens;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchField({
    required this.tokens,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(tokens.isDark ? tokens.radiusMd : 14),
      ),
      child: Row(
        children: [
          AppIcon(AppIcon.search, size: 17, color: tokens.mutedText),
          const SizedBox(width: 9),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: FeedText.body(tokens, size: 14),
              cursorColor: tokens.accent,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 9),
                // Le thème global remplit les champs en blanc et leur pose un
                // contour : le fond et la forme sont déjà portés par le
                // conteneur, sinon une pilule blanche cerclée se pose au
                // milieu de la barre. `border` seul ne suffit pas — ce sont
                // `enabledBorder`/`focusedBorder` du thème qui s'appliquent.
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                hintText: 'Rechercher un nom, une ville',
                hintStyle: FeedText.body(
                  tokens,
                  size: 14,
                  color: tokens.mutedText,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Listes
// ---------------------------------------------------------------------------

class _FollowList extends ConsumerWidget {
  final AsyncValue<List<String>> usersAsync;
  final String query;
  final String relation;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyBody;
  final String ctaLabel;
  final VoidCallback onCta;
  final bool showHashtags;

  const _FollowList({
    required this.usersAsync,
    required this.query,
    required this.relation,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptyBody,
    required this.ctaLabel,
    required this.onCta,
    this.showHashtags = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = FeedTokens.of(context);
    final hashtags =
        showHashtags
            ? ref
                .watch(followedHashtagsProvider)
                .where((h) => query.isEmpty || h.toLowerCase().contains(query))
                .toList()
            : const <String>[];

    return usersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:
          (_, __) => FeedEmptyState(
            icon: Icons.error_outline_rounded,
            title: AppLocalizations.of(context)!.error,
            body: emptyBody,
          ),
      data: (ids) {
        if (ids.isEmpty && hashtags.isEmpty) {
          return FeedEmptyState(
            icon: emptyIcon,
            title: emptyTitle,
            body: emptyBody,
            ctaLabel: ctaLabel,
            ctaIcon: Icons.explore_outlined,
            onCta: onCta,
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            for (final id in ids)
              _FollowTile(userId: id, relation: relation, query: query),
            for (final tag in hashtags) _HashtagTile(tag: tag, tokens: tokens),
          ],
        );
      },
    );
  }
}

/// Ligne de contact : avatar 44, nom, ligne de contexte « ville · relation »,
/// pastille Suivre/Suivi, filet séparateur sous chaque ligne.
class _FollowTile extends ConsumerWidget {
  final String userId;
  final String relation;
  final String query;

  const _FollowTile({
    required this.userId,
    required this.relation,
    required this.query,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = FeedTokens.of(context);
    final profile = ref.watch(profileNotifierProvider(userId)).valueOrNull;
    final name = profile?.displayName ?? l10n.user;

    // Le filtre porte sur ce qui est affiché — nom et ville — et laisse
    // passer les profils encore en cours de chargement plutôt que de les
    // faire disparaître le temps d'une requête.
    if (query.isNotEmpty && profile != null && !_matches(profile, name)) {
      return const SizedBox.shrink();
    }

    final city = profile?.currentCity?.trim();
    final context0 =
        (city != null && city.isNotEmpty) ? '$city · $relation' : relation;
    final me = FirebaseAuth.instance.currentUser?.uid;

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.hairline)),
      ),
      child: InkWell(
        onTap: () => context.push('/profile/$userId'),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            children: [
              FeedAvatar(
                name: name,
                photoUrl: profile?.photoUrl,
                tokens: tokens,
                radius: 22, // cercle de 44 px, fiche 5d
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FeedText.body(
                        tokens,
                        size: 14.5,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context0,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FeedText.body(
                        tokens,
                        size: 12,
                        color: tokens.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
              if (userId != me) ...[
                const SizedBox(width: 8),
                FollowButton(
                  targetUserId: userId,
                  variant: FollowButtonVariant.pill,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  bool _matches(ProfileEntity profile, String name) {
    final haystack = [
      name,
      profile.currentCity ?? '',
      profile.currentCountry ?? '',
      profile.handle ?? '',
    ].join(' ').toLowerCase();
    return haystack.contains(query);
  }
}

/// Ligne de hashtag suivi (onglet Abonnements) : carré au glyphe tag plutôt
/// qu'un cercle avatar, pour la distinguer d'un compte au premier coup d'œil.
class _HashtagTile extends ConsumerWidget {
  final String tag;
  final FeedTokens tokens;

  const _HashtagTile({required this.tag, required this.tokens});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.hairline)),
      ),
      child: InkWell(
        onTap: () => context.push('/feed?hashtag=$tag'),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: tokens.surface,
                  borderRadius: BorderRadius.circular(
                    tokens.isDark ? tokens.radiusSm : 12,
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.tag_rounded,
                  size: 22,
                  color: tokens.hashtagColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '#$tag',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FeedText.body(
                        tokens,
                        size: 14.5,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Hashtag',
                      style: FeedText.body(
                        tokens,
                        size: 12,
                        color: tokens.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap:
                    () => ref
                        .read(followedHashtagsProvider.notifier)
                        .unfollow(tag),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: tokens.divider),
                  ),
                  child: Text(
                    'Suivi',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: tokens.actionLabel,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
