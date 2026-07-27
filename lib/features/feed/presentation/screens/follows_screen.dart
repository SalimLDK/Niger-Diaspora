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
import '../widgets/follow_button.dart';

/// Écran « Abonnés et abonnements » de l'utilisateur courant
/// (route `/profile/follows`). Deux onglets réutilisant [followersProvider]
/// et [followingProvider].
class FollowsScreen extends ConsumerWidget {
  /// Utilisateur dont on affiche les abonnés/abonnements. Par défaut,
  /// l'utilisateur connecté.
  final String? userId;

  /// Onglet initial : 0 = abonnés, 1 = abonnements.
  final int initialTab;

  const FollowsScreen({super.key, this.userId, this.initialTab = 0});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = FeedTokens.of(context);
    final targetId = userId ?? FirebaseAuth.instance.currentUser?.uid ?? '';

    return DefaultTabController(
      length: 2,
      initialIndex: initialTab.clamp(0, 1),
      child: Scaffold(
        backgroundColor: tokens.bg,
        appBar: AppBar(
          backgroundColor: tokens.bg,
          elevation: 0,
          title: Text(
            l10n.followTitle,
            style: FeedText.heading(tokens, size: 18),
          ),
          bottom: TabBar(
            labelColor: tokens.accent,
            unselectedLabelColor: tokens.mutedText,
            indicatorColor: tokens.accent,
            tabs: [
              Tab(text: l10n.followersTitle),
              Tab(text: l10n.followingTitle),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _FollowList(
              usersAsync: ref.watch(followersProvider(targetId)),
              emptyLabel: l10n.noFollowersYet,
            ),
            _FollowList(
              usersAsync: ref.watch(followingProvider(targetId)),
              emptyLabel: l10n.noFollowingYet,
            ),
          ],
        ),
      ),
    );
  }
}

class _FollowList extends StatelessWidget {
  final AsyncValue<List<String>> usersAsync;
  final String emptyLabel;

  const _FollowList({required this.usersAsync, required this.emptyLabel});

  @override
  Widget build(BuildContext context) {
    final tokens = FeedTokens.of(context);
    return usersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(
        child: Text(
          AppLocalizations.of(context)!.error,
          style: TextStyle(color: tokens.mutedText),
        ),
      ),
      data: (ids) {
        if (ids.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                emptyLabel,
                textAlign: TextAlign.center,
                style: TextStyle(color: tokens.mutedText),
              ),
            ),
          );
        }
        return ListView.separated(
          itemCount: ids.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
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
      onTap: () => context.push('/profile/$userId'),
      leading: FeedAvatar(name: name, photoUrl: photo, tokens: tokens),
      title: Text(name),
      subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
      trailing: userId == me ? null : FollowButton(targetUserId: userId),
    );
  }
}
