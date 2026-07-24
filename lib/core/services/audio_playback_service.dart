import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// Service for playing audio messages
class AudioPlaybackService {
  static final AudioPlaybackService _instance =
      AudioPlaybackService._internal();
  factory AudioPlaybackService() => _instance;
  AudioPlaybackService._internal();

  final AudioPlayer _player = AudioPlayer();
  String? _currentlyPlayingUrl;

  /// Stream of current playback position
  Stream<Duration> get positionStream => _player.positionStream;

  /// Stream of buffered position
  Stream<Duration> get bufferedPositionStream => _player.bufferedPositionStream;

  /// Stream of total duration
  Stream<Duration?> get durationStream => _player.durationStream;

  /// Stream of player state
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  /// Stream of playing status
  Stream<bool> get playingStream => _player.playingStream;

  /// Current position
  Duration get position => _player.position;

  /// Total duration
  Duration? get duration => _player.duration;

  /// Whether the player is currently playing
  bool get isPlaying => _player.playing;

  /// The URL currently being played
  String? get currentlyPlayingUrl => _currentlyPlayingUrl;

  /// Check if a specific URL is currently playing
  bool isPlayingUrl(String url) =>
      _currentlyPlayingUrl == url && _player.playing;

  /// Check if a specific URL is loaded (playing or paused)
  bool isLoadedUrl(String url) => _currentlyPlayingUrl == url;

  /// Play audio from a URL
  Future<void> play(String url) async {
    try {
      // If already playing the same URL, just resume
      if (_currentlyPlayingUrl == url) {
        if (!_player.playing) {
          await _player.play();
        }
        return;
      }

      // Stop current playback if any
      await stop();

      // Load and play new audio
      _currentlyPlayingUrl = url;
      await _player.setUrl(url);
      await _player.play();

      // Listen for completion
      _player.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          _currentlyPlayingUrl = null;
        }
      });
    } catch (e) {
      debugPrint('Error playing audio: $e');
      _currentlyPlayingUrl = null;
      rethrow;
    }
  }

  /// Pause playback
  Future<void> pause() async {
    try {
      await _player.pause();
    } catch (e) {
      debugPrint('Error pausing audio: $e');
    }
  }

  /// Resume playback
  Future<void> resume() async {
    try {
      await _player.play();
    } catch (e) {
      debugPrint('Error resuming audio: $e');
    }
  }

  /// Stop playback
  Future<void> stop() async {
    try {
      await _player.stop();
      _currentlyPlayingUrl = null;
    } catch (e) {
      debugPrint('Error stopping audio: $e');
    }
  }

  /// Seek to a specific position
  Future<void> seek(Duration position) async {
    try {
      await _player.seek(position);
    } catch (e) {
      debugPrint('Error seeking audio: $e');
    }
  }

  /// Set playback speed
  Future<void> setSpeed(double speed) async {
    try {
      await _player.setSpeed(speed);
    } catch (e) {
      debugPrint('Error setting speed: $e');
    }
  }

  /// Toggle play/pause for a specific URL
  Future<void> togglePlayPause(String url) async {
    if (isPlayingUrl(url)) {
      await pause();
    } else if (isLoadedUrl(url)) {
      await resume();
    } else {
      await play(url);
    }
  }

  /// Reads audio duration from a local file (seconds).
  static Future<int?> getDurationFromFile(String filePath) async {
    try {
      final player = AudioPlayer();
      await player.setFilePath(filePath);
      final duration = player.duration;
      await player.dispose();
      return duration?.inSeconds;
    } catch (e) {
      debugPrint('getDurationFromFile error: $e');
      return null;
    }
  }

  /// Dispose resources
  void dispose() {
    _player.dispose();
  }
}
