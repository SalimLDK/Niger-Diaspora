import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:diaspo_niger/core/theme/app_theme.dart';
import 'package:diaspo_niger/features/admin/domain/enums/admin_enums.dart';
import 'package:diaspo_niger/features/auth/domain/entities/user_entity.dart';
import 'package:diaspo_niger/features/auth/presentation/providers/auth_provider.dart';
import 'package:diaspo_niger/features/groups/domain/entities/group_entity.dart';
import 'package:diaspo_niger/features/groups/presentation/providers/group_provider.dart';
import 'package:diaspo_niger/features/groups/presentation/screens/edit_group_screen.dart';
import 'package:diaspo_niger/features/groups/presentation/screens/group_edit_route.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

/// `/groups/:groupId/edit` atteinte sans l'entité en main.
///
/// La route faisait `state.extra as GroupEntity` — vers un type **non
/// nullable** — donc `TypeError` par lien profond et par notification.
///
/// Comme pour l'événement, résoudre l'identifiant ne suffit pas :
/// `EditGroupScreen` n'a aucune vérification d'autorisation, elle faisait
/// confiance au menu de la fiche, masqué derrière `isCreator || isAdmin`.
/// La garde est donc portée par la route, repli superAdmin compris.
void main() {
  const groupe = GroupEntity(
    id: 'grp-1',
    name: 'Diaspora Paris',
    description: 'Le groupe',
    creatorId: 'createur',
    adminIds: ['createur', 'admin-2'],
    memberIds: ['createur', 'admin-2', 'membre'],
  );

  const officiel = GroupEntity(
    id: 'grp-1',
    name: 'Groupe officiel',
    description: 'Officiel',
    creatorId: 'plateforme',
    isOfficial: true,
  );

  /// `sessionEnVol` : `currentUserProvider` n'a ni valeur ni erreur, comme au
  /// demarrage a froid. `moi` est alors ignore.
  Widget boot({
    required UserEntity? moi,
    required GroupEntity? resolu,
    GroupEntity? extra,
    bool sessionEnVol = false,
  }) {
    final router = GoRouter(
      initialLocation: '/groups/grp-1/edit',
      routes: [
        GoRoute(
          path: '/groups',
          builder: (_, __) => const Scaffold(body: Text('liste')),
        ),
        GoRoute(
          path: '/groups/:groupId',
          builder: (_, __) => const Scaffold(body: Text('fiche')),
        ),
        GoRoute(
          path: '/groups/:groupId/edit',
          builder:
              (context, state) => GroupEditRoute(
                groupId: state.pathParameters['groupId']!,
                initialGroup: extra,
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
        groupByIdProvider('grp-1').overrideWith((ref) async => resolu),
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

  testWidgets('Le créateur atteint le formulaire par l\'identifiant seul', (
    tester,
  ) async {
    await tester.pumpWidget(
      boot(moi: const UserEntity(id: 'createur'), resolu: groupe),
    );
    await tester.pumpAndSettle();

    // Le test de fond : plus de TypeError là où le cast en levait un.
    expect(tester.takeException(), isNull);
    expect(find.byType(EditGroupScreen), findsOneWidget);
  });

  testWidgets('Un administrateur aussi', (tester) async {
    await tester.pumpWidget(
      boot(moi: const UserEntity(id: 'admin-2'), resolu: groupe),
    );
    await tester.pumpAndSettle();
    expect(find.byType(EditGroupScreen), findsOneWidget);
  });

  testWidgets('Un simple membre, non', (tester) async {
    await tester.pumpWidget(
      boot(moi: const UserEntity(id: 'membre'), resolu: groupe),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(EditGroupScreen), findsNothing);
    expect(
      find.text('Modification réservée aux administrateurs'),
      findsOneWidget,
    );
  });

  testWidgets('La garde vaut aussi pour l\'entité passée par extra', (
    tester,
  ) async {
    await tester.pumpWidget(
      boot(moi: const UserEntity(id: 'membre'), resolu: null, extra: groupe),
    );
    await tester.pumpAndSettle();

    expect(find.byType(EditGroupScreen), findsNothing);
    expect(
      find.text('Modification réservée aux administrateurs'),
      findsOneWidget,
    );
  });

  testWidgets('Un superAdmin gère un groupe officiel sans y être admin', (
    tester,
  ) async {
    // Le repli que porte déjà la fiche de groupe : sur un groupe officiel,
    // RLS accepte l'écriture d'un superAdmin qui n'a pas de ligne
    // group_members. Sans ce repli ici, l'UI refuserait ce que la base
    // accepte.
    await tester.pumpWidget(
      boot(
        moi: const UserEntity(id: 'moi', adminRole: AdminRole.superAdmin),
        resolu: officiel,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(EditGroupScreen), findsOneWidget);
  });

  testWidgets('Groupe irrésolu : un état nommé, et une sortie', (tester) async {
    await tester.pumpWidget(
      boot(moi: const UserEntity(id: 'createur'), resolu: null),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Chargement impossible'), findsOneWidget);

    final sortie = find.text('Retour aux groupes');
    expect(sortie, findsOneWidget);
    await tester.tap(sortie);
    await tester.pumpAndSettle();
    expect(find.text('liste'), findsOneWidget);
  });

  testWidgets("Session pas encore chargée n'est pas un refus", (tester) async {
    // Meme defaut que la route jumelle des evenements : la garde tranchait
    // avant que `currentUserProvider` n'ait emis, et opposait « reserve aux
    // administrateurs » a un administrateur.
    await tester.pumpWidget(
      boot(
        moi: const UserEntity(id: 'createur'),
        resolu: groupe,
        sessionEnVol: true,
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(
      find.textContaining('réservée'),
      findsNothing,
      reason: "on ignore encore qui regarde : on ne peut pas refuser",
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
