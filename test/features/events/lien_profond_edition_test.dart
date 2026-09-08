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
import 'package:diaspo_niger/features/events/presentation/screens/event_recap_screen.dart';
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

  /// `sessionEnVol` : `currentUserProvider` n'a ni valeur ni erreur, comme au
  /// demarrage a froid. `moi` est alors ignore.
  Widget boot({
    required UserEntity? moi,
    required EventEntity? resolu,
    EventEntity? extra,
    bool recap = false,
    bool sessionEnVol = false,
  }) {
    final router = GoRouter(
      initialLocation: '/events/${event.id}/${recap ? 'recap' : 'edit'}',
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
        GoRoute(
          path: '/events/:eventId/recap',
          builder:
              (context, state) => EventRecapRoute(
                eventId: state.pathParameters['eventId']!,
                initialEvent: extra,
              ),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        currentUserProvider.overrideWith(
          (ref) =>
              sessionEnVol
                  ? const Stream<UserEntity?>.empty()
                  : Stream.value(moi),
        ),
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

  testWidgets("Récap : l'organisateur atteint le formulaire", (tester) async {
    await tester.pumpWidget(
      boot(moi: organisateur, resolu: event, recap: true),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(EventRecapScreen), findsOneWidget);
  });

  testWidgets("Récap : quelqu'un d'autre ne peut pas écrire", (
    tester,
  ) async {
    // Ce n'était pas gardé du tout : l'accueil ouvrait ce formulaire à qui
    // voulait dès qu'un événement passé avait des photos, donc n'importe qui
    // pouvait réécrire le récapitulatif de l'événement d'autrui.
    await tester.pumpWidget(
      boot(moi: quelquunDautre, resolu: event, recap: true),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(EventRecapScreen), findsNothing);
    expect(find.text("Récap réservé à l'organisateur"), findsOneWidget);
  });

  testWidgets('Récap : la sortie mène à la fiche, où les photos sont visibles', (
    tester,
  ) async {
    // Le refus ne doit pas couper l'accès à ce qui était consultable :
    // `EventDetailScreen` affiche description et grille de photos du récap.
    await tester.pumpWidget(
      boot(moi: quelquunDautre, resolu: event, recap: true),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text("Voir l'événement"));
    await tester.pumpAndSettle();
    expect(find.text('fiche'), findsOneWidget);
  });

  testWidgets("Récap : la garde vaut aussi pour l'entité passée par extra", (
    tester,
  ) async {
    await tester.pumpWidget(
      boot(moi: quelquunDautre, resolu: null, extra: event, recap: true),
    );
    await tester.pumpAndSettle();

    expect(find.byType(EventRecapScreen), findsNothing);
    expect(find.text("Récap réservé à l'organisateur"), findsOneWidget);
  });

  for (final recap in [false, true]) {
    final quoi = recap ? 'Récap' : 'Édition';
    testWidgets(
      "$quoi : session pas encore chargée n'est pas un refus",
      (tester) async {
        // Le defaut vu sur SM A515F le 2026-09-08 : la garde tranchait avant
        // que `currentUserProvider` n'ait emis, et opposait « reserve a
        // l'organisateur » **a l'organisateur**. Intermittent — le meme lien
        // ouvrait le formulaire une minute plus tot — et sans rien a
        // reessayer une fois le refus affiche.
        //
        // `moi` est l'organisateur : si la session etait attendue comme il
        // faut, on verrait le formulaire ; ce qu'on exige ici, au minimum,
        // c'est de ne pas voir d'accusation.
        await tester.pumpWidget(
          boot(
            moi: organisateur,
            resolu: event,
            recap: recap,
            sessionEnVol: true,
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(
          find.textContaining('réservé'),
          findsNothing,
          reason: "on ignore encore qui regarde : on ne peut pas refuser",
        );
        expect(
          find.textContaining('réservée'),
          findsNothing,
          reason: "on ignore encore qui regarde : on ne peut pas refuser",
        );
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      },
    );
  }
}
