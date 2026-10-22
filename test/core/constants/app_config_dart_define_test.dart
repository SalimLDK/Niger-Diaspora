import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `String.fromEnvironment` n'est évaluable qu'en contexte constant.
///
/// `AppConfig._read` l'appelait avec une clé variable : sur la VM ça passe
/// (valeur par défaut), sur dart2js ça **lève** « String.fromEnvironment can
/// only be used as a const constructor » — mesuré le 2026-10-14 sur le build
/// web du panneau admin : page blanche dès `isSupabaseConfigured`. Ce test
/// garde `lib/` libre de tout `fromEnvironment` dont l'argument n'est pas un
/// littéral, et vérifie que chaque clé lue par `_read` a bien son entrée
/// constante dans `_dartDefines`.
void main() {
  test("aucun fromEnvironment avec une clé variable dans lib/", () {
    final nonConstant = RegExp(r'(String|bool|int)\.fromEnvironment\(\s*[A-Za-z_]');
    final commentaire = RegExp(r'//.*');
    final fautifs = <String>[];
    for (final file in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      // Les commentaires sont retirés : celui d'`AppConfig._dartDefines` cite
      // justement l'ancien appel fautif pour expliquer la table.
      final code = file
          .readAsStringSync()
          .split('\n')
          .map((ligne) => ligne.replaceFirst(commentaire, ''))
          .join('\n');
      if (nonConstant.hasMatch(code)) {
        fautifs.add(file.path);
      }
    }
    expect(
      fautifs,
      isEmpty,
      reason: "l'argument de fromEnvironment doit être un littéral : dart2js "
          'lève à l\'exécution sinon (page blanche sur le web)',
    );
  });

  test('chaque clé lue par AppConfig._read a son entrée constante', () {
    final source =
        File('lib/core/constants/app_config.dart').readAsStringSync();
    final clesLues = RegExp(r"_read\(\s*'([A-Z_]+)'")
        .allMatches(source)
        .map((m) => m.group(1)!)
        .toSet();
    final clesDeclarees = RegExp(r"'([A-Z_]+)':\s*String\.fromEnvironment\('([A-Z_]+)'\)")
        .allMatches(source)
        .where((m) => m.group(1) == m.group(2))
        .map((m) => m.group(1)!)
        .toSet();
    expect(clesLues, isNotEmpty);
    expect(
      clesLues.difference(clesDeclarees),
      isEmpty,
      reason: 'une clé lue par _read sans entrée dans _dartDefines '
          "n'a pas de --dart-define",
    );
  });
}
