import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'e2ee_service.dart';
import 'webrtc_service.dart';

/// Callback for remote stream events
typedef OnRemoteStreamCallback =
    void Function(String participantId, MediaStream stream);
typedef OnParticipantLeftCallback = void Function(String participantId);
typedef OnParticipantJoinedCallback = void Function(String participantId);

/// Service for managing mesh-based group calls (2-4 participants)
///
/// Each participant creates a direct WebRTC connection to every other participant.
/// Uses Firebase Realtime Database for signaling.
class GroupCallService {
  static final GroupCallService _instance = GroupCallService._internal();
  factory GroupCallService() => _instance;
  GroupCallService._internal();

  static GroupCallService get instance => _instance;

  // Firebase Realtime Database reference
  final _database = FirebaseDatabase.instance;

  // E2EE Service
  final _e2eeService = E2EEService.instance;

  // Peer connections - one per remote participant
  final Map<String, RTCPeerConnection> _peerConnections = {};

  // Remote streams - one per remote participant
  final Map<String, MediaStream> _remoteStreams = {};

  // Video renderers for each remote participant
  final Map<String, RTCVideoRenderer> _remoteRenderers = {};

  // Local stream and renderer
  MediaStream? _localStream;
  final RTCVideoRenderer localRenderer = RTCVideoRenderer();

  // Signaling subscriptions
  final Map<String, StreamSubscription> _signalingSubscriptions = {};

  // State
  bool _isInitialized = false;
  bool _isMuted = false;
  bool _isCameraOff = true;
  String? _currentCallId;
  String? _currentUserId;
  bool _isE2EEEnabled = false;

  // Callbacks
  OnRemoteStreamCallback? _onRemoteStream;
  OnParticipantLeftCallback? _onParticipantLeft;
  OnParticipantJoinedCallback? _onParticipantJoined;

  // Stream controllers
  final _connectionStateController =
      StreamController<Map<String, WebRTCConnectionState>>.broadcast();

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isMuted => _isMuted;
  bool get isCameraOff => _isCameraOff;
  bool get isE2EEEnabled => _isE2EEEnabled;
  MediaStream? get localStream => _localStream;
  Map<String, MediaStream> get remoteStreams =>
      Map.unmodifiable(_remoteStreams);
  Stream<Map<String, WebRTCConnectionState>> get connectionStatesStream =>
      _connectionStateController.stream;

  /// Initialize the group call service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await localRenderer.initialize();
      _isInitialized = true;
      debugPrint('GroupCallService: Initialized successfully');
    } catch (e) {
      debugPrint('GroupCallService: Error initializing: $e');
      rethrow;
    }
  }

  /// Get or create a renderer for a remote participant
  Future<RTCVideoRenderer> getRemoteRenderer(String participantId) async {
    if (!_remoteRenderers.containsKey(participantId)) {
      final renderer = RTCVideoRenderer();
      await renderer.initialize();
      _remoteRenderers[participantId] = renderer;
    }
    return _remoteRenderers[participantId]!;
  }

  /// Start or join a group call
  ///
  /// [callId] - Unique identifier for the call
  /// [oderId] - Current user's ID
  /// [participantIds] - List of all participant IDs (including self)
  /// [enableVideo] - Whether to enable video
  /// [enableE2EE] - Whether to enable end-to-end encryption
  Future<void> joinCall({
    required String callId,
    required String oderId,
    required List<String> participantIds,
    bool enableVideo = false,
    bool enableE2EE = true,
    OnRemoteStreamCallback? onRemoteStream,
    OnParticipantLeftCallback? onParticipantLeft,
    OnParticipantJoinedCallback? onParticipantJoined,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    _currentCallId = callId;
    _currentUserId = oderId;
    _onRemoteStream = onRemoteStream;
    _onParticipantLeft = onParticipantLeft;
    _onParticipantJoined = onParticipantJoined;
    _isE2EEEnabled = enableE2EE;

    try {
      // Get local media stream
      await _getUserMedia(enableVideo: enableVideo);

      // Setup E2EE if enabled
      if (enableE2EE) {
        final keyData = await _e2eeService.generateCallKey();
        // Store encrypted key in Firebase for other participants
        await _shareE2EEKey(callId, keyData, participantIds);
      }

      // Get other participants (excluding self)
      final otherParticipants =
          participantIds.where((id) => id != oderId).toList();

      // S'inscrire AVANT d'ecouter. L'ordre inverse marche tant que les regles
      // RTDB laissent lire `group_calls/<id>` a tout compte connecte, mais des
      // qu'elles reservent la lecture aux participants — ce qui est le but —
      // ecouter avant de s'inscrire est refuse, et la detection des arrivees
      // meurt en silence. Verifie en emulateur le 2026-08-06
      // (tools/rules_tests/signalisation_appels.mjs).
      //
      // S'inscrire d'abord ne fait rien perdre : `onChildAdded` emet aussi
      // pour les enfants deja presents.
      await _registerParticipant(callId, oderId);

      // Listen for new participants joining
      _listenForParticipants(callId, oderId);

      // Create peer connections to each existing participant
      for (final participantId in otherParticipants) {
        await _connectToParticipant(
          participantId: participantId,
          callId: callId,
          isInitiator: oderId.compareTo(participantId) > 0,
        );
      }

      debugPrint(
        'GroupCallService: Joined call $callId with ${otherParticipants.length} participants',
      );
    } catch (e) {
      debugPrint('GroupCallService: Error joining call: $e');
      await leaveCall();
      rethrow;
    }
  }

  /// Join a group call with an existing media stream (for 1:1 to group conversion)
  ///
  /// [callId] - Unique identifier for the group call
  /// [userId] - Current user's ID
  /// [participantIds] - List of all participant IDs (including self)
  /// [existingLocalStream] - The existing local stream from the 1:1 call
  /// [enableE2EE] - Whether to enable end-to-end encryption
  Future<void> joinCallWithExistingStream({
    required String callId,
    required String userId,
    required List<String> participantIds,
    required MediaStream existingLocalStream,
    bool enableE2EE = true,
    OnRemoteStreamCallback? onRemoteStream,
    OnParticipantLeftCallback? onParticipantLeft,
    OnParticipantJoinedCallback? onParticipantJoined,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    _currentCallId = callId;
    _currentUserId = userId;
    _onRemoteStream = onRemoteStream;
    _onParticipantLeft = onParticipantLeft;
    _onParticipantJoined = onParticipantJoined;
    _isE2EEEnabled = enableE2EE;

    try {
      // Reuse the existing stream instead of getting new media
      _localStream = existingLocalStream;

      // Check if video is enabled in the existing stream
      final hasVideoTrack = existingLocalStream.getVideoTracks().isNotEmpty;
      final videoEnabled = hasVideoTrack &&
          (existingLocalStream.getVideoTracks().firstOrNull?.enabled ?? false);
      _isCameraOff = !videoEnabled;

      if (videoEnabled) {
        localRenderer.srcObject = _localStream;
      }

      debugPrint(
        'GroupCallService: Reusing existing stream for group call (video: $videoEnabled)',
      );

      // Setup E2EE if enabled
      if (enableE2EE) {
        final keyData = await _e2eeService.generateCallKey();
        await _shareE2EEKey(callId, keyData, participantIds);
      }

      // Get other participants (excluding self)
      final otherParticipants =
          participantIds.where((id) => id != userId).toList();

      // S'inscrire AVANT d'ecouter — meme raison qu'au-dessus : sous des regles
      // qui reservent la lecture aux participants, ecouter avant de s'inscrire
      // est refuse et la detection des arrivees meurt en silence.
      await _registerParticipant(callId, userId);

      // Listen for new participants joining
      _listenForParticipants(callId, userId);

      // Create peer connections to each existing participant
      for (final participantId in otherParticipants) {
        await _connectToParticipant(
          participantId: participantId,
          callId: callId,
          isInitiator: userId.compareTo(participantId) > 0,
        );
      }

      debugPrint(
        'GroupCallService: Joined call $callId with existing stream, '
        '${otherParticipants.length} participants',
      );
    } catch (e) {
      debugPrint('GroupCallService: Error joining call with existing stream: $e');
      await leaveCall();
      rethrow;
    }
  }

  /// Get user media (camera and/or microphone)
  Future<void> _getUserMedia({required bool enableVideo}) async {
    final constraints = <String, dynamic>{
      'audio': true,
      'video':
          enableVideo
              ? {
                'facingMode': 'user',
                'width': {'ideal': 640},
                'height': {'ideal': 480},
              }
              : false,
    };

    try {
      _localStream = await navigator.mediaDevices.getUserMedia(constraints);
      _isCameraOff = !enableVideo;

      if (enableVideo) {
        localRenderer.srcObject = _localStream;
      }

      debugPrint('GroupCallService: Got local stream');
    } catch (e) {
      debugPrint('GroupCallService: Error getting user media: $e');
      rethrow;
    }
  }

  /// Share E2EE key with all participants
  Future<void> _shareE2EEKey(
    String callId,
    E2EEKeyData keyData,
    List<String> participantIds,
  ) async {
    final encryptedKey = await _e2eeService.encryptKeyForSharing(
      callId: callId,
      participantIds: participantIds,
    );

    final callRef = _database.ref('group_calls/$callId');
    await callRef.child('e2ee_key').set({
      'keyId': keyData.keyId,
      'encryptedKey': encryptedKey,
    });

    debugPrint('GroupCallService: E2EE key shared');
  }

  /// Register as a participant in Firebase
  Future<void> _registerParticipant(String callId, String oderId) async {
    final callRef = _database.ref('group_calls/$callId');
    await callRef.child('participants/$oderId').set({
      'joinedAt': ServerValue.timestamp,
    });
  }

  /// Listen for participants joining/leaving
  void _listenForParticipants(String callId, String oderId) {
    final participantsRef = _database.ref('group_calls/$callId/participants');

    // Listen for new participants
    final addedSub = participantsRef.onChildAdded.listen((event) async {
      final participantId = event.snapshot.key!;
      if (participantId == oderId) return;

      // Check if we already have a connection
      if (_peerConnections.containsKey(participantId)) return;

      debugPrint('GroupCallService: New participant joined: $participantId');
      _onParticipantJoined?.call(participantId);

      // Connect to the new participant
      await _connectToParticipant(
        participantId: participantId,
        callId: callId,
        isInitiator: oderId.compareTo(participantId) > 0,
      );
    });

    _signalingSubscriptions['participants_added'] = addedSub;

    // Listen for participants leaving
    final removedSub = participantsRef.onChildRemoved.listen((event) {
      final participantId = event.snapshot.key!;
      if (participantId == oderId) return;

      debugPrint('GroupCallService: Participant left: $participantId');
      _onParticipantLeft?.call(participantId);
      _disconnectFromParticipant(participantId);
    });

    _signalingSubscriptions['participants_removed'] = removedSub;
  }

  /// Create a peer connection to a specific participant
  Future<void> _connectToParticipant({
    required String participantId,
    required String callId,
    required bool isInitiator,
  }) async {
    debugPrint(
      'GroupCallService: Connecting to $participantId (initiator: $isInitiator)',
    );

    final configuration = <String, dynamic>{
      'iceServers': await IceServerConfig.fetchIceServers(),
      'sdpSemantics': 'unified-plan',
    };

    final pc = await createPeerConnection(configuration);
    _peerConnections[participantId] = pc;

    // Add local stream tracks
    _localStream?.getTracks().forEach((track) {
      pc.addTrack(track, _localStream!);
    });

    // Handle incoming streams
    pc.onTrack = (RTCTrackEvent event) async {
      if (event.streams.isNotEmpty) {
        final stream = event.streams[0];
        _remoteStreams[participantId] = stream;

        final renderer = await getRemoteRenderer(participantId);
        renderer.srcObject = stream;

        _onRemoteStream?.call(participantId, stream);
        debugPrint('GroupCallService: Received stream from $participantId');
      }
    };

    // Handle ICE candidates
    pc.onIceCandidate = (RTCIceCandidate candidate) {
      _sendIceCandidate(
        callId: callId,
        fromId: _currentUserId!,
        toId: participantId,
        candidate: candidate,
      );
    };

    // Handle connection state changes
    pc.onConnectionState = (RTCPeerConnectionState state) {
      debugPrint(
        'GroupCallService: Connection to $participantId state: $state',
      );
      _notifyConnectionStateChange();
    };

    // Setup signaling listeners for this participant
    _setupSignalingForParticipant(
      callId: callId,
      localId: _currentUserId!,
      remoteId: participantId,
      pc: pc,
    );

    // If we're the initiator, create and send offer
    if (isInitiator) {
      await _createAndSendOffer(callId, participantId, pc);
    }

    // Enable E2EE if configured
    if (_isE2EEEnabled) {
      await _enableE2EEForConnection(participantId, pc);
    }
  }

  /// Setup signaling listeners for a specific participant
  void _setupSignalingForParticipant({
    required String callId,
    required String localId,
    required String remoteId,
    required RTCPeerConnection pc,
  }) {
    final signalingRef = _database.ref(
      'group_calls/$callId/signaling/$remoteId/$localId',
    );

    // Listen for offers
    final offerSub = signalingRef.child('offer').onValue.listen((event) async {
      if (event.snapshot.value == null) return;
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      await _handleOffer(pc, data, callId, localId, remoteId);
    });
    _signalingSubscriptions['offer_$remoteId'] = offerSub;

    // Listen for answers
    final answerSub = signalingRef.child('answer').onValue.listen((
      event,
    ) async {
      if (event.snapshot.value == null) return;
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      await _handleAnswer(pc, data);
    });
    _signalingSubscriptions['answer_$remoteId'] = answerSub;

    // Listen for ICE candidates
    final candidateSub = signalingRef.child('candidates').onChildAdded.listen((
      event,
    ) async {
      if (event.snapshot.value == null) return;
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      await _handleIceCandidate(pc, data);
    });
    _signalingSubscriptions['candidates_$remoteId'] = candidateSub;
  }

  /// Create and send SDP offer
  Future<void> _createAndSendOffer(
    String callId,
    String toId,
    RTCPeerConnection pc,
  ) async {
    try {
      final offer = await pc.createOffer();
      await pc.setLocalDescription(offer);

      final signalingRef = _database.ref(
        'group_calls/$callId/signaling/$_currentUserId/$toId',
      );
      await signalingRef.child('offer').set({
        'type': offer.type,
        'sdp': offer.sdp,
      });

      debugPrint('GroupCallService: Sent offer to $toId');
    } catch (e) {
      debugPrint('GroupCallService: Error creating offer: $e');
    }
  }

  /// Handle received offer
  Future<void> _handleOffer(
    RTCPeerConnection pc,
    Map<String, dynamic> data,
    String callId,
    String localId,
    String remoteId,
  ) async {
    try {
      final offer = RTCSessionDescription(data['sdp'], data['type']);
      await pc.setRemoteDescription(offer);

      final answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);

      final signalingRef = _database.ref(
        'group_calls/$callId/signaling/$localId/$remoteId',
      );
      await signalingRef.child('answer').set({
        'type': answer.type,
        'sdp': answer.sdp,
      });

      debugPrint('GroupCallService: Sent answer to $remoteId');
    } catch (e) {
      debugPrint('GroupCallService: Error handling offer: $e');
    }
  }

  /// Handle received answer
  Future<void> _handleAnswer(
    RTCPeerConnection pc,
    Map<String, dynamic> data,
  ) async {
    try {
      final answer = RTCSessionDescription(data['sdp'], data['type']);
      await pc.setRemoteDescription(answer);
      debugPrint('GroupCallService: Received and set answer');
    } catch (e) {
      debugPrint('GroupCallService: Error handling answer: $e');
    }
  }

  /// Send ICE candidate
  void _sendIceCandidate({
    required String callId,
    required String fromId,
    required String toId,
    required RTCIceCandidate candidate,
  }) {
    final signalingRef = _database.ref(
      'group_calls/$callId/signaling/$fromId/$toId/candidates',
    );
    signalingRef.push().set({
      'candidate': candidate.candidate,
      'sdpMid': candidate.sdpMid,
      'sdpMLineIndex': candidate.sdpMLineIndex,
    });
  }

  /// Handle received ICE candidate
  Future<void> _handleIceCandidate(
    RTCPeerConnection pc,
    Map<String, dynamic> data,
  ) async {
    try {
      final candidate = RTCIceCandidate(
        data['candidate'],
        data['sdpMid'],
        data['sdpMLineIndex'],
      );
      await pc.addCandidate(candidate);
    } catch (e) {
      debugPrint('GroupCallService: Error adding ICE candidate: $e');
    }
  }

  /// Enable E2EE for a specific connection
  Future<void> _enableE2EEForConnection(
    String participantId,
    RTCPeerConnection pc,
  ) async {
    try {
      // Enable for senders
      final senders = await pc.getSenders();
      for (final sender in senders) {
        if (sender.track != null) {
          await _e2eeService.enableE2EEForSender(
            participantId: participantId,
            sender: sender,
            peerConnection: pc,
          );
        }
      }

      // Enable for receivers
      final receivers = await pc.getReceivers();
      for (final receiver in receivers) {
        if (receiver.track != null) {
          await _e2eeService.enableE2EEForReceiver(
            participantId: participantId,
            receiver: receiver,
            peerConnection: pc,
          );
        }
      }

      debugPrint('GroupCallService: E2EE enabled for $participantId');
    } catch (e) {
      debugPrint('GroupCallService: Error enabling E2EE: $e');
    }
  }

  /// Disconnect from a specific participant
  Future<void> _disconnectFromParticipant(String participantId) async {
    // Close peer connection
    final pc = _peerConnections.remove(participantId);
    await pc?.close();

    // Remove remote stream
    _remoteStreams.remove(participantId);

    // Cleanup renderer
    final renderer = _remoteRenderers.remove(participantId);
    renderer?.srcObject = null;
    await renderer?.dispose();

    // Cancel signaling subscriptions for this participant
    _signalingSubscriptions.remove('offer_$participantId')?.cancel();
    _signalingSubscriptions.remove('answer_$participantId')?.cancel();
    _signalingSubscriptions.remove('candidates_$participantId')?.cancel();

    // Disable E2EE for this participant
    await _e2eeService.disableE2EE(participantId);

    _notifyConnectionStateChange();
  }

  /// Notify listeners of connection state changes
  void _notifyConnectionStateChange() {
    final states = <String, WebRTCConnectionState>{};
    for (final entry in _peerConnections.entries) {
      // Map RTCPeerConnectionState to WebRTCConnectionState
      states[entry.key] = WebRTCConnectionState.connecting;
    }
    _connectionStateController.add(states);
  }

  /// Toggle microphone mute
  void toggleMute() {
    _isMuted = !_isMuted;
    _localStream?.getAudioTracks().forEach((track) {
      track.enabled = !_isMuted;
    });
    debugPrint('GroupCallService: Muted: $_isMuted');
  }

  /// Toggle camera on/off
  void toggleCamera() {
    _isCameraOff = !_isCameraOff;
    _localStream?.getVideoTracks().forEach((track) {
      track.enabled = !_isCameraOff;
    });

    if (!_isCameraOff) {
      localRenderer.srcObject = _localStream;
    }

    debugPrint('GroupCallService: Camera off: $_isCameraOff');
  }

  /// Set camera enabled/disabled
  Future<void> setCameraEnabled(bool enabled) async {
    _isCameraOff = !enabled;
    _localStream?.getVideoTracks().forEach((track) {
      track.enabled = enabled;
    });

    if (enabled) {
      localRenderer.srcObject = _localStream;
    }

    debugPrint('GroupCallService: Camera enabled: $enabled');
  }

  /// Switch between front and back camera
  Future<void> switchCamera() async {
    if (_localStream == null) return;

    final videoTrack = _localStream!.getVideoTracks().firstOrNull;
    if (videoTrack != null) {
      await Helper.switchCamera(videoTrack);
      debugPrint('GroupCallService: Camera switched');
    }
  }

  /// Enable video during an audio call
  Future<void> enableVideo() async {
    if (_isCameraOff && _localStream != null) {
      // Get video stream
      final videoStream = await navigator.mediaDevices.getUserMedia({
        'audio': false,
        'video': {
          'facingMode': 'user',
          'width': {'ideal': 640},
          'height': {'ideal': 480},
        },
      });

      final videoTrack = videoStream.getVideoTracks().first;
      _localStream!.addTrack(videoTrack);

      // Add track to all peer connections
      for (final pc in _peerConnections.values) {
        await pc.addTrack(videoTrack, _localStream!);
      }

      localRenderer.srcObject = _localStream;
      _isCameraOff = false;

      debugPrint('GroupCallService: Video enabled');
    }
  }

  /// Leave the current call
  Future<void> leaveCall() async {
    debugPrint('GroupCallService: Leaving call');

    // Remove ourselves from participants
    if (_currentCallId != null && _currentUserId != null) {
      await _database
          .ref('group_calls/$_currentCallId/participants/$_currentUserId')
          .remove();
    }

    // Cancel all signaling subscriptions
    for (final sub in _signalingSubscriptions.values) {
      await sub.cancel();
    }
    _signalingSubscriptions.clear();

    // Close all peer connections
    for (final participantId in _peerConnections.keys.toList()) {
      await _disconnectFromParticipant(participantId);
    }

    // Stop local stream
    _localStream?.getTracks().forEach((track) {
      track.stop();
    });
    await _localStream?.dispose();
    _localStream = null;
    localRenderer.srcObject = null;

    // Cleanup E2EE
    await _e2eeService.dispose();

    // Reset state
    _currentCallId = null;
    _currentUserId = null;
    _isMuted = false;
    _isCameraOff = true;
    _isE2EEEnabled = false;

    debugPrint('GroupCallService: Left call successfully');
  }

  /// Dispose resources
  Future<void> dispose() async {
    await leaveCall();
    await localRenderer.dispose();
    await _connectionStateController.close();
    _isInitialized = false;
  }
}
