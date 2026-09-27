import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// « Distribué » n'était posé qu'à l'ouverture de la discussion, en même
/// temps que « Lu ». Le gestionnaire FCM d'arrière-plan appelait la RPC sur un
/// `Supabase.instance` jamais initialisé dans son isolate — et sans session,
/// alors que la RPC n'accuse réception que pour l'appelant. L'échec était
/// avalé. Mesuré en production le 2026-09-27 : délai médian envoi → distribué
/// de ~58 h sur 14 jours.
void main() {
  late String source;

  setUpAll(() {
    source = File('lib/core/services/notification_service.dart')
        .readAsStringSync()
        .replaceAll('\r\n', '\n');
  });

  String entre(String debut, String fin) {
    final i = source.indexOf(debut);
    expect(i, isNot(-1), reason: '$debut introuvable');
    final j = source.indexOf(fin, i);
    expect(j, isNot(-1), reason: '$fin introuvable après $debut');
    return source.substring(i, j);
  }

  test("l'accusé d'arrière-plan prépare une session avant la RPC", () {
    final corps = entre(
      'Future<void> _accuserReceptionEnArrierePlan(',
      '\n}\n',
    );
    final session = corps.indexOf('BackgroundReplyService.preparerSession()');
    final rpc = corps.indexOf("rpc('mark_messages_as_delivered'");
    expect(session, isNot(-1));
    expect(rpc, isNot(-1));
    expect(session, lessThan(rpc));
  });

  test('le gestionnaire ne touche plus Supabase sans session', () {
    final handler = entre(
      'Future<void> firebaseMessagingBackgroundHandler(',
      '\n}\n',
    );
    expect(handler, isNot(contains("rpc('mark_messages_as_delivered'")),
        reason: 'la RPC passe par _accuserReceptionEnArrierePlan');
    expect(handler, contains('_accuserReceptionEnArrierePlan('));
  });

  test("l'accusé part APRÈS la bannière", () {
    // L'échange de jeton peut prendre des secondes : il ne doit pas retarder
    // l'affichage de la notification.
    final handler = entre(
      'Future<void> firebaseMessagingBackgroundHandler(',
      '\n}\n',
    );
    expect(
      handler.indexOf('_showFallbackMessageNotification('),
      lessThan(handler.indexOf('_accuserReceptionEnArrierePlan(')),
    );
  });

  test('au premier plan aussi, la session est vérifiée avant la RPC', () {
    final corps = entre(
      'Future<void> _confirmMessageDelivery({',
      '\n  }\n',
    );
    expect(
      corps.indexOf('ensureReadableSession()'),
      lessThan(corps.indexOf("rpc('mark_messages_as_delivered'")),
    );
    expect(corps, contains('ensureReadableSession()'));
  });
}
