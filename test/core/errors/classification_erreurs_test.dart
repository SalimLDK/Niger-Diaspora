import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import 'package:diaspo_niger/core/errors/classification_erreurs.dart';
import 'package:diaspo_niger/core/errors/exceptions.dart';

/// Fige les libellés d'erreur **réellement vus dans la console Crashlytics**
/// le 2026-09-10, avec leur volume. Ce ne sont pas des exemples inventés : la
/// classification se fait sur le texte (voir la docstring de
/// `classification_erreurs.dart`), donc seuls des messages authentiques
/// prouvent quelque chose.
void main() {
  group('pannes réseau — vues en production, classées non-fatales', () {
    test('google_fonts hors ligne (4 évts, 3 utilisateurs)', () {
      expect(
        estPanneReseau(
          "Exception: Failed to load font with url "
          "https://fonts.gstatic.com/s/a/ecdb53099b1a68cd.ttf: "
          "ClientException with SocketException: Failed host lookup: "
          "'fonts.gstatic.com' (OS Error: No address associated with hostname)",
        ),
        isTrue,
      );
    });

    test('Supabase injoignable (2 évts, 1 utilisateur)', () {
      expect(
        estPanneReseau(
          "ClientException with SocketException: Failed host lookup: "
          "'zyrfkcjjrhddpfxcgezo.supabase.co' (OS Error: No address "
          "associated with hostname, errno = 7), "
          "uri=https://zyrfkcjjrhddpfxcgezo.supabase.co/rest/v1/users",
        ),
        isTrue,
      );
    });

    test('délai dépassé', () {
      expect(estPanneReseau('TimeoutException after 0:00:30.000000'), isTrue);
    });

    test('la casse ne compte pas', () {
      expect(estPanneReseau('FAILED HOST LOOKUP: example.com'), isTrue);
    });
  });

  group('passerelles — vues en production, classées non-fatales', () {
    test('522 Cloudflare sur getNearbyProfiles (13/10, SM-N976U)', () {
      expect(
        estPanneReseau(
          const PostgrestException(message: 'error code: 522', code: '522'),
        ),
        isTrue,
      );
    });

    test('503 pendant une maintenance Supabase', () {
      expect(
        estPanneReseau(
          const PostgrestException(
            message: '<html>Service Unavailable</html>',
            code: '503',
          ),
        ),
        isTrue,
      );
    });

    test('502 et 504, 520 à 524', () {
      for (final code in const ['502', '504', '520', '521', '523', '524']) {
        expect(
          estPanneReseau(PostgrestException(message: 'x', code: code)),
          isTrue,
          reason: 'code $code',
        );
      }
    });

    test('le corps Cloudflare suffit, même sans code', () {
      expect(
        estPanneReseau(const PostgrestException(message: 'error code: 521')),
        isTrue,
      );
    });

    test('ré-emballée en ServerException, le libellé la trahit encore', () {
      expect(
        estPanneReseau(
          ServerException('Lecture de l\'annuaire refusée : error code: 522'),
        ),
        isTrue,
      );
    });
  });

  group('ce qui doit RESTER fatal', () {
    test('contrainte 23514 à la création d\'un commerce (11 évts le 11/10)', () {
      // Une contrainte violée est un défaut de l'app — le formulaire a laissé
      // passer une valeur que la base refuse — pas une panne d'environnement.
      expect(
        estPanneReseau(
          const PostgrestException(
            message:
                'new row for relation "businesses" violates check constraint '
                '"businesses_phone_check"',
            code: '23514',
          ),
        ),
        isFalse,
      );
    });

    test('JWT expiré : affaire de session, pas de réseau', () {
      expect(
        estPanneReseau(
          const PostgrestException(message: 'JWT expired', code: 'PGRST303'),
        ),
        isFalse,
      );
    });

    test('un 500 vient de l\'origine, pas de la passerelle', () {
      expect(
        estPanneReseau(
          const PostgrestException(
            message: 'Internal Server Error',
            code: '500',
          ),
        ),
        isFalse,
      );
    });

    test('un vrai défaut de code', () {
      expect(
        estPanneReseau(
          "NoSuchMethodError: The getter 'length' was called on null",
        ),
        isFalse,
      );
    });

    test('une assertion de rendu', () {
      expect(
        estPanneReseau('A RenderFlex overflowed by 100 pixels on the bottom.'),
        isFalse,
      );
    });

    test('un état applicatif, même déclenché hors ligne', () {
      // Vue en production (3 évts, 2 utilisateurs). Sa cause profonde est
      // souvent le réseau, mais son libellé ne le dit pas : la reclasser
      // demanderait de décider ce que « fatal » veut dire pour une session
      // absente. Laissée fatale, sciemment.
      expect(
        estPanneReseau(
          'ServerException: Session non établie – reconnectez-vous',
        ),
        isFalse,
      );
    });

    test('null ne classe rien', () {
      expect(estPanneReseau(null), isFalse);
    });
  });
}
