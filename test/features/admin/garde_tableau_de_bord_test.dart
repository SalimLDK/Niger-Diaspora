import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/features/admin/domain/enums/admin_enums.dart';
import 'package:diaspo_niger/features/admin/presentation/providers/permission_provider.dart';
import 'package:diaspo_niger/features/admin/presentation/providers/second_facteur_provider.dart';
import 'package:diaspo_niger/features/admin/presentation/widgets/garde_tableau_de_bord.dart';
import 'package:diaspo_niger/features/auth/domain/entities/second_facteur.dart';

/// `/dashboard` était une route nommée sans garde : atteignable par URL sans
/// connexion (audit du 2026-10-14, § 8). La garde ne rend le tableau de bord
/// qu'à un rôle lu dans le jeton **et** un second facteur enrôlé
/// (`docs/deploiement/MFA_ADMIN.md`) : l'écran de connexion sans rôle,
/// l'enrôlement sans facteur — et rien de définitif tant que l'un ou l'autre
/// n'est pas lu.
const _unFacteur = [FacteurEnrole(id: 'f1', type: FacteurEnrole.typeTotp)];

Future<void> _monter(
  WidgetTester tester,
  Stream<AdminRole> role, {
  Future<List<FacteurEnrole>> Function()? facteurs,
  void Function()? surLectureDesFacteurs,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentAdminRoleProvider.overrideWith((ref) => role),
        facteursEnrolesProvider.overrideWith((ref) {
          surLectureDesFacteurs?.call();
          return facteurs?.call() ?? Future.value(_unFacteur);
        }),
      ],
      child: const MaterialApp(
        home: GardeTableauDeBord(
          tableauDeBord: Text('TABLEAU DE BORD'),
          connexion: Text('CONNEXION'),
          enrolement: Text('ENRÔLEMENT'),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('rôle admin lu dans le jeton, un facteur : tableau de bord', (
    tester,
  ) async {
    await _monter(tester, Stream.value(AdminRole.superAdmin));

    expect(find.text('TABLEAU DE BORD'), findsOneWidget);
    expect(find.text('CONNEXION'), findsNothing);
    expect(find.text('ENRÔLEMENT'), findsNothing);
  });

  testWidgets('aucun rôle (pas de session, ou sans claim) : connexion', (
    tester,
  ) async {
    var facteursLus = false;
    await _monter(
      tester,
      Stream.value(AdminRole.none),
      surLectureDesFacteurs: () => facteursLus = true,
    );

    expect(find.text('CONNEXION'), findsOneWidget);
    expect(
      find.text('TABLEAU DE BORD'),
      findsNothing,
      reason: 'la route rendait le panneau sans connexion',
    );
    expect(
      facteursLus,
      isFalse,
      reason: 'sans rôle, les facteurs du compte ne sont même pas lus',
    );
  });

  testWidgets('jeton pas encore lu : ni l\'un ni l\'autre', (tester) async {
    final jamais = StreamController<AdminRole>();
    addTearDown(jamais.close);
    await _monter(tester, jamais.stream);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('TABLEAU DE BORD'), findsNothing);
    expect(
      find.text('CONNEXION'),
      findsNothing,
      reason:
          '« pas encore lu » n\'est pas « refusé » : le jeton se renouvelle '
          'de force au premier passage',
    );
  });

  testWidgets('rôle admin, aucun facteur enrôlé : enrôlement', (tester) async {
    await _monter(
      tester,
      Stream.value(AdminRole.superAdmin),
      facteurs: () => Future.value(const []),
    );

    expect(find.text('ENRÔLEMENT'), findsOneWidget);
    expect(
      find.text('TABLEAU DE BORD'),
      findsNothing,
      reason: 'un admin sans second facteur n\'atteint jamais /dashboard',
    );
    expect(find.text('CONNEXION'), findsNothing);
  });

  testWidgets('rôle admin, facteurs pas encore lus : ni l\'un ni l\'autre', (
    tester,
  ) async {
    final jamais = Completer<List<FacteurEnrole>>();
    await _monter(
      tester,
      Stream.value(AdminRole.superAdmin),
      facteurs: () => jamais.future,
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('TABLEAU DE BORD'), findsNothing);
    expect(find.text('ENRÔLEMENT'), findsNothing);
  });

  testWidgets('rôle admin, facteurs illisibles : connexion, pas l\'enrôlement',
      (tester) async {
    await _monter(
      tester,
      Stream.value(AdminRole.superAdmin),
      facteurs: () => Future.error(StateError('Aucune session ouverte')),
    );

    expect(find.text('CONNEXION'), findsOneWidget);
    expect(find.text('TABLEAU DE BORD'), findsNothing);
    expect(
      find.text('ENRÔLEMENT'),
      findsNothing,
      reason:
          '« illisible » n\'est pas « aucun » : ouvrir l\'enrôlement sur une '
          'session morte échouerait plus loin, sans dire pourquoi',
    );
  });
}
