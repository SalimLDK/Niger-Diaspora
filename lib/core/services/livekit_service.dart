import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/widgets.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

import '../../features/group_calls/domain/entities/group_participant_entity.dart';
import 'preferences_service.dart';

/// Callback types for LiveKit events
typedef OnLiveKitParticipantCallback =
    void Function(lk.RemoteParticipant participant);
typedef OnLiveKitTrackCallback =
    void Function(
      lk.RemoteParticipant participant,
      lk.RemoteTrackPublication publication,
    );

/// RoomState enum for connection state
enum LiveKitRoomState { disconnected, connecting, connected, reconnecting }

/// Service for managing LiveKit SFU-based group calls (5+ participants)
///
/// Uses LiveKit for:
/// - Scalable group video/audio calls
/// - Automatic bandwidth management (simulcast)
/// - Built-in E2EE support
class LiveKitService {
  static final LiveKitService _instance = LiveKitService._internal();
  factory LiveKitService() => _instance;
  LiveKitService._internal();

  static LiveKitService get instance => _instance;

  // LiveKit server URL (configure for your self-hosted instance)
  static String get _serverUrl => dotenv.env['LIVEKIT_SERVER_URL'] ?? 'wss://livekit.diasponiger.com';

  // Cloud Functions for token generation
  final _functions = FirebaseFunctions.instance;

  // LiveKit Room
  lk.Room? _room;
  lk.LocalParticipant? _localParticipant;

  // State
  bool _isConnected = false;
  bool _isMuted = false;
  bool _isCameraOff = true;
  bool _isScreenSharing = false;
  bool _isE2EEEnabled = false;
  String? _currentRoomName;
  bool _noiseSuppressionEnabled =
      true; // Default to enabled for better audio quality

  /// Get the current room name
  String? get currentRoomName => _currentRoomName;

  // Event listeners
  lk.EventsListener<lk.RoomEvent>? _roomListener;

  // Callbacks
  OnLiveKitParticipantCallback? _onParticipantJoined;
  OnLiveKitParticipantCallback? _onParticipantLeft;
  OnLiveKitTrackCallback? _onTrackSubscribed;
  OnLiveKitTrackCallback? _onTrackUnsubscribed;
  VoidCallback? _onDisconnected;

  // Stream controllers (non-final to allow re-creation in _ensureControllers)
  StreamController<List<lk.RemoteParticipant>> _participantsController =
      StreamController<List<lk.RemoteParticipant>>.broadcast();
  StreamController<LiveKitRoomState> _connectionStateController =
      StreamController<LiveKitRoomState>.broadcast();
  StreamController<Set<String>> _speakingParticipantsController =
      StreamController<Set<String>>.broadcast();

  // Getters
  bool get isConnected => _isConnected;
  bool get isMuted => _isMuted;
  bool get isCameraOff => _isCameraOff;
  bool get isScreenSharing => _isScreenSharing;
  bool get isE2EEEnabled => _isE2EEEnabled;
  bool get noiseSuppressionEnabled => _noiseSuppressionEnabled;
  lk.Room? get room => _room;
  lk.LocalParticipant? get localParticipant => _localParticipant;
  List<lk.RemoteParticipant> get remoteParticipants =>
      _room?.remoteParticipants.values.toList() ?? [];
  Stream<List<lk.RemoteParticipant>> get participantsStream =>
      _participantsController.stream;
  Stream<LiveKitRoomState> get connectionStateStream =>
      _connectionStateController.stream;
  Stream<Set<String>> get speakingParticipantsStream =>
      _speakingParticipantsController.stream;

  /// Join a LiveKit room
  ///
  /// [roomName] - Name of the room to join
  /// [participantName] - Display name for this participant
  /// [enableVideo] - Whether to enable video initially
  /// [enableSimulcast] - Whether to enable simulcast (multiple quality layers)
  /// [enableE2EE] - Whether to enable end-to-end encryption
  /// [enableNoiseSuppression] - Whether to enable noise suppression (recommended for Sahel regions)
  ///   If null, uses the user's saved preference from settings
  Future<void> joinRoom({
    required String roomName,
    required String participantName,
    bool enableVideo = false,
    bool enableSimulcast = true,
    bool enableE2EE = false,
    String? e2eeKey,
    bool? enableNoiseSuppression,
    OnLiveKitParticipantCallback? onParticipantJoined,
    OnLiveKitParticipantCallback? onParticipantLeft,
    OnLiveKitTrackCallback? onTrackSubscribed,
    OnLiveKitTrackCallback? onTrackUnsubscribed,
    VoidCallback? onDisconnected,
  }) async {
    _onParticipantJoined = onParticipantJoined;
    _onParticipantLeft = onParticipantLeft;
    _onTrackSubscribed = onTrackSubscribed;
    _onTrackUnsubscribed = onTrackUnsubscribed;
    _onDisconnected = onDisconnected;
    _currentRoomName = roomName;
    _isE2EEEnabled = enableE2EE && e2eeKey != null;
    _ensureControllers();

    // Use provided value or fall back to user's saved preference
    final useNoiseSuppression =
        enableNoiseSuppression ??
        PreferencesService.instance.noiseSuppressionEnabled;
    _noiseSuppressionEnabled = useNoiseSuppression;

    try {
      // Get token from Cloud Function
      final token = await _getToken(roomName, participantName);

      // Configure audio capture options with noise suppression
      // Noise suppression is recommended for Sahel regions with variable environments
      final audioCaptureOptions = lk.AudioCaptureOptions(
        noiseSuppression: useNoiseSuppression,
        echoCancellation: true,
        autoGainControl: true,
        typingNoiseDetection: true,
        highPassFilter: true, // Filter low-frequency noise (wind, AC, etc.)
      );

      // Set up E2EE when a key is provided
      lk.E2EEOptions? e2eeOptions;
      if (_isE2EEEnabled && e2eeKey != null) {
        final keyProvider = await lk.BaseKeyProvider.create();
        await keyProvider.setKey(e2eeKey);
        e2eeOptions = lk.E2EEOptions(keyProvider: keyProvider);
        debugPrint('LiveKitService: E2EE enabled for room $roomName');
      }

      // Configure room options
      final roomOptions = lk.RoomOptions(
        adaptiveStream: true,
        dynacast: true, // Enable dynamic broadcast for efficient bandwidth
        defaultAudioCaptureOptions: audioCaptureOptions,
        defaultAudioPublishOptions: const lk.AudioPublishOptions(
          dtx: true, // Discontinuous transmission for audio
        ),
        defaultVideoPublishOptions: lk.VideoPublishOptions(
          simulcast: enableSimulcast,
          videoCodec: 'vp8',
          videoSimulcastLayers: [
            const lk.VideoParameters(
              dimensions: lk.VideoDimensions(180, 180),
              encoding: lk.VideoEncoding(maxBitrate: 150000, maxFramerate: 15),
            ),
            const lk.VideoParameters(
              dimensions: lk.VideoDimensions(360, 360),
              encoding: lk.VideoEncoding(maxBitrate: 500000, maxFramerate: 25),
            ),
            const lk.VideoParameters(
              dimensions: lk.VideoDimensions(720, 720),
              encoding: lk.VideoEncoding(maxBitrate: 1500000, maxFramerate: 30),
            ),
          ],
        ),
        defaultScreenShareCaptureOptions: const lk.ScreenShareCaptureOptions(
          useiOSBroadcastExtension: true,
          maxFrameRate: 15.0,
        ),
        e2eeOptions: e2eeOptions,
      );

      // Create and connect to room
      _room = lk.Room(roomOptions: roomOptions);

      // Setup event listeners
      _setupRoomListeners();

      // Connect to room
      await _room!.connect(_serverUrl, token);

      _localParticipant = _room!.localParticipant;
      _isConnected = true;
      _connectionStateController.add(LiveKitRoomState.connected);

      // Publish local tracks based on settings
      await _localParticipant!.setMicrophoneEnabled(true);
      _isMuted = false;

      if (enableVideo) {
        await _localParticipant!.setCameraEnabled(true);
        _isCameraOff = false;
      }

      debugPrint(
        'LiveKitService: Connected to room $roomName with ${remoteParticipants.length} participants',
      );
    } catch (e) {
      debugPrint('LiveKitService: Error joining room: $e');
      _isConnected = false;
      // H5 fix: Clean up partially initialized room on failure to prevent leak
      await leaveRoom();
      rethrow;
    }
  }

  /// Join a LiveKit room using an externally-fetched token.
  /// Identical to [joinRoom] except the token is provided by the caller
  /// (used by audio rooms which have their own Cloud Function for token generation).
  Future<void> joinRoomWithToken({
    required String roomName,
    required String token,
    required String participantName,
    bool enableVideo = false,
    bool enableSimulcast = true,
    String? e2eeKey,
    OnLiveKitParticipantCallback? onParticipantJoined,
    OnLiveKitParticipantCallback? onParticipantLeft,
    OnLiveKitTrackCallback? onTrackSubscribed,
    OnLiveKitTrackCallback? onTrackUnsubscribed,
    VoidCallback? onDisconnected,
  }) async {
    _onParticipantJoined = onParticipantJoined;
    _onParticipantLeft = onParticipantLeft;
    _onTrackSubscribed = onTrackSubscribed;
    _onTrackUnsubscribed = onTrackUnsubscribed;
    _onDisconnected = onDisconnected;
    _currentRoomName = roomName;
    _isE2EEEnabled = e2eeKey != null;
    _ensureControllers();

    final useNoiseSuppression = PreferencesService.instance.noiseSuppressionEnabled;
    _noiseSuppressionEnabled = useNoiseSuppression;

    try {
      final audioCaptureOptions = lk.AudioCaptureOptions(
        noiseSuppression: useNoiseSuppression,
        echoCancellation: true,
        autoGainControl: true,
        typingNoiseDetection: true,
        highPassFilter: true,
      );

      lk.E2EEOptions? e2eeOptions;
      if (e2eeKey != null) {
        final keyProvider = await lk.BaseKeyProvider.create();
        await keyProvider.setKey(e2eeKey);
        e2eeOptions = lk.E2EEOptions(keyProvider: keyProvider);
        debugPrint('LiveKitService: E2EE enabled for room $roomName');
      }

      final roomOptions = lk.RoomOptions(
        adaptiveStream: true,
        dynacast: true,
        defaultAudioCaptureOptions: audioCaptureOptions,
        defaultAudioPublishOptions: const lk.AudioPublishOptions(dtx: true),
        defaultVideoPublishOptions: lk.VideoPublishOptions(
          simulcast: enableSimulcast,
          videoCodec: 'vp8',
        ),
        e2eeOptions: e2eeOptions,
      );

      _room = lk.Room(roomOptions: roomOptions);
      _setupRoomListeners();
      await _room!.connect(_serverUrl, token);

      _localParticipant = _room!.localParticipant;
      _isConnected = true;
      _connectionStateController.add(LiveKitRoomState.connected);

      await _localParticipant!.setMicrophoneEnabled(true);
      _isMuted = false;

      if (enableVideo) {
        await _localParticipant!.setCameraEnabled(true);
        _isCameraOff = false;
      }

      debugPrint('LiveKitService: Connected to room $roomName (external token)');
    } catch (e) {
      debugPrint('LiveKitService: joinRoomWithToken error: $e');
      _isConnected = false;
      await leaveRoom();
      rethrow;
    }
  }

  /// Get authentication token from Cloud Function
  Future<String> _getToken(String roomName, String participantName) async {
    try {
      final callable = _functions.httpsCallable(
        'getLiveKitToken',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
      );
      final result = await callable.call<Map<String, dynamic>>({
        'roomName': roomName,
        'participantName': participantName,
      });

      return result.data['token'] as String;
    } catch (e) {
      debugPrint('LiveKitService: Error getting token: $e');
      rethrow;
    }
  }

  /// Setup room event listeners
  void _setupRoomListeners() {
    _roomListener = _room!.createListener();

    _roomListener!
      ..on<lk.ParticipantConnectedEvent>((event) {
        debugPrint(
          'LiveKitService: Participant joined: ${event.participant.identity}',
        );
        _onParticipantJoined?.call(event.participant);
        _notifyParticipantsChanged();
      })
      ..on<lk.ParticipantDisconnectedEvent>((event) {
        debugPrint(
          'LiveKitService: Participant left: ${event.participant.identity}',
        );
        _onParticipantLeft?.call(event.participant);
        _notifyParticipantsChanged();
      })
      ..on<lk.TrackSubscribedEvent>((event) {
        debugPrint(
          'LiveKitService: Track subscribed from ${event.participant.identity}',
        );
        _onTrackSubscribed?.call(event.participant, event.publication);
      })
      ..on<lk.TrackUnsubscribedEvent>((event) {
        debugPrint(
          'LiveKitService: Track unsubscribed from ${event.participant.identity}',
        );
        _onTrackUnsubscribed?.call(event.participant, event.publication);
      })
      ..on<lk.RoomDisconnectedEvent>((event) {
        debugPrint('LiveKitService: Disconnected from room');
        _isConnected = false;
        _connectionStateController.add(LiveKitRoomState.disconnected);
        _onDisconnected?.call();
      })
      ..on<lk.RoomReconnectingEvent>((event) {
        debugPrint('LiveKitService: Reconnecting...');
        _connectionStateController.add(LiveKitRoomState.reconnecting);
      })
      ..on<lk.RoomReconnectedEvent>((event) {
        debugPrint('LiveKitService: Reconnected');
        _connectionStateController.add(LiveKitRoomState.connected);
      })
      ..on<lk.ActiveSpeakersChangedEvent>((event) {
        final speakingIds =
            event.speakers.map((p) => p.identity).whereType<String>().toSet();
        _speakingParticipantsController.add(speakingIds);
      })
      ..on<lk.ParticipantNameUpdatedEvent>((event) {
        _notifyParticipantsChanged();
      });
  }

  /// Notify that participants list has changed
  void _notifyParticipantsChanged() {
    _participantsController.add(remoteParticipants);
  }

  /// Toggle microphone mute
  Future<void> toggleMute() async {
    final prev = _isMuted;
    _isMuted = !_isMuted;
    try {
      await _localParticipant?.setMicrophoneEnabled(!_isMuted);
      debugPrint('LiveKitService: Muted: $_isMuted');
    } catch (e) {
      _isMuted = prev;
      debugPrint('LiveKitService: toggleMute failed, reverted: $e');
      rethrow;
    }
  }

  /// Set microphone enabled/disabled
  Future<void> setMicrophoneEnabled(bool enabled) async {
    _isMuted = !enabled;
    await _localParticipant?.setMicrophoneEnabled(enabled);
  }

  /// Toggle camera on/off
  Future<void> toggleCamera() async {
    final prev = _isCameraOff;
    _isCameraOff = !_isCameraOff;
    try {
      await _localParticipant?.setCameraEnabled(!_isCameraOff);
      debugPrint('LiveKitService: Camera off: $_isCameraOff');
    } catch (e) {
      _isCameraOff = prev;
      debugPrint('LiveKitService: toggleCamera failed, reverted: $e');
      rethrow;
    }
  }

  /// Set camera enabled/disabled
  Future<void> setCameraEnabled(bool enabled) async {
    _isCameraOff = !enabled;
    await _localParticipant?.setCameraEnabled(enabled);
  }

  /// Switch between front and back camera
  Future<void> switchCamera() async {
    try {
      final localParticipant = _localParticipant;
      if (localParticipant == null) {
        debugPrint('LiveKitService: No local participant to switch camera');
        return;
      }
      // Find the camera video track from published tracks
      final cameraPub = localParticipant.videoTrackPublications.firstOrNull;
      if (cameraPub == null || cameraPub.track == null) {
        debugPrint('LiveKitService: No camera track to switch');
        return;
      }
      final cameraTrack = cameraPub.track!;
      // H6 fix: Properly toggle camera position (front ↔ back)
      final hardware = lk.Hardware.instance;
      final videoInputs = await hardware.videoInputs();
      if (videoInputs.length < 2) {
        debugPrint('LiveKitService: Only one camera available');
        return;
      }
      // Find the camera that is NOT currently selected
      final currentDevice = hardware.selectedVideoInput;
      final targetDevice = videoInputs.firstWhere(
        (d) => d.deviceId != currentDevice?.deviceId,
        orElse: () => videoInputs[1],
      );
      await cameraTrack.switchCamera(targetDevice.deviceId);
      hardware.selectedVideoInput = targetDevice;
      debugPrint('LiveKitService: Camera switched');
    } catch (e) {
      debugPrint('LiveKitService: Error switching camera: $e');
    }
  }

  /// Toggle screen sharing
  Future<void> toggleScreenShare() async {
    _isScreenSharing = !_isScreenSharing;
    await _localParticipant?.setScreenShareEnabled(_isScreenSharing);
    debugPrint('LiveKitService: Screen sharing: $_isScreenSharing');
  }

  /// Set video quality preference for receiving
  Future<void> setVideoQuality(
    lk.RemoteParticipant participant,
    VideoQuality quality,
  ) async {
    final videoPublication =
        participant.videoTrackPublications
            .where((pub) => pub.source == lk.TrackSource.camera)
            .firstOrNull;

    if (videoPublication?.track != null) {
      // Request specific quality layer
      final lkQuality = switch (quality) {
        VideoQuality.low => lk.VideoQuality.LOW,
        VideoQuality.medium => lk.VideoQuality.MEDIUM,
        VideoQuality.high => lk.VideoQuality.HIGH,
      };

      // Update subscription with preferred quality
      await videoPublication!.setVideoQuality(lkQuality);
      debugPrint(
        'LiveKitService: Set video quality to ${quality.name} for ${participant.identity}',
      );
    }
  }

  /// Get video widget for a participant
  Widget? getVideoWidget(lk.Participant participant) {
    final videoTrack = participant.videoTrackPublications.firstOrNull?.track;

    if (videoTrack != null) {
      return lk.VideoTrackRenderer(videoTrack as lk.VideoTrack);
    }
    return null;
  }

  /// Get local video widget
  Widget? getLocalVideoWidget() {
    if (_localParticipant == null) return null;
    return getVideoWidget(_localParticipant!);
  }

  /// Leave the current room
  Future<void> leaveRoom() async {
    debugPrint('LiveKitService: Leaving room');

    _roomListener?.dispose();
    _roomListener = null;

    await _room?.disconnect();
    await _room?.dispose();
    _room = null;

    _localParticipant = null;
    _isConnected = false;
    _isMuted = false;
    _isCameraOff = true;
    _isScreenSharing = false;
    _currentRoomName = null;

    _connectionStateController.add(LiveKitRoomState.disconnected);

    debugPrint('LiveKitService: Left room successfully');
  }

  /// Dispose resources
  ///
  /// H16 fix: This is intended for final app shutdown only.
  /// For leaving a single room (to potentially join another), use [leaveRoom].
  Future<void> dispose() async {
    await leaveRoom();
    await _participantsController.close();
    await _connectionStateController.close();
    await _speakingParticipantsController.close();
    _isDisposed = true;
  }

  bool _isDisposed = false;

  /// Ensure stream controllers are open before use.
  /// Re-creates closed controllers so the service can be reused after dispose.
  void _ensureControllers() {
    if (_isDisposed) {
      _participantsController = StreamController<List<lk.RemoteParticipant>>.broadcast();
      _connectionStateController = StreamController<LiveKitRoomState>.broadcast();
      _speakingParticipantsController = StreamController<Set<String>>.broadcast();
      _isDisposed = false;
    } else {
      if (_participantsController.isClosed) {
        _participantsController = StreamController<List<lk.RemoteParticipant>>.broadcast();
      }
      if (_connectionStateController.isClosed) {
        _connectionStateController = StreamController<LiveKitRoomState>.broadcast();
      }
      if (_speakingParticipantsController.isClosed) {
        _speakingParticipantsController = StreamController<Set<String>>.broadcast();
      }
    }
  }
}
