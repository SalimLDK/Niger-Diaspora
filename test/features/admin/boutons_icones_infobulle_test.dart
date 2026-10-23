// Un bouton qui ne porte qu'une icône n'a pas de nom pour un lecteur d'écran,
// ni d'infobulle à la souris — et le panneau admin est un site web, donc à la
// souris. Ce test balaie le panneau : tout `IconButton` et tout
// `PopupMenuButton` doit déclarer son `tooltip` (ou son texte) dans les lignes
// qui suivent son ouverture.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Exceptions NOMMÉES : elles ne doivent que rétrécir.
const _exceptions = <String>{
  // (vide) — aucun bouton-icône du panneau n'est exempté.
};

void main() {
  test('chaque IconButton et PopupMenuButton du panneau a une infobulle', () {
    final racine = Directory('lib/features/admin/presentation');
    final fautifs = <String>[];
    for (final f in racine.listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final lignes = f.readAsLinesSync();
      for (var i = 0; i < lignes.length; i++) {
        if (!RegExp(r'\b(IconButton|PopupMenuButton<[^>]*>)\(').hasMatch(lignes[i])) {
          continue;
        }
        final fenetre = lignes.skip(i).take(8).join('\n');
        final nom = '${f.path.split(Platform.pathSeparator).join('/')}:${i + 1}';
        if (!fenetre.contains('tooltip:') && !_exceptions.contains(nom)) {
          fautifs.add(nom);
        }
      }
    }
    expect(fautifs, isEmpty,
        reason: 'boutons-icônes sans infobulle :\n${fautifs.join('\n')}');
  });
}
