import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:diaspo_niger/core/theme/app_theme.dart';
import 'package:diaspo_niger/features/auth/domain/entities/user_entity.dart';
import 'package:diaspo_niger/features/auth/presentation/providers/auth_provider.dart';
import 'package:diaspo_niger/features/events/domain/entities/event_entity.dart';
import 'package:diaspo_niger/features/events/presentation/providers/event_by_id_provider.dart';
import 'package:diaspo_niger/features/events/presentation/screens/edit_event_screen.dart';
import 'package:diaspo_niger/features/events/presentation/screens/event_edit_routes.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

/// `/events/:eventId/edit` atteinte sans l'entité en main.
///
/// La route faisait `state.extra as EventEntity` — vers un type **non
/// nullable**. Par lien profond ou notification, `extra` est nul par
/// construction : le cast levait un `TypeError` avant le montage de l'écran.
///
/// Le correctif ne se limite pas à résoudre l'identifiant. `EditEventScreen`
/// n'a **aucune** vérification d'autorisation : elle faisait confiance à son
/// appelant, dont le bouton est masqué derrière `isOrganizer`. Résoudre
/// l'identifiant sans garde aurait donc ouvert le formulaire d'édition de
/// l'événement de n'importe qui — le plantage, lui, fermait la porte. La
/// garde est le vrai sujet de ce fichier.
void main() {
  final event = EventEntity(
    id: 'evt-1',
    title: 'Retrouvailles',
    description: 'Une soirée',
    startDate: DateTime(2026, 10, 12, 19),
    location: 'Paris',
    organizerId: 'organisateur',
  );

  const organisateur = UserEntity(id: 'organisateur');
  const quelquunDautre = UserEntity(id: 'intrus');

  Widget boot({
    required UserEntity? moi,
    required EventEntity? resolu,
    EventEntity? extra,
  }) {
    final router = GoRouter(
      initialLocation: '/events/${event.id}/edit',
      routes: [
        GoRoute(
          path: '/events',
          builder: (_, __) => const Scaffold(body: Text('liste')),
        ),
        GoRoute(
          path: '/events/:eventId',
          builder: (_, __) => const Scaffold(body: Text('fiche')),
        ),
        GoRoute(
          path: '/events/:eventId/edit',
          builder:
              (context, state) => EventEditRoute(
                eventId: state.pathParameters['eventId']!,
                initialEvent: extra,
              ),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(moi)),
        eventByIdProvider(event.id).overrideWith((ref) async => resolu),
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

  testWidgets('L\'organisateur atteint le formulaire par l\'identifiant seul', (
    tester,
  ) async {
    await tester.pumpWidget(boot(moi: organisateur, resolu: event));
    await tester.pumpAndSettle();

    // Le test de fond : plus de TypeError là où le cast en levait un.
    expect(tester.takeException(), isNull);
    expect(find.byType(EditEventScreen), findsOneWidget);
  });

  testWidgets('Quelqu\'un d\'autre n\'obtient pas le formulaire', (
    tester,
  ) async {
    await tester.pumpWidget(boot(moi: quelquunDautre, resolu: event));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(EditEventScreen), findsNothing);
    expect(find.text('Modification réservée à l\'organisateur'), findsOneWidget);
  });

  testWidgets('Sans session non plus', (tester) async {
    await tester.pumpWidget(boot(moi: null, resolu: event));
    await tester.pumpAndSettle();

    expect(find.byType(EditEventScreen), findsNothing);
    expect(find.text('Modification réservée à l\'organisateur'), findsOneWidget);
  });

  testWidgets(
    'La garde vaut aussi pour l\'entité passée par extra',
    (tester) async {
      // Sinon un appelant interne mal gardé la contournerait : `extra` court-
      // circuite la résolution, il ne doit pas court-circuiter l'autorisation.
      await tester.pumpWidget(
        boot(moi: quelquunDautre, resolu: null, extra: event),
      );
      await tester.pumpAndSettle();

      expect(find.byType(EditEventScreen), findsNothing);
      expect(
        find.text('Modification réservée à l\'organisateur'),
        findsOneWidget,
      );
    },
  );

  testWidgets('Événement irrésolu : un état nommé, et une sortie', (
    tester,
  ) async {
    await tester.pumpWidget(boot(moi: organisateur, resolu: null));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Chargement impossible'), findsOneWidget);

    final sortie = find.text('Retour aux événements');
    expect(sortie, findsOneWidget);
    await tester.tap(sortie);
    await tester.pumpAndSettle();
    expect(find.text('liste'), findsOneWidget);
  });
}
