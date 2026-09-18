import 'dart:async';

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
import '../../../stories/presentation/story_creation.dart';
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
    unawaited(_videoController?.dispose());
    super.dispose();
  }

  void _startSegment(StoryEntity story) {
    _videoController?.removeListener(_onVideoTick);
    unawaited(_videoController?.dispose());
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
      unawaited(controller.initialize().then((_) {
        if (!mounted || _videoController != controller) return;
        unawaited(controller.play());
        setState(() {});
      }));
    } else {
      _progressController.duration = _segmentDuration;
      unawaited(_progressController.forward());
    }
    unawaited(ref.read(storyActionsNotifierProvider.notifier).markViewed(story.id));
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
    unawaited(_videoController?.pause());
  }

  void _resume() {
    if (!_paused) return;
    _paused = false;
    if (_videoController != null) {
      unawaited(_videoController!.play());
    } else {
      unawaited(_progressController.forward());
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

  /// « expire dans 14 h » / « expire dans 20 min ».
  static String _resteEnLigne(StoryEntity story) {
    final reste = story.expiresAt.difference(DateTime.now());
    if (reste.inMinutes < 1) return 'expire bientôt';
    if (reste.inHours < 1) return 'expire dans ${reste.inMinutes} min';
    return 'expire dans ${reste.inHours} h';
  }

  /// Arrête la lecture en cours pour que le prochain rendu reparte du début
  /// du segment affiché (après une suppression, le segment a changé).
  void _resetPlayback() {
    _videoController?.removeListener(_onVideoTick);
    unawaited(_videoController?.dispose());
    _videoController = null;
    _progressController.stop();
    _progressController.value = 0;
    _paused = false;
  }

  Future<void> _onMenu(String action, StoryEntity story) async {
    switch (action) {
      case 'add':
        await startStoryCreation(context);
      case 'privacy':
        await context.push('/feed/stories/privacy');
      case 'delete':
        await _deleteStory(story);
        return; // La lecture repart d'elle-même sur le segment suivant.
    }
    if (mounted) _resume();
  }

  Future<void> _deleteStory(StoryEntity story) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer cette story ?'),
        content: const Text(
          'Elle disparaît tout de suite pour toutes les personnes qui '
          'pouvaient la voir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              l10n.delete,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (confirmed != true) {
      _resume();
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final echec = await ref
        .read(storyActionsNotifierProvider.notifier)
        .deleteStory(story.id);
    if (!mounted) return;
    if (echec != null) {
      messenger.showSnackBar(
        SnackBar(content: Text(echec), backgroundColor: Colors.red),
      );
      _resume();
      return;
    }
    messenger.showSnackBar(const SnackBar(content: Text('Story supprimée')));
    // La liste est relue ; s'il ne reste rien, le viewer se referme de
    // lui-même (voir `build`). Sinon on repart sur le segment qui a pris la
    // place de la story supprimée.
    setState(_resetPlayback);
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
            // Appui long : pause, relâcher : reprise. Sans ça, une story se
            // refermait avant qu'on ait fini de la regarder, sans aucun moyen
            // de la retenir (signalé 2026-09-13).
            onLongPressStart: (_) => _pause(),
            onLongPressEnd: (_) => _resume(),
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
                // Voile sombre en haut : la barre blanche et le nom restaient
                // illisibles sur une photo claire.
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 160,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.black54, Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                        // AnimatedBuilder : la barre lisait
                        // `_progressController.value` pendant un `build` que
                        // rien ne relançait pour une photo (seule la vidéo
                        // appelait `setState`). Elle restait vide les 5 s,
                        // puis la story se fermait : « le minuteur des
                        // stories n'est pas visible » (2026-09-13).
                        child: AnimatedBuilder(
                          animation: _progressController,
                          builder: (context, _) => Row(
                            children: List.generate(group.stories.length, (i) {
                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(2),
                                    child: LinearProgressIndicator(
                                      minHeight: 3,
                                      backgroundColor:
                                          Colors.white.withValues(alpha: 0.35),
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
                              // Mes stories : combien de temps elles restent
                              // en ligne, pas seulement depuis quand.
                              isMine
                                  ? '${timeago.format(story.createdAt, locale: 'fr')} · ${_resteEnLigne(story)}'
                                  : timeago.format(story.createdAt, locale: 'fr'),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 12,
                              ),
                            ),
                            // Mes stories : ajouter, choisir qui voit,
                            // supprimer. Rien de tout ça n'existait — une
                            // story publiée ne se retirait plus.
                            if (isMine)
                              PopupMenuButton<String>(
                                icon: const Icon(
                                  Icons.more_vert,
                                  color: Colors.white,
                                ),
                                onOpened: _pause,
                                onCanceled: _resume,
                                onSelected: (a) => _onMenu(a, story),
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'add',
                                    child: ListTile(
                                      leading: Icon(Icons.add_circle_outline),
                                      title: Text('Ajouter une story'),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'privacy',
                                    child: ListTile(
                                      leading: Icon(Icons.lock_outline),
                                      title: Text('Qui peut voir mes stories'),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: ListTile(
                                      leading: Icon(
                                        Icons.delete_outline,
                                        color: Colors.red,
                                      ),
                                      title: Text(
                                        'Supprimer cette story',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ],
                              ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.white),
                              onPressed:
                                  () => context.canPop() ? context.pop() : context.go('/feed'),
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
            // L'audience de CETTE story, pour que l'auteur sache à qui il
            // l'a montrée sans rouvrir quoi que ce soit.
            const SizedBox(width: 10),
            Icon(storyAudienceIcon(story.audience), color: Colors.white70, size: 14),
            const SizedBox(width: 4),
            Text(
              story.audience.label,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
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
    final l10n = AppLocalizations.of(context)!;
    final profile =
        ref.watch(profileNotifierProvider(viewer.viewerId)).valueOrNull;
    final name = profile?.displayName ?? l10n.member;

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
