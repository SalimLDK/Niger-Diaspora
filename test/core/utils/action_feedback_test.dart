import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/core/utils/action_feedback.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

/// `reportIfFailed` : l'écran dit l'échec d'une écriture, et ne dit rien d'une
/// réussite. Le message de succès (« supprimé », « publié ») reste l'affaire de
/// l'écran, qui ne l'affiche qu'après un `true`.
void main() {
  const message = 'Une erreur est survenue';

  Widget banc(Widget Function(BuildContext) bouton) => MaterialApp(
    locale: const Locale('fr'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: Builder(builder: bouton)),
  );

  testWidgets('échec : un message d\'erreur s\'affiche, et rend false', (
    tester,
  ) async {
    bool? resultat;
    await tester.pumpWidget(
      banc(
        (context) => TextButton(
          onPressed: () async =>
              resultat = await reportIfFailed(context, Future.value(false)),
          child: const Text('go'),
        ),
      ),
    );

    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump();

    expect(resultat, isFalse);
    expect(find.text(message), findsOneWidget);
  });

  testWidgets('réussite : silence, et rend true', (tester) async {
    bool? resultat;
    await tester.pumpWidget(
      banc(
        (context) => TextButton(
          onPressed: () async =>
              resultat = await reportIfFailed(context, Future.value(true)),
          child: const Text('go'),
        ),
      ),
    );

    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump();

    expect(resultat, isTrue);
    expect(find.text(message), findsNothing);
  });

  testWidgets('écran refermé avant le résultat : le message s\'affiche quand '
      'même', (tester) async {
    // Le cas de « supprimer un podcast » : la boîte de dialogue se referme
    // dans la foulée du tap, et la réponse du serveur arrive après. Le
    // messager est pris AVANT l'attente — il vit au niveau de l'app.
    final enCours = Completer<bool>();
    await tester.pumpWidget(
      banc(
        (context) => TextButton(
          onPressed: () => unawaited(
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  body: Builder(
                    builder: (ctx) => TextButton(
                      onPressed: () {
                        unawaited(reportIfFailed(ctx, enCours.future));
                        Navigator.of(ctx).pop();
                      },
                      child: const Text('agir et refermer'),
                    ),
                  ),
                ),
              ),
            ),
          ),
          child: const Text('ouvrir'),
        ),
      ),
    );

    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('agir et refermer'));
    await tester.pumpAndSettle();
    expect(find.text('agir et refermer'), findsNothing, reason: 'écran refermé');

    enCours.complete(false);
    await tester.pump();
    await tester.pump();

    expect(find.text(message), findsOneWidget);
  });
}
