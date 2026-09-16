import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'mls_partage_extension_ios.dart';

/// Canal natif déjà en place (nettoyage de l'intent de partage, SSAID,
/// exclusion de sauvegarde) — on y ajoute une méthode plutôt que d'ouvrir un
/// second canal.
const MethodChannel _canal = MethodChannel('diaspo_niger/share_intent');

/// Nom du fichier de base pour un compte.
///
/// L'uid Firebase ne contient que des caractères sûrs ; l'assainissement est
/// une ceinture, et il est **reproduit à l'identique en Swift**. Les deux
/// doivent bouger ensemble.
String nomFichierBaseMls(String userId) =>
    '${userId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}.sqlite';

/// Dossier où vit la base SQLite du moteur, créé si besoin.
///
/// **Pourquoi ce n'est pas une constante.** Sur Android, la base est lue par
/// l'app et par l'isolate de notification, qui partagent le bac à sable :
/// `Application Support` suffit. Sur iOS, l'aperçu est reconstruit par une
/// **Notification Service Extension**, c'est-à-dire un autre processus, avec
/// **son propre bac à sable** : elle ne voit `Application Support` de l'app à
/// aucun prix. Le seul terrain commun est le conteneur du groupe
/// d'application.
///
/// **Repli, et ce qu'il coûte.** Si le groupe n'est pas provisionné — clé
/// absente des entitlements, profil pas régénéré — le conteneur est nul. On
/// reste alors sur `Application Support` : l'application fonctionne
/// exactement comme avant, seul l'aperçu des notifications retombe sur le
/// texte générique. Échouer vers « moins bien » plutôt que vers « cassé ».
Future<Directory> dossierBaseMls() async {
  final support = await getApplicationSupportDirectory();
  final prive = Directory('${support.path}/mls');

  if (!Platform.isIOS) {
    if (!await prive.exists()) await prive.create(recursive: true);
    return prive;
  }

  final conteneur = await _conteneurGroupeIos();
  if (conteneur == null || conteneur.isEmpty) {
    if (!await prive.exists()) await prive.create(recursive: true);
    return prive;
  }

  final partage = Directory('$conteneur/mls');
  if (!await partage.exists()) await partage.create(recursive: true);
  await _migrerVersLeGroupe(prive, partage);
  return partage;
}

/// Chemin complet de la base du moteur pour ce compte.
Future<String> cheminBaseMls(String userId) async {
  final dossier = await dossierBaseMls();
  return '${dossier.path}/${nomFichierBaseMls(userId)}';
}

/// ⚠️ **Muet dans un isolate frais.** Ce canal est propre à l'app : un isolate
/// de fond ne l'a pas sans liaison explicite (le dépôt l'a déjà payé avec le
/// SSAID). Sur iOS, `MlsNotificationPreview` retomberait donc sur le dossier
/// privé pendant que l'app écrit dans le groupe — et ne trouverait rien.
/// Ça n'a pas de conséquence aujourd'hui, parce que sur iOS l'aperçu est
/// justement fait par l'extension et non par un isolate ; si cet isolate
/// devait un jour servir sur iOS, c'est ici qu'il faudrait regarder en
/// premier.
Future<String?> _conteneurGroupeIos() async {
  try {
    return await _canal.invokeMethod<String>('cheminGroupeApp', groupeAppIos);
  } catch (e) {
    debugPrint('MLS: conteneur de groupe indisponible ($e)');
    return null;
  }
}

/// Déplace une base restée dans l'ancien emplacement privé.
///
/// **Déplacer, pas copier.** Deux copies de l'état MLS, c'est deux cliquets
/// qui avancent séparément : la conversation devient illisible d'un côté ou de
/// l'autre, sans qu'aucune erreur ne le dise. S'il existe déjà une base dans
/// le conteneur partagé, c'est elle qui fait foi et l'ancienne est laissée
/// telle quelle — écraser un état vivant serait pire que tout.
///
/// Les compagnons `-wal` et `-shm` suivent : un WAL orphelin resté derrière
/// contiendrait les dernières écritures, donc le cliquet le plus avancé.
Future<void> _migrerVersLeGroupe(Directory prive, Directory partage) async {
  if (!await prive.exists()) return;
  try {
    for (final entree in prive.listSync()) {
      if (entree is! File) continue;
      final nom = entree.uri.pathSegments.last;
      if (!nom.endsWith('.sqlite') &&
          !nom.endsWith('.sqlite-wal') &&
          !nom.endsWith('.sqlite-shm')) {
        continue;
      }
      final cible = File('${partage.path}/$nom');
      if (await cible.exists()) continue;
      await entree.rename(cible.path);
      debugPrint('MLS: base migrée vers le conteneur partagé ($nom)');
    }
  } catch (e) {
    // Une migration ratée laisse l'app sur une base absente du conteneur : le
    // moteur en recréera une, et l'identité neuve est un cas que le registre
    // traite déjà (`identite_mls_changee`). Jamais une raison de ne pas
    // démarrer.
    debugPrint('MLS: migration vers le conteneur partagé incomplète ($e)');
  }
}
