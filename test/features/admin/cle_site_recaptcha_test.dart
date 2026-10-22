import 'dart:io';

import 'package:diaspo_niger/features/admin/cle_site_recaptcha.dart';
import 'package:flutter_test/flutter_test.dart';

/// La clé reCAPTCHA v3 du panneau passe par `--dart-define` avec un repli
/// documenté ; elle ne doit plus apparaître en dur dans l'entrée du panneau.
///
/// Sans `--dart-define` (le cas de `flutter test`), la valeur est le repli :
/// c'est ce que vérifie le premier cas. Le second garde `main.dart` libre de
/// tout littéral de clé de site (`6L…`, 40 caractères) — une clé y revient
/// facilement par copier-coller depuis `lib/main.dart`.
void main() {
  test('sans --dart-define, la clé est le repli du projet', () {
    expect(cleSiteRecaptchaAdmin, cleSiteRecaptchaAdminRepli);
    expect(cleSiteRecaptchaAdmin, startsWith('6L'));
    expect(cleSiteRecaptchaAdmin.length, 40);
  });

  test("main.dart du panneau ne porte plus de clé de site en dur", () {
    final source = File('lib/features/admin/main.dart').readAsStringSync();
    final cleDeSite = RegExp(r'6L[0-9A-Za-z_-]{38}');
    expect(
      cleDeSite.hasMatch(source),
      isFalse,
      reason: 'la clé doit venir de cle_site_recaptcha.dart '
          '(--dart-define=ADMIN_RECAPTCHA_SITE_KEY)',
    );
    expect(source, contains('cleSiteRecaptchaAdmin'));
  });
}
