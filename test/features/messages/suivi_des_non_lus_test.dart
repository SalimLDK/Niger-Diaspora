import 'package:diaspo_niger/features/messages/data/datasources/lecture_serveur.dart';
import 'package:diaspo_niger/features/messages/presentation/utils/suivi_des_non_lus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Ce que ces tests protègent
/// --------------------------
/// Étape B du plan du séparateur. Avant : « N messages non lus » et le badge du
/// bouton « aller en bas » gardaient le compte d'ouverture jusqu'à la
/// fermeture de l'écran, même tout lu.
///
/// Trois règles, chacune avec sa façon de mal tourner :
///
/// - **le séparateur part quand tout ce qui était non lu est lu** — pas quand
///   il n'y a plus AUCUN non-lu : dans une discussion active, il ne partirait
///   jamais ;
/// - **jamais sous les yeux** — retirer une ligne qu'on regarde fait sauter le
///   fil. Il part en sortant de l'écran. Et comme `VisibilityDetector` rapporte
///   par lots de 500 ms, un séparateur entré à l'écran à l'instant doit être vu
///   comme tel ;
/// - **il ne revient pas** — un message reçu en direct n'est pas « non lu
///   depuis l'ouverture ».
final _t0 = DateTime.utc(2026, 9, 17, 10);
DateTime _a(int minutes) => _t0.add(Duration(minutes: minutes));

RepereDeLecture _repere({
  DateTime? curseur,
  int nonLus = 0,
  DateTime? dernier,
}) =>
    RepereDeLecture(
      curseurId: curseur == null ? null : 'c',
      curseurA: curseur,
      premierNonLuId: nonLus > 0 ? 'p' : null,
      nonLus: nonLus,
      dernierNonLuId: dernier == null ? null : 'd',
      dernierNonLuA: dernier,
    );

void main() {
  group('toutEstLu', () {
    test('plus aucun non-lu : tout est lu', () {
      expect(toutEstLu(_repere(curseur: _a(5))), isTrue);
    });

    test('le curseur a atteint le dernier non-lu d\'ouverture, même si d\'autres sont arrivés', () {
      // Le cas d'une discussion active : deux messages reçus pendant la lecture.
      expect(
        toutEstLu(_repere(curseur: _a(5), nonLus: 2), dernierNonLuALOuverture: _a(5)),
        isTrue,
      );
    });

    test('pas encore atteint', () {
      expect(
        toutEstLu(_repere(curseur: _a(4), nonLus: 3), dernierNonLuALOuverture: _a(5)),
        isFalse,
      );
    });

    test('sans borne d\'ouverture (migration absente), seul « plus aucun non-lu » vaut', () {
      expect(toutEstLu(_repere(curseur: _a(9), nonLus: 1)), isFalse);
    });
  });

  group('SuiviDesNonLus', () {
    SuiviDesNonLus ouvert({DateTime? dernier}) =>
        SuiviDesNonLus()..noterOuverture(_repere(nonLus: 5, dernier: dernier ?? _a(5)));

    test('le badge part du compte d\'ouverture, puis descend', () {
      final suivi = ouvert();
      expect(suivi.restants(5), 5);
      expect(suivi.suivre(_repere(curseur: _a(2), nonLus: 3)), isTrue);
      expect(suivi.restants(5), 3);
    });

    test('tout lu, séparateur hors de l\'écran : il part tout de suite', () {
      final suivi = ouvert();
      expect(suivi.suivre(_repere(curseur: _a(5))), isTrue);
      expect(suivi.toutLu, isTrue);
      expect(suivi.separateurRetire, isTrue);
    });

    test('tout lu, séparateur à l\'écran : il reste, puis part en sortant', () {
      final suivi = ouvert();
      expect(suivi.signalerSeparateur(1), isFalse);
      suivi.suivre(_repere(curseur: _a(5)));
      expect(suivi.toutLu, isTrue);
      expect(suivi.separateurRetire, isFalse, reason: 'il partirait sous les yeux');

      expect(suivi.signalerSeparateur(0.4), isFalse, reason: 'encore en partie visible');
      expect(suivi.signalerSeparateur(0), isTrue);
      expect(suivi.separateurRetire, isTrue);
    });

    test('pas tout lu : sortir de l\'écran ne le retire pas', () {
      final suivi = ouvert();
      suivi.signalerSeparateur(1);
      suivi.suivre(_repere(curseur: _a(2), nonLus: 3));
      expect(suivi.signalerSeparateur(0), isFalse);
      expect(suivi.separateurRetire, isFalse);
    });

    test('une fois parti, il ne revient pas — même si des messages arrivent', () {
      final suivi = ouvert();
      suivi.suivre(_repere(curseur: _a(5)));
      expect(suivi.separateurRetire, isTrue);

      // Trois messages reçus en direct, puis un nouveau relevé.
      suivi.suivre(_repere(curseur: _a(5), nonLus: 3));
      suivi.signalerSeparateur(1);
      suivi.signalerSeparateur(0);
      expect(suivi.separateurRetire, isTrue);
      expect(suivi.toutLu, isTrue);
    });

    test('on cesse d\'interroger le serveur quand il n\'y a plus rien à faire', () {
      final suivi = ouvert();
      expect(suivi.doitSuivre, isTrue);
      suivi.suivre(_repere(curseur: _a(5)));
      expect(suivi.doitSuivre, isFalse);
    });

    test('tout lu mais des arrivées non lues : le badge continue de suivre', () {
      final suivi = ouvert();
      suivi.suivre(_repere(curseur: _a(5), nonLus: 2));
      expect(suivi.toutLu, isTrue);
      expect(suivi.restants(5), 2);
      expect(suivi.doitSuivre, isTrue);
    });

    test('un relevé identique ne demande pas de redessiner', () {
      final suivi = ouvert();
      suivi.suivre(_repere(curseur: _a(2), nonLus: 3));
      expect(suivi.suivre(_repere(curseur: _a(2), nonLus: 3)), isFalse);
    });
  });

  group('contre un vrai ListView', () {
    // Le séparateur est la 3e ligne en partant du bas d'une liste inversée de
    // 40 lignes de 80 px : à l'écran à l'ouverture.
    Future<ScrollController> monter(WidgetTester tester, SuiviDesNonLus suivi) async {
      final defilement = ScrollController();
      addTearDown(defilement.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView.builder(
              controller: defilement,
              reverse: true,
              itemCount: 40,
              itemExtent: 80,
              itemBuilder: (_, i) => i == 2 && !suivi.separateurRetire
                  ? VisibilityDetector(
                      key: const ValueKey('separateur-non-lus'),
                      onVisibilityChanged: (info) => suivi.signalerSeparateur(info.visibleFraction),
                      child: const Text('3 messages non lus'),
                    )
                  : Text('m$i'),
            ),
          ),
        ),
      );
      return defilement;
    }

    Future<void> demonter(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 600));
    }

    setUp(() {
      VisibilityDetectorController.instance.updateInterval = const Duration(milliseconds: 500);
    });

    testWidgets('tout lu dans les 500 ms de son apparition : il ne part PAS sous les yeux',
        (tester) async {
      final suivi = SuiviDesNonLus()..noterOuverture(_repere(nonLus: 3, dernier: _a(5)));
      await monter(tester, suivi);
      // Aucun lot n'est encore parti : sans vidage, le suivi le croirait absent.
      VisibilityDetectorController.instance.notifyNow();
      suivi.suivre(_repere(curseur: _a(5)));

      expect(suivi.toutLu, isTrue);
      expect(suivi.separateurRetire, isFalse);
      await demonter(tester);
    });

    testWidgets('il part en sortant de l\'écran', (tester) async {
      final suivi = SuiviDesNonLus()..noterOuverture(_repere(nonLus: 3, dernier: _a(5)));
      final defilement = await monter(tester, suivi);
      VisibilityDetectorController.instance.notifyNow();
      suivi.suivre(_repere(curseur: _a(5)));
      expect(suivi.separateurRetire, isFalse);

      defilement.jumpTo(20 * 80);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(suivi.separateurRetire, isTrue);
      await demonter(tester);
    });
  });
}
