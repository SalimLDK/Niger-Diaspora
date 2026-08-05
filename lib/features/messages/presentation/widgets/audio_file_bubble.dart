import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/audio_playback_service.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../domain/entities/message_entity.dart';

/// Compact audio file player (music, podcast, etc.) — Telegram style.
/// No waveform, only filename, duration and a simple progress bar.
class AudioFileBubble extends StatefulWidget {
  final MessageEntity message;
  final bool isMe;

  const AudioFileBubble({
    super.key,
    required this.message,
    required this.isMe,
  });

  @override
  State<AudioFileBubble> createState() => _AudioFileBubbleState();
}

class _AudioFileBubbleState extends State<AudioFileBubble> {
  final AudioPlaybackService _playbackService = AudioPlaybackService();
  late StreamSubscription<PlayerState> _playerStateSubscription;
  late StreamSubscription<Duration> _positionSubscription;

  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  String? _error;

  double _playbackSpeed = 1.0;
  static const List<double> _speedOptions = [1.0, 1.5, 2.0];

  String get _audioUrl => widget.message.fileUrl ?? '';

  @override
  void initState() {
    super.initState();
    _totalDuration = Duration(seconds: widget.message.audioDuration ?? 0);
    _setupListeners();
  }

  void _setupListeners() {
    _playerStateSubscription = _playbackService.playerStateStream.listen((
      state,
    ) {
      if (!mounted) return;

      final isThisMessage = _playbackService.currentlyPlayingUrl == _audioUrl;

      setState(() {
        _isLoading =
            isThisMessage && state.processingState == ProcessingState.loading;
        _isPlaying = isThisMessage && state.playing;

        if (state.processingState == ProcessingState.completed &&
            isThisMessage) {
          _currentPosition = Duration.zero;
          _isPlaying = false;
        }
      });
    });

    _positionSubscription = _playbackService.positionStream.listen((position) {
      if (!mounted) return;

      if (_playbackService.currentlyPlayingUrl == _audioUrl) {
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
    if (_audioUrl.isEmpty) {
      setState(() => _error = 'Audio non disponible');
      return;
    }

    setState(() {
      _error = null;
      _isLoading = true;
    });

    try {
      await _playbackService.togglePlayPause(_audioUrl);
    } catch (e) {
      setState(() {
        _error = 'Lecture impossible';
        _isPlaying = false;
        _isLoading = false;
      });
    }
  }

  void _cyclePlaybackSpeed() {
    HapticFeedback.lightImpact();
    final currentIndex = _speedOptions.indexOf(_playbackSpeed);
    final nextIndex = (currentIndex + 1) % _speedOptions.length;
    setState(() => _playbackSpeed = _speedOptions[nextIndex]);
    _playbackService.setSpeed(_playbackSpeed);
  }

  void _onSeek(Offset localPosition, double width) {
    if (_totalDuration.inMilliseconds == 0) return;
    HapticFeedback.selectionClick();
    final progress = (localPosition.dx / width).clamp(0.0, 1.0);
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

    final displayDuration =
        _isPlaying || _currentPosition > Duration.zero
            ? _currentPosition
            : _totalDuration;

    return Container(
      constraints: const BoxConstraints(maxWidth: 280, minWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _buildPlayButton(primaryColor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.audiotrack_rounded,
                          size: 18,
                          color: primaryColor,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            widget.message.fileName ??
                                widget.message.fileUrl?.split('/').last ??
                                'Audio',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDuration(displayDuration),
                      style: TextStyle(
                        fontSize: 12,
                        color: secondaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildProgressBar(primaryColor, secondaryColor),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _error!,
                style: const TextStyle(fontSize: 11, color: Colors.red),
              ),
            ),
          const SizedBox(height: 6),
          _buildControlsRow(secondaryColor),
        ],
      ),
    );
  }

  Widget _buildPlayButton(Color color) {
    return GestureDetector(
      onTap: _togglePlayPause,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child:
            _isLoading
                ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: CircularProgressIndicator(strokeWidth: 2, color: color),
                )
                : Icon(
                  _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: color,
                  size: 26,
                ),
      ),
    );
  }

  Widget _buildProgressBar(Color primaryColor, Color secondaryColor) {
    final progress =
        _totalDuration.inMilliseconds > 0
            ? _currentPosition.inMilliseconds / _totalDuration.inMilliseconds
            : 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTapDown: (details) => _onSeek(details.localPosition, constraints.maxWidth),
          onHorizontalDragUpdate: (details) => _onSeek(
            details.localPosition,
            constraints.maxWidth,
          ),
          child: SizedBox(
            height: 16,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: secondaryColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
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
                Positioned(
                  left: (progress.clamp(0.0, 1.0) * constraints.maxWidth) - 6,
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
          ),
        );
      },
    );
  }

  Widget _buildControlsRow(Color color) {
    // L'heure et l'accusé de réception ont quitté cette ligne : ils sont posés
    // sous la bulle par MessageBubble (fiches 4a/6b).
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: _cyclePlaybackSpeed,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
      ],
    );
  }
}
