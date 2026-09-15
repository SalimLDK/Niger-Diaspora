import 'dart:io';

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
/// **Dette assumée en phase 2** : la base SQLite du moteur (clé privée de
/// signature, futurs secrets de groupe) est écrite en clair dans le
/// répertoire privé de l'app. Le plan (§ 7.4) prévoit une clé maître dans le
/// Keystore / Keychain ; elle vient avec la phase 3. Consigné dans
/// `TESTS_APPAREIL_A_FAIRE.md`.
final mlsEngineProvider = FutureProvider.family<Moteur, String>((ref, userId) async {
  await _initialiserRustUneFois();
  final support = await getApplicationSupportDirectory();
  final dossier = Directory('${support.path}/mls');
  if (!await dossier.exists()) {
    await dossier.create(recursive: true);
  }
  // L'uid Firebase ne contient que des caractères sûrs pour un nom de fichier.
  final chemin = '${dossier.path}/${userId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}.sqlite';
  final appareil = await stableDeviceId(userId);
  return Moteur.ouvrir(dbPath: chemin, userId: userId, deviceId: appareil);
});

Future<void>? _initRust;

/// `RustLib.init()` charge la bibliothèque native : une fois par processus,
/// et un second appel lève. Les appelants concurrents partagent le même
/// `Future`, comme `_inFlightSync` du pont de session.
Future<void> _initialiserRustUneFois() {
  return _initRust ??= RustLib.init();
}
