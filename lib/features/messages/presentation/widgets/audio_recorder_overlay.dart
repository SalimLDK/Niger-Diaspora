import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/audio_recording_service.dart';
import '../../../../core/theme/adaptive_colors.dart';

/// Overlay widget for recording audio messages
/// Appears when user holds the microphone button
class AudioRecorderOverlay extends StatefulWidget {
  final VoidCallback onCancel;
  final VoidCallback onSend;
  final double dragOffset;
  final bool isCancelling;

  const AudioRecorderOverlay({
    super.key,
    required this.onCancel,
    required this.onSend,
    this.dragOffset = 0,
    this.isCancelling = false,
  });

  @override
  State<AudioRecorderOverlay> createState() => _AudioRecorderOverlayState();
}

class _AudioRecorderOverlayState extends State<AudioRecorderOverlay>
    with SingleTickerProviderStateMixin {
  final AudioRecordingService _recordingService = AudioRecordingService();
  late AnimationController _pulseController;
  late StreamSubscription<int> _durationSubscription;
  late StreamSubscription<double> _amplitudeSubscription;

  int _duration = 0;
  double _currentAmplitude = 0.3;
  final List<double> _amplitudeHistory = [];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _durationSubscription =
        _recordingService.durationStream.listen((duration) {
      if (mounted) {
        setState(() => _duration = duration);
      }
    });

    _amplitudeSubscription =
        _recordingService.amplitudeStream.listen((amplitude) {
      if (mounted) {
        setState(() {
          _currentAmplitude = amplitude;
          _amplitudeHistory.add(amplitude);
          if (_amplitudeHistory.length > 50) {
            _amplitudeHistory.removeAt(0);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _durationSubscription.cancel();
    _amplitudeSubscription.cancel();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final cancelProgress = (widget.dragOffset.abs() / 100).clamp(0.0, 1.0);
    final showCancelHint = widget.dragOffset < -30;

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: widget.isCancelling
            ? Colors.red.withValues(alpha: 0.1)
            : context.surfaceColor,
        boxShadow: context.isDarkMode
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
      ),
      child: Row(
        children: [
          // Cancel hint (slides in from left)
          AnimatedOpacity(
            duration: const Duration(milliseconds: 150),
            opacity: showCancelHint ? 1.0 : 0.0,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.arrow_back,
                  color: Colors.red.withValues(alpha: cancelProgress),
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  'Glissez pour annuler',
                  style: TextStyle(
                    color: Colors.red.withValues(alpha: cancelProgress),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Recording indicator and duration
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Pulsing red dot
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.red.withValues(
                        alpha: 0.5 + (_pulseController.value * 0.5),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Duration
                  Text(
                    _formatDuration(_duration),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: widget.isCancelling
                          ? Colors.red
                          : context.textPrimaryColor,
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(width: 16),

          // Waveform visualization
          Expanded(
            child: SizedBox(
              height: 32,
              child: CustomPaint(
                painter: _LiveWaveformPainter(
                  amplitudeHistory: _amplitudeHistory,
                  currentAmplitude: _currentAmplitude,
                  color: widget.isCancelling
                      ? Colors.red
                      : context.adaptivePrimaryColor,
                ),
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Microphone icon (animated)
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final scale = 1.0 + (_currentAmplitude * 0.3);
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: widget.isCancelling
                        ? Colors.red
                        : context.adaptivePrimaryColor,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    widget.isCancelling ? Icons.delete : Icons.mic,
                    color: AppColors.white,
                    size: 24,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Painter for live waveform during recording
class _LiveWaveformPainter extends CustomPainter {
  final List<double> amplitudeHistory;
  final double currentAmplitude;
  final Color color;

  _LiveWaveformPainter({
    required this.amplitudeHistory,
    required this.currentAmplitude,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (amplitudeHistory.isEmpty) {
      // Draw placeholder bars
      final barCount = 30;
      final barWidth = 3.0;
      final gap = (size.width - barCount * barWidth) / (barCount - 1);

      final paint = Paint()
        ..color = color.withValues(alpha: 0.3)
        ..style = PaintingStyle.fill;

      for (int i = 0; i < barCount; i++) {
        final x = i * (barWidth + gap);
        final barHeight = size.height * 0.2;
        final y = (size.height - barHeight) / 2;

        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, barHeight),
          const Radius.circular(1.5),
        );
        canvas.drawRRect(rect, paint);
      }
      return;
    }

    final barWidth = 3.0;
    final gap = 2.0;
    final totalBarWidth = barWidth + gap;
    final barCount = (size.width / totalBarWidth).floor();

    // Take the last N samples to fill the width
    final samplesToShow = amplitudeHistory.length > barCount
        ? amplitudeHistory.sublist(amplitudeHistory.length - barCount)
        : amplitudeHistory;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (int i = 0; i < samplesToShow.length; i++) {
      final amplitude = samplesToShow[i].clamp(0.1, 1.0);
      final barHeight = amplitude * size.height * 0.8;

      // Position from right to left (newest on right)
      final x = size.width - ((samplesToShow.length - i) * totalBarWidth);
      final y = (size.height - barHeight) / 2;

      if (x >= 0) {
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, barHeight),
          const Radius.circular(1.5),
        );
        canvas.drawRRect(rect, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LiveWaveformPainter oldDelegate) {
    return oldDelegate.amplitudeHistory.length != amplitudeHistory.length ||
        oldDelegate.currentAmplitude != currentAmplitude;
  }
}
