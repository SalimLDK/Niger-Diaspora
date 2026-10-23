import 'dart:io';

import 'package:diaspo_niger/core/services/cache_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

Map<String, dynamic> _msg(String id, String contenu) => {
  'id': id,
  'content': contenu,
  'createdAt': '2026-10-01T10:00:00.000Z',
};

void main() {
  late Directory dossier;
  final cache = CacheService.instance;

  setUpAll(() async {
    dossier = await Directory.systemTemp.createTemp('hive_restauration_');
    Hive.init(dossier.path);
    await cache.initialize();
  });

  tearDownAll(() async {
    await Hive.close();
    await dossier.delete(recursive: true);
  });

  test('une restauration n\'écrase jamais un message déjà présent', () async {
    await cache.cacheMessages('c1', [_msg('a', 'version fraîche (modifiée)')]);

    final ajoutes = await cache.restaurerMessages('c1', [
      _msg('a', 'vieille copie de la sauvegarde'),
      _msg('b', 'message absent'),
    ]);

    expect(ajoutes, 1);
    final ids = {
      for (final m in cache.getCachedMessages('c1')) m['id']: m['content'],
    };
    expect(ids['a'], 'version fraîche (modifiée)');
    expect(ids['b'], 'message absent');
  });

  test('rien de nouveau → rien d\'écrit', () async {
    await cache.cacheMessages('c2', [_msg('a', 'x')]);
    expect(await cache.restaurerMessages('c2', [_msg('a', 'x')]), 0);
  });

  test('conversationsEnCache liste les fils, sans les clés « dechiffre_ »', () async {
    await cache.cacheMessages('c3', [_msg('a', 'x')]);
    await cache.cacheContenuDechiffre('mid', 'clair');
    final liste = cache.conversationsEnCache();
    expect(liste, containsAll(['c1', 'c2', 'c3']));
    expect(liste.any((c) => c.contains('mid')), isFalse);
  });
}
