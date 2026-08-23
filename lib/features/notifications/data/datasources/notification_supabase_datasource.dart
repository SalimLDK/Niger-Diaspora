import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/supabase_auth_bridge.dart';
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

        final stream = _supabase
            .from('notifications')
            .stream(primaryKey: ['id'])
            .eq('user_id', userId)
            .order('created_at', ascending: false)
            .limit(limit);

        await for (final rows in stream) {
          failures = 0;
          lastKnown = _mapRows(rows);
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
      var query = _supabase
          .from('notifications')
          .select()
          .eq('user_id', userId);

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
      final response = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
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

  @override
  Future<void> markAllAsRead(String userId) async {
    try {
      await SupabaseAuthBridge.instance.ensureAuthenticated();
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);
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

  @override
  Future<void> deleteAllNotifications(String userId) async {
    try {
      await SupabaseAuthBridge.instance.ensureAuthenticated();
      await _supabase
          .from('notifications')
          .delete()
          .eq('user_id', userId);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
