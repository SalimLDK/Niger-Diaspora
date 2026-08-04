import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/core/theme/app_theme.dart';
import 'package:diaspo_niger/features/auth/presentation/providers/auth_provider.dart';
import 'package:diaspo_niger/features/businesses/presentation/screens/create_business_screen.dart';
import 'package:diaspo_niger/features/embassies/domain/entities/embassy_entity.dart';
import 'package:diaspo_niger/features/embassies/presentation/screens/administrative_request_screen.dart';
import 'package:diaspo_niger/features/marketplace/presentation/screens/create_product_screen.dart';
import 'package:diaspo_niger/features/podcasts/presentation/screens/create_podcast_screen.dart';
import 'package:diaspo_niger/features/transfers/presentation/screens/add_recipient_screen.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

/// Largeur des `DropdownButtonFormField` du projet.
///
/// Même cause que le champ « Type * » de la création d'ambassade : le
/// `DropdownButton` empile **tous** ses éléments dans un `IndexedStack`, qui se
/// dimensionne sur son plus **grand** enfant et non sur celui qui est affiché.
/// Sans `isExpanded`, cette pile n'est pas placée dans un `Expanded` dans la
/// `Row` interne — donc le libellé le plus long de la liste, même jamais
/// affiché, impose sa largeur au champ replié.
///
/// La police de test rend chaque glyphe carré (1 em), donc les largeurs sont
/// nettement plus grandes qu'à l'écran : ces cas échouent tous **avant** le
/// correctif, y compris ceux qui tiendraient de justesse sur un vrai appareil.
const _fixture = EmbassyEntity(
  id: 'amb-test',
  name: 'Ambassade du Niger en France',
  country: 'France',
  city: 'Paris',
  address: '154 rue de Longchamp, 75116 Paris',
  type: 'embassy',
);

void main() {
  final ecrans = <String, Widget Function()>{
    'Ajouter un bénéficiaire (transferts)': () => const AddRecipientScreen(),
    'Demande administrative (ambassades)': () =>
        const AdministrativeRequestScreen(embassy: _fixture),
    'Créer un produit (boutique)': () => const CreateProductScreen(),
    'Créer une entreprise': () => const CreateBusinessScreen(),
    'Créer un podcast': () => const CreatePodcastScreen(),
  };

  // Nombre de menus effectivement atteignables sans interaction : ce que le
  // cas doit avoir disposé pour valoir quelque chose. Les menus « banque » et
  // « ville » des transferts n'y sont pas — ils n'apparaissent qu'après avoir
  // choisi le type « compte bancaire », donc ce test ne les couvre pas.
  const menusAttendus = <String, int>{
    'Ajouter un bénéficiaire (transferts)': 1,
    'Demande administrative (ambassades)': 1,
    'Créer un produit (boutique)': 1,
    'Créer une entreprise': 1,
    'Créer un podcast': 1,
  };

  for (final entree in ecrans.entries) {
    for (final echelle in [1.0, 1.1]) {
      testWidgets('${entree.key} ne déborde pas (échelle $echelle)',
          (tester) async {
        // Géométrie du SM A515F.
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.75;
        tester.platformDispatcher.textScaleFactorTestValue = echelle;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              // « Demande administrative » pré-remplit le formulaire depuis le
              // profil dès `initState` : sans cette surcharge, le test meurt
              // sur `[core/no-app]` avant même la mise en page. Un utilisateur
              // nul suffit — le pré-remplissage sort tout de suite.
              currentUserAsyncProvider.overrideWith((ref) => Stream.value(null)),
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
              home: entree.value(),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);

        // Un test qui ne rend jamais le menu passerait pour de mauvaises
        // raisons : on compte les `DropdownButtonFormField` réellement
        // disposés au fil du défilement.
        final menus = find.byWidgetPredicate(
          (w) => w.runtimeType.toString().startsWith('DropdownButtonFormField'),
        );
        var vus = menus.evaluate().length;

        // Les formulaires dépassent la hauteur de l'écran : on les fait
        // défiler entièrement pour que chaque champ soit réellement disposé.
        // Les listes paresseuses (ListView) ne construisent que ce qui est à
        // l'écran, d'où le décompte cumulé plutôt qu'un décompte final.
        // Attention : plusieurs de ces écrans commencent par une bande de
        // photos en ListView **horizontale**. La prendre pour cible ferait
        // défiler les photos et jamais le formulaire — les champs du bas ne
        // seraient jamais construits et le cas passerait pour rien.
        final defilables = find.byWidgetPredicate(
          (w) =>
              (w is SingleChildScrollView &&
                  w.scrollDirection == Axis.vertical) ||
              (w is ListView && w.scrollDirection == Axis.vertical),
        );
        if (defilables.evaluate().isNotEmpty) {
          for (var i = 0; i < 12; i++) {
            await tester.drag(defilables.first, const Offset(0, -400));
            await tester.pump();
            expect(tester.takeException(), isNull);
            vus = vus > menus.evaluate().length ? vus : menus.evaluate().length;
          }
        }

        expect(
          vus,
          greaterThanOrEqualTo(menusAttendus[entree.key]!),
          reason:
              'Aucun menu déroulant n\'a été disposé sur « ${entree.key} » : '
              'le cas ne prouverait rien.',
        );
      });
    }
  }
}
