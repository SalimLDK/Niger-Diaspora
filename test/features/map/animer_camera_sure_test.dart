import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:diaspo_niger/features/map/presentation/screens/map_screen.dart';

/// Crashlytics 1.2.2 (31) : « GoogleMapController for map ID 0 was used after
/// the associated GoogleMap widget had already been disposed » — un résultat
/// de recherche arrivait après la sortie de la carte.
class _FauxControleur implements GoogleMapController {
  _FauxControleur({this.detruit = false});

  final bool detruit;
  int animations = 0;

  @override
  Future<void> animateCamera(
    CameraUpdate cameraUpdate, {
    Duration? duration,
  }) async {
    if (detruit) {
      throw StateError('GoogleMapController was used after dispose');
    }
    animations++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  final maj = CameraUpdate.zoomTo(10);

  test('écran monté, contrôleur vivant : la caméra bouge', () async {
    final c = _FauxControleur();
    expect(await animerCameraSure(Future.value(c), () => true, maj), isTrue);
    expect(c.animations, 1);
  });

  test("écran déjà détruit : le contrôleur n'est pas touché", () async {
    final c = _FauxControleur();
    expect(await animerCameraSure(Future.value(c), () => false, maj), isFalse);
    expect(c.animations, 0);
  });

  test("écran quitté pendant l'attente du contrôleur : pas d'animation",
      () async {
    final attente = Completer<GoogleMapController>();
    var monte = true;
    final c = _FauxControleur();

    final resultat = animerCameraSure(attente.future, () => monte, maj);
    monte = false;
    attente.complete(c);

    expect(await resultat, isFalse);
    expect(c.animations, 0);
  });

  test("contrôleur détruit entre-temps : l'erreur est avalée", () async {
    final c = _FauxControleur(detruit: true);
    expect(await animerCameraSure(Future.value(c), () => true, maj), isFalse);
  });
}
