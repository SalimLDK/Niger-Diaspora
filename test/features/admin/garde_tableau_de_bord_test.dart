import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/features/admin/domain/enums/admin_enums.dart';
import 'package:diaspo_niger/features/admin/presentation/providers/permission_provider.dart';
import 'package:diaspo_niger/features/admin/presentation/widgets/garde_tableau_de_bord.dart';

/// `/dashboard` était une route nommée sans garde : atteignable par URL sans
/// connexion (audit du 2026-10-14, § 8). La garde ne rend le tableau de bord
/// qu'à un rôle lu dans le jeton, l'écran de connexion sinon — et rien de
/// définitif tant que le jeton n'est pas lu.
Future<void> _monter(WidgetTester tester, Stream<AdminRole> role) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [currentAdminRoleProvider.overrideWith((ref) => role)],
      child: const MaterialApp(
        home: GardeTableauDeBord(
          tableauDeBord: Text('TABLEAU DE BORD'),
          connexion: Text('CONNEXION'),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('rôle admin lu dans le jeton : tableau de bord', (tester) async {
    await _monter(tester, Stream.value(AdminRole.superAdmin));

    expect(find.text('TABLEAU DE BORD'), findsOneWidget);
    expect(find.text('CONNEXION'), findsNothing);
  });

  testWidgets('aucun rôle (pas de session, ou sans claim) : connexion', (
    tester,
  ) async {
    await _monter(tester, Stream.value(AdminRole.none));

    expect(find.text('CONNEXION'), findsOneWidget);
    expect(
      find.text('TABLEAU DE BORD'),
      findsNothing,
      reason: 'la route rendait le panneau sans connexion',
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
}
