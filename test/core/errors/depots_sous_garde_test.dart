import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Garde-fou contre le retour des exceptions qui traversent un dépôt.
///
/// Fiche Crashlytics `PostgrestBuilder._parseResponse` du 2026-10-13 : 36
/// événements, 9 usagers, tous comptés plantages, parce que dix-sept dépôts
/// n'attrapaient que `ServerException`. Une `PostgrestException` — contrainte
/// `23514`, « JWT expired », passerelle 522 — remontait jusqu'à
/// `PlatformDispatcher.onError` sans qu'aucun écran ne dise rien.
///
/// La règle : une méthode `Future<Either<Failure, T>>` d'un dépôt n'appelle
/// sa datasource que sous `garderAppel` (`lib/core/errors/garde_appel.dart`),
/// qui convertit tout ce que la couche données sait lever. Un `try` posé à la
/// main n'y suffit pas : c'est exactement ce que les dix-sept faisaient.
///
/// Limite assumée : ce test lit la source. Il juge **lexicalement** qu'un
/// appel est sous garde — à l'intérieur des parenthèses d'un `garderAppel(` —
/// et ne reconnaît que les champs dont le type se termine par `DataSource`
/// (les `…LocalDataSource`, qui lèvent `CacheException`, sont hors sujet).
void main() {
  /// Ce qui appelle encore une datasource hors de la garde, avec la raison.
  ///
  /// Clé : `fichier.dart` (tout le fichier) ou `fichier.dart#methode`. Cette
  /// liste ne peut que rétrécir : une entrée qui ne correspond plus à rien
  /// fait échouer le test, pour qu'on la retire.
  const horsGarde = <String, String>{
    'call_repository_impl.dart':
        'filet `catch (e)` générique sur chaque méthode : rien ne traverse, '
        'mais le Failure porte `e.toString()`. Migration à faire.',
    'marketplace_repository_impl.dart':
        'filet `catch (e)` générique sur chaque méthode : rien ne traverse, '
        'mais le Failure porte `e.toString()`. Migration à faire.',
    'transfer_repository_impl.dart':
        'filet `catch (e)` générique sur chaque méthode : rien ne traverse, '
        'mais le Failure porte `e.toString()`. Migration à faire.',
    'embassies_repository_impl.dart':
        'rend des listes, pas des Either, et replie sur la copie locale ; sa '
        'datasource convertit déjà toute PostgrestException en '
        'ServerException (quatre méthodes, vérifié le 2026-10-13).',
    'demarches_repository_impl.dart':
        'rend un catalogue, pas un Either, et replie sur le cache puis '
        'l\'asset ; sa datasource convertit tout en ServerException.',
  };

  final depots = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) {
        final chemin = f.path.replaceAll(r'\', '/');
        return chemin.contains('/repositories/') &&
            chemin.endsWith('_repository_impl.dart');
      })
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  test('il y a bien des dépôts à balayer', () {
    expect(depots.length, greaterThan(15));
  });

  final trouvailles = <String>[
    for (final f in depots) ..._appelsHorsGarde(f),
    for (final f in depots) ..._serverExceptionSansPostgrest(f),
  ];

  test('toute méthode Future<Either<…>> appelle sa datasource sous garderAppel',
      () {
    final restantes = trouvailles
        .where((t) => !t.endsWith(_marqueFichier))
        .where((t) => !_couverte(horsGarde, t))
        .toList();

    expect(
      restantes,
      isEmpty,
      reason:
          'Ces appels de datasource ne passent pas par garderAppel. Une '
          'PostgrestException (RLS, contrainte, JWT expiré, passerelle) '
          'traverserait le dépôt et finirait en plantage. Écrire :\n'
          '  return garderAppel(() async { … });\n'
          '${restantes.join('\n')}',
    );
  });

  test('un dépôt qui attrape ServerException attrape aussi PostgrestException',
      () {
    final restantes = trouvailles
        .where((t) => t.endsWith(_marqueFichier))
        .where((t) => !_couverte(horsGarde, t))
        .toList();

    expect(
      restantes,
      isEmpty,
      reason:
          'Ces dépôts attrapent ServerException sans jamais nommer '
          'PostgrestException : c\'est la forme exacte des dix-sept dépôts '
          'de la fiche du 2026-10-13.\n${restantes.join('\n')}',
    );
  });

  test('la liste des exceptions ne porte que des entrées encore vraies', () {
    for (final cle in horsGarde.keys) {
      expect(
        trouvailles.any((t) => _correspond(cle, t)),
        isTrue,
        reason:
            '« $cle » ne correspond plus à aucun appel hors garde : '
            'retirez-la, la liste ne doit que rétrécir.',
      );
    }
  });
}

/// Suffixe des trouvailles « fichier entier » du second test.
const _marqueFichier = '#(fichier)';

bool _couverte(Map<String, String> exceptions, String trouvaille) =>
    exceptions.keys.any((cle) => _correspond(cle, trouvaille));

/// `x.dart` couvre `x.dart#m:12` et `x.dart#(fichier)` ; `x.dart#m` ne couvre
/// que `x.dart#m:12`.
bool _correspond(String cle, String trouvaille) {
  if (cle.contains('#')) return trouvaille.startsWith('$cle:');
  return trouvaille.startsWith('$cle#');
}

/// `fichier.dart#(fichier)` si le fichier attrape `ServerException` sans
/// nommer `PostgrestException` — ni directement, ni via `garderAppel`.
Iterable<String> _serverExceptionSansPostgrest(File f) sync* {
  final src = f.readAsStringSync();
  if (!RegExp(r'\bon ServerException\b').hasMatch(src)) return;
  if (src.contains('PostgrestException')) return;
  yield '${f.uri.pathSegments.last}$_marqueFichier';
}

/// `fichier.dart#methode:ligne` pour chaque appel de datasource qui n'est pas
/// dans les parenthèses d'un `garderAppel(`, dans une méthode
/// `Future<Either<…>>`.
Iterable<String> _appelsHorsGarde(File f) sync* {
  final src = f.readAsStringSync();
  final nom = f.uri.pathSegments.last;

  final champs = RegExp(r'final\s+([\w<>?,\s]*?Data[Ss]ource\w*)\??\s+(_?\w+)\s*;')
      .allMatches(src)
      .where((m) => !m.group(1)!.contains('Local'))
      .map((m) => m.group(2)!)
      .toSet();

  final cibles = <RegExp>[
    for (final champ in champs) RegExp('\\b${RegExp.escape(champ)}\\.\\w+\\('),
    // Un dépôt qui court-circuite sa datasource est tenu à la même règle.
    RegExp(r'\bSupabase\.instance\.client\.'),
  ];

  final gardes = _blocsGardes(src);

  for (final cible in cibles) {
    for (final m in cible.allMatches(src)) {
      if (gardes.any((g) => m.start > g.$1 && m.start < g.$2)) continue;
      final methode = _methodeEnglobante(src, m.start);
      if (methode == null) continue;
      yield '$nom#$methode:${_ligne(src, m.start)}';
    }
  }
}

/// Nom de la méthode `Future<Either<…>>` qui contient [position], ou `null`
/// si le membre englobant est d'une autre forme (Stream, getter, sync…).
///
/// Le membre englobant est la dernière ligne, avant [position], à exactement
/// deux espaces d'indentation et commençant par un identifiant : c'est là que
/// `dart format` pose les déclarations d'une classe.
String? _methodeEnglobante(String src, int position) {
  final declaration = RegExp(r'^  [A-Za-z_]', multiLine: true);
  RegExpMatch? derniere;
  for (final m in declaration.allMatches(src)) {
    if (m.start > position) break;
    derniere = m;
  }
  if (derniere == null) return null;
  final finDeLigne = src.indexOf('\n', derniere.start);
  final ligne = src.substring(
    derniere.start,
    finDeLigne < 0 ? src.length : finDeLigne,
  );
  if (!RegExp(r'^  (?:static\s+)?Future<Either<').hasMatch(ligne)) return null;
  return RegExp(r'>\s+(\w+)\s*\(').firstMatch(ligne)?.group(1);
}

/// Étendues `(début, fin)` des parenthèses de chaque `garderAppel(…)`.
List<(int, int)> _blocsGardes(String src) {
  final sortie = <(int, int)>[];
  for (final m in RegExp(r'\bgarderAppel\b').allMatches(src)) {
    var i = m.end;
    while (i < src.length && src[i] == ' ') {
      i++;
    }
    if (i < src.length && src[i] == '<') {
      var profondeur = 0;
      while (i < src.length) {
        if (src[i] == '<') profondeur++;
        if (src[i] == '>') {
          profondeur--;
          if (profondeur == 0) {
            i++;
            break;
          }
        }
        i++;
      }
    }
    if (i >= src.length || src[i] != '(') continue;
    sortie.add((i, _finDeParenthese(src, i)));
  }
  return sortie;
}

/// Index de la parenthèse qui ferme celle ouverte en [ouvrante], en sautant
/// chaînes de caractères et commentaires.
int _finDeParenthese(String src, int ouvrante) {
  var profondeur = 0;
  var i = ouvrante;
  while (i < src.length) {
    final c = src[i];
    if (c == '/' && src.startsWith('//', i)) {
      final fin = src.indexOf('\n', i);
      i = fin < 0 ? src.length : fin;
      continue;
    }
    if (c == "'" || c == '"') {
      i = _finDeChaine(src, i);
      continue;
    }
    if (c == '(') profondeur++;
    if (c == ')') {
      profondeur--;
      if (profondeur == 0) return i;
    }
    i++;
  }
  return src.length;
}

/// Index juste après la chaîne ouverte en [debut] (guillemet simple, double
/// ou triple), interpolations `${…}` comprises.
int _finDeChaine(String src, int debut) {
  final guillemet = src[debut];
  final triple = src.startsWith(guillemet * 3, debut);
  final fermeture = triple ? guillemet * 3 : guillemet;
  final brute = debut > 0 && src[debut - 1] == 'r';
  var i = debut + fermeture.length;
  while (i < src.length) {
    if (src.startsWith(fermeture, i)) return i + fermeture.length;
    final c = src[i];
    if (c == r'\' && !brute) {
      i += 2;
      continue;
    }
    if (c == r'$' && !brute && i + 1 < src.length && src[i + 1] == '{') {
      var profondeur = 0;
      var j = i + 1;
      while (j < src.length) {
        if (src[j] == '{') profondeur++;
        if (src[j] == '}') {
          profondeur--;
          if (profondeur == 0) break;
        }
        j++;
      }
      i = j + 1;
      continue;
    }
    i++;
  }
  return src.length;
}

int _ligne(String src, int position) =>
    src.substring(0, position).split('\n').length;
