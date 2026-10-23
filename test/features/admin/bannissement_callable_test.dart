// Le bannissement part du panneau vers la Cloud Function `setUserBanned`
// (functions/bannissement.js), plus vers Postgres en direct (2026-10-14).
//
// Ce qui est verrouillé ici : les arguments que le panneau envoie, ce qu'il
// lit dans la réponse, et ce qu'il MONTRE d'un refus — le message du serveur
// pour les codes qu'il écrit en français, un message neutre pour le reste.
// L'appel lui-même (Firebase) est hors d'un test unitaire ; la callable a son
// banc dans `functions/test/bannissement.test.js`.
import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/features/admin/presentation/providers/admin_provider.dart';
import 'package:diaspo_niger/features/admin/presentation/providers/refus_callable.dart';

void main() {
  group('argumentsSetUserBanned', () {
    test('bannir : uid, banned vrai, motif', () {
      expect(
        argumentsSetUserBanned('uid-1', banned: true, reason: 'spam'),
        {'uid': 'uid-1', 'banned': true, 'reason': 'spam'},
      );
    });

    test("débannir : uid et banned faux, sans motif ni identité d'admin", () {
      final args = argumentsSetUserBanned('uid-1', banned: false);
      expect(args, {'uid': 'uid-1', 'banned': false});
      // Le serveur lit l'admin dans le jeton de l'appel et remet `ban_reason`
      // à null lui-même : rien de tout cela ne part du client.
      expect(args.keys, isNot(contains('reason')));
      expect(args.keys, isNot(contains('adminId')));
      expect(args.keys, isNot(contains('banned_by')));
    });

    test('un motif passé au débannissement est ignoré', () {
      expect(
        argumentsSetUserBanned('uid-1', banned: false, reason: 'x'),
        {'uid': 'uid-1', 'banned': false},
      );
    });

    test('bannir sans motif envoie une chaîne vide : au serveur de refuser', () {
      // « reason requis pour bannir » côté serveur ; on ne fabrique rien ici.
      expect(argumentsSetUserBanned('uid-1', banned: true)['reason'], '');
    });
  });

  group('motifReponseSetUserBanned', () {
    test('journalisé : rien à dire, la méthode rendra vrai', () {
      expect(
        motifReponseSetUserBanned(
          {'uid': 'u', 'banned': true, 'action': 'ban_user', 'journalise': true},
          banned: true,
        ),
        isNull,
      );
      expect(
        motifReponseSetUserBanned({'journalise': true}, banned: false),
        isNull,
      );
    });

    test("non journalisé : le dit, avec l'action, comme toute action du panneau", () {
      final ban = motifReponseSetUserBanned({'journalise': false}, banned: true);
      final unban =
          motifReponseSetUserBanned({'journalise': false}, banned: false);
      expect(ban, contains('ban_user'));
      expect(ban, contains('admin_audit_logs'));
      expect(unban, contains('unban_user'));
      expect(unban, isNot(contains(' ban_user')));
    });

    test("une réponse d'une autre forme n'est pas un succès", () {
      expect(motifReponseSetUserBanned(null, banned: true), isNotNull);
      expect(motifReponseSetUserBanned('ok', banned: true), isNotNull);
      expect(
        motifReponseSetUserBanned({'journalise': 'true'}, banned: true),
        isNotNull,
      );
      expect(motifReponseSetUserBanned(<String, dynamic>{}, banned: true),
          isNotNull);
    });
  });

  group('messageRefusDepuisCode', () {
    const droits = "Vous n'avez pas les droits nécessaires pour cette action.";
    const reseau =
        'Connexion indisponible. Vérifiez votre réseau, puis réessayez.';
    const autre = 'Une erreur est survenue. Réessayez.';

    test('les codes que le serveur écrit en français sont montrés tels quels', () {
      for (final code in codesRefusAffichables) {
        expect(messageRefusDepuisCode(code, 'Compte introuvable'),
            'Compte introuvable',
            reason: code);
      }
    });

    test('les refus de bannissement.js, mot pour mot', () {
      const refus = {
        'permission-denied': 'Impossible de se bannir soi-même',
        'not-found': 'Compte introuvable',
        'invalid-argument': 'reason requis pour bannir',
        'internal':
            'Compte banni en base (éjecté) mais pas encore désactivé côté '
                'Firebase : relancer l\'appel',
      };
      refus.forEach((code, message) {
        expect(messageRefusDepuisCode(code, message), message, reason: code);
      });
      expect(
        messageRefusDepuisCode(
          'permission-denied',
          "Un superAdmin ne se bannit pas : lui retirer son rôle d'abord",
        ),
        "Un superAdmin ne se bannit pas : lui retirer son rôle d'abord",
      );
    });

    test('un code hors liste ne montre pas son message', () {
      expect(
        messageRefusDepuisCode('unauthenticated', 'Authentification requise'),
        autre,
      );
      expect(
        messageRefusDepuisCode('deadline-exceeded', 'DEADLINE_EXCEEDED'),
        autre,
      );
      expect(messageRefusDepuisCode('unknown', 'stack trace…'), autre);
    });

    test('unavailable : le code sert aussi au SDK hors ligne — message réseau', () {
      expect(codesRefusAffichables, isNot(contains('unavailable')));
      expect(messageRefusDepuisCode('unavailable', 'UNAVAILABLE'), reseau);
      expect(
        messageRefusDepuisCode('unavailable', 'Base de données injoignable'),
        reseau,
      );
    });

    test('message vide ou blanc : classement par le code seul', () {
      expect(messageRefusDepuisCode('permission-denied', ''), droits);
      expect(messageRefusDepuisCode('permission-denied', '   '), droits);
      expect(messageRefusDepuisCode('permission-denied', null), droits);
      expect(messageRefusDepuisCode('not-found', null), autre);
    });

    test("l'exception, quand elle est là, sert au classement, jamais à l'affichage", () {
      expect(
        messageRefusDepuisCode(
          'unknown',
          null,
          erreur: Exception('SocketException: Failed host lookup: x.y'),
        ),
        reseau,
      );
      expect(
        messageRefusDepuisCode(
          'unknown',
          null,
          erreur: Exception('[firebase_functions/unknown] 42501 secret'),
        ),
        droits,
      );
    });
  });
}
