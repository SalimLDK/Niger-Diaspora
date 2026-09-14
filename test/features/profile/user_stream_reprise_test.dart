import 'package:dartz/dartz.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/core/errors/failures.dart';
import 'package:diaspo_niger/features/profile/domain/entities/profile_entity.dart';
import 'package:diaspo_niger/features/profile/domain/repositories/profile_repository.dart';
import 'package:diaspo_niger/features/profile/presentation/providers/profile_provider.dart';

/// Reprise du flux de profil après une lecture échouée hors ligne.
///
/// Mesuré sur SM A515F le 2026-09-14 : une discussion ouverte pendant une
/// coupure gardait son en-tête de repli (« Conversation », avatar « C ») même
/// une fois le réseau revenu — à +45 s comme à +105 s, et après être sorti de
/// l'écran et y être revenu. Seul un redémarrage de l'app rétablissait le nom.
///
/// La cause tient en deux faits : `userStreamProvider` est une `family` **sans
/// `autoDispose`** (l'instance en échec vit aussi longtemps que l'app), et son
/// flux se termine dès que le repository a rendu son `Left` transitoire. Plus
/// aucune lecture n'était tentée.
///
/// Ce test rejoue exactement ça, sans appareil : première lecture en échec,
/// puis vérification qu'une seconde part toute seule et remplit le profil.
class _DepotQuiEchouePuisRepond implements ProfileRepository {
  _DepotQuiEchouePuisRepond(this.profil);

  final ProfileEntity profil;

  /// Nombre d'abonnements demandés au repository.
  int abonnements = 0;

  /// Rien en cache : c'est la lecture réseau qu'on observe ici.
  @override
  Either<Failure, ProfileEntity?> getCachedProfile(String userId) =>
      const Right(null);

  @override
  Stream<Either<Failure, ProfileEntity>> getUserStream(String userId) {
    abonnements++;
    // Ce que rend réellement `ProfileRepositoryImpl` hors ligne : une erreur
    // transitoire poussée en `Left`, puis fin de flux.
    if (abonnements == 1) {
      return Stream.value(
        Left<Failure, ProfileEntity>(ServerFailure('hors ligne')),
      );
    }
    return Stream.value(Right<Failure, ProfileEntity>(profil));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Flux qui ne rend jamais rien : sert à prouver qu'aucune reprise ne part
/// tant que rien n'a échoué.
class _DepotMuet implements ProfileRepository {
  int abonnements = 0;

  @override
  Either<Failure, ProfileEntity?> getCachedProfile(String userId) =>
      const Right(null);

  @override
  Stream<Either<Failure, ProfileEntity>> getUserStream(String userId) {
    abonnements++;
    return const Stream<Either<Failure, ProfileEntity>>.empty();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Le cas du démarrage à froid hors ligne : rien à lire, mais un profil déjà
/// connu sur le disque.
class _DepotHorsLigneAvecCache implements ProfileRepository {
  _DepotHorsLigneAvecCache(this.connu);

  final ProfileEntity connu;

  @override
  Either<Failure, ProfileEntity?> getCachedProfile(String userId) =>
      Right(connu);

  @override
  Stream<Either<Failure, ProfileEntity>> getUserStream(String userId) {
    return Stream.value(
      Left<Failure, ProfileEntity>(ServerFailure('hors ligne')),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  // Le flux écoute la connectivité (déclencheur immédiat au retour du réseau) :
  // sans binding, l'`EventChannel` de `connectivity_plus` refuse de s'abonner.
  TestWidgetsFlutterBinding.ensureInitialized();

  const userId = 'u1';

  ProfileEntity profilDeBase() =>
      const ProfileEntity(id: userId, displayName: 'Salim L.');

  test('une lecture échouée est retentée toute seule, et remplit le profil', () {
    fakeAsync((async) {
      final depot = _DepotQuiEchouePuisRepond(profilDeBase());
      final container = ProviderContainer(
        overrides: [profileRepositoryProvider.overrideWithValue(depot)],
      );
      addTearDown(container.dispose);

      container.listen(userStreamProvider(userId), (_, __) {});
      async.flushMicrotasks();

      // L'échec est bien remonté comme erreur — jamais comme « supprimé ».
      final apresEchec = container.read(userStreamProvider(userId));
      expect(apresEchec.hasError, isTrue);
      expect(apresEchec.hasValue, isFalse);
      expect(depot.abonnements, 1);

      // Personne ne touche à l'écran : le premier palier (3 s) suffit.
      async.elapse(const Duration(seconds: 4));
      async.flushMicrotasks();

      expect(depot.abonnements, 2);
      expect(
        container.read(userStreamProvider(userId)).valueOrNull?.displayName,
        'Salim L.',
      );
    });
  });

  test('hors ligne, le dernier profil connu s\'affiche au lieu du repli', () {
    fakeAsync((async) {
      final depot = _DepotHorsLigneAvecCache(profilDeBase());
      final container = ProviderContainer(
        overrides: [profileRepositoryProvider.overrideWithValue(depot)],
      );
      addTearDown(container.dispose);

      container.listen(userStreamProvider(userId), (_, __) {});
      async.flushMicrotasks();

      // Le nom est là sans qu'aucune lecture réseau n'ait abouti : c'est ce qui
      // évite « Conversation » / « Utilisateur » au démarrage à froid.
      expect(
        container.read(userStreamProvider(userId)).valueOrNull?.displayName,
        'Salim L.',
      );
    });
  });

  test('un flux qui n\'a pas échoué n\'est pas rebranché en boucle', () {
    fakeAsync((async) {
      final depot = _DepotMuet();
      final container = ProviderContainer(
        overrides: [profileRepositoryProvider.overrideWithValue(depot)],
      );
      addTearDown(container.dispose);

      container.listen(userStreamProvider(userId), (_, __) {});
      async.flushMicrotasks();

      // Le flux se termine sans rien dire : on reprend, mais par paliers qui
      // doublent (3 s, 6 s, 12 s…), pas à chaque tick.
      async.elapse(const Duration(minutes: 1));
      expect(depot.abonnements, lessThanOrEqualTo(6));
    });
  });
}
