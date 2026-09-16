import 'package:flutter/foundation.dart';

import '../../../features/messages/domain/entities/message_entity.dart';
import 'mls_conversation_service.dart';
import 'mls_delivery.dart';
import 'mls_message_mapper.dart';
import 'mls_metadonnees.dart';
import 'mls_notification_preview.dart';
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

  /// Modifications reçues dont la cible n'est pas encore dans le fil — un
  /// contrôle peut précéder le chargement du message qu'il vise. Vidée dès
  /// que la cible paraît.
  final Map<String, ({String texte, DateTime quand})> _editions = {};

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
      // Un contrôle n'est pas une bulle : il modifie, supprime ou annote un
      // autre message. L'afficher ferait apparaître une ligne vide dans le
      // fil à chaque réaction.
      if (e.row.kind == 'control') {
        _traiterControle(e);
        continue;
      }
      if (!deja.add(e.row.id)) continue;
      fil.add(MlsMessageMapper.depuisEntrant(
        e,
        senderName: await _nom(e.row.senderId),
        currentUserId: userId,
      ));
    }
    fil.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    _appliquerEditionsEnAttente(fil);
    _connus.addAll(deja);
    return _avecMetadonnees(List.of(fil));
  }

  /// Reprend le fil déchiffré depuis le cache local de l'appareil.
  ///
  /// **C'est ce qui fait tenir une conversation basculée d'un lancement à
  /// l'autre.** Le moteur ne sait pas relire ce qu'il a déjà déchiffré — MLS
  /// supprime le secret d'un message applicatif après usage. Au démarrage, le
  /// serveur n'a donc plus rien de lisible à offrir : seul le cache de
  /// l'appareil garde le clair.
  ///
  /// N'amorce qu'une fois : ensuite c'est le fil en mémoire qui fait foi, et
  /// il contient déjà tout le cache plus ce qui est arrivé depuis.
  void amorcer(String conversationId, List<MessageEntity> caches) {
    // Ne verrouiller le fil que sur un amorçage QUI A QUELQUE CHOSE.
    //
    // `containsKey` tenait tant qu'on supposait le cache toujours lisible au
    // premier appel. Il ne l'est pas : `_mlsDuCache` rend `const []` dès que
    // `mlsSince` est nul, et `mlsSince` vient d'une lecture réseau. Au
    // démarrage à froid, tant qu'elle n'a pas répondu, `enMls` reste vrai par
    // le DRAPEAU DE COMPTE pendant que la date de bascule manque encore. Le
    // premier appel posait alors `_fil[conv] = []`, et `containsKey` faisait
    // sortir tous les suivants : le fil chiffré restait vide pour TOUTE la vie
    // du processus, même une fois `mls_since` connu.
    //
    // Mesuré sur SM A515F le 2026-09-15 : trois messages vivants en base
    // (ciphertext non vide, `is_deleted` faux), aucun à l'écran, et pas une
    // ligne dans `mls_diagnostics` — l'échec ne se signalait nulle part. Le
    // même fil réapparaissait dès qu'on renvoyait un message, ce qui faisait
    // passer la panne pour un caprice d'affichage.
    if (_fil[conversationId]?.isNotEmpty ?? false) return;
    if (caches.isEmpty) return;
    final fil = [...caches]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    _fil[conversationId] = fil;
    _connus.addAll(fil.map((m) => m.id));
  }

  /// Un message de contrôle reçu. Un type inconnu — écrit par une version
  /// plus récente — est ignoré, pas jeté en erreur : le fil doit survivre à
  /// ce qu'il ne comprend pas.
  void _traiterControle(MlsIncoming entrant) {
    final payload = entrant.payload;
    if (payload == null || payload.type != 'edit') return;
    final cible = payload.body['targetId'] as String?;
    final texte = payload.body['content'] as String?;
    if (cible == null || texte == null) return;
    _editions[cible] = (texte: texte, quand: entrant.row.createdAt.toLocal());
  }

  /// Applique les modifications reçues **dans le fil lui-même**, pas à la
  /// sortie : c'est ce fil-là qui sera mis en cache, donc relu au prochain
  /// lancement. Un contrôle n'est délivré qu'une fois — s'il ne laissait pas
  /// de trace durable, le texte d'avant réapparaîtrait au redémarrage.
  void _appliquerEditionsEnAttente(List<MessageEntity> fil) {
    if (_editions.isEmpty) return;
    for (var i = 0; i < fil.length; i++) {
      final edition = _editions.remove(fil[i].id);
      if (edition == null) continue;
      fil[i] = fil[i].copyWith(
        content: edition.texte,
        editedAt: edition.quand,
      );
    }
  }

  /// Recolle les métadonnées en ligne sur un fil déjà déchiffré.
  Future<List<MessageEntity>> _avecMetadonnees(List<MessageEntity> fil) async {
    if (fil.isEmpty) return fil;
    final lot = await _meta.pour(fil.map((m) => m.id));
    // **On sort sur l'échec de lecture, pas sur le vide.**
    //
    // Sortir quand le lot est vide paraissait une économie : rien à recoller,
    // rien à faire. C'en était une seulement si l'on oubliait que ce bloc ne
    // fait pas qu'ajouter — il **efface** aussi ce que le serveur ne porte
    // plus. Le fil vient du cache de l'appareil, qui garde les réactions,
    // étoiles et marques de lecture d'hier : sauter le recollage les figeait.
    //
    // Mesuré le 2026-09-15 sur SM A515F : une bulle affichait un 👍 alors que
    // `mls_message_reactions` était **vide**. Une réaction retirée restait
    // donc à l'écran pour toujours, et une réaction dont l'écriture avait
    // échoué paraissait avoir pris — l'échec muet, là encore.
    if (!lot.lu) return fil;
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

    // Une seule lecture de la conversation pour deux besoins : rafraîchir la
    // bascule (que le `ensureGroup` ci-dessus vient peut-être de poser) et
    // relire le minuteur. Il est relu à CHAQUE envoi, jamais mémorisé : un
    // minuteur qu'on vient d'activer doit mordre dès le message suivant.
    final conv = await _delivery.conversation(conversationId);
    _bascule[conversationId] =
        DateTime.tryParse((conv?['mls_since'] as String?) ?? '');
    final ttl = _minuteurDe(conv);

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
      ttl: ttl,
    );
    final row = await _service.send(
      conversationId,
      payload,
      contentType: MlsMessageMapper.contentType(type),
      // La colonne, elle, sert au balayage du serveur — le récepteur, lui,
      // recalcule l'échéance depuis le `ttl` du payload.
      expiresAt: ttl == null
          ? null
          : DateTime.now().toUtc().add(Duration(seconds: ttl)),
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
        ttl: payload.ttl,
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
    int? dureeVideo,
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
        // Champ distinct : `duration` est lu comme une duree AUDIO par le
        // mapper. Y ranger une video l'aurait fait disparaitre du badge.
        if (dureeVideo != null) 'videoDuration': dureeVideo,
        if (waveform != null) 'waveform': waveform,
      };

  /// Un envoi peut-il encore emprunter le chemin d'aujourd'hui ?
  ///
  /// Seulement si rien n'est engagé. Une fois `mls_since` posé, la réponse
  /// est non, définitivement — et le serveur la ferait respecter de toute
  /// façon.
  Future<bool> repliLegacyPossible(String conversationId) async =>
      await mlsSince(conversationId) == null;

  /// Le minuteur de la conversation en secondes, `null` s'il est coupé.
  ///
  /// Même source que le chemin legacy — `conversations.data`, écrit par
  /// l'écran de réglage — pour qu'une conversation basculée à MLS garde le
  /// minuteur qu'elle avait avant.
  static int? _minuteurDe(Map<String, dynamic>? conversation) {
    final data = conversation?['data'];
    if (data is! Map) return null;
    final secondes = (data['autoDeleteAfterSeconds'] as num?)?.toInt();
    return secondes == null || secondes <= 0 ? null : secondes;
  }

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

  /// Parmi ces messages, ceux que **moi seul** ai mis en favori.
  ///
  /// L'écran des favoris interrogeait la table `messages`, où un message
  /// chiffré n'a pas de ligne : mettre en favori marchait — l'étoile est bien
  /// écrite dans `mls_message_stars`, et le fil l'affiche — mais la LISTE des
  /// favoris restait vide, sans erreur. On étoilait dans le vide.
  ///
  /// L'appelant fournit les identifiants qu'il peut déjà afficher, c'est-à-dire
  /// ceux de son cache : le clair n'existe que là.
  Future<Set<String>> favorisParmi(Iterable<String> messageIds) async {
    final ids = messageIds.toList();
    if (ids.isEmpty) return const <String>{};
    final lot = await _meta.pour(ids);
    return lot.etoiles;
  }

  /// « Supprimer pour moi » — sur tous mes appareils, pas seulement celui-ci.
  Future<void> supprimerPourMoi(String messageId) => _meta.masquer(messageId);

  /// « Supprimer pour tous » — le serveur cesse de servir le ciphertext.
  /// Réservé à l'expéditeur par le RLS.
  Future<void> supprimerPourTous(String messageId) =>
      _meta.supprimerPourTous(messageId);

  static const modificationBranchee = true;

  /// Modifie un message chiffré.
  ///
  /// Le nouveau texte **repart chiffré**, dans un message de contrôle : le
  /// serveur ne peut pas le lire, et garde le ciphertext d'origine qu'il n'a
  /// jamais compris. La colonne `edited_at`, elle, dit publiquement « ce
  /// message a été modifié » — pour l'appareil qui n'aurait pas reçu le
  /// contrôle, et qui doit savoir que son texte n'est plus le dernier.
  ///
  /// Lève si l'envoi échoue : une modification qui « réussit » sans rien
  /// changer est l'échec muet que ce chantier traque.
  Future<void> modifier({
    required String conversationId,
    required String messageId,
    required String nouveauTexte,
  }) async {
    await _service.send(
      conversationId,
      MlsPayload(
        id: '',
        type: 'edit',
        sentAt: DateTime.now().millisecondsSinceEpoch,
        body: {'targetId': messageId, 'content': nouveauTexte},
      ),
      kind: 'control',
    );
    await _meta.marquerModifie(messageId);
    // Chez moi aussi : `catchUp` saute mes propres messages, le contrôle ne
    // me reviendra jamais.
    _editions[messageId] = (texte: nouveauTexte, quand: DateTime.now());
    final fil = _fil[conversationId];
    if (fil != null) _appliquerEditionsEnAttente(fil);
  }

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

  /// L'aperçu du dernier message de chaque conversation basculée, **sans
  /// ouvrir la discussion**.
  ///
  /// Un message reçu pendant que la discussion est fermée n'est jamais
  /// déchiffré par le fil : la liste affichait donc « Message chiffré »
  /// indéfiniment. Constaté le 2026-09-15 sur Pixel 10 Pro XL — un message
  /// de 21:23 encore illisible à 21:33, app ouverte, liste à l'écran.
  ///
  /// Le clair existe pourtant déjà sur l'appareil : l'isolate de notification
  /// l'a déchiffré à l'arrivée du push, via `apercuSansEtat` — une **copie
  /// jetable** côté Rust, qui n'avance pas le cliquet. C'est ce qui rend cette
  /// lecture sûre : on ne déchiffre rien ici, on relit ce qui l'a déjà été.
  /// L'app reste le seul écrivain de l'état MLS.
  ///
  /// Limite assumée : sans push reçu (notifications coupées, message d'un
  /// epoch que l'isolate n'a pas su traiter), il n'y a rien à relire et le
  /// libellé générique reste. C'est un progrès, pas une garantie.
  Future<Map<String, String>> apercusDejaDechiffres() async {
    try {
      final derniers = await _meta.derniersMessages();
      if (derniers.isEmpty) return const {};
      final sortie = <String, String>{};
      for (final e in derniers.entries) {
        final texte = await MlsNotificationPreview.apercuCache(e.value);
        if (texte != null && texte.isNotEmpty) sortie[e.key] = texte;
      }
      return sortie;
    } catch (e) {
      debugPrint('MlsGateway: aperçus indisponibles ($e)');
      return const {};
    }
  }

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
