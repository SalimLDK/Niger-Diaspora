import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/core/theme/app_theme.dart';
import 'package:diaspo_niger/features/embassies/domain/entities/embassy_entity.dart';
import 'package:diaspo_niger/features/embassies/presentation/screens/employee_search_screen.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

/// Mise en page de la recherche d'employés, aux échelles de police 1.0 et 1.1.
///
/// ⚠ **Ce n'est pas un test de non-régression du correctif `isExpanded`.**
/// Vérifié par mutation : en retirant `isExpanded` du champ « Département »,
/// ce test passe toujours. La raison est que le `Text` de chaque élément porte
/// déjà `maxLines: 1` + ellipse, ce qui supprime l'erreur de débordement avant
/// qu'`isExpanded` n'ait à jouer. Les deux bornes se recouvrent ici.
///
/// Ce qu'il apporte réellement : c'est le seul test qui monte
/// `EmployeeSearchScreen`, un écran autrement jamais exercé. Il couvre le
/// rendu de l'en-tête fixe et l'état d'erreur de la liste.
///
/// La police de test rend chaque glyphe carré (1 em), donc les largeurs sont
/// plus grandes qu'à l'écran.
///
/// ⚠ Contrairement au test de référence, on n'attend pas `takeException() ==
/// null` : l'écran instancie un `EmbassyRemoteDataSourceImpl` en champ et
/// appelle `_loadEmployees()` dès `initState`, donc il lève forcément un
/// `FirebaseException` hors appareil. On capture donc nous-mêmes les erreurs
/// de rendu et on n'échoue que sur un débordement — la mise en page, elle,
/// est bien exercée.
void main() {
  const embassy = EmbassyEntity(
    id: 'amb-test',
    name: 'Ambassade du Niger',
    country: 'France',
    city: 'Paris',
    address: '154 rue de Longchamp',
  );

  Widget boot() => ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('fr'),
          home: const EmployeeSearchScreen(embassy: embassy),
        ),
      );

  for (final scale in [1.0, 1.1]) {
    testWidgets(
      'La recherche d\'employés ne déborde pas (échelle $scale)',
      (tester) async {
        // On intercepte avant le binding : sinon la première exception
        // retenue serait celle de Firebase et masquerait le débordement.
        final errors = <FlutterErrorDetails>[];
        final previousOnError = FlutterError.onError;
        FlutterError.onError = errors.add;
        addTearDown(() => FlutterError.onError = previousOnError);

        void expectNoOverflow() {
          final overflows = errors
              .map((d) => d.exception.toString())
              .where((e) => e.contains('overflowed'))
              .toList();
          expect(overflows, isEmpty, reason: overflows.join('\n'));
        }

        // Géométrie du SM A515F.
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.75;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        await tester.pumpWidget(boot());
        await tester.pump();
        expectNoOverflow();

        // Le filtre « Département » est en tête d'écran, hors zone défilante :
        // il est disposé dès la première frame. On laisse la liste se
        // stabiliser pour couvrir aussi l'état d'erreur.
        await tester.pump(const Duration(milliseconds: 300));
        expectNoOverflow();
      },
    );
  }
}
