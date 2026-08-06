import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/services/webrtc_service.dart';
import '../../../../core/services/call_message_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/native_call_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../settings/presentation/providers/blocked_users_provider.dart';
import '../../data/datasources/call_remote_datasource.dart';
import '../../data/repositories/call_repository_impl.dart';
import '../../domain/entities/call_entity.dart';
import '../../domain/repositories/call_repository.dart';
import '../../../group_calls/domain/entities/group_call_entity.dart';
import '../../../group_calls/presentation/providers/group_call_provider.dart';

/// Provider for CallRemoteDataSource
final callRemoteDataSourceProvider = Provider<CallRemoteDataSource>((ref) {
  return CallRemoteDataSourceImpl(
    firestoreInstance: FirebaseFirestore.instance,
    databaseInstance: FirebaseDatabase.instance,
  );
});

/// Provider for CallRepository
final callRepositoryProvider = Provider<CallRepository>((ref) {
  return CallRepositoryImpl(
    remoteDataSource: ref.watch(callRemoteDataSourceProvider),
  );
});

/// Provider for WebRTCService
final webRTCServiceProvider = Provider<WebRTCService>((ref) {
  return WebRTCService.instance;
});

/// Provider for CallMessageService
final callMessageServiceProvider = Provider<CallMessageService>((ref) {
  return CallMessageService();
});

/// Provider for NativeCallService (CallKit/ConnectionService)
final nativeCallServiceProvider = Provider<NativeCallService>((ref) {
  final service = NativeCallService.instance;
  service.initialize();
  return service;
});

/// Stream of active call for current user
final activeCallProvider = StreamProvider<CallEntity?>((ref) async* {
  final currentUser = await ref.watch(currentUserProvider.future);
  if (currentUser == null) {
    yield null;
    return;
  }

  final repository = ref.watch(callRepositoryProvider);
  yield* repository
      .getActiveCallStream(currentUser.id)
      .map((either) => either.fold((failure) => null, (call) => call));
});

/// Stream that watches a specific call by ID (regardless of status)
/// Essential for detecting when remote party ends/declines the call
final callByIdProvider = StreamProvider.family<CallEntity?, String>((ref, callId) {
  final repository = ref.watch(callRepositoryProvider);
  return repository.watchCallById(callId);
});

/// Stream of call history for current user
final callHistoryProvider = StreamProvider<List<CallEntity>>((ref) async* {
  final currentUser = await ref.watch(currentUserProvider.future);
  if (currentUser == null) {
    yield [];
    return;
  }

  final repository = ref.watch(callRepositoryProvider);
  yield* repository
      .getCallHistory(currentUser.id, limit: 50)
      .map(
        (either) => either.fold((failure) => <CallEntity>[], (calls) => calls),
      );
});

/// Clear call history for current user
final clearCallHistoryProvider = FutureProvider.family<bool, List<String>>((
  ref,
  callIds,
) async {
  final repository = ref.read(callRepositoryProvider);

  for (final callId in callIds) {
    final result = await repository.deleteCall(callId);
    if (result.isLeft()) {
      return false;
    }
  }

  ref.invalidate(callHistoryProvider);
  return true;
});

/// Status of a video upgrade request
enum VideoUpgradeStatus {
  none,
  requesting,
  pendingApproval,
  accepted,
  declined,
}

/// State for the current call
class CurrentCallState {
  final CallEntity? call;
  final bool isConnecting;
  final bool isConnected;
  final bool isRinging;
  final bool isMuted;
  final bool isCameraOff;
  final bool isSpeakerOn;
  final bool isOnHold;
  final bool isVideoEnabled;
  final bool isVideoDisabledDueToNetwork;
  final Duration? duration;
  final String? error;
  final String? errorCode;
  final String? networkMessage;
  final VideoUpgradeStatus videoUpgradeStatus;
  // Guards to prevent race conditions
  final bool isEnding;
  final bool isInitiating;

  const CurrentCallState({
    this.call,
    this.isConnecting = false,
    this.isConnected = false,
    this.isRinging = false,
    this.isMuted = false,
    this.isCameraOff = false,
    this.isSpeakerOn = true,
    this.isOnHold = false,
    this.isVideoEnabled = false,
    this.isVideoDisabledDueToNetwork = false,
    this.duration,
    this.error,
    this.errorCode,
    this.networkMessage,
    this.videoUpgradeStatus = VideoUpgradeStatus.none,
    this.isEnding = false,
    this.isInitiating = false,
  });

  CurrentCallState copyWith({
    CallEntity? call,
    bool? isConnecting,
    bool? isConnected,
    bool? isRinging,
    bool? isMuted,
    bool? isCameraOff,
    bool? isSpeakerOn,
    bool? isOnHold,
    bool? isVideoEnabled,
    bool? isVideoDisabledDueToNetwork,
    Duration? duration,
    String? error,
    String? errorCode,
    String? networkMessage,
    VideoUpgradeStatus? videoUpgradeStatus,
    bool clearNetworkMessage = false,
    bool? isEnding,
    bool? isInitiating,
  }) {
    return CurrentCallState(
      call: call ?? this.call,
      isConnecting: isConnecting ?? this.isConnecting,
      isConnected: isConnected ?? this.isConnected,
      isRinging: isRinging ?? this.isRinging,
      isMuted: isMuted ?? this.isMuted,
      isCameraOff: isCameraOff ?? this.isCameraOff,
      isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
      isOnHold: isOnHold ?? this.isOnHold,
      isVideoEnabled: isVideoEnabled ?? this.isVideoEnabled,
      isVideoDisabledDueToNetwork:
          isVideoDisabledDueToNetwork ?? this.isVideoDisabledDueToNetwork,
      duration: duration ?? this.duration,
      error: error,
      errorCode: errorCode,
      networkMessage:
          clearNetworkMessage ? null : (networkMessage ?? this.networkMessage),
      videoUpgradeStatus: videoUpgradeStatus ?? this.videoUpgradeStatus,
      isEnding: isEnding ?? this.isEnding,
      isInitiating: isInitiating ?? this.isInitiating,
    );
  }
}

/// Provider for current call notifier (keepAlive = true)
final currentCallProvider =
    NotifierProvider<CurrentCallNotifier, CurrentCallState>(
      CurrentCallNotifier.new,
    );

/// Notifier for managing the current call
class CurrentCallNotifier extends Notifier<CurrentCallState> {
  Timer? _durationTimer;
  Timer? _networkMessageTimer;
  Timer? _ringingTimeoutTimer;
  Timer? _connectionTimeoutTimer;
  Timer? _heartbeatTimer;
  StreamSubscription<WebRTCConnectionState>? _connectionStateSubscription;
  StreamSubscription<String>? _videoUpgradeRequestSubscription;
  StreamSubscription<bool>? _videoUpgradeResponseSubscription;
  StreamSubscription<NetworkDegradationEvent>? _networkDegradationSubscription;
  StreamSubscription<Either<Failure, DateTime?>>? _remoteHeartbeatSubscription;
  DateTime? _callStartTime;
  DateTime? _lastRemoteHeartbeat;

  // Timeout durations
  static const Duration _ringingTimeout = Duration(seconds: 45);
  static const Duration _connectionTimeout = Duration(seconds: 30); // Increased for slow networks
  static const Duration _heartbeatInterval = Duration(seconds: 5);
  static const Duration _heartbeatTimeout = Duration(seconds: 15);

  /// Plafond appliqué aux écritures distantes de fin d'appel (archivage
  /// Firestore, message de conversation). Ces écritures ne sont que du
  /// bookkeeping : au-delà, on abandonne plutôt que de faire attendre
  /// l'utilisateur sur un écran d'appel déjà terminé.
  static const Duration _remoteBookkeepingTimeout = Duration(seconds: 10);

  @override
  CurrentCallState build() {
    ref.onDispose(() {
      _durationTimer?.cancel();
      _networkMessageTimer?.cancel();
      _ringingTimeoutTimer?.cancel();
      _connectionTimeoutTimer?.cancel();
      _heartbeatTimer?.cancel();
      _connectionStateSubscription?.cancel();
      _videoUpgradeRequestSubscription?.cancel();
      _videoUpgradeResponseSubscription?.cancel();
      _networkDegradationSubscription?.cancel();
      _remoteHeartbeatSubscription?.cancel();
    });

    // Cleanup stale calls from previous session (crash recovery)
    Future.microtask(() => _cleanupStaleCalls());

    return const CurrentCallState();
  }

  /// Cleanup stale calls from previous session (crash recovery)
  Future<void> _cleanupStaleCalls() async {
    final currentUser = await ref.read(currentUserAsyncProvider.future);
    if (currentUser == null) return;

    try {
      final repository = ref.read(callRepositoryProvider);
      final result = await repository.cleanupUserStaleCalls(currentUser.id);
      result.fold(
        (failure) => debugPrint('CurrentCallNotifier: Failed to cleanup stale calls: ${failure.message}'),
        (cleanedCount) {
          if (cleanedCount > 0) {
            debugPrint('CurrentCallNotifier: Cleaned up $cleanedCount stale calls from previous session');
          }
        },
      );
    } catch (e) {
      debugPrint('CurrentCallNotifier: Error cleaning up stale calls: $e');
    }
  }

  /// Initiate a new call
  Future<CallEntity?> initiateCall({
    required String calleeId,
    required String calleeName,
    String? calleePhotoUrl,
    required CallType type,
  }) async {
    // Guard: prevent concurrent call initiation
    if (state.isInitiating || state.call != null) {
      debugPrint('CurrentCallNotifier: Already initiating or in a call');
      return null;
    }

    final currentUser = await ref.read(currentUserAsyncProvider.future);
    if (currentUser == null) {
      state = state.copyWith(error: 'Utilisateur non connecté');
      return null;
    }

    // Check block status before initiating call
    debugPrint('CurrentCallNotifier: Checking block status between ${currentUser.id} and $calleeId');
    final blockStatus = await ref
        .read(blockedUsersRepositoryProvider)
        .checkBlockStatus(currentUser.id, calleeId);

    final hasBlockRelationship = blockStatus.fold(
      (failure) {
        debugPrint('CurrentCallNotifier: Block check failed: ${failure.message}');
        return false;
      },
      (status) {
        debugPrint('CurrentCallNotifier: Block status - blocked: $status');
        return status;
      },
    );

    if (hasBlockRelationship) {
      debugPrint('CurrentCallNotifier: Call blocked by user');
      state = state.copyWith(
        error: 'Vous ne pouvez pas appeler cet utilisateur',
        errorCode: 'blocked_user',
      );
      return null;
    }
    debugPrint('CurrentCallNotifier: No block relationship, proceeding with call');

    state = state.copyWith(isConnecting: true, isInitiating: true, error: null);

    final result = await ref
        .read(callRepositoryProvider)
        .initiateCall(
          callerId: currentUser.id,
          callerName: currentUser.displayName ?? 'Utilisateur',
          callerPhotoUrl: currentUser.photoUrl,
          calleeId: calleeId,
          calleeName: calleeName,
          calleePhotoUrl: calleePhotoUrl,
          type: type,
        );

    return result.fold(
      (failure) {
        state = state.copyWith(isConnecting: false, isInitiating: false, error: failure.message);
        return null;
      },
      (call) async {
        // Check if callee was busy
        if (call.status == CallStatus.busy) {
          state = state.copyWith(
            isConnecting: false,
            isInitiating: false,
            error: '$calleeName est déjà en appel',
            errorCode: 'callee_busy',
          );
          return null;
        }

        state = state.copyWith(
          call: call,
          isConnecting: false,
          isInitiating: false,
          isRinging: true,
        );

        // Start ringing timeout (45 seconds)
        _startRingingTimeout(call.id);

        // Show native outgoing call UI
        await ref
            .read(nativeCallServiceProvider)
            .showOutgoingCall(
              callId: call.id,
              calleeName: calleeName,
              calleePhotoUrl: calleePhotoUrl,
              isVideo: type == CallType.video,
            );

        // Initialize WebRTC as initiator
        await _initializeWebRTC(
          call.id,
          isInitiator: true,
          enableVideo: type == CallType.video,
        );

        return call;
      },
    );
  }

  /// Start timeout timer for ringing state (caller side)
  void _startRingingTimeout(String callId) {
    _ringingTimeoutTimer?.cancel();
    _ringingTimeoutTimer = Timer(_ringingTimeout, () {
      if (state.isRinging && state.call?.id == callId) {
        debugPrint('CurrentCallNotifier: Ringing timeout reached for call $callId');
        endCall(reason: 'no_answer');
      }
    });
  }

  /// Cancel ringing timeout (called when call connects or ends)
  void _cancelRingingTimeout() {
    _ringingTimeoutTimer?.cancel();
    _ringingTimeoutTimer = null;
  }

  /// Start timeout timer for connection state (callee side)
  void _startConnectionTimeout(String callId) {
    _connectionTimeoutTimer?.cancel();
    _connectionTimeoutTimer = Timer(_connectionTimeout, () {
      if (state.isConnecting && state.call?.id == callId && !state.isConnected) {
        // Connection timeout - WebRTC failed to establish connection
        state = state.copyWith(
          error: 'Échec de la connexion',
          errorCode: 'connection_timeout',
        );
        endCall(reason: 'connection_timeout');
      }
    });
  }

  /// Cancel connection timeout (called when connected or call ends)
  void _cancelConnectionTimeout() {
    _connectionTimeoutTimer?.cancel();
    _connectionTimeoutTimer = null;
  }

  /// Answer an incoming call
  Future<bool> answerCall(CallEntity call) async {
    if (state.isEnding) {
      debugPrint('CurrentCallNotifier: answerCall ignoré - fin en cours');
      return false;
    }
    // L'acceptation arrive par DEUX chemins qui peuvent se déclencher tous les
    // deux : le bouton in-app et l'évènement `accepted` de CallKit. L'ancien
    // garde ne rejetait que « un AUTRE appel est en cours », donc une double
    // acceptation du MÊME appel passait et démarrait WebRTC deux fois.
    if (state.call != null &&
        (state.call!.id != call.id || state.isConnecting || state.isConnected)) {
      debugPrint(
        'CurrentCallNotifier: answerCall ignoré - appel ${state.call!.id} '
        'déjà en cours (demandé: ${call.id})',
      );
      return false;
    }

    state = state.copyWith(
      call: call,
      isConnecting: true,
      isRinging: false,
      error: null,
    );

    // Start connection timeout (15 seconds)
    _startConnectionTimeout(call.id);

    final result = await ref.read(callRepositoryProvider).answerCall(call.id);

    return result.fold(
      (failure) {
        _cancelConnectionTimeout();
        state = state.copyWith(isConnecting: false, error: failure.message);
        return false;
      },
      (_) async {
        // Initialize WebRTC as receiver
        await _initializeWebRTC(
          call.id,
          isInitiator: false,
          enableVideo: call.type == CallType.video,
        );

        return true;
      },
    );
  }

  /// Initialize WebRTC connection
  Future<void> _initializeWebRTC(
    String callId, {
    required bool isInitiator,
    required bool enableVideo,
  }) async {
    final webrtc = ref.read(webRTCServiceProvider);

    // Listen to connection state changes
    _connectionStateSubscription?.cancel();
    _connectionStateSubscription = webrtc.connectionStateStream.listen((
      rtcState,
    ) {
      debugPrint('CurrentCallNotifier: WebRTC state changed to: $rtcState');
      switch (rtcState) {
        case WebRTCConnectionState.connected:
          debugPrint('CurrentCallNotifier: Call connected successfully!');
          _onCallConnected();
          break;
        case WebRTCConnectionState.reconnecting:
          debugPrint('CurrentCallNotifier: Call reconnecting...');
          break;
        case WebRTCConnectionState.disconnected:
        case WebRTCConnectionState.failed:
          debugPrint('CurrentCallNotifier: Call disconnected/failed - state: $rtcState');
          _onCallDisconnected();
          break;
        default:
          break;
      }
    });

    // Listen for video upgrade requests from the other party
    _videoUpgradeRequestSubscription?.cancel();
    _videoUpgradeRequestSubscription = webrtc.videoUpgradeRequestStream.listen((
      _,
    ) {
      state = state.copyWith(
        videoUpgradeStatus: VideoUpgradeStatus.pendingApproval,
      );
    });

    // Listen for video upgrade responses to our request
    _videoUpgradeResponseSubscription?.cancel();
    _videoUpgradeResponseSubscription = webrtc.videoUpgradeResponseStream
        .listen((accepted) {
          state = state.copyWith(
            videoUpgradeStatus:
                accepted
                    ? VideoUpgradeStatus.accepted
                    : VideoUpgradeStatus.declined,
            isVideoEnabled: accepted ? true : state.isVideoEnabled,
          );

          // Reset status after a brief delay for declined
          if (!accepted) {
            Future.delayed(const Duration(seconds: 3), () {
              if (state.videoUpgradeStatus == VideoUpgradeStatus.declined) {
                state = state.copyWith(
                  videoUpgradeStatus: VideoUpgradeStatus.none,
                );
              }
            });
          }
        });

    // Listen for network degradation events (automatic video disable on poor network)
    _networkDegradationSubscription?.cancel();
    _networkDegradationSubscription = webrtc.networkDegradationStream.listen((
      event,
    ) {
      _handleNetworkDegradation(event);
    });

    if (enableVideo) {
      state = state.copyWith(isVideoEnabled: true);
    }

    // startCall() relance ses erreurs : micro/caméra refusés, getUserMedia en
    // timeout, StateError « Already in a call ». Ces appels n'étaient gardés
    // nulle part — ni ici, ni chez les appelants (l'évènement CallKit `accepted`
    // lance answerCall() sans await ni catch). L'échec partait donc en
    // exception non capturée et laissait l'utilisateur sur « Connexion… »
    // jusqu'à ce que le timeout de 30 ou 45 s finisse par retomber dessus.
    // On échoue franchement et tout de suite à la place.
    try {
      await webrtc.startCall(
        callId: callId,
        isInitiator: isInitiator,
        enableVideo: enableVideo,
      );
    } catch (e) {
      debugPrint('CurrentCallNotifier: démarrage WebRTC échoué: $e');
      final message = e is TimeoutException
          ? 'Micro ou caméra inaccessible'
          : 'Impossible d\'établir la connexion';
      await endCall(reason: 'webrtc_start_failed');
      // Le motif se pose APRÈS endCall : celui-ci passe par _resetState(), qui
      // remet un CurrentCallState vierge et effacerait l'erreur posée avant.
      state = state.copyWith(error: message, errorCode: 'webrtc_start_failed');
      return;
    }

    // Initialize audio route:
    // - Video calls: speaker ON (so both can see and hear clearly)
    // - Audio calls: earpiece (prevents Larsen effect when devices are close)
    final useSpeaker = enableVideo;
    try {
      await webrtc.setSpeakerEnabled(useSpeaker);
      state = state.copyWith(isSpeakerOn: useSpeaker);
    } catch (e) {
      // Le routage audio est un confort : son échec ne doit pas couper l'appel.
      debugPrint('CurrentCallNotifier: routage audio échoué: $e');
    }
  }

  /// Called when WebRTC connection is established
  void _onCallConnected() {
    // Cancel any pending timeouts
    _cancelRingingTimeout();
    _cancelConnectionTimeout();

    _callStartTime = DateTime.now();
    _startDurationTimer();

    // Update call status to connected
    if (state.call != null) {
      ref
          .read(callRepositoryProvider)
          .updateCallStatus(state.call!.id, CallStatus.connected);

      // Start heartbeat mechanism
      _startHeartbeat();
    }

    // Update native call UI to connected state
    ref.read(nativeCallServiceProvider).setCallConnected();

    state = state.copyWith(
      isConnecting: false,
      isConnected: true,
      isRinging: false,
    );
  }

  /// Start heartbeat mechanism to detect remote party disconnection
  void _startHeartbeat() {
    final call = state.call;
    if (call == null) return;

    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser == null) return;

    final repository = ref.read(callRepositoryProvider);

    // Determine remote user ID
    final remoteUserId = call.callerId == currentUser.id
        ? call.calleeId
        : call.callerId;

    debugPrint('CurrentCallNotifier: Starting heartbeat - myId: ${currentUser.id}, remoteId: $remoteUserId');

    // Send heartbeat immediately
    repository.sendHeartbeat(call.id, currentUser.id);
    _lastRemoteHeartbeat = DateTime.now(); // Assume remote is alive initially
    debugPrint('CurrentCallNotifier: Initial heartbeat sent, assuming remote alive');

    // Send heartbeat every 5 seconds
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      if (state.call != null && state.isConnected) {
        debugPrint('CurrentCallNotifier: Sending heartbeat...');
        repository.sendHeartbeat(call.id, currentUser.id);
        _checkRemoteHeartbeat();
      }
    });

    // Watch remote heartbeat
    _remoteHeartbeatSubscription?.cancel();
    _remoteHeartbeatSubscription = repository
        .watchRemoteHeartbeat(call.id, remoteUserId)
        .listen((result) {
      result.fold(
        (failure) => debugPrint('CurrentCallNotifier: Heartbeat watch error: ${failure.message}'),
        (timestamp) {
          if (timestamp != null) {
            debugPrint('CurrentCallNotifier: Received remote heartbeat: $timestamp');
            _lastRemoteHeartbeat = timestamp;
          } else {
            debugPrint('CurrentCallNotifier: Remote heartbeat is null');
          }
        },
      );
    });
  }

  /// Check if remote party is still alive based on last heartbeat
  /// Only times out if BOTH heartbeat and WebRTC indicate a problem
  void _checkRemoteHeartbeat() {
    if (_lastRemoteHeartbeat == null) {
      debugPrint('CurrentCallNotifier: _checkRemoteHeartbeat - lastRemoteHeartbeat is null, skipping');
      return;
    }

    final timeSinceLastHeartbeat = DateTime.now().difference(_lastRemoteHeartbeat!);
    debugPrint('CurrentCallNotifier: _checkRemoteHeartbeat - time since last: ${timeSinceLastHeartbeat.inSeconds}s (timeout: ${_heartbeatTimeout.inSeconds}s)');

    if (timeSinceLastHeartbeat > _heartbeatTimeout) {
      // Before ending, check if WebRTC is still connected
      // If WebRTC is fine, the remote may just have an older app version without heartbeats
      final webrtcService = ref.read(webRTCServiceProvider);
      final webrtcState = webrtcService.connectionState;

      debugPrint('CurrentCallNotifier: Heartbeat timeout - WebRTC state: $webrtcState');

      if (webrtcState == WebRTCConnectionState.connected) {
        // WebRTC is connected, remote is likely using older app without heartbeats
        // Don't end the call, just log a warning
        debugPrint('CurrentCallNotifier: Heartbeat timeout but WebRTC connected - NOT ending call (remote may have older app)');
        return;
      }

      debugPrint('CurrentCallNotifier: Remote party heartbeat timeout (${timeSinceLastHeartbeat.inSeconds}s) AND WebRTC disconnected - ENDING CALL');
      endCall(reason: 'remote_heartbeat_timeout');
    }
  }

  /// Stop heartbeat mechanism
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _remoteHeartbeatSubscription?.cancel();
    _remoteHeartbeatSubscription = null;
    _lastRemoteHeartbeat = null;
  }

  /// Called when WebRTC connection is lost
  void _onCallDisconnected() {
    debugPrint('CurrentCallNotifier: WebRTC disconnected/failed - ending call');
    debugPrint('CurrentCallNotifier: Call state - isConnected: ${state.isConnected}, isConnecting: ${state.isConnecting}, duration: ${state.duration}');
    endCall(reason: 'disconnected');
  }

  /// Start the call duration timer
  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_callStartTime != null && state.isConnected && !state.isEnding) {
        final duration = DateTime.now().difference(_callStartTime!);
        state = state.copyWith(duration: duration);
      }
    });
  }

  /// Handle network degradation events (automatic video disable on poor network)
  void _handleNetworkDegradation(NetworkDegradationEvent event) {
    switch (event.type) {
      case NetworkDegradationType.videoDisabledPoorNetwork:
        state = state.copyWith(
          isVideoDisabledDueToNetwork: true,
          isCameraOff: true,
          networkMessage: event.message,
        );
        // Clear the message after 5 seconds
        _networkMessageTimer?.cancel();
        _networkMessageTimer = Timer(const Duration(seconds: 5), () {
          state = state.copyWith(clearNetworkMessage: true);
        });
        break;

      case NetworkDegradationType.videoReenabledNetworkImproved:
        state = state.copyWith(
          isVideoDisabledDueToNetwork: false,
          isCameraOff: false,
          networkMessage: event.message,
        );
        // Clear the message after 3 seconds
        _networkMessageTimer?.cancel();
        _networkMessageTimer = Timer(const Duration(seconds: 3), () {
          state = state.copyWith(clearNetworkMessage: true);
        });
        break;

      case NetworkDegradationType.networkQualityWarning:
        state = state.copyWith(networkMessage: event.message);
        // Clear the warning after 4 seconds
        _networkMessageTimer?.cancel();
        _networkMessageTimer = Timer(const Duration(seconds: 4), () {
          state = state.copyWith(clearNetworkMessage: true);
        });
        break;

      case NetworkDegradationType.connectionLost:
        state = state.copyWith(networkMessage: event.message);
        break;

      case NetworkDegradationType.connectionRestored:
        state = state.copyWith(networkMessage: event.message);
        _networkMessageTimer?.cancel();
        _networkMessageTimer = Timer(const Duration(seconds: 3), () {
          state = state.copyWith(clearNetworkMessage: true);
        });
        break;
    }
  }

  /// Force re-enable video after automatic network disable (user override)
  void forceReenableVideo() {
    final webrtc = ref.read(webRTCServiceProvider);
    webrtc.forceReenableVideo();
    state = state.copyWith(
      isVideoDisabledDueToNetwork: false,
      isCameraOff: false,
      clearNetworkMessage: true,
    );
  }

  /// Refuse un appel entrant.
  ///
  /// Même ordre que [endCall] : on coupe l'UI native et on libère l'état
  /// AVANT le réseau, pour qu'un Firestore lent ne laisse pas la bannière
  /// CallKit sonner après que l'utilisateur a refusé.
  Future<bool> declineCall(String callId) async {
    if (state.isEnding) {
      debugPrint('CurrentCallNotifier: declineCall ignoré - fin déjà en cours');
      return false;
    }

    final call = state.call;
    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    final repository = ref.read(callRepositoryProvider);
    final messageService = ref.read(callMessageServiceProvider);
    final nativeCallService = ref.read(nativeCallServiceProvider);

    state = state.copyWith(isEnding: true);

    // 1. Libération locale — ne doit jamais dépendre du réseau.
    await _closeNativeCallUi(nativeCallService);
    _resetState();

    // 2. Bookkeeping distant — best effort et borné dans le temps.
    final declined = await _guardRemote(
      'declineCall',
      () => repository.declineCall(callId),
    );

    if (call != null && currentUser != null) {
      await _guardRemote(
        'createCallMessage(declined)',
        () => messageService.createCallMessage(
          callId: call.id,
          callerId: call.callerId,
          callerName: call.callerName,
          calleeId: call.calleeId,
          calleeName: call.calleeName,
          callType: call.type == CallType.video ? 'video' : 'audio',
          callStatus: 'declined',
          callDuration: null,
          currentUserId: currentUser.id,
          currentUserName: currentUser.displayName ?? 'Utilisateur',
        ),
      );
    }

    return declined;
  }

  /// Termine l'appel en cours.
  ///
  /// L'ORDRE des opérations est le cœur du correctif « appel fantôme ».
  /// Auparavant tout le travail distant (Firestore + message de conversation)
  /// était fait AVANT `_resetState()`, alors que `isEnding` était déjà posé et
  /// que le garde de réentrance rejetait tout nouvel appel. Si une écriture
  /// traînait ou échouait — réseau coupé, Firestore injoignable — la méthode
  /// n'atteignait jamais `_resetState()` : l'écran d'appel restait ouvert
  /// indéfiniment et plus aucun raccrochage n'était possible.
  ///
  /// Désormais : on libère WebRTC, l'UI native et l'état local d'abord, puis
  /// on archive l'appel en best effort.
  Future<void> endCall({String? reason}) async {
    final call = state.call;
    if (state.isEnding || call == null) {
      debugPrint('CurrentCallNotifier: endCall ignoré - isEnding=${state.isEnding}, call=${state.call?.id}');
      return;
    }

    final duration = state.duration;
    final wasRinging = state.isRinging;
    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    final repository = ref.read(callRepositoryProvider);
    final messageService = ref.read(callMessageServiceProvider);
    final nativeCallService = ref.read(nativeCallServiceProvider);
    final webrtc = ref.read(webRTCServiceProvider);

    // Statut à archiver, calculé tant que l'état est encore intact.
    final String callStatus;
    if (reason == 'missed' || reason == 'no_answer') {
      callStatus = 'missed';
    } else if (wasRinging && (duration == null || duration.inSeconds == 0)) {
      // Fin pendant la sonnerie : annulé si c'est l'appelant qui raccroche,
      // manqué si c'est l'appelé.
      callStatus = (currentUser != null && call.callerId == currentUser.id)
          ? 'cancelled'
          : 'missed';
    } else {
      callStatus = 'ended';
    }

    state = state.copyWith(isEnding: true);

    // 1. Libération locale.
    _cancelAllTimers();
    try {
      await webrtc.hangUp();
    } catch (e) {
      debugPrint('CurrentCallNotifier: hangUp a échoué: $e');
    }
    await _closeNativeCallUi(nativeCallService);
    _resetState();

    // 2. Bookkeeping distant — best effort.
    await _guardRemote(
      'endCall',
      () => repository.endCall(call.id, reason: reason ?? 'completed'),
    );

    if (currentUser != null) {
      await _guardRemote(
        'createCallMessage($callStatus)',
        () => messageService.createCallMessage(
          callId: call.id,
          callerId: call.callerId,
          callerName: call.callerName,
          calleeId: call.calleeId,
          calleeName: call.calleeName,
          callType: call.type == CallType.video ? 'video' : 'audio',
          callStatus: callStatus,
          callDuration: duration?.inSeconds,
          currentUserId: currentUser.id,
          currentUserName: currentUser.displayName ?? 'Utilisateur',
        ),
      );
    }
  }

  /// Ferme l'UI d'appel native sans jamais propager d'erreur : c'est une
  /// étape de libération, elle ne doit pas empêcher la suite.
  Future<void> _closeNativeCallUi(NativeCallService service) async {
    try {
      await service.endCall();
    } catch (e) {
      debugPrint('CurrentCallNotifier: fermeture de l\'UI native échouée: $e');
    }
  }

  /// Exécute une écriture distante de fin d'appel en best effort : bornée dans
  /// le temps et sans propagation d'erreur, pour qu'aucune latence réseau ne
  /// puisse bloquer la libération de l'appel.
  /// Renvoie false si l'écriture a échoué (exception, timeout, ou [Failure]
  /// renvoyée par le repository).
  Future<bool> _guardRemote(String label, Future<Object?> Function() op) async {
    try {
      final result = await op().timeout(_remoteBookkeepingTimeout);
      if (result is Either) {
        return result.fold(
          (failure) {
            debugPrint('CurrentCallNotifier: $label a échoué: $failure');
            return false;
          },
          (_) => true,
        );
      }
      return true;
    } catch (e) {
      debugPrint('CurrentCallNotifier: $label a échoué (ignoré): $e');
      return false;
    }
  }

  /// Toggle microphone mute
  void toggleMute() {
    final webrtc = ref.read(webRTCServiceProvider);
    webrtc.toggleMute();
    state = state.copyWith(isMuted: webrtc.isMuted);
  }

  /// Toggle camera on/off
  void toggleCamera() {
    final webrtc = ref.read(webRTCServiceProvider);
    webrtc.toggleCamera();
    state = state.copyWith(isCameraOff: webrtc.isCameraOff);
  }

  /// Toggle speaker - changes actual audio output route
  /// Using earpiece prevents Larsen effect when devices are close
  Future<void> toggleSpeaker() async {
    final webrtc = ref.read(webRTCServiceProvider);
    await webrtc.toggleSpeaker();
    state = state.copyWith(isSpeakerOn: webrtc.isSpeakerOn);
  }

  /// Toggle hold/resume
  void toggleHold() {
    final webrtc = ref.read(webRTCServiceProvider);
    webrtc.toggleHold();
    state = state.copyWith(isOnHold: webrtc.isOnHold);
  }

  /// Switch camera (front/back)
  Future<void> switchCamera() async {
    final webrtc = ref.read(webRTCServiceProvider);
    await webrtc.switchCamera();
  }

  /// Request to upgrade from audio to video call
  Future<void> requestVideoUpgrade() async {
    final webrtc = ref.read(webRTCServiceProvider);
    state = state.copyWith(videoUpgradeStatus: VideoUpgradeStatus.requesting);
    await webrtc.requestVideoUpgrade();
  }

  /// Respond to a video upgrade request from the other party
  Future<void> respondToVideoUpgrade(bool accepted) async {
    final webrtc = ref.read(webRTCServiceProvider);
    await webrtc.respondToVideoUpgrade(accepted);
    state = state.copyWith(
      videoUpgradeStatus: VideoUpgradeStatus.none,
      isVideoEnabled: accepted ? true : state.isVideoEnabled,
    );
  }

  /// Convert the current 1:1 call to a group call with additional participants
  ///
  /// [additionalParticipantIds] - List of user IDs to add to the call
  /// Returns the created GroupCallEntity, or null if conversion failed
  Future<GroupCallEntity?> convertToGroupCall(
    List<String> additionalParticipantIds,
  ) async {
    final call = state.call;
    if (call == null) {
      debugPrint('CurrentCallNotifier: Cannot convert - no active call');
      return null;
    }

    if (!state.isConnected) {
      debugPrint('CurrentCallNotifier: Cannot convert - call not connected');
      return null;
    }

    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser == null) {
      debugPrint('CurrentCallNotifier: Cannot convert - no current user');
      return null;
    }

    try {
      debugPrint(
        'CurrentCallNotifier: Converting call ${call.id} to group call with ${additionalParticipantIds.length} additional participants',
      );

      // Get the WebRTC service to access the existing local stream
      final webrtc = ref.read(webRTCServiceProvider);
      final existingLocalStream = webrtc.localStream;

      if (existingLocalStream == null) {
        debugPrint('CurrentCallNotifier: Cannot convert - no local stream');
        return null;
      }

      // Create group call via the group call provider
      final groupCallNotifier = ref.read(currentGroupCallProvider.notifier);
      final groupCall = await groupCallNotifier.createFromOneToOneCall(
        originalCall: call,
        additionalParticipantIds: additionalParticipantIds,
        existingLocalStream: existingLocalStream,
      );

      if (groupCall == null) {
        debugPrint('CurrentCallNotifier: Failed to create group call');
        return null;
      }

      // Mark the 1:1 call as converted
      final datasource = ref.read(callRemoteDataSourceProvider);
      await datasource.markAsConvertedToGroup(call.id, groupCall.id);

      // Send transition signal to the other participant
      await datasource.sendTransitionSignal(call.id, groupCall.id);

      debugPrint(
        'CurrentCallNotifier: Successfully converted to group call ${groupCall.id}',
      );

      // Nettoie l'état de l'appel 1-à-1 sans toucher à WebRTC (le flux local
      // est réutilisé par l'appel de groupe). _resetState fait exactement ça :
      // timers + souscriptions + heartbeat, sans hangUp.
      _resetState();

      return groupCall;
    } catch (e) {
      debugPrint('CurrentCallNotifier: Error converting to group call: $e');
      return null;
    }
  }

  /// Annule tous les timers de l'appel en cours.
  ///
  /// Regroupés ici parce que chaque chemin de sortie (raccrochage, refus,
  /// conversion en appel de groupe) doit les couper TOUS. Les oublis passés
  /// laissaient le timer de sonnerie ou celui de durée survivre à la fin de
  /// l'appel et retomber sur l'appel suivant.
  void _cancelAllTimers() {
    _durationTimer?.cancel();
    _durationTimer = null;
    _networkMessageTimer?.cancel();
    _networkMessageTimer = null;
    _cancelRingingTimeout();
    _cancelConnectionTimeout();
  }

  /// Reset state
  void _resetState() {
    _callStartTime = null;
    _cancelAllTimers();
    // La souscription à l'état WebRTC doit mourir avec l'appel : sinon un
    // évènement `disconnected` tardif rappelait endCall() sur l'appel SUIVANT.
    _connectionStateSubscription?.cancel();
    _connectionStateSubscription = null;
    _videoUpgradeRequestSubscription?.cancel();
    _videoUpgradeRequestSubscription = null;
    _videoUpgradeResponseSubscription?.cancel();
    _videoUpgradeResponseSubscription = null;
    _networkDegradationSubscription?.cancel();
    _networkDegradationSubscription = null;
    _stopHeartbeat();
    state = const CurrentCallState();
  }
}

/// Provider to check if there's an incoming call
final incomingCallProvider = Provider<CallEntity?>((ref) {
  final activeCallAsync = ref.watch(activeCallProvider);
  final currentUser = ref.watch(currentUserProvider).valueOrNull;
  final currentCallState = ref.watch(currentCallProvider);

  // Don't show incoming call if we're already in a call
  if (currentCallState.call != null) return null;

  final activeCall = activeCallAsync.valueOrNull;
  if (activeCall == null || currentUser == null) return null;

  // Check if we're the callee and call is ringing
  if (activeCall.calleeId == currentUser.id &&
      activeCall.status == CallStatus.ringing) {
    return activeCall;
  }

  return null;
});

/// Provider for call notification handler
final callNotificationHandlerProvider =
    NotifierProvider<CallNotificationHandler, void>(
      CallNotificationHandler.new,
    );

/// Provider for call notifications handling
class CallNotificationHandler extends Notifier<void> {
  StreamSubscription<NativeCallEventData>? _nativeCallSubscription;

  @override
  void build() {
    // Register notification callbacks for incoming calls
    _registerNotificationCallbacks();

    // Listen for native call events (from CallKit/ConnectionService)
    _listenToNativeCallEvents();

    // Check for pending calls when app starts (handles case where user
    // accepted call from native UI while app was killed/background)
    _checkPendingCallsOnStart();

    // Listen for incoming calls and show native call UI
    ref.listen<CallEntity?>(incomingCallProvider, (previous, next) {
      if (next != null && previous == null) {
        // New incoming call - show native call UI
        _handleIncomingCall(next);
      } else if (next == null && previous != null) {
        // Call ended - hide native call UI
        _hideNativeCallUI();
      }
    });

    ref.onDispose(() {
      _nativeCallSubscription?.cancel();
    });
  }

  /// Check for pending calls when app starts
  /// Handles case where user accepted call from native UI while app was killed
  Future<void> _checkPendingCallsOnStart() async {
    try {
      final nativeService = ref.read(nativeCallServiceProvider);
      final activeCalls = await nativeService.getActiveCalls();

      if (activeCalls.isNotEmpty) {
        debugPrint('CallNotificationHandler: Found ${activeCalls.length} active calls on start');

        for (final call in activeCalls) {
          if (call is Map) {
            final callId = call['extra']?['callId'] as String? ??
                           call['id'] as String? ?? '';
            final isAccepted = call['isAccepted'] == true;

            if (callId.isNotEmpty && isAccepted) {
              debugPrint('CallNotificationHandler: Auto-answering pending call: $callId');
              await _answerCallFromBackground(callId);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('CallNotificationHandler: Error checking pending calls: $e');
    }
  }

  /// Listen to events from native call UI (user actions on lock screen)
  void _listenToNativeCallEvents() {
    final nativeService = ref.read(nativeCallServiceProvider);
    _nativeCallSubscription?.cancel();
    _nativeCallSubscription = nativeService.eventStream.listen((event) {
      _handleNativeCallEvent(event);
    });
  }

  /// Handle events from native call UI
  void _handleNativeCallEvent(NativeCallEventData event) {
    final incomingCall = ref.read(incomingCallProvider);
    final currentCallState = ref.read(currentCallProvider);

    switch (event.event) {
      case NativeCallEvent.accepted:
        // User accepted call from native UI
        if (incomingCall != null) {
          ref.read(currentCallProvider.notifier).answerCall(incomingCall);
        } else {
          // App was in background - fetch call from repository using callId
          final callId = event.callId;
          if (callId.isNotEmpty) {
            _answerCallFromBackground(callId);
          }
        }
        break;

      case NativeCallEvent.declined:
        // User declined call from native UI
        if (incomingCall != null) {
          ref.read(currentCallProvider.notifier).declineCall(incomingCall.id);
        } else {
          // App was in background - decline using callId
          final callId = event.callId;
          if (callId.isNotEmpty) {
            ref.read(currentCallProvider.notifier).declineCall(callId);
          }
        }
        break;

      case NativeCallEvent.ended:
        // User ended call from native UI
        if (currentCallState.call != null) {
          ref.read(currentCallProvider.notifier).endCall(reason: 'user_ended');
        }
        break;

      case NativeCallEvent.timeout:
        // Call timed out (not answered)
        if (incomingCall != null) {
          ref.read(currentCallProvider.notifier).declineCall(incomingCall.id);
        }
        break;

      case NativeCallEvent.toggleMute:
        // User toggled mute from native UI
        if (currentCallState.call != null) {
          ref.read(currentCallProvider.notifier).toggleMute();
        }
        break;

      case NativeCallEvent.toggleHold:
        // User toggled hold from native UI
        if (currentCallState.call != null) {
          ref.read(currentCallProvider.notifier).toggleHold();
        }
        break;

      default:
        break;
    }
  }

  /// Answer a call from background when incomingCallProvider is not yet loaded
  Future<void> _answerCallFromBackground(String callId) async {
    debugPrint('CallNotificationHandler: Answering call from background: $callId');
    final repository = ref.read(callRepositoryProvider);
    final result = await repository.getCall(callId);

    result.fold(
      (failure) {
        debugPrint('CallNotificationHandler: Failed to get call: $failure');
      },
      (call) {
        if (call == null) {
          debugPrint('CallNotificationHandler: Call not found');
          return;
        }
        // Ne répondre qu'à un appel ENCORE actif ET récent. Sans ce garde, un
        // record d'appel obsolète (terminé/manqué, ou vieux de plusieurs
        // heures) était ré-« answered » à chaque démarrage : l'app relançait
        // WebRTC et prenait le micro pour un appel fantôme.
        const answerable = {
          CallStatus.ringing,
          CallStatus.connecting,
          CallStatus.connected,
          CallStatus.reconnecting,
          CallStatus.onHold,
        };
        final age = DateTime.now().difference(call.createdAt);
        if (!answerable.contains(call.status) ||
            age > const Duration(minutes: 2)) {
          debugPrint(
            'CallNotificationHandler: Ignoring stale call $callId '
            '(status=${call.status}, age=${age.inSeconds}s) + CallKit cleanup',
          );
          // Purge l'entrée CallKit résiduelle pour stopper la récurrence.
          ref.read(nativeCallServiceProvider).endAllCalls();
          return;
        }
        debugPrint('CallNotificationHandler: Found call, answering...');
        ref.read(currentCallProvider.notifier).answerCall(call);
      },
    );
  }

  /// Register callbacks for FCM notifications
  void _registerNotificationCallbacks() {
    final notificationService = NotificationService();

    // Handle incoming call from FCM notification (background/killed state)
    notificationService.setIncomingCallCallback(({
      required String callId,
      required String callerId,
      required String callerName,
      String? callerPhotoUrl,
      required bool isVideo,
    }) {
      // Show native call UI immediately for background calls
      _showNativeCallUI(
        callId: callId,
        callerName: callerName,
        callerPhotoUrl: callerPhotoUrl,
        isVideo: isVideo,
      );

      // Also fetch the call from repository
      _handleIncomingCallFromNotification(
        callId: callId,
        callerId: callerId,
        callerName: callerName,
        callerPhotoUrl: callerPhotoUrl,
        isVideo: isVideo,
      );
    });

    // Handle call status changes from FCM notification
    notificationService.setCallStatusCallback(({
      required String callId,
      required String status,
    }) {
      _handleCallStatusFromNotification(callId: callId, status: status);
    });
  }

  /// Show native call UI (CallKit on iOS, ConnectionService on Android)
  Future<void> _showNativeCallUI({
    required String callId,
    required String callerName,
    String? callerPhotoUrl,
    required bool isVideo,
  }) async {
    final nativeService = ref.read(nativeCallServiceProvider);
    await nativeService.showIncomingCall(
      callId: callId,
      callerName: callerName,
      callerPhotoUrl: callerPhotoUrl,
      isVideo: isVideo,
    );
  }

  /// Hide native call UI
  Future<void> _hideNativeCallUI() async {
    final nativeService = ref.read(nativeCallServiceProvider);
    await nativeService.endCall();
  }

  /// Handle incoming call from FCM notification
  Future<void> _handleIncomingCallFromNotification({
    required String callId,
    required String callerId,
    required String callerName,
    String? callerPhotoUrl,
    required bool isVideo,
  }) async {
    // Fetch the call entity from repository
    final repository = ref.read(callRepositoryProvider);
    final result = await repository.getCall(callId);

    result.fold(
      (failure) {
        // Call not found or error - ignore
      },
      (call) {
        if (call != null && call.status == CallStatus.ringing) {
          _handleIncomingCall(call);
        }
      },
    );
  }

  /// Handle call status change from FCM notification
  void _handleCallStatusFromNotification({
    required String callId,
    required String status,
  }) {
    final currentCallState = ref.read(currentCallProvider);

    // If we have an active call with this ID, handle the status change
    if (currentCallState.call?.id == callId) {
      if (status == 'declined' || status == 'missed') {
        // End our call UI
        ref.read(currentCallProvider.notifier).endCall(reason: status);
      }
    }

    // Also hide native call UI
    if (status == 'declined' || status == 'missed' || status == 'ended') {
      _hideNativeCallUI();
    }
  }

  void _handleIncomingCall(CallEntity call) {
    // Show native call UI (CallKit on iOS, full-screen notification on Android)
    _showNativeCallUI(
      callId: call.id,
      callerName: call.callerName,
      callerPhotoUrl: call.callerPhotoUrl,
      isVideo: call.type == CallType.video,
    );
  }
}
