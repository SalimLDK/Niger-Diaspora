import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../src/rust/api/mls.dart';
import '../../../src/rust/frb_generated.dart';
import '../../services/e2ee/stable_device_id.dart';

/// Le moteur MLS (Rust, OpenMLS) de l'appareil courant, pour un compte.
///
/// **Ne dépend que de l'identifiant utilisateur.** C'est la première règle
/// tirée du chantier Signal (plan MLS, § 7.3 et § 10) : un `Provider` qui en
/// observait deux autres se faisait reconstruire à leur moindre invalidation,
/// repartait « non initialisé », et personne ne le rejouait — d'où 0 message
/// chiffré en production pendant des semaines. Ici, rien à observer : le
/// moteur vit tant que le compte est connecté, et se rouvre depuis sa base
/// SQLite s'il est recréé.
///
/// Pas `autoDispose` : le résultat est une poignée sur un fichier ouvert, et
/// la reconstruire au gré des écrans rouvrirait la base à chaque fois.
///
/// **Dette assumée, et ce qui la tient** : la base SQLite du moteur (clé
/// privée de signature, secrets d'epoch, arbres de groupe) est écrite en clair
/// dans le répertoire privé de l'app. Le plan (§ 7.4) prévoit une clé maître
/// dans le Keystore / Keychain, en laissant le chiffrement au choix — SQLCipher
/// ou chiffrement des valeurs par le provider. **Les deux voies ont été
/// mesurées le 2026-09-15, et aucune n'est ouverte en l'état :**
///
/// - **SQLCipher** demande `rusqlite/bundled-sqlcipher-vendored-openssl`. La
///   configuration d'OpenSSL échoue sur ce poste — le `perl` de Git Bash ne
///   convient pas à `Configure` pour la cible `VC-WIN64A`. Le banc Rust de la
///   phase 3 ne compilerait plus ici, et la compilation croisée Android
///   resterait à prouver.
/// - **Chiffrer les valeurs par le `Codec`** ne marche pas tel quel : dans
///   `openmls_sqlite_storage`, les **clés de recherche** passent par le même
///   `Codec::to_vec` que les entités et servent de critère d'égalité en SQL.
///   Un AES-GCM à nonce aléatoire rendrait toute lecture introuvable. Il
///   faudrait un chiffrement déterministe (AES-SIV), plus faible, et le
///   `Codec` étant un trait à méthodes statiques, la clé devrait vivre dans un
///   global de processus.
///
/// Et une troisième contrainte, découverte au même moment, pèse sur les deux :
/// l'isolate de notification doit rouvrir cette base (§ 8) mais **n'a pas de
/// `MethodChannel` sans liaison explicite** — il ne peut donc pas lire le
/// Keystore comme l'app. Chiffrer sans résoudre ce point casserait l'aperçu
/// des notifications, déjà livré.
///
/// **Ce qui est fait en attendant** : la base ne quitte plus l'appareil, sur
/// les deux plateformes. Android l'exclut de la sauvegarde Google et du
/// transfert d'appareil à appareil (`android/app/src/main/res/xml/`) ; iOS la
/// retire de la sauvegarde iCloud par un drapeau posé à l'ouverture
/// (`_exclureDeLaSauvegardeIos`, ci-dessous). C'est le seul chemin
/// d'exfiltration qui ne demande ni root ni accès physique, et il est fermé.
/// Verrouillé par `test/core/crypto/etat_mls_hors_sauvegarde_test.dart`.
///
/// Le chiffrement du fichier lui-même reste à faire, et reste consigné dans
/// `TESTS_APPAREIL_A_FAIRE.md`.
final mlsEngineProvider = FutureProvider.family<Moteur, String>((ref, userId) async {
  await _initialiserRustUneFois();
  final support = await getApplicationSupportDirectory();
  final dossier = Directory('${support.path}/mls');
  if (!await dossier.exists()) {
    await dossier.create(recursive: true);
  }
  await _exclureDeLaSauvegardeIos(dossier);
  // L'uid Firebase ne contient que des caractères sûrs pour un nom de fichier.
  final chemin = '${dossier.path}/${userId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}.sqlite';
  final appareil = await stableDeviceId(userId);
  return Moteur.ouvrir(dbPath: chemin, userId: userId, deviceId: appareil);
});

/// Pendant iOS de l'exclusion Android : retirer le dossier du moteur de la
/// sauvegarde iCloud.
///
/// Android obtient la même chose par deux fichiers de règles, déclaratifs.
/// iOS n'a pas d'équivalent : c'est un drapeau posé sur le dossier, à
/// l'exécution, et il faut le reposer à chaque fois puisque le dossier peut
/// venir d'être créé.
///
/// **Échoue en silence, et c'est délibéré.** Une exclusion qui ne prend pas
/// est un problème de confidentialité ; empêcher le moteur de s'ouvrir serait
/// une panne. On journalise et on continue — l'entrée de vérification
/// appareil porte le contrôle qui, lui, ne se contente pas du journal.
///
/// ⚠️ **Jamais compilé.** Ce dépôt n'a pas de Mac : le code Swift qui répond à
/// cet appel est écrit, pas éprouvé. Sur Android, la méthode n'existe pas et
/// l'appel retombe dans le `catch` sans rien faire — c'est pourquoi la garde
/// de plateforme est quand même posée.
Future<void> _exclureDeLaSauvegardeIos(Directory dossier) async {
  if (!Platform.isIOS) return;
  try {
    final fait = await const MethodChannel('diaspo_niger/share_intent')
        .invokeMethod<bool>('exclureDeLaSauvegarde', dossier.path);
    if (fait != true) {
      debugPrint('MLS: dossier NON exclu de la sauvegarde iCloud');
    }
  } catch (e) {
    debugPrint('MLS: exclusion iCloud indisponible ($e)');
  }
}

Future<void>? _initRust;

/// `RustLib.init()` charge la bibliothèque native : une fois par processus,
/// et un second appel lève. Les appelants concurrents partagent le même
/// `Future`, comme `_inFlightSync` du pont de session.
Future<void> _initialiserRustUneFois() {
  return _initRust ??= RustLib.init();
}
