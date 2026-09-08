import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/core/theme/app_theme.dart';
import 'package:diaspo_niger/features/auth/presentation/providers/auth_provider.dart';
import 'package:diaspo_niger/features/embassies/domain/entities/embassy_entity.dart';
import 'package:diaspo_niger/features/embassies/presentation/providers/embassies_provider.dart';
import 'package:diaspo_niger/features/embassies/presentation/screens/embassies_screen.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

/// L'annuaire, clavier ouvert, sur un écran court (paysage).
///
/// Reproduit « BOTTOM OVERFLOWED BY 69 PIXELS » constaté le 2026-09-08 sur
/// Pixel 10 Pro XL en paysage, juste sous le champ de recherche.
///
/// Les métriques sont celles de l'appareil, relevées à l'adb — pas des rondeurs
/// choisies pour faire passer le test :
///
/// * `wm size` → 1080 × 2404 px, donc 2404 × 1080 en paysage ;
/// * `wm density` → **440** en surcharge (et non les 390 physiques), donc
///   `devicePixelRatio` = 2.75 et une hauteur utile de seulement 392 dp ;
/// * `settings get system font_scale` → **1.3** ;
/// * le clavier Gboard occupe 732 px (266 dp), mesurés sur la capture.
///
/// Ce qui reste au `body` une fois la barre d'état, l'`AppBar` et le clavier
/// retirés : **42 dp**. Le champ de recherche seul en fait 60, la ligne de
/// comptage 50 — d'où le débordement. Avant correctif, ce test mesurait
/// **67 px** à l'échelle 1.3 (69 sur l'appareil) et 54 à l'échelle 1.0.
///
/// Le débordement n'a rien de la famille « panneau ancré » de
/// `message_input.dart` : aucun inset périmé, aucune animation. Le contenu fixe
/// posé au-dessus de l'`Expanded` est simplement plus haut que le `body`, donc
/// l'`Expanded` tombe à 0 et la `Column` déborde du reste. Il n'y a rien à lire
/// dans `View.of(context)` : le correctif est de rendre le contenu défilant.
///
/// ⚠ `tester.view.viewInsets`, surtout pas la `MediaQuery` : `MaterialApp` et
/// `Scaffold` la réécrivent, et le `body` d'un `Scaffold` voit toujours un
/// `viewInsets.bottom` à 0 (le Scaffold l'a déjà consommé pour rétrécir).
void main() {
  const embassies = [
    EmbassyEntity(
      id: 'amb-us',
      name: 'Ambassade du Niger aux États-Unis',
      country: 'États-Unis',
      city: 'Washington DC',
      address: '2204 R Street NW',
      latitude: 38.9,
      longitude: -77.05,
    ),
    EmbassyEntity(
      id: 'amb-fr',
      name: 'Ambassade du Niger en France',
      country: 'France',
      city: 'Paris',
      address: '154 rue de Longchamp',
      latitude: 48.86,
      longitude: 2.29,
    ),
  ];

  Widget boot() => ProviderScope(
        overrides: [
          // L'écran ne doit dépendre d'aucun réseau ici : sans surcharge,
          // `embassiesList` construit un vrai dépôt Supabase.
          embassiesListProvider.overrideWith((ref) async => embassies),
          // Pas de session : `_myLatLng()` rend (null, null), donc la carte
          // « le plus proche » est masquée. C'est **le cas rapporté** — celui
          // qui déborde de 69 px. Carte affichée, l'appareil monte à 188.
          currentUserProvider.overrideWith((ref) => Stream.value(null)),
        ],
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
          home: const EmbassiesScreen(),
        ),
      );

  /// On ne retient que les débordements **verticaux**.
  ///
  /// La police de test rend chaque glyphe carré (1 em), donc bien plus large
  /// qu'à l'écran : les libellés longs (« 32 ambassade(s) trouvée(s) », les noms
  /// d'ambassades) débordent horizontalement au banc sans rien signifier pour
  /// l'appareil. Filtrer sur « on the bottom » garde le test sensible à ce qu'il
  /// mesure et insensible à cet artefact.
  List<String> bas(List<FlutterErrorDetails> errors) => errors
      .map((d) => d.exception.toString())
      .where((e) => e.contains('overflowed') && e.contains('on the bottom'))
      .toList();

  /// Joue le scénario et rend les débordements verticaux avant / après clavier.
  ///
  /// ⚠ Tout est capturé **puis** `FlutterError.onError` est rendu, et seulement
  /// après on affirme. Un `expect()` qui échoue pendant que le gestionnaire est
  /// détourné fait sauter une assertion interne du binding (« A test overrode
  /// FlutterError.onError… ») : le vrai motif d'échec disparaît derrière elle,
  /// et le runner met six minutes à s'arrêter — le test paraît figé.
  Future<({List<String> avant, List<String> apres})> jouer(
    WidgetTester tester, {
    required Size taillePhysique,
    required double hautClavier,
    required double echelle,
    required double barreEtat,
  }) async {
    final errors = <FlutterErrorDetails>[];
    final previousOnError = FlutterError.onError;
    FlutterError.onError = errors.add;
    try {
      tester.view.devicePixelRatio = 2.75;
      tester.view.physicalSize = taillePhysique;
      tester.view.padding = FakeViewPadding(top: barreEtat);
      tester.platformDispatcher.textScaleFactorTestValue = echelle;

      await tester.pumpWidget(boot());
      // Pas de `pumpAndSettle` : l'indicateur de chargement tourne sans fin,
      // il ne se stabilise jamais.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final avant = bas(errors);

      tester.view.viewInsets = FakeViewPadding(bottom: hautClavier);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      return (avant: avant, apres: bas(errors));
    } finally {
      FlutterError.onError = previousOnError;
      tester.view.reset();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    }
  }

  for (final scale in [1.0, 1.3]) {
    testWidgets(
      'L\'annuaire ne déborde pas, clavier ouvert en paysage (échelle $scale)',
      (tester) async {
        final r = await jouer(
          tester,
          taillePhysique: const Size(2404, 1080), // Pixel 10 Pro XL, paysage
          hautClavier: 732, // Gboard, mesuré
          echelle: scale,
          barreEtat: 72,
        );

        // Sans clavier, l'écran tient déjà : c'est la borne de référence.
        expect(
          r.avant,
          isEmpty,
          reason: 'paysage sans clavier ne doit rien casser\n${r.avant.join()}',
        );
        expect(
          r.apres,
          isEmpty,
          reason: 'le clavier ne laisse que ~42 dp : le contenu doit défiler, '
              'pas déborder\n${r.apres.join('\n')}',
        );
      },
    );
  }

  testWidgets(
    'L\'état « aucun résultat » ne déborde pas non plus, clavier ouvert',
    (tester) async {
      // C'est le cas le plus exposé : la recherche infructueuse remplace la
      // liste par une icône de 80 px et deux textes, dans un
      // `SliverFillRemaining(hasScrollBody: false)`. En paysage, ce bloc est
      // plus haut que les 42 dp restants — il doit défiler, pas déborder.
      final errors = <FlutterErrorDetails>[];
      final previousOnError = FlutterError.onError;
      FlutterError.onError = errors.add;
      List<String> debordements;
      try {
        tester.view.devicePixelRatio = 2.75;
        tester.view.physicalSize = const Size(2404, 1080);
        tester.view.padding = const FakeViewPadding(top: 72);
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;

        await tester.pumpWidget(boot());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        tester.view.viewInsets = const FakeViewPadding(bottom: 732);
        await tester.enterText(find.byType(TextField), 'zzzzzz');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        debordements = bas(errors);
      } finally {
        FlutterError.onError = previousOnError;
        tester.view.reset();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      }

      expect(debordements, isEmpty, reason: debordements.join('\n'));
    },
  );

  testWidgets(
    'L\'annuaire ne déborde pas non plus en portrait, clavier ouvert',
    (tester) async {
      // En portrait le clavier est plus haut en valeur absolue, mais l'écran
      // est bien plus long : le contenu passe. Ce cas ne débordait pas avant
      // correctif non plus — il est là pour attraper une correction qui
      // casserait le sens de lecture courant.
      final r = await jouer(
        tester,
        taillePhysique: const Size(1080, 2404),
        hautClavier: 1000,
        echelle: 1.3,
        barreEtat: 108,
      );

      expect(r.avant, isEmpty, reason: r.avant.join('\n'));
      expect(r.apres, isEmpty, reason: r.apres.join('\n'));
    },
  );
}
