import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/features/feed/presentation/widgets/feed_error_state.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

/// Bandeau « Fil hors ligne · dernière mise à jour … ».
///
/// Vu sur SM A515F le 2026-09-14 : « dernière mise à jour **Il** y a 11
/// **minute(s)** ». Deux défauts dans une seule ligne — une majuscule en plein
/// milieu de la phrase, parce que le libellé d'âge est écrit pour vivre seul
/// et se retrouve enchâssé ici ; et un pluriel non décliné, là où le reste de
/// l'app décline.
void main() {
  Future<void> poser(WidgetTester tester, {required Duration age}) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: FeedCachedNotice(cachedAt: DateTime.now().subtract(age)),
        ),
      ),
    );
    await tester.pump();
  }

  /// Le texte du bandeau, quel que soit son découpage.
  String texte(WidgetTester tester) =>
      tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? '').join();

  testWidgets('l\'âge s\'enchâsse en minuscule, pas en tête de phrase',
      (tester) async {
    await poser(tester, age: const Duration(minutes: 11));

    expect(texte(tester), contains('il y a 11 minutes'));
    expect(texte(tester), isNot(contains('Il y a')),
        reason: 'une majuscule en milieu de phrase se lit comme une faute');
  });

  testWidgets('le pluriel se décline vraiment', (tester) async {
    await poser(tester, age: const Duration(minutes: 1));
    expect(texte(tester), contains('il y a 1 minute'));
    expect(texte(tester), isNot(contains('minute(s)')),
        reason: '« minute(s) » est un pluriel qu\'on n\'a pas pris la peine '
            'd\'écrire');

    await poser(tester, age: const Duration(hours: 3));
    expect(texte(tester), contains('il y a 3 heures'));

    await poser(tester, age: const Duration(hours: 1));
    expect(texte(tester), contains('il y a 1 heure'));
  });
}
