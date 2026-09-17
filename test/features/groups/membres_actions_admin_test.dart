import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/core/theme/app_theme.dart';
import 'package:diaspo_niger/features/auth/domain/entities/user_entity.dart';
import 'package:diaspo_niger/features/auth/presentation/providers/auth_provider.dart';
import 'package:diaspo_niger/features/groups/domain/entities/group_entity.dart';
import 'package:diaspo_niger/features/groups/presentation/providers/group_provider.dart';
import 'package:diaspo_niger/features/groups/presentation/screens/group_members_screen.dart';
import 'package:diaspo_niger/features/messages/presentation/providers/media_gallery_provider.dart';
import 'package:diaspo_niger/features/profile/domain/entities/profile_entity.dart';
import 'package:diaspo_niger/features/profile/presentation/providers/profile_provider.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

/// Les trois actions d'un admin sur un membre — « Promouvoir Admin »,
/// « Retirer Admin », « Retirer du groupe » — n'apparaissaient pour personne.
///
/// Elles exigent la conversation du groupe, et la route
/// `/groups/:groupId/members` ne la transmettait pas : depuis sa création
/// (décembre 2025), le menu d'un admin ne proposait que le rôle modérateur.
/// Constaté le 2026-09-17 en préparant la passe appareil des notices de
/// groupe : le compilateur avait retiré de l'app jusqu'aux appels des RPC
/// `exclure_du_groupe`, `nommer_admin_du_groupe` et `retirer_admin_du_groupe`.
///
/// L'écran est construit ici EXACTEMENT comme la route le construit — sans
/// `conversationId` — et doit retrouver la conversation lui-même.
void main() {
  const groupe = GroupEntity(
    id: 'grp-1',
    name: 'Groupe de test',
    description: 'Le groupe',
    creatorId: 'alice',
    adminIds: ['alice'],
    memberIds: ['alice', 'bachir'],
  );

  const alice = UserEntity(id: 'alice', email: 'alice@example.com');
  const bachir = UserEntity(id: 'bachir', email: 'bachir@example.com');

  const profils = {
    'alice': ProfileEntity(id: 'alice', displayName: 'Alice Amadou'),
    'bachir': ProfileEntity(id: 'bachir', displayName: 'Bachir Boubacar'),
  };

  late int recherchesDeConversation;

  setUp(() => recherchesDeConversation = 0);

  Widget sousTest({
    required UserEntity moi,
    required String? conversationTrouvee,
  }) {
    return ProviderScope(
      overrides: [
        currentUserAsyncProvider.overrideWith((ref) => Stream.value(moi)),
        currentUserProvider.overrideWith((ref) => Stream.value(moi)),
        groupStreamProvider('grp-1').overrideWith((ref) => Stream.value(groupe)),
        groupConversationIdProvider('grp-1').overrideWith((ref) async {
          recherchesDeConversation++;
          return conversationTrouvee;
        }),
        for (final entry in profils.entries)
          userStreamProvider(entry.key).overrideWith(
            (ref) => Stream.value(entry.value),
          ),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('fr'),
        // Comme `app_router.dart` : ni `conversationId`, ni rien d'autre.
        home: const GroupMembersScreen(groupId: 'grp-1', group: groupe),
      ),
    );
  }

  testWidgets(
    "un admin voit promouvoir et retirer, sans que la route passe la conversation",
    (tester) async {
      await tester.pumpWidget(
        sousTest(moi: alice, conversationTrouvee: 'conv-1'),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Bachir Boubacar'));
      await tester.pumpAndSettle();

      expect(find.text('Promouvoir Admin'), findsOneWidget);
      expect(find.text('Retirer du groupe'), findsOneWidget);
    },
  );

  testWidgets(
    "sans conversation de groupe, seul le rôle modérateur reste proposé",
    (tester) async {
      // Groupe dont la discussion n'a jamais été créée : il n'y a rien à
      // exclure de `participant_ids`, et aucune notice à poser.
      await tester.pumpWidget(sousTest(moi: alice, conversationTrouvee: null));
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Bachir Boubacar'));
      await tester.pumpAndSettle();

      expect(find.text('Promouvoir modérateur'), findsOneWidget);
      expect(find.text('Promouvoir Admin'), findsNothing);
      expect(find.text('Retirer du groupe'), findsNothing);
    },
  );

  testWidgets(
    "un simple membre ne déclenche pas la recherche de la conversation",
    (tester) async {
      // La recherche passe par `join_group_conversation`, qui rattache
      // l'appelant à la discussion : on ne la lance pas pour qui ne peut rien
      // faire de la réponse.
      await tester.pumpWidget(
        sousTest(moi: bachir, conversationTrouvee: 'conv-1'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Alice Amadou'), findsOneWidget);
      expect(recherchesDeConversation, 0);
    },
  );
}
