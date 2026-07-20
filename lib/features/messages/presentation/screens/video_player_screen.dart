import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../../../core/theme/adaptive_colors.dart';
import '../../../../l10n/app_localizations.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';

/// Écran de lecture vidéo plein écran (style WhatsApp)
class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String? senderName;
  final DateTime? timestamp;
  final String? caption;
  final Duration? initialPosition;

  const VideoPlayerScreen({
    super.key,
    required this.videoUrl,
    this.senderName,
    this.timestamp,
    this.caption,
    this.initialPosition,
  });

  static Future<void> show(
    BuildContext context, {
    required String videoUrl,
    String? senderName,
    DateTime? timestamp,
    String? caption,
    Duration? initialPosition,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(
          videoUrl: videoUrl,
          senderName: senderName,
          timestamp: timestamp,
          caption: caption,
          initialPosition: initialPosition,
        ),
      ),
    );
  }

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen>
    with SingleTickerProviderStateMixin {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _showControls = true;
  bool _isSaving = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  late AnimationController _controlsAnimationController;
  late Animation<double> _controlsAnimation;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
    _setupControlsAnimation();

    // Mode plein écran
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  void _setupControlsAnimation() {
    _controlsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _controlsAnimation = CurvedAnimation(
      parent: _controlsAnimationController,
      curve: Curves.easeOut,
    );
    _controlsAnimationController.forward();
  }

  Future<void> _initializeVideo() async {
    if (widget.videoUrl.startsWith('http')) {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    } else {
      _controller = VideoPlayerController.file(File(widget.videoUrl));
    }

    try {
      await _controller.initialize();
      _controller.addListener(_videoListener);

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _duration = _controller.value.duration;
        });

        // Seek to initial position if provided
        if (widget.initialPosition != null &&
            widget.initialPosition! < _controller.value.duration) {
          await _controller.seekTo(widget.initialPosition!);
        }

        // Auto-play
        _controller.play();
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.videoPlaybackError),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _videoListener() {
    if (mounted) {
      setState(() {
        _isPlaying = _controller.value.isPlaying;
        _position = _controller.value.position;
      });
    }
  }

  void _togglePlayPause() {
    if (_controller.value.isPlaying) {
      _controller.pause();
    } else {
      if (_position >= _duration) {
        _controller.seekTo(Duration.zero);
      }
      _controller.play();
    }
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });

    if (_showControls) {
      _controlsAnimationController.forward();
      // Auto-hide après 3 secondes
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _isPlaying && _showControls) {
          setState(() => _showControls = false);
          _controlsAnimationController.reverse();
        }
      });
    } else {
      _controlsAnimationController.reverse();
    }
  }

  void _seekTo(Duration position) {
    _controller.seekTo(position);
  }

  Future<void> _saveVideo() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      String filePath;

      if (widget.videoUrl.startsWith('http')) {
        // Télécharger la vidéo
        final response = await http.get(Uri.parse(widget.videoUrl));
        if (response.statusCode == 200) {
          final tempDir = await getTemporaryDirectory();
          filePath = '${tempDir.path}/video_${DateTime.now().millisecondsSinceEpoch}.mp4';
          final file = File(filePath);
          await file.writeAsBytes(response.bodyBytes);
        } else {
          throw Exception('Échec du téléchargement');
        }
      } else {
        filePath = widget.videoUrl;
      }

      // Sauvegarder dans la galerie
      await Gal.putVideo(filePath);

      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.videoSavedToGallery),
            backgroundColor: context.adaptivePrimaryColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.saveVideoError),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _controller.dispose();
    _controlsAnimationController.dispose();

    // Restaurer l'orientation et la barre système
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Vidéo
            Center(
              child: _isInitialized
                  ? AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    )
                  : const CircularProgressIndicator(color: Colors.white),
            ),

            // Overlay de contrôles
            if (_showControls)
              FadeTransition(
                opacity: _controlsAnimation,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.7),
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.7),
                      ],
                      stops: const [0.0, 0.2, 0.8, 1.0],
                    ),
                  ),
                ),
              ),

            // Header avec infos
            if (_showControls)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: FadeTransition(
                  opacity: _controlsAnimation,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const AppIcon(AppIcon.arrowBack, color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (widget.senderName != null)
                                  Text(
                                    widget.senderName!,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                if (widget.timestamp != null)
                                  Text(
                                    _formatDateTime(widget.timestamp!),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          // Bouton sauvegarder
                          IconButton(
                            onPressed: _isSaving ? null : _saveVideo,
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.download, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Bouton play/pause central
            if (_isInitialized)
              Center(
                child: AnimatedOpacity(
                  opacity: _showControls || !_isPlaying ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: GestureDetector(
                    onTap: _togglePlayPause,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isPlaying ? Icons.pause : Icons.play_arrow,
                        size: 48,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),

            // Contrôles du bas (progress bar, temps)
            if (_showControls && _isInitialized)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: FadeTransition(
                  opacity: _controlsAnimation,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Caption
                          if (widget.caption != null && widget.caption!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Text(
                                widget.caption!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),

                          // Progress bar
                          SliderTheme(
                            data: SliderThemeData(
                              activeTrackColor: context.adaptivePrimaryColor,
                              inactiveTrackColor: Colors.white30,
                              thumbColor: context.adaptivePrimaryColor,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6,
                              ),
                              trackHeight: 3,
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 12,
                              ),
                            ),
                            child: Slider(
                              value: _position.inMilliseconds.toDouble(),
                              min: 0,
                              max: _duration.inMilliseconds.toDouble(),
                              onChanged: (value) {
                                _seekTo(Duration(milliseconds: value.toInt()));
                              },
                            ),
                          ),

                          // Temps
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatDuration(_position),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  _formatDuration(_duration),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dt.year, dt.month, dt.day);

    String dateStr;
    if (date == today) {
      dateStr = "Aujourd'hui";
    } else if (date == today.subtract(const Duration(days: 1))) {
      dateStr = 'Hier';
    } else {
      dateStr = '${dt.day}/${dt.month}/${dt.year}';
    }

    final time = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return '$dateStr à $time';
  }
}
