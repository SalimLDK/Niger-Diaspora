import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:uuid/uuid.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../utils/wakelock_helper.dart';

/// Events from native call UI (CallKit iOS / ConnectionService Android)
enum NativeCallEvent {
  accepted,
  declined,
  ended,
  timeout,
  callback,
  toggleMute,
  toggleHold,
  toggleDmtf,
  toggleGroup,
  toggleAudioSession,
  didDisplayIncomingCall,
  didActivateAudioSession,
  didDeactivateAudioSession,
}

/// Data associated with a native call event
class NativeCallEventData {
  final NativeCallEvent event;
  final String callId;
  final Map<String, dynamic>? extra;

  NativeCallEventData({required this.event, required this.callId, this.extra});
}

/// Service for native call UI integration
/// Uses CallKit on iOS and ConnectionService on Android
class NativeCallService {
  static final NativeCallService _instance = NativeCallService._internal();
  factory NativeCallService() => _instance;
  NativeCallService._internal();

  static NativeCallService get instance => _instance;

  final _uuid = const Uuid();
  final _eventController = StreamController<NativeCallEventData>.broadcast();

  /// Stream of native call events
  Stream<NativeCallEventData> get eventStream => _eventController.stream;

  bool _isInitialized = false;
  String? _activeCallUuid;
  /// callId LOGIQUE de l'appel entrant actuellement affiché (≠ _activeCallUuid,
  /// qui est l'UUID CallKit). Sert à dédupliquer : un même appel arrive par
  /// plusieurs chemins (stream Firestore + callback push, ce dernier déclenchant
  /// showIncomingCall deux fois) → sans ce garde, plusieurs bannières CallKit.
  String? _activeCallId;
  String? _voipToken;

  /// VoIP push token for iOS (null on Android)
  String? get voipToken => _voipToken;

  /// Callback for when VoIP token is updated
  void Function(String token)? onVoipTokenUpdated;

  /// Initialize the native call service
  Future<void> initialize() async {
    if (_isInitialized) return;
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      debugPrint('NativeCallService: Skipping init on unsupported platform');
      return;
    }

    try {
      FlutterCallkitIncoming.onEvent.listen(
        _handleCallKitEvent,
        onError: (Object e) {
          debugPrint('NativeCallService: Event stream error: $e');
        },
      );

      _isInitialized = true;
      debugPrint('NativeCallService: Initialized successfully');
    } catch (e) {
      debugPrint('NativeCallService: Error initializing: $e');
    }
  }

  /// Show incoming call UI
  Future<void> showIncomingCall({
    required String callId,
    required String callerName,
    String? callerPhotoUrl,
    required bool isVideo,
    String? handle,
  }) async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;

    // Déduplication SYNCHRONE — AVANT tout `await`. Un même appel entrant arrive
    // par plusieurs chemins (stream Firestore + callback push, parfois plusieurs
    // fois dans le même tick). Si le garde est placé APRÈS `await initialize()`,
    // des invocations concurrentes le franchissent TOUTES : l'init n'est pas
    // finie, `_activeCallId` est encore null au moment où chacune vérifie
    // → plusieurs bannières/plein-écran CallKit empilés (bug « plusieurs
    // couches »). En vérifiant ET affectant ici, sans aucun await intercalé,
    // seule la 1re invocation passe ; les suivantes sont ignorées.
    if (_activeCallId == callId) {
      debugPrint('NativeCallService: appel $callId déjà affiché, showIncomingCall ignoré');
      return;
    }
    _activeCallId = callId;

    if (!_isInitialized) {
      await initialize();
    }

    // Generate a UUID for this call (required by CallKit)
    _activeCallUuid = _uuid.v4();

    final params = CallKitParams(
      id: _activeCallUuid,
      nameCaller: callerName,
      appName: 'Diaspo Niger',
      avatar: callerPhotoUrl,
      handle: handle ?? callerName,
      type: isVideo ? 1 : 0, // 0 = audio, 1 = video
      textAccept: 'Accepter',
      textDecline: 'Refuser',
      missedCallNotification: NotificationParams(
        showNotification: true,
        isShowCallback: true,
        subtitle:
            isVideo ? 'Appel vid\u00e9o manqu\u00e9' : 'Appel manqu\u00e9',
        callbackText: 'Rappeler',
      ),
      duration: 45000, // Ring for 45 seconds
      extra: <String, dynamic>{'callId': callId, 'isVideo': isVideo},
      headers: <String, dynamic>{'callId': callId},
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: true,
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#E97424',
        backgroundUrl: null,
        actionColor: '#4CAF50',
        textColor: '#FFFFFF',
        incomingCallNotificationChannelName: 'Appels entrants',
        missedCallNotificationChannelName: 'Appels manqu\u00e9s',
        isShowCallID: false,
      ),
      ios: IOSParams(
        iconName: 'CallKitIcon',
        handleType: 'generic',
        supportsVideo: isVideo,
        maximumCallGroups: 1,
        maximumCallsPerCallGroup: 1,
        audioSessionMode:
            'voiceChat', // Enables built-in noise suppression & echo cancellation
        audioSessionActive: true,
        audioSessionPreferredSampleRate: 16000.0, // Optimal for voice
        audioSessionPreferredIOBufferDuration: 0.005,
        supportsDTMF: false,
        supportsHolding: true,
        supportsGrouping: false,
        supportsUngrouping: false,
        ringtonePath: 'system_ringtone_default',
      ),
    );

    await FlutterCallkitIncoming.showCallkitIncoming(params);

    // Keep screen on during incoming call
    await WakelockHelper.enable();

    debugPrint('NativeCallService: Showing incoming call UI for $callerName');
  }

  /// Show outgoing call UI
  Future<void> showOutgoingCall({
    required String callId,
    required String calleeName,
    String? calleePhotoUrl,
    required bool isVideo,
    String? handle,
  }) async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;
    if (!_isInitialized) {
      await initialize();
    }

    _activeCallUuid = _uuid.v4();

    final params = CallKitParams(
      id: _activeCallUuid,
      nameCaller: calleeName,
      appName: 'Diaspo Niger',
      avatar: calleePhotoUrl,
      handle: handle ?? calleeName,
      type: isVideo ? 1 : 0,
      extra: <String, dynamic>{'callId': callId, 'isVideo': isVideo},
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: true,
        backgroundColor: '#E97424',
        actionColor: '#4CAF50',
        textColor: '#FFFFFF',
      ),
      ios: IOSParams(
        iconName: 'CallKitIcon',
        handleType: 'generic',
        supportsVideo: isVideo,
        maximumCallGroups: 1,
        maximumCallsPerCallGroup: 1,
      ),
    );

    await FlutterCallkitIncoming.startCall(params);

    // Keep screen on during call
    await WakelockHelper.enable();

    debugPrint('NativeCallService: Starting outgoing call to $calleeName');
  }

  /// Update call to connected state
  Future<void> setCallConnected() async {
    if (_activeCallUuid == null) return;

    if (Platform.isAndroid) {
      await FlutterCallkitIncoming.setCallConnected(_activeCallUuid!);
    }
    // iOS handles this automatically via CallKit

    debugPrint('NativeCallService: Call connected');
  }

  /// End the active call
  Future<void> endCall() async {
    if (_activeCallUuid != null) {
      await FlutterCallkitIncoming.endCall(_activeCallUuid!);
    }

    // Allow screen to turn off
    await WakelockHelper.disable();

    _activeCallUuid = null;
    _activeCallId = null;
    debugPrint('NativeCallService: Call ended');
  }

  /// End all calls
  Future<void> endAllCalls() async {
    await FlutterCallkitIncoming.endAllCalls();
    await WakelockHelper.disable();
    _activeCallUuid = null;
    _activeCallId = null;
    debugPrint('NativeCallService: All calls ended');
  }

  /// Hide incoming call notification (when call is handled in-app)
  Future<void> hideIncomingCall() async {
    if (_activeCallUuid != null) {
      await FlutterCallkitIncoming.endCall(_activeCallUuid!);
    }
  }

  /// Get active calls
  Future<List<dynamic>> getActiveCalls() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return [];
    return await FlutterCallkitIncoming.activeCalls();
  }

  /// Check if there are any active calls
  Future<bool> hasActiveCalls() async {
    final calls = await getActiveCalls();
    return calls.isNotEmpty;
  }

  /// Handle events from CallKit/ConnectionService
  void _handleCallKitEvent(CallEvent? event) {
    if (event == null) return;

    final body = event.body as Map<String, dynamic>?;
    final callId =
        body?['extra']?['callId'] as String? ?? body?['id'] as String? ?? '';

    debugPrint('NativeCallService: Event ${event.event} for call $callId');

    NativeCallEvent? nativeEvent;

    switch (event.event) {
      case Event.actionCallAccept:
        nativeEvent = NativeCallEvent.accepted;
        break;
      case Event.actionCallDecline:
        nativeEvent = NativeCallEvent.declined;
        break;
      case Event.actionCallEnded:
        nativeEvent = NativeCallEvent.ended;
        _activeCallUuid = null;
        _activeCallId = null;
        WakelockPlus.disable();
        break;
      case Event.actionCallTimeout:
        nativeEvent = NativeCallEvent.timeout;
        _activeCallUuid = null;
        _activeCallId = null;
        WakelockPlus.disable();
        break;
      case Event.actionCallCallback:
        nativeEvent = NativeCallEvent.callback;
        break;
      case Event.actionCallToggleMute:
        nativeEvent = NativeCallEvent.toggleMute;
        break;
      case Event.actionCallToggleHold:
        nativeEvent = NativeCallEvent.toggleHold;
        break;
      case Event.actionCallToggleDmtf:
        nativeEvent = NativeCallEvent.toggleDmtf;
        break;
      case Event.actionCallToggleGroup:
        nativeEvent = NativeCallEvent.toggleGroup;
        break;
      case Event.actionCallToggleAudioSession:
        nativeEvent = NativeCallEvent.toggleAudioSession;
        break;
      case Event.actionDidUpdateDevicePushTokenVoip:
        // Handle VoIP token update - save and notify listener
        final token = body?['deviceTokenVoIP'] as String?;
        if (token != null && token.isNotEmpty) {
          _voipToken = token;
          debugPrint('NativeCallService: VoIP token updated: $token');
          onVoipTokenUpdated?.call(token);
        }
        return;
      case Event.actionCallIncoming:
        nativeEvent = NativeCallEvent.didDisplayIncomingCall;
        break;
      case Event.actionCallStart:
        // Call started - nothing to propagate
        return;
      case Event.actionCallCustom:
        // Custom event - handle if needed
        return;
      case Event.actionCallConnected:
        // Call connected notification from system
        debugPrint('NativeCallService: Call connected');
        return;
    }

    _eventController.add(
      NativeCallEventData(event: nativeEvent, callId: callId, extra: body),
    );
  }

  /// Set call hold status (iOS only)
  Future<void> setCallHeld(bool held) async {
    if (_activeCallUuid == null || !Platform.isIOS) return;
    // Note: flutter_callkit_incoming doesn't have direct hold API
    // The hold state is managed via toggleHold event
    debugPrint('NativeCallService: Call hold state: $held');
  }

  /// Set mute status
  Future<void> setMuted(bool muted) async {
    if (_activeCallUuid == null) return;
    // Mute is handled via toggleMute event from native UI
    debugPrint('NativeCallService: Mute state: $muted');
  }

  /// Get the current active call UUID
  String? get activeCallUuid => _activeCallUuid;

  /// Dispose resources
  Future<void> dispose() async {
    await _eventController.close();
    await WakelockHelper.disable();
    _isInitialized = false;
  }
}
