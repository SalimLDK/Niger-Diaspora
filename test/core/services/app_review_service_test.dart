import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:diaspo_niger/core/services/app_review_service.dart';
import 'package:diaspo_niger/core/services/preferences_service.dart';

/// Banc de l'invitation à noter l'app.
///
/// Ce qu'il verrouille tient en une phrase : **une invitation ne doit jamais
/// se répéter à chaque ouverture**. `requestReview()` ne renvoie rien et ne
/// dit pas si le dialogue s'est affiché — un compteur mal tenu redemanderait
/// donc en boucle, et personne ne le verrait dans un journal.
class _FauxAvis implements NativeReviewPrompt {
  _FauxAvis({
    this.disponible = true,
    this.demandeEchoue = false,
    this.ficheEchoue = false,
  });

  final bool disponible;
  final bool demandeEchoue;
  final bool ficheEchoue;

  int demandes = 0;
  int fiches = 0;
  String? dernierAppStoreId;

  @override
  Future<bool> isAvailable() async => disponible;

  @override
  Future<void> requestReview() async {
    demandes++;
    if (demandeEchoue) throw PlatformException(code: 'quota');
  }

  @override
  Future<void> openStoreListing({String? appStoreId}) async {
    fiches++;
    dernierAppStoreId = appStoreId;
    if (ficheEchoue) throw PlatformException(code: 'no-store');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final debut = DateTime(2026, 9, 1, 12);

  /// Un état de préférences qui coche tout sauf ce que le test change.
  Map<String, Object> prefsPretes({
    int ouvertures = AppReviewPolicy.ouverturesMinimum,
    DateTime? premiere,
    DateTime? derniere,
    bool ficheOuverte = false,
  }) => {
    'review_ouvertures': ouvertures,
    'review_premiere_ouverture':
        (premiere ?? debut.subtract(const Duration(days: 30)))
            .toUtc()
            .toIso8601String(),
    if (derniere != null)
      'review_derniere_invitation': derniere.toUtc().toIso8601String(),
    'review_fiche_ouverte': ficheOuverte,
  };

  Future<AppReviewService> service(
    _FauxAvis faux, {
    Map<String, Object>? prefs,
    DateTime? maintenant,
  }) async {
    SharedPreferences.setMockInitialValues(prefs ?? {});
    await PreferencesService.instance.initialize();
    return AppReviewService(faux, horloge: () => maintenant ?? debut);
  }

  group('AppReviewPolicy — quand se taire', () {
    bool inviter({
      int ouvertures = AppReviewPolicy.ouverturesMinimum,
      DateTime? premiere,
      DateTime? derniere,
      bool ficheOuverte = false,
    }) => AppReviewPolicy.doitInviter(
      ouvertures: ouvertures,
      premiereOuverture:
          premiere ?? debut.subtract(const Duration(days: 30)),
      derniereInvitation: derniere,
      ficheDejaOuverte: ficheOuverte,
      maintenant: debut,
    );

    test('le cas nominal invite', () {
      expect(inviter(), isTrue);
    });

    test('pas avant huit ouvertures', () {
      expect(inviter(ouvertures: AppReviewPolicy.ouverturesMinimum - 1),
          isFalse);
    });

    test("pas avant trois jours d'ancienneté", () {
      expect(
        inviter(premiere: debut.subtract(const Duration(days: 2, hours: 23))),
        isFalse,
      );
    });

    test('pas de première ouverture connue : on se tait', () {
      // Installation antérieure au compteur : inviter reviendrait à demander
      // sur la foi d'un seul signal.
      expect(
        AppReviewPolicy.doitInviter(
          ouvertures: 400,
          premiereOuverture: null,
          derniereInvitation: null,
          ficheDejaOuverte: false,
          maintenant: debut,
        ),
        isFalse,
      );
    });

    test('pas deux fois dans le trimestre', () {
      expect(
        inviter(derniere: debut.subtract(const Duration(days: 119))),
        isFalse,
      );
      expect(
        inviter(derniere: debut.subtract(const Duration(days: 121))),
        isTrue,
      );
    });

    test('la personne est déjà allée sur la fiche : plus jamais', () {
      expect(inviter(ficheOuverte: true), isFalse);
    });
  });

  group('enregistrerOuverture', () {
    test('la première ouverture est datée une fois, puis on compte', () async {
      final faux = _FauxAvis();
      final s = await service(faux);

      await s.enregistrerOuverture();
      final premiere = PreferencesService.instance.reviewPremiereOuverture;
      expect(premiere, isNotNull);
      expect(PreferencesService.instance.reviewOuvertures, 1);

      await s.enregistrerOuverture();
      expect(PreferencesService.instance.reviewOuvertures, 2);
      expect(PreferencesService.instance.reviewPremiereOuverture, premiere);
    });

    test('une horloge avancée puis remise à l\'heure ne bloque pas', () async {
      // Le téléphone a cru être en 2030 : les deux repères sont dans le
      // futur. Sans recalage, `maintenant.difference(...)` reste négatif et
      // l'invitation ne repart jamais — sans rien dans aucun journal.
      final futur = DateTime(2030).toUtc().toIso8601String();
      final faux = _FauxAvis();
      final s = await service(
        faux,
        prefs: {
          'review_ouvertures': 40,
          'review_premiere_ouverture': futur,
          'review_derniere_invitation': futur,
        },
      );

      await s.enregistrerOuverture();

      final p = PreferencesService.instance;
      expect(p.reviewPremiereOuverture!.isAfter(debut), isFalse);
      expect(p.reviewDerniereInvitation!.isAfter(debut), isFalse);
    });
  });

  group('inviterSiLeMomentSyPrete', () {
    test('demande une fois, puis se tait le trimestre suivant', () async {
      final faux = _FauxAvis();
      final s = await service(faux, prefs: prefsPretes());

      expect(await s.inviterSiLeMomentSyPrete(), isTrue);
      expect(faux.demandes, 1);

      // Même instant, même app relancée : plus rien.
      expect(await s.inviterSiLeMomentSyPrete(), isFalse);
      expect(faux.demandes, 1);
    });

    test('un dialogue avalé en silence ne redemande pas à chaque fois',
        () async {
      // `requestReview()` qui échoue est indiscernable d'un quota atteint.
      // L'horodatage doit avoir été posé AVANT l'appel, sinon la tentative
      // repart au démarrage suivant, et au suivant.
      final faux = _FauxAvis(demandeEchoue: true);
      final s = await service(faux, prefs: prefsPretes());

      expect(await s.inviterSiLeMomentSyPrete(), isFalse);
      expect(PreferencesService.instance.reviewDerniereInvitation, isNotNull);
      expect(s.momentOpportun(), isFalse);
    });

    test('sans Play Store, rien n\'est demandé et rien n\'est consommé',
        () async {
      final faux = _FauxAvis(disponible: false);
      final s = await service(faux, prefs: prefsPretes());

      expect(await s.inviterSiLeMomentSyPrete(), isFalse);
      expect(faux.demandes, 0);
      // Le quota n'a pas été entamé : le moment reste opportun pour le jour
      // où le Play Store sera là.
      expect(PreferencesService.instance.reviewDerniereInvitation, isNull);
      expect(s.momentOpportun(), isTrue);
    });

    test('le chemin automatique n\'ouvre jamais la fiche du store', () async {
      final faux = _FauxAvis(disponible: false);
      final s = await service(faux, prefs: prefsPretes());

      await s.inviterSiLeMomentSyPrete();
      expect(faux.fiches, 0);
    });
  });

  group('ouvrirLaFicheDuStore', () {
    test('ouvre la fiche et coupe l\'invitation automatique', () async {
      final faux = _FauxAvis();
      final s = await service(faux, prefs: prefsPretes());

      expect(await s.ouvrirLaFicheDuStore(), isTrue);
      expect(faux.fiches, 1);
      expect(faux.dernierAppStoreId, AppReviewService.appStoreId);
      expect(PreferencesService.instance.reviewFicheOuverte, isTrue);
      expect(s.momentOpportun(), isFalse);
    });

    test('jamais le dialogue natif : un bouton mort serait pire', () async {
      final faux = _FauxAvis();
      final s = await service(faux, prefs: prefsPretes());

      await s.ouvrirLaFicheDuStore();
      expect(faux.demandes, 0);
    });

    test('un échec d\'ouverture ne se fait pas passer pour un avis déposé',
        () async {
      // Ni le plugin ni `url_launcher` ne répondent (pas de canal en test) :
      // le bouton doit dire non, et l'invitation automatique rester possible.
      final faux = _FauxAvis(ficheEchoue: true);
      final s = await service(faux, prefs: prefsPretes());

      expect(await s.ouvrirLaFicheDuStore(), isFalse);
      expect(PreferencesService.instance.reviewFicheOuverte, isFalse);
      expect(s.momentOpportun(), isTrue);
    });
  });
}
