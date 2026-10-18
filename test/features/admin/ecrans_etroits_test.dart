import 'package:diaspo_niger/features/admin/data/datasources/reglages_historique_datasource.dart';
import 'package:diaspo_niger/features/admin/presentation/providers/a_traiter_provider.dart';
import 'package:diaspo_niger/features/admin/presentation/widgets/bloc_a_traiter.dart';
import 'package:diaspo_niger/features/admin/presentation/widgets/historique_reglages.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Spécification d'interfaces § 20-21 : les écrans restent utilisables sur un
/// écran étroit et avec une police agrandie. Un débordement est une exception
/// Flutter : il fait échouer le test.
Future<void> _monter(
  WidgetTester tester,
  Widget enfant, {
  required List<Override> overrides,
  double largeur = 320,
  double echelle = 1.5,
}) async {
  tester.view.physicalSize = Size(largeur, 700);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(echelle)),
          child: child!,
        ),
        home: Scaffold(body: SingleChildScrollView(child: enfant)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

ListeATraiter _liste(List<ElementATraiter> e) => ListeATraiter(DateTime(2026, 10, 19, 9, 5), e);

void main() {
  final elements = [
    ElementATraiter(cle: 'reports', nombre: 12, urgent: 5, leMoinsRecent: DateTime(2026, 10, 1)),
    const ElementATraiter(cle: 'support', nombre: 0),
    ElementATraiter(cle: 'demarches', nombre: 3, urgent: 1, leMoinsRecent: DateTime(2026, 9, 12)),
    const ElementATraiter(cle: 'privacy', nombre: 2, urgent: 0),
  ];

  group('Bloc « À traiter »', () {
    for (final largeur in [320.0, 411.0, 1200.0]) {
      testWidgets('rend sans débordement à ${largeur.toInt()} dp, police ×1,5', (tester) async {
        await _monter(
          tester,
          BlocATraiter(onOuvrir: (_) {}),
          largeur: largeur,
          overrides: [aTraiterProvider.overrideWith((ref) async => _liste(elements))],
        );

        expect(find.text('Signalements'), findsOneWidget);
        expect(find.textContaining('Calculé à 09:05'), findsOneWidget,
            reason: 'chaque indicateur est daté');
        expect(find.text('Rien en attente'), findsOneWidget,
            reason: 'une file vide se dit, elle ne s\'efface pas');
      });
    }

    testWidgets('une erreur de calcul affiche l\'erreur et un bouton, jamais des zéros', (tester) async {
      await _monter(
        tester,
        BlocATraiter(onOuvrir: (_) {}),
        overrides: [aTraiterProvider.overrideWith((ref) => Future.error(Exception('refus')))],
      );

      expect(find.textContaining('Impossible de calculer'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
      expect(find.text('0'), findsNothing);
    });

    testWidgets('un rôle sans file le dit', (tester) async {
      await _monter(
        tester,
        BlocATraiter(onOuvrir: (_) {}),
        overrides: [aTraiterProvider.overrideWith((ref) async => _liste(const []))],
      );

      expect(find.textContaining('Aucune file à traiter'), findsOneWidget);
    });

    testWidgets('toucher une ligne ouvre sa rubrique', (tester) async {
      String? ouverte;
      await _monter(
        tester,
        BlocATraiter(onOuvrir: (d) => ouverte = d),
        overrides: [aTraiterProvider.overrideWith((ref) async => _liste(elements))],
      );

      await tester.ensureVisible(find.text('Démarches consulaires'));
      await tester.tap(find.text('Démarches consulaires'));
      expect(ouverte, 'demarches');
    });
  });

  group('Historique des réglages', () {
    final entrees = [
      EntreeHistoriqueReglage(
        id: 'e2',
        section: 'fees',
        avant: const {'taux': 2, 'liste': [1, 2]},
        apres: const {'taux': 3, 'liste': [1, 2], 'nouveau': true},
        par: 'super-1',
        date: DateTime(2026, 10, 19, 10, 30),
        nature: 'update',
        motif: 'Passage à 3 %',
      ),
      EntreeHistoriqueReglage(
        id: 'e1',
        section: 'fees',
        apres: const {'taux': 2},
        par: 'super-1',
        date: DateTime(2026, 10, 18, 8, 0),
        nature: 'update',
      ),
    ];

    for (final largeur in [320.0, 600.0]) {
      testWidgets('rend sans débordement à ${largeur.toInt()} dp, police ×1,5', (tester) async {
        await _monter(
          tester,
          const HistoriqueReglagesDialog(),
          largeur: largeur,
          overrides: [reglagesHistoriqueProvider.overrideWith((ref) async => entrees)],
        );

        expect(find.textContaining('taux : 2 → 3'), findsOneWidget);
        expect(find.textContaining('nouveau : (absent) → true'), findsOneWidget);
        expect(find.text('liste'), findsNothing, reason: 'une clé inchangée n\'est pas listée');
        expect(find.text('Restaurer l\'ancienne valeur'), findsOneWidget,
            reason: 'seule l\'entrée qui a un « avant » se restaure');
        expect(find.textContaining('pas d\'ancienne valeur'), findsOneWidget);
      });
    }

    testWidgets('une lecture qui échoue n\'est pas un historique vide', (tester) async {
      await _monter(
        tester,
        const HistoriqueReglagesDialog(),
        overrides: [
          reglagesHistoriqueProvider.overrideWith((ref) => Future.error(Exception('refus'))),
        ],
      );

      expect(find.textContaining('Impossible de lire l\'historique'), findsOneWidget);
      expect(find.textContaining('Aucun changement enregistré'), findsNothing);
    });

    testWidgets('un historique réellement vide le dit', (tester) async {
      await _monter(
        tester,
        const HistoriqueReglagesDialog(),
        overrides: [reglagesHistoriqueProvider.overrideWith((ref) async => const [])],
      );

      expect(find.textContaining('Aucun changement enregistré'), findsOneWidget);
    });
  });
}
