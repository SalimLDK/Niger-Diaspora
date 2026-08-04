import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'package:diaspo_niger/core/utils/date_formatter.dart';
import 'package:diaspo_niger/core/utils/date_parsing.dart';

/// Le symptôme rapporté sur appareil : « 02:01 » affiché « 06:01 ».
/// On vérifie ici le bout de la chaîne — de la chaîne ISO jusqu'au texte —
/// sans dépendre du fuseau de la machine de test.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR');
  });

  String heureLocaleAttendue(DateTime utc) =>
      DateFormat('HH:mm').format(utc.toLocal());

  group('affichage d\'une date ISO terminée par Z', () {
    test('formatTime imprime l\'heure locale, pas les composantes UTC', () {
      final date = tryParseLocalDate('2026-08-04T06:01:00Z')!;

      expect(DateFormatter.formatTime(date),
          heureLocaleAttendue(DateTime.utc(2026, 8, 4, 6, 1)));
    });

    test('formatTime reste correct même si une date UTC lui parvient', () {
      // Filet : les modèles normalisent déjà, mais un appelant oublié ne doit
      // pas réintroduire le décalage.
      final utc = DateTime.utc(2026, 8, 4, 6, 1);

      expect(DateFormatter.formatTime(utc), heureLocaleAttendue(utc));
    });

    test('formatDate suit le jour local', () {
      final utc = DateTime.utc(2026, 8, 4, 6, 1);

      expect(DateFormatter.formatDate(utc),
          DateFormat('dd/MM/yyyy').format(utc.toLocal()));
    });
  });

  group('regroupements par jour', () {
    test('un message de maintenant est classé « aujourd\'hui »', () {
      final maintenant = DateTime.now();

      expect(DateFormatter.formatMessageDate(maintenant),
          DateFormatter.formatTime(maintenant));
    });

    test('la même instant en UTC est classé pareil', () {
      // Avant correction, `date.year/month/day` lisait les composantes UTC :
      // un message de fin de soirée basculait au lendemain.
      final maintenant = DateTime.now();

      expect(DateFormatter.formatMessageDate(maintenant.toUtc()),
          DateFormatter.formatMessageDate(maintenant));
    });

    test('la veille est étiquetée « Hier », en local comme en UTC', () {
      // Construit par composantes plutôt que par `subtract(1 jour)` : un
      // changement d'heure rendrait le second flaky (23 h ou 25 h réelles).
      final now = DateTime.now();
      final veille = DateTime(now.year, now.month, now.day, 12)
          .subtract(const Duration(days: 1));

      expect(DateFormatter.formatMessageDate(veille), 'Hier');
      expect(DateFormatter.formatMessageDate(veille.toUtc()), 'Hier');
    });
  });

  group('ancienneté', () {
    test('timeAgo compare des instants : mélanger local et UTC est sans effet',
        () {
      final il5min = DateTime.now().subtract(const Duration(minutes: 5));

      expect(DateFormatter.timeAgo(il5min), 'Il y a 5 min');
      expect(DateFormatter.timeAgo(il5min.toUtc()), 'Il y a 5 min');
    });

    test('timeAgoShort de même', () {
      final il3h = DateTime.now().subtract(const Duration(hours: 3));

      expect(DateFormatter.timeAgoShort(il3h), '3 h');
      expect(DateFormatter.timeAgoShort(il3h.toUtc()), '3 h');
    });
  });

  group('formatPostMeta (fiche « Mes publications »)', () {
    test('affiche l\'heure locale d\'un ISO en Z', () {
      final date = tryParseLocalDate('2026-08-04T06:01:00Z')!;

      expect(DateFormatter.formatPostMeta(date),
          endsWith(heureLocaleAttendue(DateTime.utc(2026, 8, 4, 6, 1))));
    });
  });
}
