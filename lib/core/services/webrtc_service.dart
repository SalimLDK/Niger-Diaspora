import 'dart:async';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:firebase_database/firebase_database.dart';

/// ICE servers configuration — populated at call time from Cloud Function.
/// TURN credentials are ephemeral (HMAC-based) and never stored in source code.
class IceServerConfig {
  /// Static STUN servers (no credentials needed)
  static const List<Map<String, dynamic>> stunServers = [
    {
      'urls': [
        'stun:turn.diasponiger.com:3478',
        'stun:stun1.l.google.com:19302',
      ],
    },
  ];

  /// Fetches ephemeral TURN credentials from the backend and returns
  /// the full ICE server list (STUN + TURN with short-lived credentials).
  static Future<List<Map<String, dynamic>>> fetchIceServers() async {
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('getTurnCredentials')
          .call<Map<String, dynamic>>({});

      final data = result.data;
      final turnUsername = data['username'] as String?;
      final turnCredential = data['credential'] as String?;
      final ttlSeconds = data['ttl'] as int?;

      if (turnUsername == null || turnCredential == null) {
        debugPrint('IceServerConfig: TURN credentials missing, using STUN only');
        return [...stunServers];
      }

      debugPrint('IceServerConfig: TURN credentials obtained (ttl=${ttlSeconds}s)');
      return [
        ...stunServers,
        // Self-hosted TURN server (UDP)
        {
          'urls': 'turn:turn.diasponiger.com:3478',
          'username': turnUsername,
          'credential': turnCredential,
        },
        // Self-hosted TURNS server (TLS - for restrictive networks)
        {
          'urls': 'turns:turn.diasponiger.com:5349',
          'username': turnUsername,
          'credential': turnCredential,
        },
        // TCP fallback for strict firewalls
        {
          'urls': 'turn:turn.diasponiger.com:3478?transport=tcp',
          'username': turnUsername,
          'credential': turnCredential,
        },
      ];
    } catch (e) {
      debugPrint('IceServerConfig: Failed to fetch TURN credentials: $e');
      // Fallback to STUN-only (calls will work on most networks, may fail on strict firewalls)
      return [...stunServers];
    }
  }
}

/// Represents the state of a WebRTC connection
enum WebRTCConnectionState {
  idle,
  connecting,
  connected,
  reconnecting,
  disconnected,
  failed,
}

/// Call quality level
enum CallQualityLevel { excellent, good, fair, poor, unknown }

/// Metrics for call quality monitoring
class CallQualityMetrics {
  final double? roundTripTimeMs;
  final double? jitterMs;
  final double? packetLossPercent;
  final int? availableBandwidthKbps;
  final String? audioCodec;
  final String? videoCodec;
  final int? frameRate;
  final int? frameWidth;
  final int? frameHeight;
  final int? audioBytesSent;
  final int? audioBytesReceived;
  final int? videoBytesSent;
  final int? videoBytesReceived;
  final CallQualityLevel qualityLevel;
  final DateTime timestamp;

  const CallQualityMetrics({
    this.roundTripTimeMs,
    this.jitterMs,
    this.packetLossPercent,
    this.availableBandwidthKbps,
    this.audioCodec,
    this.videoCodec,
    this.frameRate,
    this.frameWidth,
    this.frameHeight,
    this.audioBytesSent,
    this.audioBytesReceived,
    this.videoBytesSent,
    this.videoBytesReceived,
    this.qualityLevel = CallQualityLevel.unknown,
    required this.timestamp,
  });

  /// Calculate quality level based on metrics
  static CallQualityLevel calculateQualityLevel({
    double? rtt,
    double? packetLoss,
    double? jitter,
  }) {
    if (rtt == null && packetLoss == null) return CallQualityLevel.unknown;

    // Excellent: RTT < 100ms, packet loss < 1%, jitter < 30ms
    if ((rtt ?? 0) < 100 && (packetLoss ?? 0) < 1 && (jitter ?? 0) < 30) {
      return CallQualityLevel.excellent;
    }
    // Good: RTT < 200ms, packet loss < 3%, jitter < 50ms
    if ((rtt ?? 0) < 200 && (packetLoss ?? 0) < 3 && (jitter ?? 0) < 50) {
      return CallQualityLevel.good;
    }
    // Fair: RTT < 400ms, packet loss < 5%, jitter < 100ms
    if ((rtt ?? 0) < 400 && (packetLoss ?? 0) < 5 && (jitter ?? 0) < 100) {
      return CallQualityLevel.fair;
    }
    // Poor: anything worse
    return CallQualityLevel.poor;
  }
}

/// Network degradation event types
enum NetworkDegradationType {
  /// Video disabled due to poor network - switched to audio only
  videoDisabledPoorNetwork,

  /// Video re-enabled as network improved
  videoReenabledNetworkImproved,

  /// Warning: network quality degrading
  networkQualityWarning,

  /// Connection lost, attempting reconnection
  connectionLost,

  /// Connection restored
  connectionRestored,
}

/// Event emitted when network conditions change significantly
class NetworkDegradationEvent {
  final NetworkDegradationType type;
  final String message;
  final CallQualityLevel? qualityLevel;
  final DateTime timestamp;

  const NetworkDegradationEvent({
    required this.type,
    required this.message,
    this.qualityLevel,
    required this.timestamp,
  });
}

/// Callback types for WebRTC events
typedef OnStreamCallback = void Function(MediaStream stream);
typedef OnConnectionStateCallback = void Function(WebRTCConnectionState state);
typedef OnAudioLevelCallback = void Function(double level);

/// Service for managing WebRTC connections for calls and audio rooms
class WebRTCService {
  static final WebRTCService _instance = WebRTCService._internal();
  factory WebRTCService() => _instance;
  WebRTCService._internal();

  static WebRTCService get instance => _instance;

  // Firebase Realtime Database reference
  final _database = FirebaseDatabase.instance;

  // Peer connection
  RTCPeerConnection? _peerConnection;

  // Media streams
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  // Video renderers
  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  // State
  WebRTCConnectionState _connectionState = WebRTCConnectionState.idle;
  bool _isInitialized = false;
  bool _isMuted = false;
  bool _isCameraOff = false;
  bool _isSpeakerOn = true;
  bool _isOnHold = false;
  String? _currentCallId;
  bool _isInitiator = false;

  // Device compatibility
  bool _useHardwareAcceleration = true;
  bool _deviceChecked = false;

  // Stream subscriptions for Firebase signaling
  StreamSubscription? _offerSubscription;
  StreamSubscription? _answerSubscription;
  StreamSubscription? _candidateSubscription;
  StreamSubscription? _videoUpgradeSubscription;
  StreamSubscription? _renegotiateOfferSubscription;
  StreamSubscription? _renegotiateAnswerSubscription;
  StreamSubscription? _iceRestartOfferSubscription;
  StreamSubscription? _iceRestartAnswerSubscription;

  // Callbacks
  OnStreamCallback? _onRemoteStream;
  OnStreamCallback? _onLocalStream;
  OnConnectionStateCallback? _onConnectionStateChange;

  // Stream controllers for state changes
  final _connectionStateController =
      StreamController<WebRTCConnectionState>.broadcast();
  final _audioLevelController = StreamController<double>.broadcast();
  final _videoUpgradeRequestController = StreamController<String>.broadcast();
  final _videoUpgradeResponseController = StreamController<bool>.broadcast();
  final _qualityMetricsController =
      StreamController<CallQualityMetrics>.broadcast();
  final _networkDegradationController =
      StreamController<NetworkDegradationEvent>.broadcast();

  // Quality monitoring
  Timer? _qualityMonitorTimer;
  CallQualityMetrics? _lastQualityMetrics;
  CallQualityLevel _currentAdaptiveQuality = CallQualityLevel.good;
  bool _adaptiveQualityEnabled = true;
  bool _videoDisabledDueToNetwork = false;
  int _poorQualityCount = 0;
  static const int _poorQualityThreshold =
      3; // 3 consecutive poor readings = switch to audio

  // Reconnection
  Timer? _reconnectionTimer;
  int _reconnectionAttempts = 0;
  static const int _maxReconnectionAttempts = 3;
  static const Duration _reconnectionTimeout = Duration(seconds: 30);

  // Guards for concurrent operations
  bool _isStartingCall = false;
  bool _isEndingCall = false;

  // Timeouts
  static const Duration _getUserMediaTimeout = Duration(seconds: 10);
  static const Duration _signalingTimeout = Duration(seconds: 10);
  static const int _maxSignalingRetries = 3;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isMuted => _isMuted;
  bool get isCameraOff => _isCameraOff;
  bool get isSpeakerOn => _isSpeakerOn;
  bool get isOnHold => _isOnHold;
  WebRTCConnectionState get connectionState => _connectionState;
  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;
  Stream<WebRTCConnectionState> get connectionStateStream =>
      _connectionStateController.stream;
  Stream<double> get audioLevelStream => _audioLevelController.stream;
  Stream<String> get videoUpgradeRequestStream =>
      _videoUpgradeRequestController.stream;
  Stream<bool> get videoUpgradeResponseStream =>
      _videoUpgradeResponseController.stream;
  Stream<CallQualityMetrics> get qualityMetricsStream =>
      _qualityMetricsController.stream;
  Stream<NetworkDegradationEvent> get networkDegradationStream =>
      _networkDegradationController.stream;
  CallQualityMetrics? get lastQualityMetrics => _lastQualityMetrics;
  String? get currentCallId => _currentCallId;
  bool get isVideoDisabledDueToNetwork => _videoDisabledDueToNetwork;

  /// Initialize the WebRTC service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Check device compatibility for hardware acceleration
      await _checkDeviceCompatibility();

      // Initialize renderers (may throw if already disposed)
      try {
        await localRenderer.initialize();
      } catch (e) {
        debugPrint('WebRTCService: Error initializing local renderer: $e');
      }
      try {
        await remoteRenderer.initialize();
      } catch (e) {
        debugPrint('WebRTCService: Error initializing remote renderer: $e');
      }

      _isInitialized = true;
      debugPrint('WebRTCService: Initialized successfully');
      debugPrint(
        'WebRTCService: Hardware acceleration: $_useHardwareAcceleration',
      );
    } catch (e) {
      debugPrint('WebRTCService: Error initializing: $e');
      rethrow;
    }
  }

  /// Check device compatibility and determine if hardware acceleration should be used
  /// Some devices have buggy H.264 hardware decoders that cause video artifacts
  Future<void> _checkDeviceCompatibility() async {
    if (_deviceChecked) return;
    _deviceChecked = true;

    try {
      if (Platform.isAndroid) {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;

        final manufacturer = androidInfo.manufacturer.toLowerCase();
        final model = androidInfo.model.toLowerCase();
        final sdkInt = androidInfo.version.sdkInt;

        debugPrint('WebRTCService: Device - $manufacturer $model, SDK $sdkInt');

        // AGRESSIVE: Disable hardware acceleration on ALL Android devices
        // to avoid pixel corruption issues with H.264 hardware decoders
        // This forces software decoding which is more reliable
        _useHardwareAcceleration = false;
        debugPrint(
          'WebRTCService: Hardware acceleration DISABLED for reliability',
        );

        // Log device info for debugging
        final problematicManufacturers = [
          'samsung',
          'xiaomi',
          'huawei',
          'oppo',
          'vivo',
          'realme',
          'tecno',
          'infinix',
        ];
        final isPotentiallyProblematic = problematicManufacturers.any(
          (m) => manufacturer.contains(m),
        );
        if (isPotentiallyProblematic) {
          debugPrint('WebRTCService: Known problematic manufacturer detected');
        }
      }
    } catch (e) {
      debugPrint('WebRTCService: Error checking device compatibility: $e');
      // Disable hardware acceleration by default for safety
      _useHardwareAcceleration = false;
    }
  }

  /// Start a call (as initiator or receiver)
  ///
  /// [callId] - Unique identifier for the call
  /// [isInitiator] - Whether this user is initiating the call
  /// [enableVideo] - Whether to enable video
  /// [onRemoteStream] - Callback when remote stream is received
  /// [onLocalStream] - Callback when local stream is ready
  /// [onConnectionStateChange] - Callback for connection state changes
  ///
  /// Throws [StateError] if a call is already in progress
  Future<void> startCall({
    required String callId,
    required bool isInitiator,
    bool enableVideo = false,
    OnStreamCallback? onRemoteStream,
    OnStreamCallback? onLocalStream,
    OnConnectionStateCallback? onConnectionStateChange,
  }) async {
    // Guard: Prevent concurrent call starts
    if (_isStartingCall) {
      debugPrint('WebRTCService: startCall already in progress, ignoring');
      return;
    }

    // Guard: Check if there's already an active call
    if (_currentCallId != null && _currentCallId != callId) {
      debugPrint(
        'WebRTCService: Already in call $_currentCallId, cannot start $callId',
      );
      throw StateError('Already in a call: $_currentCallId');
    }

    // Guard: If same callId, check if we're reconnecting or already connected
    if (_currentCallId == callId) {
      if (_connectionState == WebRTCConnectionState.connected ||
          _connectionState == WebRTCConnectionState.connecting ||
          _connectionState == WebRTCConnectionState.reconnecting) {
        debugPrint('WebRTCService: Call $callId already active, ignoring');
        return;
      }
    }

    _isStartingCall = true;

    try {
      if (!_isInitialized) {
        await initialize();
      }

      // Check if call was ended during initialization
      if (_isEndingCall) {
        debugPrint('WebRTCService: startCall aborted - call ended during init');
        return;
      }

      _currentCallId = callId;
      _isInitiator = isInitiator;
      _onRemoteStream = onRemoteStream;
      _onLocalStream = onLocalStream;
      _onConnectionStateChange = onConnectionStateChange;

      _updateConnectionState(WebRTCConnectionState.connecting);

      // Get local media stream with timeout
      await _getUserMediaWithTimeout(enableVideo: enableVideo);

      // Check if call was ended during getUserMedia
      if (_isEndingCall) {
        debugPrint('WebRTCService: startCall aborted - call ended during getUserMedia');
        return;
      }

      // Create peer connection
      await _createPeerConnection();

      // Check if call was ended during peer connection creation
      if (_isEndingCall) {
        debugPrint('WebRTCService: startCall aborted - call ended during peer connection');
        return;
      }

      // Setup Firebase signaling listeners
      _setupSignalingListeners(callId);

      if (isInitiator) {
        // Create and send offer with retry
        await _createOfferWithRetry(callId);
      }

      debugPrint(
        'WebRTCService: Call started - callId: $callId, isInitiator: $isInitiator',
      );
    } catch (e) {
      debugPrint('WebRTCService: Error starting call: $e');
      _currentCallId = null;
      _updateConnectionState(WebRTCConnectionState.failed);
      rethrow;
    } finally {
      _isStartingCall = false;
    }
  }

  /// Get user media with timeout protection
  /// Throws TimeoutException if media access takes too long
  Future<void> _getUserMediaWithTimeout({required bool enableVideo}) async {
    try {
      await _getUserMedia(enableVideo: enableVideo).timeout(
        _getUserMediaTimeout,
        onTimeout: () {
          throw TimeoutException(
            'Failed to access camera/microphone within ${_getUserMediaTimeout.inSeconds}s',
            _getUserMediaTimeout,
          );
        },
      );
    } on TimeoutException {
      debugPrint('WebRTCService: getUserMedia timeout');
      rethrow;
    }
  }

  /// Get user media (camera and/or microphone)
  Future<void> _getUserMedia({required bool enableVideo}) async {
    // Check if call is ending before accessing camera/microphone
    if (_isEndingCall) {
      debugPrint('WebRTCService: _getUserMedia aborted - call is ending');
      return;
    }

    debugPrint('WebRTCService: _getUserMedia called with enableVideo=$enableVideo');

    // Use VERY LOW resolution for maximum compatibility across devices
    // Many devices have hardware decoder issues with higher resolutions
    // 320x240 (QVGA) is universally supported and avoids texture corruption
    final constraints = <String, dynamic>{
      'audio': {
        // Standard WebRTC audio processing
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
        // Google-specific audio processing (Android) - Maximum AEC for Larsen prevention
        'googNoiseSuppression': true,
        'googEchoCancellation': true,
        'googEchoCancellation2':
            true, // Enhanced echo cancellation (second generation)
        'googDAEchoCancellation':
            true, // Delay-agnostic AEC - handles varying audio delays
        'googAutoGainControl': true,
        'googAutoGainControl2': true, // Enhanced AGC
        'googHighpassFilter': true, // Filters low-frequency noise (wind, AC)
        'googTypingNoiseDetection': true,
        'googAudioMirroring':
            false, // Disable mirroring to prevent feedback loops
      },
      'video':
          enableVideo
              ? {
                'facingMode': 'user',
                // Use 320x240 (QVGA) for MAXIMUM device compatibility
                // This avoids texture/decoder corruption on problematic devices
                'width': {'ideal': 320, 'max': 640},
                'height': {'ideal': 240, 'max': 480},
                'frameRate': {'ideal': 15, 'max': 24},
              }
              : false,
    };

    try {
      debugPrint('WebRTCService: Requesting user media...');
      _localStream = await navigator.mediaDevices.getUserMedia(constraints);

      // Check if call ended while waiting for getUserMedia
      if (_isEndingCall) {
        debugPrint('WebRTCService: Call ended during getUserMedia - cleaning up stream');
        _localStream?.getTracks().forEach((track) => track.stop());
        await _localStream?.dispose();
        _localStream = null;
        return;
      }

      debugPrint('WebRTCService: User media obtained successfully');

      // NE PAS assigner srcObject ici - laissons le CallScreen le faire
      // pour éviter les problèmes de multiple EglRenderers
      debugPrint(
        'WebRTCService: Got local stream with ${_localStream!.getTracks().length} tracks',
      );
      for (final track in _localStream!.getTracks()) {
        debugPrint(
          'WebRTCService: - Local track: ${track.kind}, enabled: ${track.enabled}, id: ${track.id}',
        );
      }

      _onLocalStream?.call(_localStream!);
    } catch (e, stackTrace) {
      debugPrint('WebRTCService: Error getting user media: $e');
      debugPrint('WebRTCService: getUserMedia stackTrace: $stackTrace');
      rethrow;
    }
  }

  /// Create RTCPeerConnection
  Future<void> _createPeerConnection() async {
    // Fetch ephemeral TURN credentials from backend (C1 security fix)
    final iceServers = await IceServerConfig.fetchIceServers();

    final configuration = <String, dynamic>{
      'iceServers': iceServers,
      'sdpSemantics': 'unified-plan',
      // Disable insertable streams (can cause issues)
      'encodedInsertableStreams': false,
    };

    // Try to disable hardware acceleration on Android
    // by setting codec preferences in factory options
    if (Platform.isAndroid && !_useHardwareAcceleration) {
      debugPrint('WebRTCService: Configuring for software codec preference');
    }

    _peerConnection = await createPeerConnection(configuration);

    // Add local stream tracks to peer connection with explicit codec preference
    _localStream?.getTracks().forEach((track) async {
      final sender = await _peerConnection?.addTrack(track, _localStream!);

      // For video tracks, try to set codec preference to VP8
      if (track.kind == 'video' && sender != null) {
        try {
          final params = sender.parameters;
          // Log current encoding settings
          debugPrint(
            'WebRTCService: Video sender parameters: ${params.encodings?.length ?? 0} encodings',
          );
        } catch (e) {
          debugPrint('WebRTCService: Could not get sender parameters: $e');
        }
      }
    });

    // Handle incoming streams
    _peerConnection?.onTrack = (RTCTrackEvent event) {
      debugPrint(
        'WebRTCService: onTrack called - streams: ${event.streams.length}, track: ${event.track.kind}',
      );

      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        try {
          remoteRenderer.srcObject = _remoteStream;
        } catch (e) {
          debugPrint('WebRTCService: Error setting remote renderer srcObject: $e');
        }
        _onRemoteStream?.call(_remoteStream!);

        debugPrint('WebRTCService: Remote stream assigned to renderer');
        debugPrint(
          'WebRTCService: Remote stream tracks: ${_remoteStream!.getTracks().length}',
        );

        for (final track in _remoteStream!.getTracks()) {
          debugPrint(
            'WebRTCService: - Track: ${track.kind}, enabled: ${track.enabled}',
          );
        }
      } else {
        debugPrint(
          'WebRTCService: WARNING - onTrack called but no streams available',
        );
      }
    };

    // Handle ICE candidates
    _peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
      _sendIceCandidate(candidate);
    };

    // Handle connection state changes
    _peerConnection?.onConnectionState = (RTCPeerConnectionState state) {
      debugPrint('WebRTCService: Connection state: $state');
      switch (state) {
        case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
          _cancelReconnection();
          _updateConnectionState(WebRTCConnectionState.connected);
          _verifyVideoConnection();
          break;
        case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
          // Try to reconnect instead of immediately failing
          _attemptReconnection();
          break;
        case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
          // Try ICE restart before giving up
          _attemptReconnection();
          break;
        case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
          _cancelReconnection();
          _updateConnectionState(WebRTCConnectionState.idle);
          break;
        default:
          break;
      }
    };

    // Handle ICE connection state
    _peerConnection?.onIceConnectionState = (RTCIceConnectionState state) {
      debugPrint('WebRTCService: ICE connection state: $state');

      switch (state) {
        case RTCIceConnectionState.RTCIceConnectionStateFailed:
          debugPrint(
            'WebRTCService: ICE connection FAILED - attempting reconnection',
          );
          _attemptReconnection();
          break;
        case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
          debugPrint('WebRTCService: ICE disconnected - will try to reconnect');
          // Don't immediately trigger reconnection, wait for connection state
          break;
        case RTCIceConnectionState.RTCIceConnectionStateConnected:
          debugPrint('WebRTCService: ICE connection CONNECTED successfully');
          _cancelReconnection();
          break;
        default:
          break;
      }
    };

    debugPrint('WebRTCService: Peer connection created');
  }

  /// Vérifie que la vidéo fonctionne après connexion
  Future<void> _verifyVideoConnection() async {
    await Future.delayed(const Duration(seconds: 3));

    if (_connectionState == WebRTCConnectionState.connected) {
      final hasRemoteVideo =
          _remoteStream?.getVideoTracks().isNotEmpty ?? false;
      final remoteVideoEnabled =
          _remoteStream?.getVideoTracks().firstOrNull?.enabled ?? false;

      debugPrint('WebRTCService: Video verification:');
      debugPrint('  - Has remote video track: $hasRemoteVideo');
      debugPrint('  - Remote video enabled: $remoteVideoEnabled');
      debugPrint(
        '  - Remote renderer has source: ${remoteRenderer.srcObject != null}',
      );

      if (!hasRemoteVideo || !remoteVideoEnabled) {
        debugPrint(
          'WebRTCService: WARNING - No remote video track or disabled',
        );
      }
    }
  }

  /// Attempt to reconnect the call using ICE restart
  Future<void> _attemptReconnection() async {
    if (_peerConnection == null || _currentCallId == null) {
      _updateConnectionState(WebRTCConnectionState.failed);
      return;
    }

    // Check if we've exceeded max attempts
    if (_reconnectionAttempts >= _maxReconnectionAttempts) {
      debugPrint('WebRTCService: Max reconnection attempts reached, giving up');
      _updateConnectionState(WebRTCConnectionState.failed);
      return;
    }

    // Don't start another reconnection if one is in progress
    if (_connectionState == WebRTCConnectionState.reconnecting) {
      return;
    }

    _updateConnectionState(WebRTCConnectionState.reconnecting);

    // Start timeout timer — couvre toute la SÉQUENCE de reconnexion, pas une
    // seule tentative : les relances en cas d'échec restent sous ce délai.
    _reconnectionTimer?.cancel();
    _reconnectionTimer = Timer(_reconnectionTimeout, () {
      if (_connectionState == WebRTCConnectionState.reconnecting) {
        debugPrint('WebRTCService: Reconnection timeout');
        _updateConnectionState(WebRTCConnectionState.failed);
      }
    });

    await _retryIceRestart();
  }

  /// Tente un ICE restart et relance jusqu'à `_maxReconnectionAttempts` en
  /// cas d'échec (ex. jeton Firebase en cours de renouvellement au moment de
  /// l'écriture RTDB).
  ///
  /// Séparé d'`_attemptReconnection` : rappeler cette dernière pour relancer
  /// tombait sur son propre garde anti-doublon (`_connectionState ==
  /// reconnecting`, posé une ligne plus haut et jamais retiré entre deux
  /// tentatives) — la relance retournait donc immédiatement sans rien
  /// retenter. Un seul échec de signalisation, même transitoire, abandonnait
  /// l'appel au bout du timeout de 30 s au lieu d'épuiser ses 3 tentatives.
  Future<void> _retryIceRestart() async {
    _reconnectionAttempts++;
    debugPrint(
      'WebRTCService: Attempting reconnection (attempt $_reconnectionAttempts/$_maxReconnectionAttempts)',
    );

    try {
      await _performIceRestart();
    } catch (e) {
      debugPrint('WebRTCService: Error during reconnection: $e');
      if (_connectionState != WebRTCConnectionState.reconnecting) {
        // hangUp() ou une reconnexion réussie a tourné entre-temps : ne pas
        // relancer sur un appel qui n'est plus en train de se reconnecter.
        return;
      }
      if (_reconnectionAttempts < _maxReconnectionAttempts) {
        await Future.delayed(const Duration(seconds: 2));
        await _retryIceRestart();
      } else {
        _updateConnectionState(WebRTCConnectionState.failed);
      }
    }
  }

  /// Perform ICE restart to re-establish connection
  Future<void> _performIceRestart() async {
    final pc = _peerConnection;
    if (pc == null || _currentCallId == null) return;

    if (pc.signalingState == RTCSignalingState.RTCSignalingStateClosed) {
      debugPrint('WebRTCService: Cannot perform ICE restart - connection closed');
      return;
    }

    debugPrint('WebRTCService: Performing ICE restart');

    try {
      final offer = await pc.createOffer({'iceRestart': true});

      // Re-check: hangUp() could have run during the await above
      if (_peerConnection == null ||
          _peerConnection!.signalingState == RTCSignalingState.RTCSignalingStateClosed) {
        debugPrint('WebRTCService: Connection closed during ICE restart');
        return;
      }

      // Prefer VP8 codec
      final modifiedSdp = _preferVP8Codec(offer.sdp ?? '');
      final modifiedOffer = RTCSessionDescription(modifiedSdp, offer.type);

      await pc.setLocalDescription(modifiedOffer);

      // Send the new offer via Firebase
      final callRef = _database.ref('calls/$_currentCallId');
      await callRef.child('ice_restart_offer').set({
        'type': modifiedOffer.type,
        'sdp': modifiedOffer.sdp,
        'timestamp': ServerValue.timestamp,
      });

      debugPrint('WebRTCService: ICE restart offer sent');
    } catch (e) {
      debugPrint('WebRTCService: Error performing ICE restart: $e');
      rethrow;
    }
  }

  /// Cancel ongoing reconnection attempt
  void _cancelReconnection() {
    _reconnectionTimer?.cancel();
    _reconnectionTimer = null;
    _reconnectionAttempts = 0;
  }

  /// Setup Firebase signaling listeners
  void _setupSignalingListeners(String callId) {
    final callRef = _database.ref('calls/$callId');

    // Listen for offer (if we're not the initiator)
    if (!_isInitiator) {
      _offerSubscription = callRef.child('offer').onValue.listen((event) async {
        if (event.snapshot.value != null) {
          final data = Map<String, dynamic>.from(event.snapshot.value as Map);
          await _handleOffer(data, callId);
        }
      });
    }

    // Listen for answer (if we're the initiator)
    if (_isInitiator) {
      _answerSubscription = callRef.child('answer').onValue.listen((
        event,
      ) async {
        if (event.snapshot.value != null) {
          final data = Map<String, dynamic>.from(event.snapshot.value as Map);
          await _handleAnswer(data);
        }
      });
    }

    // Listen for ICE candidates from the other party
    final candidatesPath =
        _isInitiator ? 'calleeCandidates' : 'callerCandidates';
    _candidateSubscription = callRef.child(candidatesPath).onChildAdded.listen((
      event,
    ) async {
      if (event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        await _handleIceCandidate(data);
      }
    });

    // Listen for video upgrade requests/responses
    _videoUpgradeSubscription = callRef.child('videoUpgrade').onValue.listen((
      event,
    ) async {
      if (event.snapshot.value == null) return;
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      final requestedBy = data['requestedBy'] as String?;
      final status = data['status'] as String?;

      final iAmRequester =
          (_isInitiator && requestedBy == 'caller') ||
          (!_isInitiator && requestedBy == 'callee');

      if (status == 'pending' && !iAmRequester) {
        // Other party requested video upgrade → notify UI
        _videoUpgradeRequestController.add(requestedBy ?? '');
      } else if (status == 'accepted' && iAmRequester) {
        // My request was accepted → enable video
        await _enableVideoMidCall();
        _videoUpgradeResponseController.add(true);
      } else if (status == 'declined' && iAmRequester) {
        // My request was declined
        _videoUpgradeResponseController.add(false);
      }
    });

    // Listen for renegotiation offers from the other party
    _renegotiateOfferSubscription = callRef.child('renegotiate_offer').onValue.listen((event) async {
      if (event.snapshot.value == null) return;
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      await _handleRenegotiationOffer(data, callId);
    });

    // Listen for renegotiation answers
    _renegotiateAnswerSubscription = callRef.child('renegotiate_answer').onValue.listen((event) async {
      if (event.snapshot.value == null) return;
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      await _handleAnswer(data);
    });

    // Listen for ICE restart offers from the other party
    _iceRestartOfferSubscription = callRef.child('ice_restart_offer').onValue.listen((event) async {
      if (event.snapshot.value == null) return;
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      await _handleIceRestartOffer(data, callId);
    });

    // Listen for ICE restart answers
    _iceRestartAnswerSubscription = callRef.child('ice_restart_answer').onValue.listen((event) async {
      if (event.snapshot.value == null) return;
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      await _handleAnswer(data);
    });
  }

  /// Handle renegotiation offer (when the other party adds video)
  Future<void> _handleRenegotiationOffer(
    Map<String, dynamic> data,
    String callId,
  ) async {
    try {
      // Check if peer connection is still valid
      if (_peerConnection == null ||
          _peerConnection!.signalingState == RTCSignalingState.RTCSignalingStateClosed) {
        debugPrint('WebRTCService: Cannot handle renegotiation - connection closed');
        return;
      }

      final sdp = data['sdp'] as String?;
      final type = data['type'] as String?;
      if (sdp == null || type == null) {
        debugPrint('WebRTCService: Renegotiation offer missing sdp/type, ignoring');
        return;
      }

      final offer = RTCSessionDescription(sdp, type);
      await _peerConnection?.setRemoteDescription(offer);

      // Check again before creating answer
      if (_peerConnection == null ||
          _peerConnection!.signalingState == RTCSignalingState.RTCSignalingStateClosed) {
        debugPrint('WebRTCService: Connection closed during renegotiation');
        return;
      }

      final answer = await _peerConnection?.createAnswer();
      if (answer == null) {
        debugPrint('WebRTCService: createAnswer() returned null during renegotiation');
        return;
      }

      // Check again before setting local description
      if (_peerConnection == null ||
          _peerConnection!.signalingState == RTCSignalingState.RTCSignalingStateClosed) {
        debugPrint('WebRTCService: Connection closed during renegotiation answer');
        return;
      }

      await _peerConnection?.setLocalDescription(answer);

      final callRef = _database.ref('calls/$callId');
      await callRef.child('renegotiate_answer').set({
        'type': answer.type,
        'sdp': answer.sdp,
      });

      debugPrint('WebRTCService: Renegotiation answer sent');
    } catch (e) {
      debugPrint('WebRTCService: Error handling renegotiation offer: $e');
    }
  }

  /// Handle ICE restart offer from the other party
  Future<void> _handleIceRestartOffer(
    Map<String, dynamic> data,
    String callId,
  ) async {
    try {
      // Check if peer connection is still valid
      if (_peerConnection == null ||
          _peerConnection!.signalingState == RTCSignalingState.RTCSignalingStateClosed) {
        debugPrint('WebRTCService: Cannot handle ICE restart - connection closed');
        return;
      }

      debugPrint('WebRTCService: Handling ICE restart offer');

      final iceRestartSdp = data['sdp'] as String?;
      final iceRestartType = data['type'] as String?;
      if (iceRestartSdp == null || iceRestartType == null) {
        debugPrint('WebRTCService: ICE restart offer missing sdp/type, ignoring');
        return;
      }

      final offer = RTCSessionDescription(iceRestartSdp, iceRestartType);
      await _peerConnection?.setRemoteDescription(offer);

      // Check again before creating answer
      if (_peerConnection == null ||
          _peerConnection!.signalingState == RTCSignalingState.RTCSignalingStateClosed) {
        debugPrint('WebRTCService: Connection closed during ICE restart handling');
        return;
      }

      // Create answer for ICE restart
      final answer = await _peerConnection?.createAnswer();
      if (answer == null) {
        debugPrint('WebRTCService: createAnswer() returned null during ICE restart');
        return;
      }

      // Check again before setting local description
      if (_peerConnection == null ||
          _peerConnection!.signalingState == RTCSignalingState.RTCSignalingStateClosed) {
        debugPrint('WebRTCService: Connection closed during ICE restart answer');
        return;
      }

      await _peerConnection?.setLocalDescription(answer);

      // Send the answer through the ice_restart_answer path
      final callRef = _database.ref('calls/$callId');
      await callRef.child('ice_restart_answer').set({
        'type': answer.type,
        'sdp': answer.sdp,
      });

      debugPrint('WebRTCService: ICE restart answer sent');
    } catch (e) {
      debugPrint('WebRTCService: Error handling ICE restart offer: $e');
    }
  }

  /// Create and send SDP offer with retry logic
  Future<void> _createOfferWithRetry(String callId) async {
    Exception? lastException;

    for (int attempt = 1; attempt <= _maxSignalingRetries; attempt++) {
      try {
        await _createOffer(callId).timeout(
          _signalingTimeout,
          onTimeout: () {
            throw TimeoutException(
              'Offer creation timeout',
              _signalingTimeout,
            );
          },
        );
        return; // Success
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        debugPrint(
          'WebRTCService: Offer attempt $attempt/$_maxSignalingRetries failed: $e',
        );

        if (attempt < _maxSignalingRetries) {
          // Wait before retry with exponential backoff
          await Future.delayed(Duration(milliseconds: 500 * attempt));
        }
      }
    }

    // All retries failed
    throw lastException ?? Exception('Failed to create offer after $_maxSignalingRetries attempts');
  }

  /// Create and send SDP offer
  Future<void> _createOffer(String callId) async {
    try {
      // Check if peer connection is still valid
      if (_peerConnection == null ||
          _peerConnection!.signalingState == RTCSignalingState.RTCSignalingStateClosed) {
        debugPrint('WebRTCService: Cannot create offer - connection closed');
        return;
      }

      final offer = await _peerConnection?.createOffer();

      // Check again before setting local description (connection might have closed)
      if (_peerConnection == null ||
          _peerConnection!.signalingState == RTCSignalingState.RTCSignalingStateClosed) {
        debugPrint('WebRTCService: Connection closed during offer creation');
        return;
      }

      // Prefer VP8 codec over H.264 for better device compatibility
      final modifiedSdp = _preferVP8Codec(offer?.sdp ?? '');
      final modifiedOffer = RTCSessionDescription(modifiedSdp, offer?.type);

      await _peerConnection?.setLocalDescription(modifiedOffer);

      // Send offer to Firebase with retry logic
      final callRef = _database.ref('calls/$callId');
      await _sendToFirebaseWithRetry(
        callRef.child('offer'),
        {
          'type': modifiedOffer.type,
          'sdp': modifiedOffer.sdp,
        },
      );

      debugPrint('WebRTCService: Offer created and sent (VP8 preferred)');
    } catch (e) {
      debugPrint('WebRTCService: Error creating offer: $e');
      rethrow;
    }
  }

  /// Modify SDP to prefer VP8 codec over H.264
  /// VP8 has reliable software decoding and avoids hardware decoder bugs
  /// We reorder codecs but keep H.264 as fallback to maintain SDP validity
  String _preferVP8Codec(String sdp) {
    if (sdp.isEmpty) return sdp;

    try {
      final lines = sdp.split('\r\n');
      final modifiedLines = <String>[];

      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];

        // Find video m= line and reorder codecs to prefer VP8
        if (line.startsWith('m=video')) {
          final parts = line.split(' ');
          if (parts.length > 3) {
            final payloadTypes = parts.sublist(3).toList();

            // Find VP8 payload type
            String? vp8PayloadType;
            for (
              int j = i + 1;
              j < lines.length && !lines[j].startsWith('m=');
              j++
            ) {
              if (lines[j].contains('VP8/90000')) {
                final match = RegExp(
                  r'a=rtpmap:(\d+) VP8',
                ).firstMatch(lines[j]);
                if (match != null) {
                  vp8PayloadType = match.group(1);
                  break;
                }
              }
            }

            // Reorder to put VP8 first (keep all codecs for compatibility)
            if (vp8PayloadType != null &&
                payloadTypes.contains(vp8PayloadType)) {
              payloadTypes.remove(vp8PayloadType);
              payloadTypes.insert(0, vp8PayloadType);
              final newLine =
                  '${parts.sublist(0, 3).join(' ')} ${payloadTypes.join(' ')}';
              modifiedLines.add(newLine);
              debugPrint(
                'WebRTCService: VP8 prioritized (payload: $vp8PayloadType)',
              );
              continue;
            }
          }
        }

        modifiedLines.add(line);
      }

      return modifiedLines.join('\r\n');
    } catch (e) {
      debugPrint('WebRTCService: Error modifying SDP for VP8: $e');
      return sdp;
    }
  }

  /// Handle received offer and create answer
  Future<void> _handleOffer(Map<String, dynamic> data, String callId) async {
    try {
      // Check if peer connection is still valid
      if (_peerConnection == null ||
          _peerConnection!.signalingState == RTCSignalingState.RTCSignalingStateClosed) {
        debugPrint('WebRTCService: Cannot handle offer - connection closed');
        return;
      }

      final offer = RTCSessionDescription(data['sdp'], data['type']);
      await _peerConnection?.setRemoteDescription(offer);

      // Check again before creating answer
      if (_peerConnection == null ||
          _peerConnection!.signalingState == RTCSignalingState.RTCSignalingStateClosed) {
        debugPrint('WebRTCService: Connection closed while handling offer');
        return;
      }

      final answer = await _peerConnection?.createAnswer();
      if (answer == null) {
        debugPrint('WebRTCService: createAnswer() returned null');
        return;
      }

      // Check again before setting local description
      if (_peerConnection == null ||
          _peerConnection!.signalingState == RTCSignalingState.RTCSignalingStateClosed) {
        debugPrint('WebRTCService: Connection closed during answer creation');
        return;
      }

      // Prefer VP8 codec in answer as well
      final modifiedSdp = _preferVP8Codec(answer.sdp ?? '');
      final modifiedAnswer = RTCSessionDescription(modifiedSdp, answer.type);

      await _peerConnection?.setLocalDescription(modifiedAnswer);

      // Send answer to Firebase with retry logic
      final callRef = _database.ref('calls/$callId');
      await _sendToFirebaseWithRetry(
        callRef.child('answer'),
        {
          'type': modifiedAnswer.type,
          'sdp': modifiedAnswer.sdp,
        },
      );

      debugPrint('WebRTCService: Answer created and sent (VP8 preferred)');
    } catch (e) {
      debugPrint('WebRTCService: Error handling offer: $e');
    }
  }

  /// Handle received answer
  Future<void> _handleAnswer(Map<String, dynamic> data) async {
    try {
      // Check if peer connection is still valid
      if (_peerConnection == null ||
          _peerConnection!.signalingState == RTCSignalingState.RTCSignalingStateClosed) {
        debugPrint('WebRTCService: Cannot handle answer - connection closed');
        return;
      }

      final answer = RTCSessionDescription(data['sdp'], data['type']);
      await _peerConnection?.setRemoteDescription(answer);
      debugPrint('WebRTCService: Answer received and set');
      debugPrint('WebRTCService: Remote description type: ${answer.type}');
    } catch (e) {
      debugPrint('WebRTCService: Error handling answer: $e');
    }
  }

  /// Send data to Firebase with retry logic
  Future<void> _sendToFirebaseWithRetry(
    DatabaseReference ref,
    Map<String, dynamic> data, {
    int maxRetries = 3,
  }) async {
    Exception? lastException;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        await ref.set(data).timeout(
          _signalingTimeout,
          onTimeout: () {
            throw TimeoutException(
              'Firebase write timeout',
              _signalingTimeout,
            );
          },
        );
        return; // Success
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        debugPrint(
          'WebRTCService: Firebase write attempt $attempt/$maxRetries failed: $e',
        );

        if (attempt < maxRetries) {
          await Future.delayed(Duration(milliseconds: 300 * attempt));
        }
      }
    }

    throw lastException ?? Exception('Firebase write failed after $maxRetries attempts');
  }

  /// Send ICE candidate to Firebase (fire-and-forget with single retry)
  void _sendIceCandidate(RTCIceCandidate candidate) {
    if (_currentCallId == null) return;

    final candidatesPath =
        _isInitiator ? 'callerCandidates' : 'calleeCandidates';
    final callRef = _database.ref('calls/$_currentCallId/$candidatesPath');

    // Fire and forget with single retry on failure
    callRef.push().set({
      'candidate': candidate.candidate,
      'sdpMid': candidate.sdpMid,
      'sdpMLineIndex': candidate.sdpMLineIndex,
    }).catchError((e) {
      debugPrint('WebRTCService: ICE candidate send failed, retrying: $e');
      // Single retry
      callRef.push().set({
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      }).catchError((e2) {
        debugPrint('WebRTCService: ICE candidate retry failed: $e2');
      });
    });
  }

  /// Handle received ICE candidate
  Future<void> _handleIceCandidate(Map<String, dynamic> data) async {
    try {
      final candidate = RTCIceCandidate(
        data['candidate'],
        data['sdpMid'],
        data['sdpMLineIndex'],
      );
      await _peerConnection?.addCandidate(candidate);
      debugPrint(
        'WebRTCService: ICE candidate added - mid: ${candidate.sdpMid}',
      );
    } catch (e) {
      debugPrint('WebRTCService: Error adding ICE candidate: $e');
    }
  }

  /// Toggle microphone mute
  void toggleMute() {
    _isMuted = !_isMuted;
    _localStream?.getAudioTracks().forEach((track) {
      track.enabled = !_isMuted;
    });
    debugPrint('WebRTCService: Muted: $_isMuted');
  }

  /// Set microphone enabled/disabled
  void setMicrophoneEnabled(bool enabled) {
    _isMuted = !enabled;
    _localStream?.getAudioTracks().forEach((track) {
      track.enabled = enabled;
    });
  }

  /// Toggle camera on/off
  void toggleCamera() {
    _isCameraOff = !_isCameraOff;
    _localStream?.getVideoTracks().forEach((track) {
      track.enabled = !_isCameraOff;
    });
    debugPrint('WebRTCService: Camera off: $_isCameraOff');
  }

  /// Set camera enabled/disabled
  void setCameraEnabled(bool enabled) {
    _isCameraOff = !enabled;
    _localStream?.getVideoTracks().forEach((track) {
      track.enabled = enabled;
    });
  }

  /// Switch between front and back camera
  Future<void> switchCamera() async {
    if (_localStream == null) return;

    final videoTrack = _localStream!.getVideoTracks().firstOrNull;
    if (videoTrack != null) {
      await Helper.switchCamera(videoTrack);
      debugPrint('WebRTCService: Camera switched');
    }
  }

  /// Toggle hold/resume - mutes audio and pauses video tracks
  void toggleHold() {
    _isOnHold = !_isOnHold;
    _localStream?.getAudioTracks().forEach((track) {
      track.enabled = !_isOnHold;
    });
    _localStream?.getVideoTracks().forEach((track) {
      track.enabled = !_isOnHold;
    });
    debugPrint('WebRTCService: On hold: $_isOnHold');
  }

  /// Toggle speaker - actually changes the audio output route
  /// Using earpiece mode is essential for preventing Larsen effect
  /// because the AEC works much better when audio goes through earpiece
  Future<void> toggleSpeaker() async {
    _isSpeakerOn = !_isSpeakerOn;

    // Actually change the audio route using flutter_webrtc Helper
    // This is crucial for proper AEC - speaker mode can cause feedback
    // when two devices are close together
    try {
      await Helper.setSpeakerphoneOn(_isSpeakerOn);
      debugPrint(
        'WebRTCService: Speaker ${_isSpeakerOn ? 'ON' : 'OFF (earpiece)'} - audio route changed',
      );
    } catch (e) {
      debugPrint('WebRTCService: Error changing speaker state: $e');
    }
  }

  /// Set speaker enabled/disabled
  Future<void> setSpeakerEnabled(bool enabled) async {
    if (_isSpeakerOn == enabled) return;
    _isSpeakerOn = enabled;

    try {
      await Helper.setSpeakerphoneOn(enabled);
      debugPrint(
        'WebRTCService: Speaker set to ${enabled ? 'ON' : 'OFF (earpiece)'}',
      );
    } catch (e) {
      debugPrint('WebRTCService: Error setting speaker state: $e');
    }
  }

  /// Request to upgrade the call from audio to video
  Future<void> requestVideoUpgrade() async {
    if (_currentCallId == null) return;

    final callRef = _database.ref('calls/$_currentCallId');
    await callRef.child('videoUpgrade').set({
      'requestedBy': _isInitiator ? 'caller' : 'callee',
      'status': 'pending',
      'timestamp': ServerValue.timestamp,
    });

    debugPrint('WebRTCService: Video upgrade requested');
  }

  /// Respond to a video upgrade request
  Future<void> respondToVideoUpgrade(bool accepted) async {
    if (_currentCallId == null) return;

    final callRef = _database.ref('calls/$_currentCallId');
    await callRef.child('videoUpgrade').update({
      'status': accepted ? 'accepted' : 'declined',
    });

    if (accepted) {
      await _enableVideoMidCall();
    }

    debugPrint(
      'WebRTCService: Video upgrade ${accepted ? 'accepted' : 'declined'}',
    );
  }

  /// Enable video during an active audio call (for both requester and accepter)
  Future<void> _enableVideoMidCall() async {
    debugPrint('WebRTCService: _enableVideoMidCall() called');
    debugPrint('WebRTCService: peerConnection=${_peerConnection != null}, localStream=${_localStream != null}');

    if (_peerConnection == null || _localStream == null) {
      debugPrint('WebRTCService: Cannot enable video - peerConnection or localStream is null');
      return;
    }

    try {
      debugPrint('WebRTCService: Getting video stream...');
      // Get a new stream with video enabled
      // Use LOW resolution for compatibility (same as initial call)
      final videoStream = await navigator.mediaDevices.getUserMedia({
        'audio': false,
        'video': {
          'facingMode': 'user',
          // Use 320x240 (QVGA) for maximum compatibility
          'width': {'ideal': 320, 'max': 640},
          'height': {'ideal': 240, 'max': 480},
          'frameRate': {'ideal': 15, 'max': 24},
        },
      });
      debugPrint('WebRTCService: Video stream obtained');

      final videoTrack = videoStream.getVideoTracks().first;
      debugPrint('WebRTCService: Video track obtained: ${videoTrack.id}');

      // Add video track to the existing local stream
      _localStream!.addTrack(videoTrack);
      debugPrint('WebRTCService: Video track added to local stream');

      // Add the video track to the peer connection
      await _peerConnection!.addTrack(videoTrack, _localStream!);
      debugPrint('WebRTCService: Video track added to peer connection');

      // Update local renderer
      localRenderer.srcObject = _localStream;
      _isCameraOff = false;

      // Renegotiate the connection
      debugPrint('WebRTCService: Starting renegotiation...');
      await _renegotiate();

      debugPrint('WebRTCService: Video enabled mid-call - SUCCESS');
    } catch (e, stackTrace) {
      debugPrint('WebRTCService: Error enabling video mid-call: $e');
      debugPrint('WebRTCService: StackTrace: $stackTrace');
    }
  }

  /// Renegotiate the peer connection after adding video track
  Future<void> _renegotiate() async {
    if (_peerConnection == null || _currentCallId == null) return;

    // Check if peer connection is still in a valid state
    if (_peerConnection!.signalingState == RTCSignalingState.RTCSignalingStateClosed) {
      debugPrint('WebRTCService: Cannot renegotiate - connection closed');
      return;
    }

    try {
      final offer = await _peerConnection!.createOffer();

      // Check again before setting local description
      if (_peerConnection == null ||
          _peerConnection!.signalingState == RTCSignalingState.RTCSignalingStateClosed) {
        debugPrint('WebRTCService: Connection closed during renegotiation');
        return;
      }

      await _peerConnection!.setLocalDescription(offer);

      final callRef = _database.ref('calls/$_currentCallId');
      await callRef.child('renegotiate_offer').set({
        'type': offer.type,
        'sdp': offer.sdp,
      });

      debugPrint('WebRTCService: Renegotiation offer sent');
    } catch (e) {
      debugPrint('WebRTCService: Error renegotiating: $e');
    }
  }

  /// Update connection state and notify listeners
  void _updateConnectionState(WebRTCConnectionState state) {
    _connectionState = state;
    _connectionStateController.add(state);
    _onConnectionStateChange?.call(state);

    // Start/stop quality monitoring based on connection state
    if (state == WebRTCConnectionState.connected) {
      _startQualityMonitoring();
    } else if (state == WebRTCConnectionState.disconnected ||
        state == WebRTCConnectionState.failed ||
        state == WebRTCConnectionState.idle) {
      _stopQualityMonitoring();
    }
  }

  /// Start monitoring call quality
  void _startQualityMonitoring() {
    _stopQualityMonitoring();
    // Collect stats every 2 seconds
    _qualityMonitorTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _collectQualityMetrics();
    });
    debugPrint('WebRTCService: Quality monitoring started');
  }

  /// Stop monitoring call quality
  void _stopQualityMonitoring() {
    _qualityMonitorTimer?.cancel();
    _qualityMonitorTimer = null;
    _lastQualityMetrics = null;
  }

  /// Collect WebRTC statistics and calculate quality metrics
  Future<void> _collectQualityMetrics() async {
    if (_peerConnection == null) return;

    try {
      final stats = await _peerConnection!.getStats();

      double? rtt;
      double? jitter;
      double? packetLossPercent;
      int? availableBandwidth;
      String? audioCodec;
      String? videoCodec;
      int? frameRate;
      int? frameWidth;
      int? frameHeight;
      int audioBytesSent = 0;
      int audioBytesReceived = 0;
      int videoBytesSent = 0;
      int videoBytesReceived = 0;
      int packetsLost = 0;
      int packetsReceived = 0;

      for (final report in stats) {
        final values = report.values;

        switch (report.type) {
          case 'candidate-pair':
            // Get RTT from the active candidate pair
            if (values['state'] == 'succeeded' || values['nominated'] == true) {
              rtt = (values['currentRoundTripTime'] as num?)?.toDouble();
              if (rtt != null) rtt *= 1000; // Convert to ms
              availableBandwidth =
                  (values['availableOutgoingBitrate'] as num?)?.toInt();
              if (availableBandwidth != null) {
                availableBandwidth =
                    availableBandwidth ~/ 1000; // Convert to kbps
              }
            }
            break;

          case 'inbound-rtp':
            final kind = values['kind'] as String?;
            if (kind == 'audio') {
              audioBytesReceived =
                  (values['bytesReceived'] as num?)?.toInt() ?? 0;
              jitter = (values['jitter'] as num?)?.toDouble();
              if (jitter != null) jitter *= 1000; // Convert to ms
              packetsLost += (values['packetsLost'] as num?)?.toInt() ?? 0;
              packetsReceived +=
                  (values['packetsReceived'] as num?)?.toInt() ?? 0;
            } else if (kind == 'video') {
              videoBytesReceived =
                  (values['bytesReceived'] as num?)?.toInt() ?? 0;
              frameRate = (values['framesPerSecond'] as num?)?.toInt();
              frameWidth = (values['frameWidth'] as num?)?.toInt();
              frameHeight = (values['frameHeight'] as num?)?.toInt();
              packetsLost += (values['packetsLost'] as num?)?.toInt() ?? 0;
              packetsReceived +=
                  (values['packetsReceived'] as num?)?.toInt() ?? 0;
            }
            break;

          case 'outbound-rtp':
            final kind = values['kind'] as String?;
            if (kind == 'audio') {
              audioBytesSent = (values['bytesSent'] as num?)?.toInt() ?? 0;
            } else if (kind == 'video') {
              videoBytesSent = (values['bytesSent'] as num?)?.toInt() ?? 0;
            }
            break;

          case 'codec':
            final mimeType = values['mimeType'] as String?;
            if (mimeType != null) {
              if (mimeType.startsWith('audio/')) {
                audioCodec = mimeType.replaceFirst('audio/', '');
              } else if (mimeType.startsWith('video/')) {
                videoCodec = mimeType.replaceFirst('video/', '');
              }
            }
            break;
        }
      }

      // Calculate packet loss percentage
      if (packetsReceived > 0 || packetsLost > 0) {
        packetLossPercent =
            (packetsLost / (packetsReceived + packetsLost)) * 100;
      }

      // Calculate quality level
      final qualityLevel = CallQualityMetrics.calculateQualityLevel(
        rtt: rtt,
        packetLoss: packetLossPercent,
        jitter: jitter,
      );

      final metrics = CallQualityMetrics(
        roundTripTimeMs: rtt,
        jitterMs: jitter,
        packetLossPercent: packetLossPercent,
        availableBandwidthKbps: availableBandwidth,
        audioCodec: audioCodec,
        videoCodec: videoCodec,
        frameRate: frameRate,
        frameWidth: frameWidth,
        frameHeight: frameHeight,
        audioBytesSent: audioBytesSent,
        audioBytesReceived: audioBytesReceived,
        videoBytesSent: videoBytesSent,
        videoBytesReceived: videoBytesReceived,
        qualityLevel: qualityLevel,
        timestamp: DateTime.now(),
      );

      _lastQualityMetrics = metrics;
      _qualityMetricsController.add(metrics);

      // Adapt video quality based on network conditions
      if (_adaptiveQualityEnabled) {
        _adaptVideoQuality(metrics);
      }
    } catch (e) {
      debugPrint('WebRTCService: Error collecting quality metrics: $e');
    }
  }

  /// Adapt video quality based on network metrics
  /// For Sahel context: automatically switch to audio-only on very poor network
  Future<void> _adaptVideoQuality(CallQualityMetrics metrics) async {
    final newQuality = metrics.qualityLevel;
    final previousQuality = _currentAdaptiveQuality;

    // Track consecutive poor quality readings for automatic video disable
    if (newQuality == CallQualityLevel.poor) {
      _poorQualityCount++;

      // After threshold consecutive poor readings, disable video automatically
      if (_poorQualityCount >= _poorQualityThreshold &&
          !_videoDisabledDueToNetwork) {
        await _disableVideoDueToNetwork();
        return;
      }
    } else {
      // Reset poor quality counter on improvement
      _poorQualityCount = 0;

      // Re-enable video if network improved significantly and was disabled due to network
      if (_videoDisabledDueToNetwork &&
          (newQuality == CallQualityLevel.good ||
              newQuality == CallQualityLevel.excellent)) {
        await _reenableVideoAfterNetworkImprovement();
      }
    }

    // Only adapt if quality level changed significantly
    if (newQuality == previousQuality) return;

    _currentAdaptiveQuality = newQuality;

    // Emit warning event when quality degrades to fair
    if (newQuality == CallQualityLevel.fair &&
        previousQuality != CallQualityLevel.fair) {
      _networkDegradationController.add(
        NetworkDegradationEvent(
          type: NetworkDegradationType.networkQualityWarning,
          message: 'Qualité réseau dégradée',
          qualityLevel: newQuality,
          timestamp: DateTime.now(),
        ),
      );
    }

    // Get video senders and adjust parameters
    final senders = await _peerConnection?.getSenders();
    if (senders == null) return;

    for (final sender in senders) {
      if (sender.track?.kind != 'video') continue;

      try {
        final params = sender.parameters;
        final encodings = params.encodings;

        if (encodings == null || encodings.isEmpty) continue;

        // Adjust encoding parameters based on quality level
        for (final encoding in encodings) {
          switch (newQuality) {
            case CallQualityLevel.excellent:
              // High quality - 640x480 @ 30fps
              encoding.maxBitrate = 800000; // 800 kbps
              encoding.maxFramerate = 30;
              encoding.scaleResolutionDownBy = 1.0;
              break;
            case CallQualityLevel.good:
              // Medium quality - 480x360 @ 24fps
              encoding.maxBitrate = 500000; // 500 kbps
              encoding.maxFramerate = 24;
              encoding.scaleResolutionDownBy = 1.33;
              break;
            case CallQualityLevel.fair:
              // Low quality - 320x240 @ 15fps
              encoding.maxBitrate = 250000; // 250 kbps
              encoding.maxFramerate = 15;
              encoding.scaleResolutionDownBy = 2.0;
              break;
            case CallQualityLevel.poor:
              // Very low quality - 160x120 @ 10fps
              encoding.maxBitrate = 100000; // 100 kbps
              encoding.maxFramerate = 10;
              encoding.scaleResolutionDownBy = 4.0;
              break;
            case CallQualityLevel.unknown:
              // Keep current settings
              break;
          }
        }

        await sender.setParameters(params);
        debugPrint('WebRTCService: Adapted video quality to $newQuality');
      } catch (e) {
        debugPrint('WebRTCService: Error adapting video quality: $e');
      }
    }
  }

  /// Disable video due to poor network conditions (automatic fallback to audio)
  Future<void> _disableVideoDueToNetwork() async {
    if (_videoDisabledDueToNetwork) return;

    _videoDisabledDueToNetwork = true;

    // Disable video tracks
    _localStream?.getVideoTracks().forEach((track) {
      track.enabled = false;
    });
    _isCameraOff = true;

    // Emit event to notify UI
    _networkDegradationController.add(
      NetworkDegradationEvent(
        type: NetworkDegradationType.videoDisabledPoorNetwork,
        message: 'Connexion faible — passage en audio uniquement',
        qualityLevel: CallQualityLevel.poor,
        timestamp: DateTime.now(),
      ),
    );

    debugPrint(
      'WebRTCService: Video disabled due to poor network - switched to audio only',
    );
  }

  /// Re-enable video after network improvement
  Future<void> _reenableVideoAfterNetworkImprovement() async {
    if (!_videoDisabledDueToNetwork) return;

    _videoDisabledDueToNetwork = false;

    // Re-enable video tracks
    _localStream?.getVideoTracks().forEach((track) {
      track.enabled = true;
    });
    _isCameraOff = false;

    // Emit event to notify UI
    _networkDegradationController.add(
      NetworkDegradationEvent(
        type: NetworkDegradationType.videoReenabledNetworkImproved,
        message: 'Connexion améliorée — vidéo restaurée',
        qualityLevel: _currentAdaptiveQuality,
        timestamp: DateTime.now(),
      ),
    );

    debugPrint('WebRTCService: Video re-enabled after network improvement');
  }

  /// Manually re-enable video after automatic disable (user override)
  void forceReenableVideo() {
    if (_videoDisabledDueToNetwork) {
      _videoDisabledDueToNetwork = false;
      _poorQualityCount = 0;

      _localStream?.getVideoTracks().forEach((track) {
        track.enabled = true;
      });
      _isCameraOff = false;

      debugPrint('WebRTCService: Video force re-enabled by user');
    }
  }

  /// Enable or disable adaptive quality
  void setAdaptiveQualityEnabled(bool enabled) {
    _adaptiveQualityEnabled = enabled;
    debugPrint(
      'WebRTCService: Adaptive quality ${enabled ? 'enabled' : 'disabled'}',
    );
  }

  /// Get current adaptive quality level
  CallQualityLevel get currentAdaptiveQuality => _currentAdaptiveQuality;

  /// Hang up the call
  Future<void> hangUp() async {
    // Guard: Prevent concurrent hangups
    if (_isEndingCall) {
      debugPrint('WebRTCService: hangUp already in progress, ignoring');
      return;
    }

    // Guard: No active call to hang up
    if (_currentCallId == null && _connectionState == WebRTCConnectionState.idle) {
      debugPrint('WebRTCService: No active call to hang up');
      return;
    }

    _isEndingCall = true;
    debugPrint('WebRTCService: Hanging up');

    // Tout le corps est encadré : `_isEndingCall` vient d'être posé et le garde
    // d'entrée rejette tout nouvel appel tant qu'il est vrai. Sans ce
    // try/finally, la moindre exception en cours de route — fermeture de la
    // peer connection, dispose du flux, et surtout la suppression RÉSEAU des
    // données de signalisation en RTDB — laissait le service définitivement
    // coincé : `_currentCallId` non nul, `_isEndingCall` bloqué à vrai, donc
    // plus aucun raccrochage possible ET `startCall` qui lève « Already in a
    // call » pour tous les appels suivants, jusqu'au redémarrage de l'app.
    try {
      // Cancel any ongoing reconnection attempt
      _cancelReconnection();

      // Stop quality monitoring
      _stopQualityMonitoring();

      await _cancelSignalingSubscriptions();

      try {
        await _peerConnection?.close();
      } catch (e) {
        debugPrint('WebRTCService: Error closing peer connection: $e');
      }
      _peerConnection = null;

      try {
        _localStream?.getTracks().forEach((track) {
          track.stop();
        });
        await _localStream?.dispose();
      } catch (e) {
        debugPrint('WebRTCService: Error disposing local stream: $e');
      }
      _localStream = null;

      // Clear remote stream
      _remoteStream = null;

      // Clear renderers (may fail if not initialized)
      try {
        localRenderer.srcObject = null;
        remoteRenderer.srcObject = null;
      } catch (e) {
        // Ignore - renderers may not be initialized
      }

      // Nettoyage des données de signalisation : appel réseau, donc borné dans
      // le temps et best effort. Un RTDB injoignable ne doit pas empêcher la
      // libération locale — au pire quelques noeuds orphelins restent, que
      // cleanupStaleCalls balaie.
      final callId = _currentCallId;
      if (callId != null) {
        try {
          await _database.ref('calls/$callId').remove().timeout(_signalingTimeout);
        } catch (e) {
          debugPrint('WebRTCService: Signaling cleanup failed for $callId: $e');
        }
      }
    } finally {
      // Reset state
      _currentCallId = null;
      _isInitiator = false;
      _isMuted = false;
      _isCameraOff = false;
      _isSpeakerOn = true;
      _isOnHold = false;
      _videoDisabledDueToNetwork = false;
      _poorQualityCount = 0;
      _currentAdaptiveQuality = CallQualityLevel.good;
      _isEndingCall = false;
      _isStartingCall = false;
      _updateConnectionState(WebRTCConnectionState.idle);
    }

    debugPrint('WebRTCService: Hung up successfully');
  }

  /// Annule et oublie toutes les souscriptions de signalisation.
  ///
  /// Chacune est annulée indépendamment : un échec sur l'une ne doit pas
  /// laisser les suivantes vivantes et écouter l'appel précédent.
  Future<void> _cancelSignalingSubscriptions() async {
    final subscriptions = <StreamSubscription?>[
      _offerSubscription,
      _answerSubscription,
      _candidateSubscription,
      _videoUpgradeSubscription,
      _renegotiateOfferSubscription,
      _renegotiateAnswerSubscription,
      _iceRestartOfferSubscription,
      _iceRestartAnswerSubscription,
    ];
    _offerSubscription = null;
    _answerSubscription = null;
    _candidateSubscription = null;
    _videoUpgradeSubscription = null;
    _renegotiateOfferSubscription = null;
    _renegotiateAnswerSubscription = null;
    _iceRestartOfferSubscription = null;
    _iceRestartAnswerSubscription = null;

    for (final subscription in subscriptions) {
      try {
        await subscription?.cancel();
      } catch (e) {
        debugPrint('WebRTCService: Error cancelling signaling subscription: $e');
      }
    }
  }

  /// Dispose resources
  /// Note: After dispose, call initialize() again before reusing the service
  Future<void> dispose() async {
    await hangUp();
    try {
      await localRenderer.dispose();
    } catch (e) {
      debugPrint('WebRTCService: Error disposing local renderer: $e');
    }
    try {
      await remoteRenderer.dispose();
    } catch (e) {
      debugPrint('WebRTCService: Error disposing remote renderer: $e');
    }
    await _connectionStateController.close();
    await _audioLevelController.close();
    await _videoUpgradeRequestController.close();
    await _videoUpgradeResponseController.close();
    await _qualityMetricsController.close();
    await _networkDegradationController.close();
    _isInitialized = false;
  }
}
