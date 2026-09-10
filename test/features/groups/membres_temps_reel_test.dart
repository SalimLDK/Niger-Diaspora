import 'dart:async';

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
import 'package:diaspo_niger/features/profile/domain/entities/profile_entity.dart';
import 'package:diaspo_niger/features/profile/presentation/providers/profile_provider.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

/// L'écran des membres suit-il les arrivées et les départs pendant qu'il est
/// ouvert ?
///
/// Il ne le faisait pas, pour deux raisons superposées :
///
/// * côté base, ni `groups` ni `group_members` n'étaient dans la publication
///   `supabase_realtime` — le « stream » de la fiche groupe ne faisait que son
///   chargement initial (migration
///   `20260909210000_realtime_groupes_et_appartenance.sql`) ;
/// * côté app, cet écran ne lisait même pas ce flux : il affichait le
///   `GroupEntity` transmis par la navigation, un instantané figé au moment du
///   tap, sinon une lecture one-shot.
///
/// Résultat visible : un admin acceptait une demande d'adhésion, la personne
/// n'apparaissait chez personne d'autre — ni le compte, ni la liste — tant que
/// l'écran n'était pas refermé et rouvert. Idem à l'inverse quand quelqu'un
/// quittait le groupe.
///
/// Le test ne peut pas vérifier la partie base (elle vit dans Postgres) ; il
/// verrouille la partie app : le flux fait autorité, et une émission suffit à
/// changer la liste sans aucune interaction.
void main() {
  const groupeAvantAcceptation = GroupEntity(
    id: 'grp-1',
    name: 'Diaspora Paris',
    description: 'Le groupe',
    creatorId: 'alice',
    adminIds: ['alice'],
    memberIds: ['alice'],
  );

  const groupeApresAcceptation = GroupEntity(
    id: 'grp-1',
    name: 'Diaspora Paris',
    description: 'Le groupe',
    creatorId: 'alice',
    adminIds: ['alice'],
    memberIds: ['alice', 'bachir'],
  );

  const moi = UserEntity(id: 'alice', email: 'alice@example.com');

  const profils = {
    'alice': ProfileEntity(id: 'alice', displayName: 'Alice Amadou'),
    'bachir': ProfileEntity(id: 'bachir', displayName: 'Bachir Boubacar'),
  };

  Widget sousTest(
    Stream<GroupEntity?> flux, {
    required GroupEntity? groupeTransmis,
  }) {
    return ProviderScope(
      overrides: [
        currentUserAsyncProvider.overrideWith((ref) => Stream.value(moi)),
        currentUserProvider.overrideWith((ref) => Stream.value(moi)),
        groupStreamProvider('grp-1').overrideWith((ref) => flux),
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
        home: GroupMembersScreen(
          groupId: 'grp-1',
          group: groupeTransmis,
        ),
      ),
    );
  }

  testWidgets(
    "un membre accepté apparaît sans quitter l'écran",
    (tester) async {
      final flux = StreamController<GroupEntity?>();
      addTearDown(flux.close);

      // L'écran est ouvert depuis une liste : la navigation lui transmet
      // l'état du groupe AVANT l'acceptation. C'est ce paramètre qui gagnait
      // sur tout le reste.
      await tester.pumpWidget(
        sousTest(flux.stream, groupeTransmis: groupeAvantAcceptation),
      );
      flux.add(groupeAvantAcceptation);
      await tester.pumpAndSettle();

      expect(find.text('Alice Amadou'), findsOneWidget);
      expect(find.text('Bachir Boubacar'), findsNothing);

      // Un admin accepte Bachir depuis son propre téléphone : côté serveur,
      // une ligne de plus dans `group_members`. Ici, une émission du flux.
      flux.add(groupeApresAcceptation);
      await tester.pumpAndSettle();

      expect(find.text('Bachir Boubacar'), findsOneWidget);
    },
  );

  testWidgets(
    "un membre parti disparaît sans quitter l'écran",
    (tester) async {
      final flux = StreamController<GroupEntity?>();
      addTearDown(flux.close);

      await tester.pumpWidget(
        sousTest(flux.stream, groupeTransmis: groupeApresAcceptation),
      );
      flux.add(groupeApresAcceptation);
      await tester.pumpAndSettle();

      expect(find.text('Bachir Boubacar'), findsOneWidget);

      flux.add(groupeAvantAcceptation);
      await tester.pumpAndSettle();

      expect(find.text('Bachir Boubacar'), findsNothing);
      expect(find.text('Alice Amadou'), findsOneWidget);
    },
  );

  testWidgets(
    "sans rien du flux, le groupe transmis reste affiché",
    (tester) async {
      // Le repli compte autant que le correctif : le flux met un aller-retour
      // réseau à répondre, et hors ligne il ne répond pas du tout. Le faire
      // passer devant `group` ne doit pas transformer ces cas en écran vide.
      final flux = StreamController<GroupEntity?>();
      addTearDown(flux.close);

      await tester.pumpWidget(
        sousTest(flux.stream, groupeTransmis: groupeApresAcceptation),
      );
      await tester.pumpAndSettle();

      expect(find.text('Alice Amadou'), findsOneWidget);
      expect(find.text('Bachir Boubacar'), findsOneWidget);
    },
  );
}
