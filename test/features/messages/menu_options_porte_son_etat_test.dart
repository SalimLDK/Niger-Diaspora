import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Le menu d'options d'une discussion affiche l'état qu'on lui passe — et on
/// oubliait de le lui passer. Deux fois déjà : le minuteur des messages
/// éphémères (2026-09-15, il ne pouvait plus être éteint) et la sourdine
/// (2026-09-21, SM A515F : « Mettre en sourdine » affiché pendant la sourdine,
/// aucun moyen de la lever depuis la discussion).
void main() {
  test('conversation_screen passe la sourdine et le minuteur au menu', () {
    final source = File(
      'lib/features/messages/presentation/screens/conversation_screen.dart',
    ).readAsStringSync().replaceAll('\r\n', '\n');
    final debut = source.indexOf('ConversationOptionsModal(');
    expect(debut, isNot(-1));
    final appel = source.substring(debut, source.indexOf('\n          ),', debut));
    expect(appel, contains('isMuted:'));
    expect(appel, contains('autoDeleteAfterSeconds:'));
  });
}
