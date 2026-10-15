// Avatar des cartes du panneau et nom de l'organisateur d'un événement.
import 'package:diaspo_niger/features/admin/presentation/screens/admin_moderation_screen.dart';
import 'package:diaspo_niger/features/admin/presentation/widgets/avatar_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AvatarAdmin.initiale', () {
    test('première lettre en majuscule', () {
      expect(AvatarAdmin.initiale('mariam kone'), 'M');
      expect(AvatarAdmin.initiale('  éric'), 'É');
    });
    test("U quand il n'y a rien à lire", () {
      expect(AvatarAdmin.initiale(null), 'U');
      expect(AvatarAdmin.initiale('   '), 'U');
    });
  });

  group('AvatarAdmin', () {
    testWidgets('sans photo : initiale sur fond dégradé', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AvatarAdmin(nom: 'Aïcha'))),
      );
      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('photo illisible : l\'initiale revient, pas une pastille blanche',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AvatarAdmin(
              nom: 'Mariam Kone',
              photoUrl: 'https://exemple.invalid/introuvable.jpg',
            ),
          ),
        ),
      );
      // Le chargement échoue (hôte inexistant / HTTP 400 sous test).
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pump();
      expect(find.text('M'), findsOneWidget);
    });
  });

  group('libelleOrganisateur', () {
    test("le nom d'abord", () {
      expect(libelleOrganisateur('Awa Diallo', 'uid-1'), 'Awa Diallo');
    });
    test("l'identifiant à défaut de nom", () {
      expect(libelleOrganisateur(null, 'uid-1'), 'uid-1');
      expect(libelleOrganisateur('  ', 'uid-1'), 'uid-1');
    });
  });
}
