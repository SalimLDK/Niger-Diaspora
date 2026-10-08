import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// La recherche de discussions interroge Supabase.
///
/// Elle instanciait l'ancienne source Firestore (`MessageRemoteDataSourceImpl`)
/// et cherchait dans la collection `conversations`, vide depuis la migration :
/// aucune discussion ne sortait jamais, sans erreur. L'ancienne source est
/// désormais en commentaire (code inutilisé, à supprimer) ; rien de `lib/` ne
/// doit plus y renvoyer.
void main() {
  test('la recherche se branche sur MessageSupabaseDataSource', () {
    final source = File(
      'lib/features/search/data/datasources/search_remote_datasource.dart',
    ).readAsStringSync();
    expect(source, contains('messageDataSource ?? MessageSupabaseDataSource()'));
  });

  test('plus rien n\'instancie l\'ancienne source Firestore', () {
    final appels = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => f
            .readAsLinesSync()
            .any((l) => !l.trimLeft().startsWith('//') &&
                l.contains('MessageRemoteDataSourceImpl(')))
        .map((f) => f.path)
        .toList();
    expect(appels, isEmpty);
  });
}
