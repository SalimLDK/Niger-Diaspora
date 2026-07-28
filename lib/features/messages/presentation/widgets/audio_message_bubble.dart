import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/audio_playback_service.dart';
import '../../../../core/services/preferences_service.dart';
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

  /// Vrai dès la première lecture — masque le point « non écouté ».
  /// Initialisé depuis l'état persisté ; les notes que j'envoie n'ont jamais
  /// de point « non écouté ».
  late bool _hasBeenPlayed;

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
    // Mes propres notes n'ont pas de point « non écouté » ; sinon on repart de
    // l'état persisté localement pour ne pas réafficher le point après écoute.
    _hasBeenPlayed = widget.isMe ||
        PreferencesService.instance.isVoiceNotePlayed(widget.message.id);
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
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
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
    _playerStateSubscription = _playbackService.playerStateStream.listen((
      state,
    ) {
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
        final justPlayed = position > Duration.zero && !_hasBeenPlayed;
        setState(() {
          _currentPosition = position;
          if (justPlayed) _hasBeenPlayed = true;
          if (_playbackService.duration != null) {
            _totalDuration = _playbackService.duration!;
          }
        });
        // Persiste l'état « écouté » à la première lecture d'une note reçue.
        if (justPlayed && !widget.isMe) {
          PreferencesService.instance.markVoiceNotePlayed(widget.message.id);
        }
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

  // ── Palette de la bulle audio (cf. handoff « Bulle audio ») ───────────────
  // Vert de bulle : #1B5E32 (clair) / #2D7D46 (sombre).
  Color _accentGreen(bool isDark) =>
      isDark ? const Color(0xFF2D7D46) : const Color(0xFF1B5E32);

  /// Couleur de fond de la bulle qui héberge ce lecteur (pour cercler la
  /// tête de lecture).
  Color _hostBubbleColor(bool isDark) =>
      widget.isMe
          ? _accentGreen(isDark)
          : (isDark ? const Color(0xFF252119) : Colors.white);

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final green = _accentGreen(isDark);

    // Barres/tête lues : vert sur bulle reçue, blanc sur bulle envoyée.
    final Color playedColor = widget.isMe ? AppColors.white : green;
    // Barres non lues : leur teinte distingue un audio déjà écouté d'un audio
    // qui ne l'a pas encore été.
    // • Non écouté → barres vives (accent vert / blanc plus opaque) pour
    //   attirer l'œil.
    // • Écouté → beige/gris neutre atténué (#DDD3C4 clair / #4A423A sombre).
    final Color unplayedColor =
        _hasBeenPlayed
            ? (widget.isMe
                ? AppColors.white.withValues(alpha: 0.35)
                : (isDark
                    ? const Color(0xFF4A423A)
                    : const Color(0xFFDDD3C4)))
            : (widget.isMe
                ? AppColors.white.withValues(alpha: 0.6)
                : green.withValues(alpha: isDark ? 0.55 : 0.45));
    // Lecture : pastille 44 px, verte sur reçue, blanche sur envoyée.
    final Color playBtnBg = widget.isMe ? AppColors.white : green;
    final Color playBtnFg = widget.isMe ? green : AppColors.white;
    final Color textColor =
        widget.isMe
            ? AppColors.white.withValues(alpha: 0.85)
            : context.textSecondaryColor;

    return Container(
      constraints: const BoxConstraints(maxWidth: 250, minWidth: 230),
      padding: const EdgeInsets.all(10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPlayButton(playBtnBg, playBtnFg),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Waveform + pastille de vitesse sur la même ligne.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: _buildInteractiveWaveform(
                        playedColor,
                        unplayedColor,
                        _hostBubbleColor(isDark),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildSpeedPill(playedColor),
                  ],
                ),
                const SizedBox(height: 4),
                _buildControlsRow(textColor, playedColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayButton(Color bg, Color fg) {
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
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: bg.withValues(alpha: 0.35),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child:
              _isLoading
                  ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                  )
                  : Icon(
                    _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: fg,
                    size: 26,
                  ),
        ),
      ),
    );
  }

  Widget _buildSpeedPill(Color color) {
    // 1× → 1,5× → 2× sur la même ligne que la waveform.
    final label =
        _playbackSpeed == _playbackSpeed.roundToDouble()
            ? '${_playbackSpeed.toInt()}×'
            : '${_playbackSpeed.toString().replaceAll('.', ',')}×';
    return GestureDetector(
      onTap: _cyclePlaybackSpeed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildInteractiveWaveform(
    Color playedColor,
    Color unplayedColor,
    Color playheadRing,
  ) {
    final waveform = widget.message.audioWaveform;
    final progress =
        _totalDuration.inMilliseconds > 0
            ? _currentPosition.inMilliseconds / _totalDuration.inMilliseconds
            : 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => _onWaveformTap(details, width),
          onHorizontalDragUpdate: (details) {
            _onWaveformTap(
              TapDownDetails(localPosition: details.localPosition),
              width,
            );
          },
          child: SizedBox(
            height: 36,
            width: double.infinity,
            child: CustomPaint(
              painter: _WaveformPainter(
                waveform: waveform ?? const [],
                progress: progress.clamp(0.0, 1.0),
                playedColor: playedColor,
                unplayedColor: unplayedColor,
                playheadRing: playheadRing,
              ),
              size: Size(width, 36),
            ),
          ),
        );
      },
    );
  }

  Widget _buildControlsRow(Color textColor, Color accentColor) {
    final displayPos =
        _isPlaying || _currentPosition > Duration.zero
            ? _currentPosition
            : Duration.zero;

    return Row(
      children: [
        // « 0:12 / 0:34 »
        Text(
          '${_formatDuration(displayPos)} / ${_formatDuration(_totalDuration)}',
          style: TextStyle(
            fontSize: 11.5,
            color: textColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        // Point vert « non écouté » (disparaît après la première lecture).
        if (!_hasBeenPlayed) ...[
          const SizedBox(width: 6),
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: accentColor,
              shape: BoxShape.circle,
            ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(width: 6),
          Text(
            _error!,
            style: const TextStyle(fontSize: 11, color: Colors.red),
          ),
        ],
      ],
    );
  }
}

/// Waveform statique seekable : 18 barres, tête de lecture + pastille.
class _WaveformPainter extends CustomPainter {
  final List<double> waveform;
  final double progress;
  final Color playedColor;
  final Color unplayedColor;
  final Color playheadRing;

  _WaveformPainter({
    required this.waveform,
    required this.progress,
    required this.playedColor,
    required this.unplayedColor,
    required this.playheadRing,
  });

  static const int _barCount = 18;
  static const double _barWidth = 4;
  static const double _gap = 3.5;

  @override
  void paint(Canvas canvas, Size size) {
    final totalBar = _barWidth + _gap;
    final step = waveform.isEmpty ? 0.0 : waveform.length / _barCount;

    for (int i = 0; i < _barCount; i++) {
      double amplitude;
      if (waveform.isEmpty) {
        // Motif décoratif reproductible quand pas de données d'amplitude.
        amplitude = 0.35 + 0.55 * (0.5 + 0.5 * math.sin(i * 0.9));
      } else {
        final idx = (i * step).floor().clamp(0, waveform.length - 1);
        amplitude = waveform[idx].clamp(0.12, 1.0);
      }

      final barHeight = amplitude * size.height;
      final x = i * totalBar;
      final y = (size.height - barHeight) / 2;

      final barCenter = (x + _barWidth / 2) / size.width;
      final isPlayed = barCenter <= progress;

      final paint =
          Paint()
            ..color = isPlayed ? playedColor : unplayedColor
            ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, _barWidth, barHeight),
          const Radius.circular(2),
        ),
        paint,
      );
    }

    // Tête de lecture : filet 2 px + pastille 8 px cerclée de la bulle.
    if (progress > 0) {
      final px = (progress * size.width).clamp(0.0, size.width);
      final linePaint =
          Paint()
            ..color = playedColor
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(px, 2), Offset(px, size.height - 2), linePaint);

      final cy = size.height / 2;
      canvas.drawCircle(Offset(px, cy), 5, Paint()..color = playheadRing);
      canvas.drawCircle(Offset(px, cy), 4, Paint()..color = playedColor);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter old) {
    return old.progress != progress ||
        old.waveform != waveform ||
        old.playedColor != playedColor ||
        old.unplayedColor != unplayedColor;
  }
}
