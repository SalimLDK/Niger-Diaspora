part of 'conversation_screen.dart';

/// Accusés de lecture : visibilité des messages, curseur de lecture,
/// présence de l'écran.
extension _LectureConversation on _ConversationScreenState {
  /// Le fil chargé va-t-il jusqu'au dernier message que la liste annonçait ?
  ///
  /// `_loadCacheSync` affiche d'abord le cache local, qui ne contient pas les
  /// messages reçus entre deux visites. Compter les non-lus sur ce fil-là donne
  /// un compte trop bas, et surtout un **rang faux**.
  bool _filVaJusquAuBout(List<MessageEntity> messages) {
    final annonce = _dernierMessageAnnonce;
    if (annonce == null) return true; // rien à quoi comparer (lien profond)
    if (messages.isEmpty) return false;
    return !messages.last.createdAt.isBefore(annonce);
  }

  void _signalerVisibilite(MessageEntity message, double fraction) {
    // Un rapport en attente peut tomber après la fermeture de l'écran.
    if (!mounted) return;
    // Ni mes propres messages, ni les repères système : personne ne les
    // « lit », et rien ne viendra jamais les marquer.
    if (message.senderId == ref.read(currentUserProvider).valueOrNull?.id) {
      return;
    }
    if (message.isSystem) return;

    _aLEcran.noter(message, fraction);
    if (fraction < _visibiliteMinimale) {
      _attentesDeVisibilite.remove(message.id)?.cancel();
      return;
    }

    // La vue n'est pas encore posée : noté, sans rien compter.
    // [_lireCeQuiEstALEcran] reprendra ce relevé dès qu'elle le sera.
    if (!_aLEcran.vuePosee) return;
    _attendreAvantDeLire(message);
  }

  /// Le chemin ordinaire, une fois la vue posée : la bulle doit rester à
  /// l'écran [_dureeAvantVu], et le serveur n'est prévenu qu'après
  /// [_delaiAvantEnvoi]. C'est ce qui empêche un défilement de « lire ».
  void _attendreAvantDeLire(MessageEntity message) {
    if (_attentesDeVisibilite.containsKey(message.id)) return;

    _attentesDeVisibilite[message.id] = Timer(_dureeAvantVu, () {
      _attentesDeVisibilite.remove(message.id);
      if (!mounted) return;
      // Les deux gardes sont évaluées **à l'échéance**, pas à la réception de
      // l'événement de visibilité.
      //
      // À la réception, `_estAffichee` est encore faux : `VisibilityDetector`
      // rapporte la bulle pendant la transition de route, quand l'emplacement
      // du routeur n'est pas encore `/messages/<id>`. Refuser là annulait le
      // compte à rebours — et comme la visibilité ne change plus ensuite,
      // **aucun autre événement ne venait** : le curseur n'avançait jamais.
      // Constaté le 2026-09-16 sur Pixel 10 Pro XL, deux messages à l'écran
      // pendant deux minutes et `read_at` toujours nul.

      if (!_isAppInForeground || !_estAffichee) return;
      final vu = _vuJusqua;
      if (vu != null && !message.createdAt.isAfter(vu)) return;
      _vuJusqua = message.createdAt;
      _vuJusquaId = message.id;
      _envoiCurseur?.cancel();
      _envoiCurseur = Timer(_delaiAvantEnvoi, _pousserCurseur);
    });
  }

  /// **Ouvrir, c'est lire ce qui est à l'écran** (choix A2 du 2026-09-16).
  ///
  /// Appelé quand la vue vient de se poser, et au retour au premier plan. Ce
  /// qui est affiché à cet instant est lu **tout de suite** : les 400 ms +
  /// 700 ms protègent d'un défilement, et il n'y en a pas — la vue est posée.
  /// Ce qui est sous le pli reste non lu, et le séparateur garde son sens.
  ///
  /// Le repère, lui, a déjà été relevé : [_pousserCurseur] attend la fin du
  /// relevé avant d'écrire quoi que ce soit.
  void _lireCeQuiEstALEcran() {
    if (!mounted) return;
    final cible = plusRecentALire(
      _aLEcran.visibles,
      moi: ref.read(currentUserProvider).valueOrNull?.id,
      dejaVu: _vuJusqua,
    );
    if (cible == null) return;

    if (!_isAppInForeground || !_estAffichee) {
      // Pas réellement affichée (transition, feuille par-dessus) : les comptes
      // à rebours ordinaires, qui réévaluent les gardes à l'échéance. Refuser
      // ici sans rien armer, c'était ne plus jamais lire ces bulles — leur
      // visibilité ne changera plus.
      for (final message in _aLEcran.visibles.toList()) {
        _attendreAvantDeLire(message);
      }
      return;
    }

    _vuJusqua = cible.createdAt;
    _vuJusquaId = cible.id;
    _envoiCurseur?.cancel();
    unawaited(_pousserCurseur());
  }

  /// La vue est posée : à l'image suivante, lire ce qui est à l'écran. Voir
  /// [ReleveALEcran.poser].
  void _apresPlacement() {
    _filetPlacement?.cancel();
    _aLEcran.poser(_lireCeQuiEstALEcran, monte: () => mounted);
  }

  Future<void> _pousserCurseur() async {
    final jusqua = _vuJusqua;
    final jusquaId = _vuJusquaId;
    if (jusqua == null || jusquaId == null || !mounted) return;

    // **Relever, puis marquer.** Dans l'autre ordre, le repère se lirait sur un
    // état déjà « lu » et le séparateur n'aurait plus rien à désigner. Les
    // délais de visibilité (1,1 s) le garantissaient presque toujours, pas sur
    // un réseau lent.
    await _releve.future;
    if (!mounted) return;

    final conversationId = widget.conversationId;
    final passerelle = ref.read(mlsGatewayProvider);

    // Basculée ou non se décide sur `mls_since`, pas sur `enMls` : ce dernier
    // est vrai pour TOUTE conversation dès que le drapeau du compte est
    // ouvert, et une conversation encore en clair n'avait alors jamais ses
    // messages marqués — le curseur MLS n'y trouvait rien.
    var basculee = false;
    try {
      basculee = passerelle != null &&
          await passerelle.mlsSince(conversationId) != null;
      if (basculee) {
        await passerelle.avancerCurseur(conversationId, jusqua);
      }
    } catch (e) {
      debugPrint('ConversationScreen: curseur MLS non avancé ($e)');
    }

    // Les messages en clair, **toujours** — y compris dans une conversation
    // basculée, qui peut porter des messages d'avant la bascule jamais lus.
    // La borne peut être un message MLS : le serveur relit sa date.
    try {
      await ref.read(lectureServeurProvider).avancerJusqua(conversationId, jusquaId);
      _essaisCurseur = 0;
      // Les notifications de la discussion — `message`, `messageReaction` et
      // `messageMention` — sont marquées lues par `marquer_lus_jusqua`
      // elle-même, jusqu'à la même borne (20260919120000) : rien à faire ici.
    } on LectureServeurAbsente {
      // Migration pas encore appliquée : l'ancien chemin, qui marque la
      // conversation entière. C'est ce qui se faisait jusqu'ici — rien ne
      // régresse, et le « jusqu'à » arrive avec la migration.
      if (basculee || !mounted) return;
      final moi = ref.read(currentUserProvider).valueOrNull;
      if (moi == null) return;
      // `markAsRead` rend un `Either` et ne lève pas : rien à rattraper ici.
      await ref
          .read(messageRepositoryProvider)
          .markAsRead(conversationId: conversationId, userId: moi.id);
    } catch (e) {
      // Un refus ou une panne ne se rattrapent PAS par l'ancien chemin : il
      // marquerait aussi ce qui n'a pas été vu. On retente la MÊME borne.
      debugPrint('ConversationScreen: curseur non avancé ($e)');
      _reessayerLeCurseur();
    }

    await _suivreLaLecture();
  }

  /// Retente l'envoi du curseur après un échec.
  ///
  /// On comptait sur « le prochain lot vu » pour repasser. Or il n'y en a
  /// souvent pas : ouvrir une discussion depuis une notification, lire le
  /// message, et rien d'autre n'arrive. L'échec le plus courant est
  /// justement là — au retour d'arrière-plan, la session Supabase n'est pas
  /// encore rétablie et `avancerJusqua` refuse de partir en anon. Le « Lu »
  /// était alors perdu : l'expéditeur restait sur « Distribué » alors que le
  /// message avait été lu, jusqu'au message suivant.
  ///
  /// On relance dès que la session est établie ; sinon à 3, 6 puis 9 s, pour
  /// une panne réseau qui ne s'annonce pas. Même borne, relue au moment de
  /// relancer : le serveur ne marque jamais au-delà de ce qui a été vu.
  void _reessayerLeCurseur() {
    if (!mounted || _essaisCurseur >= 3) return;
    _essaisCurseur++;
    void relancer() {
      _filetCurseur?.cancel();
      _filetCurseur = null;
      unawaited(_attenteSessionCurseur?.cancel());
      _attenteSessionCurseur = null;
      if (mounted) unawaited(_pousserCurseur());
    }

    _filetCurseur?.cancel();
    unawaited(_attenteSessionCurseur?.cancel());
    _attenteSessionCurseur =
        ref.read(sessionSupabaseEtablieProvider).listen((_) => relancer());
    _filetCurseur = Timer(Duration(seconds: 3 * _essaisCurseur), relancer);
  }

  Future<void> _releverCurseur() async {
    try {
      // Un seul point d'entrée, pour les deux magasins : `repere_de_lecture`
      // lit `messages` ET `mls_messages` dans le même instantané.
      final repere = await ref
          .read(lectureServeurProvider)
          .relever(widget.conversationId);
      _curseurALOuverture = repere.curseurA?.toLocal();
      // Rien d'annoncé par la liste (lien profond, notification, démarrage à
      // froid) : le serveur sait jusqu'où vont les non-lus. Sans cette
      // échéance, [_filVaJusquAuBout] tenait le fil du cache pour complet.
      _dernierMessageAnnonce ??= repere.echeanceDuFil?.toLocal();
      if (repere.aUnSeparateur) {
        _repereServeur = (id: repere.premierNonLuId!, nombre: repere.nonLus);
      }
      _suivi.noterOuverture(repere);
      _repereFaitFoi = true;
    } catch (e) {
      debugPrint('ConversationScreen: repère serveur indisponible ($e)');
      await _releverCurseurMls();
    } finally {
      _curseurReleve = true;
      if (!_releve.isCompleted) _releve.complete();
    }
    // La lecture est asynchrone : le comptage a pu passer avant elle.
    if (mounted) _calculateUnreadOnOpen();
  }

  /// Repli quand `repere_de_lecture` ne répond pas : l'ancien relevé, par la
  /// passerelle, qui ne voit que les messages MLS. Au-delà, ce sont les
  /// messages chargés qui décident (voir [_calculateUnreadOnOpen]).
  Future<void> _releverCurseurMls() async {
    try {
      final passerelle = ref.read(mlsGatewayProvider);
      if (passerelle != null) {
        final curseur = await passerelle.curseurDeLecture(widget.conversationId);
        _curseurALOuverture = curseur?.quand.toLocal();

        // Le repère, pris au même instant que le curseur : les deux doivent
        // décrire le même état, sans quoi un message arrivé entre les deux
        // lectures décalerait le compte.
        final premier = await passerelle.premierNonLu(
          widget.conversationId,
          apres: curseur?.quand,
        );
        if (premier != null) {
          final compteurs = await passerelle.nonLus();
          final nombre = compteurs[widget.conversationId]?.nonLus ?? 0;
          if (nombre > 0) {
            _repereServeur = (id: premier.id, nombre: nombre);
            // Même échéance que [_releverCurseur], à défaut du dernier : le fil
            // doit au moins aller jusqu'au premier non-lu.
            _dernierMessageAnnonce ??= premier.quand.toLocal();
          }
        }
      }
    } catch (_) {
      // Curseur indisponible : on retombe sur l'état de lecture des messages
      // chargés.
    }
  }

  /// Cette discussion est-elle **réellement à l'écran** ?
  ///
  /// `_isAppInForeground` ne suffit pas, et la différence coûtait un accusé de
  /// lecture mensonger. `StatefulShellRoute` garde les branches **montées**
  /// quand on change d'onglet : une discussion ouverte puis quittée par
  /// l'onglet Accueil reste vivante, son `didChangeAppLifecycleState` et son
  /// `ref.listen` continuent de tourner, et marquaient lu tout ce qui
  /// arrivait — sans que personne ne regarde.
  ///
  /// Mesuré le 2026-09-15 sur Pixel 10 Pro XL : `read_at` posé **une seconde
  /// après** `delivered_at`, en lot, sur trois messages dont la discussion
  /// n'était pas affichée. Côté expéditeur, « Lu » sur des messages jamais
  /// lus ; côté destinataire, plus aucune pastille de non-lus, jamais.
  ///
  /// **Mesuré, pas supposé.** J'ai d'abord interrogé l'emplacement global du
  /// routeur (`currentConfiguration.uri`), en craignant que
  /// `ModalRoute.isCurrent` ne soit vrai jusque dans une branche d'onglet
  /// inactive. Sur appareil, ce garde rendait **toujours faux** alors que la
  /// discussion était bien à l'écran — le curseur de lecture n'avançait donc
  /// jamais, en silence. Tracé le 2026-09-16 sur Pixel 10 Pro XL :
  /// `fraction=1.0` à chaque bulle, puis `affichee=false` à chaque échéance.
  ///
  /// La crainte ne s'appliquait pas : l'écran de discussion est poussé
  /// **au-dessus** du shell — c'est pourquoi la barre d'onglets disparaît —
  /// et non dans une branche. `ModalRoute.isCurrent` dit donc exactement
  /// « cette route est au sommet », y compris quand une feuille ou un
  /// visionneur passe par-dessus.
  bool get _estAffichee {
    if (!mounted) return false;
    // Absent hors navigateur (un test qui monte l'écran seul) : on ne bloque
    // pas le comportement historique.
    return ModalRoute.of(context)?.isCurrent ?? true;
  }

  bool get _isGroup => widget.isGroup || _isGroupFromConversation;
  String? get _effectiveGroupId => widget.groupId ?? _groupIdFromConversation;
  bool get _isSelfNotes => widget.isSelfNotes || _isSelfNotesFromConversation;
  String? get _effectiveOtherUserId =>
      widget.otherUserId ?? _otherUserIdFromConversation;

  /// Pose, **dès la première image**, ce que l'appareil sait déjà de
  /// l'interlocuteur : son identifiant, puis son profil.
  ///
  /// Les trois sources sont locales et synchrones — l'uid Firebase (tenu en
  /// mémoire dès l'initialisation, sans réseau), la conversation en cache et le
  /// profil en cache. Les providers, eux, ne peuvent pas répondre à temps : un
  /// flux n'émet jamais dans la même image que le premier rendu. L'en-tête
  /// passait donc par « Chargement… » alors que le nom était déjà sur le
  /// disque — d'autant plus visible hors ligne, où la suite ne vient jamais.
  ///
  /// Ne sème rien pour un groupe ou « Mes notes » : ils n'ont pas
  /// d'interlocuteur. Et rien non plus si le compte courant est inconnu — sans
  /// lui, « l'autre participant » ne se calcule pas.
  void _semerIdentiteConnue() {
    final moi = FirebaseAuth.instance.currentUser?.uid;

    // 1. La conversation, telle que le cache local la connaît. Elle porte le
    //    nom et l'image d'un groupe, et la liste des participants d'un DM.
    final connues = ref
        .read(messageRepositoryProvider)
        .getCachedConversations()
        .fold((_) => const <ConversationEntity>[], (liste) => liste);
    for (final conversation in connues) {
      if (conversation.id == widget.conversationId) {
        _conversationConnueAuDemarrage = conversation;
        break;
      }
    }
    final connue = _conversationConnueAuDemarrage;

    // 1 bis. Le compteur de non-lus, pris sur la liste **vivante** et non sur
    //        le cache : pour une conversation chiffrée, le serveur n'écrit
    //        jamais `data.unreadCount`, et la copie en cache dirait zéro. La
    //        liste, elle, l'a reconstitué depuis `mls_unread_counts` — c'est
    //        ce nombre-là qu'affichait la pastille juste avant le tap.
    //
    //        Il faut le prendre **maintenant** : `markAsRead` part au premier
    //        rendu, et tout sera lu quelques millisecondes plus tard.
    if (moi != null) {
      final vivantes = ref.read(conversationsProvider).valueOrNull;
      for (final c in vivantes ?? const <ConversationEntity>[]) {
        if (c.id == widget.conversationId) {
          _nonLusAvantOuverture = c.getUnreadCountFor(moi);
          _dernierMessageAnnonce = c.lastMessageAt;
          break;
        }
      }
    }

    // 2. Sa nature. « Mes notes » se décide par différence avec le compte
    //    courant, comme l'interlocuteur : sans lui, on ne tranche pas.
    if (connue != null) {
      if (connue.isGroup) {
        _isGroupFromConversation = true;
        _groupIdFromConversation = connue.groupId;
      } else if (moi != null && connue.isSelfNotesFor(moi)) {
        _isSelfNotesFromConversation = true;
      }
    }

    // 3. L'interlocuteur d'un tête-à-tête, puis son profil.
    if (_isGroup || _isSelfNotes) return;

    var autreId = widget.otherUserId;
    if (autreId == null && connue != null && moi != null) {
      final autre = connue.getOtherParticipantId(moi);
      if (autre.isNotEmpty) {
        autreId = autre;
        _otherUserIdFromConversation = autre;
      }
    }
    if (autreId == null) return;

    _profilConnuAuDemarrage = ref
        .read(profileRepositoryProvider)
        .getCachedProfile(autreId)
        .fold((_) => null, (profil) => profil);
  }
}

