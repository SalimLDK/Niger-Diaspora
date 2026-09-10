import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Service pour détecter et gérer les appels GSM (téléphoniques traditionnels).
///
/// Permet de mettre en pause les appels VoIP quand un appel GSM arrive
/// et de les reprendre quand l'appel GSM se termine.
///
/// Android uniquement - sur iOS, CallKit gère cela automatiquement.
class GsmCallService {
  static const _channel = EventChannel('com.diasponiger.diaspo_niger/gsm_state');

  static GsmCallService? _instance;
  static GsmCallService get instance => _instance ??= GsmCallService._();

  GsmCallService._();

  StreamSubscription? _subscription;
  final _gsmCallController = StreamController<GsmCallEvent>.broadcast();

  /// Stream des événements d'appels GSM
  Stream<GsmCallEvent> get gsmCallEvents => _gsmCallController.stream;

  /// Le canal natif est-il implémenté ?
  ///
  /// **Non**, et pas « pas encore prêt » : `com.diasponiger.diaspo_niger/gsm_state`
  /// n'existe nulle part dans `android/app/src/main` — aucun `EventChannel`
  /// correspondant n'est enregistré côté Kotlin/Java. Écouter ce canal ne peut
  /// donc qu'échouer.
  ///
  /// Et l'échec n'était **pas** rattrapable là où il était écrit. Le
  /// `try/catch` autour de `.listen()` et le `onError` du flux ne voient rien :
  /// `EventChannel.receiveBroadcastStream` signale un échec d'activation par
  /// `FlutterError.reportError` (cf. `platform_channel.dart:713`), qui part
  /// directement dans `FlutterError.onError` — donc dans Crashlytics. Constaté
  /// le 2026-09-10 : *MissingPluginException (No implementation found for
  /// method listen on channel …/gsm_state)*, 3 occurrences.
  ///
  /// Tant que l'implémentation native n'existe pas, on n'active pas le canal.
  /// Le jour où elle arrive, il suffit de passer ce drapeau à `true`.
  static const bool _canalNatifImplemente = false;

  /// Démarre l'écoute des événements d'appels GSM
  void startListening() {
    // GSM call detection n'est supporté que sur Android
    if (!Platform.isAndroid) return;

    if (!_canalNatifImplemente) {
      debugPrint(
        'GsmCallService: canal natif absent, détection GSM désactivée',
      );
      return;
    }

    // Éviter les doublons
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

  /// Arrête l'écoute des événements d'appels GSM
  /// Can be called from dispose() - handles async cleanup safely
  void stopListening() {
    debugPrint('GsmCallService: Stopping GSM call event listener');
    // Simply null out the subscription without calling cancel()
    // This avoids MissingPluginException when the native channel isn't available
    // The native resources will be cleaned up when the Activity is destroyed
    _subscription = null;
  }

  /// Libère les ressources
  void dispose() {
    stopListening();
    _gsmCallController.close();
  }
}

/// Événements d'appels GSM possibles
enum GsmCallEvent {
  /// Un appel GSM entrant (sonnerie)
  incoming,

  /// Un appel GSM est actif (décroché)
  active,

  /// L'appel GSM s'est terminé
  ended,
}
