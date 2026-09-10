import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/core/errors/classification_erreurs.dart';

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

  group('ce qui doit RESTER fatal', () {
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
          'ServerException: Session Supabase non établie – reconnectez-vous',
        ),
        isFalse,
      );
    });

    test('null ne classe rien', () {
      expect(estPanneReseau(null), isFalse);
    });
  });
}
