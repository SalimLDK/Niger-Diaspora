import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:diaspo_niger/l10n/app_localizations.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../providers/feed_provider.dart';
import '../theme/feed_text.dart';
import '../theme/feed_tokens.dart';
import '../widgets/feed_avatar.dart';
import '../widgets/feed_empty_state.dart';
import '../widgets/feed_segmented_control.dart';
import '../widgets/follow_button.dart';

/// Écran « Mon réseau » de l'utilisateur courant (route `/profile/follows`).
/// Deux segments pleins (Abonnés · N / Abonnements · N) — refonte tour 5d,
/// remplace la `TabBar` soulignée.
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
  late int _tab = widget.initialTab.clamp(0, 1);

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

    String withCount(String label, int? n) =>
        n == null ? label : '$label · $n';

    return Scaffold(
      backgroundColor: tokens.bg,
      appBar: AppBar(
        backgroundColor: tokens.bg,
        elevation: 0,
        title: Text(l10n.followTitle, style: FeedText.heading(tokens, size: 18)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: FeedSegmentedControl<int>(
              tokens: tokens,
              fullWidth: true,
              selected: _tab,
              onChanged: (v) => setState(() => _tab = v),
              segments: [
                FeedSegment(
                  value: 0,
                  icon: (c) => Icon(Icons.people_outline_rounded, color: c),
                  label: withCount(l10n.followersTitle, followersCount),
                ),
                FeedSegment(
                  value: 1,
                  icon: (c) => Icon(Icons.person_add_alt_1_outlined, color: c),
                  label: withCount(l10n.followingTitle, followingCount),
                ),
              ],
            ),
          ),
          Expanded(
            child: _tab == 0
                ? _FollowList(
                    usersAsync: ref.watch(followersProvider(targetId)),
                    emptyIcon: Icons.people_outline_rounded,
                    emptyTitle: l10n.followersEmptyTitle,
                    emptyBody: l10n.followersEmptyBody,
                    ctaLabel: l10n.exploreFeed,
                    onCta: () => context.push('/feed'),
                  )
                : _FollowList(
                    usersAsync: ref.watch(followingProvider(targetId)),
                    emptyIcon: Icons.person_add_alt_1_outlined,
                    emptyTitle: l10n.followingEmptyTitle,
                    emptyBody: l10n.followingEmptyBody,
                    ctaLabel: l10n.exploreFeed,
                    onCta: () => context.push('/feed'),
                  ),
          ),
        ],
      ),
    );
  }
}

class _FollowList extends StatelessWidget {
  final AsyncValue<List<String>> usersAsync;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyBody;
  final String ctaLabel;
  final VoidCallback onCta;

  const _FollowList({
    required this.usersAsync,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptyBody,
    required this.ctaLabel,
    required this.onCta,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = FeedTokens.of(context);
    return usersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => FeedEmptyState(
        icon: Icons.error_outline_rounded,
        title: AppLocalizations.of(context)!.error,
        body: emptyBody,
      ),
      data: (ids) {
        if (ids.isEmpty) {
          return FeedEmptyState(
            icon: emptyIcon,
            title: emptyTitle,
            body: emptyBody,
            ctaLabel: ctaLabel,
            ctaIcon: Icons.explore_outlined,
            onCta: onCta,
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 24),
          itemCount: ids.length,
          separatorBuilder: (_, __) =>
              Divider(height: 1, color: tokens.hairline),
          itemBuilder: (context, index) => _FollowTile(userId: ids[index]),
        );
      },
    );
  }
}

class _FollowTile extends ConsumerWidget {
  final String userId;

  const _FollowTile({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final profile = ref.watch(profileNotifierProvider(userId)).valueOrNull;
    final name = profile?.displayName ?? l10n.user;
    final photo = profile?.photoUrl;
    final subtitle = [profile?.currentCity, profile?.currentCountry]
        .where((e) => e != null && e.isNotEmpty)
        .join(', ');
    final me = FirebaseAuth.instance.currentUser?.uid;
    final tokens = FeedTokens.of(context);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onTap: () => context.push('/profile/$userId'),
      leading: FeedAvatar(name: name, photoUrl: photo, tokens: tokens),
      title: Text(
        name,
        style: FeedText.body(tokens, size: 15, weight: FontWeight.w600),
      ),
      subtitle: subtitle.isNotEmpty
          ? Text(
              subtitle,
              style: FeedText.body(tokens, size: 12.5, color: tokens.mutedText),
            )
          : null,
      trailing: userId == me ? null : FollowButton(targetUserId: userId),
    );
  }
}
