import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:diaspo_niger/core/theme/app_theme.dart';
import 'package:diaspo_niger/features/auth/domain/entities/user_entity.dart';
import 'package:diaspo_niger/features/auth/presentation/providers/auth_provider.dart';
import 'package:diaspo_niger/features/events/domain/entities/event_entity.dart';
import 'package:diaspo_niger/features/events/presentation/providers/event_provider.dart';
import 'package:diaspo_niger/features/events/presentation/screens/event_detail_screen.dart';
import 'package:diaspo_niger/features/groups/domain/entities/group_entity.dart';
import 'package:diaspo_niger/features/groups/presentation/providers/group_provider.dart';
import 'package:diaspo_niger/features/groups/presentation/screens/group_detail_screen.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

/// Ce qu'un lien profond donne quand la cible ne se charge pas.
///
/// Les deux écrans d'arrivée résolvent leur entité eux-mêmes (l'identifiant
/// est tout ce qu'un lien apporte) et retombaient sur un état muet :
///
/// - `EventDetailScreen` ne regardait que `valueOrNull`. Un échec rend `null`
///   exactement comme un chargement en cours → roue infinie, mesurée encore
///   présente après 75 s sur `/events/<id>` le 2026-09-09 ;
/// - `GroupDetailScreen` affichait « Erreur de chargement » et un
///   « Réessayer » sur le refus de lecture d'un groupe privé, qui ne peut par
///   construction jamais aboutir (PGRST116 : la RLS ne rend aucune ligne).
class _EvenementEnEchec extends EventDetailNotifier {
  @override
  AsyncValue<EventEntity?> build() =>
      AsyncValue.error('panne reseau', StackTrace.empty);

  // L'ecran appelle `loadEvent` au premier frame ; la vraie implementation
  // irait chercher le depot, donc Firebase, absent du banc.
  @override
  Future<void> loadEvent(String eventId) async {}
}

class _EvenementEnVol extends EventDetailNotifier {
  @override
  AsyncValue<EventEntity?> build() => const AsyncValue.loading();

  @override
  Future<void> loadEvent(String eventId) async {}
}

class _GroupeRefuse extends GroupDetailNotifier {
  @override
  AsyncValue<GroupEntity?> build() => AsyncValue.error(
    'PostgrestException(message: JSON object requested, multiple (or no) rows '
    'returned, code: PGRST116, details: The result contains 0 rows, hint: null)',
    StackTrace.empty,
  );

  @override
  Future<void> loadGroup(String groupId) async {}
}

class _GroupeEnPanne extends GroupDetailNotifier {
  @override
  AsyncValue<GroupEntity?> build() =>
      AsyncValue.error('panne reseau', StackTrace.empty);

  @override
  Future<void> loadGroup(String groupId) async {}
}

void main() {
  const moi = UserEntity(id: 'moi');

  Widget boot({required String route, required List<Override> overrides}) {
    final router = GoRouter(
      initialLocation: route,
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, __) => const Scaffold(body: Text('accueil')),
        ),
        GoRoute(
          path: '/events/:eventId',
          builder: (_, state) =>
              EventDetailScreen(eventId: state.pathParameters['eventId']!),
        ),
        GoRoute(
          path: '/groups/:groupId',
          builder: (_, state) =>
              GroupDetailScreen(groupId: state.pathParameters['groupId']!),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(moi)),
        ...overrides,
      ],
      child: MaterialApp.router(
        theme: AppTheme.lightTheme,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('fr'),
        routerConfig: router,
      ),
    );
  }

  testWidgets('Événement en échec : un message, pas une roue éternelle', (
    tester,
  ) async {
    await tester.pumpWidget(
      boot(
        route: '/events/evt-1',
        overrides: [
          eventDetailNotifierProvider.overrideWith(_EvenementEnEchec.new),
        ],
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Erreur de chargement'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
  });

  testWidgets('Événement encore en vol : la roue reste légitime', (
    tester,
  ) async {
    await tester.pumpWidget(
      boot(
        route: '/events/evt-1',
        overrides: [
          eventDetailNotifierProvider.overrideWith(_EvenementEnVol.new),
        ],
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Erreur de chargement'), findsNothing);
  });

  testWidgets('Groupe privé refusé : on le dit, sans proposer de réessayer', (
    tester,
  ) async {
    await tester.pumpWidget(
      boot(
        route: '/groups/g-1',
        overrides: [
          groupDetailNotifierProvider.overrideWith(_GroupeRefuse.new),
          groupStreamProvider('g-1').overrideWith(
            (ref) => Stream<GroupEntity?>.value(null),
          ),
        ],
      ),
    );
    await tester.pump();

    expect(find.text('Ce groupe est privé ou n\'existe plus.'), findsOneWidget);
    expect(find.text('Réessayer'), findsNothing);
    expect(find.text('Retour'), findsOneWidget);
  });

  testWidgets('Vraie panne sur un groupe : « Réessayer » reste offert', (
    tester,
  ) async {
    await tester.pumpWidget(
      boot(
        route: '/groups/g-1',
        overrides: [
          groupDetailNotifierProvider.overrideWith(_GroupeEnPanne.new),
          groupStreamProvider('g-1').overrideWith(
            (ref) => Stream<GroupEntity?>.value(null),
          ),
        ],
      ),
    );
    await tester.pump();

    expect(find.text('Erreur de chargement'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
  });

  testWidgets('Retour depuis une pile vide : l\'accueil, pas un écran noir', (
    tester,
  ) async {
    await tester.pumpWidget(
      boot(
        route: '/events/evt-1',
        overrides: [
          eventDetailNotifierProvider.overrideWith(_EvenementEnEchec.new),
        ],
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.text('accueil'), findsOneWidget);
  });
}
