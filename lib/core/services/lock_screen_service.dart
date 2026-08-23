import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Autorise l'écran d'appel — et lui seul — à s'afficher par-dessus le keyguard.
///
/// Le privilège vivait dans `AndroidManifest.xml`
/// (`android:showWhenLocked="true"` sur MainActivity). Un attribut de manifeste
/// vaut pour toute la vie de l'activité : l'application entière restait donc
/// consultable écran verrouillé — verrouiller le téléphone avec Diaspo Niger au
/// premier plan puis rallumer l'écran rouvrait l'app sans code.
///
/// Ici, le privilège est demandé quand un écran d'appel s'ouvre et rendu quand
/// il se ferme. Aucun effet hors Android.
class LockScreenService {
  LockScreenService._();

  static final LockScreenService instance = LockScreenService._();

  static const MethodChannel _channel = MethodChannel(
    'diaspo_niger/lockscreen',
  );

  /// Nombre d'écrans qui demandent le privilège en ce moment.
  ///
  /// Un appel peut empiler deux écrans (bannière d'appel entrant puis écran
  /// d'appel) : décompter permet de ne rendre le privilège qu'au dernier qui
  /// part, au lieu de le retirer sous les pieds de celui qui reste.
  int _holders = 0;

  Future<void> acquire() async {
    _holders++;
    if (_holders == 1) await _apply(true);
  }

  Future<void> release() async {
    if (_holders == 0) return;
    _holders--;
    if (_holders == 0) await _apply(false);
  }

  Future<void> _apply(bool enabled) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>('setShowWhenLocked', {
        'enabled': enabled,
      });
    } on PlatformException catch (e) {
      debugPrint('LockScreenService: setShowWhenLocked($enabled) a échoué: $e');
    } on MissingPluginException {
      // Canal absent (test unitaire, ancienne version native) : sans effet.
    }
  }
}
