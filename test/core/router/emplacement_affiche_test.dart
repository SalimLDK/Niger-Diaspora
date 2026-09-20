import 'dart:async';

import 'package:diaspo_niger/core/router/emplacement_affiche.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Le chemin de la page réellement affichée, contre le VRAI routeur.
///
/// La structure reproduit celle de l'app : des onglets dans une
/// `StatefulShellRoute.indexedStack`, et les écrans de détail en `GoRoute` à la
/// racine, ouverts par `push`. `emplacementAffiche` décide si une notification
/// arrivée est celle de l'écran que l'on regarde : se tromper d'écran, c'est
/// marquer lue une notification que personne n'a vue, ou ne jamais marquer.
Widget _page(String nom) => Scaffold(body: Center(child: Text(nom)));

GoRouter _routeur() => GoRouter(
  initialLocation: '/home',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, coque) => coque,
      branches: [
        StatefulShellBranch(
          routes: [GoRoute(path: '/home', builder: (_, __) => _page('home'))],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: '/feed', builder: (_, __) => _page('fil'))],
        ),
      ],
    ),
    GoRoute(
      path: '/feed/:postId',
      builder: (_, e) => _page('post ${e.pathParameters['postId']}'),
    ),
    GoRoute(
      path: '/events/:eventId',
      builder: (_, e) => _page('événement ${e.pathParameters['eventId']}'),
    ),
    GoRoute(
      path: '/marketplace/my-orders',
      builder: (_, __) => _page('commandes'),
    ),
  ],
);

Future<GoRouter> _monte(WidgetTester tester) async {
  final routeur = _routeur();
  await tester.pumpWidget(MaterialApp.router(routerConfig: routeur));
  await tester.pumpAndSettle();
  return routeur;
}

void main() {
  testWidgets('l\'onglet affiché à l\'ouverture', (tester) async {
    final routeur = await _monte(tester);
    expect(emplacementAffiche(routeur), '/home');
  });

  testWidgets('un écran de détail ouvert par push est celui du dessus',
      (tester) async {
    final routeur = await _monte(tester);

    unawaited(routeur.push('/feed/abc'));
    await tester.pumpAndSettle();

    expect(emplacementAffiche(routeur), '/feed/abc');
  });

  testWidgets('empilés, puis dépilés : toujours celui du dessus',
      (tester) async {
    final routeur = await _monte(tester);

    unawaited(routeur.push('/feed/abc'));
    await tester.pumpAndSettle();
    unawaited(routeur.push('/events/xyz'));
    await tester.pumpAndSettle();
    expect(emplacementAffiche(routeur), '/events/xyz');

    routeur.pop();
    await tester.pumpAndSettle();
    expect(emplacementAffiche(routeur), '/feed/abc');

    routeur.pop();
    await tester.pumpAndSettle();
    expect(emplacementAffiche(routeur), '/home');
  });

  testWidgets('un lien profond (go) donne aussi le bon chemin', (tester) async {
    final routeur = await _monte(tester);

    routeur.go('/events/xyz');
    await tester.pumpAndSettle();

    expect(emplacementAffiche(routeur), '/events/xyz');
  });

  testWidgets('changer d\'onglet dans la coquille', (tester) async {
    final routeur = await _monte(tester);

    routeur.go('/feed');
    await tester.pumpAndSettle();

    expect(emplacementAffiche(routeur), '/feed');
  });

  testWidgets('la requête n\'entre pas dans le chemin', (tester) async {
    final routeur = await _monte(tester);

    unawaited(routeur.push('/feed/abc?depuis=notification'));
    await tester.pumpAndSettle();

    expect(emplacementAffiche(routeur), '/feed/abc');
  });

  testWidgets('POURQUOI ce n\'est pas `currentConfiguration.uri`',
      (tester) async {
    final routeur = await _monte(tester);

    unawaited(routeur.push('/feed/abc'));
    await tester.pumpAndSettle();

    // Observé sur go_router 14.8.1 : après un `push`, `uri` rend l'écran de
    // DESSOUS. C'est ce que l'app fait pour presque tous ses détails, et lire
    // `uri` aurait fait croire qu'on est encore sur l'onglet.
    //
    // Si cette ligne tombe après une montée de go_router : le piège est
    // corrigé, `emplacementAffiche` peut se simplifier — rien d'autre ne casse.
    expect(routeur.routerDelegate.currentConfiguration.uri.path, '/home');
    expect(emplacementAffiche(routeur), '/feed/abc');
  });
}
