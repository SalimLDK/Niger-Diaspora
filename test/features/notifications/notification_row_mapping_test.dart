import 'package:diaspo_niger/features/notifications/data/datasources/notification_supabase_datasource.dart';
import 'package:diaspo_niger/features/notifications/domain/entities/notification_entity.dart';
import 'package:flutter_test/flutter_test.dart';

/// Garde-fous du décodage d'une ligne `notifications`.
///
/// Les deux causes du « l'appui sur une notification ne fait rien » vivaient
/// ici, et aucune n'était visible à la relecture : la cible arrivait nulle
/// parce que la clé lue n'était pas celle écrite, et la moitié des types
/// tombait sur `general` faute de correspondance de nom.
void main() {
  final dataSource = NotificationSupabaseDataSource();

  Map<String, dynamic> row({
    String type = 'general',
    Map<String, dynamic> data = const {},
    Object? title = 'Titre',
    Object? body = 'Corps',
  }) => {
    'id': 'n1',
    'user_id': 'u1',
    'type': type,
    'title': title,
    'body': body,
    'is_read': false,
    'created_at': '2026-08-22T10:00:00Z',
    'data': data,
  };

  group('cible de navigation', () {
    test('lit target_id (serpent), écrit par create_user_notification', () {
      final model = dataSource.fromRow(
        row(type: 'friendRequest', data: {'target_id': 'user-42'}),
      );
      expect(model.targetId, 'user-42');
    });

    test('lit targetId (chameau) quand il est présent', () {
      final model = dataSource.fromRow(
        row(type: 'message', data: {'targetId': 'conv-7'}),
      );
      expect(model.targetId, 'conv-7');
    });

    test('le chameau a la priorité si les deux sont présents', () {
      final model = dataSource.fromRow(
        row(data: {'targetId': 'a', 'target_id': 'b'}),
      );
      expect(model.targetId, 'a');
    });

    test('se replie sur postId pour les notifications du fil', () {
      final model = dataSource.fromRow(
        row(type: 'new_post', data: {'postId': 'post-9'}),
      );
      expect(model.targetId, 'post-9');
    });

    test('senderId accepte actor_id, posé par la RPC', () {
      final model = dataSource.fromRow(row(data: {'actor_id': 'moi'}));
      expect(model.senderId, 'moi');
    });
  });

  group('type', () {
    test('serpent des déclencheurs SQL', () {
      expect(
        dataSource.fromRow(row(type: 'new_post')).toEntity().type,
        NotificationType.newPost,
      );
      expect(
        dataSource.fromRow(row(type: 'group_mention')).toEntity().type,
        NotificationType.groupMention,
      );
      expect(
        dataSource.fromRow(row(type: 'report_resolved')).toEntity().type,
        NotificationType.reportResolved,
      );
    });

    test('chameau du client', () {
      expect(
        dataSource.fromRow(row(type: 'friendRequest')).toEntity().type,
        NotificationType.friendRequest,
      );
      expect(
        dataSource.fromRow(row(type: 'groupCallInvitation')).toEntity().type,
        NotificationType.groupCallInvitation,
      );
    });

    test('un type inconnu reste general, sans lever', () {
      expect(
        dataSource.fromRow(row(type: 'quelque_chose_de_neuf')).toEntity().type,
        NotificationType.general,
      );
    });
  });

  group('tolérance aux lignes abîmées', () {
    test('title/body nuls ne lèvent plus — la liste entière tombait avec', () {
      final model = dataSource.fromRow(row(title: null, body: null));
      expect(model.title, '');
      expect(model.body, '');
    });

    test('data absent est traité comme vide', () {
      final r = row()..remove('data');
      final model = dataSource.fromRow(r);
      expect(model.targetId, isNull);
    });
  });
}
