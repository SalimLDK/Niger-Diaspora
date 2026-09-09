import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Luminosité de l'écran poussée au maximum le temps d'afficher un QR.
///
/// Le code de transfert des clés est lu par la caméra d'un autre téléphone : un
/// écran en veille douce ou réglé bas rend le scan pénible, voire impossible en
/// extérieur.
///
/// Porté par la fenêtre de l'activité côté Android, pas par les réglages de
/// l'appareil : rien n'est modifié durablement, et l'effet retombe tout seul si
/// l'activité meurt sans que [restore] ait pu être appelé.
///
/// Muet ailleurs qu'Android — l'appel n'est pas implémenté, on l'ignore, comme
/// [WakelockHelper] le fait pour ses propres exceptions.
class ScreenBrightnessHelper {
  ScreenBrightnessHelper._();

  static const MethodChannel _channel = MethodChannel('diaspo_niger/screen');

  static Future<void> max() => _set(true);

  static Future<void> restore() => _set(false);

  static Future<void> _set(bool enabled) async {
    try {
      await _channel.invokeMethod<void>('setMaxBrightness', {
        'enabled': enabled,
      });
    } on PlatformException catch (e) {
      debugPrint('ScreenBrightnessHelper ignored: $e');
    } on MissingPluginException {
      // Plateforme sans implémentation (iOS, web, tests) : sans effet.
    }
  }
}
