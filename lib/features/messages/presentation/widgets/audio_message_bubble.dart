import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/audio_playback_service.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../domain/entities/message_entity.dart';

/// Widget for displaying audio message with animated waveform visualization
class AudioMessageBubble extends StatefulWidget {
  final MessageEntity message;
  final bool isMe;

  const AudioMessageBubble({
    super.key,
    required this.message,
    required this.isMe,
  });

  @override
  State<AudioMessageBubble> createState() => _AudioMessageBubbleState();
}

class _AudioMessageBubbleState extends State<AudioMessageBubble>
    with TickerProviderStateMixin {
  final AudioPlaybackService _playbackService = AudioPlaybackService();
  late StreamSubscription<PlayerState> _playerStateSubscription;
  late StreamSubscription<Duration> _positionSubscription;

  // Playback state
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  String? _error;

  // Playback speed
  double _playbackSpeed = 1.0;
  static const List<double> _speedOptions = [1.0, 1.5, 2.0];

  // Animations
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _waveAnimationController;

  // Store status listener for cleanup
  late void Function(AnimationStatus) _pulseStatusListener;

  @override
  void initState() {
    super.initState();
    _setupListeners();
    _totalDuration = Duration(seconds: widget.message.audioDuration ?? 0);
    _setupAnimations();
  }

  void _setupAnimations() {
    // Pulse animation for play button
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    // Store the listener reference for cleanup in dispose
    _pulseStatusListener = (status) {
      if (status == AnimationStatus.completed) {
        _pulseController.reverse();
      } else if (status == AnimationStatus.dismissed && _isPlaying) {
        _pulseController.forward();
      }
    };
    _pulseController.addStatusListener(_pulseStatusListener);

    // Waveform animation
    _waveAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  void _setupListeners() {
    _playerStateSubscription =
        _playbackService.playerStateStream.listen((state) {
      if (!mounted) return;

      final isThisMessage =
          _playbackService.currentlyPlayingUrl == widget.message.fileUrl;

      setState(() {
        _isLoading =
            isThisMessage && state.processingState == ProcessingState.loading;
        _isPlaying = isThisMessage && state.playing;

        if (state.processingState == ProcessingState.completed &&
            isThisMessage) {
          _currentPosition = Duration.zero;
          _isPlaying = false;
          _pulseController.stop();
          _pulseController.reset();
        }
      });

      // Control pulse animation
      if (_isPlaying) {
        _pulseController.forward();
      } else {
        _pulseController.stop();
        _pulseController.reset();
      }
    });

    _positionSubscription = _playbackService.positionStream.listen((position) {
      if (!mounted) return;

      if (_playbackService.currentlyPlayingUrl == widget.message.fileUrl) {
        setState(() {
          _currentPosition = position;
          if (_playbackService.duration != null) {
            _totalDuration = _playbackService.duration!;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _playerStateSubscription.cancel();
    _positionSubscription.cancel();
    // Remove status listener before disposing to prevent memory leaks
    _pulseController.removeStatusListener(_pulseStatusListener);
    _pulseController.dispose();
    _waveAnimationController.dispose();
    super.dispose();
  }

  Future<void> _togglePlayPause() async {
    if (widget.message.fileUrl == null) return;

    setState(() {
      _error = null;
    });

    try {
      await _playbackService.togglePlayPause(widget.message.fileUrl!);
    } catch (e) {
      setState(() {
        _error = 'Erreur de lecture';
        _isPlaying = false;
        _isLoading = false;
      });
    }
  }

  void _cyclePlaybackSpeed() {
    HapticFeedback.lightImpact();
    final currentIndex = _speedOptions.indexOf(_playbackSpeed);
    final nextIndex = (currentIndex + 1) % _speedOptions.length;
    setState(() {
      _playbackSpeed = _speedOptions[nextIndex];
    });
    _playbackService.setSpeed(_playbackSpeed);
  }

  void _onWaveformTap(TapDownDetails details, double width) {
    if (_totalDuration.inMilliseconds == 0) return;

    HapticFeedback.selectionClick();
    final tapPosition = details.localPosition.dx;
    final progress = tapPosition / width;
    final seekPosition = Duration(
      milliseconds: (_totalDuration.inMilliseconds * progress).round(),
    );
    _playbackService.seek(seekPosition);
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor =
        widget.isMe ? AppColors.white : context.adaptivePrimaryColor;
    final secondaryColor =
        widget.isMe
            ? AppColors.white.withValues(alpha: 0.7)
            : context.textSecondaryColor;

    return Container(
      constraints: const BoxConstraints(maxWidth: 280, minWidth: 220),
      padding: const EdgeInsets.all(10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated Play/Pause button with pulse
          _buildPlayButton(primaryColor),
          const SizedBox(width: 10),
          // Waveform and controls
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Interactive waveform visualization
                _buildInteractiveWaveform(primaryColor, secondaryColor),
                const SizedBox(height: 6),
                // Duration and speed control
                _buildControlsRow(secondaryColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayButton(Color color) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _isPlaying ? _pulseAnimation.value : 1.0,
          child: child,
        );
      },
      child: GestureDetector(
        onTap: _togglePlayPause,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            boxShadow:
                _isPlaying
                    ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.3),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ]
                    : null,
          ),
          child:
              _isLoading
                  ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: color,
                    ),
                  )
                  : Icon(
                    _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: color,
                    size: 28,
                  ),
        ),
      ),
    );
  }

  Widget _buildInteractiveWaveform(Color primaryColor, Color secondaryColor) {
    final waveform = widget.message.audioWaveform;
    final progress =
        _totalDuration.inMilliseconds > 0
            ? _currentPosition.inMilliseconds / _totalDuration.inMilliseconds
            : 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTapDown: (details) => _onWaveformTap(details, constraints.maxWidth),
          onHorizontalDragUpdate: (details) {
            _onWaveformTap(
              TapDownDetails(localPosition: details.localPosition),
              constraints.maxWidth,
            );
          },
          child: SizedBox(
            height: 36,
            child:
                (waveform != null && waveform.isNotEmpty)
                    ? CustomPaint(
                      painter: _AnimatedWaveformPainter(
                        waveform: waveform,
                        progress: progress,
                        activeColor: primaryColor,
                        inactiveColor: secondaryColor.withValues(alpha: 0.4),
                        isPlaying: _isPlaying,
                        animationValue:
                            _isPlaying
                                ? (DateTime.now().millisecondsSinceEpoch % 1000) /
                                    1000
                                : 0,
                      ),
                      size: Size(constraints.maxWidth, 36),
                    )
                    : _buildSimpleProgressBar(progress, primaryColor, secondaryColor),
          ),
        );
      },
    );
  }

  Widget _buildSimpleProgressBar(
    double progress,
    Color primaryColor,
    Color secondaryColor,
  ) {
    return Container(
      height: 36,
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          // Background track
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: secondaryColor.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Progress
          FractionallySizedBox(
            widthFactor: progress.clamp(0.0, 1.0),
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Thumb
          Positioned(
            left: (progress.clamp(0.0, 1.0) * 200) - 6,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: primaryColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.3),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsRow(Color color) {
    final displayDuration =
        _isPlaying || _currentPosition > Duration.zero
            ? _currentPosition
            : _totalDuration;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Duration text
        Text(
          _formatDuration(displayDuration),
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),

        // Error or controls
        if (_error != null)
          Text(
            _error!,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.red,
            ),
          )
        else
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Speed control button
              GestureDetector(
                onTap: _cyclePlaybackSpeed,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_playbackSpeed}x',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ),
              if (_isPlaying) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.volume_up_rounded,
                  size: 16,
                  color: color,
                ),
              ],
            ],
          ),
      ],
    );
  }
}

/// Custom painter for animated waveform visualization
class _AnimatedWaveformPainter extends CustomPainter {
  final List<double> waveform;
  final double progress;
  final Color activeColor;
  final Color inactiveColor;
  final bool isPlaying;
  final double animationValue;

  _AnimatedWaveformPainter({
    required this.waveform,
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
    required this.isPlaying,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (waveform.isEmpty) return;

    final barWidth = 3.0;
    final gap = 2.0;
    final totalBarWidth = barWidth + gap;
    final barCount = (size.width / totalBarWidth).floor();

    // Sample waveform data to fit the available bars
    final step = waveform.length / barCount;

    for (int i = 0; i < barCount; i++) {
      final sampleIndex = (i * step).floor().clamp(0, waveform.length - 1);
      var amplitude = waveform[sampleIndex].clamp(0.1, 1.0);

      // Add subtle animation when playing
      if (isPlaying) {
        final barProgress = i / barCount;
        if (barProgress <= progress + 0.05 && barProgress >= progress - 0.05) {
          // Animate bars near the current position
          amplitude *= 1.0 + 0.3 * math.sin(animationValue * math.pi * 2 + i * 0.5);
        }
      }

      final barHeight = amplitude * size.height * 0.85;
      final x = i * totalBarWidth;
      final y = (size.height - barHeight) / 2;

      final isActive = i / barCount <= progress;
      final paint =
          Paint()
            ..color = isActive ? activeColor : inactiveColor
            ..style = PaintingStyle.fill;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        const Radius.circular(1.5),
      );
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AnimatedWaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.waveform != waveform ||
        oldDelegate.isPlaying != isPlaying ||
        oldDelegate.animationValue != animationValue;
  }
}
