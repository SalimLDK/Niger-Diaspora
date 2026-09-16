import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Ce que l'app doit déposer pour que l'extension de notification iOS puisse
/// travailler, et pourquoi ça ne peut pas passer par `SharedPreferences`.
///
/// **Le problème.** Sur Android, l'aperçu d'un message MLS est reconstruit par
/// un isolate Dart : il a `SharedPreferences`, donc `currentUserId` et
/// l'identifiant d'appareil sont déjà là. iOS n'offre pas ça — une Notification
/// Service Extension est un binaire séparé, sans moteur Flutter et sans Dart.
/// Elle lit des `UserDefaults`, et seulement ceux du groupe partagé.
///
/// **Le piège qu'on évite.** `SharedPreferences` écrit dans
/// `UserDefaults.standard`, et **préfixe toutes ses clés par `flutter.`**.
/// Même en partageant la suite, une extension qui lit `"currentUserId"` ne
/// trouverait rien — sans erreur, sans journal, avec pour seul symptôme un
/// aperçu générique. On écrit donc nous-mêmes, aux clés exactes que le Swift
/// lit, dans la suite du groupe.
///
/// ⚠️ **Jamais compilé.** Ce dépôt n'a pas de Mac : le Swift qui répond à cet
/// appel est écrit, pas éprouvé.
const String groupeAppIos = 'group.com.diasponiger.diasponiger';

const MethodChannel _canal = MethodChannel('diaspo_niger/share_intent');

/// Dépose le compte courant et son identifiant d'appareil pour l'extension.
///
/// Sans objet ailleurs qu'iOS : Android lit les mêmes valeurs dans
/// `SharedPreferences`, que le registre écrit juste avant.
///
/// Échoue en silence. Sans ces deux valeurs l'extension retombe sur l'aperçu
/// générique du serveur ; faire échouer l'inscription de l'appareil pour ça
/// serait hors de proportion.
Future<void> deposerContexteExtensionIos({
  required String userId,
  required String deviceId,
}) async {
  if (!Platform.isIOS) return;
  try {
    await _canal.invokeMethod<bool>('deposerContexteMls', <String, String>{
      'groupe': groupeAppIos,
      'userId': userId,
      'deviceId': deviceId,
    });
  } catch (e) {
    debugPrint('MLS: contexte non déposé pour l\'extension iOS ($e)');
  }
}

/// Efface ce dépôt à la déconnexion.
///
/// Même raison que le `remove('currentUserId')` de `NotificationService` juste
/// à côté : sans ça l'extension continuerait, après déconnexion, à reconstruire
/// des aperçus sous l'identité du compte précédent. L'état MLS de ce compte est
/// toujours sur l'appareil — c'est bien pour ça qu'il faut couper l'accès par
/// son nom.
Future<void> effacerContexteExtensionIos() async {
  if (!Platform.isIOS) return;
  try {
    await _canal.invokeMethod<bool>('effacerContexteMls', groupeAppIos);
  } catch (e) {
    debugPrint('MLS: contexte de l\'extension iOS non effacé ($e)');
  }
}
