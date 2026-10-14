part of 'message_supabase_datasource.dart';

/// Retouches d'un message : modification, suppression, réactions, épingles.
mixin _Retouches on _MessageSupabaseBase {
  // ═══════════════════════════════════════════════════════════════════════════
  // MESSAGE MUTATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Future<void> deleteMessageForMe({
    required String conversationId,
    required String messageId,
    required String userId,
  }) async {
    try {
      await _mergeMsgData(messageId, {
        'deletedFor': userId,
      }, appendToList: true);
    } catch (e) {
      throw ServerException('deleteMessageForMe error: $e');
    }
  }

  @override
  Future<void> deleteMessageForEveryone({
    required String conversationId,
    required String messageId,
  }) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();

      // Une instruction (`modifier_donnees_message`, 20261005100000) : relire
      // `data` pour le réécrire vidé effaçait un « Lu » ou une réaction
      // arrivés entre les deux. Rend `null` si aucune ligne n'a bougé.
      final supprime = await _supabase.rpc('modifier_donnees_message', params: {
        'p_message_id': messageId,
        'p_fusion': {
          'deletedForEveryone': true,
          'deletedAt': now,
          'content': '',
        },
        'p_retirer': [
          'fileUrl',
          'thumbnailUrl',
          // Une carte de partage survivait à « supprimer pour tout le
          // monde » : le contenu partait, l'aperçu — titre, extrait, image,
          // URL cible — restait en base. La forme chiffrée comme les
          // anciennes en clair.
          _kAnnexesChiffrees,
          // La clé d'un média chiffré part avec lui : le blob Storage
          // restant devient définitivement illisible.
          _kMediaChiffre,
          ..._kChampsAnnexes,
        ],
        'p_supprime': true,
      });
      if (supprime == null) return;

      // Retire l'épingle éventuelle : sans ça le bandeau garde une entrée
      // fantôme (« Appuyez pour voir ») vers un message qui n'existe plus.
      // RLS sans droit d'épinglage ⇒ 0 ligne supprimée, sans erreur.
      await _supabase
          .from('group_pinned_items')
          .delete()
          .eq('item_type', 'message')
          .eq('item_id', messageId);

      // Et l'aperçu de la liste des discussions, qui porte le même texte en
      // clair. Sans lui, la bulle dit « Message supprimé » pendant que son
      // contenu reste parfaitement lisible une ligne plus haut.
      await _viderApercuSiDernier(conversationId, messageId);
    } catch (e) {
      throw ServerException('deleteMessageForEveryone error: $e');
    }
  }

  /// Vide `conversations.data->>'lastMessage'` quand le message supprimé était
  /// le dernier de la conversation, et pose la marque qui dit pourquoi.
  ///
  /// **L'échec ne fait pas échouer la suppression, mais il ne se tait pas.**
  /// Le premier jet relevait l'exception, au motif qu'« une erreur remontée
  /// est réparable ». Elle ne l'était pas : `deleteMessageProvider` n'est
  /// jamais `watch`é — seulement lu par `.notifier` —, la modale de
  /// suppression se referme **avant** l'appel, et son `onDeleted` n'est même
  /// pas fourni par `message_bubble.dart`. Un `throw` d'ici n'atteignait donc
  /// ni l'écran ni un journal : il coûtait une invalidation du fil, et rien
  /// d'autre. L'usager ne peut pas réessayer non plus — le message porte déjà
  /// sa pierre tombale, et « supprimer pour tout le monde » ne lui est plus
  /// proposé dessus.
  ///
  /// D'où [signalerEchecSilencieux], qui est exactement fait pour ça :
  /// « ne pas faire échouer » n'est pas « ne rien dire ». La fuite devient
  /// visible dans Crashlytics au lieu de n'exister nulle part.
  ///
  /// `vider_apercu_si_dernier` (20261005100000) fait la comparaison et
  /// l'écriture dans une seule instruction, au critère de
  /// `purger_messages_expires()` : `last_message_at`, recopié du `created_at`
  /// du message par `apres_envoi_message` (20261005090000), égale celui du
  /// message supprimé. Relire puis réécrire `data` effaçait une sourdine ou
  /// un message arrivés entre les deux.
  Future<void> _viderApercuSiDernier(
    String conversationId,
    String messageId,
  ) async {
    try {
      await _supabase.rpc('vider_apercu_si_dernier', params: {
        'p_conversation_id': conversationId,
        'p_message_id': messageId,
      });
    } catch (e) {
      signalerEchecSilencieux(e, contexte: 'apercu du message supprime');
    }
  }

  @override
  Future<void> addReaction({
    required String conversationId,
    required String messageId,
    required String userId,
    required String emoji,
  }) async {
    try {
      await _setReaction(messageId: messageId, userId: userId, emoji: emoji);
    } catch (e) {
      throw ServerException('addReaction error: $e');
    }
  }

  @override
  Future<void> removeReaction({
    required String conversationId,
    required String messageId,
    required String userId,
  }) async {
    try {
      await _setReaction(messageId: messageId, userId: userId, emoji: null);
    } catch (e) {
      throw ServerException('removeReaction error: $e');
    }
  }

  /// Pose (`emoji`) ou retire (`null`) la réaction de l'utilisateur courant.
  ///
  /// Passe par `set_message_reaction`, qui ne touche que `reactions.<uid>` au
  /// moment de l'UPDATE et notifie l'auteur. L'ancienne écriture relisait
  /// `data` en entier puis le réécrivait : un accusé de lecture ou la réaction
  /// d'un autre membre posés entre les deux étaient écrasés, et aucune
  /// notification ne partait. Elle a quitté aussi le repli sur `PGRST202` :
  /// 20260912220000 précède 20261004100000, dont l'app dépend déjà.
  Future<void> _setReaction({
    required String messageId,
    required String userId,
    required String? emoji,
  }) async {
    if (!await SupabaseAuthBridge.instance.ensureAuthenticated()) {
      throw ServerException('setReaction: not authenticated');
    }
    await _supabase.rpc(
      'set_message_reaction',
      params: {'p_message_id': messageId, 'p_emoji': emoji},
    );
  }

  @override
  Future<void> toggleStarMessage({
    required String conversationId,
    required String messageId,
    required String userId,
  }) async {
    // Bascule faite DANS l'UPDATE (`basculer_dans_liste_message`) : réécrire
    // `data` entier pour une étoile effaçait un « Lu » arrivé entre-temps.
    try {
      await _supabase.rpc('basculer_dans_liste_message', params: {
        'p_message_id': messageId,
        'p_cle': 'starredBy',
        'p_valeur': userId,
      });
    } catch (e) {
      throw ServerException('toggleStarMessage error: $e');
    }
  }

  /// Modifie le texte d'un message, **rechiffré** comme à l'envoi.
  ///
  /// [oldContent] n'est plus écrit nulle part : l'historique ne conserve que la
  /// date des modifications. Le paramètre reste à la signature parce que
  /// l'appelant s'en sert pour revenir en arrière si l'écriture échoue.
  @override
  Future<void> editMessage({
    required String conversationId,
    required String messageId,
    required String newContent,
    required String oldContent,
  }) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();

      final rows = await _supabase
          .from('messages')
          .select('sender_id')
          .eq('id', messageId)
          .limit(1);
      // Aucune ligne : ce message n'est PAS dans `messages`. C'est le cas d'un
      // message MLS, dont la ligne vit dans `mls_messages` — l'aiguillage a
      // manqué sa cible. Le `return` muet d'avant faisait croire au succès :
      // l'écran affichait « Message modifié », le nouveau texte restait en
      // optimiste, et le texte d'avant revenait à la moindre relecture.
      // Constaté sur SM A515F le 2026-09-15 (aucun message de contrôle émis
      // côté MLS pour deux modifications annoncées réussies). Un geste sans
      // effet doit se voir.
      if (rows.isEmpty) {
        // On ne sait toujours pas POURQUOI l'aiguillage manque sa cible : le
        // cas ne se provoque pas depuis l'interface (pour qu'une bulle MLS
        // s'affiche, son fil a forcément été amorcé, donc son identifiant est
        // déjà connu de la passerelle). Alors on fait parler la prochaine
        // occurrence : l'erreur emporte l'état de bascule de la conversation,
        // qui est précisément l'entrée dont dépend la décision.
        String bascule;
        try {
          final conv = await _supabase
              .from('conversations')
              .select('mls_since')
              .eq('id', conversationId)
              .maybeSingle();
          bascule = conv == null
              ? 'conversation introuvable (RLS ?)'
              : 'mls_since=${conv['mls_since'] ?? 'null'}';
        } catch (e) {
          bascule = 'lecture de mls_since impossible : $e';
        }
        throw ServerException(
          'editMessage : aucun message $messageId dans `messages` — '
          'message chiffré ? aiguillage MLS manqué [$bascule]',
        );
      }
      // Le message modifié est forcément celui de son auteur (`canEdit` le
      // vérifie côté appelant) : sa ligne porte donc l'identifiant dont la
      // résolution du destinataire a besoin.
      final senderId = (rows.first['sender_id'] as String?) ?? '';

      // Rechiffrer par le chemin de l'envoi. Sans ça, `data['content']`
      // repartait en clair : modifier un message annulait son chiffrement, et
      // `encryptionLevel` continuait d'annoncer 'e2ee' par-dessus.
      final cible = await _cibleChiffrement(conversationId, senderId);
      final cryptoFields = await _encryptContent(
        plaintext: newContent,
        recipientId: cible.recipientId,
        participantIds: cible.participantIds,
        conversationId: conversationId,
        selfNote: cible.selfNote,
      );

      // Une instruction (`modifier_donnees_message`, 20261005100000) :
      // réécrire `data` entier après le rechiffrement effaçait un « Lu », une
      // réaction ou une étoile posés pendant ce temps.
      await _supabase.rpc('modifier_donnees_message', params: {
        'p_message_id': messageId,
        // Purger les charges de la version précédente AVANT d'appliquer les
        // nouvelles (la fonction retire, puis fusionne) : `decrypt` reconnaît
        // les formats dans un ordre fixe, et un `senderKeyPayload` périmé
        // resté à côté d'un `e2eePayloads` neuf serait lu en premier — le
        // message deviendrait illisible sans rien signaler.
        'p_retirer': ['e2eePayloads', 'e2eePayload', 'senderKeyPayload'],
        'p_fusion': {...cryptoFields, 'editedAt': now},
        // L'historique ne garde plus le texte d'avant. Il reposait en clair à
        // côté d'un contenu chiffré, et **rien ne l'affiche** : aucun écran
        // ne lit `editHistory`, seul le modèle le transporte. On garde la
        // trace du passage — combien de modifications, et quand — sans le
        // contenu.
        'p_ajouts': {
          'editHistory': {'editedAt': now},
        },
      });
    } catch (e) {
      throw ServerException('editMessage error: $e');
    }
  }

  @override
  Future<void> reportMessage({
    required String conversationId,
    required String messageId,
    required String userId,
    required String reason,
  }) async {
    await _mergeMsgData(messageId, {'reportedBy': userId}, appendToList: true);
  }

  @override
  Future<void> reportGroup({
    required String conversationId,
    required String userId,
    required String reason,
  }) async {
    try {
      await _supabase.rpc('modifier_donnees_conversation', params: {
        'p_conversation_id': conversationId,
        'p_ajouts': {'reportedBy': userId},
      });
    } catch (e) {
      throw ServerException('reportGroup error: $e');
    }
  }
}
