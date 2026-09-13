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
  ];

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
  /// [type] restreint à un type de notification : indispensable quand la clé
  /// est partagée par plusieurs familles (un `groupId` porte aussi les
  /// notifications de message du groupe, qui ne sont pas lues pour autant).
  static Future<void> markTargetRead(
    String id, {
    List<String> keys = const ['targetId', 'target_id'],
    String? type,
  }) async {
    final filter = targetFilter(id, keys);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (filter == null || uid == null) return;
    try {
      if (!await SupabaseAuthBridge.instance.ensureAuthenticated()) return;
      var query = Supabase.instance.client
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', uid)
          .eq('is_read', false);
      if (type != null) query = query.eq('type', type);
      await query.or(filter);
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
