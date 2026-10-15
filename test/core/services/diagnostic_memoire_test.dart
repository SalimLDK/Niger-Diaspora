import 'package:diaspo_niger/core/services/diagnostic_memoire.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _Faux implements EnregistreurDiagnostic {
  final Map<String, Object> cles = {};
  final List<String> journal = [];
  bool leve = false;

  @override
  Future<void> poserCle(String cle, Object valeur) async {
    if (leve) throw StateError('Firebase pas initialisé');
    cles[cle] = valeur;
  }

  @override
  Future<void> journaliser(String message) async {
    if (leve) throw StateError('Firebase pas initialisé');
    journal.add(message);
  }
}

void main() {
  late _Faux faux;

  setUp(() {
    DiagnosticMemoire.reinitialiser();
    faux = _Faux();
    DiagnosticMemoire.enregistreur = faux;
    DiagnosticMemoire.lecteurRssMio = () => 321;
    DiagnosticMemoire.lecteurMemoireJava = () async => {
          'tasMaxMio': 256,
          'tasAlloueMio': 200,
          'tasLibreMio': 50,
          'classeMemoireMio': 192,
          'largeClasseMemoireMio': 512,
          'appareilPeuDeRam': false,
        };
  });

  test("ouvrir un isolat pose l'isolat, la mémoire Java et le journal", () async {
    await DiagnosticMemoire.ouvrirIsolat(
      Isolat.fcmArrierePlan,
      serviceLocalisationActif: true,
      auPremierPlan: false,
    );

    expect(faux.cles['isolat'], 'fcm_arriere_plan');
    expect(faux.cles['service_localisation_actif'], true);
    expect(faux.cles['appli_au_premier_plan'], false);
    expect(faux.cles['tas_max_mio'], 256);
    expect(faux.cles['tas_alloue_mio'], 200);
    expect(faux.cles['tas_libre_mio'], 50);
    // 256 - (200 - 50) : ce que le processus peut encore prendre avant l'OOM.
    expect(faux.cles['tas_restant_mio'], 106);
    expect(faux.cles['classe_memoire_mio'], 192);
    expect(faux.cles['grande_classe_memoire_mio'], 512);
    expect(faux.cles['appareil_peu_de_ram'], false);
    expect(faux.cles['rss_mio'], 321);
    expect(faux.journal, ['isolat ouvert : fcm_arriere_plan']);
  });

  test('le changement de premier plan repose les clés sans les oublier', () async {
    await DiagnosticMemoire.ouvrirIsolat(Isolat.principal);
    await DiagnosticMemoire.premierPlanChange(true);
    await DiagnosticMemoire.serviceLocalisationChange(false);

    expect(faux.cles['isolat'], 'principal');
    expect(faux.cles['appli_au_premier_plan'], true);
    expect(faux.cles['service_localisation_actif'], false);
  });

  test("sans plugin natif (iOS), les clés d'isolat sont posées quand même", () async {
    DiagnosticMemoire.lecteurMemoireJava =
        () async => throw MissingPluginException();

    await DiagnosticMemoire.ouvrirIsolat(Isolat.serviceLocalisation);

    expect(faux.cles['isolat'], 'service_localisation');
    expect(faux.cles.containsKey('tas_max_mio'), isFalse);
  });

  test('ne lève jamais, même si Crashlytics lève (Firebase pas prêt)', () async {
    faux.leve = true;
    DiagnosticMemoire.lecteurRssMio = () => throw UnsupportedError('web');

    await DiagnosticMemoire.ouvrirIsolat(Isolat.reponseRapide);
    await DiagnosticMemoire.journaliser('x');
    await DiagnosticMemoire.poser();
  });

  testWidgets("l'observateur de cycle de vie repose l'état et journalise", (
    tester,
  ) async {
    await DiagnosticMemoire.ouvrirIsolat(Isolat.principal);
    final observateur = ObservateurDiagnosticMemoire();

    observateur.didChangeAppLifecycleState(AppLifecycleState.paused);
    await tester.pump();
    expect(faux.cles['appli_au_premier_plan'], false);

    observateur.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump();
    expect(faux.cles['appli_au_premier_plan'], true);
    expect(faux.journal, contains('cycle de vie : arrière-plan'));
    expect(faux.journal, contains('cycle de vie : premier plan'));
  });
}
