import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/image_upload_service.dart';
import '../../../../core/services/video_upload_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../stories/domain/entities/story_entity.dart';
import '../../../stories/presentation/providers/story_provider.dart';
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
/// accent pour les non-vues. Mon avatar en premier, avec « + » si je n'ai
/// pas de story active. Se replie en barre compacte au défilement
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
      error: (_, __) => const SizedBox.shrink(),
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

  Future<void> _createStory(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: tokens.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_camera_outlined, color: tokens.accent),
              title: Text(l10n.storyTakePhoto),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: Icon(Icons.photo_library_outlined, color: tokens.accent),
              title: Text(l10n.storyChooseFromGallery),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: Icon(Icons.videocam_outlined, color: tokens.accent),
              title: Text(l10n.storyChooseVideo),
              subtitle: Text(
                l10n.storyVideoMaxDuration,
                style: TextStyle(fontSize: 12, color: tokens.mutedText),
              ),
              onTap: () => Navigator.pop(context, 'video'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;

    if (choice == 'video') {
      await _createVideoStory(context, ref);
    } else {
      await _createPhotoStory(context, ref, choice);
    }
  }

  Future<void> _createPhotoStory(
    BuildContext context,
    WidgetRef ref,
    String choice,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final uploadService = ImageUploadService();
    final result = choice == 'camera'
        ? await uploadService.pickImageFromCameraWithResult()
        : await uploadService.pickImageFromGalleryWithResult();
    if (!result.isSuccess || result.file == null) return;
    if (!context.mounted) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final tempId = DateTime.now().millisecondsSinceEpoch.toString();
    final url = await uploadService.uploadImage(
      file: result.file!,
      type: ImageUploadType.story,
      id: tempId,
    );
    if (url == null) return;

    final profile =
        ref.read(profileNotifierProvider(user.uid)).valueOrNull;
    await ref.read(storyActionsNotifierProvider.notifier).createStory(
          authorId: user.uid,
          authorName: profile?.displayName ?? user.displayName ?? l10n.you,
          authorPhotoUrl: profile?.photoUrl ?? user.photoURL,
          mediaUrl: url,
          mediaType: StoryMediaType.image,
        );
  }

  Future<void> _createVideoStory(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final videoService = VideoUploadService();
    final pick = await videoService.pickVideoFromGallery(
      maxDuration: const Duration(seconds: 30),
    );
    if (!pick.isSuccess || pick.file == null) return;
    if (!context.mounted) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final tempId = DateTime.now().millisecondsSinceEpoch.toString();
    final uploadResult = await videoService.uploadStoryVideo(
      file: pick.file!,
      storyId: tempId,
    );
    if (uploadResult == null) return;

    final profile =
        ref.read(profileNotifierProvider(user.uid)).valueOrNull;
    await ref.read(storyActionsNotifierProvider.notifier).createStory(
          authorId: user.uid,
          authorName: profile?.displayName ?? user.displayName ?? l10n.you,
          authorPhotoUrl: profile?.photoUrl ?? user.photoURL,
          mediaUrl: uploadResult.videoUrl,
          mediaType: StoryMediaType.video,
          videoDurationSeconds: uploadResult.durationSeconds,
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final user = FirebaseAuth.instance.currentUser;
    final hasStory = myGroup != null && myGroup!.stories.isNotEmpty;

    return GestureDetector(
      onTap: hasStory
          ? () => context.push('/feed/stories/${myGroup!.authorId}')
          : () => _createStory(context, ref),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                _StoryRing(
                  tokens: tokens,
                  hasUnviewed: myGroup?.hasUnviewed ?? false,
                  photoUrl: myGroup?.authorPhotoUrl ?? user?.photoURL,
                  fallbackInitial: (user?.displayName?.trim().isNotEmpty ?? false)
                      ? user!.displayName!.trim()[0]
                      : '?',
                ),
                if (!hasStory)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: tokens.accent,
                        shape: BoxShape.circle,
                        border: Border.all(color: tokens.bg, width: 2),
                      ),
                      child: const Icon(Icons.add, size: 14, color: Colors.white),
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
