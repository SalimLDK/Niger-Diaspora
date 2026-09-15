import 'dart:typed_data';

import 'package:diaspo_niger/core/crypto/mls/mls_code_qr.dart';
import 'package:diaspo_niger/core/crypto/mls/mls_code_securite.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ce que ce test protège
/// ----------------------
/// Le 2026-09-15, sur un téléphone, le dialogue du code de sécurité s'ouvrait
/// **complètement vide** : ni titre, ni bouton, ni QR. Rien dans `logcat`, pas
/// d'écran rouge — ce dépôt détourne `FlutterError.onError` vers Crashlytics,
/// donc l'erreur de mise en page ne sortait nulle part. Il a fallu
/// `flutter attach` pour lire la vraie cause :
///
///     LayoutBuilder does not support returning intrinsic dimensions.
///
/// `AlertDialog` mesure son contenu par dimensions intrinsèques ;
/// `QrImageView` contient un `LayoutBuilder`, qui ne sait pas y répondre. La
/// mise en page du dialogue échouait donc en entier.
///
/// Le test reproduit exactement ce cadre — un `AlertDialog` avec un titre, des
/// actions et le QR dans son contenu — parce que c'est **le dialogue** qui
/// pose la question intrinsèque, pas le QR tout seul. Rendre le widget hors
/// dialogue passerait sans rien prouver.

Uint8List _empreinte() => MlsCodeSecurite.empreinteAppareil(
      mlsIdentity: 'u1:abc:def',
      signatureKey: Uint8List.fromList(List.generate(32, (i) => i)),
    );

void main() {
  testWidgets('le QR se met en page DANS un AlertDialog', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Code de sécurité'),
                content: SizedBox(
                  width: 252,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MlsCodeQr(
                        mlsIdentity: 'u1:abc:def',
                        empreinte: _empreinte(),
                      ),
                      const SizedBox(height: 12),
                      const Text('Faites scanner ce code.'),
                    ],
                  ),
                ),
                actions: const [Text('Fermer')],
              ),
            ),
            child: const Text('ouvrir'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();

    // Le symptôme exact du défaut : le dialogue existe, mais rien dedans
    // n'arrive à se peindre.
    expect(tester.takeException(), isNull,
        reason: 'la mise en page du dialogue a échoué');
    expect(find.text('Code de sécurité'), findsOneWidget);
    expect(find.text('Fermer'), findsOneWidget);
    expect(find.byType(MlsCodeQr), findsOneWidget);

    final taille = tester.getSize(find.byType(MlsCodeQr));
    expect(taille.width, 244);
    expect(taille.height, 244);
  });

  testWidgets('la charge encodée est bien celle du code affiché',
      (tester) async {
    // Le QR et les soixante chiffres doivent désigner la même empreinte :
    // deux personnes qui comparent, l'une à l'œil et l'autre en scannant,
    // doivent aboutir au même verdict.
    final empreinte = _empreinte();
    final charge = MlsCodeSecurite.chargeQr(
      mlsIdentity: 'u1:abc:def',
      empreinte: empreinte,
    );
    final lu = MlsCodeSecurite.lireQr(charge);

    expect(lu, isNotNull);
    expect(lu!.empreinte, empreinte);
    expect(MlsCodeSecurite.formater(lu.empreinte),
        MlsCodeSecurite.formater(empreinte));
  });
}
