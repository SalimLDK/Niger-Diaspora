import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Garde-fou : un destinataire passé à `/messages/new` doit être **lu** par la
/// route.
///
/// Le défaut, corrigé le 2026-09-14 : la route construisait
/// `const NewConversationScreen()` — un écran sans paramètre, qui ne lisait ni
/// `?userId=` ni `state.extra`. Trois appelants nommaient pourtant quelqu'un :
/// la tuile « écrivez à … » de la messagerie vide, un résultat de recherche
/// « personnes », et le bouton « Contacter » d'une fiche entreprise. Les trois
/// atterrissaient sur le sélecteur générique, strictement identique à celui du
/// bouton « Nouvelle conversation » — il fallait re-chercher à la main la
/// personne qu'on venait de toucher du doigt.
///
/// Rien ne le signalait : le destinataire était bien construit côté appelant,
/// et jeté en silence côté routeur. Pas d'erreur, pas de journal, juste un
/// écran qui ressemble à celui qu'on attendait.
///
/// Ce garde tient les deux bouts de la chaîne : ce que les appelants passent,
/// et ce que la route lit.
///
/// Limite assumée : le test lit les sources. Il attrape le paramètre ignoré —
/// la famille observée — pas une route qui le lirait puis en ferait n'importe
/// quoi. Le parcours réel est suivi dans `TESTS_APPAREIL_A_FAIRE.md`,
/// « Désigner quelqu'un ouvre sa discussion, plus le sélecteur ».
void main() {
  /// Le bloc `GoRoute` de `/messages/new`, du `GoRoute(` qui le porte
  /// jusqu'au `GoRoute(` suivant.
  String routeBlock() {
    final source = File('lib/core/router/app_router.dart').readAsStringSync();
    final start = source.indexOf("path: '/messages/new'");
    expect(
      start,
      isNot(-1),
      reason: "la route '/messages/new' a disparu du routeur",
    );
    final next = source.indexOf('GoRoute(', start);
    return next == -1 ? source.substring(start) : source.substring(start, next);
  }

  /// Toutes les sources de `lib/`, chemin → contenu.
  Map<String, String> libSources() {
    return {
      for (final f in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart')))
        f.path: f.readAsStringSync(),
    };
  }

  test("la route '/messages/new' lit le destinataire qu'on lui passe", () {
    final block = routeBlock();

    expect(
      block.contains("queryParameters['userId']"),
      isTrue,
      reason:
          "la route ignore `?userId=` : les appelants qui nomment quelqu'un "
          'retombent sur le sélecteur générique',
    );
    expect(
      block.contains("'recipientId'"),
      isTrue,
      reason:
          "la route ignore `extra['recipientId']` : le bouton « Contacter » "
          "d'une fiche entreprise retombe sur le sélecteur générique",
    );
    expect(
      RegExp(r'const\s+NewConversationScreen\s*\(\s*\)').hasMatch(block),
      isFalse,
      reason:
          "`const NewConversationScreen()` n'accepte aucun destinataire : "
          'c\'est la forme exacte du défaut du 2026-09-14',
    );
  });

  test('tout paramètre passé par un appelant est lu par la route', () {
    final block = routeBlock();

    // Les noms de paramètres présents dans un lien `/messages/new?…` écrit
    // quelque part dans `lib/`.
    final passed = <String, String>{};
    final link = RegExp(r"'/messages/new\?([^']*)'");
    libSources().forEach((path, source) {
      for (final m in link.allMatches(source)) {
        for (final pair in m.group(1)!.split('&')) {
          final name = pair.split('=').first.trim();
          if (name.isNotEmpty) passed[name] = path;
        }
      }
    });

    expect(
      passed,
      isNotEmpty,
      reason:
          'aucun appelant ne nomme plus de destinataire — si la fonction a '
          'été retirée, retirer ce garde avec elle',
    );

    passed.forEach((name, path) {
      expect(
        block.contains("queryParameters['$name']"),
        isTrue,
        reason:
            "$path passe `?$name=` à /messages/new, que la route ne lit pas : "
            'le destinataire est construit puis jeté en silence',
      );
    });
  });

  test("l'écran accepte un destinataire et se remplace par la discussion", () {
    final screen =
        File(
          'lib/features/messages/presentation/screens/'
          'new_conversation_screen.dart',
        ).readAsStringSync();

    expect(
      screen.contains('initialRecipientId'),
      isTrue,
      reason:
          "l'écran n'a plus de paramètre de destinataire : la route n'a nulle "
          'part où le poser',
    );
    expect(
      screen.contains('pushReplacement'),
      isTrue,
      reason:
          'la discussion doit **remplacer** le sélecteur, sinon le retour '
          "depuis la discussion ramène sur un sélecteur qu'on n'a jamais "
          'utilisé',
    );
  });
}
