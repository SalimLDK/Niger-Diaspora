import 'package:diaspo_niger/core/theme/app_theme.dart';
import 'package:diaspo_niger/features/admin/presentation/providers/dossier_moderation_provider.dart'
    show adminAPermissionProvider;
import 'package:diaspo_niger/features/admin/presentation/providers/evenements_admin_provider.dart';
import 'package:diaspo_niger/features/admin/presentation/providers/recherche_admin_provider.dart';
import 'package:diaspo_niger/features/admin/presentation/providers/sources_consulaires_provider.dart';
import 'package:diaspo_niger/features/admin/presentation/providers/support_admin_provider.dart';
import 'package:diaspo_niger/features/admin/presentation/screens/admin_recherche_screen.dart';
import 'package:diaspo_niger/features/admin/presentation/screens/admin_sources_consulaires_screen.dart';
import 'package:diaspo_niger/features/admin/presentation/widgets/evenements_validation.dart';
import 'package:diaspo_niger/features/admin/presentation/widgets/reglages_support_dialog.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Les écrans d'administration ajoutés ici tiennent sur un téléphone étroit
/// (360 dp) avec une police agrandie : aucun débordement, aucune exception.
///
/// Les données sont posées à la main (surcharges de providers) : le test ne
/// parle pas à Supabase. La police de test rend chaque glyphe carré, donc les
/// largeurs sont plus grandes qu'à l'écran — un test qui passe ici passe sur
/// l'appareil.
void main() {
  Widget boot(Widget home, List<Override> overrides) => ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('fr'),
          home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: home)),
        ),
      );

  void telephone(WidgetTester tester, double echelle) {
    tester.view.physicalSize = const Size(1080, 2220); // 360 x 740 dp à 3x
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = echelle;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  final permissionsOui = [
    adminAPermissionProvider.overrideWith((ref, cle) async => true),
    permissionEvenementsProvider.overrideWith((ref, cle) async => true),
    permissionSupportProvider.overrideWith((ref, cle) async => true),
  ];

  for (final echelle in [1.0, 1.5]) {
    testWidgets('À traiter et recherche, 360 dp, échelle $echelle', (tester) async {
      telephone(tester, echelle);
      await tester.pumpWidget(boot(
        AdminRechercheScreen(onOuvrir: (_) {}),
        [
          fileATraiterProvider.overrideWith((ref) async => [
                LigneATraiter('reports', 12, 3, DateTime(2026, 9, 1)),
                LigneATraiter('tickets_overdue', 4, 4, null),
                LigneATraiter('businesses_review', 1, 1, DateTime(2026, 1, 1)),
              ]),
          rechercheGlobaleProvider.overrideWith((ref) async => null),
        ],
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Signalements en attente'), findsOneWidget);

      await tester.tap(find.text('Recherche'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Sources consulaires, 360 dp, échelle $echelle', (tester) async {
      telephone(tester, echelle);
      await tester.pumpWidget(boot(
        AdminSourcesConsulairesScreen(onOuvrir: (_) {}),
        [
          ...permissionsOui,
          sourcesConsulairesProvider.overrideWith((ref) async => SourcesConsulaires(
                [
                  SourceDemarche(
                    id: 'd1',
                    titre: 'Renouvellement de passeport biométrique pour un mineur né à l\'étranger',
                    publiee: true,
                    sourceUrl: 'https://exemple.test/une/adresse/tres/longue/vers/la/source/officielle',
                    editeur: 'Ministère des Affaires étrangères',
                    problemes: const [
                      ProblemeSource.jamaisVerifiee,
                      ProblemeSource.revisionDepassee,
                      ProblemeSource.sansRevisionPrevue,
                    ],
                    revisionLe: DateTime(2026, 5, 1),
                  ),
                ],
                [
                  const SourceAmbassade(
                    id: 'a1',
                    nom: 'Ambassade de la République du Niger auprès du Royaume',
                    ville: 'Ville à nom très long',
                    problemes: [ProblemeSource.sansSource, ProblemeSource.jamaisVerifiee],
                  ),
                ],
                20,
                32,
              )),
        ],
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Validation des événements, 360 dp, échelle $echelle', (tester) async {
      telephone(tester, echelle);
      await tester.pumpWidget(boot(
        const OngletValidationEvenements(),
        [
          ...permissionsOui,
          validationExigeeProvider.overrideWith((ref) async => true),
          evenementsEnAttenteProvider.overrideWith((ref) async => [
                EvenementEnAttente(
                  'e1',
                  'Grande rencontre annuelle de la diaspora nigérienne en Île-de-France',
                  DateTime(2026, 12, 5),
                  'Villeneuve-Saint-Georges',
                  'Association des Nigériens de France',
                  DateTime(2026, 10, 1),
                ),
              ]),
        ],
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Réglages du support, 360 dp, échelle $echelle', (tester) async {
      telephone(tester, echelle);
      await tester.pumpWidget(boot(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => ReglagesSupportDialog(
                libelleCategorie: (l, c) => c,
                libellePriorite: (l, p) => p,
              ),
            ),
            child: const Text('ouvrir'),
          ),
        ),
        [
          ...permissionsOui,
          modelesReponseProvider.overrideWith((ref) async => [
                const ModeleReponse('m1', 'Accusé de réception d\'une demande de remboursement', 'texte', 'transaction'),
              ]),
          delaisCiblesProvider.overrideWith((ref) async => [
                const DelaiCible('transaction', 'urgent', 4, 48),
              ]),
        ],
      ));
      await tester.tap(find.text('ouvrir'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
