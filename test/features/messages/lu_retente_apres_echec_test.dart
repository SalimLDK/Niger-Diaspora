import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Signalé en production le 2026-09-27 : « Lu » arrive tard, ou pas.
///
/// Un envoi du curseur en échec n'était jamais retenté : l'écran comptait sur
/// « le prochain lot vu ». Ouvrir une discussion depuis une notification, lire
/// le message et ne rien recevoir d'autre ne produit pas de prochain lot — et
/// c'est justement là que l'échec est le plus fréquent, la session Supabase
/// n'étant pas encore rétablie au retour d'arrière-plan. L'expéditeur restait
/// sur « Distribué » jusqu'au message suivant.
void main() {
  late String source;

  setUpAll(() {
    source = File(
      'lib/features/messages/presentation/screens/conversation_screen.dart',
    ).readAsStringSync().replaceAll('\r\n', '\n');
  });

  String corpsDe(String signature) {
    final debut = source.indexOf(signature);
    expect(debut, isNot(-1), reason: '$signature introuvable');
    final fin = source.indexOf('\n  }\n', debut);
    return source.substring(debut, fin);
  }

  test("l'échec de l'envoi du curseur programme un nouvel essai", () {
    final corps = corpsDe('Future<void> _pousserCurseur() async {');
    final echec =
        corps.indexOf("debugPrint('ConversationScreen: curseur non avancé");
    expect(echec, isNot(-1));
    expect(corps.indexOf('_reessayerLeCurseur();', echec), isNot(-1),
        reason: "un échec avalé sans nouvel essai perd le « Lu »");
  });

  test('le nouvel essai part dès que la session est établie', () {
    final corps = corpsDe('void _reessayerLeCurseur() {');
    expect(corps, contains('sessionSupabaseEtablieProvider'));
    expect(corps, contains('_pousserCurseur()'));
    // Borné : une panne durable ne relance pas sans fin.
    expect(corps, contains('_essaisCurseur >= 3'));
  });

  test('le nouvel essai meurt avec l’écran', () {
    final corps = corpsDe('void dispose() {');
    expect(corps, contains('_filetCurseur?.cancel()'));
    expect(corps, contains('_attenteSessionCurseur?.cancel()'));
  });
}
