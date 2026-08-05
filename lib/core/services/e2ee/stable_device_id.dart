import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

/// Canal déjà utilisé pour le nettoyage de l'intent de partage — on y ajoute
/// simplement une méthode plutôt que d'ouvrir un second canal.
const MethodChannel _channel = MethodChannel('diaspo_niger/share_intent');

/// Identifiant d'appareil **stable entre deux vidages de données**.
///
/// Avant : `Uuid().v4()` rangé dans le stockage sécurisé. Le moindre vidage de
/// données le perdait, la régénération des clés créait alors une NOUVELLE ligne
/// dans `e2ee_devices`, et les entrées mortes s'accumulaient (2 → 3 constaté le
/// 2026-08-04 sur le SM A515F). Ce n'est pas que de l'encombrement : chaque
/// message destiné au compte doit être chiffré pour **chaque** appareil actif,
/// identités mortes comprises.
///
/// Désormais dérivé du SSAID Android (`Settings.Secure.ANDROID_ID`), propre au
/// triplet (clé de signature, utilisateur, appareil) depuis Android 8 : il
/// survit au vidage de données et à une réinstallation signée de la même clé.
///
/// **L'identifiant brut n'est jamais transmis.** On en publie un condensé
/// SHA-256 salé par [userId] : deux comptes sur le même téléphone obtiennent
/// donc des identifiants différents, ce qui interdit au serveur de les
/// rapprocher.
///
/// Repli sur un UUID aléatoire si la plateforme ne fournit rien (ROM exotique,
/// iOS/desktop pour l'instant) : c'est exactement l'ancien comportement, donc
/// jamais pire.
Future<String> stableDeviceId(String userId) async {
  final installationId = await _installationId();
  if (installationId == null || installationId.isEmpty) {
    return const Uuid().v4();
  }
  return deviceIdFromInstallation(installationId, userId);
}

/// Dérivation pure de [stableDeviceId], isolée pour être testable : le chemin
/// complet dépend de `Platform.isAndroid`, faux sur l'hôte de test.
///
/// Doit rester **déterministe** (même appareil + même compte = même
/// identifiant, c'est tout l'intérêt) et **cloisonnée par compte** (deux
/// comptes sur le même téléphone ne doivent pas être rapprochables côté
/// serveur).
@visibleForTesting
String deviceIdFromInstallation(String installationId, String userId) {
  final digest = sha256.convert(utf8.encode('$installationId:$userId'));
  // 32 caractères hex : assez large pour éviter toute collision, et de la même
  // famille visuelle qu'un UUID dans les journaux et la base.
  return digest.toString().substring(0, 32);
}

Future<String?> _installationId() async {
  if (kIsWeb || !Platform.isAndroid) return null;
  try {
    return await _channel.invokeMethod<String>('getInstallationId');
  } catch (e) {
    debugPrint('stableDeviceId: identifiant d\'installation indisponible ($e)');
    return null;
  }
}
