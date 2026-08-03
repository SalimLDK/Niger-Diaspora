import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/services/gsm_call_service.dart';
import '../../../../core/services/pip_service.dart';
import '../../../../core/services/proximity_service.dart';
import '../../../../core/services/ringtone_service.dart';
import '../../../../core/services/webrtc_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../features/calls/domain/entities/call_entity.dart';
import '../../../../features/calls/presentation/providers/call_provider.dart';
import '../../../../features/calls/presentation/providers/eligible_participants_provider.dart';
import '../../../../core/utils/wakelock_helper.dart';
import '../../../../features/calls/presentation/widgets/active_call_indicator.dart';
import '../../../../features/calls/presentation/widgets/add_participant_modal.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';

/// Screen for 1:1 audio/video calls
class CallScreen extends ConsumerStatefulWidget {
  final String callId;
  final bool isInitiator;
  final bool isVideo;
  final String? calleeName;
  final String? calleePhotoUrl;
  final bool isCalleeOnline;

  const CallScreen({
    super.key,
    required this.callId,
    required this.isInitiator,
    required this.isVideo,
    this.calleeName,
    this.calleePhotoUrl,
    this.isCalleeOnline = true,
  });

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen>
    with TickerProviderStateMixin {
  final WebRTCService _webrtcService = WebRTCService.instance;
  final RingtoneService _ringtoneService = RingtoneService();
  final ProximityService _proximityService = ProximityService.instance;
  final GsmCallService _gsmCallService = GsmCallService.instance;
  final PipService _pipService = PipService.instance;

  // Use the service's renderer which is already initialized
  bool _localRendererReady = false;

  bool _isEnding = false;
  bool _isDisposing = false; // Flag to prevent camera init during dispose
  bool _ringbackStarted = false;
  StreamSubscription<WebRTCConnectionState>? _connectionSubscription;
  StreamSubscription<GsmCallEvent>? _gsmSubscription;
  Timer? _videoCheckTimer;

  // GSM call handling state
  bool _wasCallPausedByGsm = false;
  bool _wasCameraEnabledBeforeGsm = false;

  // PiP video position (draggable)
  Offset? _pipPosition; // null means not initialized yet
  bool _isDraggingPip = false;
  static const double _pipWidth = 120;
  static const double _pipHeight = 160;

  // PiP improvements: video swap & spring animation
  bool _isLocalVideoFullScreen = false; // Double-tap to swap videos
  AnimationController? _pipSpringController;
  Animation<Offset>? _pipSpringAnimation;

  // Auto-hide controls
  bool _controlsVisible = true;
  Timer? _hideControlsTimer;
  static const Duration _controlsHideDelay = Duration(seconds: 5);

  // System PiP mode state (when app is minimized during video call)
  bool _isInSystemPipMode = false;

  @override
  void initState() {
    super.initState();

    // Initialize PiP spring animation controller
    _pipSpringController = AnimationController(vsync: this);

    // Listen to system PiP mode changes
    _pipService.pipModeNotifier.addListener(_onPipModeChanged);

    debugPrint(
      'CallScreen.initState: isVideo=${widget.isVideo}, callId=${widget.callId}',
    );

    // Mark that we're on the call screen (hides floating indicator)
    // Deferred to avoid modifying provider during widget tree build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(isOnCallScreenProvider.notifier).state = true;
      }
    });

    // Vérifier les permissions avant d'initialiser l'appel
    _checkPermissionsAndInitialize();
  }

  /// Vérifie les permissions micro/caméra avant d'initialiser l'appel
  Future<void> _checkPermissionsAndInitialize() async {
    // Déterminer les permissions requises
    final permissions = <Permission>[Permission.microphone];
    if (widget.isVideo) {
      permissions.add(Permission.camera);
    }

    // Demander les permissions
    final statuses = await permissions.request();

    // Vérifier si toutes les permissions sont accordées
    final allGranted = statuses.values.every((s) => s.isGranted);

    if (!allGranted) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        final deniedPermissions = <String>[];
        if (statuses[Permission.microphone]?.isDenied ?? false) {
          deniedPermissions.add(l10n.callPermissionMicrophone);
        }
        if (statuses[Permission.camera]?.isDenied ?? false) {
          deniedPermissions.add(l10n.callPermissionCamera);
        }

        final denied = deniedPermissions.join(' ${l10n.callPermissionAnd} ');

        final shouldOpenSettings = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder:
              (ctx) => AlertDialog(
                title: Text(l10n.callPermissionRequired),
                content: Text(
                  l10n.callPermissionDenied(denied),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: Text(l10n.cancel),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: Text(l10n.callSettings),
                  ),
                ],
              ),
        );

        if (shouldOpenSettings == true && mounted) {
          await openAppSettings();
        }

        // Fermer l'écran d'appel car les permissions ne sont pas accordées
        if (mounted) {
          Navigator.of(context).pop();
        }
        return;
      }
    }

    // Permissions OK, continuer l'initialisation
    _initializeCall();
  }

  /// Initialise l'appel après vérification des permissions
  void _initializeCall() {
    // Démarrer la tonalité d'attente si on est l'appelant
    if (widget.isInitiator) {
      _ringbackStarted = true;
      _ringtoneService.startRingback();
    }

    // Enable proximity sensor for audio calls (turns off screen when phone is near ear)
    if (!widget.isVideo) {
      _proximityService.enable();
    }

    // Enable PiP (Picture-in-Picture) for all calls (video and audio)
    // When user presses home, the call will continue in a small floating window
    _pipService.setVideoCallActive(active: true, autoPipEnabled: true);

    // Register PiP action callback for custom buttons (Mute, End Call)
    _pipService.onPipAction = _handlePipAction;

    if (widget.isVideo) {
      // Keep screen on during video calls
      WakelockHelper.enable();
    }

    // Attendre que WebRTC initialise son renderer
    _waitForWebRTCInitialization();

    // Listen to WebRTC connection state changes for UI updates
    _connectionSubscription = _webrtcService.connectionStateStream.listen((
      state,
    ) {
      if (!mounted) return;
      debugPrint('CallScreen: WebRTC state changed to $state');

      // Arrêter la tonalité d'attente quand connecté
      if (state == WebRTCConnectionState.connected && _ringbackStarted) {
        _ringbackStarted = false;
        _ringtoneService.stopRingback();
      }

      if (state == WebRTCConnectionState.disconnected ||
          state == WebRTCConnectionState.failed) {
        _endCall();
      }
      // Trigger rebuild for connection status
      setState(() {});
    });

    // Vérifier périodiquement si la vidéo locale est prête et déclencher rebuild
    _videoCheckTimer = Timer.periodic(const Duration(milliseconds: 500), (
      timer,
    ) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      // Déclencher rebuild pour mettre à jour l'UI
      setState(() {});

      // Arrêter le timer une fois que la vidéo est prête
      final hasVideo =
          (_localRendererReady &&
              _webrtcService.localRenderer.srcObject != null) ||
          (_webrtcService.remoteRenderer.srcObject != null);
      if (hasVideo && timer.tick > 5) {
        timer.cancel();
      }

      // Arrêter après 20 secondes maximum
      if (timer.tick > 40) {
        timer.cancel();
      }
    });

    // Écouter les événements d'appels GSM (Android uniquement)
    // pour mettre en pause l'appel VoIP quand un appel téléphonique arrive
    _gsmCallService.startListening();
    _gsmSubscription = _gsmCallService.gsmCallEvents.listen((event) {
      if (!mounted) return;
      debugPrint('CallScreen: GSM event received: $event');

      switch (event) {
        case GsmCallEvent.incoming:
        case GsmCallEvent.active:
          // Mettre en pause l'appel VoIP
          _pauseCallForGsm();
          break;
        case GsmCallEvent.ended:
          // Reprendre l'appel VoIP
          _resumeCallAfterGsm();
          break;
      }
    });
  }

  /// Attendre que WebRTC initialise et assigner le stream au renderer du service
  Future<void> _waitForWebRTCInitialization() async {
    // Skip if already disposing or ending call to prevent camera initialization during cleanup
    if (_isDisposing || _isEnding) {
      debugPrint('CallScreen: Skipping WebRTC init - disposing or ending');
      return;
    }

    try {
      // Attendre que le service WebRTC soit initialisé
      int attempts = 0;
      while (!_webrtcService.isInitialized && attempts < 30) {
        // Check disposal state BEFORE and AFTER each delay
        if (_isDisposing || _isEnding || !mounted) {
          debugPrint('CallScreen: Aborting WebRTC init - call ended');
          return;
        }
        await Future.delayed(const Duration(milliseconds: 100));
        if (_isDisposing || _isEnding || !mounted) {
          debugPrint('CallScreen: Aborting WebRTC init - call ended');
          return;
        }
        attempts++;
      }

      // Final check after waiting
      if (_isDisposing || _isEnding || !mounted) {
        debugPrint('CallScreen: Aborting WebRTC init - call ended');
        return;
      }

      if (_webrtcService.isInitialized) {
        debugPrint('CallScreen: WebRTC service initialized');

        // Attendre que le localStream soit prêt
        attempts = 0;
        while (_webrtcService.localStream == null && attempts < 30) {
          // Check disposal state BEFORE and AFTER each delay
          if (_isDisposing || _isEnding || !mounted) {
            debugPrint('CallScreen: Aborting WebRTC init - call ended');
            return;
          }
          await Future.delayed(const Duration(milliseconds: 100));
          if (_isDisposing || _isEnding || !mounted) {
            debugPrint('CallScreen: Aborting WebRTC init - call ended');
            return;
          }
          attempts++;
        }

        // Final check after waiting
        if (_isDisposing || _isEnding || !mounted) {
          debugPrint('CallScreen: Aborting WebRTC init - call ended');
          return;
        }

        // Utiliser le renderer du service (déjà initialisé)
        // Final check BEFORE any stream assignment to prevent camera init during cleanup
        if (_webrtcService.localStream != null &&
            !_isDisposing && !_isEnding && mounted) {
          debugPrint('CallScreen: Assigning stream to service localRenderer');

          // Assign stream to the pre-initialized renderer from the service
          // This avoids creating a new renderer and the flutter_webrtc bug
          _webrtcService.localRenderer.srcObject = _webrtcService.localStream;
          debugPrint(
            'CallScreen: Stream assigned, textureId=${_webrtcService.localRenderer.textureId}',
          );

          // Force rebuild
          if (mounted && !_isDisposing && !_isEnding) {
            setState(() {
              _localRendererReady = true;
            });
          }
        } else if (_isDisposing || _isEnding) {
          debugPrint('CallScreen: Skipping stream assignment - call ending');
        } else {
          debugPrint('CallScreen: WARNING - No local stream after waiting');
        }
      } else {
        debugPrint(
          'CallScreen: WARNING - WebRTC service not initialized after waiting',
        );
      }
    } catch (e) {
      debugPrint('CallScreen: Error waiting for WebRTC initialization: $e');
    }
  }

  /// Met en pause l'appel VoIP quand un appel GSM arrive
  void _pauseCallForGsm() {
    if (_wasCallPausedByGsm) return; // Déjà en pause

    debugPrint('CallScreen: Pausing VoIP call for GSM call');
    _wasCallPausedByGsm = true;

    final callState = ref.read(currentCallProvider);

    // Sauvegarder l'état de la caméra avant de la désactiver
    _wasCameraEnabledBeforeGsm = !callState.isCameraOff;

    // Couper le micro
    if (!callState.isMuted) {
      ref.read(currentCallProvider.notifier).toggleMute();
    }

    // Désactiver la caméra si elle était activée
    if (_wasCameraEnabledBeforeGsm) {
      ref.read(currentCallProvider.notifier).toggleCamera();
    }

    // Mettre l'appel en attente
    if (!callState.isOnHold) {
      ref.read(currentCallProvider.notifier).toggleHold();
    }
  }

  /// Reprend l'appel VoIP après la fin de l'appel GSM
  void _resumeCallAfterGsm() {
    if (!_wasCallPausedByGsm) return; // N'était pas en pause à cause d'un GSM

    debugPrint('CallScreen: Resuming VoIP call after GSM call');
    _wasCallPausedByGsm = false;

    final callState = ref.read(currentCallProvider);

    // Reprendre l'appel (retirer de l'attente)
    if (callState.isOnHold) {
      ref.read(currentCallProvider.notifier).toggleHold();
    }

    // Réactiver le micro
    if (callState.isMuted) {
      ref.read(currentCallProvider.notifier).toggleMute();
    }

    // Réactiver la caméra si elle était activée avant
    if (_wasCameraEnabledBeforeGsm && callState.isCameraOff) {
      ref.read(currentCallProvider.notifier).toggleCamera();
    }
  }

  String get _formattedDuration {
    final currentCallState = ref.read(currentCallProvider);
    final duration = currentCallState.duration;
    if (duration == null) return '00:00';
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Texte de statut selon l'état de la connexion et le statut en ligne du destinataire
  String _getStatusText(AppLocalizations l10n) {
    final currentCallState = ref.read(currentCallProvider);
    if (currentCallState.isOnHold) {
      return l10n.callOnHold;
    }
    if (currentCallState.isConnected) {
      return _formattedDuration;
    }
    if (!widget.isInitiator) {
      return l10n.callConnecting;
    }
    // Initiateur: si le destinataire n'est pas en ligne, afficher juste "Appel"
    return widget.isCalleeOnline ? l10n.callCalling : l10n.callTitle;
  }

  void _toggleMute() {
    ref.read(currentCallProvider.notifier).toggleMute();
  }

  void _toggleSpeaker() {
    ref.read(currentCallProvider.notifier).toggleSpeaker();
  }

  void _toggleCamera() {
    ref.read(currentCallProvider.notifier).toggleCamera();
  }

  void _switchCamera() {
    ref.read(currentCallProvider.notifier).switchCamera();
  }

  void _toggleHold() {
    ref.read(currentCallProvider.notifier).toggleHold();
  }

  void _requestVideoUpgrade() {
    ref.read(currentCallProvider.notifier).requestVideoUpgrade();
  }

  void _respondToVideoUpgrade(bool accepted) {
    ref.read(currentCallProvider.notifier).respondToVideoUpgrade(accepted);
  }

  /// Affiche une confirmation avant de terminer l'appel
  Future<bool> _showEndCallConfirmation() async {
    final l10n = AppLocalizations.of(context)!;
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          l10n.callHangUp,
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          l10n.callEndConfirmMessage,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l10n.callEndButton),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _endCall() async {
    // Éviter les appels multiples
    if (_isEnding) return;
    _isEnding = true;

    // Arrêter la tonalité d'attente
    if (_ringbackStarted) {
      _ringbackStarted = false;
      _ringtoneService.stopRingback();
    }

    await ref.read(currentCallProvider.notifier).endCall();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  /// Gérer la fin d'appel distante avec feedback utilisateur approprié
  void _handleRemoteEnd(String status) {
    if (_isEnding) return;
    _isEnding = true;

    // Arrêter la tonalité d'attente si en cours
    if (_ringbackStarted) {
      _ringbackStarted = false;
      _ringtoneService.stopRingback();
    }

    // Afficher un message selon le statut
    final l10n = AppLocalizations.of(context)!;
    String message;
    switch (status) {
      case 'declined':
        message = l10n.callDeclinedStatus;
        break;
      case 'missed':
        message = l10n.callNoAnswer;
        break;
      default:
        message = l10n.callEndedStatus;
    }

    // Cleanup WebRTC
    final webrtc = ref.read(webRTCServiceProvider);
    webrtc.hangUp();

    // Afficher un snackbar bref et fermer l'écran
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
          backgroundColor: status == 'declined' ? Colors.orange : Colors.grey[800],
        ),
      );
      Navigator.of(context).pop();
    }
  }

  /// Show modal to add participants to the call (converts to group call)
  void _showAddParticipantModal(CurrentCallState callState) {
    final call = callState.call;
    if (call == null) return;

    // Exclude current participants (caller and callee)
    final excludeIds = [call.callerId, call.calleeId];

    AddParticipantModal.show(
      context: context,
      excludeIds: excludeIds,
      onParticipantsSelected: (participants) {
        if (participants.isNotEmpty) {
          _convertToGroupCall(participants);
        }
      },
    );
  }

  /// Convert the 1:1 call to a group call with the selected participants
  Future<void> _convertToGroupCall(List<EligibleParticipant> participants) async {
    final l10n = AppLocalizations.of(context)!;

    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Text(l10n.convertingToGroupCall),
          ],
        ),
        duration: const Duration(seconds: 10),
      ),
    );

    try {
      // Convert to group call via provider
      final participantIds = participants.map((p) => p.id).toList();
      final groupCall = await ref.read(currentCallProvider.notifier)
          .convertToGroupCall(participantIds);

      if (groupCall != null && mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.callConvertedToGroup),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate to group call screen
        context.pushReplacement(
          '/group-calls/${groupCall.id}',
          extra: {
            'isInitiator': true,
            'isVideo': widget.isVideo,
            'isMigratedFrom1to1': true,
          },
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.conversionFailed),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('CallScreen: Error converting to group call: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.conversionFailed),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    // Set flag to prevent any camera/media initialization during dispose
    _isDisposing = true;

    _connectionSubscription?.cancel();
    _videoCheckTimer?.cancel();
    // Arrêter l'écoute des événements GSM
    _gsmSubscription?.cancel();
    _gsmCallService.stopListening();
    // Arrêter la tonalité d'attente si elle est en cours
    if (_ringbackStarted) {
      _ringtoneService.stopRingback();
    }
    // Disable proximity sensor
    _proximityService.disable();
    // Remove PiP mode listener
    _pipService.pipModeNotifier.removeListener(_onPipModeChanged);
    // Remove PiP action callback
    _pipService.onPipAction = null;
    // Disable PiP mode
    _pipService.setVideoCallActive(active: false);
    // Disable wakelock (screen can turn off again)
    WakelockHelper.disable();
    // Cancel auto-hide timer
    _hideControlsTimer?.cancel();
    // Dispose PiP spring animation controller
    _pipSpringController?.dispose();
    // Mark that we're leaving the call screen (shows floating indicator if call active)
    // Use try-catch as ref may not be accessible during dispose
    try {
      ref.read(isOnCallScreenProvider.notifier).state = false;
    } catch (_) {
      // Widget already disposed, ignore
    }
    // Don't dispose the service renderer - it's managed by WebRTCService
    super.dispose();
  }

  /// Callback when system PiP mode changes
  void _onPipModeChanged() {
    if (!mounted) return;
    final isInPip = _pipService.isInPipMode;
    if (_isInSystemPipMode != isInPip) {
      setState(() {
        _isInSystemPipMode = isInPip;
      });
      debugPrint('CallScreen: System PiP mode changed to $isInPip');
    }
  }

  /// Handle PiP action button clicks (Mute, End Call)
  void _handlePipAction(String action, Map<String, dynamic>? data) {
    if (!mounted) return;
    debugPrint('CallScreen: PiP action received: $action, data: $data');
    switch (action) {
      case 'mute':
        // Toggle mute state
        _toggleMute();
        // Sync mute state with native side
        final callState = ref.read(currentCallProvider);
        _pipService.updateMuteState(callState.isMuted);
        break;
      case 'endCall':
        // End the call
        _endCall();
        break;
    }
  }

  /// Start or reset the timer to hide controls after inactivity
  void _resetHideControlsTimer() {
    _hideControlsTimer?.cancel();
    if (!_controlsVisible) {
      setState(() {
        _controlsVisible = true;
      });
    }
    _hideControlsTimer = Timer(_controlsHideDelay, () {
      if (mounted) {
        setState(() {
          _controlsVisible = false;
        });
      }
    });
  }

  /// Toggle controls visibility on tap
  void _onScreenTap() {
    if (_controlsVisible) {
      // Hide immediately
      _hideControlsTimer?.cancel();
      setState(() {
        _controlsVisible = false;
      });
    } else {
      // Show and start timer
      _resetHideControlsTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch CurrentCallState for reactive UI updates
    final callState = ref.watch(currentCallProvider);

    // If in system PiP mode (Android), show simplified UI
    if (_isInSystemPipMode && widget.isVideo) {
      return _buildSystemPipModeUI(callState);
    }

    // TOUJOURS activer la vidéo si widget.isVideo est true
    // Ne pas dépendre uniquement de callState.isVideoEnabled qui peut être retardé
    final isVideoActive = widget.isVideo || callState.isVideoEnabled;

    // Détecter si on a une vidéo distante active
    final hasRemoteVideo =
        _webrtcService.remoteStream?.getVideoTracks().isNotEmpty ?? false;
    final remoteVideoEnabled =
        _webrtcService.remoteStream?.getVideoTracks().firstOrNull?.enabled ??
        false;
    final showRemoteVideo =
        hasRemoteVideo && remoteVideoEnabled && callState.isConnected;

    // Écouter ce appel spécifique par ID pour détecter les changements de statut
    // Cela inclut les statuts terminaux (ended, declined, missed) que activeCallProvider filtre
    ref.listen<AsyncValue<CallEntity?>>(callByIdProvider(widget.callId), (previous, next) {
      final call = next.valueOrNull;

      if (call == null) {
        // Appel supprimé de Firebase
        debugPrint('CallScreen: Call document deleted');
        _handleRemoteEnd('ended');
        return;
      }

      // Arrêter la tonalité d'attente quand l'appel est connecté
      if ((call.status == CallStatus.connecting ||
              call.status == CallStatus.connected) &&
          _ringbackStarted) {
        _ringbackStarted = false;
        _ringtoneService.stopRingback();
      }

      // Détecter si l'AUTRE partie a terminé l'appel
      if (call.status == CallStatus.ended ||
          call.status == CallStatus.declined ||
          call.status == CallStatus.missed) {
        debugPrint('CallScreen: Remote party ended call: ${call.status}');
        _handleRemoteEnd(call.status.name);
      }
    });

    // Vérifier si la vidéo locale est prête
    final hasLocalVideo =
        _webrtcService.localStream != null &&
        _webrtcService.localStream!.getVideoTracks().isNotEmpty;

    // Auto-hide controls for video calls when connected
    final shouldAutoHideControls = isVideoActive && callState.isConnected;

    // Start auto-hide timer when video call is connected
    if (shouldAutoHideControls &&
        _hideControlsTimer == null &&
        _controlsVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _resetHideControlsTimer();
        }
      });
    }

    // PopScope to prevent accidental back button during call
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // Show confirmation dialog before ending call
        final shouldEnd = await _showEndCallConfirmation();
        if (shouldEnd && mounted) {
          await _endCall();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
        child: GestureDetector(
          onTap: shouldAutoHideControls ? _onScreenTap : null,
          behavior: HitTestBehavior.translucent,
          child: Stack(
            children: [
              // Local video (full screen when no remote video)
              if (isVideoActive && !showRemoteVideo)
                Positioned.fill(
                  child:
                      _localRendererReady &&
                              hasLocalVideo &&
                              !callState.isCameraOff
                          ? RTCVideoView(
                            _webrtcService.localRenderer,
                            mirror: true,
                            // Use Contain instead of Cover to avoid scaling artifacts
                            // Cover can cause pixel corruption on some devices
                            objectFit:
                                RTCVideoViewObjectFit
                                    .RTCVideoViewObjectFitContain,
                            // Use low filter quality to reduce GPU load
                            filterQuality: FilterQuality.low,
                          )
                          : Container(
                            color: Colors.grey[900],
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (!_localRendererReady || !hasLocalVideo)
                                    const CircularProgressIndicator(
                                      color: Colors.white,
                                    )
                                  else
                                    const Icon(
                                      Icons.videocam_off,
                                      color: Colors.white54,
                                      size: 48,
                                    ),
                                  const SizedBox(height: 16),
                                  Builder(
                                    builder: (context) {
                                      final l10n = AppLocalizations.of(context)!;
                                      return Text(
                                        !_localRendererReady || !hasLocalVideo
                                            ? l10n.callCameraInitializing
                                            : l10n.callCameraDisabled,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 14,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                ),

              // Main video (full screen) - shows remote or local based on swap state
              if (isVideoActive && showRemoteVideo)
                Positioned.fill(
                  child: GestureDetector(
                    onDoubleTap: _swapVideos, // Double-tap to swap videos
                    child: Container(
                      color: Colors.black,
                      child: RTCVideoView(
                        _isLocalVideoFullScreen
                            ? _webrtcService.localRenderer
                            : _webrtcService.remoteRenderer,
                        mirror: _isLocalVideoFullScreen, // Mirror only local video
                        // Use Contain to avoid scaling artifacts and pixel corruption
                        objectFit:
                            RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                        // Use low filter quality to reduce GPU load on problematic devices
                        filterQuality: FilterQuality.low,
                      ),
                    ),
                  ),
                ),

              // Audio call UI
              if (!isVideoActive) _buildAudioCallUI(),

              // Local video (picture-in-picture) - draggable
              if (isVideoActive && showRemoteVideo && _localRendererReady)
                _buildDraggablePip(context, callState),

              // Call info (top) - with auto-hide for video calls
              Builder(
                builder: (context) {
                  final l10n = AppLocalizations.of(context)!;
                  return Positioned(
                    top: 16,
                    left: 16,
                    right: isVideoActive ? 150 : 16,
                    child: AnimatedOpacity(
                      opacity:
                          shouldAutoHideControls && !_controlsVisible
                              ? 0.0
                              : 1.0,
                      duration: const Duration(milliseconds: 300),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  widget.calleeName ?? l10n.callTitle,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              // Connection quality indicator
                              if (callState.isConnected)
                                _buildConnectionQualityIndicator(),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            callState.isOnHold
                                ? l10n.callOnHold
                                : _getStatusText(l10n),
                            style: TextStyle(
                              color:
                                  callState.isOnHold
                                      ? Colors.amber
                                      : Colors.white.withValues(alpha: 0.7),
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              // Video upgrade request banner (incoming request from other party)
              if (callState.videoUpgradeStatus ==
                  VideoUpgradeStatus.pendingApproval)
                _buildVideoUpgradeRequestBanner(),

              // Video upgrade status banner (requesting / declined)
              if (callState.videoUpgradeStatus == VideoUpgradeStatus.requesting)
                _buildVideoUpgradeStatusBanner(),
              if (callState.videoUpgradeStatus == VideoUpgradeStatus.declined)
                _buildVideoUpgradeDeclinedBanner(),

              // Network degradation message banner
              if (callState.networkMessage != null)
                _buildNetworkMessageBanner(callState),

              // Add participant button (top left corner) - only when connected
              if (callState.isConnected)
                Positioned(
                  top: 16,
                  left: 16,
                  child: SafeArea(
                    child: _buildAddParticipantButton(callState),
                  ),
                ),

              // Call controls (bottom) - Always visible with modern UI
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildModernCallControls(callState, isVideoActive),
              ),

              // Reconnecting overlay
              if (_webrtcService.connectionState == WebRTCConnectionState.reconnecting)
                _buildReconnectingOverlay(),
            ],
          ),
        ),
      ),
    ),); // Close PopScope
  }

  /// Simplified UI when in system PiP mode (small floating window)
  /// Shows only the video with minimal controls
  Widget _buildSystemPipModeUI(CurrentCallState callState) {
    final hasRemoteVideo =
        _webrtcService.remoteStream?.getVideoTracks().isNotEmpty ?? false;
    final remoteVideoEnabled =
        _webrtcService.remoteStream?.getVideoTracks().firstOrNull?.enabled ??
        false;
    final showRemoteVideo =
        hasRemoteVideo && remoteVideoEnabled && callState.isConnected;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        // Tap anywhere to exit PiP mode and return to full screen
        onTap: () {
          // This will bring the app back to foreground on Android
          // On iOS, we'd need to call a native method
        },
        child: Stack(
          children: [
            // Video feed - show remote video if available, otherwise local
            Positioned.fill(
              child:
                  showRemoteVideo
                      ? RTCVideoView(
                        _webrtcService.remoteRenderer,
                        objectFit:
                            RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                        filterQuality: FilterQuality.low,
                      )
                      : (_localRendererReady && !callState.isCameraOff
                          ? RTCVideoView(
                            _webrtcService.localRenderer,
                            mirror: true,
                            objectFit:
                                RTCVideoViewObjectFit
                                    .RTCVideoViewObjectFitCover,
                            filterQuality: FilterQuality.low,
                          )
                          : Container(
                            color: Colors.grey[900],
                            child: Center(
                              child: CircleAvatar(
                                radius: 30,
                                backgroundColor: Colors.grey[800],
                                backgroundImage:
                                    widget.calleePhotoUrl != null
                                        ? NetworkImage(widget.calleePhotoUrl!)
                                        : null,
                                child:
                                    widget.calleePhotoUrl == null
                                        ? const AppIcon(AppIcon.person,
                                          size: 30,
                                          color: Colors.white54,
                                        )
                                        : null,
                              ),
                            ),
                          )),
            ),

            // Minimal overlay with call duration
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Call duration badge
                  if (callState.isConnected)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _formattedDuration,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  // End call button (small, for PiP mode)
                  GestureDetector(
                    onTap: _endCall,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.call_end,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Mute indicator
            if (callState.isMuted)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.mic_off,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Draggable PiP (Picture-in-Picture) local video view
  /// Swap local and remote video (double-tap feature)
  void _swapVideos() {
    HapticFeedback.mediumImpact();
    setState(() {
      _isLocalVideoFullScreen = !_isLocalVideoFullScreen;
    });
  }

  /// Animate PiP snap to edge with spring physics
  void _animatePipToEdge(Offset from, Offset to) {
    _pipSpringAnimation = Tween<Offset>(
      begin: from,
      end: to,
    ).animate(
      CurvedAnimation(
        parent: _pipSpringController!,
        curve: Curves.elasticOut,
      ),
    );

    _pipSpringController!.duration = const Duration(milliseconds: 500);
    _pipSpringAnimation!.addListener(() {
      if (mounted) {
        setState(() {
          _pipPosition = _pipSpringAnimation!.value;
        });
      }
    });

    _pipSpringController!.forward(from: 0);
    HapticFeedback.lightImpact();
  }

  /// Draggable PiP (Picture-in-Picture) local video view with improvements
  Widget _buildDraggablePip(BuildContext context, CurrentCallState callState) {
    final screenSize = MediaQuery.of(context).size;
    final safeArea = MediaQuery.of(context).padding;

    // Calculate bounds for PiP movement
    const minX = 8.0;
    final maxX = screenSize.width - _pipWidth - 8;
    final minY = safeArea.top + 8;
    final maxY =
        screenSize.height -
        _pipHeight -
        safeArea.bottom -
        100; // Leave space for controls

    // Initialize position to top-right
    final currentPosition = _pipPosition ?? Offset(maxX, minY);
    if (_pipPosition == null) {
      // Schedule the update for next frame to avoid setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _pipPosition = Offset(maxX, minY);
          });
        }
      });
    }

    // Determine which video to show in PiP (swapped or not)
    final showLocalInPip = !_isLocalVideoFullScreen;
    final renderer = showLocalInPip
        ? _webrtcService.localRenderer
        : _webrtcService.remoteRenderer;
    final isMirrored = showLocalInPip; // Only mirror local video

    return Positioned(
      left: currentPosition.dx,
      top: currentPosition.dy,
      width: _pipWidth,
      height: _pipHeight,
      child: GestureDetector(
        // Double-tap to swap local/remote videos
        onDoubleTap: _swapVideos,
        onPanStart: (_) {
          _pipSpringController?.stop();
          setState(() {
            _isDraggingPip = true;
          });
        },
        onPanUpdate: (details) {
          setState(() {
            // Update position with bounds checking
            final pos = _pipPosition ?? currentPosition;
            double newX = pos.dx + details.delta.dx;
            double newY = pos.dy + details.delta.dy;

            // Clamp to screen bounds
            newX = newX.clamp(minX, maxX);
            newY = newY.clamp(minY, maxY);

            _pipPosition = Offset(newX, newY);
          });
        },
        onPanEnd: (details) {
          _isDraggingPip = false;
          final pos = _pipPosition ?? currentPosition;

          // Snap to nearest edge (left or right) with spring animation
          final centerX = pos.dx + _pipWidth / 2;
          final screenCenterX = screenSize.width / 2;

          final targetX = centerX < screenCenterX ? minX : maxX;
          final targetPosition = Offset(targetX, pos.dy);

          // Use spring animation for smooth snap
          _animatePipToEdge(pos, targetPosition);
        },
        child: AnimatedScale(
          scale: _isDraggingPip ? 1.08 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    _isDraggingPip
                        ? Colors.white.withValues(alpha: 0.6)
                        : Colors.white.withValues(alpha: 0.3),
                width: _isDraggingPip ? 3 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: _isDraggingPip ? 0.5 : 0.3,
                  ),
                  blurRadius: _isDraggingPip ? 12 : 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                children: [
                  // Video content
                  Positioned.fill(
                    child: callState.isCameraOff && showLocalInPip
                        ? const Center(
                            child: Icon(
                              Icons.videocam_off,
                              color: Colors.white54,
                              size: 32,
                            ),
                          )
                        : RTCVideoView(
                            renderer,
                            mirror: isMirrored,
                            objectFit:
                                RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                            filterQuality: FilterQuality.low,
                          ),
                  ),
                  // Mute indicator badge (bottom-left)
                  if (callState.isMuted)
                    Positioned(
                      bottom: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const AppIcon(
                          AppIcon.micOff,
                          color: Colors.red,
                          size: 14,
                        ),
                      ),
                    ),
                  // Swap hint indicator (shows briefly on first load)
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.swap_horiz_rounded,
                        color: Colors.white70,
                        size: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Banner shown when the other party requests a video upgrade
  Widget _buildVideoUpgradeRequestBanner() {
    final l10n = AppLocalizations.of(context)!;
    return Positioned(
      top: 80,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[900]!.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blue.withValues(alpha: 0.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const AppIcon(AppIcon.video, color: Colors.blue, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.videoUpgradeRequest(widget.calleeName ?? ''),
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _respondToVideoUpgrade(false),
                  child: Text(
                    l10n.callDecline,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _respondToVideoUpgrade(true),
                  icon: const AppIcon(AppIcon.video, color: Colors.white54, size: 18),
                  label: Text(l10n.callAccept),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Banner shown while waiting for the other party to accept video upgrade
  Widget _buildVideoUpgradeStatusBanner() {
    final l10n = AppLocalizations.of(context)!;
    return Positioned(
      top: 80,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[900]!.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.videoUpgradeWaiting,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Banner shown when video upgrade was declined
  Widget _buildVideoUpgradeDeclinedBanner() {
    final l10n = AppLocalizations.of(context)!;
    return Positioned(
      top: 80,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red[900]!.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.videocam_off, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.videoUpgradeDeclined,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Overlay shown when WebRTC is reconnecting
  Widget _buildReconnectingOverlay() {
    final l10n = AppLocalizations.of(context)!;
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.7),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                color: Colors.orange,
                strokeWidth: 3,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.callReconnectingStatus,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.callPleaseWait,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Banner shown for network degradation messages (Sahel context)
  Widget _buildNetworkMessageBanner(CurrentCallState callState) {
    final isVideoDisabled = callState.isVideoDisabledDueToNetwork;
    final backgroundColor =
        isVideoDisabled
            ? Colors.orange[800]!.withValues(alpha: 0.95)
            : Colors.blue[800]!.withValues(alpha: 0.9);
    final icon =
        isVideoDisabled
            ? Icons.signal_cellular_connected_no_internet_4_bar
            : Icons.signal_cellular_alt;

    return Positioned(
      top: 80,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                callState.networkMessage!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            // Show button to re-enable video if it was disabled due to network
            if (isVideoDisabled)
              Builder(
                builder: (context) {
                  final l10n = AppLocalizations.of(context)!;
                  return TextButton(
                    onPressed: () {
                      ref.read(currentCallProvider.notifier).forceReenableVideo();
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                    ),
                    child: Text(
                      l10n.callReenableButton,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioCallUI() {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Avatar
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[800],
              image:
                  widget.calleePhotoUrl != null
                      ? DecorationImage(
                        image: NetworkImage(widget.calleePhotoUrl!),
                        fit: BoxFit.cover,
                      )
                      : null,
            ),
            child:
                widget.calleePhotoUrl == null
                    ? const AppIcon(AppIcon.person, size: 60, color: Colors.white54)
                    : null,
          ),
          const SizedBox(height: 24),
          // Nom de l'interlocuteur en serif (§23a). Le blanc reste : cet
          // écran se peint sur le flux vidéo ou un fond sombre, ce n'est
          // pas une couleur figée par oubli mais le seul contraste tenable.
          Text(
            widget.calleeName ?? l10n.callTitle,
            style: GoogleFonts.playfairDisplay(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _getStatusText(l10n),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  /// Barre de contrôles (§12) : quatre contrôles nommés de 64 px sur une
  /// rangée, puis « Raccrocher » pleine largeur — le libellé sous chaque
  /// icône lève l'ambiguïté du pictogramme seul.
  Widget _buildModernCallControls(CurrentCallState callState, bool isVideoActive) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
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
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 40, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _buildNamedControls(callState, isVideoActive, l10n),
              ),
              const SizedBox(height: 20),
              _buildFullWidthHangup(l10n),
            ],
          ),
        ),
      ),
    );
  }

  /// Les quatre contrôles nommés (hors « Raccrocher », désormais séparé).
  List<Widget> _buildNamedControls(
    CurrentCallState callState,
    bool isVideoActive,
    AppLocalizations l10n,
  ) {
    if (isVideoActive) {
      // Retourner | Caméra | Micro | Haut-parleur
      return [
        _buildNamedControl(
          icon: Icons.cameraswitch_rounded,
          label: l10n.callControlFlip,
          isActive: true,
          onPressed: _switchCamera,
        ),
        _buildNamedControl(
          icon: callState.isCameraOff
              ? Icons.videocam_off_rounded
              : Icons.videocam_rounded,
          label: l10n.callControlCamera,
          isActive: !callState.isCameraOff,
          onPressed: _toggleCamera,
        ),
        _buildNamedControl(
          icon: callState.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
          label: callState.isMuted ? l10n.callControlMicOff : l10n.callControlMic,
          isActive: !callState.isMuted,
          onPressed: _toggleMute,
        ),
        _buildNamedControl(
          icon: callState.isSpeakerOn
              ? Icons.volume_up_rounded
              : Icons.volume_off_rounded,
          label: callState.isSpeakerOn
              ? l10n.callControlSpeaker
              : l10n.callControlEarpiece,
          isActive: callState.isSpeakerOn,
          onPressed: _toggleSpeaker,
        ),
      ];
    }
    // Appel audio : Vidéo | Pause | Micro | Haut-parleur
    return [
      if (callState.isConnected)
        _buildNamedControl(
          icon: Icons.videocam_rounded,
          label: l10n.callControlVideo,
          isActive: callState.videoUpgradeStatus == VideoUpgradeStatus.none,
          onPressed: callState.videoUpgradeStatus == VideoUpgradeStatus.none
              ? _requestVideoUpgrade
              : () {},
        )
      else
        const SizedBox(width: 64),
      if (callState.isConnected)
        _buildNamedControl(
          icon: callState.isOnHold
              ? Icons.play_arrow_rounded
              : Icons.pause_rounded,
          label: callState.isOnHold
              ? l10n.callControlResume
              : l10n.callControlHold,
          isActive: !callState.isOnHold,
          onPressed: _toggleHold,
        )
      else
        const SizedBox(width: 64),
      _buildNamedControl(
        icon: callState.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
        label: callState.isMuted ? l10n.callControlMicOff : l10n.callControlMic,
        isActive: !callState.isMuted,
        onPressed: _toggleMute,
      ),
      _buildNamedControl(
        icon: callState.isSpeakerOn
            ? Icons.volume_up_rounded
            : Icons.volume_off_rounded,
        label: callState.isSpeakerOn
            ? l10n.callControlSpeaker
            : l10n.callControlEarpiece,
        isActive: callState.isSpeakerOn,
        onPressed: _toggleSpeaker,
      ),
    ];
  }

  /// Contrôle nommé : pastille 64 px + libellé dessous.
  Widget _buildNamedControl({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: isActive ? 0.22 : 0.12),
            ),
            child: Icon(
              icon,
              color: isActive ? Colors.white : Colors.white60,
              size: 26,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// « Raccrocher » pleine largeur, 68 px.
  Widget _buildFullWidthHangup(AppLocalizations l10n) {
    return SizedBox(
      width: double.infinity,
      height: 68,
      child: ElevatedButton.icon(
        onPressed: _endCall,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(34),
          ),
        ),
        icon: const Icon(Icons.call_end_rounded, size: 26),
        label: Text(
          l10n.hangUp,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  /// Add participant button (top right corner)
  Widget _buildAddParticipantButton(CurrentCallState callState) {
    return GestureDetector(
      onTap: () => _showAddParticipantModal(callState),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.5),
        ),
        child: const AppIcon(
          AppIcon.personAdd,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }

  Widget _buildConnectionQualityIndicator() {
    // Use real quality metrics from WebRTC
    final metrics = _webrtcService.lastQualityMetrics;
    final connectionState = _webrtcService.connectionState;

    Color color;
    int bars;

    if (metrics != null) {
      // Use real metrics to determine quality
      switch (metrics.qualityLevel) {
        case CallQualityLevel.excellent:
          color = Colors.green;
          bars = 4;
        case CallQualityLevel.good:
          color = Colors.green;
          bars = 3;
        case CallQualityLevel.fair:
          color = Colors.amber;
          bars = 2;
        case CallQualityLevel.poor:
          color = Colors.red;
          bars = 1;
        case CallQualityLevel.unknown:
          color = Colors.grey;
          bars = 2;
      }
    } else {
      // Fallback to connection state if no metrics yet
      switch (connectionState) {
        case WebRTCConnectionState.connected:
          color = Colors.green;
          bars = 3;
        case WebRTCConnectionState.connecting:
        case WebRTCConnectionState.reconnecting:
          color = Colors.amber;
          bars = 2;
        case WebRTCConnectionState.disconnected:
          color = Colors.red;
          bars = 1;
        default:
          color = Colors.grey;
          bars = 0;
      }
    }

    return GestureDetector(
      onTap: () => _showQualityDetails(metrics),
      child: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(4, (index) {
            final barHeight = 4.0 + (index * 3);
            return Container(
              width: 3,
              height: barHeight,
              margin: const EdgeInsets.only(right: 2),
              decoration: BoxDecoration(
                color:
                    index < bars ? color : Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(1.5),
              ),
            );
          }),
        ),
      ),
    );
  }

  /// Show quality details in a popup
  void _showQualityDetails(CallQualityMetrics? metrics) {
    if (metrics == null) return;

    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.grey[900],
            title: Row(
              children: [
                const Icon(Icons.signal_cellular_alt, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  l10n.callConnectionQuality,
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMetricRow(
                  l10n.callLatency,
                  metrics.roundTripTimeMs != null
                      ? '${metrics.roundTripTimeMs!.toStringAsFixed(0)} ms'
                      : '-',
                  _getLatencyColor(metrics.roundTripTimeMs),
                ),
                _buildMetricRow(
                  l10n.callPacketLoss,
                  metrics.packetLossPercent != null
                      ? '${metrics.packetLossPercent!.toStringAsFixed(1)}%'
                      : '-',
                  _getPacketLossColor(metrics.packetLossPercent),
                ),
                _buildMetricRow(
                  l10n.callJitter,
                  metrics.jitterMs != null
                      ? '${metrics.jitterMs!.toStringAsFixed(0)} ms'
                      : '-',
                  _getJitterColor(metrics.jitterMs),
                ),
                if (metrics.availableBandwidthKbps != null)
                  _buildMetricRow(
                    l10n.callBandwidth,
                    '${metrics.availableBandwidthKbps} kbps',
                    Colors.white70,
                  ),
                const Divider(color: Colors.white24),
                if (metrics.audioCodec != null)
                  _buildMetricRow(
                    l10n.callAudioCodec,
                    metrics.audioCodec!,
                    Colors.white70,
                  ),
                if (metrics.videoCodec != null)
                  _buildMetricRow(
                    l10n.callVideoCodec,
                    metrics.videoCodec!,
                    Colors.white70,
                  ),
                if (metrics.frameRate != null && metrics.frameWidth != null)
                  _buildMetricRow(
                    l10n.callVideoLabel,
                    '${metrics.frameWidth}x${metrics.frameHeight} @ ${metrics.frameRate} fps',
                    Colors.white70,
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.callCloseButton),
              ),
            ],
          ),
    );
  }

  Widget _buildMetricRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          Text(
            value,
            style: TextStyle(color: valueColor, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Color _getLatencyColor(double? latency) {
    if (latency == null) return Colors.white70;
    if (latency < 100) return Colors.green;
    if (latency < 200) return Colors.amber;
    return Colors.red;
  }

  Color _getPacketLossColor(double? loss) {
    if (loss == null) return Colors.white70;
    if (loss < 1) return Colors.green;
    if (loss < 3) return Colors.amber;
    return Colors.red;
  }

  Color _getJitterColor(double? jitter) {
    if (jitter == null) return Colors.white70;
    if (jitter < 30) return Colors.green;
    if (jitter < 50) return Colors.amber;
    return Colors.red;
  }

}
