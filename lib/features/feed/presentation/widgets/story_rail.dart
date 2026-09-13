import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../stories/domain/entities/story_entity.dart';
import '../../../stories/presentation/providers/story_provider.dart';
import '../../../stories/presentation/story_creation.dart';
import '../theme/feed_tokens.dart';

/// Taille du libellé sous chaque avatar du rail. Partagée avec le calcul de
/// hauteur du rail (`StoryRail._railHeight`) pour qu'ils ne divergent pas.
const double _labelFontSize = 11.5;

/// Interligne du libellé, imposé explicitement. Sans lui, le `Text` hérite du
/// `height` de `bodyMedium` (1.55, cf. `AppTheme._buildTextTheme`) : la ligne
/// mesurait 17,8 px là où le rail n'en réservait que 16, d'où le
/// « BOTTOM OVERFLOWED BY 2.0 PIXELS » sous « Ma story ». En le figeant ici, la
/// ligne vaut `fontSize × _labelLineHeight` arrondi au pixel le plus proche —
/// indépendamment du thème ambiant et de la police — donc toujours ≤ ce que
/// `_railHeight` provisionne avec `ceilToDouble`.
const double _labelLineHeight = 1.3;

/// Style commun aux libellés du rail, mesurable par `_railHeight`.
TextStyle _labelStyle(FeedTokens tokens) => TextStyle(
      fontSize: _labelFontSize,
      height: _labelLineHeight,
      color: tokens.mutedText,
    );

/// Rail de stories/actus (§4) — cercles d'avatars en haut du fil, anneau
/// accent pour les non-vues. Mon avatar en premier, avec un « + » pour
/// publier (même quand j'ai déjà une story active). Se replie en barre compacte au défilement
/// ([collapsed], piloté par le `ScrollController` de `feed_screen.dart`).
class StoryRail extends ConsumerWidget {
  final bool collapsed;
  final VoidCallback onExpand;

  const StoryRail({
    super.key,
    this.collapsed = false,
    required this.onExpand,
  });

  /// Hauteur du rail déplié : marge verticale (2 × 8) + anneau (60) + écart (6)
  /// + la ligne de libellé, qui grandit avec le réglage d'accessibilité du
  /// système. Elle était figée à 96 px : dès `font_scale = 1.1` le libellé
  /// « Ajouter » débordait de 6 px (constaté sur SM A515F, 2026-08-03).
  /// L'interligne est celui de `_labelStyle`, pas celui du thème : le facteur
  /// était estimé à 1.35 alors que `bodyMedium` en impose 1.55, ce qui laissait
  /// déborder le libellé de 2 px même à `font_scale = 1.0` (SM A515F,
  /// 2026-08-04). `ceilToDouble` absorbe l'arrondi restant.
  static double _railHeight(BuildContext context) {
    final labelHeight = MediaQuery.textScalerOf(context).scale(_labelFontSize) *
        _labelLineHeight;
    return 16 + 60 + 6 + labelHeight.ceilToDouble();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = FeedTokens.of(context);
    final groupsAsync = ref.watch(activeStoriesProvider);
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final railHeight = _railHeight(context);

    return groupsAsync.when(
      loading: () => SizedBox(height: railHeight),
      // En erreur, le rail disparaissait entièrement — et avec lui le seul
      // moyen de publier une story. On garde au moins mon avatar.
      error: (_, __) => SizedBox(
        height: railHeight,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [_MyStoryAvatar(tokens: tokens, myGroup: null)],
        ),
      ),
      data: (groups) {
        // Rien à montrer et personne n'a de story : le rail reste discret
        // (pas de rangée vide qui prend de la place pour rien), sauf pour
        // proposer d'en publier une (mon avatar avec « + »).
        final myGroup =
            groups.where((g) => g.authorId == myUid).firstOrNull;
        final others = groups.where((g) => g.authorId != myUid).toList();

        return AnimatedCrossFade(
          duration: const Duration(milliseconds: 220),
          crossFadeState: collapsed
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: SizedBox(
            height: railHeight,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                _MyStoryAvatar(tokens: tokens, myGroup: myGroup),
                ...others.map(
                  (group) => _StoryAvatar(tokens: tokens, group: group),
                ),
              ],
            ),
          ),
          secondChild: _CollapsedStoryBar(
            tokens: tokens,
            groups: groups,
            onTap: onExpand,
          ),
        );
      },
    );
  }
}

/// Barre repliée (§4) : trois avatars superposés + « N récits aujourd'hui »
/// + action « Afficher ».
class _CollapsedStoryBar extends StatelessWidget {
  final FeedTokens tokens;
  final List<AuthorStories> groups;
  final VoidCallback onTap;

  const _CollapsedStoryBar({
    required this.tokens,
    required this.groups,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) return const SizedBox.shrink();
    final visible = groups.take(3).toList();
    final l10n = AppLocalizations.of(context)!;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            SizedBox(
              width: 22.0 + (visible.length - 1) * 14,
              height: 26,
              child: Stack(
                children: visible.asMap().entries.map((entry) {
                  final group = entry.value;
                  return Positioned(
                    left: entry.key * 14.0,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: tokens.avatarBg,
                        border: Border.all(color: tokens.bg, width: 1.5),
                      ),
                      clipBehavior: Clip.antiAlias,
                      alignment: Alignment.center,
                      child: (group.authorPhotoUrl != null &&
                              group.authorPhotoUrl!.isNotEmpty)
                          ? CachedNetworkImage(
                              imageUrl: group.authorPhotoUrl!,
                              fit: BoxFit.cover,
                              width: 26,
                              height: 26,
                              errorWidget: (_, __, ___) => Text(
                                group.authorName.isNotEmpty
                                    ? group.authorName[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  color: tokens.avatarFg,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          : Text(
                              group.authorName.isNotEmpty
                                  ? group.authorName[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                color: tokens.avatarFg,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.storiesTodayCount(groups.length),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, color: tokens.mutedText),
              ),
            ),
            Text(
              l10n.storiesShow,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: tokens.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MyStoryAvatar extends ConsumerWidget {
  final FeedTokens tokens;
  final AuthorStories? myGroup;

  const _MyStoryAvatar({required this.tokens, required this.myGroup});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final user = FirebaseAuth.instance.currentUser;
    final hasStory = myGroup != null && myGroup!.stories.isNotEmpty;

    return SizedBox(
      width: 72,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              // Avatar : ouvre mes stories s'il y en a, sinon en crée une.
              GestureDetector(
                onTap: hasStory
                    ? () => context.push('/feed/stories/${myGroup!.authorId}')
                    : () => startStoryCreation(context),
                onLongPress: () => startStoryCreation(context),
                behavior: HitTestBehavior.opaque,
                child: _StoryRing(
                  tokens: tokens,
                  hasUnviewed: myGroup?.hasUnviewed ?? false,
                  photoUrl: myGroup?.authorPhotoUrl ?? user?.photoURL,
                  fallbackInitial:
                      (user?.displayName?.trim().isNotEmpty ?? false)
                          ? user!.displayName!.trim()[0]
                          : '?',
                ),
              ),
              // « + » TOUJOURS là. Il disparaissait dès la première story :
              // l'avatar ouvrait alors le viewer, et plus rien ne permettait
              // d'en publier une deuxième (signalé 2026-09-12).
              Positioned(
                right: -6,
                bottom: -6,
                child: Semantics(
                  button: true,
                  label: 'Ajouter une story',
                  child: GestureDetector(
                    onTap: () => startStoryCreation(context),
                    behavior: HitTestBehavior.opaque,
                    // Zone de 30 px autour d'une pastille de 22 : la pastille
                    // seule était sous la taille minimale d'une cible tactile.
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: tokens.accent,
                          shape: BoxShape.circle,
                          border: Border.all(color: tokens.bg, width: 2),
                        ),
                        child: const Icon(
                          Icons.add,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            hasStory ? 'Ma story' : l10n.add,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _labelStyle(tokens),
          ),
        ],
      ),
    );
  }
}

class _StoryAvatar extends StatelessWidget {
  final FeedTokens tokens;
  final AuthorStories group;

  const _StoryAvatar({required this.tokens, required this.group});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/feed/stories/${group.authorId}'),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            _StoryRing(
              tokens: tokens,
              hasUnviewed: group.hasUnviewed,
              photoUrl: group.authorPhotoUrl,
              fallbackInitial:
                  group.authorName.isNotEmpty ? group.authorName[0] : '?',
            ),
            const SizedBox(height: 6),
            Text(
              group.authorName.split(' ').first,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _labelStyle(tokens),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryRing extends StatelessWidget {
  final FeedTokens tokens;
  final bool hasUnviewed;
  final String? photoUrl;
  final String fallbackInitial;

  const _StoryRing({
    required this.tokens,
    required this.hasUnviewed,
    required this.photoUrl,
    required this.fallbackInitial,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: hasUnviewed
            ? LinearGradient(colors: [tokens.accent, tokens.accent2])
            : null,
        border: hasUnviewed
            ? null
            : Border.all(color: tokens.divider, width: 1.5),
      ),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(shape: BoxShape.circle, color: tokens.bg),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: tokens.avatarBg,
          ),
          clipBehavior: Clip.antiAlias,
          alignment: Alignment.center,
          child: (photoUrl != null && photoUrl!.isNotEmpty)
              ? CachedNetworkImage(
                  imageUrl: photoUrl!,
                  fit: BoxFit.cover,
                  width: 52,
                  height: 52,
                  errorWidget: (_, __, ___) => _initial(),
                )
              : _initial(),
        ),
      ),
    );
  }

  Widget _initial() => Text(
        fallbackInitial.toUpperCase(),
        style: TextStyle(
          color: tokens.avatarFg,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      );
}
