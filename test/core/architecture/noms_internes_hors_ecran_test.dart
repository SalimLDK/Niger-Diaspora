import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Aucun nom de brique interne dans un texte qui peut atteindre l'écran.
///
/// Vu sur appareil le 2026-09-14 : une discussion ouverte hors ligne affichait
/// **« Session Supabase non établie – réessayez »** en plein milieu de l'écran.
/// C'est le message d'une exception interne, rendu tel quel par l'état d'erreur
/// de la liste — un utilisateur n'a que faire du nom de notre base, et ça
/// renseigne gratuitement notre pile technique.
///
/// La règle porte sur ce qui **sort vers l'utilisateur** : messages jetés
/// (leur texte finit régulièrement dans un bandeau ou un `SnackBar`), libellés
/// d'interface en dur, et valeurs des fichiers de traduction. Les journaux
/// (`debugPrint`, `dev.log`) gardent le droit de nommer les briques : ils
/// servent au diagnostic et ne s'affichent nulle part.
void main() {
  final motsInterdits = RegExp(r'(Supabase|Firebase)');

  /// Messages jetés : `throw XxxException('…')`, `Failure('…')`, `StateError`…
  final messageJete = RegExp(
    r'''(Exception|Failure|StateError|ArgumentError|RangeError)\(\s*(['"])((?:(?!\2).)*)\2''',
  );

  /// Libellés d'interface posés en dur.
  final libelleEnDur = RegExp(
    r'''(Text|SelectableText)\(\s*(['"])((?:(?!\2).)*)\2''',
  );

  test('aucun message jeté ne nomme une brique interne', () {
    final fautes = <String>[];

    for (final fichier in Directory('lib').listSync(recursive: true)) {
      if (fichier is! File || !fichier.path.endsWith('.dart')) continue;
      final lignes = fichier.readAsLinesSync();
      for (var i = 0; i < lignes.length; i++) {
        final ligne = lignes[i];
        if (ligne.trimLeft().startsWith('//')) continue;
        for (final motif in [messageJete, libelleEnDur]) {
          for (final trouve in motif.allMatches(ligne)) {
            final texte = trouve.group(3) ?? '';
            if (motsInterdits.hasMatch(texte)) {
              fautes.add('${fichier.path}:${i + 1} → « $texte »');
            }
          }
        }
      }
    }

    expect(
      fautes,
      isEmpty,
      reason:
          'Ces textes peuvent atteindre l\'écran et nomment une brique '
          'interne. Remplacer par un libellé neutre ; le détail technique '
          'reste dans les journaux.\n${fautes.join('\n')}',
    );
  });

  test('aucune traduction ne nomme une brique interne', () {
    for (final nom in ['lib/l10n/app_fr.arb', 'lib/l10n/app_en.arb']) {
      final fichier = File(nom);
      if (!fichier.existsSync()) continue;
      final fautes = <String>[];
      final lignes = fichier.readAsLinesSync();
      for (var i = 0; i < lignes.length; i++) {
        if (motsInterdits.hasMatch(lignes[i])) {
          fautes.add('$nom:${i + 1} → ${lignes[i].trim()}');
        }
      }
      expect(fautes, isEmpty, reason: fautes.join('\n'));
    }
  });
}
