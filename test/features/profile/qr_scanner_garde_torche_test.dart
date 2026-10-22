import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:diaspo_niger/features/profile/presentation/screens/qr_scanner_screen.dart';

/// Crashlytics 1.2.2 (31) : `MobileScannerException(controllerUninitialized)`
/// — la torche ou le changement de caméra touchés avant `start()` (permission
/// refusée, démarrage en cours) levaient une erreur non gérée.
void main() {
  test('le contrôleur brut lève bien controllerUninitialized (le piège)', () {
    final controller = MobileScannerController(autoStart: false);
    addTearDown(controller.dispose);

    expect(
      controller.toggleTorch(),
      throwsA(
        isA<MobileScannerException>().having(
          (e) => e.errorCode,
          'errorCode',
          MobileScannerErrorCode.controllerUninitialized,
        ),
      ),
    );
  });

  test('la torche, caméra non démarrée : rien ne lève, rien ne bascule',
      () async {
    final controller = MobileScannerController(autoStart: false);
    addTearDown(controller.dispose);

    expect(await basculerTorche(controller), isFalse);
  });

  test('le changement de caméra, caméra non démarrée : rien ne lève',
      () async {
    final controller = MobileScannerController(autoStart: false);
    addTearDown(controller.dispose);

    expect(await changerDeCamera(controller), isFalse);
  });
}
