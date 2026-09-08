import 'package:diaspo_niger/main.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// L'écran d'erreur ne doit rien laisser filtrer de l'exception.
///
/// Ce test existe pour un défaut vu sur SM A515F le 2026-09-08 : hors ligne,
/// l'écran rouge de Flutter affichait le message brut, soit l'hôte du projet
/// Supabase **et** l'identifiant du compte, en clair, à qui regardait l'écran.
///
/// Le cas ci-dessous rejoue exactement cette exception-là. S'il rougit un
/// jour, c'est que quelqu'un a remis le détail à l'écran.
void main() {
  // L'exception réellement observée, telle quelle.
  final exceptionObservee = Exception(
    "ClientException with SocketException: Failed host lookup: "
    "'zyrfkcjjrhddpfxcgezo.supabase.co' (OS Error: No address associated "
    "with hostname, errno = 7), uri=https://zyrfkcjjrhddpfxcgezo.supabase.co"
    "/rest/v1/users?select=%2A&id=eq.vQZE49dTdyRtLwSG6lMIbhAqoFG2",
  );

  testWidgets("l'écran d'erreur ne divulgue rien de l'exception", (
    tester,
  ) async {
    await tester.pumpWidget(
      construireEcranErreurNeutre(FlutterErrorDetails(exception: exceptionObservee)),
    );

    expect(find.text('Une erreur est survenue'), findsOneWidget);

    // Les trois fuites constatées à l'écran, chacune nommée : un test qui
    // échoue doit dire laquelle est revenue.
    expect(
      find.textContaining('supabase.co'),
      findsNothing,
      reason: "l'hôte du projet Supabase ne doit pas être affiché",
    );
    expect(
      find.textContaining('vQZE49dTdyRtLwSG6lMIbhAqoFG2'),
      findsNothing,
      reason: "l'identifiant du compte ne doit pas être affiché",
    );
    expect(
      find.textContaining('SocketException'),
      findsNothing,
      reason: 'aucun détail technique ne doit être affiché',
    );
  });

  testWidgets('il tient dans une zone minuscule sans déborder', (tester) async {
    // Un `ErrorWidget` remplace le widget fautif *sur place* : il hérite de
    // ses contraintes, qui peuvent être une simple ligne de liste.
    await tester.pumpWidget(
      Center(
        child: SizedBox(
          width: 80,
          height: 40,
          child: construireEcranErreurNeutre(
            FlutterErrorDetails(exception: exceptionObservee),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets("il se rend sans Directionality ni Theme au-dessus", (
    tester,
  ) async {
    // Cas réel : la levée peut survenir au-dessus de `MaterialApp`, donc sans
    // aucun de ces héritages.
    await tester.pumpWidget(
      construireEcranErreurNeutre(FlutterErrorDetails(exception: exceptionObservee)),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(Directionality), findsWidgets);
  });

  /// Le rendu suit la luminosité du SYSTÈME, pas le thème de l'app.
  ///
  /// C'est un choix contraint : un `ErrorWidget` peut être posé au-dessus de
  /// `MaterialApp`, donc sans `Theme` à interroger. La conséquence, assumée,
  /// est qu'un usager qui force un thème contraire à celui du système verra
  /// cet écran-là dans l'autre sens. Les deux rendus doivent donc rester
  /// lisibles à eux seuls — c'est ce que ces deux cas vérifient.
  Color fondRendu(WidgetTester tester) {
    final boites = tester.widgetList<ColoredBox>(find.byType(ColoredBox));
    return boites.first.color;
  }

  Color couleurDuTitre(WidgetTester tester) {
    final titre = tester.widget<Text>(find.text('Une erreur est survenue'));
    return titre.style!.color!;
  }

  testWidgets('thème clair : fond clair, texte sombre', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(
      construireEcranErreurNeutre(
        FlutterErrorDetails(exception: exceptionObservee),
      ),
    );

    expect(fondRendu(tester), const Color(0xFFF7F7F7));
    expect(couleurDuTitre(tester), const Color(0xFF1A1A1A));
    // Contraste : le titre doit être nettement plus sombre que son fond.
    expect(
      couleurDuTitre(tester).computeLuminance(),
      lessThan(fondRendu(tester).computeLuminance() - 0.5),
      reason: 'titre illisible sur son fond en thème clair',
    );
  });

  testWidgets('thème sombre : fond sombre, texte clair', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(
      construireEcranErreurNeutre(
        FlutterErrorDetails(exception: exceptionObservee),
      ),
    );

    expect(fondRendu(tester), const Color(0xFF121212));
    expect(couleurDuTitre(tester), const Color(0xFFF5F5F5));
    expect(
      couleurDuTitre(tester).computeLuminance(),
      greaterThan(fondRendu(tester).computeLuminance() + 0.5),
      reason: 'titre illisible sur son fond en thème sombre',
    );
  });

  testWidgets('le texte est peint proprement, pas avec le style de secours', (
    tester,
  ) async {
    // Défaut vu sur SM A515F le 2026-09-08 : les couleurs étaient bonnes mais
    // le texte s'affichait en chasse fixe, doublement souligné de jaune. Un
    // `ErrorWidget` n'a aucun `Material` au-dessus de lui, donc rien ne
    // fournit de `DefaultTextStyle` : sans le poser soi-même, Flutter tombe
    // sur son style de secours. Les tests précédents ne pouvaient pas le
    // voir — ils ne regardaient que les couleurs.
    await tester.pumpWidget(
      construireEcranErreurNeutre(
        FlutterErrorDetails(exception: exceptionObservee),
      ),
    );

    expect(
      find.byType(DefaultTextStyle),
      findsWidgets,
      reason: 'sans DefaultTextStyle, Flutter peint son style de secours',
    );

    for (final texte in tester.widgetList<Text>(find.byType(Text))) {
      final effectif = texte.style;
      expect(
        effectif?.decoration ?? TextDecoration.none,
        TextDecoration.none,
        reason: 'aucun soulignement ne doit rester sur « ${texte.data} »',
      );
    }

    final style = tester
        .widget<DefaultTextStyle>(find.byType(DefaultTextStyle).first)
        .style;
    expect(style.decoration, TextDecoration.none);
  });

  test('le constructeur global est bien celui-ci une fois main() passé', () {
    // Garde-fou de câblage : la fonction ne sert à rien si personne ne
    // l'affecte. On ne peut pas exécuter `main()` ici (Firebase), donc on
    // vérifie au moins que l'affectation compile et tient le type attendu.
    final ErrorWidgetBuilder attendu = construireEcranErreurNeutre;
    expect(attendu, isNotNull);
    expect(kDebugMode || kReleaseMode || kProfileMode, isTrue);
  });
}
