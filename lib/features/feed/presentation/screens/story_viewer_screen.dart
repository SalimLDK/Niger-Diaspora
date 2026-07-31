import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../stories/domain/entities/story_entity.dart';
import '../../../stories/presentation/providers/story_provider.dart';

/// Viewer plein écran d'un auteur de stories (§4). Barre de progression
/// segmentée, auto-avance, tap gauche/droite, swipe vers le bas = fermer.
/// MVP : navigue entre les segments d'UN auteur ; passe à l'auteur suivant
/// (dans l'ordre du rail) en fin de dernière story, sinon ferme.
class StoryViewerScreen extends ConsumerStatefulWidget {
  final String authorId;

  const StoryViewerScreen({super.key, required this.authorId});

  @override
  ConsumerState<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends ConsumerState<StoryViewerScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressController;
  int _index = 0;
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
    super.dispose();
  }

  void _startSegment(StoryEntity story) {
    _progressController
      ..reset()
      ..forward();
    ref.read(storyActionsNotifierProvider.notifier).markViewed(story.id);
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

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(activeStoriesProvider);

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

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_progressController.isAnimating &&
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
                CachedNetworkImage(
                  imageUrl: story.mediaUrl,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => const ColoredBox(
                    color: Colors.black87,
                  ),
                ),
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
