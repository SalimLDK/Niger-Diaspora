import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'key_backup_service.dart';
import 'key_manager_service.dart';
import 'messaging_e2ee_service.dart';
import 'secure_key_storage.dart';

/// Action de sauvegarde des clés E2EE que l'UI doit proposer à l'utilisateur.
enum E2EEBackupPrompt {
  /// Rien à proposer.
  none,

  /// Des clés viennent d'être générées sur cet appareil et ne sont sauvegardées
  /// nulle part : proposer de créer une sauvegarde chiffrée.
  needsBackup,

  /// Aucune clé locale mais une sauvegarde chiffrée existe à distance : proposer
  /// de la restaurer (sinon les messages chiffrés reçus resteront illisibles).
  needsRestore,
}

/// Expose l'action de sauvegarde/restauration à proposer après la connexion.
///
/// L'UI (cf. `MainShell`) l'observe pour afficher un bandeau non bloquant.
final e2eeBackupCoordinatorProvider =
    StateNotifierProvider<E2EEBackupCoordinator, E2EEBackupPrompt>((ref) {
  return E2EEBackupCoordinator(ref);
});

/// Aiguille le démarrage E2EE à la connexion et décide s'il faut proposer une
/// sauvegarde ou une restauration des clés — sans jamais écraser une identité
/// restaurable par des clés neuves.
class E2EEBackupCoordinator extends StateNotifier<E2EEBackupPrompt> {
  E2EEBackupCoordinator(this._ref) : super(E2EEBackupPrompt.none);

  final Ref _ref;

  /// Aiguille le démarrage E2EE pour [userId]. Best-effort : toute erreur laisse
  /// l'app fonctionner (repli AES) plutôt que de bloquer la connexion.
  ///
  /// - Clés locales présentes           -> initialise (re-publie au besoin), pas de prompt.
  /// - Pas de clés + backup distant      -> `needsRestore`, NE génère PAS de clés
  ///   (générer créerait une nouvelle identité et casserait le déchiffrement).
  /// - Pas de clés + pas de backup       -> génère les clés puis `needsBackup`.
  ///
  /// Limite connue : [KeyBackupService.hasBackup] renvoie `false` sur toute
  /// erreur (y compris réseau), donc une panne réseau au login peut faire
  /// générer des clés neuves alors qu'un backup existe. C'est déjà le
  /// comportement historique (génération inconditionnelle) ; à durcir plus tard
  /// en distinguant « absent » de « injoignable ».
  Future<void> bootstrap(String userId) async {
    try {
      final storage = _ref.read(secureKeyStorageProvider);
      await storage.initialize();

      final keyManager = _ref.read(keyManagerServiceProvider);
      final hasKeys = await keyManager.hasKeys(userId);

      if (hasKeys) {
        // Clés déjà présentes : initialise le service (re-publie sur Supabase si
        // la publication initiale avait échoué). Aucun prompt.
        await _ref.read(messagingE2EEServiceProvider).initialize(userId);
        state = E2EEBackupPrompt.none;
        return;
      }

      // Pas de clés locales : une sauvegarde distante est-elle disponible ?
      final backupService = _ref.read(keyBackupServiceProvider);
      final hasBackup = await backupService.hasBackup(userId);

      if (hasBackup) {
        // On NE génère PAS : cela créerait une identité neuve, rendrait le backup
        // irrécupérable et casserait les sessions existantes. On propose la
        // restauration ; les clés seront initialisées après restauration réussie.
        state = E2EEBackupPrompt.needsRestore;
        return;
      }

      // Premier appareil, aucun backup : générer les clés puis inviter à sauvegarder.
      await _ref.read(messagingE2EEServiceProvider).initialize(userId);
      state = E2EEBackupPrompt.needsBackup;
    } catch (e) {
      debugPrint('E2EEBackupCoordinator: bootstrap failed: $e');
      // En cas d'échec, ne rien proposer à tort : rester silencieux.
      state = E2EEBackupPrompt.none;
    }
  }

  /// L'utilisateur a traité (ou reporté) le prompt : on l'efface pour cette session.
  void acknowledge() => state = E2EEBackupPrompt.none;
}
