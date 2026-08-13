import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/features/settings/data/datasources/blocked_by_supabase_datasource.dart';

/// Pendant la fenêtre `_startFromLocalSession` (auth_provider.dart), l'app
/// est déjà sur /home alors que la session Supabase n'est pas confirmée.
/// `watchBlockedBy` ne doit pas s'abonner en anon avant d'avoir laissé une
/// chance à la session de se confirmer.
void main() {
  test('attend la garde avant de s\'abonner', () async {
    var guardCalled = false;
    final ds = BlockedBySupabaseDataSource(
      ensureReadableAuth: () async {
        guardCalled = true;
        return false;
      },
    );

    // Aucun client Supabase n'est initialisé ici : l'abonnement échoue quand
    // même — mais *après* la garde, ce qui prouve qu'elle a bien été
    // consultée avant de contacter Supabase.
    await expectLater(
      ds.watchBlockedBy('u1').first,
      throwsA(anything),
    );
    expect(guardCalled, isTrue, reason: 'la garde n\'a pas été consultée');
  });

  test('session confirmée : la garde laisse passer l\'abonnement', () async {
    var guardCalled = false;
    final ds = BlockedBySupabaseDataSource(
      ensureReadableAuth: () async {
        guardCalled = true;
        return true;
      },
    );

    await expectLater(ds.watchBlockedBy('u1').first, throwsA(anything));
    expect(guardCalled, isTrue);
  });
}
