import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Service pour d├®tecter et g├®rer les appels GSM (t├®l├®phoniques traditionnels).
///
/// Permet de mettre en pause les appels VoIP quand un appel GSM arrive
/// et de les reprendre quand l'appel GSM se termine.
///
/// Android uniquement - sur iOS, CallKit g├¿re cela automatiquement.
class GsmCallService {
  static const _channel = EventChannel('com.diasponiger.diaspo_niger/gsm_state');

  static GsmCallService? _instance;
  static GsmCallService get instance => _instance ??= GsmCallService._();

  GsmCallService._();

  StreamSubscription? _subscription;
  final _gsmCallController = StreamController<GsmCallEvent>.broadcast();

  /// Stream des ├®v├®nements d'appels GSM
  Stream<GsmCallEvent> get gsmCallEvents => _gsmCallController.stream;

  /// D├®marre l'├®coute des ├®v├®nements d'appels GSM
  void startListening() {
    // GSM call detection n'est support├® que sur Android
    if (!Platform.isAndroid) return;

    // ├ëviter les doublons
    if (_subscription != null) return;

    debugPrint('GsmCallService: Starting to listen for GSM call events');

    // Wrap in try-catch to handle MissingPluginException when native code
    // is not available. This is expected on devices without GSM support
    // or when the native implementation is not included.
    try {
      _subscription = _channel.receiveBroadcastStream().listen(
        (event) {
          if (event is! Map) return;

          final data = Map<String, dynamic>.from(event);
          final eventType = data['event'] as String?;

          debugPrint('GsmCallService: Received event: $eventType');

          switch (eventType) {
            case 'gsm_call_incoming':
              _gsmCallController.add(GsmCallEvent.incoming);
              break;
            case 'gsm_call_active':
              _gsmCallController.add(GsmCallEvent.active);
              break;
            case 'gsm_call_ended':
              _gsmCallController.add(GsmCallEvent.ended);
              break;
          }
        },
        onError: (error) {
          // Ignore MissingPluginException - channel may not be ready
          if (!error.toString().contains('MissingPluginException')) {
            debugPrint('GsmCallService: Stream error: $error');
          }
        },
      );
    } on MissingPluginException {
      // Native implementation not available - this is expected
      // GSM call detection will be disabled
      debugPrint('GsmCallService: Native implementation not available, GSM detection disabled');
    } catch (e) {
      // Other errors - log but don't crash
      debugPrint('GsmCallService: Error starting listener: $e');
    }
  }

  /// Arr├¬te l'├®coute des ├®v├®nements d'appels GSM
  /// Can be called from dispose() - handles async cleanup safely
  void stopListening() {
    debugPrint('GsmCallService: Stopping GSM call event listener');
    // Simply null out the subscription without calling cancel()
    // This avoids MissingPluginException when the native channel isn't available
    // The native resources will be cleaned up when the Activity is destroyed
    _subscription = null;
  }

  /// Lib├¿re les ressources
  void dispose() {
    stopListening();
    _gsmCallController.close();
  }
}

/// ├ëv├®nements d'appels GSM possibles
enum GsmCallEvent {
  /// Un appel GSM entrant (sonnerie)
  incoming,

  /// Un appel GSM est actif (d├®croch├®)
  active,

  /// L'appel GSM s'est termin├®
  ended,
}
