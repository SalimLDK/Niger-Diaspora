import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diaspo_niger/core/providers/villes_provider.dart';
import 'package:diaspo_niger/core/services/villes_service.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:diaspo_niger/shared/widgets/ville_search_field.dart';

/// Le champ ville doit tenir deux promesses que le champ de texte nu ne tenait
/// pas, et dont dépendent les groupes de ville :
///
///   1. ce qui est retenu est une LIGNE du référentiel, pas la chaîne saisie ;
///   2. retoucher le texte DÉFAIT ce choix. Sans cette règle, un profil
///      garderait `ville_id` = Montréal avec « Montreu » dans `city`, et
///      entrerait dans le groupe de Montréal sur une faute de frappe.
///
/// La recherche est aussi bornée au pays : c'est ce qui empêche « Montréal »
/// de remonter quand le profil dit Niger.
class _FauxVillesService implements VillesService {
  _FauxVillesService(this.reponses);

  final List<Ville> reponses;
  final List<String?> paysDemandes = [];
  final List<String> textesDemandes = [];

  @override
  Future<List<Ville>> rechercher({
    String? pays,
    String texte = '',
    int limite = 20,
  }) async {
    paysDemandes.add(pays);
    textesDemandes.add(texte);
    return reponses;
  }

  @override
  Future<Ville?> laPlusProche({
    required double latitude,
    required double longitude,
    double rayonKm = 50,
  }) async =>
      reponses.isEmpty ? null : reponses.first;
}

const _montreal = Ville(
  id: 7,
  nom: 'Montréal',
  pays: 'Canada',
  region: 'Québec',
  latitude: 45.5088,
  longitude: -73.5878,
  population: 1704694,
);

void main() {
  late _FauxVillesService service;
  Ville? retenue;
  late TextEditingController controller;

  setUp(() {
    service = _FauxVillesService([_montreal]);
    retenue = null;
    controller = TextEditingController();
  });

  tearDown(() => controller.dispose());

  Widget banc({String? pays = 'Canada'}) {
    return ProviderScope(
      overrides: [villesServiceProvider.overrideWithValue(service)],
      child: MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => VilleSearchField(
              controller: controller,
              pays: pays,
              villeChoisieId: retenue?.id,
              onVilleChoisie: (v) => setState(() => retenue = v),
            ),
          ),
        ),
      ),
    );
  }

  /// La recherche attend 250 ms après la dernière frappe.
  ///
  /// La première pompe est indispensable et n'est pas une précaution : `pump`
  /// avec une durée AVANCE L'HORLOGE PUIS reconstruit. Sans elle, le provider
  /// de « mont » n'existe qu'une fois les 300 ms écoulées, son minuteur part
  /// à ce moment-là, et la pompe suivante — qui n'avance pas le temps — ne le
  /// voit jamais échoir : la liste reste vide et le service n'est pas appelé.
  Future<void> laisserChercher(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(attenteAvantRecherche + const Duration(milliseconds: 50));
    await tester.pump();
  }

  testWidgets('une frappe propose les villes du pays, pas du monde',
      (tester) async {
    await tester.pumpWidget(banc());
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'mont');
    await laisserChercher(tester);

    expect(find.text('Montréal, Québec'), findsOneWidget);
    expect(service.paysDemandes, contains('Canada'));
    expect(service.textesDemandes.last, 'mont');
  });

  testWidgets('choisir une ville retient la ligne, pas le texte saisi',
      (tester) async {
    await tester.pumpWidget(banc());
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'mont');
    await laisserChercher(tester);

    await tester.tap(find.text('Montréal, Québec'));
    await tester.pumpAndSettle();

    expect(retenue, _montreal);
    expect(retenue!.id, 7);
    expect(controller.text, 'Montréal');
  });

  testWidgets('retoucher le texte défait le choix', (tester) async {
    await tester.pumpWidget(banc());
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'mont');
    await laisserChercher(tester);
    await tester.tap(find.text('Montréal, Québec'));
    await tester.pumpAndSettle();
    expect(retenue, isNotNull);

    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Montreu');
    // Le choix tombe dès la frappe ; on laisse tout de même la recherche
    // s'écouler, sinon son minuteur survit à l'arbre et le banc s'en plaint.
    await laisserChercher(tester);

    expect(retenue, isNull,
        reason: 'un texte modifié ne désigne plus la ville retenue');
  });

  testWidgets('une recherche en échec ne fait pas tomber le champ',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          villesServiceProvider.overrideWithValue(_ServiceEnPanne()),
        ],
        child: MaterialApp(
          locale: const Locale('fr'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: VilleSearchField(
              controller: controller,
              onVilleChoisie: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'mont');
    await laisserChercher(tester);

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Recherche impossible'), findsOneWidget);
  });
}

class _ServiceEnPanne implements VillesService {
  @override
  Future<List<Ville>> rechercher({
    String? pays,
    String texte = '',
    int limite = 20,
  }) async =>
      throw Exception('hors ligne');

  @override
  Future<Ville?> laPlusProche({
    required double latitude,
    required double longitude,
    double rayonKm = 50,
  }) async =>
      throw Exception('hors ligne');
}
