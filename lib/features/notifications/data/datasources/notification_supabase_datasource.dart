import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/supabase_auth_bridge.dart';
import '../../domain/entities/notification_entity.dart';
import '../models/notification_model.dart';
import 'notification_remote_datasource.dart';

class NotificationSupabaseDataSource implements NotificationRemoteDataSource {
  SupabaseClient get _supabase => Supabase.instance.client;

  /// Convertit une ligne `notifications` en modèle.
  ///
  /// Deux pièges traités ici :
  ///
  /// 1. **`targetId` vs `target_id`.** Le modèle ne lisait que `targetId`,
  ///    alors que `NotificationService.createNotification` — donc les demandes
  ///    d'ami, les participations, tout ce qui passe par la RPC — n'écrit que
  ///    `target_id`. La cible arrivait donc nulle, et chaque branche de
  ///    navigation est gardée par `if (targetId != null)` : l'appui sur la
  ///    notification ne faisait rien. On accepte les deux écritures, plus les
  ///    clés spécifiques du fil (`postId`) et des appels (`callId`).
  ///
  /// 2. **Une ligne malformée ne doit pas emporter la liste entière.** `title`
  ///    et `body` sont des `String` requis : une valeur nulle en base levait un
  ///    `TypeError` **à l'intérieur du `.map()` du flux**, qui passait alors en
  ///    erreur — l'écran affichait « erreur de chargement » alors que les
  ///    autres lignes étaient parfaitement lisibles. Elles sont désormais
  ///    repliées sur une chaîne vide, et [_safeFromRow] écarte la ligne fautive
  ///    au lieu de tout faire échouer.
  @visibleForTesting
  NotificationModel fromRow(Map<String, dynamic> row) {
    final data = Map<String, dynamic>.from(
      (row['data'] as Map<String, dynamic>?) ?? {},
    );

    String? firstString(List<String> keys) {
      for (final key in keys) {
        final value = data[key];
        if (value is String && value.isNotEmpty) return value;
        if (value != null && value is! Map && value is! List) {
          final asText = value.toString();
          if (asText.isNotEmpty) return asText;
        }
      }
      return null;
    }

    return NotificationModel.fromJson({
      ...data,
      'id': row['id'].toString(),
      'userId': row['user_id']?.toString() ?? '',
      'type': row['type']?.toString() ?? 'general',
      'title': row['title']?.toString() ?? '',
      'body': row['body']?.toString() ?? '',
      'isRead': row['is_read'] as bool? ?? false,
      'createdAt': row['created_at'],
      'targetId': firstString([
        'targetId',
        'target_id',
        'postId',
        'callId',
        'conversationId',
        'groupId',
        'eventId',
      ]),
      'senderId': firstString([
        'senderId',
        'sender_id',
        'actor_id',
        'actorId',
        'authorId',
        'callerId',
        'fromUserId',
      ]),
    });
  }

  /// [fromRow] tolérant : une ligne illisible est écartée, pas propagée.
  NotificationModel? _safeFromRow(Map<String, dynamic> row) {
    try {
      return fromRow(row);
    } catch (e) {
      debugPrint('NotificationSupabaseDataSource: ligne ignorée ($e)');
      return null;
    }
  }

  List<NotificationModel> _mapRows(List<Map<String, dynamic>> rows) {
    return rows.map(_safeFromRow).whereType<NotificationModel>().toList();
  }

  /// Filtre PostgREST (`or=`) qui écarte les [kTypesHorsEcranNotifications].
  ///
  /// `type.is.null` est gardé explicitement : `NOT IN` rend NULL sur une
  /// valeur nulle, la ligne serait donc écartée — alors que [fromRow] l'affiche
  /// en `general`.
  @visibleForTesting
  static final String filtreTypesAffiches =
      'type.is.null,type.not.in.'
      '(${kTypesHorsEcranNotifications.map((t) => t.name).join(',')})';

  /// Le même critère que [filtreTypesAffiches], sur la valeur brute d'une
  /// ligne reçue par le canal temps réel.
  @visibleForTesting
  static bool typeAffiche(Object? type) =>
      type == null ||
      !kTypesHorsEcranNotifications.any((t) => t.name == type.toString());

  /// Dit si un changement reçu du canal peut modifier la liste affichée.
  ///
  /// - **Insertion** : seulement si son type est affiché. L'arrivée d'un
  ///   message ne coûte ainsi ni requête ni reconstruction de l'écran.
  /// - **Mise à jour** : type affiché, ou ligne déjà à l'écran (qui en sort).
  /// - **Suppression** : l'ancien enregistrement ne porte que la clé primaire
  ///   (pas de `REPLICA IDENTITY FULL`), et Realtime ne sait pas filtrer les
  ///   suppressions — on reçoit celles des autres. Seul critère fiable : la
  ///   ligne était-elle à l'écran ?
  @visibleForTesting
  static bool changementPertinent(
    PostgresChangeEvent evenement,
    Map<String, dynamic> nouveau,
    Map<String, dynamic> ancien,
    Set<String> idsAffiches,
  ) {
    switch (evenement) {
      case PostgresChangeEvent.insert:
        return typeAffiche(nouveau['type']);
      case PostgresChangeEvent.update:
        return typeAffiche(nouveau['type']) ||
            idsAffiches.contains(nouveau['id']?.toString());
      case PostgresChangeEvent.delete:
        return idsAffiches.contains(ancien['id']?.toString());
      case PostgresChangeEvent.all:
        return false;
    }
  }

  PostgrestFilterBuilder<PostgrestList> _selectAffichees(String userId) {
    return _supabase
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .or(filtreTypesAffiches);
  }

  /// Liste affichable, rechargée à chaque changement qui peut la modifier.
  ///
  /// Ce n'est plus `.stream()` : il n'accepte **qu'un** filtre, déjà pris par
  /// `user_id`, et sa limite porte sur les lignes brutes. Les messages étant
  /// écartés de l'écran, les 20 lignes les plus récentes pouvaient toutes en
  /// être : liste vide, et rien à faire défiler pour déclencher la pagination.
  ///
  /// Le canal écoute donc la table, et la requête filtrée fait foi. Les
  /// erreurs remontent dans le flux, où la boucle de [getNotifications] les
  /// traite comme avant.
  Stream<List<NotificationModel>> _fluxAffiches(String userId, int limit) {
    late final StreamController<List<NotificationModel>> controller;
    RealtimeChannel? canal;
    var idsAffiches = <String>{};
    var annule = false;
    var dejaAbonne = false;
    var enCours = false;
    var aRefaire = false;

    Future<void> recharger() async {
      // Des changements arrivés pendant une requête n'en relancent qu'une.
      if (enCours) {
        aRefaire = true;
        return;
      }
      enCours = true;
      try {
        do {
          aRefaire = false;
          final rows = await _selectAffichees(userId)
              .order('created_at', ascending: false)
              .limit(limit);
          if (annule) return;
          final models = _mapRows(rows);
          idsAffiches = models.map((m) => m.id).toSet();
          controller.add(models);
        } while (aRefaire && !annule);
      } catch (e, st) {
        if (!annule) controller.addError(e, st);
      } finally {
        enCours = false;
      }
    }

    controller = StreamController<List<NotificationModel>>(
      onListen: () {
        canal = _supabase
            .channel(
              'notifications-affichees:$userId:'
              '${DateTime.now().microsecondsSinceEpoch}',
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'notifications',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'user_id',
                value: userId,
              ),
              callback: (payload) {
                if (annule) return;
                if (changementPertinent(
                  payload.eventType,
                  payload.newRecord,
                  payload.oldRecord,
                  idsAffiches,
                )) {
                  unawaited(recharger());
                }
              },
            )
            .subscribe((status, [error]) {
              if (annule) return;
              switch (status) {
                case RealtimeSubscribeStatus.subscribed:
                  // Une reconnexion a pu laisser passer des changements.
                  if (dejaAbonne) unawaited(recharger());
                  dejaAbonne = true;
                case RealtimeSubscribeStatus.closed:
                case RealtimeSubscribeStatus.timedOut:
                case RealtimeSubscribeStatus.channelError:
                  controller.addError(
                    StateError('canal notifications : $status ${error ?? ''}'),
                  );
              }
            });
        unawaited(recharger());
      },
      onCancel: () async {
        annule = true;
        final c = canal;
        if (c != null) await _supabase.removeChannel(c);
      },
    );
    return controller.stream;
  }

  /// Flux temps réel des notifications.
  ///
  /// Deux causes distinctes du « erreur de chargement » intermittent sont
  /// traitées ici :
  ///
  /// - **La course à l'ouverture.** L'abonnement partait avec la session
  ///   Supabase du moment. Ouvert avant que le pont Firebase vers Supabase ait
  ///   échangé le jeton, il partait en `anon`, la RLS `notifications_own` ne
  ///   rendait rien et le flux tombait en erreur. On attend donc une session
  ///   lisible avant de s'abonner.
  /// - **La coupure en cours de route.** Une déconnexion realtime (réseau,
  ///   jeton expiré) faisait passer le provider en erreur définitivement :
  ///   l'écran restait sur son message d'erreur jusqu'à ce qu'on le quitte. On
  ///   réessaie maintenant, en conservant à l'écran la dernière liste connue.
  @override
  Stream<List<NotificationModel>> getNotifications(
    String userId, {
    int limit = 20,
  }) async* {
    var failures = 0;
    List<NotificationModel>? lastKnown;

    while (true) {
      try {
        await SupabaseAuthBridge.instance.ensureReadableSession();

        await for (final models in _fluxAffiches(userId, limit)) {
          failures = 0;
          lastKnown = models;
          yield lastKnown;
        }
        return; // Flux clos normalement (provider détruit).
      } catch (e) {
        failures++;
        debugPrint(
          'NotificationSupabaseDataSource: flux interrompu '
          '(essai $failures) : $e',
        );
        // Au-delà de quatre échecs d'affilée, ce n'est plus un incident
        // passager : on laisse l'erreur remonter pour que l'écran le dise.
        if (failures > 4) rethrow;
        if (lastKnown != null) yield lastKnown;
        await Future<void>.delayed(Duration(seconds: failures * 2));
      }
    }
  }

  @override
  Future<List<NotificationModel>> fetchNotifications({
    required String userId,
    int limit = 20,
    DateTime? startAfter,
  }) async {
    try {
      var query = _selectAffichees(userId);

      if (startAfter != null) {
        query = query.lt('created_at', startAfter.toUtc().toIso8601String());
      }

      final rows = await query
          .order('created_at', ascending: false)
          .limit(limit);
      return _mapRows(rows);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<int> getUnreadCount(String userId) async {
    try {
      final response = await _selectAffichees(userId)
          .eq('is_read', false)
          .count(CountOption.exact);
      return response.count;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    try {
      await SupabaseAuthBridge.instance.ensureAuthenticated();
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  /// « Tout lire » ne touche que ce que l'écran montre : une notification de
  /// message reste non lue tant que le message ne l'est pas.
  @override
  Future<void> markAllAsRead(String userId) async {
    try {
      await SupabaseAuthBridge.instance.ensureAuthenticated();
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false)
          .or(filtreTypesAffiches);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> deleteNotification(String notificationId) async {
    try {
      await SupabaseAuthBridge.instance.ensureAuthenticated();
      await _supabase
          .from('notifications')
          .delete()
          .eq('id', notificationId);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  /// Même périmètre que [markAllAsRead] : les lignes de messagerie, que
  /// l'écran ne montre pas, ne sont pas supprimées dans le dos de la personne.
  @override
  Future<void> deleteAllNotifications(String userId) async {
    try {
      await SupabaseAuthBridge.instance.ensureAuthenticated();
      await _supabase
          .from('notifications')
          .delete()
          .eq('user_id', userId)
          .or(filtreTypesAffiches);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
