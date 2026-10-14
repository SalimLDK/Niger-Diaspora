import 'dart:io';

import 'package:diaspo_niger/core/utils/segment_de_route.dart';
import 'package:flutter_test/flutter_test.dart';

/// Audit du module notifications (2026-10-14), côté application.
///
/// 1. Les identifiants d'un push (`eventId`, `postId`, `targetId`…) servaient
///    de segment de route sans contrôle : `x/edit` ouvrait un écran de
///    modification, `?`/`#` greffaient des paramètres.
/// 2. Les notifications du fil tombaient dans le cas par défaut, qui poussait
///    `/notifications/<id de la publication>` — un détail vide.
/// 3. iOS proposait « Répondre » sur toute bannière de message, alors que
///    les réponses rapides sont coupées (`kNotificationQuickActionsEnabled`).
/// 4. Une bannière posée par l'app, touchée app tuée, n'ouvrait rien :
///    `getNotificationAppLaunchDetails` n'était jamais lu.
/// 5. Le texte d'une réponse non traitée partait dans le journal.
/// 6. Un jeton push écarté par le serveur (rattaché à un autre compte) n'était
///    jamais remplacé, et la déconnexion ne faisait pas tourner le jeton.
void main() {
  String lire(String chemin) => File(chemin).readAsStringSync();

  String corps(String source, String signature) {
    final debut = source.indexOf(signature);
    expect(debut, isNot(-1), reason: signature);
    return source.substring(debut, source.indexOf('\n  }\n', debut));
  }

  group('segment de route', () {
    test('un identifiant ordinaire passe', () {
      for (final id in [
        'fW3kQ9xZ2bTnM8pL1aYcR7vH0eJ4',
        '3f2b8a40-1c9d-4e7a-9b1f-2d6c8e0a5b71',
        'group_3f2b8a40-1c9d-4e7a-9b1f-2d6c8e0a5b71',
        'uidA_uidB',
      ]) {
        expect(segmentDeRoute(id), id);
      }
    });

    test('un chemin, un paramètre ou un vide ne passent pas', () {
      for (final id in [
        'x/edit',
        '../admin',
        'abc?tab=1',
        'abc#x',
        '',
        'a b',
        'é',
        'x' * 129,
        null,
      ]) {
        expect(segmentDeRoute(id), isNull, reason: '$id');
      }
    });
  });

  group('source', () {
    test('le toucher sur un push valide ses identifiants', () {
      final app = lire('lib/app.dart');
      final nav = corps(app, 'void _navigateToNotificationTarget(');
      for (final brut in [
        r"route = '/messages/$conversationId';",
        r"'/profile/$senderId'",
        r"'/events/$eventId'",
        r"'/groups/$groupId'",
        r"'/feed/$postId'",
      ]) {
        expect(nav, contains(brut));
      }
      expect('segmentDeRoute('.allMatches(nav).length, greaterThanOrEqualTo(6));
      // Le cas par défaut ne fabrique plus un détail de notification.
      expect(nav, isNot(contains(r"'/notifications/$targetId'")));
      for (final type in ["'postLiked'", "'new_post'", "'mentioned'", "'group_mention'"]) {
        expect(nav, contains('case $type:'), reason: type);
      }
    });

    test('la liste des notifications passe par pousserVersCible', () {
      for (final f in [
        'lib/features/notifications/presentation/screens/notifications_screen.dart',
        'lib/features/notifications/presentation/screens/notification_detail_screen.dart',
      ]) {
        final s = lire(f);
        expect(s, isNot(contains(r"${notification.targetId}'")), reason: f);
        expect(s, contains('pousserVersCible('), reason: f);
      }
    });

    final service = lire('lib/core/services/notification_service.dart');

    test('iOS : pas d\'action « Répondre » tant que les réponses rapides sont coupées', () {
      final debut = service.indexOf("'message_category',");
      final bloc = service.substring(debut, service.indexOf('DarwinNotificationAction.text(', debut));
      expect(bloc, contains('!kNotificationQuickActionsEnabled'));
    });

    test('démarrage à froid : la bannière posée par l\'app est lue', () {
      expect(service, contains('getNotificationAppLaunchDetails()'));
    });

    test('le texte d\'une réponse ne part pas dans le journal', () {
      expect(service, isNot(contains(r'input="${input')));
    });

    test('jeton refusé (23505) : rotation ; déconnexion : rotation', () {
      final save = corps(service, 'Future<void> _saveTokenToDatabase(');
      expect(save, contains("e.code == '23505'"));
      expect(save, contains('_fairTournerLeJeton()'));
      final retrait = corps(service, 'Future<void> removeTokenForUser(');
      expect(retrait, contains('_messaging.deleteToken()'));
      expect(retrait, contains('_fcmToken = null;'));
    });
  });
}
