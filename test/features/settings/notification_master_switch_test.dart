import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:diaspo_niger/core/errors/failures.dart';
import 'package:diaspo_niger/core/services/preferences_service.dart';
import 'package:diaspo_niger/features/auth/domain/entities/user_entity.dart';
import 'package:diaspo_niger/features/auth/presentation/providers/auth_provider.dart';
import 'package:diaspo_niger/features/profile/domain/entities/profile_entity.dart';
import 'package:diaspo_niger/features/profile/domain/repositories/profile_repository.dart';
import 'package:diaspo_niger/features/profile/presentation/providers/profile_provider.dart';
import 'package:diaspo_niger/features/settings/presentation/providers/notification_preferences_provider.dart';

/// Interrupteur maître des notifications : il écrit deux étages, et ils
/// doivent rester d'accord.
///
/// - la **préférence locale** décide de l'affichage (`notification_service`
///   la lit avant de montrer une notification) ;
/// - la colonne serveur `users.notifications_enabled` décide de l'envoi
///   (`send-push` la lit avant tout FCM).
///
/// L'étage serveur n'avait aucun `try/catch`, et ses trois sorties ratées —
/// profil introuvable, `updateProfile` qui pose une erreur au lieu de lever,
/// exception — laissaient l'étage local écrit. L'interrupteur affichait
/// « désactivé » et masquait les notifications au premier plan, pendant que le
/// back-end continuait de pousser vers un téléphone dont l'utilisateur croyait
/// avoir coupé le son.
class _FauxDepot implements ProfileRepository {
  _FauxDepot(this.profil);

  ProfileEntity profil;
  ProfileEntity? ecrit;
  bool refuser = false;
  bool absent = false;

  @override
  Future<Either<Failure, ProfileEntity>> getProfile(String userId) async =>
      absent ? const Left(ServerFailure('introuvable')) : Right(profil);

  @override
  Either<Failure, ProfileEntity?> getCachedProfile(String userId) =>
      absent ? const Right(null) : Right(profil);

  @override
  Future<Either<Failure, ProfileEntity>> updateProfile(
    ProfileEntity profile,
  ) async {
    ecrit = profile;
    if (refuser) return const Left(ServerFailure('refusé'));
    profil = profile;
    return Right(profile);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const userId = 'u1';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService.instance.initialize();
  });

  Future<ProviderContainer> conteneur(_FauxDepot depot) async {
    final c = ProviderContainer(
      overrides: [
        profileRepositoryProvider.overrideWithValue(depot),
        currentUserAsyncProvider.overrideWith(
          (ref) => Stream.value(const UserEntity(id: userId)),
        ),
      ],
    );
    addTearDown(c.dispose);
    c.listen(currentUserAsyncProvider, (_, __) {}, fireImmediately: true);
    c.listen(
      profileNotifierProvider(userId),
      (_, __) {},
      fireImmediately: true,
    );
    c.listen(
      notificationPreferencesNotifierProvider,
      (_, __) {},
      fireImmediately: true,
    );
    await c.read(currentUserAsyncProvider.future);
    await Future<void>.delayed(Duration.zero);
    return c;
  }

  test('acceptée : les deux étages passent à « désactivé »', () async {
    final depot = _FauxDepot(const ProfileEntity(id: userId));
    final c = await conteneur(depot);

    final ok = await c
        .read(notificationPreferencesNotifierProvider.notifier)
        .setMasterEnabled(false);

    expect(ok, isTrue);
    expect(c.read(notificationPreferencesNotifierProvider).masterEnabled, false);
    expect(PreferencesService.instance.notificationsEnabled, isFalse);
    expect(depot.ecrit?.notificationsEnabled, isFalse);
  });

  test('serveur refuse : l\'étage local revient en arrière avec lui', () async {
    final depot = _FauxDepot(const ProfileEntity(id: userId))..refuser = true;
    final c = await conteneur(depot);

    final ok = await c
        .read(notificationPreferencesNotifierProvider.notifier)
        .setMasterEnabled(false);

    expect(ok, isFalse, reason: 'le refus devait remonter à l\'appelant');
    expect(
      c.read(notificationPreferencesNotifierProvider).masterEnabled,
      isTrue,
      reason:
          'l\'interrupteur affichait « désactivé » alors que la colonne lue '
          'par send-push restait à « activé »',
    );
    expect(
      PreferencesService.instance.notificationsEnabled,
      isTrue,
      reason:
          'la préférence locale est restée écrite : les notifications étaient '
          'masquées au premier plan sans que le serveur ait cessé d\'envoyer',
    );
  });

  test('profil introuvable : l\'étage serveur n\'est plus sauté en silence',
      () async {
    final depot = _FauxDepot(const ProfileEntity(id: userId))..absent = true;
    final c = await conteneur(depot);

    final ok = await c
        .read(notificationPreferencesNotifierProvider.notifier)
        .setMasterEnabled(false);

    expect(ok, isFalse);
    expect(c.read(notificationPreferencesNotifierProvider).masterEnabled, true);
    expect(PreferencesService.instance.notificationsEnabled, isTrue);
  });
}
