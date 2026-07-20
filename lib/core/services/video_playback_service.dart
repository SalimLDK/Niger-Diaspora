import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import 'audio_playback_service.dart';

/// Service for managing inline video playback in message bubbles
/// Singleton pattern ensures only one video plays at a time
class VideoPlaybackService extends ChangeNotifier {
  static final VideoPlaybackService _instance =
      VideoPlaybackService._internal();
  factory VideoPlaybackService() => _instance;
  VideoPlaybackService._internal();

  VideoPlayerController? _controller;
  String? _currentMessageId;
  bool _isMuted = false;
  bool _isInitializing = false;
  String? _error;
  bool _isLooping = false;
  double _playbackSpeed = 1.0;

  /// Available playback speed options
  static const List<double> speedOptions = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  /// The message ID of the currently playing video
  String? get currentMessageId => _currentMessageId;

  /// The current video controller
  VideoPlayerController? get controller => _controller;

  /// Whether video is muted
  bool get isMuted => _isMuted;

  /// Whether a video is currently playing
  bool get isPlaying => _controller?.value.isPlaying ?? false;

  /// Whether controller is initialized
  bool get isInitialized => _controller?.value.isInitialized ?? false;

  /// Whether we're currently initializing a video
  bool get isInitializing => _isInitializing;

  /// Current error message if any
  String? get error => _error;

  /// Whether video is looping
  bool get isLooping => _isLooping;

  /// Current playback speed
  double get playbackSpeed => _playbackSpeed;

  /// Current playback position
  Duration get position => _controller?.value.position ?? Duration.zero;

  /// Total video duration
  Duration get duration => _controller?.value.duration ?? Duration.zero;

  /// Check if a specific message's video is currently active
  bool isActiveVideo(String messageId) => _currentMessageId == messageId;

  /// Check if a specific message's video is currently playing
  bool isPlayingVideo(String messageId) =>
      _currentMessageId == messageId && isPlaying;

  /// Play a video for a specific message
  /// Returns true if video started successfully
  Future<bool> play(String messageId, String videoPath) async {
    _error = null;

    // If same video, toggle play/pause
    if (_currentMessageId == messageId && _controller != null) {
      if (_controller!.value.isInitialized) {
        if (_controller!.value.isPlaying) {
          await _controller!.pause();
        } else {
          // Reset to start if video completed
          if (_controller!.value.position >= _controller!.value.duration) {
            await _controller!.seekTo(Duration.zero);
          }
          await _controller!.play();
        }
        notifyListeners();
        return true;
      }
    }

    // Stop any currently playing audio
    AudioPlaybackService().stop();

    // Stop current video if different
    await stop();

    _isInitializing = true;
    _currentMessageId = messageId;
    notifyListeners();

    try {
      // Initialize new controller based on path type
      if (videoPath.startsWith('http')) {
        _controller = VideoPlayerController.networkUrl(Uri.parse(videoPath));
      } else {
        _controller = VideoPlayerController.file(File(videoPath));
      }

      await _controller!.initialize();
      _controller!.setLooping(_isLooping);
      _controller!.setVolume(_isMuted ? 0.0 : 1.0);
      _controller!.setPlaybackSpeed(_playbackSpeed);

      // Add listener for state changes
      _controller!.addListener(_onVideoStateChanged);

      _isInitializing = false;
      await _controller!.play();
      notifyListeners();

      return true;
    } catch (e) {
      debugPrint('VideoPlaybackService: Error initializing video: $e');
      _error = 'Erreur de lecture';
      _isInitializing = false;
      _currentMessageId = null;
      _controller?.dispose();
      _controller = null;
      notifyListeners();
      return false;
    }
  }

  void _onVideoStateChanged() {
    // Notify listeners of state changes (position, playing status, etc.)
    notifyListeners();

    // Check if video completed
    if (_controller != null &&
        _controller!.value.isInitialized &&
        !_controller!.value.isPlaying &&
        _controller!.value.position >= _controller!.value.duration &&
        _controller!.value.duration > Duration.zero) {
      // Video completed - optionally stop
      // We keep the controller so user can replay
    }
  }

  /// Pause playback
  Future<void> pause() async {
    try {
      await _controller?.pause();
      notifyListeners();
    } catch (e) {
      debugPrint('VideoPlaybackService: Error pausing: $e');
    }
  }

  /// Resume playback
  Future<void> resume() async {
    try {
      await _controller?.play();
      notifyListeners();
    } catch (e) {
      debugPrint('VideoPlaybackService: Error resuming: $e');
    }
  }

  /// Stop playback and dispose controller
  Future<void> stop() async {
    try {
      _controller?.removeListener(_onVideoStateChanged);
      await _controller?.pause();
      await _controller?.dispose();
      _controller = null;
      _currentMessageId = null;
      _isInitializing = false;
      _error = null;
      notifyListeners();
    } catch (e) {
      debugPrint('VideoPlaybackService: Error stopping: $e');
    }
  }

  /// Seek to a specific position
  Future<void> seekTo(Duration position) async {
    try {
      await _controller?.seekTo(position);
      notifyListeners();
    } catch (e) {
      debugPrint('VideoPlaybackService: Error seeking: $e');
    }
  }

  /// Toggle mute state
  void toggleMute() {
    _isMuted = !_isMuted;
    _controller?.setVolume(_isMuted ? 0.0 : 1.0);
    notifyListeners();
  }

  /// Set mute state
  void setMuted(bool muted) {
    _isMuted = muted;
    _controller?.setVolume(_isMuted ? 0.0 : 1.0);
    notifyListeners();
  }

  /// Toggle loop state
  void toggleLoop() {
    _isLooping = !_isLooping;
    _controller?.setLooping(_isLooping);
    notifyListeners();
  }

  /// Set loop state
  void setLooping(bool looping) {
    _isLooping = looping;
    _controller?.setLooping(_isLooping);
    notifyListeners();
  }

  /// Set playback speed
  void setSpeed(double speed) {
    if (!speedOptions.contains(speed)) return;
    _playbackSpeed = speed;
    _controller?.setPlaybackSpeed(speed);
    notifyListeners();
  }

  /// Cycle through playback speeds
  void cycleSpeed() {
    final currentIndex = speedOptions.indexOf(_playbackSpeed);
    final nextIndex = (currentIndex + 1) % speedOptions.length;
    setSpeed(speedOptions[nextIndex]);
  }

  /// Seek relative to current position (for double-tap seek)
  Future<void> seekRelative(int seconds) async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    final currentPosition = _controller!.value.position;
    final duration = _controller!.value.duration;
    final newPosition = Duration(
      milliseconds: (currentPosition.inMilliseconds + (seconds * 1000))
          .clamp(0, duration.inMilliseconds),
    );
    await seekTo(newPosition);
  }

  /// Get current position as fraction (0.0 - 1.0)
  double get progressFraction {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _controller!.value.duration.inMilliseconds == 0) {
      return 0.0;
    }
    return _controller!.value.position.inMilliseconds /
        _controller!.value.duration.inMilliseconds;
  }

  @override
  void dispose() {
    _controller?.removeListener(_onVideoStateChanged);
    _controller?.dispose();
    super.dispose();
  }
}

/// Provider for the video playback service
final videoPlaybackServiceProvider =
    ChangeNotifierProvider<VideoPlaybackService>((ref) {
  return VideoPlaybackService();
});

/// Provider to check if a specific video is playing
final isVideoPlayingProvider = Provider.family<bool, String>((ref, messageId) {
  final service = ref.watch(videoPlaybackServiceProvider);
  return service.isPlayingVideo(messageId);
});

/// Provider to check if a specific video is active (playing or paused)
final isVideoActiveProvider = Provider.family<bool, String>((ref, messageId) {
  final service = ref.watch(videoPlaybackServiceProvider);
  return service.isActiveVideo(messageId);
});
