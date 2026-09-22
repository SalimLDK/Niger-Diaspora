import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Retire un dossier de la sauvegarde iCloud — pendant iOS des règles
/// Android `regles_sauvegarde.xml` / `regles_extraction_donnees.xml`.
///
/// iOS n'a pas de règles déclaratives : c'est un drapeau posé sur le dossier,
/// à l'exécution (`isExcludedFromBackup`, `AppDelegate.exclureDeLaSauvegarde`).
/// Il couvre tout ce que le dossier contient, y compris ce qui y sera écrit
/// plus tard.
///
/// Même mécanique que `_exclureDeLaSauvegardeIos` du moteur MLS
/// (`mls_engine_provider.dart`), qui garde la sienne pour ne pas toucher à
/// l'ouverture du moteur.
///
/// **Échoue en silence, et c'est délibéré** : une exclusion qui ne prend pas
/// est un problème de confidentialité, empêcher l'app de démarrer ou un média
/// de s'afficher serait une panne. On journalise et on continue.
///
/// ⚠️ **Jamais exécuté sur iOS** : ce dépôt n'a pas de Mac, le code Swift qui
/// répond est écrit, pas éprouvé. Hors iOS, ne fait rien.
Future<void> exclureDeLaSauvegardeIos(
  Directory dossier, {
  required String etiquette,
}) async {
  if (!Platform.isIOS) return;
  try {
    final fait = await const MethodChannel('diaspo_niger/share_intent')
        .invokeMethod<bool>('exclureDeLaSauvegarde', dossier.path);
    if (fait != true) {
      debugPrint('$etiquette : dossier NON exclu de la sauvegarde iCloud');
    }
  } catch (e) {
    debugPrint('$etiquette : exclusion iCloud indisponible ($e)');
  }
}
