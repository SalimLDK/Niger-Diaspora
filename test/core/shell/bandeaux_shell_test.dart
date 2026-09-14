import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/core/services/e2ee/e2ee_backup_coordinator.dart';
import 'package:diaspo_niger/core/services/mise_a_jour_service.dart';
import 'package:diaspo_niger/core/shell/bandeaux_shell.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

/// Les deux bandeaux de `MainShell`, rendus pour de vrai.
///
/// Ils étaient construits dans des méthodes privées d'un `State` : aucun banc
/// ne pouvait les poser sans monter le shell, son routeur et ses providers.
/// Or c'est le rendu qui casse — le bandeau E2EE porte **trois** actions, et
/// une échelle de police augmentée les empile.
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

  group('arbitrage entre les deux bandeaux', () {
    // Le risque P1 de tout ce changement, et le seul qui coûte des données :
    // les deux bandeaux partagent un canal qui n'en affiche qu'un à la fois
    // (`clearMaterialBanners()` vide aussi la file). Une notice de mise à jour
    // qui prendrait la place du rappel E2EE ferait perdre des messages au
    // changement d'appareil — pas une mise à jour en retard.
    const notice = NoticeMiseAJour(versionPubliee: '2.0.0', brut: '2.0.0+100');

    test('rien à dire des deux côtés : aucun bandeau', () {
      expect(
        bandeauAPoser(e2ee: E2EEBackupPrompt.none, maj: null),
        isNull,
      );
    });

    test('seule la mise à jour parle : elle passe', () {
      expect(
        bandeauAPoser(e2ee: E2EEBackupPrompt.none, maj: notice),
        notice,
      );
    });

    test('AUCUN prompt E2EE ne se fait doubler par la mise à jour', () {
      // Bouclé sur l'énumération, et pas écrit cas par cas : une valeur
      // ajoutée plus tard à `E2EEBackupPrompt` tomberait sinon en silence du
      // côté de la mise à jour, et ce test ne dirait rien.
      for (final prompt in E2EEBackupPrompt.values) {
        if (prompt == E2EEBackupPrompt.none) continue;
        expect(
          bandeauAPoser(e2ee: prompt, maj: notice),
          prompt,
          reason: '$prompt doit primer sur la notice de mise à jour',
        );
      }
    });

    test('la notice écartée reprend sa place, elle n\'est pas perdue', () {
      // La séquence réelle : le rappel E2EE couvre la notice, puis la personne
      // le traite. `MainShell` rappelle cette fonction à chaque changement
      // d'état, donc la notice doit revenir d'elle-même.
      expect(
        bandeauAPoser(e2ee: E2EEBackupPrompt.needsRestore, maj: notice),
        E2EEBackupPrompt.needsRestore,
      );
      expect(
        bandeauAPoser(e2ee: E2EEBackupPrompt.none, maj: notice),
        notice,
      );
    });

    test('les deux types se comparent par valeur (le dédoublonnage en dépend)',
        () {
      // `MainShell` garde la dernière demande et se tait si elle n'a pas
      // changé. Sans égalité par valeur, il reposerait le même bandeau à
      // chaque rebuild — clignotement garanti.
      expect(
        const NoticeMiseAJour(versionPubliee: '2.0.0', brut: '2.0.0+100'),
        const NoticeMiseAJour(versionPubliee: '2.0.0', brut: '2.0.0+100'),
      );
      expect(
        const NoticeMiseAJour(versionPubliee: '2.0.1', brut: '2.0.1+101'),
        isNot(notice),
      );
      // Passés en `Object`, comme `MainShell` les garde : il compare une
      // demande à la précédente sans savoir de quel type elle était. Écrit
      // avec les types concrets, l'analyseur refuse la comparaison
      // (`unrelated_type_equality_checks`) — alors que c'est exactement le
      // cas qui doit se produire quand un bandeau remplace l'autre.
      final Object prompt = E2EEBackupPrompt.needsBackup;
      final Object miseAJour = notice;
      expect(prompt == miseAJour, isFalse);
    });
  });

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

  group('bandeau E2EE', () {
    // Trois actions et un message plus long que celui de la mise à jour : si
    // l'un des deux déborde, c'est lui. Il n'était tenu par aucun banc.
    for (final largeur in largeurs) {
      for (final echelle in echelles) {
        for (final prompt in [
          E2EEBackupPrompt.needsBackup,
          E2EEBackupPrompt.needsRestore,
        ]) {
          testWidgets(
            'ne déborde pas — ${largeur.toInt()} dp, police ×$echelle, '
            '${prompt.name}',
            (tester) async {
              dimensionne(tester, largeur);
              await tester.pumpWidget(banc(
                construis: (l10n) => bandeauE2EE(
                  l10n: l10n,
                  prompt: prompt,
                  surNePlusRappeler: () {},
                  surPasMaintenant: () {},
                  surAgir: () {},
                ),
                echelle: echelle,
                brillance: Brightness.light,
              ));
              await tester.pump(const Duration(milliseconds: 300));

              expect(tester.takeException(), isNull);
              expect(find.text('Ne plus me le rappeler'), findsOneWidget);
            },
          );
        }
      }
    }
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
