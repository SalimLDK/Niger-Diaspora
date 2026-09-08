import 'package:diaspo_niger/core/services/politique_de_reprise.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le défaut que cette politique doit rendre impossible : sur SM A515F, mode
/// avion, l'app retentait l'échange de session **toutes les ~5 secondes sans
/// jamais abandonner**, et l'écran des ambassades tournait indéfiniment.
void main() {
  /// Horloge que le test avance à la main : sinon il faudrait attendre
  /// vraiment 5 minutes.
  late DateTime maintenant;
  late PolitiqueDeReprise politique;

  setUp(() {
    maintenant = DateTime(2026, 9, 8, 9, 0);
    politique = PolitiqueDeReprise(horloge: () => maintenant);
  });

  void avancer(Duration d) => maintenant = maintenant.add(d);

  test('au repos, une tentative est permise', () {
    expect(politique.peutTenter, isTrue);
  });

  test('le repli croît puis se plafonne à 80 s', () {
    expect(politique.enregistrerEchec(), const Duration(seconds: 5));
    expect(politique.enregistrerEchec(), const Duration(seconds: 10));
    expect(politique.enregistrerEchec(), const Duration(seconds: 20));
    expect(politique.enregistrerEchec(), const Duration(seconds: 40));
    expect(politique.enregistrerEchec(), const Duration(seconds: 80));
  });

  test(
    "un rappel externe pendant la fenêtre de calme ne relance rien "
    "— c'est le défaut d'origine",
    () {
      politique.enregistrerEchec(); // 5 s de calme

      // `authStateChanges` réémet aussitôt : avant, ça repartait pour un tour.
      avancer(const Duration(seconds: 1));
      expect(politique.peutTenter, isFalse);

      avancer(const Duration(seconds: 2));
      expect(politique.peutTenter, isFalse);

      // Passé le délai, une tentative redevient utile.
      avancer(const Duration(seconds: 3));
      expect(politique.peutTenter, isTrue);
    },
  );

  test('on abandonne après 6 échecs, sans minuteur supplémentaire', () {
    for (var i = 0; i < PolitiqueDeReprise.maxTentatives - 1; i++) {
      expect(politique.enregistrerEchec(), isNotNull);
      avancer(const Duration(seconds: 90));
    }
    // Le sixième échec est celui de trop.
    expect(
      politique.enregistrerEchec(),
      isNull,
      reason: 'null = plus aucun minuteur, on cesse de retenter tout seul',
    );
    expect(politique.aAbandonne, isTrue);
  });

  test("après l'abandon, la fenêtre de calme tient les rappels à distance", () {
    // On n'avance PAS l'horloge après le dernier échec : le repos doit être
    // mesuré depuis lui, pas depuis un instant plus tardif.
    for (var i = 0; i < PolitiqueDeReprise.maxTentatives; i++) {
      if (i > 0) avancer(const Duration(seconds: 90));
      politique.enregistrerEchec();
    }
    expect(politique.aAbandonne, isTrue);

    // Sans repos, les rappels de `authStateChanges` repartiraient toutes les
    // 5 s -- exactement ce qui a ete vu sur l'appareil.
    expect(politique.peutTenter, isFalse);

    avancer(const Duration(minutes: 4));
    expect(politique.peutTenter, isFalse);

    avancer(const Duration(minutes: 2));
    expect(
      politique.peutTenter,
      isTrue,
      reason: 'le réseau peut revenir sans que rien ne nous le dise',
    );
  });

  test('le retour du réseau court-circuite le repos', () {
    politique.enregistrerEchec();
    expect(politique.peutTenter, isFalse);

    politique.autoriserUneTentative();
    expect(politique.peutTenter, isTrue);
  });

  test('un succès efface tout', () {
    politique.enregistrerEchec();
    politique.enregistrerEchec();
    expect(politique.echecsConsecutifs, 2);

    politique.enregistrerSucces();

    expect(politique.echecsConsecutifs, 0);
    expect(politique.aAbandonne, isFalse);
    expect(politique.peutTenter, isTrue);
    // Le repli repart du bas, il ne reste pas plafonné.
    expect(politique.enregistrerEchec(), const Duration(seconds: 5));
  });
}
