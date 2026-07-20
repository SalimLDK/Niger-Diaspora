import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/podcast_audio_handler.dart';
import '../../../../core/services/podcast_download_service.dart';
import '../../domain/entities/podcast_episode_entity.dart';

/// State for the global podcast player
class PodcastPlayerState {
  /// Currently playing episode
  final PodcastEpisodeEntity? currentEpisode;

  /// Podcast title (for display in mini-player)
  final String? podcastTitle;

  /// Podcast cover image URL
  final String? podcastCoverUrl;

  /// Whether the player is currently playing
  final bool isPlaying;

  /// Whether the player is loading
  final bool isLoading;

  /// Current playback position
  final Duration position;

  /// Total duration
  final Duration duration;

  /// Playback speed
  final double speed;

  /// Error message if any
  final String? error;

  const PodcastPlayerState({
    this.currentEpisode,
    this.podcastTitle,
    this.podcastCoverUrl,
    this.isPlaying = false,
    this.isLoading = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.speed = 1.0,
    this.error,
  });

  bool get hasEpisode => currentEpisode != null;

  String? get coverUrl => currentEpisode?.coverImageUrl ?? podcastCoverUrl;

  PodcastPlayerState copyWith({
    PodcastEpisodeEntity? currentEpisode,
    String? podcastTitle,
    String? podcastCoverUrl,
    bool? isPlaying,
    bool? isLoading,
    Duration? position,
    Duration? duration,
    double? speed,
    String? error,
  }) {
    return PodcastPlayerState(
      currentEpisode: currentEpisode ?? this.currentEpisode,
      podcastTitle: podcastTitle ?? this.podcastTitle,
      podcastCoverUrl: podcastCoverUrl ?? this.podcastCoverUrl,
      isPlaying: isPlaying ?? this.isPlaying,
      isLoading: isLoading ?? this.isLoading,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      speed: speed ?? this.speed,
      error: error,
    );
  }

  factory PodcastPlayerState.initial() => const PodcastPlayerState();
}

/// Provider for the global podcast player
final podcastPlayerProvider =
    NotifierProvider<PodcastPlayerNotifier, PodcastPlayerState>(
  PodcastPlayerNotifier.new,
);

/// Notifier for managing podcast playback via AudioService.
class PodcastPlayerNotifier extends Notifier<PodcastPlayerState> {
  PodcastAudioHandler? _handler;
  StreamSubscription<PlaybackState>? _playbackStateSubscription;
  StreamSubscription<MediaItem?>? _mediaItemSubscription;

  @override
  PodcastPlayerState build() {
    ref.onDispose(() {
      _playbackStateSubscription?.cancel();
      _mediaItemSubscription?.cancel();
    });
    _setupListeners();
    return PodcastPlayerState.initial();
  }

  void _setupListeners() {
    // Defer handler access until after initialization
    Future.microtask(() async {
      try {
        _handler = await AudioService.init(
          builder: () => PodcastAudioHandler(),
          config: const AudioServiceConfig(
            androidNotificationChannelId: 'podcast_playback_channel',
            androidNotificationChannelName: 'Lecture Podcast',
            androidNotificationOngoing: true,
            androidStopForegroundOnPause: true,
            androidShowNotificationBadge: false,
            fastForwardInterval: Duration(seconds: 30),
            rewindInterval: Duration(seconds: 10),
          ),
        );

        _playbackStateSubscription =
            _handler!.playbackState.listen((playbackState) {
          if (state.hasEpisode) {
            final isPlaying = playbackState.playing;
            final isLoading = playbackState.processingState ==
                    AudioProcessingState.loading ||
                playbackState.processingState ==
                    AudioProcessingState.buffering;

            state = state.copyWith(
              isPlaying: isPlaying,
              isLoading: isLoading,
              position: playbackState.updatePosition,
              speed: playbackState.speed,
            );

            // Handle completion
            if (playbackState.processingState ==
                AudioProcessingState.completed) {
              state = state.copyWith(
                isPlaying: false,
                position: Duration.zero,
              );
            }
          }
        });

        _mediaItemSubscription = _handler!.mediaItem.listen((mediaItem) {
          if (mediaItem?.duration != null) {
            state = state.copyWith(duration: mediaItem!.duration!);
          }
        });
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Error initializing AudioService: $e');
        }
      }
    });
  }

  /// Play a podcast episode
  Future<void> playEpisode({
    required PodcastEpisodeEntity episode,
    required String podcastTitle,
    String? podcastCoverUrl,
  }) async {
    // Video episodes are rendered by VideoEpisodePlayer widget, not AudioService.
    if (episode.isVideoEpisode) {
      state = state.copyWith(
        currentEpisode: episode,
        podcastTitle: podcastTitle,
        podcastCoverUrl: podcastCoverUrl,
        isLoading: false,
        error: null,
      );
      return;
    }

    try {
      state = state.copyWith(
        currentEpisode: episode,
        podcastTitle: podcastTitle,
        podcastCoverUrl: podcastCoverUrl,
        isLoading: true,
        position: Duration.zero,
        duration: Duration.zero,
        error: null,
      );

      if (_handler != null) {
        // Check for a locally downloaded (and encrypted) copy first.
        // decryptForPlayback returns a temp file path or null if not cached.
        final localFile = await ref
            .read(podcastDownloadServiceProvider)
            .decryptForPlayback(episode.id);

        await _handler!.playEpisode(
          episode,
          podcastTitle,
          podcastCoverUrl,
          localFilePath: localFile?.path,
        );
      }

      state = state.copyWith(
        isLoading: false,
        isPlaying: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Erreur de lecture: $e',
      );
    }
  }

  /// Toggle play/pause
  Future<void> togglePlayPause() async {
    if (state.currentEpisode == null || _handler == null) return;

    try {
      if (state.isPlaying) {
        await _handler!.pause();
      } else {
        await _handler!.play();
      }
    } catch (e) {
      state = state.copyWith(error: 'Erreur: $e');
    }
  }

  /// Pause playback
  Future<void> pause() async {
    if (_handler == null) return;
    try {
      await _handler!.pause();
    } catch (e) {
      state = state.copyWith(error: 'Erreur: $e');
    }
  }

  /// Resume playback
  Future<void> resume() async {
    if (_handler == null) return;
    try {
      await _handler!.play();
    } catch (e) {
      state = state.copyWith(error: 'Erreur: $e');
    }
  }

  /// Seek to position
  Future<void> seek(Duration position) async {
    if (_handler == null) return;
    try {
      await _handler!.seek(position);
    } catch (e) {
      state = state.copyWith(error: 'Erreur: $e');
    }
  }

  /// Skip forward by seconds (default 30s)
  Future<void> skipForward({int seconds = 30}) async {
    if (_handler == null) return;
    try {
      await _handler!.fastForward();
    } catch (e) {
      state = state.copyWith(error: 'Erreur: $e');
    }
  }

  /// Skip backward by seconds (default 10s)
  Future<void> skipBackward({int seconds = 10}) async {
    if (_handler == null) return;
    try {
      await _handler!.rewind();
    } catch (e) {
      state = state.copyWith(error: 'Erreur: $e');
    }
  }

  /// Set playback speed
  Future<void> setSpeed(double speed) async {
    if (_handler == null) return;
    try {
      await _handler!.setSpeed(speed);
      state = state.copyWith(speed: speed);
    } catch (e) {
      state = state.copyWith(error: 'Erreur: $e');
    }
  }

  /// Stop and clear the current episode
  Future<void> stop() async {
    if (_handler == null) return;
    try {
      await _handler!.stop();
      state = PodcastPlayerState.initial();
    } catch (e) {
      state = state.copyWith(error: 'Erreur: $e');
    }
  }
}
