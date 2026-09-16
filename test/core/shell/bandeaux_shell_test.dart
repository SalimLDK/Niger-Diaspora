import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/core/services/mise_a_jour_service.dart';
import 'package:diaspo_niger/core/shell/bandeaux_shell.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

/// Le bandeau de `MainShell`, rendu pour de vrai.
///
/// Il était construit dans une méthode privée d'un `State` : aucun banc ne
/// pouvait le poser sans monter le shell, son routeur et ses providers. Or
/// c'est le rendu qui casse, sous une échelle de police augmentée.
///
/// Le bandeau E2EE et l'arbitrage entre les deux étaient tenus ici aussi. Ils
/// sont partis avec lui le 2026-09-16 (raisonnement dans `bandeaux_shell.dart`)
/// et il ne reste qu'une source : plus rien à arbitrer.
///
/// Mesuré sur SM-A515F le 2026-09-14 : avec sa seconde phrase (« Mettez à jour
/// pour profiter des derniers correctifs »), le bandeau de mise à jour occupait
/// un sixième de l'écran, par-dessus l'Accueil comme par-dessus une
/// discussion. La borne de hauteur ci-dessous tient ce gain.
void main() {
  /// SM-A515F en portrait : 1080 px / 2,625 = 411 dp. 320 dp = le plus petit
  /// écran encore vendu ; 2,0 = l'échelle de police maximale d'Android.
  const largeurs = [411.0, 360.0, 320.0];
  const echelles = [1.0, 1.3, 1.6, 2.0];

  Widget banc({
    required Widget Function(AppLocalizations) construis,
    required double echelle,
    required Brightness brillance,
  }) {
    return MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(brightness: brillance),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(echelle),
          ),
          child: Scaffold(
            body: Column(
              children: [construis(AppLocalizations.of(context)!)],
            ),
          ),
        ),
      ),
    );
  }

  void dimensionne(WidgetTester tester, double largeurDp) {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(largeurDp, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget miseAJour(AppLocalizations l10n) => bandeauMiseAJour(
        l10n: l10n,
        // Le plus long numéro plausible : trois segments à deux chiffres.
        notice: const NoticeMiseAJour(
          versionPubliee: '10.20.30',
          brut: '10.20.30+999',
        ),
        surPasMaintenant: () {},
        surMettreAJour: () {},
      );

  group('bandeau de mise à jour', () {
    for (final largeur in largeurs) {
      for (final echelle in echelles) {
        for (final brillance in Brightness.values) {
          testWidgets(
            'ne déborde pas — ${largeur.toInt()} dp, police ×$echelle, '
            '${brillance.name}',
            (tester) async {
              dimensionne(tester, largeur);
              await tester.pumpWidget(banc(
                construis: miseAJour,
                echelle: echelle,
                brillance: brillance,
              ));
              await tester.pump(const Duration(milliseconds: 300));

              expect(tester.takeException(), isNull);
              expect(find.text('Pas maintenant'), findsOneWidget);
              expect(find.text('Mettre à jour'), findsOneWidget);
            },
          );
        }
      }
    }

    testWidgets('tient sous 180 dp de haut à l\'échelle par défaut', (
      tester,
    ) async {
      // Mesuré à 411 dp de large, échelle 1,0 :
      //
      //   2 actions + message long  : 224 dp   <- ce qui était livré
      //   2 actions + message court : 164 dp   <- aujourd'hui
      //   1 action  + message court : 102 dp
      //
      // Les 60 dp du milieu viennent de la seconde phrase, qui faisait passer
      // le message de une à trois lignes. Les 62 dp du bas ne sont PAS
      // gagnables : `MaterialBanner` ne range l'action sur la même ligne que
      // le contenu qu'avec **une seule** action, et supprimer « Pas
      // maintenant » rendrait le bandeau impossible à écarter — il reviendrait
      // à chaque lancement, ce que toute la persistance vise à éviter.
      //
      // Le plafond est donc posé entre les deux : il laisse passer les 164 dp
      // d'aujourd'hui et tombe si le message repasse à plusieurs lignes.
      dimensionne(tester, 411);
      await tester.pumpWidget(banc(
        construis: miseAJour,
        echelle: 1.0,
        brillance: Brightness.light,
      ));
      await tester.pump(const Duration(milliseconds: 300));

      final hauteur = tester.getSize(find.byType(MaterialBanner)).height;
      expect(
        hauteur,
        lessThan(180),
        reason: 'le bandeau mesure ${hauteur.toStringAsFixed(1)} dp',
      );
    });
  });

  testWidgets('les callbacks partent bien, et un seul à la fois', (
    tester,
  ) async {
    var pasMaintenant = 0;
    var mettreAJour = 0;

    dimensionne(tester, 411);
    await tester.pumpWidget(banc(
      construis: (l10n) => bandeauMiseAJour(
        l10n: l10n,
        notice: const NoticeMiseAJour(
          versionPubliee: '2.0.0',
          brut: '2.0.0+100',
        ),
        surPasMaintenant: () => pasMaintenant++,
        surMettreAJour: () => mettreAJour++,
      ),
      echelle: 1.0,
      brillance: Brightness.light,
    ));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Mettre à jour'));
    expect(mettreAJour, 1);
    expect(pasMaintenant, 0);

    await tester.tap(find.text('Pas maintenant'));
    expect(pasMaintenant, 1);
    expect(mettreAJour, 1);
  });

  testWidgets('le message porte le nom de version, jamais le numéro de build', (
    tester,
  ) async {
    // `brut` sert à retenir un refus, il ne doit pas fuir à l'écran : « Diaspo
    // Niger 2.0.0+100 est disponible » ne veut rien dire pour personne.
    dimensionne(tester, 411);
    await tester.pumpWidget(banc(
      construis: miseAJour,
      echelle: 1.0,
      brillance: Brightness.light,
    ));
    await tester.pump(const Duration(milliseconds: 300));

    final texte = tester
        .widgetList<Text>(find.descendant(
          of: find.byType(MaterialBanner),
          matching: find.byType(Text),
        ))
        .map((t) => t.data ?? '')
        .join(' ');
    expect(texte, contains('10.20.30'));
    expect(texte, isNot(contains('+999')));
  });
}
