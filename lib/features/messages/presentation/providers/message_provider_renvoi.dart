part of 'message_provider.dart';

// Renvoi automatique des messages restés en attente.

/// Au-delà de ce délai, un message en attente ne repart plus tout seul.
///
/// Il n'est pas perdu pour autant : il reste affiché en échec, avec son
/// bouton « Renvoyer ». Le but est d'éviter qu'un message écrit et oublié
/// il y a trois jours parte à l'improviste au premier retour de réseau.
/// Une fenêtre **nulle** (`Duration.zero`) désactive la condition d'âge : tout
/// ce qui attend repart, quel que soit son âge.
const Duration kFenetreRenvoiAutomatique = Duration(hours: 24);

/// Reconstruit le message tel qu'il doit repartir.
///
/// `messageJson` porte l'entité complète — réponse citée, carte de
/// publication ou d'événement, mentions. Les entrées écrites par les versions
/// précédentes ne l'ont pas : on retombe alors sur les champs plats, qui ne
/// décrivent qu'un texte.
MessageEntity? messageEnAttenteVersEntite(PendingMessage attente) {
  final blob = attente.messageJson;
  if (blob != null) {
    try {
      final json = jsonDecode(blob) as Map<String, dynamic>;
      final entite = MessageModel.fromJson(json).toEntity();
      return entite.copyWith(
        status: MessageStatus.failed,
        // `MessageModel` ne porte pas le chemin local du média : il ne vit que
        // sur l'entité, et c'est lui qu'il faudra re-téléverser.
        localFilePath: attente.filePath,
      );
    } catch (e) {
      debugPrint('message en attente illisible (${attente.id}) : $e');
    }
  }

  if (attente.content.isEmpty) return null;
  return MessageEntity(
    id: attente.id,
    senderId: attente.senderId,
    senderName: attente.senderName,
    senderPhotoUrl: attente.senderPhotoUrl,
    content: attente.content,
    type: MessageType.values.firstWhere(
      (t) => t.name == attente.type,
      orElse: () => MessageType.text,
    ),
    status: MessageStatus.failed,
    createdAt: attente.createdAt,
    readBy: const [],
    readAt: const {},
    localFilePath: attente.filePath,
  );
}

/// Renvoie tout seul les messages jamais partis.
///
/// Tenu en vie par un `ref.watch` dans `app.dart` : sans lui Riverpod ne le
/// construirait jamais, et la file resterait pleine — c'est exactement ce qui
/// se passait avant, `processQueue` n'étant appelé de nulle part.
///
/// ⚠️ N'utilise **pas** `OfflineQueueService.processQueue` : celui-ci
/// **supprime** le message après cinq tentatives. C'est précisément la perte
/// qu'on cherche à éviter — passé les tentatives, le message doit rester
/// affiché et attendre un geste, pas disparaître.
class RenvoiMessagesEnAttente {
  RenvoiMessagesEnAttente(this._ref);

  /// Intervalle du filet de sécurité. Voir [_battement] : c'est lui qui fait
  /// le travail quand le signal de connectivité ment.
  static const Duration intervalleDeControle = Duration(seconds: 60);

  final Ref _ref;
  ProviderSubscription<bool>? _abonnement;
  Timer? _battement;
  bool _enCours = false;

  void demarrer() {
    _abonnement = _ref.listen<bool>(
      connectivityNotifierProvider,
      (avant, apres) {
        if (apres == true && avant != true) unawaited(renvoyerCeQuiPeutPartir());
      },
    );

    // ⚠️ **Le retour du réseau ne suffit pas comme déclencheur**, et c'est
    // vérifié : `ConnectivityService.isConnected` vaut
    // `!results.contains(none)`, or `connectivity_plus` liste `vpn` tant que
    // le tunnel est debout. Sur le SM A515F, qui porte un VPN permanent,
    // couper les deux radios laisse donc l'app **se croire en ligne** : aucune
    // transition `false → true` n'est émise au retour, et ce qui attendait
    // n'est jamais reparti (mesuré le 2026-09-14). La même illusion vaut pour
    // un portail captif ou une connexion qui répond sans router.
    //
    // D'où ce battement, qui ne demande rien à personne : il relit la file et
    // sort immédiatement si elle est vide, ce qui est le cas ordinaire.
    _battement = Timer.periodic(
      intervalleDeControle,
      (_) => unawaited(renvoyerCeQuiPeutPartir()),
    );

    // Un démarrage d'app en ligne n'émet aucune transition : la file laissée
    // par la session précédente doit partir quand même.
    unawaited(renvoyerCeQuiPeutPartir());
  }

  void arreter() {
    _abonnement?.close();
    _abonnement = null;
    _battement?.cancel();
    _battement = null;
  }

  /// Tente un envoi pour chaque message en attente encore éligible.
  ///
  /// Un message est laissé dans la file — donc toujours visible et renvoyable
  /// à la main — quand il est trop vieux, quand son média local a disparu, ou
  /// quand l'envoi échoue encore.
  Future<void> renvoyerCeQuiPeutPartir() async {
    if (_enCours) return;
    _enCours = true;
    try {
      final file = _ref.read(offlineQueueServiceProvider);
      await file.init();
      final enAttente = file.getQueue();
      // Cas ordinaire : rien n'attend, le battement ne coûte qu'une lecture.
      if (enAttente.isEmpty) return;

      const fenetre = kFenetreRenvoiAutomatique;
      final maintenant = DateTime.now();

      for (final attente in enAttente) {
        if (fenetre > Duration.zero &&
            maintenant.difference(attente.createdAt) > fenetre) {
          continue;
        }
        final chemin = attente.filePath;
        if (chemin != null && chemin.isNotEmpty && !File(chemin).existsSync()) {
          // Android a purgé le fichier temporaire : il n'y a plus rien à
          // téléverser. Le message reste en file pour rester visible, mais le
          // renvoyer n'aboutirait qu'à un échec de plus.
          debugPrint('renvoi impossible, média absent : $chemin');
          continue;
        }

        final entite = messageEnAttenteVersEntite(attente);
        if (entite == null) {
          await file.dequeue(attente.id);
          continue;
        }

        try {
          final parti = await _ref
              .read(sendMessageProvider.notifier)
              .retryFailedMessage(
                conversationId: attente.conversationId,
                failedMessage: entite,
                ecritLe: attente.createdAt,
              );
          if (parti) await file.dequeue(attente.id);
        } catch (e) {
          debugPrint('renvoi du message ${attente.id} : $e');
        }
      }
    } catch (e) {
      debugPrint('renvoi des messages en attente : $e');
    } finally {
      _enCours = false;
    }
  }
}

final renvoiMessagesEnAttenteProvider = Provider<RenvoiMessagesEnAttente>((ref) {
  final renvoi = RenvoiMessagesEnAttente(ref)..demarrer();
  ref.onDispose(renvoi.arreter);
  return renvoi;
});
