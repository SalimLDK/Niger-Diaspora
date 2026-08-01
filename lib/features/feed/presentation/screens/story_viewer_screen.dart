import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:video_player/video_player.dart';

import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../stories/domain/entities/story_entity.dart';
import '../../../stories/presentation/providers/story_provider.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

/// Viewer plein écran d'un auteur de stories (§4). Barre de progression
/// segmentée, auto-avance (5s photo / durée réelle vidéo), tap gauche/droite,
/// swipe vers le bas = fermer. Passe à l'auteur suivant (ordre du rail) en
/// fin de dernière story, sinon ferme. « N vues » (auteur uniquement) ouvre
/// la liste détaillée en mettant la lecture en pause.
class StoryViewerScreen extends ConsumerStatefulWidget {
  final String authorId;

  const StoryViewerScreen({super.key, required this.authorId});

  @override
  ConsumerState<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends ConsumerState<StoryViewerScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressController;
  VideoPlayerController? _videoController;
  int _index = 0;
  bool _paused = false;
  static const _segmentDuration = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: _segmentDuration,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) _next();
      });
  }

  @override
  void dispose() {
    _progressController.dispose();
    _videoController?.removeListener(_onVideoTick);
    _videoController?.dispose();
    super.dispose();
  }

  void _startSegment(StoryEntity story) {
    _videoController?.removeListener(_onVideoTick);
    _videoController?.dispose();
    _videoController = null;
    _progressController.stop();
    _progressController.value = 0;
    _paused = false;

    if (story.mediaType == StoryMediaType.video) {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(story.mediaUrl),
      );
      _videoController = controller;
      controller.addListener(_onVideoTick);
      controller.initialize().then((_) {
        if (!mounted || _videoController != controller) return;
        controller.play();
        setState(() {});
      });
    } else {
      _progressController
        ..duration = _segmentDuration
        ..forward();
    }
    ref.read(storyActionsNotifierProvider.notifier).markViewed(story.id);
  }

  void _onVideoTick() {
    final c = _videoController;
    if (c == null || !c.value.isInitialized || !mounted) return;
    final duration = c.value.duration;
    if (duration.inMilliseconds <= 0) return;
    final value = c.value.position.inMilliseconds / duration.inMilliseconds;
    setState(() => _progressController.value = value.clamp(0, 1));
    if (!c.value.isPlaying &&
        c.value.position >= duration - const Duration(milliseconds: 200)) {
      c.removeListener(_onVideoTick);
      _next();
    }
  }

  void _pause() {
    if (_paused) return;
    _paused = true;
    _progressController.stop();
    _videoController?.pause();
  }

  void _resume() {
    if (!_paused) return;
    _paused = false;
    if (_videoController != null) {
      _videoController!.play();
    } else {
      _progressController.forward();
    }
  }

  void _next() {
    final groups = ref.read(activeStoriesProvider).valueOrNull ?? const [];
    final group = groups.where((g) => g.authorId == widget.authorId).firstOrNull;
    if (group == null) {
      if (mounted) context.pop();
      return;
    }
    if (_index < group.stories.length - 1) {
      setState(() => _index++);
      _startSegment(group.stories[_index]);
      return;
    }
    // Fin des stories de cet auteur : auteur suivant du rail, sinon fermer.
    final authorIds = groups.map((g) => g.authorId).toList();
    final myPos = authorIds.indexOf(widget.authorId);
    if (myPos != -1 && myPos < authorIds.length - 1) {
      context.pushReplacement('/feed/stories/${authorIds[myPos + 1]}');
      return;
    }
    if (mounted) context.pop();
  }

  void _previous() {
    if (_index > 0) {
      setState(() => _index--);
      final groups = ref.read(activeStoriesProvider).valueOrNull ?? const [];
      final group =
          groups.where((g) => g.authorId == widget.authorId).firstOrNull;
      if (group != null) _startSegment(group.stories[_index]);
      return;
    }
    context.pop();
  }

  Future<void> _showViewers(StoryEntity story) async {
    _pause();
    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ViewersSheet(storyId: story.id),
    );
    if (mounted) _resume();
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(activeStoriesProvider);
    final myUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.black,
      body: groupsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
        error: (_, __) => const SizedBox.shrink(),
        data: (groups) {
          final group =
              groups.where((g) => g.authorId == widget.authorId).firstOrNull;
          if (group == null || group.stories.isEmpty) {
            // Story expirée/supprimée entre-temps.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) context.pop();
            });
            return const SizedBox.shrink();
          }
          final safeIndex = _index.clamp(0, group.stories.length - 1);
          final story = group.stories[safeIndex];
          final isMine = story.authorId == myUid;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_videoController == null &&
                !_progressController.isAnimating &&
                _progressController.value == 0) {
              _startSegment(story);
            }
          });

          return GestureDetector(
            onTapUp: (details) {
              final w = MediaQuery.of(context).size.width;
              if (details.globalPosition.dx < w / 3) {
                _previous();
              } else {
                _next();
              }
            },
            onVerticalDragEnd: (details) {
              if ((details.primaryVelocity ?? 0) > 200) context.pop();
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                _StoryMedia(story: story, videoController: _videoController),
                SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                        child: Row(
                          children: List.generate(group.stories.length, (i) {
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: LinearProgressIndicator(
                                    minHeight: 2.5,
                                    backgroundColor:
                                        Colors.white.withValues(alpha: 0.3),
                                    color: Colors.white,
                                    value: i < safeIndex
                                        ? 1
                                        : i > safeIndex
                                            ? 0
                                            : _progressController.value,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 10, 0),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.white24,
                              backgroundImage: (story.authorPhotoUrl != null &&
                                      story.authorPhotoUrl!.isNotEmpty)
                                  ? CachedNetworkImageProvider(
                                      story.authorPhotoUrl!,
                                    )
                                  : null,
                              child: (story.authorPhotoUrl == null ||
                                      story.authorPhotoUrl!.isEmpty)
                                  ? Text(
                                      story.authorName.isNotEmpty
                                          ? story.authorName[0].toUpperCase()
                                          : '?',
                                      style:
                                          const TextStyle(color: Colors.white),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                story.authorName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              timeago.format(story.createdAt, locale: 'fr'),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 12,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.white),
                              onPressed: () => context.pop(),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // « N vues » pour l'auteur (ouvre la liste détaillée,
                      // met en pause) ; réactions rapides pour les autres.
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: isMine
                            ? _ViewersTap(
                                story: story,
                                onTap: () => _showViewers(story),
                              )
                            : _ReactionBar(storyId: story.id),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StoryMedia extends StatelessWidget {
  final StoryEntity story;
  final VideoPlayerController? videoController;

  const _StoryMedia({required this.story, required this.videoController});

  @override
  Widget build(BuildContext context) {
    if (story.mediaType == StoryMediaType.video) {
      final c = videoController;
      if (c == null || !c.value.isInitialized) {
        return const ColoredBox(
          color: Colors.black,
          child: Center(
            child: CircularProgressIndicator(color: Colors.white54),
          ),
        );
      }
      return FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: c.value.size.width,
          height: c.value.size.height,
          child: VideoPlayer(c),
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: story.mediaUrl,
      fit: BoxFit.cover,
      errorWidget: (_, __, ___) => const ColoredBox(color: Colors.black87),
    );
  }
}

class _ViewersTap extends StatelessWidget {
  final StoryEntity story;
  final VoidCallback onTap;

  const _ViewersTap({required this.story, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black45,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.remove_red_eye_outlined,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              l10n.storyViewersCount(story.viewCount),
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

/// Réactions rapides (§4) — mêmes 6 emojis que les réactions de message,
/// une par personne (retaper le même emoji la retire).
const _quickReactions = ['❤️', '👍', '😂', '😮', '😢', '🙏'];

class _ReactionBar extends ConsumerWidget {
  final String storyId;

  const _ReactionBar({required this.storyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final reactions =
        ref.watch(storyReactionsProvider(storyId)).valueOrNull ?? const [];
    final mine = reactions.where((r) => r.userId == userId).firstOrNull;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: _quickReactions.map((emoji) {
          final isMine = mine?.emoji == emoji;
          return GestureDetector(
            onTap: () => ref
                .read(storyActionsNotifierProvider.notifier)
                .toggleReaction(storyId, emoji),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.all(6),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isMine
                    ? Colors.white.withValues(alpha: 0.25)
                    : Colors.transparent,
              ),
              child: Text(emoji, style: const TextStyle(fontSize: 22)),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ViewersSheet extends ConsumerWidget {
  final String storyId;

  const _ViewersSheet({required this.storyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final viewersAsync = ref.watch(storyViewersProvider(storyId));
    final reactions =
        ref.watch(storyReactionsProvider(storyId)).valueOrNull ?? const [];
    final reactionByUser = {for (final r in reactions) r.userId: r.emoji};

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Flexible(
                child: viewersAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: CircularProgressIndicator(color: Colors.white54),
                    ),
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (viewers) {
                    if (viewers.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          l10n.storyNoViewersYet,
                          style: const TextStyle(color: Colors.white54),
                        ),
                      );
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: viewers.length,
                      itemBuilder: (context, i) => _ViewerRow(
                        viewer: viewers[i],
                        reaction: reactionByUser[viewers[i].viewerId],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ViewerRow extends ConsumerWidget {
  final StoryViewerEntity viewer;
  final String? reaction;

  const _ViewerRow({required this.viewer, this.reaction});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile =
        ref.watch(profileNotifierProvider(viewer.viewerId)).valueOrNull;
    final name = profile?.displayName ?? 'Membre';

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: Colors.white24,
        backgroundImage: (profile?.photoUrl != null &&
                profile!.photoUrl!.isNotEmpty)
            ? CachedNetworkImageProvider(profile.photoUrl!)
            : null,
        child: (profile?.photoUrl == null || profile!.photoUrl!.isEmpty)
            ? Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white),
              )
            : null,
      ),
      title: Text(name, style: const TextStyle(color: Colors.white)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (reaction != null) ...[
            Text(reaction!, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
          ],
          Text(
            timeago.format(viewer.viewedAt, locale: 'fr'),
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
