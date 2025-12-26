import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Service for recording audio messages
class AudioRecordingService {
  static final AudioRecordingService _instance =
      AudioRecordingService._internal();
  factory AudioRecordingService() => _instance;
  AudioRecordingService._internal();

  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  String? _currentPath;
  DateTime? _recordingStartTime;
  Timer? _durationTimer;

  final _durationController = StreamController<int>.broadcast();
  final _amplitudeController = StreamController<double>.broadcast();

  /// Whether the recorder is currently recording
  bool get isRecording => _isRecording;

  /// Stream of recording duration in seconds
  Stream<int> get durationStream => _durationController.stream;

  /// Stream of amplitude values for waveform visualization (0.0 to 1.0)
  Stream<double> get amplitudeStream => _amplitudeController.stream;

  /// Current recording duration in seconds
  int get currentDuration {
    if (_recordingStartTime == null) return 0;
    return DateTime.now().difference(_recordingStartTime!).inSeconds;
  }

  /// Request microphone permission
  Future<bool> requestPermission() async {
    try {
      return await _recorder.hasPermission();
    } catch (e) {
      debugPrint('Error requesting audio permission: $e');
      return false;
    }
  }

  /// Start recording audio
  /// Returns the file path where the audio will be saved
  Future<String?> startRecording() async {
    try {
      if (_isRecording) {
        await cancelRecording();
      }

      final hasPermission = await requestPermission();
      if (!hasPermission) {
        debugPrint('Microphone permission denied');
        return null;
      }

      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentPath = '${directory.path}/audio_$timestamp.m4a';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: _currentPath!,
      );

      _isRecording = true;
      _recordingStartTime = DateTime.now();

      // Start duration timer
      _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        _durationController.add(currentDuration);
      });

      // Start amplitude monitoring for waveform
      _startAmplitudeMonitoring();

      return _currentPath;
    } catch (e) {
      debugPrint('Error starting recording: $e');
      _isRecording = false;
      return null;
    }
  }

  void _startAmplitudeMonitoring() {
    Timer.periodic(const Duration(milliseconds: 100), (timer) async {
      if (!_isRecording) {
        timer.cancel();
        return;
      }

      try {
        final amplitude = await _recorder.getAmplitude();
        // Normalize amplitude from dB to 0.0-1.0 range
        // Typical amplitude range is -60 to 0 dB
        final normalized = ((amplitude.current + 60) / 60).clamp(0.0, 1.0);
        _amplitudeController.add(normalized);
      } catch (e) {
        // Ignore amplitude errors
      }
    });
  }

  /// Stop recording and return the recorded file with duration
  /// Returns a tuple of (File, duration in seconds, waveform data)
  Future<(File, int, List<double>)?> stopRecording() async {
    if (!_isRecording) return null;

    try {
      final duration = currentDuration;
      final path = await _recorder.stop();

      _durationTimer?.cancel();
      _durationTimer = null;
      _isRecording = false;

      if (path == null || path.isEmpty) {
        return null;
      }

      final file = File(path);
      if (!await file.exists()) {
        return null;
      }

      // Generate simple waveform data (placeholder - actual implementation would analyze audio)
      final waveform = _generatePlaceholderWaveform(duration);

      _recordingStartTime = null;
      _currentPath = null;

      return (file, duration, waveform);
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      _isRecording = false;
      return null;
    }
  }

  /// Cancel the current recording
  Future<void> cancelRecording() async {
    if (!_isRecording) return;

    try {
      await _recorder.stop();

      _durationTimer?.cancel();
      _durationTimer = null;
      _isRecording = false;

      // Delete the partial recording file
      if (_currentPath != null) {
        final file = File(_currentPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }

      _recordingStartTime = null;
      _currentPath = null;
    } catch (e) {
      debugPrint('Error canceling recording: $e');
      _isRecording = false;
    }
  }

  /// Generate placeholder waveform data
  /// In a real implementation, this would analyze the actual audio file
  List<double> _generatePlaceholderWaveform(int durationSeconds) {
    // Generate ~30 samples per second for visualization
    final sampleCount = durationSeconds * 30;
    final waveform = <double>[];

    for (int i = 0; i < sampleCount; i++) {
      // Generate somewhat random but smooth waveform
      final value =
          0.3 + 0.5 * (i % 10 / 10) + 0.2 * ((i * 7) % 13 / 13);
      waveform.add(value.clamp(0.1, 1.0));
    }

    return waveform;
  }

  /// Dispose resources
  void dispose() {
    _durationTimer?.cancel();
    _durationController.close();
    _amplitudeController.close();
    _recorder.dispose();
  }
}
