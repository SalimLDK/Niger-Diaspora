import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/core/utils/lecture_sans_chevauchement.dart';

/// La liste des discussions relisait tout à chaque événement temps réel, en
/// parallèle : une réponse ancienne revenue la dernière figeait l'écran sur
/// un état périmé. Ces tests fixent les deux garanties qui l'empêchent.
void main() {
  test('jamais deux passes à la fois', () async {
    var enVol = 0;
    var maxEnVol = 0;
    final portes = <Completer<void>>[];
    final lecture = LectureSansChevauchement(() async {
      enVol++;
      if (enVol > maxEnVol) maxEnVol = enVol;
      final porte = Completer<void>();
      portes.add(porte);
      await porte.future;
      enVol--;
    });

    final premiere = lecture.lire();
    unawaited(lecture.lire());
    unawaited(lecture.lire());
    await Future<void>.delayed(Duration.zero);
    expect(portes, hasLength(1), reason: 'la 2e attend la fin de la 1re');

    portes[0].complete();
    await Future<void>.delayed(Duration.zero);
    expect(portes, hasLength(2),
        reason: 'les appels tombés pendant la passe en redemandent UNE');
    portes[1].complete();
    await premiere;

    expect(maxEnVol, 1);
    expect(portes, hasLength(2));
  });

  test('un changement signalé pendant une passe est relu après elle',
      () async {
    // Ce que la version parallèle perdait : la réponse de la passe lancée
    // AVANT le changement était la dernière à revenir.
    var version = 0;
    var vu = -1;
    final porte = Completer<void>();
    var premiere = true;
    final lecture = LectureSansChevauchement(() async {
      final lue = version;
      if (premiere) {
        premiere = false;
        await porte.future;
      }
      vu = lue;
    });

    final passe = lecture.lire();
    await Future<void>.delayed(Duration.zero);
    version = 1;
    unawaited(lecture.lire());
    porte.complete();
    await passe;

    expect(vu, 1);
  });

  test('planifier regroupe une rafale en une lecture', () async {
    var lectures = 0;
    final lecture = LectureSansChevauchement(
      () async => lectures++,
      regroupement: const Duration(milliseconds: 20),
    );

    for (var i = 0; i < 5; i++) {
      lecture.planifier();
    }
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(lectures, 1);
  });

  test('fermer annule une lecture planifiée', () async {
    var lectures = 0;
    final lecture = LectureSansChevauchement(
      () async => lectures++,
      regroupement: const Duration(milliseconds: 20),
    );

    lecture.planifier();
    lecture.fermer();
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(lectures, 0);
  });
}
