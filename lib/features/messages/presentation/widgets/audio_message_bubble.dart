import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/audio_playback_service.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../domain/entities/message_entity.dart';

/// Widget for displaying audio message with waveform visualization
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

class _AudioMessageBubbleState extends State<AudioMessageBubble> {
  final AudioPlaybackService _playbackService = AudioPlaybackService();
  late StreamSubscription<PlayerState> _playerStateSubscription;
  late StreamSubscription<Duration> _positionSubscription;

  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  String? _error;

  @override
  void initState() {
    super.initState();
    _setupListeners();
    _totalDuration = Duration(seconds: widget.message.audioDuration ?? 0);
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

        if (state.processingState == ProcessingState.completed && isThisMessage) {
          _currentPosition = Duration.zero;
          _isPlaying = false;
        }
      });
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

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor =
        widget.isMe ? AppColors.white : context.adaptivePrimaryColor;
    final secondaryColor = widget.isMe
        ? AppColors.white.withValues(alpha: 0.7)
        : context.textSecondaryColor;

    return Container(
      constraints: const BoxConstraints(maxWidth: 250, minWidth: 200),
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play/Pause button
          _buildPlayButton(primaryColor),
          const SizedBox(width: 8),
          // Waveform and duration
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Waveform visualization
                _buildWaveform(primaryColor, secondaryColor),
                const SizedBox(height: 4),
                // Duration
                _buildDurationText(secondaryColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayButton(Color color) {
    return GestureDetector(
      onTap: _togglePlayPause,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: _isLoading
            ? Padding(
                padding: const EdgeInsets.all(12),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: color,
                ),
              )
            : Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: color,
                size: 28,
              ),
      ),
    );
  }

  Widget _buildWaveform(Color primaryColor, Color secondaryColor) {
    final waveform = widget.message.audioWaveform;
    final progress = _totalDuration.inMilliseconds > 0
        ? _currentPosition.inMilliseconds / _totalDuration.inMilliseconds
        : 0.0;

    // Use actual waveform data if available, otherwise show simple bars
    if (waveform != null && waveform.isNotEmpty) {
      return SizedBox(
        height: 30,
        child: CustomPaint(
          painter: _WaveformPainter(
            waveform: waveform,
            progress: progress,
            activeColor: primaryColor,
            inactiveColor: secondaryColor.withValues(alpha: 0.4),
          ),
          size: const Size(double.infinity, 30),
        ),
      );
    }

    // Simple progress bar fallback
    return Container(
      height: 30,
      alignment: Alignment.center,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: LinearProgressIndicator(
          value: progress,
          backgroundColor: secondaryColor.withValues(alpha: 0.3),
          valueColor: AlwaysStoppedAnimation(primaryColor),
          minHeight: 4,
        ),
      ),
    );
  }

  Widget _buildDurationText(Color color) {
    final displayDuration = _isPlaying || _currentPosition > Duration.zero
        ? _currentPosition
        : _totalDuration;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          _formatDuration(displayDuration),
          style: TextStyle(
            fontSize: 12,
            color: color,
          ),
        ),
        if (_error != null)
          Text(
            _error!,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.red,
            ),
          )
        else if (_isPlaying)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.volume_up,
                size: 14,
                color: color,
              ),
            ],
          ),
      ],
    );
  }
}

/// Custom painter for waveform visualization
class _WaveformPainter extends CustomPainter {
  final List<double> waveform;
  final double progress;
  final Color activeColor;
  final Color inactiveColor;

  _WaveformPainter({
    required this.waveform,
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
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
      final amplitude = waveform[sampleIndex].clamp(0.1, 1.0);
      final barHeight = amplitude * size.height * 0.8;

      final x = i * totalBarWidth;
      final y = (size.height - barHeight) / 2;

      final isActive = i / barCount <= progress;
      final paint = Paint()
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
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.waveform != waveform;
  }
}
