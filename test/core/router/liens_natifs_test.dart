import 'package:diaspo_niger/core/router/liens_natifs.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Un lien reçu par une activité neuve sur un moteur déjà lancé passe par ce
/// chemin quand le Dart n'écoutait pas encore : si la réclamation échoue, le
/// lien est perdu et l'app s'ouvre sur son dernier écran — le défaut reproduit
/// sur SM A515F le 2026-09-11. Le côté natif ne se teste que sur appareil.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const canal = MethodChannel('test/deep_link');
  final messager =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messager.setMockMethodCallHandler(canal, null));

  test('une route gardée par le natif est rejouée', () async {
    messager.setMockMethodCallHandler(canal, (appel) async {
      expect(appel.method, 'takePendingLink');
      return '/groups/03077217-24d5-4cfa-9ec6-ed5b593c3cd2';
    });
    final vues = <String>[];

    await reprendreLienEnAttente(canal, vues.add);

    expect(vues, ['/groups/03077217-24d5-4cfa-9ec6-ed5b593c3cd2']);
  });

  test('rien en attente : aucune navigation', () async {
    messager.setMockMethodCallHandler(canal, (_) async => null);
    final vues = <String>[];

    await reprendreLienEnAttente(canal, vues.add);

    expect(vues, isEmpty);
  });

  test('pas de natif (iOS, tests) : ni navigation ni exception', () async {
    final vues = <String>[];

    await reprendreLienEnAttente(canal, vues.add);

    expect(vues, isEmpty);
  });

  test('erreur du natif : avalée, le montage du routeur continue', () async {
    messager.setMockMethodCallHandler(
      canal,
      (_) async => throw PlatformException(code: 'x'),
    );
    final vues = <String>[];

    await reprendreLienEnAttente(canal, vues.add);

    expect(vues, isEmpty);
  });
}
