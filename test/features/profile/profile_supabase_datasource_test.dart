import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/core/errors/exceptions.dart';
import 'package:diaspo_niger/features/profile/data/datasources/profile_supabase_datasource.dart';
import 'package:diaspo_niger/features/profile/data/models/profile_model.dart';

/// Toute écriture du profil doit refuser de partir sans session Supabase.
///
/// Sans cette garde, la RLS rejette l'UPDATE en 204 sans corps : aucune
/// exception n'est levée, 0 ligne est modifiée, et le réglage semble
/// pourtant enregistré côté UI. L'échec est silencieux — d'où ces tests.
void main() {
  const profile = ProfileModel(id: 'u1');

  /// Les 7 écritures du datasource, indexées par nom pour un rapport lisible.
  final writes = <String, Future<void> Function(ProfileSupabaseDataSource)>{
    'updateProfile': (ds) => ds.updateProfile(profile),
    'updateLocation': (ds) => ds.updateLocation('u1', 13.51, 2.11),
    'updateLastLogin': (ds) => ds.updateLastLogin('u1'),
    'updateOnlineStatus': (ds) =>
        ds.updateOnlineStatus('u1', true, DateTime.utc(2026, 7, 27)),
    'updateOnlineStatusVisibility': (ds) =>
        ds.updateOnlineStatusVisibility('u1', true),
    'updateNotifyLocalEvents': (ds) => ds.updateNotifyLocalEvents('u1', true),
    'updateShowMessagePreview': (ds) => ds.updateShowMessagePreview('u1', true),
    'updateNotificationPrefs': (ds) =>
        ds.updateNotificationPrefs('u1', const {'messages': false}),
  };

  group('session absente', () {
    writes.forEach((name, call) {
      test('$name refuse d\'écrire', () async {
        var guardCalled = false;
        final ds = ProfileSupabaseDataSource(
          ensureAuth: () async {
            guardCalled = true;
            return false;
          },
        );

        await expectLater(
          call(ds),
          throwsA(
            isA<ServerException>().having(
              (e) => e.message,
              'message',
              contains('Session Supabase'),
            ),
          ),
        );
        expect(guardCalled, isTrue, reason: 'la garde n\'a pas été consultée');
      });
    });
  });

  test('session valide : la garde laisse passer l\'écriture', () async {
    var guardCalled = false;
    final ds = ProfileSupabaseDataSource(
      ensureAuth: () async {
        guardCalled = true;
        return true;
      },
    );

    // Aucun client Supabase n'est initialisé ici, donc l'appel échoue quand
    // même — mais *après* la garde, et pour une autre raison. C'est ce qui
    // prouve que la garde ne bloque pas une session valide.
    await expectLater(ds.updateLastLogin('u1'), throwsA(isNot(isA<ServerException>())));
    expect(guardCalled, isTrue);
  });

  /// Pendant la fenêtre `_startFromLocalSession` (auth_provider.dart), l'app
  /// est déjà sur /home alors que la session Supabase n'est pas confirmée.
  /// Ces lectures ne doivent pas interroger la table en anon.
  group('session non confirmée (lecture)', () {
    test('getProfile refuse de lire', () async {
      var guardCalled = false;
      final ds = ProfileSupabaseDataSource(
        ensureReadableAuth: () async {
          guardCalled = true;
          return false;
        },
      );

      await expectLater(
        ds.getProfile('u1'),
        throwsA(
          isA<ServerException>().having(
            (e) => e.message,
            'message',
            contains('Session Supabase'),
          ),
        ),
      );
      expect(guardCalled, isTrue, reason: 'la garde n\'a pas été consultée');
    });

    test('getNearbyProfiles refuse de lire', () async {
      var guardCalled = false;
      final ds = ProfileSupabaseDataSource(
        ensureReadableAuth: () async {
          guardCalled = true;
          return false;
        },
      );

      await expectLater(
        ds.getNearbyProfiles(13.51, 2.11, 50),
        throwsA(isA<ServerException>()),
      );
      expect(guardCalled, isTrue);
    });

    test('isHandleAvailable se replie sur "disponible" sans interroger', () async {
      var guardCalled = false;
      final ds = ProfileSupabaseDataSource(
        ensureReadableAuth: () async {
          guardCalled = true;
          return false;
        },
      );

      // Repli identique à celui déjà utilisé pour une erreur réseau : la
      // contrainte UNIQUE serveur tranche au moment du save.
      expect(await ds.isHandleAvailable('salim'), isTrue);
      expect(guardCalled, isTrue);
    });
  });

  test('session confirmée : la garde de lecture laisse passer', () async {
    var guardCalled = false;
    final ds = ProfileSupabaseDataSource(
      ensureReadableAuth: () async {
        guardCalled = true;
        return true;
      },
    );

    // Aucun client Supabase n'est initialisé ici : l'appel échoue quand même,
    // mais *après* la garde — preuve qu'une session confirmée n'est pas
    // bloquée.
    await expectLater(ds.getProfile('u1'), throwsA(isNot(isA<ServerException>())));
    expect(guardCalled, isTrue);
  });
}
