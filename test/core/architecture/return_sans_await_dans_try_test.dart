import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:flutter_test/flutter_test.dart';

/// Garde-fou contre le `return unFutur()` sans `await` dans un `try`.
///
/// Dans une fonction `async`, `return unFutur()` à l'intérieur d'un `try`
/// rend le Future sans l'attendre : s'il échoue, le `catch` est déjà dépassé.
/// Or ce `catch` est celui qui convertit en `ServerException` ou en message
/// lisible — l'échec arrivait donc brut à l'appelant, ou nulle part.
///
/// 23 sites corrigés le 2026-10-13 (`8073f496`, `59d0e0e3`). Aucune règle
/// d'analyse ne les signale avec le SDK épinglé (Dart 3.12 ne connaît pas
/// `unawaited_return_in_try_block`) : sans ce test, le défaut revient sans
/// bruit.
///
/// Comment corriger un site signalé :
///
/// - l'appelé est réellement asynchrone → `return await …` ;
/// - le type n'est qu'un `FutureOr` inféré, typiquement `either.fold(...)`
///   avec deux rappels synchrones → donner le type à `fold<T>(...)`.
///
/// Limite assumée : il faut les types résolus (un Future ne se reconnaît pas
/// au texte), donc ce test analyse `lib/` en entier — compter une à deux
/// minutes. Les fichiers sans `try` sont écartés avant résolution.
void main() {
  test(
    'le balayage reconnaît le défaut et épargne ses deux corrections',
    () async {
      final dossier = Directory.systemTemp.createTempSync('return_sans_await');
      addTearDown(() => dossier.deleteSync(recursive: true));
      File('${dossier.path}${Platform.pathSeparator}echantillon.dart')
          .writeAsStringSync('''
import 'dart:async';

Future<int> lent() async => 1;
T plier<T>(T Function() f) => f();

Future<int> fautif() async {
  try {
    return lent();
  } catch (_) {
    return 0;
  }
}

Future<int> fautifFinally() async {
  try {
    return lent();
  } finally {}
}

Future<bool> fautifFutureOr(FutureOr<bool> v) async {
  try {
    return v;
  } catch (_) {
    return false;
  }
}

Future<int> attendu() async {
  try {
    return await lent();
  } catch (_) {
    return 0;
  }
}

Future<bool> type() async {
  try {
    return plier<bool>(() => true);
  } catch (_) {
    return false;
  }
}

Future<int> horsTry() async {
  return lent();
}

Future<int> dansLeCatch() async {
  try {
    throw StateError('x');
  } catch (_) {
    return lent();
  }
}

Future<int> nonAsync() {
  try {
    return lent();
  } catch (_) {
    return Future.value(0);
  }
}

Future<int> fermetureSynchrone() async {
  try {
    final f = () => lent();
    return await f();
  } catch (_) {
    return 0;
  }
}
''');

      final sites = await _returnsSansAwait(
        dossier.resolveSymbolicLinksSync(),
      );

      expect(
        sites.map((s) => s.split(':').last.trim()).toList(),
        ['return lent();', 'return lent();', 'return v;'],
        reason: 'attendu : fautif, fautifFinally, fautifFutureOr — rien '
            "d'autre. Trouvé :\n${sites.join('\n')}",
      );
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );

  test(
    'aucun return de Future sans await dans un try, dans lib/',
    () async {
      final sites = await _returnsSansAwait(Directory('lib').absolute.path);

      expect(
        sites,
        isEmpty,
        reason: 'Un échec de ces Futures échapperait au catch qui les '
            'entoure. `return await …` si l\'appelé est asynchrone ; un type '
            'explicite sur `fold<T>(...)` si seul le FutureOr inféré est en '
            'cause.\n${sites.join('\n')}',
      );
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}

/// Sites `chemin:ligne: instruction` de [racine] où un `return` rend un
/// Future (ou un FutureOr) sans `await`, dans le corps d'un `try` muni d'un
/// `catch` ou d'un `finally`, au sein d'une fonction `async`.
Future<List<String>> _returnsSansAwait(String racine) async {
  final collection = AnalysisContextCollection(
    includedPaths: [racine],
    sdkPath: _sdkDart(),
  );
  final sites = <String>[];
  for (final contexte in collection.contexts) {
    for (final chemin in contexte.contextRoot.analyzedFiles()) {
      if (!chemin.endsWith('.dart') ||
          chemin.endsWith('.g.dart') ||
          chemin.endsWith('.freezed.dart')) {
        continue;
      }
      // Résoudre coûte ; lire non. Pas de `try`, pas de site possible.
      if (!File(chemin).readAsStringSync().contains('try')) continue;
      final resultat = await contexte.currentSession.getResolvedUnit(chemin);
      if (resultat is ResolvedUnitResult) {
        resultat.unit.accept(_Visiteur(resultat, sites));
      }
    }
  }
  await collection.dispose();
  return sites;
}

/// `flutter test` tourne sous `flutter_tester`, d'où l'analyseur ne sait pas
/// déduire le SDK : on le lui désigne.
String? _sdkDart() {
  final flutter = Platform.environment['FLUTTER_ROOT'];
  if (flutter == null) return null;
  final sdk = Directory(
    [flutter, 'bin', 'cache', 'dart-sdk'].join(Platform.pathSeparator),
  );
  return sdk.existsSync() ? sdk.path : null;
}

class _Visiteur extends RecursiveAstVisitor<void> {
  _Visiteur(this._resultat, this._sites);

  final ResolvedUnitResult _resultat;
  final List<String> _sites;

  @override
  void visitReturnStatement(ReturnStatement node) {
    super.visitReturnStatement(node);
    final expression = node.expression;
    if (expression == null || expression is AwaitExpression) return;
    final type = expression.staticType;
    if (type == null || !_estUnFutur(type)) return;

    // Remonter jusqu'au corps de fonction le plus proche : le `try` doit être
    // traversé par son corps (pas par un `catch`), et la fonction être async.
    var dansUnTry = false;
    AstNode enfant = node;
    for (var parent = node.parent; parent != null; parent = parent.parent) {
      if (parent is TryStatement &&
          identical(parent.body, enfant) &&
          (parent.catchClauses.isNotEmpty || parent.finallyBlock != null)) {
        dansUnTry = true;
      }
      if (parent is FunctionBody) {
        if (dansUnTry && parent.isAsynchronous && !parent.isGenerator) {
          final ligne =
              _resultat.lineInfo.getLocation(node.offset).lineNumber;
          final source = node.toSource().split('\n').first;
          _sites.add('${_resultat.path}:$ligne: $source');
        }
        return;
      }
      enfant = parent;
    }
  }

  bool _estUnFutur(DartType type) =>
      type.isDartAsyncFuture ||
      type.isDartAsyncFutureOr ||
      (type is InterfaceType &&
          type.allSupertypes.any((s) => s.isDartAsyncFuture));
}
