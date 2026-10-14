part of 'message_repository_impl.dart';

/// Branchement MLS : passerelle, rattrapage en arrière-plan, fusion avec le
/// cache.
mixin _Mls on _MessageRepositoryBase {
  /// La passerelle MLS si — et seulement si — cette conversation doit
  /// passer par elle. Nulle sinon, et l'appelant reprend son chemin habituel.
  ///
  /// Centralisée parce qu'elle est appelée par les six méthodes d'envoi : un
  /// type de message oublié ici, et il partirait vers `messages` que le
  /// serveur refuse désormais pour une conversation basculée — l'envoi
  /// échouerait sans que rien n'explique pourquoi.
  Future<MlsGateway?> _passerellePour(String conversationId) async {
    final passerelle = mlsGateway;
    if (passerelle == null) return null;
    return await passerelle.enMls(conversationId) ? passerelle : null;
  }

  /// Dernier déclenchement du rattrapage de fond.
  DateTime? _dernierRattrapage;

  /// Plancher entre deux planifications. Il ne régule plus grand-chose depuis
  /// que [rattrapageADeclencher] filtre sur « quelque chose a bougé » : ce qui
  /// reste est un garde-fou contre une conversation qui échoue en boucle.
  ///
  /// Il valait 20 s, et c'était trop : plusieurs messages reçus d'affilée —
  /// le cas de toute conversation vivante — voyaient le deuxième et le
  /// troisième bloqués par le premier, donc affichés « Message chiffré »
  /// pendant tout ce temps.
  ///
  /// **Un rattrapage retenu par ce plancher est reporté, jamais abandonné.**
  /// Il rendait la main sans rien reprogrammer : un message reçu moins de 5 s
  /// après le précédent — le premier échange de toute conversation — gardait
  /// « Message chiffré » dans la liste jusqu'à la prochaine émission du
  /// serveur, c'est-à-dire, liste immobile, jusqu'au message suivant ou à un
  /// tirer-pour-rafraîchir. Signalé par Salim le 2026-09-21.
  @visibleForTesting
  Duration espacementRattrapage = const Duration(seconds: 5);

  /// Combien la liste attend le déchiffrement avant d'émettre sans lui. Un
  /// déchiffrement normal prend ~2 s (réseau + MLS, mesuré le 2026-09-21).
  @visibleForTesting
  Duration attenteDechiffrementMax = const Duration(seconds: 3);

  /// La reprise programmée à la fin du plancher, s'il en faut une. Une seule
  /// à la fois : elle repart de la dernière liste reçue, pas de celle qui l'a
  /// demandée, puisque d'autres messages ont pu arriver entre-temps.
  Timer? _rattrapageReporte;
  ({MlsGateway passerelle, List<ConversationEntity> conversations})?
      _listeAReprendre;

  void _reporterRattrapage(
    MlsGateway passerelle,
    List<ConversationEntity> conversations,
    Duration delai,
  ) {
    _listeAReprendre = (passerelle: passerelle, conversations: conversations);
    if (_rattrapageReporte?.isActive ?? false) return;
    _rattrapageReporte = Timer(delai, () {
      _rattrapageReporte = null;
      final reprise = _listeAReprendre;
      _listeAReprendre = null;
      if (reprise == null || _rattrapageFini.isClosed) return;
      unawaited(
        _rattraperMlsEnArrierePlan(reprise.passerelle, reprise.conversations),
      );
    });
  }

  /// Ce pour quoi un rattrapage a déjà été **tenté** : conversation →
  /// `lastMessageAt` de la tentative. Une date neuve rouvre la tentative ; la
  /// même, non — sinon un fil qui refuse de se déchiffrer serait redemandé à
  /// chaque émission de la liste.
  final Map<String, DateTime> _rattrapageTente = {};

  /// Émis quand une passe de rattrapage a déchiffré et mis en cache : la
  /// liste se rejoue alors (voir [getConversations]). Sans ce signal, le
  /// rattrapage faisait tout le travail et personne ne le regardait.
  final StreamController<void> _rattrapageFini =
      StreamController<void>.broadcast();

  /// Fait recalculer la liste des discussions depuis sa dernière version
  /// serveur, sans attendre que la ligne `conversations` change.
  ///
  /// Pour une conversation chiffrée, l'aperçu est reconstitué depuis le cache
  /// local du fil (`apercuDepuisCache`) : tout geste qui modifie ce cache sans
  /// toucher `conversations` doit le signaler, sinon la liste garde ce qu'elle
  /// avait calculé avant.
  void _rejouerLaListe() {
    if (!_rattrapageFini.isClosed) _rattrapageFini.add(null);
  }

  /// Après « supprimer pour tous » d'un message chiffré : le message caché
  /// porte la marque, perd son texte, et la liste se recalcule.
  ///
  /// La suppression n'écrit que dans `mls_messages`. Le serveur n'a jamais eu
  /// le clair ; l'appareil, lui, le garde dans son cache, et la liste n'était
  /// pas rejouée. Vu le 2026-09-21 sur Pixel 10 Pro XL : la tuile de
  /// l'expéditeur affichait « Vous: PA6SECRET » deux minutes après la
  /// suppression, et jusqu'à la relance de l'app — le seul moment où la liste
  /// relisait le cache.
  ///
  /// L'entrée est vidée, pas seulement marquée : c'est la copie qui fuyait.
  /// La relecture du fil par la passerelle réécrira cette entrée de toute
  /// façon, avec la même marque — mais seulement au prochain passage, et
  /// une app tuée entre les deux laissait sur le disque ce que cette
  /// écriture n'avait pas retiré (voir [entreeCacheSupprimee]).
  Future<void> _marquerSupprimeDansLeCache(
    String conversationId,
    String messageId,
  ) async {
    try {
      final cached = cacheService.getCachedMessages(conversationId);
      final index = cached.indexWhere((m) => m['id'] == messageId);
      if (index != -1) {
        await cacheService.cacheMessages(
          conversationId,
          [MessageRepositoryImpl.entreeCacheSupprimee(cached[index])],
        );
      }
    } catch (e) {
      // La suppression serveur a réussi : un cache récalcitrant ne doit pas
      // la faire passer pour un échec.
      dev.log('Cache après suppression', name: 'message_repository_impl', error: e);
    }
    _rejouerLaListe();
  }

  /// Déchiffre en tâche de fond les conversations dont le dernier message
  /// n'a jamais été lu sur cet appareil, et met le résultat en cache.
  ///
  /// Le cache est le point : c'est lui que `_loadCacheSync` affiche
  /// instantanément à l'ouverture. Déchiffrer sans mettre en cache ne ferait
  /// gagner que la moitié du temps.
  ///
  /// Ne lève jamais : un rattrapage raté coûte l'attente qu'on avait avant.
  ///
  /// [attente] : la liste qui attend cette passe (voir `_completerAvecMls`).
  /// Tant qu'elle ne l'a pas abandonnée, c'est elle qui relit le cache — la
  /// faire rejouer en plus émettrait deux fois la même chose. Nulle pour une
  /// passe reportée, que personne n'attend.
  Future<void> _rattraperMlsEnArrierePlan(
    MlsGateway passerelle,
    List<ConversationEntity> conversations, {
    _AttenteRattrapage? attente,
  }) async {
    // Ce qui reste à montrer : les conversations sans aperçu, avec la date du
    // message qu'on n'arrive pas à afficher.
    final candidats = {
      for (final c in conversations)
        if ((c.lastMessage ?? '').isEmpty && c.lastMessageAt != null)
          c.id: c.lastMessageAt!,
    };
    // Une conversation qui a retrouvé son aperçu sort de la mémoire des
    // tentatives : elle n'a plus rien à rattraper, et la table reste bornée.
    _rattrapageTente.removeWhere((id, _) => !candidats.containsKey(id));

    if (!MessageRepositoryImpl.rattrapageADeclencher(
      candidats: candidats,
      dejaTente: _rattrapageTente,
    )) {
      return;
    }

    final maintenant = DateTime.now();
    final precedent = _dernierRattrapage;
    if (precedent != null) {
      final ecoule = maintenant.difference(precedent);
      if (ecoule < espacementRattrapage) {
        _reporterRattrapage(passerelle, conversations,
            espacementRattrapage - ecoule);
        return;
      }
    }
    // Cette passe part de la liste la plus récente : une reprise en attente
    // n'aurait plus rien à ajouter.
    _rattrapageReporte?.cancel();
    _rattrapageReporte = null;
    _listeAReprendre = null;
    _dernierRattrapage = maintenant;

    var dechiffre = false;
    try {
      final aFaire = await passerelle.conversationsARattraper(
        [for (final c in conversations) c.id],
      );
      for (final id in aFaire) {
        // Retenue **avant** la tentative, et gardée même si elle échoue : une
        // conversation qui ne se déchiffre pas ne doit pas être redemandée à
        // chaque émission de la liste. Le prochain message y rouvrira la
        // tentative, puisque sa date changera.
        if (candidats[id] case final quand?) _rattrapageTente[id] = quand;
        try {
          final mls = await passerelle.messages(id);
          if (mls.isEmpty) continue;
          await cacheService.cacheMessages(
            id,
            MessageRepositoryImpl.jsonPourCacheMls(mls),
          );
          dechiffre = true;
        } catch (e) {
          dev.log('Rattrapage MLS impossible',
              name: 'message_repository_impl', error: e);
        }
      }
    } catch (e) {
      dev.log('Rattrapage MLS non planifié',
          name: 'message_repository_impl', error: e);
    }

    // Hors du `try`, et c'est tout l'objet du passage : sans ce signal, le
    // clair est en cache et la tuile continue d'afficher « Message chiffré ».
    final dejaRelu = attente != null && !attente.abandonnee;
    if (dechiffre && !dejaRelu && !_rattrapageFini.isClosed) {
      _rattrapageFini.add(null);
    }
  }

  /// La passerelle si **ce message-là** est un message MLS.
  ///
  /// L'aiguillage se fait par message, pas par conversation : une discussion
  /// basculée garde son historique en clair juste au-dessus du séparateur, et
  /// réagir à l'un de ces anciens messages doit continuer d'écrire dans
  /// `messages`. Se tromper de table ne lève rien — un `update … where id`
  /// sans cible réussit avec zéro ligne — et l'action paraîtrait juste « ne
  /// pas prendre ».
  Future<MlsGateway?> _passerelleMessage(
    String conversationId,
    String messageId,
  ) async {
    final passerelle = mlsGateway;
    if (passerelle == null) return null;
    return await passerelle.estMlsMessage(conversationId, messageId)
        ? passerelle
        : null;
  }

  /// Exécute un envoi MLS, avec la règle du repli : avant la bascule, un
  /// échec peut encore emprunter le chemin d'aujourd'hui ; après, il remonte.
  ///
  /// **Et met le message en cache, comme le fait le chemin legacy.** Le clair
  /// de nos propres messages n'existe que sur cet appareil ; le chemin legacy
  /// le met en cache juste après l'envoi pour cette raison, le chemin MLS
  /// l'oubliait. Le cache ne le recevait qu'au prochain chargement du fil
  /// (`_fusionnerAvecMls`), c'est-à-dire en rouvrant la discussion.
  ///
  /// Ce que ça coûtait, entre l'envoi et cette réouverture : la liste des
  /// discussions perdait son aperçu. Le serveur avance `last_message_at` sur
  /// la note qu'on vient d'écrire, mais n'a pas son texte — il ne l'aura
  /// jamais — et `apercuDepuisCache` ne trouvait, côté cache, que le message
  /// d'AVANT. Les deux horodatages ne concordant pas, elle refusait, à raison.
  /// La discussion retombait donc sur son libellé de type. Constaté sur
  /// SM A515F le 2026-09-15, tuile « Mes notes » : « Notes, brouillons et
  /// sondages » à la place de la note écrite trente secondes plus tôt.
  ///
  /// L'égalité que cette garde exige n'est atteignable que parce que
  /// `MlsDelivery.publishMessage` relit `created_at` : le message mis en cache
  /// ici porte l'horodatage **du serveur**, celui-là même qui vient d'être
  /// écrit dans `last_message_at`. Les deux correctifs ne valent qu'ensemble.
  ///
  /// `cacheMessages` fusionne par id, donc ajouter une seule entrée est sans
  /// risque pour le reste du fil.
  Future<Either<Failure, MessageEntity>?> _tenterEnvoiMls(
    MlsGateway passerelle,
    String conversationId,
    Future<MessageEntity> Function() envoi,
  ) async {
    try {
      final envoye = await envoi();
      unawaited(cacheService.cacheMessages(
        conversationId,
        [MessageModel.fromEntity(envoye).toJson()],
      ));
      return Right(envoye);
    } catch (e) {
      if (!await passerelle.repliLegacyPossible(conversationId)) rethrow;
      dev.log('MLS indisponible, envoi en clair (conversation non basculée)',
          name: 'message_repository_impl', error: e);
      return null;
    }
  }

  /// Fusionne l'historique legacy déjà chargé avec le fil MLS.
  ///
  /// Rend la liste inchangée dès que MLS n'est pas concerné : pas de
  /// passerelle injectée, ou conversation jamais basculée et drapeau fermé.
  /// Un échec de lecture MLS ne coûte pas l'historique — il coûte les
  /// messages chiffrés, et se voit dans `mls_diagnostics`.
  Future<List<MessageEntity>> _fusionnerAvecMls(
    String conversationId,
    List<MessageEntity> legacy,
  ) async {
    final passerelle = mlsGateway;
    if (passerelle == null) return legacy;
    try {
      if (!await passerelle.enMls(conversationId)) return legacy;
      // Le moteur ne sait pas relire ce qu'il a déjà déchiffré : au
      // lancement, le serveur n'a plus rien de lisible à offrir pour les
      // messages d'hier. Le cache de l'appareil, lui, a le clair — on le rend
      // à la passerelle avant de lui demander le fil.
      passerelle.amorcer(
        conversationId,
        _mlsDuCache(conversationId, await passerelle.mlsSince(conversationId)),
      );
      final mls = await passerelle.messages(conversationId);
      if (mls.isEmpty) return legacy;
      // Sans ce cache, rouvrir la discussion hors ligne ferait disparaître
      // les messages chiffrés : le serveur ne saura jamais les rendre en
      // clair, et le cliquet ne se rejoue pas.
      unawaited(cacheService.cacheMessages(
        conversationId,
        MessageRepositoryImpl.jsonPourCacheMls(mls),
      ));
      return MlsSourceMerger.fusionner(
        legacy: legacy,
        mls: mls,
        mlsSince: await passerelle.mlsSince(conversationId),
      );
    } catch (e) {
      dev.log('Fusion MLS impossible', name: 'message_repository_impl', error: e);
      return legacy;
    }
  }

  /// Les messages chiffrés déjà en cache sur cet appareil.
  ///
  /// Reconnus à leur date : une fois `mls_since` posé, le serveur refuse
  /// toute écriture en clair pour cette conversation — tout ce qui vient
  /// après la bascule est donc chiffré, et rien d'autre ne l'est.
  ///
  /// Les placeholders sont écartés : un « 🔐 Message chiffré » mis en cache
  /// par un passage précédent ne doit pas revenir prendre la place du clair
  /// qu'un autre passage avait obtenu.
  List<MessageEntity> _mlsDuCache(String conversationId, DateTime? depuis) =>
      MessageRepositoryImpl.mlsDuCache(
        cacheService.getCachedMessages(conversationId),
        depuis,
      );

  /// Lit la durée d'une vidéo locale sans la compresser (juste ses métadonnées),
  /// pour le badge de durée de `VideoBubble`.
  Future<int?> _getVideoDurationSeconds(String path) async {
    try {
      final info = await VideoCompress.getMediaInfo(path);
      final durationMs = info.duration;
      if (durationMs == null) return null;
      return (durationMs / 1000).round();
    } catch (e) {
      dev.log(
        'Impossible de lire la durée vidéo',
        name: 'message_repository_impl',
        error: e,
      );
      return null;
    }
  }
}
