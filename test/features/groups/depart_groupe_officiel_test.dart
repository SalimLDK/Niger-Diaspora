import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/core/theme/app_theme.dart';
import 'package:diaspo_niger/features/groups/data/datasources/official_group_departure_datasource.dart';
import 'package:diaspo_niger/features/groups/presentation/providers/official_group_departure_provider.dart';
import 'package:diaspo_niger/features/groups/presentation/widgets/official_group_departure_card.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

/// Quitter le groupe officiel de l'ancien pays : jamais sans l'accord de
/// l'utilisateur.
///
/// Consigne de Salim (2026-09-13) : après un changement de pays, quitter
/// l'ancien groupe officiel « après 6 mois, avec avertissement et
/// consentement ». La base ne fait que proposer (tâche quotidienne +
/// notification) ; le départ passe uniquement par `repondre_depart_groupe_officiel`,
/// appelée depuis cette carte. Ces tests verrouillent le côté consentement :
/// rien n'est envoyé sans un appui, « Quitter » redemande confirmation, et un
/// échec ne fait croire à rien.
class _FakeDataSource extends OfficialGroupDepartureDataSource {
  OfficialGroupDeparture? pending;
  bool fail = false;
  final List<bool> answers = [];

  _FakeDataSource(this.pending);

  @override
  Future<OfficialGroupDeparture?> pendingFor(String groupId) async => pending;

  @override
  Future<String?> answer(String groupId, {required bool leave}) async {
    answers.add(leave);
    if (fail) throw Exception('réseau');
    pending = null;
    return leave ? 'quitte' : 'reste';
  }
}

void main() {
  final proposition = OfficialGroupDeparture(
    groupId: 'grp-cv',
    formerCountry: 'Cap-Vert',
    changedAt: DateTime(2026, 9, 11),
  );

  late int departs;

  Widget boot(_FakeDataSource source) {
    departs = 0;
    return ProviderScope(
      overrides: [
        officialGroupDepartureDataSourceProvider.overrideWithValue(source),
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
        home: Scaffold(
          body: SingleChildScrollView(
            child: OfficialGroupDepartureCard(
              groupId: 'grp-cv',
              onLeft: () => departs++,
            ),
          ),
        ),
      ),
    );
  }

  group('côté base : seule la réponse de l\'utilisateur fait sortir', () {
    // Les migrations, dans l'ordre où `db push` les applique.
    final migrations = Directory('supabase/migrations')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.sql'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    final sql = migrations.map((f) => f.readAsStringSync()).join('\n');

    /// Corps de la DERNIÈRE définition d'une fonction, de son `CREATE` au
    /// `$$;` qui le ferme.
    ///
    /// Chercher dans un fichier nommé ne tient pas : ces deux fonctions ont
    /// été remplacées par `20260914120000` puis `20260914130000` (groupes de
    /// ville). Le banc aurait continué de garder une version qui ne tourne
    /// plus — en passant au vert, ce qui est pire que de ne rien garder.
    String corps(String nom) {
      // `CREATE OR REPLACE` et pas seulement `FUNCTION public.<nom>(` : les
      // lignes `REVOKE ... ON FUNCTION public.<nom>(...)` de la même migration
      // arrivent APRÈS la définition, et une recherche en arrière tombait
      // dessus — la tranche partait d'un REVOKE et ne contenait rien.
      for (final f in migrations.reversed) {
        final contenu = f.readAsStringSync();
        final debut =
            contenu.lastIndexOf('CREATE OR REPLACE FUNCTION public.$nom(');
        if (debut == -1) continue;
        final fin = contenu.indexOf(RegExp(r'\$\$;'), debut);
        return contenu.substring(debut, fin);
      }
      fail('$nom introuvable dans les migrations');
    }

    test('ni le déclencheur ni la tâche quotidienne ne retirent personne', () {
      for (final nom in [
        'planifier_depart_groupe_officiel',
        'proposer_departs_groupes_officiels',
      ]) {
        final f = corps(nom).toUpperCase();
        expect(f, isNot(contains('DELETE')), reason: nom);
        expect(f, isNot(contains('LEAVE_GROUP_CONVERSATION')), reason: nom);
      }
    });

    test('le départ est dans la réponse, et seulement si elle dit quitter', () {
      final f = corps('repondre_depart_groupe_officiel');
      expect(f, contains('IF p_quitter THEN'));
      expect(f, contains('DELETE FROM public.group_members'));
      // Sur l'appelant, jamais sur un identifiant fourni.
      expect(f, contains('public.firebase_uid()'));
    });

    test('un départ de ville ne s\'annule pas tout seul', () {
      final f = corps('planifier_depart_groupe_officiel');
      // La garde « revenu dans le pays » ne doit toucher QUE les groupes de
      // pays : un groupe de ville porte le pays de sa ville, et sans cette
      // restriction un départ de Montréal s'annulait au premier
      // enregistrement de profil venu — l'usager étant toujours au Canada.
      // Rien ne l'aurait signalé : la proposition n'aurait jamais eu lieu.
      expect(f, contains('g.ville_id IS NULL'));
      // Et le départ d'une ville se planifie, les villes comparées par pôle.
      expect(f, contains('v_ancienne IS DISTINCT FROM v_nouvelle'));
      expect(f, contains('public.ville_de_groupe'));
    });

    test('la tâche quotidienne juge une ville sur la ville', () {
      final f = corps('proposer_departs_groupes_officiels');
      expect(f, contains('ville_groupe'));
      expect(f, contains('ville_profil'));
      expect(f, contains('WHEN r.ville_groupe IS NOT NULL'));
    });

    test('le déclencheur surveille aussi la ville', () {
      // `UPDATE OF` se déclenche sur les colonnes citées dans le SET : sans
      // `ville_id` dans la liste, un déménagement de ville ne réveille rien.
      expect(
        sql,
        contains('AFTER UPDATE OF country_code, ville_id ON public.users'),
      );
      expect(sql, contains('OLD.ville_id IS DISTINCT FROM NEW.ville_id'));
    });

    test('la réponse est fermée à anon, la tâche à tout client', () {
      // `REVOKE ... FROM PUBLIC` ne retire pas le droit accordé nommément à
      // `anon` par Supabase (voir 20260910070000).
      expect(sql,
          contains('repondre_depart_groupe_officiel(uuid, boolean) FROM anon'));
      expect(sql,
          contains('proposer_departs_groupes_officiels() FROM anon, authenticated'));
    });
  });

  testWidgets('sans proposition, rien ne s\'affiche', (tester) async {
    await tester.pumpWidget(boot(_FakeDataSource(null)));
    await tester.pumpAndSettle();

    expect(find.text('Vous avez changé de pays'), findsNothing);
    expect(find.text('Rester membre'), findsNothing);
  });

  testWidgets('l\'avertissement dit le pays et la date, et n\'envoie rien seul',
      (tester) async {
    final source = _FakeDataSource(proposition);
    await tester.pumpWidget(boot(source));
    await tester.pumpAndSettle();

    expect(find.text('Vous avez changé de pays'), findsOneWidget);
    expect(find.textContaining('11 septembre 2026'), findsOneWidget);
    expect(find.textContaining('Cap-Vert'), findsOneWidget);
    expect(find.textContaining('rien ne change sans votre accord'),
        findsOneWidget);
    expect(source.answers, isEmpty);
  });

  testWidgets('un départ de ville parle de ville, pas de pays', (tester) async {
    // Quelqu'un qui déménage de Montréal à Toronto est TOUJOURS au Canada :
    // « vous avez changé de pays » et « votre profil n'indique plus Canada »
    // seraient l'un et l'autre faux. C'est la ville quittée que la carte
    // doit nommer.
    final source = _FakeDataSource(
      OfficialGroupDeparture(
        groupId: 'grp-cv',
        formerCountry: 'Canada',
        formerCity: 'Montréal',
        changedAt: DateTime(2026, 9, 11),
      ),
    );
    await tester.pumpWidget(boot(source));
    await tester.pumpAndSettle();

    expect(find.text('Vous avez changé de ville'), findsOneWidget);
    expect(find.text('Vous avez changé de pays'), findsNothing);
    expect(find.textContaining('Montréal'), findsOneWidget);
    expect(find.textContaining('Canada'), findsNothing);
    expect(source.answers, isEmpty);
  });

  testWidgets('« Rester membre » garde l\'utilisateur et retire la carte',
      (tester) async {
    final source = _FakeDataSource(proposition);
    await tester.pumpWidget(boot(source));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rester membre'));
    await tester.pumpAndSettle();

    expect(source.answers, [false]);
    expect(departs, 0);
    expect(find.text('Vous restez membre de ce groupe.'), findsOneWidget);
    expect(find.text('Vous avez changé de pays'), findsNothing);
  });

  testWidgets('« Quitter » redemande confirmation, et Annuler n\'envoie rien',
      (tester) async {
    final source = _FakeDataSource(proposition);
    await tester.pumpWidget(boot(source));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Quitter le groupe'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    expect(source.answers, isEmpty);
    expect(departs, 0);
    expect(find.text('Vous avez changé de pays'), findsOneWidget);
  });

  testWidgets('« Quitter » confirmé envoie le départ et ferme la fiche',
      (tester) async {
    final source = _FakeDataSource(proposition);
    await tester.pumpWidget(boot(source));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Quitter le groupe'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Quitter'));
    await tester.pumpAndSettle();

    expect(source.answers, [true]);
    expect(departs, 1);
    expect(find.text('Vous avez quitté le groupe'), findsOneWidget);
  });

  testWidgets('un échec le dit, et l\'utilisateur reste devant son choix',
      (tester) async {
    final source = _FakeDataSource(proposition)..fail = true;
    await tester.pumpWidget(boot(source));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rester membre'));
    await tester.pumpAndSettle();

    expect(departs, 0);
    expect(
      find.text('Votre choix n\'a pas pu être enregistré. Réessayez.'),
      findsOneWidget,
    );
    expect(find.text('Vous avez changé de pays'), findsOneWidget);
  });
}
