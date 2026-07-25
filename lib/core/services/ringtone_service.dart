import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

/// Service pour g├®rer la sonnerie et la vibration des appels entrants
class RingtoneService {
  static final RingtoneService _instance = RingtoneService._internal();
  factory RingtoneService() => _instance;
  RingtoneService._internal();

  AudioPlayer? _ringbackPlayer;
  bool _isPlaying = false;
  bool _isVibrating = false;
  bool _isRingbackPlaying = false;

  /// D├®marre la sonnerie syst├¿me et la vibration pour un appel entrant
  Future<void> startRinging({bool isVideoCall = false}) async {
    if (_isPlaying) return;

    try {
      _isPlaying = true;
      _isVibrating = true;

      // Jouer la sonnerie syst├¿me de l'appareil
      await FlutterRingtonePlayer().playRingtone(
        looping: true,
        volume: 1.0,
        asAlarm: false,
      );

      // D├®marrer la vibration en boucle
      _startVibrationLoop();
    } catch (e) {
      // Si erreur, utiliser la vibration seule
      _isPlaying = false;
      _startVibrationLoop();
    }
  }

  /// Arr├¬te la sonnerie et la vibration
  Future<void> stopRinging() async {
    _isPlaying = false;
    _isVibrating = false;

    try {
      await FlutterRingtonePlayer().stop();
    } catch (e) {
      // Ignorer les erreurs de nettoyage
    }
  }

  /// Vibration en boucle (pattern typique d'appel)
  void _startVibrationLoop() async {
    while (_isVibrating) {
      // Vibration de 500ms
      HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 500));

      if (!_isVibrating) break;

      // Pause de 300ms
      await Future.delayed(const Duration(milliseconds: 300));

      if (!_isVibrating) break;

      // Vibration de 500ms
      HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 500));

      if (!_isVibrating) break;

      // Pause de 1500ms
      await Future.delayed(const Duration(milliseconds: 1500));
    }
  }

  /// Vibration courte pour les notifications
  void vibrate() {
    HapticFeedback.mediumImpact();
  }

  /// D├®marre la tonalit├® d'attente (ringback) pour l'appelant
  /// C'est le "bip... bip..." que l'appelant entend en attendant que le destinataire r├®ponde
  Future<void> startRingback() async {
    if (_isRingbackPlaying) return;

    try {
      _isRingbackPlaying = true;
      _ringbackPlayer = AudioPlayer();

      // Essayer de charger le fichier de tonalit├® d'attente
      await _ringbackPlayer!.setAsset('assets/sounds/ringback.mp3');
      await _ringbackPlayer!.setLoopMode(LoopMode.one);
      await _ringbackPlayer!.setVolume(0.5); // Volume mod├®r├®
      await _ringbackPlayer!.play();
    } catch (e) {
      // Si pas de fichier, g├®n├®rer une tonalit├® synth├®tique
      _isRingbackPlaying = false;
      _startSyntheticRingback();
    }
  }

  /// Tonalit├® d'attente synth├®tique (sans fichier audio)
  /// Simule le pattern classique: bip (1s) - silence (3s) - bip (1s) - ...
  void _startSyntheticRingback() async {
    _isRingbackPlaying = true;

    while (_isRingbackPlaying) {
      // Vibration l├®g├¿re pour simuler le "bip"
      HapticFeedback.lightImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      if (!_isRingbackPlaying) break;

      HapticFeedback.lightImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      if (!_isRingbackPlaying) break;

      HapticFeedback.lightImpact();

      // Silence de 3 secondes
      await Future.delayed(const Duration(seconds: 3));
    }
  }

  /// Arr├¬te la tonalit├® d'attente
  Future<void> stopRingback() async {
    _isRingbackPlaying = false;

    try {
      await _ringbackPlayer?.stop();
      await _ringbackPlayer?.dispose();
      _ringbackPlayer = null;
    } catch (e) {
      // Ignorer les erreurs de nettoyage
    }
  }

  /// V├®rifie si la sonnerie est en cours
  bool get isPlaying => _isPlaying;

  /// V├®rifie si la tonalit├® d'attente est en cours
  bool get isRingbackPlaying => _isRingbackPlaying;
}

final ringtoneServiceProvider = Provider<RingtoneService>((ref) {
  return RingtoneService();
});
