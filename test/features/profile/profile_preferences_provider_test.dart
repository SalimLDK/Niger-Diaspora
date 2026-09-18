import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/core/errors/failures.dart';
import 'package:diaspo_niger/features/auth/domain/entities/user_entity.dart';
import 'package:diaspo_niger/features/auth/presentation/providers/auth_provider.dart';
import 'package:diaspo_niger/features/profile/domain/entities/profile_entity.dart';
import 'package:diaspo_niger/features/profile/domain/repositories/profile_repository.dart';
import 'package:diaspo_niger/features/profile/presentation/providers/profile_preferences_provider.dart';
import 'package:diaspo_niger/features/profile/presentation/providers/profile_provider.dart';

/// Bascules de confidentialité du profil.
///
/// Régression constatée en comparant les écrans Profil et Réglages : chacun
/// gardait une copie `bool` locale des quatre préférences, initialisée à
/// `true` et rafraîchie par un `ref.listen` qui ne se déclenchait jamais (le
/// profil est déjà chargé à l'ouverture de Réglages). Comme la sauvegarde
/// réécrivait les quatre champs d'un seul `copyWith`, **toucher une bascule
/// remettait les trois autres à `true`** par-dessus les vraies valeurs
/// serveur.
///
/// Le correctif tient dans une contrainte d'API : `set` n'écrit qu'un champ.
/// Ce test le vérifie sur le scénario exact qui cassait.
class _FauxDepot implements ProfileRepository {
  _FauxDepot(this.profil);

  ProfileEntity profil;

  /// Dernière entité effectivement envoyée à l'écriture.
  ProfileEntity? ecrit;

  /// Le serveur refuse toute écriture.
  bool refuser = false;

  /// Le profil est introuvable, ni en cache ni sur le serveur.
  bool absent = false;

  /// Aucun cache local, mais le serveur, lui, a le profil.
  bool sansCache = false;

  @override
  Future<Either<Failure, ProfileEntity>> getProfile(String userId) async =>
      absent ? const Left(ServerFailure('introuvable')) : Right(profil);

  @override
  Either<Failure, ProfileEntity?> getCachedProfile(String userId) =>
      (absent || sansCache) ? const Right(null) : Right(profil);

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

  /// `countryCode` reste nul : sinon `ProfileNotifier` tente de rejoindre le
  /// groupe officiel du pays et réclamerait `groupRepositoryProvider`.
  ProfileEntity profilDeBase({
    bool isVisible = true,
    bool shareLocation = true,
  }) => ProfileEntity(
    id: userId,
    isVisible: isVisible,
    shareLocation: shareLocation,
  );

  ProviderContainer conteneur(_FauxDepot depot) {
    final c = ProviderContainer(
      overrides: [
        profileRepositoryProvider.overrideWithValue(depot),
        currentUserAsyncProvider.overrideWith(
          (ref) => Stream.value(const UserEntity(id: userId)),
        ),
      ],
    );
    addTearDown(c.dispose);
    // `currentUserAsync` est autoDispose : sans abonnement retenu, il se
    // recrée en état de chargement à chaque lecture et les providers de
    // préférence ne savent jamais de quel profil ils parlent.
    c.listen(currentUserAsyncProvider, (_, __) {}, fireImmediately: true);
    c.listen(
      profileNotifierProvider(userId),
      (_, __) {},
      fireImmediately: true,
    );
    return c;
  }

  test('basculer « ma position » n\'écrase pas « profil visible »', () async {
    // L'utilisateur s'est déjà rendu invisible. C'est précisément la valeur
    // que l'ancien code écrasait, parce que sa copie locale valait « true ».
    final depot = _FauxDepot(profilDeBase(isVisible: false));
    final c = conteneur(depot);

    await c.read(currentUserAsyncProvider.future);
    await Future<void>.delayed(Duration.zero);

    await c
        .read(profilePreferencesProvider)
        .set(ProfilePreference.shareLocation, false);

    expect(depot.ecrit, isNotNull, reason: 'aucune écriture déclenchée');
    expect(
      depot.ecrit!.shareLocation,
      isFalse,
      reason: 'la préférence demandée n\'a pas été écrite',
    );
    expect(
      depot.ecrit!.isVisible,
      isFalse,
      reason:
          'la bascule voisine a été réécrite. C\'est exactement le bug : la '
          'sauvegarde repartait de copies locales jamais rafraîchies et '
          'remettait « profil visible » à true.',
    );
  });

  // `set` ne levait ni ne rendait rien : un refus du serveur ramenait
  // l'interrupteur en arrière sans un mot, et — pour « ma position » — la
  // capture GPS partait quand même sur une préférence que le serveur n'avait
  // pas reçue. Il rend désormais `false`, et l'écran le dit (`reportIfFailed`).
  test('écriture acceptée : rend true', () async {
    final c = conteneur(_FauxDepot(profilDeBase()));
    await c.read(currentUserAsyncProvider.future);
    await Future<void>.delayed(Duration.zero);

    final ok = await c
        .read(profilePreferencesProvider)
        .set(ProfilePreference.isVisible, false);

    expect(ok, isTrue);
  });

  test('écriture refusée : rend false et l\'interrupteur garde sa valeur',
      () async {
    final depot = _FauxDepot(profilDeBase(isVisible: true))..refuser = true;
    final c = conteneur(depot);
    await c.read(currentUserAsyncProvider.future);
    await Future<void>.delayed(Duration.zero);

    final ok = await c
        .read(profilePreferencesProvider)
        .set(ProfilePreference.isVisible, false);

    expect(depot.ecrit, isNotNull, reason: 'l\'écriture n\'a pas été tentée');
    expect(ok, isFalse, reason: 'le refus devait remonter à l\'appelant');
    expect(
      c.read(profilePreferenceProvider(ProfilePreference.isVisible)),
      isTrue,
      reason:
          'l\'interrupteur doit revenir à la valeur du serveur, pas rester '
          'sur la valeur refusée',
    );
  });

  test('profil introuvable : rend false au lieu de sortir sans rien dire',
      () async {
    final depot = _FauxDepot(profilDeBase())..absent = true;
    final c = conteneur(depot);
    await c.read(currentUserAsyncProvider.future);
    await Future<void>.delayed(Duration.zero);

    final ok = await c
        .read(profilePreferencesProvider)
        .set(ProfilePreference.isVisible, false);

    expect(ok, isFalse);
    expect(depot.ecrit, isNull, reason: 'rien à écrire sans profil de départ');
  });

  // `updateProfile` écrit TOUTES les colonnes : toute écriture partielle part
  // du profil courant (`copyWith`). Or le notifier est autoDispose et son
  // chargement asynchrone : sans cache, `state` est encore en chargement juste
  // après sa création, et un `valueOrNull` y rend `null` — l'appelant sortait
  // alors sur son garde sans rien dire, ou sautait un étage d'écriture.
  test('currentProfile : sans cache, va chercher le profil au lieu de rendre '
      'null', () async {
    final depot = _FauxDepot(profilDeBase(isVisible: false))..sansCache = true;
    final c = conteneur(depot);

    // Aucun `await` avant : le chargement du notifier n'a pas rendu la main.
    expect(
      c.read(profileNotifierProvider(userId)).valueOrNull,
      isNull,
      reason: 'le scénario suppose un état encore en chargement',
    );

    final profil = await c
        .read(profileNotifierProvider(userId).notifier)
        .currentProfile();

    expect(profil, isNotNull, reason: 'le repli sur le dépôt a disparu');
    expect(profil!.isVisible, isFalse);
  });

  test('currentProfile : introuvable partout, rend null', () async {
    final depot = _FauxDepot(profilDeBase())..absent = true;
    final c = conteneur(depot);

    final profil = await c
        .read(profileNotifierProvider(userId).notifier)
        .currentProfile();

    expect(profil, isNull);
  });

  test('la valeur lue vient du profil, sans écoute à poser', () async {
    final depot = _FauxDepot(profilDeBase(isVisible: false));
    final c = conteneur(depot);

    await c.read(currentUserAsyncProvider.future);
    await Future<void>.delayed(Duration.zero);

    // Aucun `ref.listen` n'a été posé : c'est là-dessus que reposait
    // l'ancienne synchronisation, et il ne se déclenchait pas quand le profil
    // était déjà chargé.
    expect(
      c.read(profilePreferenceProvider(ProfilePreference.isVisible)),
      isFalse,
    );
    expect(
      c.read(profilePreferenceProvider(ProfilePreference.shareLocation)),
      isTrue,
    );
  });
}
