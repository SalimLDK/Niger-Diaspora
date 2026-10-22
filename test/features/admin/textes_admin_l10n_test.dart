// Les textes du panneau admin qui étaient écrits en dur dans les écrans :
// chaque clé existe dans les deux langues, et celles qui portent un paramètre
// le placent au bon endroit (un `{id}` oublié afficherait le gabarit tel quel).
import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/l10n/app_localizations_en.dart';
import 'package:diaspo_niger/l10n/app_localizations_fr.dart';

void main() {
  final fr = AppLocalizationsFr();
  final en = AppLocalizationsEn();

  test('les textes à paramètre les placent', () {
    expect(fr.adminDisputeNumber('ab12cd34'), 'Litige #ab12cd34');
    expect(en.adminDisputeNumber('ab12cd34'), 'Dispute #ab12cd34');
    expect(fr.adminReportTypeLine('Utilisateur'), 'Type : Utilisateur');
    expect(en.adminExportLabel('CSV'), 'Export CSV');
    expect(fr.adminExportLabel('CSV'), 'Exporter CSV');
  });

  test("l'anglais n'est pas une copie du français", () {
    expect(en.adminMenuVerifyProfile, isNot(fr.adminMenuVerifyProfile));
    expect(en.adminDetailSender, isNot(fr.adminDetailSender));
    expect(en.adminForceLogoutBody, isNot(fr.adminForceLogoutBody));
    expect(en.adminAuditHistoryTitle, isNot(fr.adminAuditHistoryTitle));
  });

  test('aucun texte ne garde un gabarit non résolu', () {
    for (final t in [
      fr.adminDisputeNumber('x'),
      en.adminDisputeNumber('x'),
      fr.adminReportTypeLine('x'),
      en.adminReportTypeLine('x'),
    ]) {
      expect(t, isNot(contains('{')));
    }
  });
}
