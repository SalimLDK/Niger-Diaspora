import 'dart:async';

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

  /// Les conversations dont le **dernier** message n'a jamais été déchiffré
  /// sur cet appareil, les plus récentes d'abord.
  ///
  /// Sert au rattrapage de fond : sans lui, le déchiffrement n'a lieu qu'à
  /// l'ouverture du fil, et il faut attendre réseau + déchiffrement avant de
  /// voir le message neuf. Mesuré le 2026-09-15 sur Pixel 10 Pro XL :
  /// **2,5 à 3 secondes** entre l'ouverture et l'apparition des trois messages
  /// reçus — le fil s'affichait d'abord sans eux, depuis le cache.
  ///
  /// Borné à [maximum] : il ne s'agit pas de déchiffrer toute la messagerie au
  /// démarrage, seulement ce que l'utilisateur va probablement ouvrir.
  Future<List<String>> conversationsARattraper(
    Iterable<String> conversationIds, {
    int maximum = 3,
  }) async {
    try {
      final derniers = await _meta.derniersMessages(conversationIds);
      final sortie = <String>[];
      // `derniersMessages` rend du plus récent au plus ancien, et Dart garde
      // l'ordre d'insertion : les premières sont les plus urgentes.
      for (final e in derniers.entries) {
        if (_connus.contains(e.value)) continue;
        sortie.add(e.key);
        if (sortie.length >= maximum) break;
      }
      return sortie;
    } catch (e) {
      debugPrint('MlsGateway: rattrapage impossible à planifier ($e)');
      return const [];
    }
  }

  /// Vrai une fois les dates de bascule lues en lot (voir [amorcerBascules]).
  bool _amorce = false;

  /// Apprend d'un coup quelles conversations de la liste sont basculées.
  ///
  /// [aDesConversationsBasculees] se remplissait **paresseusement**, une
  /// conversation à la fois, et seulement en ouvrant son fil. Or c'est lui qui
  /// décide, dans `_completerAvecMls`, s'il faut demander au serveur les
  /// compteurs de non-lus et les aperçus. Conséquence : après un démarrage à
  /// froid, et tant qu'aucun fil chiffré n'avait été ouvert, la liste n'avait
  /// **ni pastille de non-lus ni aperçu** sur les discussions chiffrées — elle
  /// affichait « Message chiffré » et rien d'autre.
  ///
  /// Constaté le 2026-09-15 sur Pixel 10 Pro XL : deux messages reçus,
  /// notification en clair à l'écran, et la tuile muette vingt secondes plus
  /// tard. Ouvrir la discussion « réparait » la liste pour le reste de la
  /// session, ce qui rendait le défaut déroutant.
  ///
  /// Une seule requête, une seule fois par passerelle. Un échec ne coûte que
  /// ce qu'il coûtait avant : la lecture paresseuse reprend la main.
  Future<void> amorcerBascules(Iterable<String> conversationIds) async {
    if (_amorce) return;
    final ids = [
      for (final id in conversationIds)
        if (!_bascule.containsKey(id)) id,
    ];
    if (ids.isEmpty) return;
    try {
      final dates = await _delivery.bascules(ids);
      for (final id in ids) {
        _bascule[id] = dates[id];
      }
      _amorce = true;
    } catch (e) {
      debugPrint('MlsGateway: bascules illisibles ($e)');
    }
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
  Future<List<MessageEntity>> messages(String conversationId) {
    // **Un seul rattrapage à la fois par conversation.** `catchUp` fait
    // avancer le cliquet MLS ; deux passages concurrents le feraient avancer
    // en même temps, et un cliquet abîmé rend des messages illisibles pour
    // de bon. Ce n'était pas théorique à partir du moment où la liste
    // déclenche un rattrapage de fond pendant que l'écran peut ouvrir le
    // même fil : les deux appelants partagent désormais le même futur.
    final enCours = _rattrapages[conversationId];
    if (enCours != null) return enCours;
    final futur = _rattraper(conversationId);
    _rattrapages[conversationId] = futur;
    unawaited(futur.whenComplete(() {
      if (identical(_rattrapages[conversationId], futur)) {
        // `.remove` rend la Future retirée (valeur de la map) : sans intérêt
        // ici, juste écartée — d'où l'`unawaited` explicite.
        unawaited(_rattrapages.remove(conversationId));
      }
    }).catchError((_) => <MessageEntity>[]));
    return futur;
  }

  final Map<String, Future<List<MessageEntity>>> _rattrapages = {};

  Future<List<MessageEntity>> _rattraper(String conversationId) async {
    final entrants = await _service.catchUp(conversationId);
    final fil = _fil[conversationId] ??= [];
    final deja = {for (final m in fil) m.id};
    final avantArrivee = <String>[];
    for (final e in entrants) {
      // Chiffré avant que cet appareil n'entre dans le groupe : illisible
      // pour de bon, donc ni bulle ni non-lu. Le curseur de lecture ne
      // l'atteindrait jamais — il suit ce que l'écran montre —, et la
      // pastille resterait sur un message que personne ne verra. Voir
      // `MlsConversationService.catchUp`.
      if (e.estAvantArrivee) {
        if (e.row.senderId != userId) avantArrivee.add(e.row.id);
        continue;
      }
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
    if (avantArrivee.isNotEmpty) {
      try {
        await _meta.marquer(avantArrivee, lu: true);
      } catch (e) {
        // Le fil ne doit pas en dépendre : au pire la pastille reste.
        debugPrint('MlsGateway: messages d\'avant l\'arrivée non marqués ($e)');
      }
    }
    fil.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    _appliquerEditionsEnAttente(fil);
    _connus.addAll(deja);
    return _avecMetadonnees(fil);
  }

  /// Reprend le fil déchiffré depuis le cache local de l'appareil.
  ///
  /// **C'est ce qui fait tenir une conversation basculée d'un lancement à
  /// l'autre.** Le moteur ne sait pas relire ce qu'il a déjà déchiffré — MLS
  /// supprime le secret d'un message applicatif après usage. Au démarrage, le
  /// serveur n'a donc plus rien de lisible à offrir : seul le cache de
  /// l'appareil garde le clair.
  ///
  /// Le fil en mémoire fait foi : un second amorçage ne fait qu'y ajouter les
  /// messages du cache qui lui manquent, sans rien remplacer ni retirer.
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
    if (caches.isEmpty) return;
    // Une entrée de cache déjà marquée supprimée pour tous n'entre dans le fil
    // que vidée : jusqu'ici, elle était mise en cache avec son clair, le
    // drapeau posé à côté.
    caches = [for (final m in caches) _videSiSupprime(m)];
    final vivant = _fil[conversationId];
    if (vivant == null || vivant.isEmpty) {
      final fil = [...caches]
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      _fil[conversationId] = fil;
      _connus.addAll(fil.map((m) => m.id));
      return;
    }

    // Un fil déjà vivant est COMPLÉTÉ par le cache, jamais remplacé : ce qu'il
    // porte est plus frais (métadonnées, édition), donc seules les entrées
    // qu'il n'a pas sont reprises.
    //
    // Il sortait sans rien faire. Or le fil peut naître AILLEURS que de
    // l'écran : le rattrapage de fond de la liste appelle [messages] sans
    // amorcer, et `catchUp` ne rend que le delta. Le fil ne contenait alors
    // que les messages reçus depuis le dernier passage, et l'amorçage de
    // l'ouverture — celui qui aurait rendu tout le reste — était sauté. Vu le
    // 2026-09-21 sur SM A515F : discussion rouverte après une coupure, de
    // « Tygg » (mardi) directement à PE1 ; une vingtaine de messages du jour
    // masqués jusqu'à la relance, tous intacts en base et dans le cache.
    //
    // Une exception au « jamais remplacé » : la suppression pour tous. Le
    // cache peut la savoir avant le fil — `_marquerSupprimeDansLeCache` l'y
    // écrit dès le geste, alors que le fil ne l'apprend qu'au prochain
    // recollage réussi. Garder la copie vivante telle quelle ferait réécrire
    // au cache, au passage suivant, le clair avec un drapeau retombé à faux :
    // le drapeau n'est jamais dégradé.
    final supprimesAuCache = {
      for (final m in caches)
        if (m.deletedForEveryone) m.id,
    };
    if (supprimesAuCache.isNotEmpty) _vider(vivant, supprimesAuCache);
    final deja = {for (final m in vivant) m.id};
    final manquants = [
      for (final m in caches)
        if (!deja.contains(m.id)) m,
    ];
    if (manquants.isEmpty) return;
    vivant
      ..addAll(manquants)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    _connus.addAll(manquants.map((m) => m.id));
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
      // Une modification ne ressuscite pas un message supprimé pour tous :
      // `copyWith(content:)` lui rendrait un texte.
      if (fil[i].deletedForEveryone) continue;
      fil[i] = fil[i].copyWith(
        content: edition.texte,
        editedAt: edition.quand,
      );
    }
  }

  /// Un message supprimé pour tous, réduit à sa coquille ; les autres tels
  /// quels.
  static MessageEntity _videSiSupprime(MessageEntity m) =>
      m.deletedForEveryone ? m.videPourSuppression() : m;

  /// Vide, **dans le fil lui-même**, les messages supprimés pour tous — ceux
  /// qui portent déjà le drapeau et ceux de [supprimes].
  ///
  /// Le serveur vide la ligne d'un message en clair ; celle d'un message MLS
  /// n'a jamais eu de clair, qui ne vit qu'ici — et dans le cache de
  /// l'appareil, copie de ce fil. Poser le drapeau sans vider laissait le
  /// texte, le fichier local, la clé du média et la citation dans la mémoire
  /// de la passerelle et sur le disque, réinjectés dans l'écran à chaque
  /// passage.
  void _vider(List<MessageEntity> fil, [Set<String> supprimes = const {}]) {
    for (var i = 0; i < fil.length; i++) {
      final m = fil[i];
      if (m.deletedForEveryone || supprimes.contains(m.id)) {
        fil[i] = m.videPourSuppression();
      }
    }
  }

  /// Recolle les métadonnées en ligne sur un fil déjà déchiffré.
  ///
  /// [vivant] est le fil de la passerelle : les suppressions pour tous y sont
  /// appliquées en place (voir [_vider]), le recollage porte sur une copie.
  Future<List<MessageEntity>> _avecMetadonnees(
    List<MessageEntity> vivant,
  ) async {
    _vider(vivant);
    final fil = List.of(vivant);
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
    // Après l'`await`, le fil vivant a pu bouger (envoi, amorçage) : vidage
    // par identifiant, pas par position.
    if (lot.supprimes.isNotEmpty) _vider(vivant, lot.supprimes);
    return [
      for (final m in fil)
        (lot.supprimes.contains(m.id) ? m.videPourSuppression() : m).copyWith(
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
  ///
  /// Et le fil de cet appareil perd le clair aussitôt, sans attendre le
  /// prochain recollage : c'est lui que le dépôt remet en cache.
  Future<void> supprimerPourTous(String messageId) async {
    await _meta.supprimerPourTous(messageId);
    _editions.remove(messageId);
    for (final fil in _fil.values) {
      _vider(fil, {messageId});
    }
  }

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
    _signalerLecture();
  }

  /// Émis après chaque lecture enregistrée (curseur avancé, conversation
  /// marquée lue).
  ///
  /// La liste des discussions ne se rejoue que quand la ligne
  /// `conversations` change côté serveur. Pour une conversation en clair,
  /// marquer lu la touche (`unreadCount`) ; pour une conversation chiffrée,
  /// la lecture ne vit que dans `mls_message_receipts` — la liste ne
  /// l'apprenait jamais, et sa pastille restait sur l'ancien compte après
  /// avoir quitté la discussion. Vu sur SM A515F le 2026-09-21 : « Testeurs »
  /// figé à 1 non lu, 0 en base.
  Stream<void> get lecturesAvancees => _lecturesAvancees.stream;
  final StreamController<void> _lecturesAvancees =
      StreamController<void>.broadcast();

  void _signalerLecture() {
    if (!_lecturesAvancees.isClosed) _lecturesAvancees.add(null);
  }

  /// Le dernier message lu de cette conversation — le curseur dont le
  /// séparateur « nouveaux messages » est la représentation.
  Future<({String id, DateTime quand})?> curseurDeLecture(
    String conversationId,
  ) => _meta.curseurDeLecture(conversationId);

  /// Le premier message non lu, **même hors de la page chargée** : c'est lui
  /// que le séparateur désigne.
  Future<({String id, DateTime quand})?> premierNonLu(
    String conversationId, {
    DateTime? apres,
  }) => _meta.premierNonLu(conversationId, apres: apres);

  /// Avance le curseur jusqu'à [jusqua] inclus, sans marquer au-delà.
  Future<void> avancerCurseur(String conversationId, DateTime jusqua) async {
    await _meta.marquerLusJusqua(conversationId, jusqua);
    _signalerLecture();
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
  /// [conversationIds] : celles dont l'aperçu manque. Rien n'est demandé au
  /// serveur si la liste est vide.
  Future<Map<String, String>> apercusDejaDechiffres(
    Iterable<String> conversationIds,
  ) async {
    try {
      final derniers = await _meta.derniersMessages(conversationIds);
      if (derniers.isEmpty) return const {};

      Future<Map<String, String>> lire() async {
        final trouves = <String, String>{};
        for (final e in derniers.entries) {
          final texte = await MlsNotificationPreview.apercuCache(e.value);
          if (texte != null && texte.isNotEmpty) trouves[e.key] = texte;
        }
        return trouves;
      }

      var sortie = await lire();
      if (sortie.length < derniers.length) {
        // Course perdue, et elle se voyait : l'isolate de notification met
        // l'aperçu en cache **après** l'émission de la liste qui porte le
        // message. Rien ne redéclenchait la liste, donc la tuile restait sur
        // « Message chiffré » jusqu'au rafraîchissement suivant — mesuré le
        // 2026-09-15 sur Pixel 10 Pro XL, où le texte n'est apparu qu'après
        // un « tirer pour rafraîchir ».
        //
        // Le correctif propre serait un signal émis par
        // `MlsNotificationPreview` à la mise en cache. Il n'est pas fait ici :
        // ce fichier est en cours de refonte ailleurs, et une seconde lecture
        // bornée suffit à refermer la fenêtre sans coupler les deux. Le délai
        // n'est payé **que** s'il manque quelque chose.
        await Future<void>.delayed(const Duration(milliseconds: 400));
        final second = await lire();
        if (second.length > sortie.length) sortie = second;
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
