import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/image_upload_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../stories/domain/entities/story_entity.dart';
import '../../../stories/presentation/providers/story_provider.dart';
import '../theme/feed_tokens.dart';

/// Rail de stories/actus (§4) — cercles d'avatars en haut du fil, anneau
/// accent pour les non-vues. Mon avatar en premier, avec « + » si je n'ai
/// pas de story active.
class StoryRail extends ConsumerWidget {
  const StoryRail({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = FeedTokens.of(context);
    final groupsAsync = ref.watch(activeStoriesProvider);
    final myUid = FirebaseAuth.instance.currentUser?.uid;

    return groupsAsync.when(
      loading: () => const SizedBox(height: 96),
      error: (_, __) => const SizedBox.shrink(),
      data: (groups) {
        // Rien à montrer et personne n'a de story : le rail reste discret
        // (pas de rangée vide qui prend de la place pour rien), sauf pour
        // proposer d'en publier une (mon avatar avec « + »).
        final myGroup =
            groups.where((g) => g.authorId == myUid).firstOrNull;
        final others = groups.where((g) => g.authorId != myUid).toList();

        return SizedBox(
          height: 96,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              _MyStoryAvatar(tokens: tokens, myGroup: myGroup),
              ...others.map(
                (group) => _StoryAvatar(tokens: tokens, group: group),
              ),
            ],
          ),
        );
      },
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
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;

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
          authorName: profile?.displayName ?? user.displayName ?? 'Vous',
          authorPhotoUrl: profile?.photoUrl ?? user.photoURL,
          mediaUrl: url,
          mediaType: StoryMediaType.image,
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              hasStory ? 'Ma story' : 'Ajouter',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, color: tokens.mutedText),
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
              style: TextStyle(fontSize: 11.5, color: tokens.mutedText),
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
