import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'key_backup_service.dart';
import 'key_manager_service.dart';
import 'key_transfer_service.dart';
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

/// Vrai quand le rappel de restauration des clés est en veille : tout bandeau
/// qui le répète doit se taire.
///
/// L'état du coordinateur ne suffit pas : il ne porte que ce que `MainShell`
/// doit afficher, et retombe à `none` dans des cas où le bandeau de
/// conversation, lui, s'affiche quand même (un message indéchiffrable dans un
/// fil alors que l'appareil a bien ses clés).
final e2eeRestoreNudgeMutedProvider = StateProvider<bool>((ref) => false);

/// Aiguille le démarrage E2EE à la connexion et décide s'il faut proposer une
/// sauvegarde ou une restauration des clés — sans jamais écraser une identité
/// restaurable par des clés neuves.
class E2EEBackupCoordinator extends StateNotifier<E2EEBackupPrompt> {
  E2EEBackupCoordinator(this._ref) : super(E2EEBackupPrompt.none);

  final Ref _ref;

  /// Compte pour lequel `bootstrap` a déjà tourné dans cette session.
  ///
  /// `bootstrap` est appelé depuis QUATRE endroits d'`AuthNotifier` (connexion,
  /// inscription, restauration de session, réponse tardive du profil). Sans
  /// cette garde, chacun replaçait le bandeau — y compris juste après que la
  /// personne l'ait écarté.
  String? _bootstrappedFor;

  /// Compte courant, retenu pour qu'`acknowledge()` sache quoi persister.
  String? _userId;

  /// Durée pendant laquelle un bandeau écarté ne revient pas.
  ///
  /// `acknowledge()` ne vivait qu'en mémoire : le bandeau revenait à chaque
  /// démarrage de l'application, indéfiniment, puisque `needsRestore` reste
  /// vrai tant que la sauvegarde n'est pas restaurée. C'est ce qui le faisait
  /// apparaître « très souvent ».
  static const _snoozeDuration = Duration(days: 7);

  /// Valeur écrite à la place d'un horodatage par [dismissForever]. Une date ne
  /// sait pas dire « plus jamais » ; un entier que `millisecondsSinceEpoch` ne
  /// produit jamais le dit, sans seconde clé à maintenir ni à effacer.
  static const _mutedForever = -1;

  static String _snoozeKey(String userId, E2EEBackupPrompt prompt) =>
      'e2ee_prompt_snoozed_${prompt.name}_$userId';

  Future<bool> _isSnoozed(String userId, E2EEBackupPrompt prompt) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final at = prefs.getInt(_snoozeKey(userId, prompt));
      if (at == null) return false;
      if (at == _mutedForever) return true;
      final since = DateTime.now().difference(
        DateTime.fromMillisecondsSinceEpoch(at),
      );
      return since < _snoozeDuration;
    } catch (e) {
      debugPrint('E2EEBackupCoordinator: _isSnoozed failed: $e');
      return false;
    }
  }

  Future<void> _snooze(String userId, E2EEBackupPrompt prompt) =>
      _writeSnooze(userId, prompt, DateTime.now().millisecondsSinceEpoch);

  Future<void> _muteForever(String userId, E2EEBackupPrompt prompt) =>
      _writeSnooze(userId, prompt, _mutedForever);

  Future<void> _writeSnooze(
    String userId,
    E2EEBackupPrompt prompt,
    int value,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_snoozeKey(userId, prompt), value);
    } catch (e) {
      // Sans persistance, on retombe sur l'ancien comportement : le bandeau
      // reviendra au prochain démarrage. Pas de quoi bloquer la connexion.
      debugPrint('E2EEBackupCoordinator: _writeSnooze failed: $e');
    }
  }

  /// Reprend le rendez-vous de transfert scanné avant la connexion.
  ///
  /// Best-effort : un échec (rendez-vous expiré, réseau) laisse simplement
  /// l'aiguillage habituel décider — mieux vaut proposer une restauration que
  /// bloquer la connexion.
  Future<bool> _claimPendingTransfer(String userId) async {
    final transfert = _ref.read(keyTransferServiceProvider);
    try {
      final invite = await transfert.pendingInvite();
      if (invite == null) return false;
      if (invite.userId != userId) {
        // Le QR visait un autre compte : il n'a plus rien à faire ici.
        await transfert.forgetPending();
        return false;
      }
      await transfert.claim(invite: invite, userId: userId);
      await transfert.forgetPending();
      debugPrint('E2EEBackupCoordinator: keys claimed from transfer');
      return true;
    } catch (e) {
      debugPrint('E2EEBackupCoordinator: pending transfer failed: $e');
      return false;
    }
  }

  /// Répercute la veille du rappel de restauration sur les bandeaux qui ne
  /// passent pas par l'état du coordinateur — celui de la conversation.
  void _setRestoreNudgeMuted(bool muted) {
    _ref.read(e2eeRestoreNudgeMutedProvider.notifier).state = muted;
  }

  /// Efface la mise en veille : après une vraie sauvegarde ou restauration, il
  /// n'y a plus rien à proposer, et si la situation se represente, elle est
  /// neuve.
  Future<void> clearSnooze(String userId) async {
    _setRestoreNudgeMuted(false);
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final prompt in E2EEBackupPrompt.values) {
        await prefs.remove(_snoozeKey(userId, prompt));
      }
    } catch (_) {}
  }

  /// Aiguille le démarrage E2EE pour [userId]. Best-effort : toute erreur laisse
  /// l'app fonctionner (repli AES) plutôt que de bloquer la connexion.
  ///
  /// - Clés locales présentes        -> initialise (re-publie au besoin), pas de prompt.
  /// - Pas de clés + backup présent   -> `needsRestore`, NE génère PAS de clés
  ///   (générer créerait une nouvelle identité et casserait le déchiffrement).
  /// - Pas de clés + backup absent    -> génère les clés puis `needsBackup`.
  /// - Pas de clés + statut inconnu   -> NE génère PAS non plus (le backup peut
  ///   exister mais être injoignable) ; aucun prompt, réévalué au prochain login.
  Future<void> bootstrap(String userId) async {
    if (_bootstrappedFor == userId) return;
    _bootstrappedFor = userId;
    _userId = userId;
    try {
      // Relevé avant tout aiguillage : le bandeau de conversation s'y fie même
      // dans les branches où le coordinateur n'a rien à proposer.
      final restoreSnoozed = await _isSnoozed(
        userId,
        E2EEBackupPrompt.needsRestore,
      );
      _setRestoreNudgeMuted(restoreSnoozed);

      final storage = _ref.read(secureKeyStorageProvider);
      await storage.initialize();

      // Un transfert scanné avant la connexion attend ici : il prime sur tout
      // le reste, puisqu'il apporte l'identité que les autres branches
      // essaieraient de restaurer ou de recréer.
      if (await _claimPendingTransfer(userId)) {
        await _ref.read(messagingE2EEServiceProvider).initialize(userId);
        state = E2EEBackupPrompt.none;
        return;
      }

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
      final presence = await backupService.checkBackupPresence(userId);

      switch (presence) {
        case BackupPresence.present:
          // On NE génère PAS : cela créerait une identité neuve, rendrait le
          // backup irrécupérable et casserait les sessions existantes. On
          // propose la restauration ; les clés seront initialisées après.
          state = restoreSnoozed
              ? E2EEBackupPrompt.none
              : E2EEBackupPrompt.needsRestore;

        case BackupPresence.absent:
          // Premier appareil, aucun backup confirmé : générer puis inviter à
          // sauvegarder.
          await _ref.read(messagingE2EEServiceProvider).initialize(userId);
          state = await _isSnoozed(userId, E2EEBackupPrompt.needsBackup)
              ? E2EEBackupPrompt.none
              : E2EEBackupPrompt.needsBackup;

        case BackupPresence.unknown:
          // Statut de backup indéterminé (réseau/permission/quota) : ne PAS
          // générer de clés, on risquerait d'écraser une identité restaurable.
          // Rien à proposer ; le repli AES opère et on réévaluera au prochain
          // login (ou l'utilisateur passera par l'écran de sécurité).
          debugPrint(
            'E2EEBackupCoordinator: backup presence unknown, skipping key generation',
          );
          state = E2EEBackupPrompt.none;
      }
    } catch (e) {
      debugPrint('E2EEBackupCoordinator: bootstrap failed: $e');
      // En cas d'échec, ne rien proposer à tort : rester silencieux.
      state = E2EEBackupPrompt.none;
    }
  }

  /// L'utilisateur a traité (ou reporté) le prompt.
  ///
  /// La mise en veille est **persistée** : sans ça, `needsRestore` étant vrai
  /// tant que la sauvegarde n'est pas restaurée, le bandeau revenait à chaque
  /// démarrage, sans fin.
  void acknowledge() => _dismiss(_snooze);

  /// « Ne plus me le rappeler » : la veille ne s'éteint plus d'elle-même.
  ///
  /// Reste réversible sans passer par le temps — une vraie sauvegarde ou
  /// restauration appelle [clearSnooze], et l'écran demeure atteignable depuis
  /// Réglages › Sécurité.
  void dismissForever() => _dismiss(_muteForever);

  void _dismiss(Future<void> Function(String, E2EEBackupPrompt) persist) {
    final prompt = state;
    final userId = _userId;
    state = E2EEBackupPrompt.none;
    if (userId == null || prompt == E2EEBackupPrompt.none) return;
    if (prompt == E2EEBackupPrompt.needsRestore) _setRestoreNudgeMuted(true);
    unawaited(persist(userId, prompt));
  }
}
