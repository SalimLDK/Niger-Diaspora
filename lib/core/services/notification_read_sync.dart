import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_auth_bridge.dart';

/// Marque lues les notifications in-app dont la cible a été ouverte ailleurs.
///
/// Signalé le 2026-09-12 : les notifications « déjà ouvertes autre part »
/// restaient non lues. Mesuré le même jour : 73 notifications `message` non
/// lues, dont 45 sur des messages déjà lus. Rien ne reliait l'ouverture d'une
/// cible — une discussion lue, une publication ouverte depuis le fil, une
/// notification push touchée dans le volet système, une demande d'ami
/// acceptée depuis l'écran Amis — à la ligne `notifications` qui la désigne :
/// seul un appui DANS l'écran Notifications la marquait lue.
///
/// Les notifications ne partagent pas de colonne de cible : selon l'émetteur,
/// l'identifiant vit sous `targetId`, `target_id`, `postId`, `eventId`… (cf
/// `NotificationSupabaseDataSource.fromRow`). D'où [keys].
///
/// Best-effort : un échec ne doit jamais gêner l'ouverture de l'écran. Côté
/// base, `mark_messages_as_read` et les déclencheurs de
/// `20260912200000_evenements_notifications_obsoletes.sql` font le même
/// travail pour les discussions et les cibles supprimées.
class NotificationReadSync {
  NotificationReadSync._();

  /// Identifiants acceptés dans le filtre PostgREST. L'identifiant est
  /// interpolé dans une expression `or=(…)` : une virgule, une parenthèse ou
  /// un point y changeraient le sens du filtre. Uuid Supabase, id Firestore
  /// (20 à 28 caractères alphanumériques) : rien d'autre n'est attendu.
  static final RegExp _idSur = RegExp(r'^[A-Za-z0-9_-]{1,128}$');

  static const List<String> _keySur = [
    'targetId',
    'target_id',
    'postId',
    'eventId',
    'groupId',
    'conversationId',
    'messageId',
    'inviteId',
    'senderId',
    'sender_id',
    'actor_id',
    'receiverId',
  ];

  // ── Ce qu'ouvrir un écran suffit à lire ─────────────────────────────────
  //
  // Une notification n'a plus d'objet une fois sa cible vue, quel que soit le
  // chemin qui y a mené : l'écran Notifications, une bannière, un lien, un
  // autre écran. Signalé le 2026-09-19 — « certaines ne se mettent pas comme
  // lues automatiquement » : le profil, la fiche d'un groupe et « Mes
  // commandes » n'en marquaient aucune. Seuls le fil et les événements le
  // faisaient, et les discussions par leur RPC.
  //
  // Les chaînes sont le `name` de `NotificationType` — la valeur exacte de la
  // colonne `type`. `notification_read_sync_test.dart` les compare à l'enum.
  //
  // Volontairement absents, parce qu'ils appellent un GESTE et pas seulement
  // un regard : `groupInvite` (accepter/refuser) et `groupJoinRequest`
  // (approuver/refuser) — la base les ferme quand l'invitation ou la demande
  // est close —, et `friendRequest` (Accepter/Refuser, marquée par
  // `_FriendRequestActions` et `FriendRequestNotifier`).

  /// Ouvrir la fiche d'un groupe les lit : des annonces, ou des choix qui s'y
  /// font sans que la base clôture la notification.
  static const List<String> typesLusParLaFicheDeGroupe = [
    'groupRequestApproved',
    'groupRequestRejected',
    'officialGroupLeave',
    'cityGroupInvite',
  ];

  /// Ouvrir le profil de la personne concernée lit l'annonce de son
  /// acceptation.
  static const List<String> typesLusParLeProfil = [
    'friendAccepted',
    'friendRequestAccepted',
  ];

  /// « Mes commandes » est la destination de tous les types de commande —
  /// l'appui dans la liste, la bannière et la fiche y mènent — et aucun ne
  /// porte l'identifiant de la commande.
  static const List<String> typesLusParMesCommandes = [
    'order',
    'newOrder',
    'orderPaid',
    'orderShipped',
    'orderDelivered',
    'orderCancelled',
    'orderCompleted',
    'orderShippingReminder',
  ];

  /// Les types de la messagerie. Lus par la lecture de la DISCUSSION — le
  /// curseur et les RPC, côté serveur — et jamais par l'ouverture d'un autre
  /// écran : leur `targetId` est un identifiant de conversation.
  static const List<String> typesDeLaMessagerie = [
    'message',
    'messageReaction',
    'messageMention',
    'messageEdited',
  ];

  // Les écrans destinataires. UNE table, lue deux fois : à l'OUVERTURE
  // (`mark…Opened`, appelées par les écrans) et à l'ARRIVÉE d'une notification
  // pendant que l'écran est déjà ouvert ([designeLEcranAffiche], appelée par
  // `LectureALArrivee`). Deux listes de clés recopiées finiraient par diverger.
  //
  // `types: null` = tout type, sauf la messagerie.
  static final _Ecran _fil = _Ecran(
    RegExp(r'^/feed/([^/]+)$'),
    cles: const ['postId', 'targetId', 'target_id'],
  );
  static final _Ecran _evenement = _Ecran(
    RegExp(r'^/events/([^/]+)$'),
    cles: const ['eventId', 'targetId', 'target_id'],
  );
  static final _Ecran _groupe = _Ecran(
    RegExp(r'^/groups/([^/]+)$'),
    cles: const ['groupId', 'targetId', 'target_id'],
    types: typesLusParLaFicheDeGroupe,
  );
  // Trois clés : neuf `friendAccepted` sur dix-sept en production n'ont pas de
  // `targetId`, seulement `target_id` — et `receiverId` désigne la même
  // personne.
  static final _Ecran _profil = _Ecran(
    RegExp(r'^/profile/([^/]+)$'),
    cles: const ['targetId', 'target_id', 'receiverId'],
    types: typesLusParLeProfil,
  );
  static final _Ecran _commandes = _Ecran(
    RegExp(r'^/marketplace/my-orders$'),
    cles: const [],
    types: typesLusParMesCommandes,
  );
  static final List<_Ecran> _ecrans = [
    _fil,
    _evenement,
    _groupe,
    _profil,
    _commandes,
  ];

  /// La publication [postId] vient d'être ouverte.
  static Future<void> markPostOpened(String postId) =>
      markTargetRead(postId, keys: _fil.cles, types: _fil.types);

  /// L'événement [eventId] vient d'être ouvert.
  static Future<void> markEventOpened(String eventId) =>
      markTargetRead(eventId, keys: _evenement.cles, types: _evenement.types);

  /// La fiche du groupe [groupId] vient d'être ouverte.
  static Future<void> markGroupOpened(String groupId) =>
      markTargetRead(groupId, keys: _groupe.cles, types: _groupe.types);

  /// Le profil de [userId] vient d'être ouvert.
  static Future<void> markProfileOpened(String userId) =>
      markTargetRead(userId, keys: _profil.cles, types: _profil.types);

  /// « Mes commandes » vient d'être ouvert.
  static Future<void> markOrdersOpened() => markTypesRead(typesLusParMesCommandes);

  /// La notification de type [type] qui porte [data] a-t-elle pour destination
  /// l'écran affiché à [emplacement] ?
  ///
  /// [emplacement] est un chemin du routeur (`/feed/abc`), tel que le rend
  /// `emplacementAffiche` ; une requête ou une barre finale sont tolérées.
  /// C'est la question que pose l'ARRIVÉE d'une notification : si la réponse
  /// est oui, la personne la regarde déjà.
  static bool designeLEcranAffiche(
    String emplacement, {
    required String type,
    required Map<String, dynamic> data,
  }) {
    final chemin = _normalise(emplacement);
    return _ecrans.any((e) => e.designe(chemin, type, data));
  }

  /// Sans requête, sans barre finale : `/feed/abc/?x=1` → `/feed/abc`.
  static String _normalise(String emplacement) {
    var chemin = emplacement.split('?').first;
    if (chemin.length > 1 && chemin.endsWith('/')) {
      chemin = chemin.substring(0, chemin.length - 1);
    }
    return chemin;
  }

  /// Ce qu'il faut viser pour lire les notifications de l'écran affiché à
  /// [emplacement] — le filtre de sa cible (`null` : l'écran n'a pas de cible,
  /// « Mes commandes ») et les types — ou `null` si cet écran n'est la
  /// destination d'aucune notification, ou si son identifiant n'est pas sûr à
  /// interpoler. Pure : c'est ce que la reprise écrit, sans rien écrire.
  @visibleForTesting
  static ({String? filtre, List<String>? types})? cibleAffichee(
    String emplacement,
  ) {
    final chemin = _normalise(emplacement);
    for (final e in _ecrans) {
      final trouve = e.chemin.firstMatch(chemin);
      if (trouve == null) continue;
      if (e.cles.isEmpty) return (filtre: null, types: e.types);
      final id = trouve.groupCount >= 1 ? trouve.group(1) : null;
      if (id == null) return null;
      final filtre = targetFilter(id, e.cles);
      if (filtre == null) return null;
      return (filtre: filtre, types: e.types);
    }
    return null;
  }

  /// Marque lues les notifications de l'écran affiché à [emplacement], comme
  /// si on venait de l'ouvrir. `null` : cet écran n'est la destination
  /// d'aucune notification, rien n'a été écrit. Sinon, si l'écriture a abouti.
  ///
  /// C'est la REPRISE (`LectureALArrivee.surReprise`) : ce qui est arrivé
  /// pendant que l'application n'était pas au premier plan n'a pas été jugé à
  /// l'arrivée, et un canal coupé n'a rien rejoué.
  static Future<bool?> markDisplayedRead(String emplacement) async {
    final cible = cibleAffichee(emplacement);
    if (cible == null) return null;
    return _marquerLues(types: cible.types, filtreCible: cible.filtre);
  }

  /// Expression `or` qui désigne [id] sous l'une des [keys], ou `null` si
  /// l'identifiant ou une clé n'est pas sûr à interpoler.
  @visibleForTesting
  static String? targetFilter(String id, List<String> keys) {
    if (!_idSur.hasMatch(id) || keys.isEmpty) return null;
    if (keys.any((k) => !_keySur.contains(k))) return null;
    return keys.map((k) => 'data->>$k.eq.$id').join(',');
  }

  /// Marque lues MES notifications non lues qui désignent [id].
  ///
  /// [type] (ou [types], pour plusieurs) restreint à des types de
  /// notification : indispensable quand la clé est partagée par plusieurs
  /// familles (un `groupId` porte aussi les notifications de message du
  /// groupe, qui ne sont pas lues pour autant).
  ///
  /// La lecture d'une DISCUSSION ne passe pas par ici : `marquer_lus_jusqua` et
  /// `mark_messages_as_read` marquent côté serveur `message`, `messageReaction`
  /// et `messageMention`, jusqu'à la borne du dernier message vu — ce qu'un
  /// filtre côté client ne sait pas faire sans deviner sur une date.
  static Future<void> markTargetRead(
    String id, {
    List<String> keys = const ['targetId', 'target_id'],
    String? type,
    List<String>? types,
  }) async {
    final filter = targetFilter(id, keys);
    if (filter == null) return;
    assert(type == null || types == null, 'type OU types, pas les deux');
    await _marquerLues(
      types: types ?? (type == null ? null : [type]),
      filtreCible: filter,
    );
  }

  /// Marque lues MES notifications non lues d'un ou plusieurs [types], sans
  /// autre critère.
  ///
  /// Pour un écran qui EST la destination de toute une famille et n'a pas de
  /// cible à désigner : « Mes commandes » reçoit les huit types de commande,
  /// et aucun ne porte l'identifiant de la commande.
  static Future<void> markTypesRead(List<String> types) async {
    if (types.isEmpty) return;
    await _marquerLues(types: types);
  }

  /// Marque lue MA notification [id].
  ///
  /// Pour une notification qu'on vient de voir ARRIVER (`LectureALArrivee`) :
  /// sa ligne est connue, inutile de la retrouver par type et par cible comme
  /// le font les autres entrées. Ne touche qu'une ligne non lue de l'appelant.
  ///
  /// Rend `true` si la requête est partie et revenue sans erreur. Pas « une
  /// ligne a été touchée » : PostgREST rend 200 sur un `UPDATE` qui ne trouve
  /// rien, et on ne le demande pas (`.select()`).
  static Future<bool> markIdRead(String id) async {
    if (!_idSur.hasMatch(id)) return false;
    return _marquerLues(id: id);
  }

  /// Le code d'une annonce (`data.annonce`) : lettres, chiffres, `.`, `_`, `-`.
  ///
  /// Le point est admis ici — `maj-1.2.1-chiffrement` — alors que [_idSur] le
  /// refuse : un identifiant est interpolé dans une expression `or=(…)`, où un
  /// point change le sens du filtre ; le code d'une annonce va dans un filtre
  /// `eq` simple, dont la valeur n'est jamais interprétée.
  static final RegExp _annonceSure = RegExp(r'^[A-Za-z0-9._-]{1,128}$');

  @visibleForTesting
  static bool codeDAnnonceSur(String code) => _annonceSure.hasMatch(code);

  /// Marque lue MON annonce `system` de code [code].
  ///
  /// Une annonce n'a pas de cible : la table `notifications` n'a pas de colonne
  /// `target_id`, la push part avec `targetId` vide, et l'appui sur la bannière
  /// ouvre la liste. Ce qui l'identifie est `data.annonce`, la clé stable posée
  /// par la diffusion (un code par annonce, un exemplaire par compte) — que
  /// `send-push` recopie dans la push. Restreinte au type `system`.
  static Future<bool> markAnnouncementRead(String code) async {
    if (!_annonceSure.hasMatch(code)) return false;
    return _marquerLues(
      types: const ['system'],
      egal: (colonne: 'data->>annonce', valeur: code),
    );
  }

  /// Rend `true` si la requête a abouti sans erreur (session, réseau, droits) ;
  /// les entrées qui n'ont pas besoin du résultat l'ignorent.
  static Future<bool> _marquerLues({
    List<String>? types,
    String? filtreCible,
    String? id,
    ({String colonne, String valeur})? egal,
  }) async {
    // Tout dans le `try`, y compris l'accès à FirebaseAuth : appelée depuis
    // un `initState`, une exception ici (Firebase pas encore initialisé)
    // ferait échouer l'ouverture de l'écran pour une simple tenue de compteur.
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return false;
      if (!await SupabaseAuthBridge.instance.ensureAuthenticated()) return false;
      var query = Supabase.instance.client
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', uid)
          .eq('is_read', false);
      if (id != null) query = query.eq('id', id);
      if (egal != null) query = query.eq(egal.colonne, egal.valeur);
      if (types != null) query = query.inFilter('type', types);
      if (filtreCible != null) query = query.or(filtreCible);
      await query;
      return true;
    } catch (e) {
      debugPrint('NotificationReadSync: $e');
      return false;
    }
  }

  /// Notification push touchée dans le volet système : la notification
  /// in-app correspondante est lue.
  ///
  /// Le push ne porte pas l'id de la ligne `notifications` (send-push ne le
  /// transmet pas), seulement son type et sa cible — ou, pour une annonce
  /// `system`, son code.
  static Future<void> markPushRead(Map<String, dynamic> data) async {
    final cible = cibleDeLaPush(data);
    if (cible == null) return;
    final annonce = cible.annonce;
    if (annonce != null) {
      await markAnnouncementRead(annonce);
      return;
    }
    await markTargetRead(cible.id!, keys: cible.keys, type: cible.type);
  }

  /// Ce que désigne une push touchée : l'identifiant [id] sous [keys], pour le
  /// type [type] — ou, pour une annonce `system` qui n'a pas de cible, son
  /// [annonce]. `null` si elle ne désigne rien. Pure, donc testable.
  @visibleForTesting
  static ({String? id, List<String> keys, String type, String? annonce})?
  cibleDeLaPush(Map<String, dynamic> data) {
    final type = data['type']?.toString();
    if (type == null || type.isEmpty) return null;

    final conversationId = data['conversationId']?.toString();
    if (type == 'message' && conversationId != null) {
      // Toute la discussion : c'est elle qu'on ouvre, pas un message.
      return (
        id: conversationId,
        keys: const ['conversationId'],
        type: 'message',
        annonce: null,
      );
    }

    final targetId = data['targetId']?.toString() ?? '';
    if (targetId.isNotEmpty) {
      return (
        id: targetId,
        keys: const ['targetId', 'target_id'],
        type: type,
        annonce: null,
      );
    }

    // Sans cible : seule une annonce se retrouve, par son code.
    final annonce = data['annonce']?.toString() ?? '';
    if (type == 'system' && annonce.isNotEmpty) {
      return (id: null, keys: const [], type: 'system', annonce: annonce);
    }
    return null;
  }
}

/// Un écran qui EST la destination de certaines notifications : où il se
/// trouve dans le routeur, sous quelles clés de `data` la notification désigne
/// son objet, et quels types il suffit d'y être pour les lire.
class _Ecran {
  const _Ecran(this.chemin, {required this.cles, this.types});

  /// Le chemin du routeur. Son premier groupe capture l'identifiant de l'objet
  /// affiché ; sans groupe, l'écran n'a pas d'objet (« Mes commandes »).
  final RegExp chemin;

  /// Les clés de `data` qui peuvent porter l'identifiant de l'objet. Vide :
  /// l'écran est la destination de toute la famille, sans identifiant.
  final List<String> cles;

  /// Les types que cet écran suffit à lire. `null` : tous, la messagerie
  /// exceptée — elle a sa propre lecture, côté serveur.
  final List<String>? types;

  bool designe(String emplacement, String type, Map<String, dynamic> data) {
    final trouve = chemin.firstMatch(emplacement);
    if (trouve == null) return false;

    final restreints = types;
    if (restreints == null) {
      if (NotificationReadSync.typesDeLaMessagerie.contains(type)) return false;
    } else if (!restreints.contains(type)) {
      return false;
    }

    if (cles.isEmpty) return true;
    if (trouve.groupCount < 1) return false;
    final id = trouve.group(1);
    if (id == null || id.isEmpty) return false;
    return cles.any((cle) => data[cle]?.toString() == id);
  }
}
