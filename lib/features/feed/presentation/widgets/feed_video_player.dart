import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:diaspo_niger/core/services/video_playback_service.dart';
import 'package:diaspo_niger/features/messages/presentation/screens/video_player_screen.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';

/// Lecteur vidéo inline pour le feed : tap-to-play (pas d'autoplay, économe en
/// data), pause automatique au défilement (<50% visible), et bouton plein écran.
/// S'appuie sur le [VideoPlaybackService] singleton (une seule vidéo active).
class FeedVideoPlayer extends ConsumerStatefulWidget {
  final String videoUrl;
  final String? thumbnailUrl;
  final int? durationSeconds;
  final String postId;

  const FeedVideoPlayer({
    super.key,
    required this.videoUrl,
    required this.postId,
    this.thumbnailUrl,
    this.durationSeconds,
  });

  @override
  ConsumerState<FeedVideoPlayer> createState() => _FeedVideoPlayerState();
}

class _FeedVideoPlayerState extends ConsumerState<FeedVideoPlayer> {
  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString();
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _togglePlay() {
    ref.read(videoPlaybackServiceProvider).play(widget.postId, widget.videoUrl);
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    if (info.visibleFraction < 0.5) {
      final service = ref.read(videoPlaybackServiceProvider);
      if (service.isActiveVideo(widget.postId)) service.stop();
    }
  }

  void _openFullscreen() {
    final service = ref.read(videoPlaybackServiceProvider);
    final pos = service.isActiveVideo(widget.postId) ? service.position : null;
    service.stop();
    VideoPlayerScreen.show(
      context,
      videoUrl: widget.videoUrl,
      initialPosition: pos,
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(videoPlaybackServiceProvider);
    final isActive = service.isActiveVideo(widget.postId);
    final isReady =
        isActive && service.isInitialized && service.controller != null;
    final showPlayIcon = !isReady || !service.isPlaying;

    return VisibilityDetector(
      key: Key('feed_video_${widget.postId}'),
      onVisibilityChanged: _onVisibilityChanged,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: AspectRatio(
          aspectRatio:
              isReady ? service.controller!.value.aspectRatio : 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            alignment: Alignment.center,
            children: [
              if (isReady)
                GestureDetector(
                  onTap: _togglePlay,
                  child: VideoPlayer(service.controller!),
                )
              else
                _buildThumbnail(),
              if (showPlayIcon) _buildPlayButton(),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: _openFullscreen,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.fullscreen,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
              if (!isReady &&
                  widget.durationSeconds != null &&
                  widget.durationSeconds! > 0)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _formatDuration(widget.durationSeconds!),
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    final url = widget.thumbnailUrl;
    return GestureDetector(
      onTap: _togglePlay,
      child: (url != null && url.isNotEmpty)
          ? CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => _placeholder(),
            )
          : _placeholder(),
    );
  }

  Widget _placeholder() => Container(
        color: Colors.black87,
        child: const Center(
          child: AppIcon(AppIcon.video, color: Colors.white54, size: 48),
        ),
      );

  Widget _buildPlayButton() {
    return IgnorePointer(
      child: Center(
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.play_arrow_rounded,
            color: Colors.white,
            size: 36,
          ),
        ),
      ),
    );
  }
}
