import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../core/services/audio_playback_service.dart';
import '../../../../core/services/deep_link_service.dart';
import '../../../../core/services/podcast_download_service.dart';
import '../../../reports/domain/entities/report_entity.dart';
import '../../../reports/presentation/widgets/report_content_modal.dart';
import '../../domain/entities/podcast_episode_entity.dart';
import '../providers/podcast_provider.dart';
import '../widgets/video_episode_player.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';
import 'package:diaspo_niger/core/errors/error_handler.dart';

/// Screen showing episode details with player controls
class EpisodeDetailScreen extends ConsumerStatefulWidget {
  final String episodeId;

  const EpisodeDetailScreen({
    super.key,
    required this.episodeId,
  });

  @override
  ConsumerState<EpisodeDetailScreen> createState() => _EpisodeDetailScreenState();
}

class _EpisodeDetailScreenState extends ConsumerState<EpisodeDetailScreen> {
  bool _isPlaying = false;
  bool _isLiked = false;
  double _playbackSpeed = 1.0;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  bool _stopAtEndOfEpisode = false;
  Timer? _sleepTimer;
  Timer? _sleepCountdownTimer;
  int? _sleepTimerMinutes;

  final List<double> _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
  final AudioPlaybackService _audioService = AudioPlaybackService();
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<bool>? _playingSubscription;
  String? _currentAudioUrl;

  @override
  void initState() {
    super.initState();
    _setupAudioListeners();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _playingSubscription?.cancel();
    _sleepTimer?.cancel();
    _sleepCountdownTimer?.cancel();
    super.dispose();
  }

  void _setupAudioListeners() {
    _positionSubscription = _audioService.positionStream.listen((position) {
      if (mounted && _currentAudioUrl != null && _audioService.isLoadedUrl(_currentAudioUrl!)) {
        setState(() => _currentPosition = position);

        // Check if we should stop at end of episode
        if (_stopAtEndOfEpisode &&
            _totalDuration.inSeconds > 0 &&
            position.inSeconds >= _totalDuration.inSeconds - 1) {
          _audioService.pause();
          setState(() {
            _isPlaying = false;
            _stopAtEndOfEpisode = false;
          });
        }
      }
    });

    _playingSubscription = _audioService.playingStream.listen((playing) {
      if (mounted && _currentAudioUrl != null && _audioService.isLoadedUrl(_currentAudioUrl!)) {
        setState(() => _isPlaying = playing);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final episodeAsync = ref.watch(episodeProvider(widget.episodeId));
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: episodeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const AppIcon(AppIcon.error, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                ErrorHandler.instance.getShortMessage(
                  ErrorHandler.instance.handleException(e),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.pop(),
                child: Text(l10n.back),
              ),
            ],
          ),
        ),
        data: (episode) {
          if (episode == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const AppIcon(AppIcon.podcasts, size: 48, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(l10n.episodeNotFound),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.pop(),
                    child: Text(l10n.back),
                  ),
                ],
              ),
            );
          }
          return _buildContent(context, episode, l10n);
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, PodcastEpisodeEntity episode, AppLocalizations l10n) {
    _totalDuration = Duration(seconds: episode.durationSeconds);

    return CustomScrollView(
      slivers: [
        // App Bar — video player for video episodes, cover image for audio
        SliverAppBar(
          expandedHeight: episode.isVideoEpisode ? 220 : 300,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            background: episode.isVideoEpisode
                ? Container(
                    color: Colors.black,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40), // account for status bar
                        VideoEpisodePlayer(episode: episode),
                      ],
                    ),
                  )
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      if (episode.coverImageUrl != null)
                        Image.network(
                          episode.coverImageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                            child: const AppIcon(AppIcon.podcasts, size: 80, color: Colors.white54),
                          ),
                        )
                      else
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Theme.of(context).primaryColor,
                                Theme.of(context).primaryColor.withValues(alpha: 0.6),
                              ],
                            ),
                          ),
                          child: const AppIcon(AppIcon.podcasts, size: 80, color: Colors.white54),
                        ),
                      // Gradient overlay
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.7),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          actions: [
            IconButton(
              icon: const AppIcon(AppIcon.share, color: Colors.white54),
              onPressed: () => _shareEpisode(episode),
            ),
            PopupMenuButton<String>(
              onSelected: (value) => _handleMenuAction(value, episode, l10n),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'download',
                  child: ListTile(
                    leading: const Icon(Icons.download),
                    title: Text(l10n.download),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'report',
                  child: ListTile(
                    leading: const Icon(Icons.flag),
                    title: Text(l10n.report),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),

        // Episode info and controls
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Episode label
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        episode.episodeLabel,
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      episode.formattedDuration,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    if (episode.isPremium) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'PREMIUM',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),

                // Title
                Text(
                  episode.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                // Stats row
                Row(
                  children: [
                    _buildStatChip(Icons.play_arrow, '${episode.playCount}'),
                    const SizedBox(width: 16),
                    _buildStatChip(Icons.favorite, '${episode.likeCount}'),
                    const SizedBox(width: 16),
                    _buildStatChip(Icons.download, '${episode.downloadCount}'),
                  ],
                ),
                const SizedBox(height: 24),

                // Audio player controls — hidden for video episodes
                if (!episode.isVideoEpisode) ...[
                  _buildPlayerControls(episode),
                  const SizedBox(height: 24),
                ],

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildActionButton(
                      icon: (c) => _isLiked
                          ? AppIcon(AppIcon.heart, color: c)
                          : AppIcon(AppIcon.favoriteBorder, color: c),
                      label: l10n.podcastsLikeAction,
                      color: _isLiked ? Colors.red : null,
                      onPressed: () => _toggleLike(episode),
                    ),
                    if (!episode.isVideoEpisode)
                      _buildActionButton(
                        icon: (c) => Icon(Icons.download, color: c),
                        label: l10n.download,
                        onPressed: () => _downloadEpisode(episode, l10n),
                      ),
                    _buildActionButton(
                      icon: (c) => AppIcon(AppIcon.share, color: c),
                      label: l10n.share,
                      onPressed: () => _shareEpisode(episode),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Description
                if (episode.description != null && episode.description!.isNotEmpty) ...[
                  Text(
                    l10n.podcastsPodcastDescription,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    episode.description!,
                    style: TextStyle(
                      color: Colors.grey[700],
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Chapters
                if (episode.hasChapters) ...[
                  Text(
                    l10n.podcastsChapters,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Pastilles horizontales (maquette 1e) : sauter d'un
                  // chapitre à l'autre sans dérouler la liste complète.
                  _buildChapterPills(episode),
                  const SizedBox(height: 12),
                  _buildChaptersList(episode),
                  const SizedBox(height: 24),
                ],

                // From live room indicator
                if (episode.isFromLiveRoom) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.record_voice_over, color: Colors.purple[700]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            l10n.podcastsFromLiveRoom,
                            style: TextStyle(color: Colors.purple[700]),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Transcription
                if (episode.transcription != null && episode.transcription!.isNotEmpty) ...[
                  ExpansionTile(
                    title: Text(
                      l10n.podcastsTranscription,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          episode.transcription!,
                          style: TextStyle(
                            color: Colors.grey[700],
                            height: 1.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerControls(PodcastEpisodeEntity episode) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Progress slider
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              ),
              child: Slider(
                value: _currentPosition.inSeconds.toDouble(),
                max: _totalDuration.inSeconds.toDouble(),
                onChanged: (value) {
                  final newPosition = Duration(seconds: value.toInt());
                  setState(() => _currentPosition = newPosition);
                  _audioService.seek(newPosition);
                },
              ),
            ),

            // Time indicators
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(_currentPosition),
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  Text(
                    _formatDuration(_totalDuration),
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Playback controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Speed button
                TextButton(
                  onPressed: _cycleSpeed,
                  child: Text(
                    '${_playbackSpeed}x',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Rewind 15s
                IconButton(
                  icon: const Icon(Icons.replay_10),
                  iconSize: 32,
                  onPressed: () => _seek(-10),
                ),
                const SizedBox(width: 8),

                // Play/Pause
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).primaryColor,
                  ),
                  child: IconButton(
                    icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                    iconSize: 40,
                    color: Colors.white,
                    onPressed: () => _togglePlayPause(episode),
                  ),
                ),
                const SizedBox(width: 8),

                // Forward 30s
                IconButton(
                  icon: const Icon(Icons.forward_30),
                  iconSize: 32,
                  onPressed: () => _seek(30),
                ),
                const SizedBox(width: 16),

                // Sleep timer
                Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: Icon(
                        _sleepTimerMinutes != null || _stopAtEndOfEpisode
                            ? Icons.bedtime
                            : Icons.bedtime_outlined,
                        color: _sleepTimerMinutes != null || _stopAtEndOfEpisode
                            ? Theme.of(context).primaryColor
                            : null,
                      ),
                      onPressed: _showSleepTimerDialog,
                    ),
                    if (_sleepTimerMinutes != null)
                      Positioned(
                        bottom: 0,
                        child: Text(
                          '${_sleepTimerMinutes}m',
                          style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Rangée de pastilles, une par chapitre. Le chapitre en cours est mis en
  /// évidence pour qu'on sache où on en est sans lire les horodatages.
  Widget _buildChapterPills(PodcastEpisodeEntity episode) {
    final theme = Theme.of(context);
    final currentIndex = _currentChapterIndex(episode);

    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: episode.chapters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final chapter = episode.chapters[i];
          final active = i == currentIndex;
          return GestureDetector(
            onTap: () => _seekToChapter(chapter.startSeconds),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                chapter.title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  color: active
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Index du chapitre couvrant la position de lecture actuelle, ou -1.
  int _currentChapterIndex(PodcastEpisodeEntity episode) {
    final seconds = _currentPosition.inSeconds;
    var found = -1;
    for (var i = 0; i < episode.chapters.length; i++) {
      if (episode.chapters[i].startSeconds <= seconds) {
        found = i;
      } else {
        break;
      }
    }
    return found;
  }

  Widget _buildChaptersList(PodcastEpisodeEntity episode) {
    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: episode.chapters.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final chapter = episode.chapters[index];
          final isCurrentChapter = _isChapterPlaying(episode, index);

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: isCurrentChapter
                  ? Theme.of(context).primaryColor
                  : Colors.grey[300],
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: isCurrentChapter ? Colors.white : Colors.grey[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              chapter.title,
              style: TextStyle(
                fontWeight: isCurrentChapter ? FontWeight.bold : FontWeight.normal,
                color: isCurrentChapter ? Theme.of(context).primaryColor : null,
              ),
            ),
            trailing: Text(
              chapter.formattedStartTime,
              style: TextStyle(
                color: Colors.grey[600],
                fontFamily: 'monospace',
              ),
            ),
            onTap: () => _seekToChapter(chapter.startSeconds),
          );
        },
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required Widget Function(Color color) icon,
    required String label,
    Color? color,
    required VoidCallback onPressed,
  }) {
    final resolvedColor = color ?? Colors.grey[700]!;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            icon(resolvedColor),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: resolvedColor,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  bool _isChapterPlaying(PodcastEpisodeEntity episode, int chapterIndex) {
    if (!_isPlaying) return false;

    final chapter = episode.chapters[chapterIndex];
    final nextChapter = chapterIndex < episode.chapters.length - 1
        ? episode.chapters[chapterIndex + 1]
        : null;

    final currentSeconds = _currentPosition.inSeconds;
    if (nextChapter != null) {
      return currentSeconds >= chapter.startSeconds &&
          currentSeconds < nextChapter.startSeconds;
    }
    return currentSeconds >= chapter.startSeconds;
  }

  void _togglePlayPause(PodcastEpisodeEntity episode) async {
    // Video episodes are handled by VideoEpisodePlayer, not the audio service.
    if (episode.isVideoEpisode) return;

    _currentAudioUrl = episode.audioUrl;

    if (_isPlaying) {
      await _audioService.pause();
    } else {
      // Record play
      ref.read(podcastNotifierProvider.notifier).recordPlay(episode.id, episode.podcastId);
      await _audioService.play(episode.audioUrl);
      await _audioService.setSpeed(_playbackSpeed);
    }

    setState(() => _isPlaying = !_isPlaying);
  }

  void _cycleSpeed() {
    setState(() {
      final currentIndex = _speeds.indexOf(_playbackSpeed);
      final nextIndex = (currentIndex + 1) % _speeds.length;
      _playbackSpeed = _speeds[nextIndex];
    });
    _audioService.setSpeed(_playbackSpeed);
  }

  void _seek(int seconds) {
    final newPositionSeconds = (_currentPosition.inSeconds + seconds).clamp(0, _totalDuration.inSeconds);
    final newPosition = Duration(seconds: newPositionSeconds);
    setState(() => _currentPosition = newPosition);
    _audioService.seek(newPosition);
  }

  void _seekToChapter(int startSeconds) async {
    final newPosition = Duration(seconds: startSeconds);
    setState(() {
      _currentPosition = newPosition;
      _isPlaying = true;
    });
    await _audioService.seek(newPosition);
    if (!_audioService.isPlaying) {
      await _audioService.resume();
    }
  }

  void _toggleLike(PodcastEpisodeEntity episode) {
    setState(() => _isLiked = !_isLiked);

    if (_isLiked) {
      ref.read(podcastNotifierProvider.notifier).likeEpisode(episode.id);
    } else {
      ref.read(podcastNotifierProvider.notifier).unlikeEpisode(episode.id);
    }
  }

  void _downloadEpisode(PodcastEpisodeEntity episode, AppLocalizations l10n) {
    // Video episodes are streamed; only audio episodes support offline download.
    if (episode.isVideoEpisode) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.podcastsDownloadInProgress)),
    );
    ref.read(downloadManagerProvider.notifier).startDownload(
      episodeId: episode.id,
      audioUrl: episode.audioUrl,
    );
    // Sans ça, « Téléchargements » restait à 0 dans les statistiques du
    // créateur quel que soit l'usage réel.
    ref.read(podcastNotifierProvider.notifier).recordDownload(episode.id);
  }

  void _shareEpisode(PodcastEpisodeEntity episode) {
    DeepLinkService.instance.shareEpisode(
      episodeId: episode.id,
      episodeTitle: episode.title,
      imageUrl: episode.coverImageUrl,
      duration: Duration(seconds: episode.durationSeconds),
    );
    ref.read(podcastNotifierProvider.notifier).recordShare(episode.id);
  }

  void _showSleepTimerDialog() {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.podcastsSleepTimerTitle,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.timer_off),
              title: Text(l10n.podcastsSleepTimerDisabled),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.timer),
              title: Text(l10n.podcastsSleepTimer15),
              onTap: () {
                Navigator.pop(context);
                _startSleepTimer(15);
              },
            ),
            ListTile(
              leading: const Icon(Icons.timer),
              title: Text(l10n.podcastsSleepTimer30),
              onTap: () {
                Navigator.pop(context);
                _startSleepTimer(30);
              },
            ),
            ListTile(
              leading: const Icon(Icons.timer),
              title: Text(l10n.podcastsSleepTimer45),
              onTap: () {
                Navigator.pop(context);
                _startSleepTimer(45);
              },
            ),
            ListTile(
              leading: const Icon(Icons.timer),
              title: Text(l10n.podcastsSleepTimer60),
              onTap: () {
                Navigator.pop(context);
                _startSleepTimer(60);
              },
            ),
            ListTile(
              leading: const Icon(Icons.stop_circle_outlined),
              title: Text(l10n.podcastsSleepTimerEnd),
              onTap: () {
                Navigator.pop(context);
                _setStopAtEndOfEpisode();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _setStopAtEndOfEpisode() {
    final l10n = AppLocalizations.of(context)!;
    _sleepTimer?.cancel();
    _sleepCountdownTimer?.cancel();
    setState(() {
      _stopAtEndOfEpisode = true;
      _sleepTimerMinutes = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.podcastsSleepTimerActivated)),
    );
  }

  void _startSleepTimer(int minutes) {
    final l10n = AppLocalizations.of(context)!;
    _sleepTimer?.cancel();
    _sleepCountdownTimer?.cancel();

    setState(() {
      _sleepTimerMinutes = minutes;
      _stopAtEndOfEpisode = false;
    });

    // Countdown timer to update display every minute
    _sleepCountdownTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted && _sleepTimerMinutes != null && _sleepTimerMinutes! > 1) {
        setState(() {
          _sleepTimerMinutes = _sleepTimerMinutes! - 1;
        });
      }
    });

    // Main timer to stop playback
    _sleepTimer = Timer(Duration(minutes: minutes), () {
      _sleepCountdownTimer?.cancel();
      if (mounted) {
        final l10nInner = AppLocalizations.of(context)!;
        _audioService.pause();
        setState(() {
          _isPlaying = false;
          _sleepTimerMinutes = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10nInner.podcastsSleepTimerFinished)),
        );
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.podcastsSleepTimerSet(minutes))),
    );
  }

  void _handleMenuAction(String action, PodcastEpisodeEntity episode, AppLocalizations l10n) {
    switch (action) {
      case 'download':
        _downloadEpisode(episode, l10n);
        break;
      case 'report':
        ReportContentModal.show(
          context,
          targetType: ReportTargetType.message,
          targetId: episode.id,
          targetName: episode.title,
          contentSnapshot: ReportContentModal.textMessageSnapshot(episode.title),
        );
        break;
    }
  }
}
