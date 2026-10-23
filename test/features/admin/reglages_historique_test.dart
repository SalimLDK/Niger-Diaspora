import 'package:diaspo_niger/features/admin/data/datasources/app_settings_datasource.dart';
import 'package:diaspo_niger/features/admin/data/datasources/reglages_historique_datasource.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

/// Un réglage ne change plus sans son historique : `updateSection` écrit, dans
/// la même transaction, le document des réglages ET une entrée neuve que le
/// document cite (`lastChangeId`) — ce que les règles Firestore vérifient
/// (banc : tools/rules_tests/reglages_historique.mjs).
void main() {
  late FakeFirebaseFirestore firestore;
  late AppSettingsDataSourceImpl source;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    source = AppSettingsDataSourceImpl(
      firestore: firestore,
      uidCourant: () => 'super-1',
    );
  });

  Future<List<Map<String, dynamic>>> entrees() async {
    final snap = await firestore.collection('app_config_history').get();
    return [for (final d in snap.docs) {'id': d.id, ...d.data()}];
  }

  test('une modification écrit le réglage ET son entrée, liée par lastChangeId', () async {
    await source.updateSection('fees', {'a': 2}, 'super-1');

    final settings = (await firestore.collection('app_config').doc('settings').get()).data()!;
    final liste = await entrees();
    expect(liste, hasLength(1));
    expect(settings['fees'], {'a': 2});
    expect(settings['lastChangeId'], liste.single['id'],
        reason: 'les règles exigent que le document cite une entrée neuve');
    expect(liste.single['by'], 'super-1');
    expect(liste.single['kind'], 'update');
    expect(liste.single['before'], isNull, reason: 'première valeur de la section');
    expect(liste.single['after'], {'a': 2});
  });

  test("l'« avant » est la valeur que ce changement remplace vraiment", () async {
    await source.updateSection('fees', {'a': 1}, 'super-1');
    await source.updateSection('fees', {'a': 2, 'b': 5}, 'super-1', reason: '  Correction  ');

    final liste = await entrees();
    final derniere = liste.firstWhere((e) => e['after'].toString() == {'a': 2, 'b': 5}.toString());
    expect(derniere['before'], {'a': 1});
    expect(derniere['reason'], 'Correction', reason: 'le motif est rogné');
    expect(liste.map((e) => e['id']).toSet(), hasLength(2),
        reason: 'chaque changement a SON entrée : un identifiant ne sert qu\'une fois');
  });

  test('un retour arrière est une entrée « restore » qui cite sa source', () async {
    await source.updateSection('fees', {'a': 1}, 'super-1');
    await source.updateSection('fees', {'a': 2}, 'super-1');
    final avant = (await entrees()).firstWhere((e) => e['after'].toString() == {'a': 2}.toString());

    await source.updateSection('fees', avant['before'] as Map<String, dynamic>, 'super-1',
        reason: 'Erreur de saisie', kind: 'restore', restoredFrom: avant['id'] as String);

    final restauration = (await entrees()).firstWhere((e) => e['kind'] == 'restore');
    expect(restauration['restoredFrom'], avant['id']);
    expect(restauration['before'], {'a': 2});
    expect(restauration['after'], {'a': 1});
    final settings = (await firestore.collection('app_config').doc('settings').get()).data()!;
    expect(settings['fees'], {'a': 1});
  });

  test('sans session, rien n\'est écrit', () async {
    final sansSession = AppSettingsDataSourceImpl(firestore: firestore, uidCourant: () => null);

    await expectLater(sansSession.updateSection('fees', {'a': 1}, 'x'), throwsStateError);

    expect(await entrees(), isEmpty);
    expect((await firestore.collection('app_config').doc('settings').get()).exists, isFalse);
  });

  test('la lecture rend les plus récentes d\'abord et calcule les différences', () async {
    await source.updateSection('fees', {'a': 1, 'liste': [1, 2]}, 'super-1');
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await source.updateSection('fees', {'a': 1, 'liste': [1, 3], 'b': true}, 'super-1');

    final lues = await ReglagesHistoriqueSource(firestore: firestore).lire();

    expect(lues, hasLength(2));
    final recente = lues.first;
    expect(recente.avant, {'a': 1, 'liste': [1, 2]});
    expect(recente.restaurable, isTrue);
    expect([for (final d in recente.differences) d.cle], ['b', 'liste'],
        reason: 'a est inchangée ; la liste est comparée en profondeur');
    expect(lues.last.restaurable, isFalse, reason: 'la première valeur n\'a pas d\'avant');
  });
}
