import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../domain/entities/podcast_episode_entity.dart';

/// Inline video player for podcast video episodes.
/// Shows a 16:9 video with play/pause overlay and seek bar.
/// Tapping the fullscreen button navigates to the messages VideoPlayerScreen.
class VideoEpisodePlayer extends StatefulWidget {
  final PodcastEpisodeEntity episode;

  const VideoEpisodePlayer({super.key, required this.episode});

  @override
  State<VideoEpisodePlayer> createState() => _VideoEpisodePlayerState();
}

class _VideoEpisodePlayerState extends State<VideoEpisodePlayer> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  @override
  void didUpdateWidget(VideoEpisodePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.episode.videoUrl != widget.episode.videoUrl) {
      _disposeController();
      _initController();
    }
  }

  Future<void> _initController() async {
    final url = widget.episode.videoUrl;
    if (url == null || url.isEmpty) return;
    final ctrl = VideoPlayerController.networkUrl(Uri.parse(url));
    _controller = ctrl;
    await ctrl.initialize();
    if (mounted) setState(() => _initialized = true);
    // Auto-hide controls after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && (ctrl.value.isPlaying)) {
        setState(() => _showControls = false);
      }
    });
  }

  void _disposeController() {
    _controller?.dispose();
    _controller = null;
    _initialized = false;
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  void _togglePlayPause() {
    final ctrl = _controller;
    if (ctrl == null) return;
    setState(() {
      ctrl.value.isPlaying ? ctrl.pause() : ctrl.play();
      _showControls = true;
    });
    // Auto-hide controls when playing
    if (!ctrl.value.isPlaying) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _controller?.value.isPlaying == true) {
          setState(() => _showControls = false);
        }
      });
    }
  }

  void _toggleControls() => setState(() => _showControls = !_showControls);

  void _openFullscreen() {
    final url = widget.episode.videoUrl;
    if (url == null) return;
    // Pause current before going fullscreen
    _controller?.pause();
    final pos = _controller?.value.position;
    context.push(
      '/messages/video-player',
      extra: {
        'videoUrl': url,
        'caption': widget.episode.title,
        'startPosition': pos?.inMilliseconds ?? 0,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized || _controller == null) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          color: Colors.black,
          child: const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          fit: StackFit.expand,
          children: [
            VideoPlayer(_controller!),
            // Controls overlay
            if (_showControls) ...[
              // Dark overlay
              Container(color: Colors.black26),
              // Centre play/pause
              Center(
                child: GestureDetector(
                  onTap: _togglePlayPause,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Icon(
                      _controller!.value.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              ),
              // Bottom controls: seek + fullscreen
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black87, Colors.transparent],
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: VideoProgressIndicator(
                          _controller!,
                          allowScrubbing: true,
                          colors: const VideoProgressColors(
                            playedColor: Colors.white,
                            bufferedColor: Colors.white38,
                            backgroundColor: Colors.white12,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.fullscreen,
                          color: Colors.white,
                          size: 22,
                        ),
                        onPressed: _openFullscreen,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
