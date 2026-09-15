import 'package:flutter/foundation.dart';

import '../../../features/messages/domain/entities/message_entity.dart';
import 'mls_conversation_service.dart';
import 'mls_delivery.dart';
import 'mls_message_mapper.dart';
import 'mls_metadonnees.dart';
import 'mls_payload_codec.dart';

/// Le point d'entrée unique de MLS pour la couche messages (plan MLS § 7.3).
///
/// Tout le reste de l'application ignore MLS : le repository lui demande
/// « cette conversation est-elle chiffrée ? », « donne-moi ses messages »,
/// « envoie celui-ci », et rien d'autre. C'est ce qui permet de brancher la
/// coexistence en une vingtaine de lignes au lieu d'essaimer des conditions
/// dans 81 fichiers.
///
/// **La règle du repli, et sa seule exception.** Une fois la conversation
/// basculée (`mls_since` posé), il n'existe aucun chemin de retour : le
/// serveur refuse d'écrire en clair dans `messages`, et un envoi MLS qui
/// échoue doit échouer visiblement. C'est ce repli muet qui a laissé le
/// chantier Signal envoyer en clair pendant des semaines pendant que tout
/// paraissait marcher. **Avant** la bascule, en revanche, rien n'est engagé :
/// un échec peut encore emprunter le chemin d'aujourd'hui, et ça se lit en
/// base — `mls_since` est resté nul.
class MlsGateway {
  MlsGateway({
    required this.userId,
    required bool Function() actif,
    required MlsConversationService service,
    required MlsDelivery delivery,
    MlsMetadonnees? metadonnees,
    Future<String?> Function(String userId)? nomDe,
  })  : _actif = actif,
        _service = service,
        _delivery = delivery,
        _meta = metadonnees ?? MlsMetadonnees(userId: userId),
        _nomDe = nomDe;

  final String userId;
  final bool Function() _actif;
  final MlsConversationService _service;
  final MlsDelivery _delivery;
  final MlsMetadonnees _meta;
  final Future<String?> Function(String userId)? _nomDe;

  /// `mls_since` par conversation, pour ne pas le redemander à chaque
  /// pagination. Une conversation ne se débascule jamais : une valeur non
  /// nulle est définitive, donc sûre à retenir.
  final Map<String, DateTime?> _bascule = {};
  final Map<String, String> _noms = {};

  /// Les identifiants de messages qu'on sait être des messages MLS, parce
  /// qu'on vient de les lire. Un message qu'on peut toucher est un message
  /// qu'on voit, donc qui est passé par [messages] : l'aller-retour vers la
  /// base ne sert qu'au cas d'école — action sur un message reçu depuis, ou
  /// écran rouvert sans relecture.
  final Set<String> _connus = {};

  /// Le fil déchiffré de chaque conversation, tel quel — sans métadonnées,
  /// qui sont recollées à la sortie parce qu'elles bougent sans message
  /// nouveau. `catchUp` ne rendant que le delta, c'est ici que le fil
  /// existe en entier.
  final Map<String, List<MessageEntity>> _fil = {};

  /// Le drapeau est lu à chaque appel, pas au démarrage : l'ouvrir ne doit
  /// pas demander de relancer l'application.
  bool get actif => _actif();

  /// Au moins une conversation vue est basculée.
  ///
  /// Sert à ne rien demander au serveur quand il n'y a rien à demander :
  /// refermer le drapeau n'annule pas les conversations déjà basculées, et
  /// elles gardent leurs compteurs.
  bool get aDesConversationsBasculees =>
      _bascule.values.any((date) => date != null);

  /// Date de bascule de la conversation, `null` si elle est encore en clair.
  Future<DateTime?> mlsSince(String conversationId) async {
    if (_bascule[conversationId] != null) return _bascule[conversationId];
    final row = await _delivery.conversation(conversationId);
    final brut = row?['mls_since'] as String?;
    final date = brut == null ? null : DateTime.tryParse(brut);
    _bascule[conversationId] = date;
    return date;
  }

  /// Vrai quand les messages de cette conversation passent par MLS.
  ///
  /// Une conversation **déjà basculée** reste lue par MLS même si le drapeau
  /// est refermé : sinon, refermer le drapeau rendrait illisibles des
  /// messages déjà envoyés.
  Future<bool> enMls(String conversationId) async {
    if (await mlsSince(conversationId) != null) return true;
    return actif;
  }

  /// Les messages MLS de la conversation, prêts pour l'écran.
  ///
  /// **Le fil entier, pas le dernier lot.** `catchUp` est incrémental par
  /// construction — le cliquet ne déchiffre jamais deux fois, et il saute
  /// mes propres messages, dont il ne sait pas relire le clair. Rendre son
  /// résultat tel quel viderait l'écran au deuxième affichage : la fusion
  /// retombe sur le legacy seul quand le côté MLS est vide, et tout ce qui a
  /// été dit depuis la bascule paraîtrait effacé. Le fil déchiffré est donc
  /// gardé ici, et complété à chaque passage.
  ///
  /// Le déchiffrement ne donne que le contenu : réactions, coches de lecture,
  /// favoris, « supprimé pour moi » et « supprimé pour tous » vivent dans les
  /// tables annexes (décision J) et sont recollés à chaque appel — eux
  /// changent sans qu'un nouveau message arrive.
  Future<List<MessageEntity>> messages(String conversationId) async {
    final entrants = await _service.catchUp(conversationId);
    final fil = _fil[conversationId] ??= [];
    final deja = {for (final m in fil) m.id};
    for (final e in entrants) {
      if (!deja.add(e.row.id)) continue;
      fil.add(MlsMessageMapper.depuisEntrant(
        e,
        senderName: await _nom(e.row.senderId),
        currentUserId: userId,
      ));
    }
    fil.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    _connus.addAll(deja);
    return _avecMetadonnees(List.of(fil));
  }

  /// Recolle les métadonnées en ligne sur un fil déjà déchiffré.
  Future<List<MessageEntity>> _avecMetadonnees(List<MessageEntity> fil) async {
    if (fil.isEmpty) return fil;
    final lot = await _meta.pour(fil.map((m) => m.id));
    if (lot.estVide) return fil;
    return [
      for (final m in fil)
        m.copyWith(
          reactions: lot.reactions[m.id] ?? const {},
          readBy: lot.lecteurs[m.id] ??
              // L'expéditeur a forcément lu le sien : le mapper l'a déjà posé,
              // et aucune ligne de reçu ne viendra le dire.
              (m.senderId == userId ? [userId] : const <String>[]),
          readAt: lot.luA[m.id] ?? const {},
          deliveredTo: lot.destinataires[m.id] ?? const [],
          deliveredAt: lot.livreA[m.id] ?? const {},
          starredBy: lot.etoiles.contains(m.id) ? [userId] : const [],
          deletedFor: lot.masques.contains(m.id) ? [userId] : const [],
          // Jamais dégradé : un message déjà su supprimé le reste, même si
          // la requête d'en face est revenue vide.
          deletedForEveryone:
              m.deletedForEveryone || lot.supprimes.contains(m.id),
        ),
    ];
  }

  /// Envoie un message texte.
  Future<MessageEntity> envoyerTexte({
    required String conversationId,
    required String texte,
    required String senderName,
    String? senderPhotoUrl,
    String? replyToId,
    Map<String, dynamic>? replyToMessageData,
  }) =>
      envoyer(
        conversationId: conversationId,
        type: 'text',
        body: {'content': texte},
        senderName: senderName,
        senderPhotoUrl: senderPhotoUrl,
        replyToId: replyToId,
        replyToMessageData: replyToMessageData,
      );

  /// Envoie n'importe quel type de message — texte, média, note vocale,
  /// position, sondage, sticker.
  ///
  /// **Tout ce qui décrit le message passe par [body], donc par le
  /// chiffrement** : la légende, le nom du fichier, la clé du média, les
  /// coordonnées. C'est ce que le legacy laissait fuir à côté d'un `content`
  /// chiffré, et ce que le payload MLS (§ 6.2) referme. Le serveur n'apprend
  /// que le `content_type`, gardé grossier.
  ///
  /// Lève si la conversation est basculée et que MLS échoue — c'est voulu
  /// (cf. la règle du repli en tête de classe).
  Future<MessageEntity> envoyer({
    required String conversationId,
    required String type,
    required Map<String, dynamic> body,
    required String senderName,
    String? senderPhotoUrl,
    String? replyToId,
    Map<String, dynamic>? replyToMessageData,
    List<String> mentions = const [],
    bool forwarded = false,
  }) async {
    await _service.ensureGroup(conversationId);
    await _service.reconcileMembership(conversationId);
    _bascule.remove(conversationId); // la bascule vient peut-être d'avoir lieu

    final payload = MlsPayload(
      id: '',
      type: type,
      sentAt: DateTime.now().millisecondsSinceEpoch,
      body: body,
      replyTo: replyToMessageData == null && replyToId == null
          ? null
          : {'id': replyToId, ...?replyToMessageData},
      mentions: mentions,
      forwarded: forwarded,
    );
    final row = await _service.send(
      conversationId,
      payload,
      contentType: MlsMessageMapper.contentType(type),
    );
    _connus.add(row.id);
    // Les mentions sont en ligne (décision J) : le serveur doit savoir QUI
    // est mentionné pour faire sonner un groupe muet, sans rien déchiffrer.
    // Posées après l'insertion — le RLS les réserve à l'expéditeur du
    // message, qui doit donc exister — et sans faire échouer l'envoi.
    if (mentions.isNotEmpty) {
      await _meta.poserMentions(row.id, mentions);
    }
    final envoye = MlsMessageMapper.depuisPayload(
      MlsPayload(
        id: row.id,
        type: payload.type,
        sentAt: payload.sentAt,
        body: payload.body,
        replyTo: payload.replyTo,
        mentions: payload.mentions,
        forwarded: payload.forwarded,
      ),
      row: row,
      senderName: senderName,
      senderPhotoUrl: senderPhotoUrl,
      currentUserId: userId,
    );
    // `catchUp` saute mes propres messages : sans cette ligne, celui-ci
    // disparaîtrait de l'écran au premier rafraîchissement.
    (_fil[conversationId] ??= []).add(envoye);
    return envoye;
  }

  /// Le corps d'un média, clé de fichier comprise (plan § 9).
  ///
  /// La clé voyageait jusqu'ici dans `encAnnexes`, chiffré avec la clé
  /// **dérivée** de la conversation — que le serveur sait reconstruire. Ici
  /// elle entre dans le payload MLS : le serveur ne peut plus la lire, donc
  /// plus ouvrir le fichier. C'est ce qui achève le chiffrement des pièces
  /// jointes commencé en C4.
  static Map<String, dynamic> corpsMedia({
    String? legende,
    required String storagePath,
    required String fileName,
    required String mimeType,
    required int fileSize,
    String? fileKey,
    String? fileNonce,
    String? blurhash,
    int? duration,
    List<double>? waveform,
  }) =>
      {
        if (legende != null && legende.isNotEmpty) 'content': legende,
        'storagePath': storagePath,
        'fileName': fileName,
        'mimeType': mimeType,
        'fileSize': fileSize,
        if (fileKey != null) 'fileKey': fileKey,
        if (fileNonce != null) 'fileNonce': fileNonce,
        if (blurhash != null) 'blurhash': blurhash,
        if (duration != null) 'duration': duration,
        if (waveform != null) 'waveform': waveform,
      };

  /// Un envoi peut-il encore emprunter le chemin d'aujourd'hui ?
  ///
  /// Seulement si rien n'est engagé. Une fois `mls_since` posé, la réponse
  /// est non, définitivement — et le serveur la ferait respecter de toute
  /// façon.
  Future<bool> repliLegacyPossible(String conversationId) async =>
      await mlsSince(conversationId) == null;

  /// Ce que le serveur annonçait la dernière fois qu'on l'a regardé.
  final Map<String, Set<String>> _appartenanceVue = {};

  /// Le serveur vient d'annoncer une liste de participants pour cette
  /// conversation.
  ///
  /// **Pourquoi ce point d'entrée existe.** La réconciliation ne tournait
  /// qu'à l'envoi : exclure quelqu'un d'un groupe ne le sortait de l'arbre
  /// MLS qu'au prochain message de quelqu'un d'autre — tardif, jamais faux
  /// (le retrait précède le chiffrement, donc l'exclu ne lit rien de neuf),
  /// mais tardif quand même, et un arrivant attendait ce même message pour
  /// recevoir son Welcome. Ici, le changement agit au moment où il a lieu.
  ///
  /// C'est branché sur le flux de la conversation, et non sur les six
  /// appelants qui touchent à l'appartenance (adhésion, départ, exclusion,
  /// invitation acceptée, groupe officiel, et la RPC `leave_group_
  /// conversation`) : la moitié d'entre eux écrit `group_members`, et c'est
  /// un **déclencheur** serveur qui recopie dans `participant_ids` — aucun
  /// site d'appel Dart ne le voit passer. La ligne de conversation, elle,
  /// les voit tous.
  ///
  /// Trois refus, dans cet ordre, pour que ça ne coûte rien :
  /// - une conversation pas encore basculée n'a pas d'arbre à réconcilier ;
  /// - la **première** vue ne déclenche rien, elle ne fait qu'enregistrer :
  ///   ouvrir une discussion ne doit pas lancer un balayage des appareils de
  ///   tous les participants, que `catchUp` et l'envoi couvrent déjà ;
  /// - une liste identique à la précédente ne déclenche rien non plus.
  ///
  /// Échoue en silence. Plusieurs membres en ligne réagissent au même
  /// changement : un seul gagne l'epoch, les autres reçoivent un 23505, le
  /// jettent et retrouvent le travail fait (§ 5.4). Et si tout rate, le
  /// filet d'avant est intact — le prochain envoi réconciliera.
  Future<void> appartenanceChangee(
    String conversationId,
    List<String> participants,
  ) async {
    final maintenant = participants.toSet();
    final vue = _appartenanceVue[conversationId];
    if (vue != null &&
        vue.length == maintenant.length &&
        vue.containsAll(maintenant)) {
      return;
    }
    if (!await enMls(conversationId)) return;

    _appartenanceVue[conversationId] = maintenant;
    if (vue == null) return; // première vue : on enregistre, on n'agit pas.

    try {
      await _service.ensureGroup(conversationId);
      await _service.reconcileMembership(conversationId);
    } catch (e) {
      // On remet la liste **d'avant**, pas rien du tout : effacer l'entrée
      // ferait passer le signal suivant pour une première vue, et la règle
      // « la première vue n'agit pas » avalerait le rattrapage pour de bon.
      // Trouvé par `mls_appartenance_test.dart`.
      _appartenanceVue[conversationId] = vue;
      debugPrint('MlsGateway: appartenance non réconciliée ($e)');
    }
  }

  // ── Les actions sur un message (décision J) ──────────────────────────────
  //
  // Réagir, étoiler, masquer, supprimer, accuser réception : autant de
  // chemins qui écrivaient dans `messages`, où un message MLS n'a AUCUNE
  // ligne. Sans aiguillage, chacun de ces gestes ne touche rien — et Postgres
  // ne s'en plaint pas : un `update … where id = …` sans cible réussit avec
  // zéro ligne. Le tap paraîtrait simplement « ne pas prendre ».

  /// Cette action porte-t-elle sur un message MLS ?
  ///
  /// **Une erreur remonte au lieu de répondre « non ».** Répondre « non »
  /// renverrait l'action vers `messages`, où elle ne trouverait rien et
  /// réussirait à vide : la panne se lirait comme un bouton mort. Mieux vaut
  /// un message d'erreur.
  Future<bool> estMlsMessage(String conversationId, String messageId) async {
    if (_connus.contains(messageId)) return true;
    if (!await enMls(conversationId)) return false;
    final present = await _meta.existe(messageId);
    if (present) _connus.add(messageId);
    return present;
  }

  /// Une réaction par personne : poser remplace, reposer le même retire —
  /// c'est l'appelant qui sait lequel des deux il veut.
  Future<void> reagir(String messageId, String emoji) =>
      _meta.poserReaction(messageId, emoji);

  Future<void> retirerReaction(String messageId) =>
      _meta.retirerReaction(messageId);

  /// Bascule le favori et rend son nouvel état, relu en base — le message a
  /// pu être étoilé depuis un autre appareil.
  Future<bool> basculerEtoile(String messageId) =>
      _meta.basculerEtoile(messageId);

  /// « Supprimer pour moi » — sur tous mes appareils, pas seulement celui-ci.
  Future<void> supprimerPourMoi(String messageId) => _meta.masquer(messageId);

  /// « Supprimer pour tous » — le serveur cesse de servir le ciphertext.
  /// Réservé à l'expéditeur par le RLS.
  Future<void> supprimerPourTous(String messageId) =>
      _meta.supprimerPourTous(messageId);

  /// Modifier un message chiffré n'est **pas** branché : le nouveau texte
  /// doit voyager chiffré, dans un message de contrôle, et rien ne l'émet
  /// encore. L'appelant doit refuser visiblement — laisser passer écrirait
  /// dans `messages`, sans cible, et le texte d'avant réapparaîtrait à la
  /// réouverture, sans la moindre erreur.
  static const modificationBranchee = false;

  /// Accuse réception de tous les messages des autres dans la conversation.
  ///
  /// Conversation entière, comme le chemin d'aujourd'hui (`markAsRead` ne
  /// prend pas d'identifiant de message) : les reçus manquants sont créés,
  /// les existants avancés.
  Future<void> marquerLus(String conversationId) async {
    final ids = await _meta.messagesDesAutres(conversationId);
    await _meta.marquer(ids, lu: true);
  }

  Future<void> marquerLivres(String conversationId) async {
    final ids = await _meta.messagesDesAutres(conversationId);
    await _meta.marquer(ids, lu: false);
  }

  /// Les compteurs de non-lus des conversations basculées, depuis la vue.
  Future<Map<String, ({int nonLus, int mentions})>> nonLus() => _meta.nonLus();

  Future<String> _nom(String id) async {
    if (id == userId) return '';
    final connu = _noms[id];
    if (connu != null) return connu;
    try {
      final nom = await _nomDe?.call(id);
      if (nom != null && nom.isNotEmpty) {
        _noms[id] = nom;
        return nom;
      }
    } catch (e) {
      debugPrint('MlsGateway: nom introuvable pour $id ($e)');
    }
    return '';
  }

  @visibleForTesting
  void oublierBascule(String conversationId) => _bascule.remove(conversationId);
}
