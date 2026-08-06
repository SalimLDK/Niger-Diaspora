import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../profile/presentation/providers/profile_provider.dart';
import '../providers/feed_provider.dart';
import '../theme/feed_text.dart';
import '../theme/feed_tokens.dart';
import '../widgets/feed_avatar.dart';
import '../widgets/follow_button.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

/// Liste des comptes ayant repartagé une publication donnée
/// (route `/feed/:postId/reposts`).
class RepostersScreen extends ConsumerWidget {
  final String postId;

  const RepostersScreen({super.key, required this.postId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repostersAsync = ref.watch(repostersProvider(postId));
    final tokens = FeedTokens.of(context);

    return Scaffold(
      backgroundColor: tokens.bg,
      appBar: AppBar(
        backgroundColor: tokens.bg,
        title: Text('Repartages', style: FeedText.heading(tokens, size: 18)),
        elevation: 0,
      ),
      body: repostersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Text(
            'Impossible de charger les repartages.',
            style: TextStyle(color: tokens.mutedText),
          ),
        ),
        data: (ids) {
          if (ids.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Personne n\'a encore repartagé cette publication.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: tokens.mutedText),
                ),
              ),
            );
          }
          return ListView.separated(
            itemCount: ids.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) => _ReposterTile(userId: ids[index]),
          );
        },
      ),
    );
  }
}

class _ReposterTile extends ConsumerWidget {
  final String userId;

  const _ReposterTile({required this.userId});

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
