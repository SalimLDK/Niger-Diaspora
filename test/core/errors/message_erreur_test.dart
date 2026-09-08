import 'package:diaspo_niger/core/errors/message_erreur.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le message affiché ne doit rien laisser filtrer de l'exception.
///
/// Les trois exceptions ci-dessous sont celles réellement rencontrées sur ce
/// projet, recopiées telles quelles. Si un de ces cas rougit, c'est que
/// quelqu'un a remis du détail technique à l'écran.
void main() {
  // Hors ligne, SM A515F, 2026-09-08 — l'hôte du projet ET l'id du compte.
  const pannneReseau =
      "ServerFailure(ClientException with SocketException: Failed host "
      "lookup: 'zyrfkcjjrhddpfxcgezo.supabase.co' (OS Error: No address "
      "associated with hostname, errno = 7), uri=https://"
      "zyrfkcjjrhddpfxcgezo.supabase.co/rest/v1/users?select=%2A&id=eq."
      "vQZE49dTdyRtLwSG6lMIbhAqoFG2)";

  // Refus RLS : PostgREST recopie la requête dans son message.
  const refusDroits =
      'PostgrestException(message: permission denied for table users, '
      'code: 42501, details: null, hint: null)';

  group('rien de technique ne sort', () {
    for (final cas in {
      'panne réseau': pannneReseau,
      'refus de droits': refusDroits,
      'exception quelconque': 'RangeError (index): Invalid value: 42',
    }.entries) {
      test(cas.key, () {
        final message = messageErreurUsager(Exception(cas.value));

        for (final interdit in const [
          'supabase.co',
          'vQZE49dTdyRtLwSG6lMIbhAqoFG2',
          'SocketException',
          'PostgrestException',
          '42501',
          'rest/v1',
          'RangeError',
          'uri=',
        ]) {
          expect(
            message.toLowerCase(),
            isNot(contains(interdit.toLowerCase())),
            reason: '« $interdit » ne doit pas atteindre l\'écran',
          );
        }
      });
    }
  });

  group('la panne est classée pour que le conseil soit juste', () {
    test('réseau : on dit à l\'usager ce qu\'il peut faire', () {
      expect(
        messageErreurUsager(Exception(pannneReseau)),
        contains('réseau'),
      );
    });

    test('droits : on ne lui fait pas réessayer en boucle', () {
      final message = messageErreurUsager(Exception(refusDroits));
      expect(message, contains('droits'));
      expect(
        message.toLowerCase(),
        isNot(contains('réessayez')),
        reason: 'réessayer ne sert à rien face à un refus de droits',
      );
    });

    test('le reste : réessayer est le seul conseil honnête', () {
      expect(
        messageErreurUsager(Exception('boom')),
        contains('Réessayez'),
      );
    });
  });

  test('null ne fait pas tomber la fonction', () {
    expect(messageErreurUsager(null), isNotEmpty);
  });

  test('la variante contextuelle garde le contexte et pas le détail', () {
    final message = messageErreurContextuel(
      'Envoi impossible',
      Exception(pannneReseau),
    );
    expect(message, startsWith('Envoi impossible.'));
    expect(message, isNot(contains('supabase.co')));
  });
}
