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

  /// La fiche du groupe [groupId] vient d'être ouverte.
  static Future<void> markGroupOpened(String groupId) => markTargetRead(
    groupId,
    keys: const ['groupId', 'targetId', 'target_id'],
    types: typesLusParLaFicheDeGroupe,
  );

  /// Le profil de [userId] vient d'être ouvert.
  ///
  /// Trois clés : neuf `friendAccepted` sur dix-sept en production n'ont pas de
  /// `targetId`, seulement `target_id` — et `receiverId` désigne la même
  /// personne.
  static Future<void> markProfileOpened(String userId) => markTargetRead(
    userId,
    keys: const ['targetId', 'target_id', 'receiverId'],
    types: typesLusParLeProfil,
  );

  /// « Mes commandes » vient d'être ouvert.
  static Future<void> markOrdersOpened() => markTypesRead(typesLusParMesCommandes);

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

  static Future<void> _marquerLues({
    List<String>? types,
    String? filtreCible,
  }) async {
    // Tout dans le `try`, y compris l'accès à FirebaseAuth : appelée depuis
    // un `initState`, une exception ici (Firebase pas encore initialisé)
    // ferait échouer l'ouverture de l'écran pour une simple tenue de compteur.
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      if (!await SupabaseAuthBridge.instance.ensureAuthenticated()) return;
      var query = Supabase.instance.client
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', uid)
          .eq('is_read', false);
      if (types != null) query = query.inFilter('type', types);
      if (filtreCible != null) query = query.or(filtreCible);
      await query;
    } catch (e) {
      debugPrint('NotificationReadSync: $e');
    }
  }

  /// Notification push touchée dans le volet système : la notification
  /// in-app correspondante est lue.
  ///
  /// Le push ne porte pas l'id de la ligne `notifications` (send-push ne le
  /// transmet pas), seulement son type et sa cible.
  static Future<void> markPushRead(Map<String, dynamic> data) async {
    final type = data['type']?.toString();
    if (type == null || type.isEmpty) return;
    final conversationId = data['conversationId']?.toString();
    if (type == 'message' && conversationId != null) {
      // Toute la discussion : c'est elle qu'on ouvre, pas un message.
      return markTargetRead(
        conversationId,
        keys: const ['conversationId'],
        type: 'message',
      );
    }
    final targetId = data['targetId']?.toString() ?? '';
    if (targetId.isEmpty) return;
    return markTargetRead(targetId, type: type);
  }
}
