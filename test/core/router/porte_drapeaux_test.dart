import 'dart:io';

import 'package:diaspo_niger/core/router/porte_drapeaux.dart';
import 'package:diaspo_niger/core/services/feature_flag_service.dart';
import 'package:diaspo_niger/features/admin/domain/entities/app_settings_entity.dart';
import 'package:flutter_test/flutter_test.dart';

/// La porte des routes sous drapeau (transferts, marketplace, podcasts,
/// salons audio).
///
/// Elle a eu tort dans les deux sens, à deux dates :
///
/// - **refuser pendant le chargement** renvoyait les modules actifs sur
///   `/home` à chaque démarrage à froid (défauts de [FeatureFlagsEntity] à
///   `false`) ;
/// - **laisser passer pendant le chargement**, le correctif de ce premier
///   défaut, ouvrait les modules désactivés pendant les premières secondes de
///   chaque lancement — mesuré SM A515F le 2026-09-10.
///
/// Les deux premiers tests de « chargement » tiennent chacun un de ces sens.
void main() {
  const tousFermes = FeatureFlagsEntity();
  const marketplaceOuvert = FeatureFlagsEntity(marketplace: true);
  const sallesOuvertes = FeatureFlagsEntity(audioRooms: true);

  group('décision', () {
    test('une route libre passe, quel que soit l\'état des drapeaux', () {
      for (final enEchec in [false, true]) {
        expect(
          decisionPorte('/groups/abc', drapeaux: null, enEchec: enEchec),
          DecisionPorte.passer,
        );
      }
      expect(
        decisionPorte('/groups/abc', drapeaux: tousFermes, enEchec: false),
        DecisionPorte.passer,
      );
    });

    test('drapeaux chargés : module actif, on passe', () {
      expect(
        decisionPorte(
          '/marketplace/p1',
          drapeaux: marketplaceOuvert,
          enEchec: false,
        ),
        DecisionPorte.passer,
      );
    });

    test('drapeaux chargés : module désactivé, on refuse', () {
      expect(
        decisionPorte('/marketplace/p1', drapeaux: tousFermes, enEchec: false),
        DecisionPorte.refuser,
      );
    });

    test('chargement en cours : on ATTEND — surtout pas refuser', () {
      // Premier défaut : refuser ici renvoyait les salons audio sur /home à
      // chaque démarrage à froid, alors qu'ils étaient actifs.
      expect(
        decisionPorte('/audio-rooms/r1', drapeaux: null, enEchec: false),
        DecisionPorte.attendre,
      );
    });

    test('chargement en cours : on ATTEND — surtout pas passer', () {
      // Second défaut : passer ici ouvrait /podcasts, /marketplace, /transfers
      // pendant les premières secondes, même désactivés.
      expect(
        decisionPorte('/podcasts/x', drapeaux: null, enEchec: false),
        isNot(DecisionPorte.passer),
      );
    });

    test('lecture en échec : on refuse, attendre serait attendre toujours', () {
      expect(
        decisionPorte('/transfers/send', drapeaux: null, enEchec: true),
        DecisionPorte.refuser,
      );
    });

    test('des drapeaux lus l\'emportent sur un échec ou une échéance', () {
      // Une attente échue ne doit pas fermer un module que les drapeaux,
      // arrivés ensuite, déclarent actif.
      expect(
        decisionPorte('/audio-rooms/r1', drapeaux: sallesOuvertes, enEchec: true),
        DecisionPorte.passer,
      );
    });

    test('les préfixes couvrent les sous-routes', () {
      expect(drapeauDe('/podcasts/episodes/e1'), AppFeature.podcasts);
      expect(drapeauDe('/audio-rooms/r1/replay'), AppFeature.audioRooms);
      expect(drapeauDe('/payment-history/t1'), AppFeature.moneyTransfer);
      expect(drapeauDe('/p/u/abc'), isNull);
    });

    test('podcasts : le drapeau serveur ne suffit pas sans ce build', () {
      const podcastsOuverts = FeatureFlagsEntity(podcasts: true);
      expect(
        decisionPorte('/podcasts', drapeaux: podcastsOuverts, enEchec: false),
        kPodcastsSupportesParCeBuild
            ? DecisionPorte.passer
            : DecisionPorte.refuser,
      );
    });
  });

  group('échéance de l\'attente', () {
    testWidgets('elle expire, réveille une fois, et ne se réarme plus', (
      tester,
    ) async {
      var reveils = 0;
      final attente = AttenteDrapeaux(const Duration(seconds: 8));

      attente.armer(() => reveils++);
      await tester.pump(const Duration(seconds: 7));
      expect(attente.echue, isFalse);
      expect(reveils, 0);

      await tester.pump(const Duration(seconds: 2));
      expect(attente.echue, isTrue);
      expect(reveils, 1);

      // Réarmer après échéance ne relance rien : sans ça, chaque route sous
      // drapeau reparquerait l'utilisateur 8 s sur le splash.
      attente.armer(() => reveils++);
      await tester.pump(const Duration(seconds: 30));
      expect(reveils, 1);
    });

    testWidgets('désarmée avant l\'échéance, elle ne réveille rien', (
      tester,
    ) async {
      var reveils = 0;
      final attente = AttenteDrapeaux(const Duration(seconds: 8));

      attente.armer(() => reveils++);
      await tester.pump(const Duration(seconds: 3));
      attente.desarmer();
      await tester.pump(const Duration(seconds: 30));

      expect(reveils, 0);
      expect(attente.echue, isFalse);
    });

    testWidgets('armée deux fois, un seul minuteur', (tester) async {
      var reveils = 0;
      final attente = AttenteDrapeaux(const Duration(seconds: 8));

      attente.armer(() => reveils++);
      await tester.pump(const Duration(seconds: 4));
      attente.armer(() => reveils++);
      await tester.pump(const Duration(seconds: 5));

      // Échéance comptée depuis le premier armement, et un seul réveil.
      expect(reveils, 1);
    });
  });

  test('routeur et scanner QR décident par la porte, pas chacun de son côté', () {
    // L'ancienne forme, `if (flags != null)`, laissait passer pendant le
    // chargement. Elle vivait en deux exemplaires ; qu'aucun ne revienne.
    final routeur = File('lib/core/router/app_router.dart').readAsStringSync();
    expect(routeur, contains('decisionPorte('));
    expect(
      routeur.contains('if (flags != null)'),
      isFalse,
      reason: 'le routeur a retrouvé l\'ancienne porte à deux issues',
    );

    final scanner = File(
      'lib/features/profile/presentation/screens/qr_scanner_screen.dart',
    ).readAsStringSync();
    expect(
      scanner.contains('flags != null &&'),
      isFalse,
      reason: 'le scanner QR a retrouvé l\'ancienne porte à deux issues',
    );
  });
}
