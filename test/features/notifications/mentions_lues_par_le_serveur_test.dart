import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Les mentions sont lues par le SERVEUR, et par lui seul.
///
/// `messageMention` — une mention dans une conversation en sourdine — est
/// affichée par l'écran Notifications et comptée par la cloche. Depuis la
/// migration `20260919120000`, elle est marquée lue par les deux fonctions qui
/// marquent des notifications : `mark_messages_as_read` (l'ancien chemin, et
/// l'action « Marquer comme lu » de la bannière) et `marquer_lus_jusqua` (la
/// lecture par curseur). Le marquage côté client qui la doublait est retiré.
///
/// Ce qui casserait sans bruit : une migration POSTÉRIEURE qui redéfinit l'une
/// de ces fonctions à partir d'une copie plus ancienne. `CREATE OR REPLACE` ne
/// fusionne rien, la dernière définition gagne, et la mention redeviendrait non
/// lue sans qu'aucun écran ni aucun test Dart ne le voie — d'autant que plus
/// rien, côté client, ne rattrape. Ce banc lit donc la DERNIÈRE définition de
/// chaque fonction, pas une migration fixe.
///
/// Le comportement est éprouvé en base par
/// `tools/rls_tests/mentions_lues_avec_la_discussion.sql` (21 cas ; les cas 1,
/// 2, 9 et 14 tombent sans `messageMention`). Ce fichier tient le texte.

String _lire(File f) => f.readAsStringSync().replaceAll('\r\n', '\n');

/// Les migrations dans l'ordre d'application : le préfixe est un horodatage à
/// 14 chiffres, l'ordre lexical est donc l'ordre chronologique.
List<File> _migrations() {
  final fichiers = Directory('supabase/migrations')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.sql'))
      .toList();
  fichiers.sort((a, b) => a.path.compareTo(b.path));
  return fichiers;
}

/// La DERNIÈRE définition de `public.[nom]` : le fichier qui la porte et son
/// corps, de la déclaration à la fermeture du délimiteur (`$$` ou
/// `$function$`, selon l'auteur). Accepte `CREATE FUNCTION` sans `OR REPLACE` —
/// `20260813130000` l'écrit ainsi, après un `DROP`.
({String fichier, String corps}) _derniereDefinition(String nom) {
  final declaration = RegExp(
    'CREATE\\s+(?:OR\\s+REPLACE\\s+)?FUNCTION\\s+(?:public\\.)?$nom\\s*\\(',
    caseSensitive: false,
  );
  ({String fichier, String corps})? derniere;
  for (final f in _migrations()) {
    final sql = _lire(f);
    for (final m in declaration.allMatches(sql)) {
      final apres = sql.substring(m.start);
      final ouverture = RegExp(r'AS\s+(\$[A-Za-z_]*\$)').firstMatch(apres);
      if (ouverture == null) continue;
      final debutCorps = ouverture.end;
      final fin = apres.indexOf(ouverture.group(1)!, debutCorps);
      if (fin == -1) continue;
      derniere = (
        fichier: f.uri.pathSegments.last,
        corps: apres.substring(debutCorps, fin),
      );
    }
  }
  expect(derniere, isNotNull, reason: 'aucune définition de $nom');
  return derniere!;
}

void main() {
  test('l\'assistant trouve bien la dernière définition, pas la première', () {
    // `mark_messages_as_read` est définie dans six migrations : la dernière
    // ne peut pas être une des plus anciennes.
    final d = _derniereDefinition('mark_messages_as_read');
    expect(d.fichier.compareTo('20260916235300'), greaterThanOrEqualTo(0),
        reason: d.fichier);
  });

  for (final nom in ['mark_messages_as_read', 'marquer_lus_jusqua']) {
    test('$nom : sa dernière définition marque aussi messageMention', () {
      final d = _derniereDefinition(nom);
      final liste = RegExp(
        r"type\s+IN\s*\(\s*'message'\s*,\s*'messageReaction'\s*,\s*"
        r"'messageMention'\s*\)",
      );
      expect(
        liste.hasMatch(d.corps),
        isTrue,
        reason:
            '$nom, définie en dernier par ${d.fichier}, ne marque plus '
            '`messageMention` : une mention y resterait non lue après la '
            'lecture de la discussion. Reprendre la définition de '
            '20260919120000, pas une copie plus ancienne.',
      );
    });
  }

  test('marquer_lus_jusqua : une mention postérieure à la borne reste non lue',
      () {
    // Sans cette clause, la mention partirait avec les messages lus alors
    // que son message n'a pas encore été vu.
    final d = _derniereDefinition('marquer_lus_jusqua');
    final exclusion = RegExp(
      r"n\.type\s+IN\s*\(\s*'message'\s*,\s*'messageMention'\s*\)\s+AND\s*\(",
    );
    expect(
      exclusion.hasMatch(d.corps),
      isTrue,
      reason:
          'la clause d\'exclusion par borne de ${d.fichier} ne couvre plus '
          '`messageMention` : elle serait marquée lue avant d\'avoir été vue.',
    );
  });
}
