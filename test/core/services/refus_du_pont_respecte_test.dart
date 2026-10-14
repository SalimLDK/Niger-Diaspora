import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Garde-fou : un refus du pont de session est respecté, partout.
///
/// Rafale `PGRST303` « JWT expired » de la fiche Crashlytics du 2026-10-13 :
/// cinq événements d'un seul usager, depuis trois écrans, sur une version qui
/// avait pourtant l'observateur de cycle de vie. Cause lue dans le code :
/// pendant la fenêtre de calme de `PolitiqueDeReprise`, `ensureAuthenticated()`
/// rendait `false`… et quarante-neuf sites l'ignoraient
/// (`await SupabaseAuthBridge.instance.ensureAuthenticated();` nu). La requête
/// partait quand même, avec le jeton périmé, et chaque écran ouvert pendant
/// la fenêtre ajoutait la sienne.
///
/// La règle : un appel au pont **lit sa réponse**. Soit il n'a pas de repli et
/// emploie `exigerSession()`, qui lève à sa place ; soit il en a un et teste
/// le booléen d'`ensureAuthenticated()` / `ensureReadableSession()`. Un
/// `await …();` posé seul sur sa ligne est exactement l'oubli d'origine.
///
/// Limite assumée : ce test lit la source, commentaires et chaînes retirés,
/// et juge **lexicalement** qu'une réponse est ignorée — l'appel est une
/// instruction à lui seul, ou l'argument d'un `unawaited(`. Il ne dit pas si
/// le booléen, une fois lu, est bien employé.
void main() {
  /// Ce qui ignore encore la réponse du pont, avec la raison.
  ///
  /// Clé : `fichier.dart` (tout le fichier) ou `fichier.dart:ligne`. Cette
  /// liste ne peut que rétrécir : une entrée qui ne correspond plus à rien
  /// fait échouer le test, pour qu'on la retire.
  const tolerees = <String, String>{
    'auth_repository_impl.dart':
        "déconnexion : la session part justement. `ensureReadableSession` y "
        "rétablit, borné, ce qu'il peut pour que le jeton push soit effacé "
        "en base ; sans session, l'effacement échoue et la déconnexion "
        "aboutit quand même — la réponse ne changerait rien à la suite.",
  };

  final sources = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) {
        final chemin = f.path.replaceAll(r'\', '/');
        return chemin.endsWith('.dart') &&
            !chemin.endsWith('/supabase_auth_bridge.dart');
      })
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  final appels = <_Appel>[for (final f in sources) ..._appelsDuPont(f)];

  test('il y a bien des appels au pont à balayer', () {
    // Plancher contre le test lui-même : si l'extraction cessait de
    // reconnaître les appels, il passerait au vert sans rien examiner.
    expect(appels.length, greaterThan(100));
    expect(appels.where((a) => a.methode == 'exigerSession'), isNotEmpty);
  });

  final ignores = [
    for (final a in appels)
      if (a.resultatIgnore) a.trouvaille,
  ];

  test("aucun appel au pont n'ignore sa réponse", () {
    final restantes =
        ignores.where((t) => !_couverte(tolerees, t)).toList();

    expect(
      restantes,
      isEmpty,
      reason:
          'Ces appels ignorent ce que le pont répond : sans session, la '
          "requête qui suit partirait avec un jeton périmé (PGRST303). Écrire "
          '`await SupabaseAuthBridge.instance.exigerSession();` — qui lève — '
          'ou tester le booléen quand il existe un repli.\n'
          '${restantes.join('\n')}',
    );
  });

  test('la liste des exceptions ne porte que des entrées encore vraies', () {
    for (final cle in tolerees.keys) {
      expect(
        ignores.any((t) => _correspond(cle, t)),
        isTrue,
        reason:
            '« $cle » ne correspond plus à aucun appel qui ignore sa réponse : '
            'retirez-la, la liste ne doit que rétrécir.',
      );
    }
  });
}

class _Appel {
  const _Appel(this.trouvaille, this.methode, {required this.resultatIgnore});

  /// `fichier.dart:ligne`.
  final String trouvaille;
  final String methode;
  final bool resultatIgnore;
}

bool _couverte(Map<String, String> exceptions, String trouvaille) =>
    exceptions.keys.any((cle) => _correspond(cle, trouvaille));

/// `x.dart` couvre `x.dart:12` ; `x.dart:12` ne couvre que lui-même.
bool _correspond(String cle, String trouvaille) =>
    cle.contains(':') ? trouvaille == cle : trouvaille.startsWith('$cle:');

final _appel = RegExp(
  r'SupabaseAuthBridge\.instance\s*\.\s*'
  r'(ensureAuthenticated|ensureReadableSession|exigerSession)\s*\(',
);

Iterable<_Appel> _appelsDuPont(File f) sync* {
  final brut = f.readAsStringSync();
  if (!brut.contains('SupabaseAuthBridge')) return;
  final src = _sansCommentairesNiChaines(brut);
  final nom = f.uri.pathSegments.last;

  for (final m in _appel.allMatches(src)) {
    final methode = m.group(1)!;
    final ignore = methode != 'exigerSession' &&
        _resultatIgnore(src, m.start, m.end - 1);
    yield _Appel(
      '$nom:${_ligne(src, m.start)}',
      methode,
      resultatIgnore: ignore,
    );
  }
}

/// Vrai si l'appel qui commence à [debut] (sa parenthèse ouvrante à
/// [ouvrante]) est une instruction à lui seul — `await …();` ou `…();` —
/// ou l'argument d'un `unawaited(`.
bool _resultatIgnore(String src, int debut, int ouvrante) {
  if (_seTermineParMot(src, _reculerBlancs(src, debut), 'unawaited(')) {
    return true;
  }

  var apres = _finDeParenthese(src, ouvrante) + 1;
  while (apres < src.length && _estBlanc(src[apres])) {
    apres++;
  }
  if (apres >= src.length || src[apres] != ';') return false;

  var avant = _reculerBlancs(src, debut);
  if (_seTermineParMot(src, avant, 'await')) {
    avant = _reculerBlancs(src, avant - 'await'.length);
  }
  if (avant == 0) return true;
  if (_seTermineParMot(src, avant, 'else')) return true;
  return '{};)'.contains(src[avant - 1]);
}

bool _seTermineParMot(String src, int fin, String mot) =>
    src.substring(0, fin).endsWith(mot);

bool _estBlanc(String c) => c == ' ' || c == '\n' || c == '\r' || c == '\t';

/// Index tel que `src[index - 1]` soit le dernier caractère non blanc
/// avant [position].
int _reculerBlancs(String src, int position) {
  var i = position;
  while (i > 0 && _estBlanc(src[i - 1])) {
    i--;
  }
  return i;
}

/// Index de la parenthèse qui ferme celle ouverte en [ouvrante].
int _finDeParenthese(String src, int ouvrante) {
  var profondeur = 0;
  for (var i = ouvrante; i < src.length; i++) {
    if (src[i] == '(') profondeur++;
    if (src[i] == ')') {
      profondeur--;
      if (profondeur == 0) return i;
    }
  }
  return src.length;
}

/// La source où commentaires et contenus de chaînes sont remplacés par des
/// espaces, longueur et sauts de ligne conservés : les positions et les
/// numéros de ligne restent ceux du fichier.
String _sansCommentairesNiChaines(String src) {
  final sortie = StringBuffer();
  var i = 0;
  void effacer(int jusqua) {
    for (; i < jusqua && i < src.length; i++) {
      sortie.write(src[i] == '\n' ? '\n' : ' ');
    }
  }

  while (i < src.length) {
    final c = src[i];
    if (src.startsWith('//', i)) {
      final fin = src.indexOf('\n', i);
      effacer(fin < 0 ? src.length : fin);
      continue;
    }
    if (src.startsWith('/*', i)) {
      final fin = src.indexOf('*/', i + 2);
      effacer(fin < 0 ? src.length : fin + 2);
      continue;
    }
    if (c == "'" || c == '"') {
      // On garde les guillemets eux-mêmes, pour que `'…';` reste lisible.
      sortie.write(c);
      i++;
      effacer(_finDeChaine(src, i - 1) - 1);
      if (i < src.length) {
        sortie.write(src[i]);
        i++;
      }
      continue;
    }
    sortie.write(c);
    i++;
  }
  return sortie.toString();
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
