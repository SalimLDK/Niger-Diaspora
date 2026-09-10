import 'package:diaspo_niger/core/router/retour_systeme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Le geste « retour » d'Android sur une route atteinte par lien profond.
///
/// Mesuré sur SM A515F le 2026-09-09 : `diasponiger:///services` puis retour
/// système renvoyait au **lanceur**. La route est seule dans la pile — le
/// routeur rejoue la destination par un `go`, qui remplace la pile — donc
/// personne ne traite le geste et il descend jusqu'à Android.
///
/// Ce que ce test tient, c'est l'arbitrage : on ne rattrape le geste que
/// lorsque **personne d'autre** ne l'a traité, et jamais sur un écran d'où
/// quitter l'application est le bon comportement.
void main() {
  GoRouter construireRouteur(WidgetTester tester) {
    final routeur = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const Text('accueil')),
        GoRoute(path: '/groups', builder: (_, __) => const Text('groupes')),
        GoRoute(path: '/services', builder: (_, __) => const Text('services')),
        GoRoute(path: '/auth/login', builder: (_, __) => const Text('login')),
        GoRoute(
          path: '/conversation',
          builder:
              (_, __) => PopScope(
                canPop: false,
                onPopInvokedWithResult: (didPop, _) {},
                child: const Text('discussion'),
              ),
        ),
      ],
    );
    addTearDown(routeur.dispose);
    return routeur;
  }

  Future<RetourSystemeVersAccueil> monter(
    WidgetTester tester,
    GoRouter routeur,
  ) async {
    final dispatcher = RetourSystemeVersAccueil(routeur);
    await tester.pumpWidget(
      MaterialApp.router(
        routerDelegate: routeur.routerDelegate,
        routeInformationParser: routeur.routeInformationParser,
        routeInformationProvider: routeur.routeInformationProvider,
        backButtonDispatcher: dispatcher,
      ),
    );
    await tester.pumpAndSettle();
    return dispatcher;
  }

  testWidgets('lien profond : le retour système entre dans l\'app, il n\'en '
      'sort pas', (tester) async {
    final routeur = construireRouteur(tester);
    final dispatcher = await monter(tester, routeur);

    // `go` et non `push` : c'est ce que fait le routeur quand il rejoue la
    // destination d'un lien profond, et c'est ce qui vide la pile.
    routeur.go('/services');
    await tester.pumpAndSettle();
    expect(find.text('services'), findsOneWidget);

    expect(await dispatcher.didPopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('accueil'), findsOneWidget);
  });

  testWidgets('navigation interne : le retour système dépile, il ne saute pas '
      'à l\'accueil', (tester) async {
    final routeur = construireRouteur(tester);
    final dispatcher = await monter(tester, routeur);

    routeur.go('/groups');
    await tester.pumpAndSettle();
    routeur.push('/services');
    await tester.pumpAndSettle();
    expect(find.text('services'), findsOneWidget);

    expect(await dispatcher.didPopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('groupes'), findsOneWidget);
  });

  testWidgets('onglet racine : quitter l\'application reste le bon geste', (
    tester,
  ) async {
    final routeur = construireRouteur(tester);
    final dispatcher = await monter(tester, routeur);

    expect(find.text('accueil'), findsOneWidget);
    // `false` = personne ne traite, Android reprend la main et sort de l'app.
    expect(await dispatcher.didPopRoute(), isFalse);
  });

  testWidgets('parcours de connexion : sortir aussi, sinon le retour paraît '
      'mort', (tester) async {
    final routeur = construireRouteur(tester);
    final dispatcher = await monter(tester, routeur);

    routeur.go('/auth/login');
    await tester.pumpAndSettle();

    // Renvoyer sur `/home` depuis la connexion ne ferait que rebondir sur la
    // garde du routeur : l'utilisateur appuierait sans que rien ne bouge.
    expect(await dispatcher.didPopRoute(), isFalse);
  });

  testWidgets('un écran qui porte son PopScope garde la main', (tester) async {
    final routeur = construireRouteur(tester);
    final dispatcher = await monter(tester, routeur);

    routeur.go('/conversation');
    await tester.pumpAndSettle();

    // `popRoute()` passe par `maybePop()`, qui consulte le `PopScope` : le
    // geste est déclaré traité, et on ne doit surtout pas doubler d'un `go`.
    expect(await dispatcher.didPopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('discussion'), findsOneWidget);
  });

  // La pièce qu'on oublie : réclamer le geste auprès d'Android. Avec
  // `android:enableOnBackInvokedCallback="true"` (obligatoire à partir de
  // targetSdk 36), le retour n'atteint Flutter que si le framework s'est
  // annoncé preneur. La première version de ce correctif branchait le
  // dispatcher sans ça : tests verts, et le retour quittait toujours l'app
  // sur SM A515F.
  group("réclamation du geste auprès d'Android", () {
    late List<bool> reclame;

    setUp(() {
      reclame = <bool>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (appel) async {
            if (appel.method == 'SystemNavigator.setFrameworkHandlesBack') {
              reclame.add(appel.arguments as bool);
            }
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    testWidgets('sur un écran de lien profond, on réclame le geste', (
      tester,
    ) async {
      final routeur = construireRouteur(tester);
      final dispatcher = await monter(tester, routeur);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

      routeur.go('/services');
      await tester.pumpAndSettle();
      reclame.clear();

      // Ce que le `Navigator` annonce : « rien à dépiler ».
      dispatcher.surNavigation(
        const NavigationNotification(canHandlePop: false),
      );
      expect(reclame, [true]);
    });

    testWidgets('sur un onglet racine, on laisse Android sortir', (
      tester,
    ) async {
      final routeur = construireRouteur(tester);
      final dispatcher = await monter(tester, routeur);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      reclame.clear();

      dispatcher.surNavigation(
        const NavigationNotification(canHandlePop: false),
      );
      expect(reclame, [false]);
    });

    testWidgets('ce que le Navigator sait déjà traiter passe intact', (
      tester,
    ) async {
      final routeur = construireRouteur(tester);
      final dispatcher = await monter(tester, routeur);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      reclame.clear();

      dispatcher.surNavigation(const NavigationNotification(canHandlePop: true));
      expect(reclame, [true]);
    });
  });
}
