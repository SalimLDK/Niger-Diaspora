import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Un `ListView(shrinkWrap: true)` dans le contenu d'un `AlertDialog` lève
/// « Intrinsic dimensions not available » dès qu'il a des éléments : le
/// dialogue s'ouvre vide ou en erreur. Avec une liste vide, rien ne se voit ;
/// c'est pourquoi l'historique des réglages est parti en production avec ce
/// défaut. Dans le panneau, un dialogue de liste est un SingleChildScrollView
/// + Column.
void main() {
  test('aucun ListView shrinkWrap dans le panneau d\'administration', () {
    final fautifs = <String>[];
    for (final f in Directory('lib/features/admin')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final texte = f.readAsStringSync();
      if (RegExp(r'ListView(\.\w+)?\(\s*shrinkWrap:\s*true').hasMatch(texte)) {
        fautifs.add(f.path.replaceAll('\\', '/'));
      }
    }
    expect(fautifs, isEmpty,
        reason: 'ListView(shrinkWrap) interdit : utiliser SingleChildScrollView + Column');
  });
}
