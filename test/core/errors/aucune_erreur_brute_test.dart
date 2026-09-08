import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Aucun écran ne doit interpoler une exception dans du texte affiché.
///
/// Ce garde existe parce que le défaut était partout : **42 sites dans 30
/// fichiers** au 2026-09-08, tous de la forme `Text('Erreur: $e')`. Ce qui
/// s'affichait alors, vu sur SM A515F réseau coupé :
///
///     Erreur: ServerFailure(ClientException with SocketException: Failed
///     host lookup: 'zyrfkcjjrhddpfxcgezo.supabase.co',
///     uri=.../rest/v1/users?select=%2A&id=eq.<UID>)
///
/// L'identifiant du projet Supabase et celui du compte, à l'écran. PostgREST
/// met l'URL complète dans ses messages, Firebase y met le chemin du
/// document : aucune de ces couches n'est montrable telle quelle.
///
/// Le remplaçant est `messageErreurUsager` (`lib/core/errors/message_erreur.dart`).
void main() {
  test('aucune exception interpolée dans un texte affiché', () {
    // `Text('… $e …')` où la variable est un nom d'erreur usuel.
    final motif = RegExp(
      r"""Text\(\s*'[^']*\$\{?(e|err|error|erreur|exception|ex)\}?[.'\s]""",
    );

    final fautifs = <String>[];
    final lib = Directory('lib');

    for (final f in lib.listSync(recursive: true).whereType<File>()) {
      final chemin = f.path.replaceAll(r'\', '/');
      if (!chemin.endsWith('.dart')) continue;
      if (chemin.endsWith('.g.dart') || chemin.endsWith('.freezed.dart')) {
        continue;
      }

      final lignes = f.readAsLinesSync();
      for (var i = 0; i < lignes.length; i++) {
        if (motif.hasMatch(lignes[i])) {
          fautifs.add('$chemin:${i + 1}  ${lignes[i].trim()}');
        }
      }
    }

    expect(
      fautifs,
      isEmpty,
      reason:
          "Une exception est interpolée dans du texte affiché. Le message brut\n"
          "expose l'hôte Supabase, l'identifiant du compte ou le chemin du\n"
          "document selon la couche.\n"
          'À la place :\n'
          '  Text(messageErreurUsager(e))\n'
          "  Text(messageErreurContextuel('Envoi impossible', e))\n"
          '${fautifs.join('\n')}',
    );
  });
}
