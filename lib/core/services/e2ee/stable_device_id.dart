import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
/// Sur iOS, `identifierForVendor` joue le même rôle — propre au couple
/// (éditeur, appareil), conservé tant qu'une app du même éditeur reste
/// installée.
///
/// **L'identifiant brut n'est jamais transmis.** On en publie un condensé
/// SHA-256 salé par [userId] : deux comptes sur le même téléphone obtiennent
/// donc des identifiants différents, ce qui interdit au serveur de les
/// rapprocher.
///
/// **Un canal muet ne donne jamais un identifiant inventé : on attend.** Le
/// canal est branché par `MainActivity.configureFlutterEngine`, et le moteur
/// qui exécute `main()` peut tourner sans elle : audio_service le crée aussi
/// depuis `AudioService.onCreate()`, quand le système démarre le service de
/// lecture sans ouvrir l'app. Le repli sur un UUID aléatoire tirait alors un
/// identifiant neuf **à chaque appel** — le 2026-09-16, sur le Pixel, un seul
/// moteur ouvert sous un identifiant inventé s'est inscrit trois fois en
/// 190 ms : trois appareils fantômes, que les autres membres ont ensuite
/// tenté d'ajouter en boucle. L'attente, elle, aboutit dès que l'activité se
/// rattache au moteur ; d'ici là, rien ne s'inscrit ni ne s'ouvre.
///
/// Conséquence à connaître : **ne jamais l'appeler depuis l'isolate de
/// notification**, où ce canal n'existe jamais — l'appel n'y aboutirait pas.
/// L'aperçu relit l'identifiant mémorisé à l'inscription
/// (`MlsNotificationPreview.cleStableId`).
///
/// Hors Android et iOS (tests, desktop), aucune plateforme n'a d'identifiant
/// à offrir : UUID aléatoire, comme avant.
Future<String> stableDeviceId(String userId) async {
  if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) {
    return const Uuid().v4();
  }
  final installation = await (_installation ??= attendreIdentifiantInstallation(
    lire: () => _channel.invokeMethod<String>('getInstallationId'),
    repli: _repliPersistant,
  ));
  return deviceIdFromInstallation(installation, userId);
}

/// L'identifiant d'installation, obtenu une fois par isolate. Tous les
/// appelants partagent la même lecture — et, le cas échéant, la même attente.
Future<String>? _installation;

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

/// Lit l'identifiant d'installation, en attendant que le canal réponde.
///
/// Deux issues seulement, et c'est tout l'objet de la fonction :
/// - le canal **lève** (`MissingPluginException` : personne ne l'a encore
///   branché) → on réessaie, avec un délai qui double jusqu'à [delaiMax], sans
///   limite de durée ;
/// - le canal **répond** → sa valeur, ou [repli] si la plateforme n'en a pas
///   (ROM sans SSAID, `identifierForVendor` nul).
///
/// Ne rend jamais une valeur tirée au sort parce que le canal était muet.
@visibleForTesting
Future<String> attendreIdentifiantInstallation({
  required Future<String?> Function() lire,
  required Future<String> Function() repli,
  Future<void> Function(Duration) attendre = _attendre,
  Duration premierDelai = const Duration(milliseconds: 100),
  Duration delaiMax = const Duration(seconds: 5),
}) async {
  var delai = premierDelai;
  for (var tentative = 1;; tentative++) {
    String? valeur;
    try {
      valeur = await lire();
    } catch (e) {
      if (tentative == 1) {
        debugPrint(
          'stableDeviceId: canal muet, moteur sans activité ? — attente ($e)',
        );
      }
      await attendre(delai);
      final suivant = delai * 2;
      delai = suivant > delaiMax ? delaiMax : suivant;
      continue;
    }
    if (tentative > 1) {
      debugPrint('stableDeviceId: canal branché après $tentative tentatives');
    }
    if (valeur == null || valeur.isEmpty) return repli();
    return valeur;
  }
}

Future<void> _attendre(Duration delai) => Future<void>.delayed(delai);

/// La plateforme a répondu sans identifiant : un UUID tiré **une fois** et
/// rangé, pour que l'appareil garde le même d'un lancement à l'autre. Il passe
/// ensuite par [deviceIdFromInstallation] comme un SSAID — jamais publié brut.
///
/// L'ancien repli tirait un UUID neuf à chaque appel : le même appareil
/// changeait d'identité entre l'ouverture du moteur et son inscription.
Future<String> _repliPersistant() async {
  const cle = 'stable_device_id_repli';
  try {
    final prefs = await SharedPreferences.getInstance();
    final existant = prefs.getString(cle);
    if (existant != null && existant.isNotEmpty) return existant;
    final neuf = const Uuid().v4();
    await prefs.setString(cle, neuf);
    return neuf;
  } catch (e) {
    // Mémorisé par [_installation] : stable au moins pour ce processus.
    debugPrint('stableDeviceId: repli non rangé ($e)');
    return const Uuid().v4();
  }
}
