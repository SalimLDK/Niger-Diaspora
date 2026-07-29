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

/// Hub « Mon espace » (tour 5a) — point d'entrée = avatar de l'en-tête du fil.
/// En-tête profil, cartes de stats (abonnés / abonnements) et raccourcis vers
/// Mes publications, Repartages, Enregistrés, Abonnés & abonnements.
class MonEspaceScreen extends ConsumerWidget {
  const MonEspaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = FeedTokens.of(context);
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;
    final name =
        (user?.displayName?.trim().isNotEmpty ?? false)
            ? user!.displayName!.trim()
            : 'Vous';
    final profile =
        uid != null ? ref.watch(profileNotifierProvider(uid)).valueOrNull : null;
    final handle =
        (profile?.handle != null && profile!.handle!.isNotEmpty)
            ? '@${profile.handle}'
            : '@${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}';

    return Scaffold(
      backgroundColor: tokens.bg,
      appBar: AppBar(
        backgroundColor: tokens.bg,
        elevation: 0,
        leading: IconButton(
          icon: AppIcon(AppIcon.arrowBack, color: tokens.text),
          onPressed:
              () => context.canPop() ? context.pop() : context.go('/feed'),
        ),
        title: Text('Mon espace', style: FeedText.heading(tokens, size: 20)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          _ProfileBlock(
            tokens: tokens,
            name: name,
            handle: handle,
            photoUrl: user?.photoURL,
          ),
          const SizedBox(height: 20),
          if (uid != null) _StatsRow(tokens: tokens, uid: uid),
          const SizedBox(height: 20),
          _SpaceTile(
            tokens: tokens,
            icon: AppIcon(AppIcon.person, size: 20, color: tokens.accent),
            label: 'Mes publications',
            onTap: () => context.push('/profile/my-posts'),
          ),
          _SpaceTile(
            tokens: tokens,
            icon: Icon(Icons.repeat_rounded, size: 20, color: tokens.accent2),
            label: 'Mes repartages',
            onTap: () => context.push('/profile/reposts'),
          ),
          _SpaceTile(
            tokens: tokens,
            icon: Icon(Icons.bookmark_rounded, size: 20, color: tokens.accent),
            label: 'Enregistrés',
            onTap: () => context.push('/profile/saved-posts'),
          ),
          _SpaceTile(
            tokens: tokens,
            icon: AppIcon(AppIcon.people, size: 20, color: tokens.accent),
            label: 'Abonnés et abonnements',
            onTap: () => context.push('/profile/follows'),
          ),
        ],
      ),
    );
  }
}

class _ProfileBlock extends StatelessWidget {
  final FeedTokens tokens;
  final String name;
  final String handle;
  final String? photoUrl;

  const _ProfileBlock({
    required this.tokens,
    required this.name,
    required this.handle,
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
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: FeedText.heading(tokens, size: 20)),
              const SizedBox(height: 2),
              Text(
                handle,
                style: TextStyle(fontSize: 13.5, color: tokens.mutedText),
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
      style: TextStyle(
        color: tokens.avatarFg,
        fontSize: 24,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _StatsRow extends ConsumerWidget {
  final FeedTokens tokens;
  final String uid;

  const _StatsRow({required this.tokens, required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followers = ref.watch(followersCountProvider(uid)).valueOrNull;
    final following = ref.watch(followingCountProvider(uid)).valueOrNull;
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            tokens: tokens,
            value: followers,
            label: 'Abonnés',
            onTap: () => context.push('/profile/follows?tab=0'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            tokens: tokens,
            value: following,
            label: 'Abonnements',
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
    return Material(
      color: tokens.surface,
      borderRadius: BorderRadius.circular(tokens.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(tokens.radiusMd),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Column(
            children: [
              Text(
                value?.toString() ?? '—',
                style: FeedText.heading(tokens, size: 22),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(fontSize: 12.5, color: tokens.mutedText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpaceTile extends StatelessWidget {
  final FeedTokens tokens;
  final Widget icon;
  final String label;
  final VoidCallback onTap;

  const _SpaceTile({
    required this.tokens,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(tokens.radiusMd),
        child: InkWell(
          borderRadius: BorderRadius.circular(tokens.radiusMd),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                icon,
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: tokens.text,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, color: tokens.mutedText),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
