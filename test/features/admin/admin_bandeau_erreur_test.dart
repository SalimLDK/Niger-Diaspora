import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/features/admin/presentation/providers/admin_provider.dart';
import 'package:diaspo_niger/features/admin/presentation/screens/admin_users_management_screen.dart';
import 'package:diaspo_niger/features/admin/presentation/widgets/admin_bandeau_erreur.dart';
import 'package:diaspo_niger/features/auth/domain/entities/user_entity.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

/// Une erreur posée **après** une action ne doit pas effacer la liste.
///
/// Les écrans du panneau rendaient `state.error != null` en page d'erreur
/// pleine à la place de la liste. Depuis que chaque action pose son refus dans
/// `state.error` (zéro ligne sous RLS, journal d'audit refusé — ce dernier à
/// chaque action tant que la migration `20261014050000` n'est pas poussée),
/// bannir un utilisateur faisait disparaître toute la liste, sans bouton de
/// reprise sur l'écran Utilisateurs. La liste reste, l'erreur est un bandeau
/// que l'admin referme ; la page pleine ne vaut que sans aucune donnée.
class _FauxUtilisateurs extends AdminUsersNotifier {
  _FauxUtilisateurs(this.initial);

  final AdminUsersState initial;

  @override
  AdminUsersState build() => initial;

  /// L'écran le lance à son montage ; sans Supabase ici, il poserait sa
  /// propre erreur et masquerait celle qu'on teste.
  @override
  Future<void> fetchAllUsers({int limit = 50}) async {}
}

const _aicha = UserEntity(id: 'u1', displayName: 'Aïcha Moussa');
const _motif = 'Action « ban_user » effectuée, mais non journalisée';

Future<void> _monter(WidgetTester tester, AdminUsersState initial) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(1200, 1600);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        adminUsersNotifierProvider.overrideWith(
          () => _FauxUtilisateurs(initial),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: AdminUsersManagementScreen()),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('liste chargée + erreur : bandeau au-dessus, liste intacte', (
    tester,
  ) async {
    await _monter(
      tester,
      const AdminUsersState(users: [_aicha], error: _motif),
    );

    expect(find.byType(AdminBandeauErreur), findsOneWidget);
    expect(find.textContaining(_motif), findsOneWidget);
    expect(
      find.text('Aïcha Moussa'),
      findsOneWidget,
      reason: "l'erreur remplaçait toute la liste par une page d'erreur",
    );
  });

  testWidgets('fermer le bandeau garde la liste', (tester) async {
    await _monter(
      tester,
      const AdminUsersState(users: [_aicha], error: _motif),
    );

    await tester.tap(find.byTooltip('Fermer'));
    await tester.pump();

    expect(find.byType(AdminBandeauErreur), findsNothing);
    expect(find.text('Aïcha Moussa'), findsOneWidget);
  });

  testWidgets('aucune donnée + erreur : page pleine, pas de bandeau', (
    tester,
  ) async {
    await _monter(tester, const AdminUsersState(error: _motif));

    expect(find.byType(AdminBandeauErreur), findsNothing);
    expect(find.textContaining(_motif), findsOneWidget);
  });
}
