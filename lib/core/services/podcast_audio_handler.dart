import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

import '../../features/podcasts/domain/entities/podcast_episode_entity.dart';

/// Custom AudioHandler for podcast playback.
/// Wraps [just_audio] and exposes media controls to the system (lock screen,
/// notification shade, Bluetooth headsets, Android Auto, etc.).
class PodcastAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();

  // Subscriptions
  StreamSubscription<PlaybackEvent>? _playbackEventSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<Duration>? _positionSubscription;

  PodcastAudioHandler() {
    _init();
  }

  Future<void> _init() async {
    // Configure audio session for media playback
    final session = await AudioSession.instance;
    await session.configure(
      const AudioSessionConfiguration.music(),
    );

    // Listen to playback events (state changes, position, buffering)
    _playbackEventSubscription = _player.playbackEventStream.listen(
      _broadcastState,
      onError: (Object e, StackTrace st) {
        // Silently handle playback errors
      },
    );

    // Listen to duration changes
    _durationSubscription = _player.durationStream.listen((duration) {
      if (duration != null) {
        final item = mediaItem.value;
        if (item != null) {
          mediaItem.add(item.copyWith(duration: duration));
        }
      }
    });

    // Listen to position changes to keep notification progress updated
    _positionSubscription = _player.positionStream.listen((position) {
      _broadcastState(_player.playbackEvent);
    });

    // Handle audio interruptions (phone call, other app playing)
    session.interruptionEventStream.listen((event) {
      if (event.begin) {
        switch (event.type) {
          case AudioInterruptionType.duck:
            _player.setVolume(0.5);
            break;
          case AudioInterruptionType.pause:
          case AudioInterruptionType.unknown:
            pause();
            break;
        }
      } else {
        switch (event.type) {
          case AudioInterruptionType.duck:
            _player.setVolume(1.0);
            break;
          case AudioInterruptionType.pause:
            play();
            break;
          case AudioInterruptionType.unknown:
            break;
        }
      }
    });

    // Handle becoming noisy (headphones unplugged)
    session.becomingNoisyEventStream.listen((_) {
      pause();
    });
  }

  /// Load and play a podcast episode.
  ///
  /// [localFilePath] — path to a decrypted local file (takes precedence over
  /// the network URL). Pass the result of
  /// `PodcastDownloadService.decryptForPlayback()` here when offline playback
  /// is available.
  Future<void> playEpisode(
    PodcastEpisodeEntity episode,
    String podcastTitle,
    String? podcastCoverUrl, {
    String? localFilePath,
  }) async {
    final mediaItemData = MediaItem(
      id: episode.id,
      album: podcastTitle,
      title: episode.title,
      artist: podcastTitle,
      artUri: episode.coverImageUrl != null
          ? Uri.parse(episode.coverImageUrl!)
          : (podcastCoverUrl != null ? Uri.parse(podcastCoverUrl) : null),
      duration: episode.durationSeconds > 0
          ? Duration(seconds: episode.durationSeconds)
          : null,
      displayTitle: episode.title,
      displaySubtitle: podcastTitle,
      extras: <String, dynamic>{
        'podcastId': episode.podcastId,
        'episodeNumber': episode.episodeNumber,
        'seasonNumber': episode.seasonNumber,
      },
    );

    mediaItem.add(mediaItemData);

    // Prefer the local decrypted file; fall back to network URL.
    if (localFilePath != null) {
      await _player.setFilePath(localFilePath);
    } else {
      await _player.setUrl(episode.audioUrl);
    }
    await _player.play();
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  /// Rewind by 10 seconds (mapped to MediaAction.rewind).
  @override
  Future<void> rewind() async {
    final newPosition = _player.position - const Duration(seconds: 10);
    await seek(newPosition > Duration.zero ? newPosition : Duration.zero);
  }

  /// Fast forward by 30 seconds (mapped to MediaAction.fastForward).
  @override
  Future<void> fastForward() async {
    final newPosition = _player.position + const Duration(seconds: 30);
    final duration = _player.duration;
    if (duration != null && newPosition > duration) {
      await seek(duration);
    } else {
      await seek(newPosition);
    }
  }

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  /// Dispose resources.
  Future<void> dispose() async {
    await _playbackEventSubscription?.cancel();
    await _durationSubscription?.cancel();
    await _positionSubscription?.cancel();
    await _player.dispose();
  }

  /// Broadcast the current playback state to the system.
  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    final processingState = const {
      ProcessingState.idle: AudioProcessingState.idle,
      ProcessingState.loading: AudioProcessingState.loading,
      ProcessingState.buffering: AudioProcessingState.buffering,
      ProcessingState.ready: AudioProcessingState.ready,
      ProcessingState.completed: AudioProcessingState.completed,
    }[_player.processingState];

    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.rewind,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.fastForward,
          MediaControl.stop,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
          MediaAction.play,
          MediaAction.pause,
          MediaAction.stop,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: processingState ?? AudioProcessingState.idle,
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: event.currentIndex,
      ),
    );
  }
}
