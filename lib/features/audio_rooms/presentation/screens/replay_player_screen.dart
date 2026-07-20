import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/theme/dn_colors.dart';
import '../../../../core/theme/dn_text.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/room_replay_entity.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';

/// /audio-rooms/:roomId/replay — replay player with waveform scrubber.
class ReplayPlayerScreen extends ConsumerStatefulWidget {
  final String roomId;
  final RoomReplayEntity? replay;

  const ReplayPlayerScreen({
    super.key,
    required this.roomId,
    this.replay,
  });

  @override
  ConsumerState<ReplayPlayerScreen> createState() => _ReplayPlayerScreenState();
}

class _ReplayPlayerScreenState extends ConsumerState<ReplayPlayerScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  VideoPlayerController? _videoCtrl;
  bool _videoInitialized = false;

  double _progress = 0.35; // 0.0 – 1.0
  bool _isPlaying = false;
  double _playbackSpeed = 1.0;
  int _currentChapter = 2; // 0-based

  // Simulated chapters
  static const _chapters = ['Introduction', 'Actualités', 'Diaspora & politique', 'Q&R', 'Conclusion'];
  // Simulated co-hosts
  static const _coHosts = ['Salim B.', 'Aïcha M.'];

  @override
  void initState() {
    super.initState();
    final videoUrl = widget.replay?.videoUrl;
    if (videoUrl != null && videoUrl.isNotEmpty) {
      _videoCtrl = VideoPlayerController.networkUrl(Uri.parse(videoUrl))
        ..initialize().then((_) {
          if (mounted) setState(() => _videoInitialized = true);
        });
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _videoCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [DNColors.ink, DNColors.terra2],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // App bar
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down,
                          color: DNColors.paper, size: 28,),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Spacer(),
                    Text(AppLocalizations.of(context)!.replayBadge, style: DNText.mono(size: 9, color: DNColors.ink4)),
                    const Spacer(),
                    const SizedBox(width: 40),
                  ],
                ),
              ),

              const Spacer(),

              // Video player or pulsing disc
              if (_videoCtrl != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _videoInitialized
                      ? GestureDetector(
                          onTap: () {
                            setState(() {
                              _videoCtrl!.value.isPlaying
                                  ? _videoCtrl!.pause()
                                  : _videoCtrl!.play();
                              _isPlaying = _videoCtrl!.value.isPlaying;
                            });
                          },
                          child: AspectRatio(
                            aspectRatio: _videoCtrl!.value.aspectRatio,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                VideoPlayer(_videoCtrl!),
                                if (!_isPlaying)
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black45,
                                      borderRadius: BorderRadius.circular(40),
                                    ),
                                    padding: const EdgeInsets.all(12),
                                    child: const Icon(
                                      Icons.play_arrow_rounded,
                                      color: Colors.white,
                                      size: 40,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        )
                      : const SizedBox(
                          height: 180,
                          child: Center(
                            child: CircularProgressIndicator(color: DNColors.terra),
                          ),
                        ),
                )
              else
                AnimatedBuilder(
                  animation: _pulseCtrl,
                  builder: (_, __) => Container(
                    width: 180 + _pulseCtrl.value * 6,
                    height: 180 + _pulseCtrl.value * 6,
                    decoration: BoxDecoration(
                      color: DNColors.terra,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: DNColors.terra.withValues(alpha: 0.4 * _pulseCtrl.value),
                          blurRadius: 30,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: const AppIcon(AppIcon.mic, color: Colors.white, size: 56),
                  ),
                ),
              const SizedBox(height: 24),

              // Chapter info
              Text(
                'Chapitre ${_currentChapter + 1}/${_chapters.length}',
                style: DNText.mono(size: 9, color: DNColors.ink4),
              ),
              const SizedBox(height: 4),
              Text(
                _chapters[_currentChapter],
                style: DNText.serif(size: 22, italic: true, color: DNColors.paper),
              ),
              const SizedBox(height: 4),
              Text(
                _coHosts.join(' · '),
                style: DNText.mono(size: 9, color: DNColors.ink3),
              ),

              const SizedBox(height: 24),

              // Waveform scrubber
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _Waveform(
                  progress: _progress,
                  onSeek: (v) => setState(() => _progress = v),
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_fmtProgress(0), style: DNText.mono(size: 8, color: DNColors.ink4)),
                    Text(_fmtProgress(_progress), style: DNText.mono(size: 8, color: DNColors.ink4)),
                    Text(_fmtProgress(1.0), style: DNText.mono(size: 8, color: DNColors.ink4)),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ControlBtn(
                    label: '⏮15',
                    onTap: () => setState(() =>
                        _progress = (_progress - 0.02).clamp(0.0, 1.0),),
                  ),
                  const SizedBox(width: 20),
                  GestureDetector(
                    onTap: () => setState(() => _isPlaying = !_isPlaying),
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: DNColors.paper,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isPlaying ? Icons.pause : Icons.play_arrow,
                        color: DNColors.ink,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  _ControlBtn(
                    label: '15⏭',
                    onTap: () => setState(() =>
                        _progress = (_progress + 0.02).clamp(0.0, 1.0),),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Pills row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    _SpeedPill(
                      speed: _playbackSpeed,
                      onTap: () => setState(() {
                        _playbackSpeed =
                            _playbackSpeed < 2.0 ? _playbackSpeed + 0.5 : 1.0;
                      }),
                    ),
                    const SizedBox(width: 8),
                    _Pill(label: AppLocalizations.of(context)!.chaptersPill, onTap: _showChapters),
                    const SizedBox(width: 8),
                    _Pill(label: '🪙 ${AppLocalizations.of(context)!.audioRoomTipLabel}', ochre: true, onTap: () {}),
                  ],
                ),
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  void _showChapters() {
    showModalBottomSheet(
      context: context,
      backgroundColor: DNColors.ink2,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),),
      builder: (_) => ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        itemCount: _chapters.length,
        itemBuilder: (_, i) => ListTile(
          onTap: () {
            setState(() => _currentChapter = i);
            Navigator.pop(context);
          },
          leading: Text('${i + 1}',
              style: DNText.mono(size: 12, color: DNColors.terra),),
          title: Text(_chapters[i],
              style: DNText.sans(size: 13, color: DNColors.paper),),
          selected: i == _currentChapter,
          selectedColor: DNColors.terra,
        ),
      ),
    );
  }

  static String _fmtProgress(double pct) {
    const total = Duration(hours: 1, minutes: 14);
    final pos = Duration(milliseconds: (total.inMilliseconds * pct).round());
    final m = pos.inMinutes.toString().padLeft(2, '0');
    final s = (pos.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ─── Waveform ─────────────────────────────────────────────────────────────────

class _Waveform extends StatelessWidget {
  final double progress;
  final ValueChanged<double> onSeek;

  static const _barCount = 60;

  const _Waveform({required this.progress, required this.onSeek});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (d) {
        final box = context.findRenderObject() as RenderBox;
        final local = box.globalToLocal(d.globalPosition);
        final pct = (local.dx / box.size.width).clamp(0.0, 1.0);
        onSeek(pct);
      },
      onTapDown: (d) {
        final box = context.findRenderObject() as RenderBox;
        final local = box.globalToLocal(d.globalPosition);
        final pct = (local.dx / box.size.width).clamp(0.0, 1.0);
        onSeek(pct);
      },
      child: SizedBox(
        height: 48,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(_barCount, (i) {
            final frac = i / _barCount;
            final past = frac < progress;
            // Bar height: 4 + |sin(i * 0.4)| * 24 + (i % 7) * 1.5
            final h = 4 + math.sin(i * 0.4).abs() * 24 + (i % 7) * 1.5;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: h,
                  decoration: BoxDecoration(
                    color: past
                        ? DNColors.terra
                        : Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ─── Controls ─────────────────────────────────────────────────────────────────

class _ControlBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ControlBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(label, style: DNText.mono(size: 9, color: DNColors.paper)),
        ),
      );
}

class _SpeedPill extends StatelessWidget {
  final double speed;
  final VoidCallback onTap;

  const _SpeedPill({required this.speed, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$speed×',
            style: DNText.mono(size: 10, color: DNColors.paper),
          ),
        ),
      );
}

class _Pill extends StatelessWidget {
  final String label;
  final bool ochre;
  final VoidCallback onTap;

  const _Pill({required this.label, this.ochre = false, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: ochre ? DNColors.ochre : Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: DNText.mono(size: 10, color: DNColors.paper),
          ),
        ),
      );
}
