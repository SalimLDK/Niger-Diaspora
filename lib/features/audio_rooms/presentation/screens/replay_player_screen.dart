import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/services/audio_playback_service.dart';
import '../../../../core/services/file_download_service.dart';
import '../../../../core/theme/dn_colors.dart';
import '../../../../core/theme/dn_text.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/participant_entity.dart';
import '../../domain/entities/room_replay_entity.dart';
import '../widgets/send_tip_bottom_sheet.dart';
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

  double _progress = 0.0; // 0.0 – 1.0
  bool _isPlaying = false;
  double _playbackSpeed = 1.0;
  int _currentChapter = 0; // 0-based

  /// Chapitres réels de l'entité (avec timestamps), sinon [].
  ///
  /// Un repli de cinq titres inventés (« Introduction », « Actualités »…)
  /// était affiché quand le replay n'en portait aucun, et le tap dessus
  /// sautait à `i / 5` de la piste. C'était de la donnée fabriquée présentée
  /// comme réelle : sans chapitres, on n'en montre plus.
  List<ReplayChapter> get _chaptersData => widget.replay?.chapters ?? const [];
  bool get _hasRealChapters => _chaptersData.isNotEmpty;

  List<String> get _chapterTitles =>
      _chaptersData.map((c) => c.title).toList();

  // Lecture audio réelle (§1e) via le service partagé just_audio.
  final AudioPlaybackService _audio = AudioPlaybackService();
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration?>? _durSub;
  StreamSubscription<bool>? _playSub;
  Duration _position = Duration.zero;
  Duration _total = Duration.zero;

  // Minuteur de sommeil.
  Timer? _sleepTimer;
  int? _sleepMinutes;

  // Téléchargement hors ligne (§1e).
  bool _downloading = false;
  bool _downloaded = false;

  bool get _isAudio =>
      (widget.replay?.videoUrl ?? '').isEmpty &&
      (widget.replay?.audioUrl ?? '').isNotEmpty;

  @override
  void initState() {
    super.initState();
    final videoUrl = widget.replay?.videoUrl;
    if (videoUrl != null && videoUrl.isNotEmpty) {
      _videoCtrl = VideoPlayerController.networkUrl(Uri.parse(videoUrl))
        ..addListener(_onVideoTick)
        ..initialize().then((_) {
          if (mounted) setState(() => _videoInitialized = true);
        });
    } else if (_isAudio) {
      _total = Duration(seconds: widget.replay?.durationSeconds ?? 0);
      _posSub = _audio.positionStream.listen((p) {
        if (!mounted) return;
        setState(() {
          _position = p;
          if (_total.inMilliseconds > 0) {
            _progress = (p.inMilliseconds / _total.inMilliseconds).clamp(0.0, 1.0);
          }
          // Chapitre courant d'après la position (chapitres réels).
          final ch = _chaptersData;
          if (ch.isNotEmpty) {
            var idx = 0;
            for (var j = 0; j < ch.length; j++) {
              if (p.inSeconds >= ch[j].startSeconds) idx = j;
            }
            _currentChapter = idx;
          }
        });
      });
      _durSub = _audio.durationStream.listen((d) {
        if (mounted && d != null && d > Duration.zero) {
          setState(() => _total = d);
        }
      });
      _playSub = _audio.playingStream.listen((playing) {
        if (mounted) setState(() => _isPlaying = playing);
      });
    }
    _checkDownloaded();
  }

  /// Play/pause de la piste audio (ou vidéo) réelle.
  Future<void> _togglePlay() async {
    final replay = widget.replay;
    if (_isAudio && replay?.audioUrl != null) {
      await _audio.togglePlayPause(replay!.audioUrl!);
    } else if (_videoCtrl != null) {
      setState(() {
        _videoCtrl!.value.isPlaying ? _videoCtrl!.pause() : _videoCtrl!.play();
        _isPlaying = _videoCtrl!.value.isPlaying;
      });
    }
  }

  /// Rafraîchit le compteur et la barre pendant la lecture vidéo.
  ///
  /// Le contrôleur n'était écouté par personne : sans ça, la position affichée
  /// resterait figée sur la valeur du premier rendu.
  void _onVideoTick() {
    final ctrl = _videoCtrl;
    if (!mounted || ctrl == null || !ctrl.value.isInitialized) return;
    final total = ctrl.value.duration;
    setState(() {
      _isPlaying = ctrl.value.isPlaying;
      _progress = total > Duration.zero
          ? (ctrl.value.position.inMilliseconds / total.inMilliseconds)
              .clamp(0.0, 1.0)
          : 0.0;
      final ch = _chaptersData;
      if (ch.isNotEmpty) {
        var idx = 0;
        for (var j = 0; j < ch.length; j++) {
          if (ctrl.value.position.inSeconds >= ch[j].startSeconds) idx = j;
        }
        _currentChapter = idx;
      }
    });
  }

  /// Position et durée courantes, quelle que soit la source.
  ///
  /// Le compteur de la vidéo dérivait d'une durée totale codée en dur à
  /// 1 h 14 (`_fmtProgress`) : le temps affiché n'avait aucun rapport avec le
  /// fichier lu. Le contrôleur vidéo porte les vraies valeurs ; on retombe sur
  /// la durée annoncée par l'entité tant qu'il n'est pas initialisé.
  Duration get _currentPosition =>
      _isAudio ? _position : (_videoCtrl?.value.position ?? Duration.zero);

  Duration get _currentTotal {
    if (_isAudio) return _total;
    final d = _videoCtrl?.value.duration ?? Duration.zero;
    return d > Duration.zero
        ? d
        : Duration(seconds: widget.replay?.durationSeconds ?? 0);
  }

  /// Saut relatif (§1e : −10 s / +30 s) sur la lecture réelle.
  Future<void> _skip(int seconds) async {
    if (_isAudio) {
      var target = _position + Duration(seconds: seconds);
      if (target < Duration.zero) target = Duration.zero;
      if (_total > Duration.zero && target > _total) target = _total;
      await _audio.seek(target);
    } else if (_videoCtrl != null) {
      await _videoCtrl!.seekTo(
        _videoCtrl!.value.position + Duration(seconds: seconds),
      );
    }
  }

  Future<void> _seekFraction(double v) async {
    if (_isAudio && _total > Duration.zero) {
      await _audio.seek(
        Duration(milliseconds: (v * _total.inMilliseconds).round()),
      );
      return;
    }
    // En vidéo, glisser sur la forme d'onde ne faisait que déplacer le
    // curseur à l'écran : la lecture continuait à sa position d'origine.
    final ctrl = _videoCtrl;
    final total = ctrl?.value.duration ?? Duration.zero;
    if (ctrl != null && total > Duration.zero) {
      await ctrl.seekTo(
        Duration(milliseconds: (v * total.inMilliseconds).round()),
      );
      return;
    }
    setState(() => _progress = v);
  }

  void _cycleSpeed() {
    setState(() {
      _playbackSpeed = _playbackSpeed < 2.0 ? _playbackSpeed + 0.5 : 1.0;
    });
    if (_isAudio) _audio.setSpeed(_playbackSpeed);
  }

  /// Envoie un pourboire à l'hôte du salon rejoué.
  ///
  /// Le replay ne porte pas de liste de participants : on reconstruit une
  /// [ParticipantEntity] minimale à partir des champs `host*` de l'entité,
  /// qui sont les seules informations dont la feuille a besoin (id, nom,
  /// photo).
  Future<void> _sendTipToHost() async {
    final replay = widget.replay;
    if (replay == null || replay.hostId.isEmpty) return;

    await SendTipBottomSheet.show(
      context,
      roomId: replay.roomId,
      roomTitle: replay.roomTitle,
      recipient: ParticipantEntity(
        userId: replay.hostId,
        userName: replay.hostName,
        photoUrl: replay.hostPhotoUrl,
        role: ParticipantRole.host,
        connectionState: ParticipantConnectionState.disconnected,
        joinedAt: replay.recordedAt,
      ),
    );
  }

  Future<void> _checkDownloaded() async {
    final id = widget.replay?.id;
    if (id == null) return;
    final path = await FileDownloadService().getDownloadedPath('replay_$id');
    if (mounted && path != null) setState(() => _downloaded = true);
  }

  Future<void> _downloadReplay() async {
    final replay = widget.replay;
    final url = replay?.audioUrl;
    if (_downloading || _downloaded || replay == null || url == null || url.isEmpty) {
      return;
    }
    setState(() => _downloading = true);
    final file = await FileDownloadService().downloadToAppDirectory(
      url,
      fileName: 'replay_${replay.id}.m4a',
      messageId: 'replay_${replay.id}',
    );
    if (!mounted) return;
    setState(() {
      _downloading = false;
      _downloaded = file != null;
    });
  }

  /// Minuteur de sommeil (§1e) : met la lecture en pause après N minutes.
  void _setSleepTimer(int? minutes) {
    _sleepTimer?.cancel();
    setState(() => _sleepMinutes = minutes);
    if (minutes != null) {
      _sleepTimer = Timer(Duration(minutes: minutes), () {
        if (_isAudio) {
          _audio.pause();
        } else {
          _videoCtrl?.pause();
        }
        if (mounted) setState(() => _sleepMinutes = null);
      });
    }
  }

  void _showSleepMenu() {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: DNColors.darkSurface,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Text(l10n.sleepTimer,
                style: DNText.mono(size: 10, color: DNColors.ink4),),
            const SizedBox(height: 4),
            for (final m in const [5, 15, 30, 60])
              ListTile(
                title: Text('$m min',
                    style: DNText.sans(size: 15, color: DNColors.paper),),
                trailing: _sleepMinutes == m
                    ? const Icon(Icons.check, color: DNColors.ochre)
                    : null,
                onTap: () {
                  _setSleepTimer(m);
                  Navigator.pop(context);
                },
              ),
            ListTile(
              title: Text(l10n.sleepTimerOff,
                  style: DNText.sans(size: 15, color: DNColors.paper),),
              trailing: _sleepMinutes == null
                  ? const Icon(Icons.check, color: DNColors.ochre)
                  : null,
              onTap: () {
                _setSleepTimer(null);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _videoCtrl?.removeListener(_onVideoTick);
    _videoCtrl?.dispose();
    _sleepTimer?.cancel();
    _posSub?.cancel();
    _durSub?.cancel();
    _playSub?.cancel();
    if (_isAudio) _audio.pause();
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
                    // Téléchargement hors ligne (§1e).
                    if (_downloading)
                      const SizedBox(
                        width: 40,
                        height: 40,
                        child: Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: DNColors.paper,
                            ),
                          ),
                        ),
                      )
                    else if ((widget.replay?.audioUrl ?? '').isNotEmpty)
                      IconButton(
                        icon: Icon(
                          _downloaded
                              ? Icons.download_done_rounded
                              : Icons.download_for_offline_outlined,
                          color: _downloaded ? DNColors.leaf : DNColors.paper,
                          size: 24,
                        ),
                        onPressed: _downloaded ? null : _downloadReplay,
                      )
                    else
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

              // Chapitre en cours — seulement si le replay en porte vraiment.
              if (_hasRealChapters) ...[
                Text(
                  'Chapitre ${_currentChapter + 1}/${_chapterTitles.length}',
                  style: DNText.mono(size: 9, color: DNColors.ink4),
                ),
                const SizedBox(height: 4),
              ],
              // Sans chapitre, cette place revient au titre du salon rejoué,
              // qui n'était affiché nulle part ailleurs sur l'écran.
              Text(
                _hasRealChapters
                    ? _chapterTitles[
                        _currentChapter.clamp(0, _chapterTitles.length - 1)]
                    : (widget.replay?.roomTitle ?? ''),
                style: DNText.serif(size: 22, italic: true, color: DNColors.paper),
              ),
              const SizedBox(height: 4),
              Text(
                widget.replay?.hostName ?? '',
                style: DNText.mono(size: 9, color: DNColors.ink3),
              ),

              const SizedBox(height: 24),

              // Waveform scrubber
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _Waveform(
                  progress: _progress,
                  onSeek: _seekFraction,
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_fmtDuration(Duration.zero),
                        style: DNText.mono(size: 8, color: DNColors.ink4),),
                    Text(_fmtDuration(_currentPosition),
                        style: DNText.mono(size: 8, color: DNColors.ink4),),
                    Text(_fmtDuration(_currentTotal),
                        style: DNText.mono(size: 8, color: DNColors.ink4),),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ControlBtn(
                    label: '⏮10',
                    onTap: () => _skip(-10),
                  ),
                  const SizedBox(width: 20),
                  GestureDetector(
                    onTap: _togglePlay,
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
                    label: '30⏭',
                    onTap: () => _skip(30),
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
                      onTap: _cycleSpeed,
                    ),
                    const SizedBox(width: 8),
                    // Pastille masquée sans chapitres réels : elle n'ouvrait
                    // qu'une liste inventée.
                    if (_hasRealChapters)
                      _Pill(
                        label: AppLocalizations.of(context)!.chaptersPill,
                        onTap: _showChapters,
                      ),
                    const SizedBox(width: 8),
                    // Minuteur de sommeil (§1e).
                    _Pill(
                      label: _sleepMinutes != null
                          ? '😴 ${_sleepMinutes}m'
                          : '😴 ${AppLocalizations.of(context)!.sleepTimer}',
                      ochre: _sleepMinutes != null,
                      onTap: _showSleepMenu,
                    ),
                    const SizedBox(width: 8),
                    // Le bouton était mort alors que SendTipBottomSheet
                    // fonctionne déjà dans le salon en direct. Masqué si le
                    // replay ne porte pas d'hôte : sans destinataire il n'y a
                    // rien à envoyer.
                    if ((widget.replay?.hostId ?? '').isNotEmpty) ...[
                      _Pill(
                        label:
                            '🪙 ${AppLocalizations.of(context)!.audioRoomTipLabel}',
                        ochre: true,
                        onTap: _sendTipToHost,
                      ),
                    ],
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
        itemCount: _chapterTitles.length,
        itemBuilder: (_, i) => ListTile(
          onTap: () {
            setState(() => _currentChapter = i);
            final start = Duration(seconds: _chaptersData[i].startSeconds);
            if (_isAudio) {
              _audio.seek(start);
            } else {
              _videoCtrl?.seekTo(start);
            }
            Navigator.pop(context);
          },
          leading: Text('${i + 1}',
              style: DNText.mono(size: 12, color: DNColors.terra),),
          title: Text(_chapterTitles[i],
              style: DNText.sans(size: 13, color: DNColors.paper),),
          subtitle: Text(_chaptersData[i].formattedTime,
              style: DNText.mono(size: 10, color: DNColors.ink4),),
          selected: i == _currentChapter,
          selectedColor: DNColors.terra,
        ),
      ),
    );
  }

  static String _fmtDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
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
