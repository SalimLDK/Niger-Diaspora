import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/services/location_publisher_service.dart';
import '../../../../core/services/preferences_service.dart';
import '../../data/datasources/profile_remote_datasource.dart';
import '../../data/datasources/profile_supabase_datasource.dart';
import '../../data/repositories/profile_repository_impl.dart';
import '../../domain/entities/profile_entity.dart';
import '../../domain/repositories/profile_repository.dart';
import '../../../groups/presentation/providers/group_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// Provider pour la source de donnees distante du profil
final profileRemoteDataSourceProvider = Provider<ProfileRemoteDataSource>((
  ref,
) {
  return ProfileSupabaseDataSource();
});

/// Provider pour le repository de profil
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepositoryImpl(
    remoteDataSource: ref.watch(profileRemoteDataSourceProvider),
    networkInfo: ref.watch(networkInfoProvider),
  );
});

/// Provider pour le profil d'un utilisateur (avec cache stale-while-revalidate)
/// autoDispose: libere la memoire quand le provider n'est plus utilise
final profileNotifierProvider = StateNotifierProvider.autoDispose
    .family<ProfileNotifier, AsyncValue<ProfileEntity?>, String>((ref, userId) {
      return ProfileNotifier(ref, userId);
    });

/// Notifier pour gerer l'etat du profil utilisateur
class ProfileNotifier extends StateNotifier<AsyncValue<ProfileEntity?>> {
  final Ref _ref;
  final String userId;

  /// Évite de retenter l'adhésion au groupe pays à chaque rafraîchissement.
  bool _countryGroupJoinAttempted = false;

  ProfileNotifier(this._ref, this.userId) : super(const AsyncValue.loading()) {
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final repository = _ref.read(profileRepositoryProvider);

    // 1. Tenter de charger depuis le cache (stale-while-revalidate)
    final cachedResult = repository.getCachedProfile(userId);
    ProfileEntity? cachedProfile;

    cachedResult.fold((l) => null, (r) => cachedProfile = r);

    if (cachedProfile != null) {
      // Si on a un cache, on le retourne immediatement
      state = AsyncValue.data(cachedProfile);
      // Et on lance le rafraichissement en arriere-plan
      Future.microtask(() => _fetchAndRefresh());
      return;
    }

    // 2. Si pas de cache, on charge normalement
    final result = await repository.getProfile(userId);

    result.fold(
      (failure) =>
          state = AsyncValue.error(
            Exception(failure.message),
            StackTrace.current,
          ),
      (profile) {
        state = AsyncValue.data(profile);
        _maybeJoinCountryGroup(profile);
      },
    );
  }

  Future<void> _fetchAndRefresh() async {
    try {
      final repository = _ref.read(profileRepositoryProvider);
      final result = await repository.getProfile(userId);

      result.fold(
        (failure) {
          // En cas d'echec silencieux, on garde la version en cache
        },
        (profile) {
          // Mise a jour de l'etat avec les donnees fraiches
          state = AsyncValue.data(profile);
          _maybeJoinCountryGroup(profile);
        },
      );
    } catch (e) {
      // Erreur inattendue ignoree pour ne pas crasher l'UI
    }
  }

  /// Rattache l'utilisateur au groupe officiel de son pays au chargement du
  /// profil (une seule fois par session). Idempotent côté backend.
  void _maybeJoinCountryGroup(ProfileEntity? profile) {
    if (_countryGroupJoinAttempted) return;
    if (profile == null) return;
    if (profile.countryCode == null || profile.countryCode!.isEmpty) return;
    _countryGroupJoinAttempted = true;
    // Best-effort, ne bloque jamais l'UI.
    _joinOfficialCountryGroup(profile);
  }

  /// Écriture **optimiste** : l'état porte la valeur demandée dès l'appel, et
  /// n'est corrigé qu'en cas de refus du serveur.
  ///
  /// Il passait auparavant par `AsyncValue.loading()`, ce qui vidait le profil
  /// le temps de l'aller-retour. Deux conséquences, l'une visible et l'autre
  /// pas : une bascule de réglage revenait en arrière sous le doigt pendant
  /// l'écriture, et surtout tout appelant qui relisait `valueOrNull` juste
  /// après — c'est le cas de la sauvegarde des réglages — tombait sur `null`
  /// et **abandonnait la sauvegarde en silence** quand deux gestes se
  /// suivaient de près.
  ///
  /// `copyWithPrevious` conserve la dernière donnée connue sous l'erreur :
  /// `hasError` reste vrai pour les appelants qui affichent un message, mais
  /// l'écran ne se vide pas.
  Future<void> updateProfile(ProfileEntity profile) async {
    final previous = state;
    state = AsyncValue.data(profile);

    final repository = _ref.read(profileRepositoryProvider);
    final result = await repository.updateProfile(profile);

    result.fold(
      (failure) =>
          state = AsyncValue<ProfileEntity?>.error(
            failure.message,
            StackTrace.current,
          ).copyWithPrevious(previous),
      (updatedProfile) {
        state = AsyncValue.data(updatedProfile);
        // Best-effort : ne doit jamais faire echouer la sauvegarde du profil.
        _joinOfficialCountryGroup(updatedProfile);
      },
    );
  }

  /// Rattache l'utilisateur au groupe officiel de son pays (cree s'il n'existe
  /// pas encore). Echec silencieux : ce n'est qu'un enrichissement auxiliaire.
  Future<void> _joinOfficialCountryGroup(ProfileEntity profile) async {
    final countryCode = profile.countryCode;
    if (countryCode == null || countryCode.isEmpty) return;

    try {
      final groupRepository = _ref.read(groupRepositoryProvider);
      final groupResult = await groupRepository.ensureOfficialGroup(
        countryCode: countryCode,
        countryName: profile.currentCountry ?? countryCode,
      );
      await groupResult.fold((failure) async {}, (group) async {
        await groupRepository.joinGroup(group.id, profile.id);
      });
    } catch (_) {}
  }

  Future<String?> uploadPhoto(String filePath) async {
    final repository = _ref.read(profileRepositoryProvider);
    final result = await repository.uploadProfilePhoto(userId, filePath);

    return result.fold((failure) => null, (url) {
      // Recharger le profil pour obtenir la nouvelle photo
      _loadProfile();
      return url;
    });
  }

  Future<void> updateLocation(double lat, double lng) async {
    final repository = _ref.read(profileRepositoryProvider);
    await repository.updateLocation(userId, lat, lng);
    // Mise a jour silencieuse
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    await _loadProfile();
  }
}

/// Provider pour les profils a proximite
final nearbyProfilesNotifierProvider = StateNotifierProvider<
  NearbyProfilesNotifier,
  AsyncValue<List<ProfileEntity>>
>((ref) {
  return NearbyProfilesNotifier(ref);
});

/// Notifier pour gerer les profils a proximite
class NearbyProfilesNotifier
    extends StateNotifier<AsyncValue<List<ProfileEntity>>> {
  final Ref _ref;

  // État initial « loading » (et non liste vide) pour que l'accueil affiche le
  // squelette avant le premier chargement, jamais un état vide (maquette
  // 1b/CAS 3 : « jamais de texte vide avant la fin du chargement »).
  NearbyProfilesNotifier(this._ref) : super(const AsyncValue.loading());

  Future<void> loadNearbyProfiles(
    double lat,
    double lng, {
    double radiusKm = 50,
  }) async {
    state = const AsyncValue.loading();

    final repository = _ref.read(profileRepositoryProvider);
    final result = await repository.getNearbyProfiles(lat, lng, radiusKm);

    result.fold(
      (failure) =>
          state = AsyncValue.error(failure.message, StackTrace.current),
      (profiles) {
        // Exclure l'utilisateur courant : on ne s'affiche pas dans sa propre
        // liste de membres à proximité.
        final currentUserId = _ref.read(currentUserProvider).valueOrNull?.id;

        // Choix produit : afficher tout membre proche ayant une position
        // connue, sans filtre de fraîcheur de présence (le dépôt renvoie déjà
        // les profils visibles dans le rayon). Seul l'utilisateur courant est
        // écarté.
        final filteredProfiles =
            profiles
                .where((p) => currentUserId == null || p.id != currentUserId)
                .toList();

        state = AsyncValue.data(filteredProfiles);
      },
    );
  }

  /// Vide imm\u00e9diatement la liste (utilis\u00e9 quand l'utilisateur active le mode priv\u00e9).
  void clear() {
    state = const AsyncValue.data([]);
  }
}

/// Provider pour le toggle "Membres \u00e0 proximit\u00e9".
/// Quand `false`, l'utilisateur est en mode priv\u00e9 : aucun membre n'est affich\u00e9
/// sur l'accueil/la carte ET sa propre position n'est plus envoy\u00e9e \u00e0 Firestore.
final nearbyMembersEnabledProvider =
    StateNotifierProvider<NearbyMembersEnabledNotifier, bool>(
      (ref) => NearbyMembersEnabledNotifier(ref),
    );

class NearbyMembersEnabledNotifier extends StateNotifier<bool> {
  final Ref _ref;

  NearbyMembersEnabledNotifier(this._ref)
    : super(PreferencesService.instance.nearbyMembersEnabled);

  Future<void> setEnabled(bool value) async {
    if (state == value) return;
    await PreferencesService.instance.setNearbyMembersEnabled(value);
    state = value;
    if (!value) {
      // Vider imm\u00e9diatement les profils \u00e0 proximit\u00e9 d\u00e9j\u00e0 charg\u00e9s
      _ref.read(nearbyProfilesNotifierProvider.notifier).clear();
      // ... et cesser d'\u00e9mettre la sienne : le service tourne d\u00e9sormais
      // pour toute l'app, il ne s'arr\u00eate plus en quittant l'\u00e9cran carte.
      LocationPublisherService.instance.stop();
    } else {
      await LocationPublisherService.instance.start();
    }
  }

  Future<void> toggle() => setEnabled(!state);
}

/// Provider pour la recherche de profils
final searchProfilesNotifierProvider = StateNotifierProvider<
  SearchProfilesNotifier,
  AsyncValue<List<ProfileEntity>>
>((ref) {
  return SearchProfilesNotifier(ref);
});

/// Notifier pour gerer la recherche de profils
class SearchProfilesNotifier
    extends StateNotifier<AsyncValue<List<ProfileEntity>>> {
  final Ref _ref;

  SearchProfilesNotifier(this._ref) : super(const AsyncValue.data([]));

  Future<void> search(String query) async {
    if (query.isEmpty) {
      state = const AsyncValue.data([]);
      return;
    }

    state = const AsyncValue.loading();

    final repository = _ref.read(profileRepositoryProvider);
    final result = await repository.searchProfiles(query);

    result.fold(
      (failure) =>
          state = AsyncValue.error(failure.message, StackTrace.current),
      (profiles) => state = AsyncValue.data(profiles),
    );
  }

  void clear() {
    state = const AsyncValue.data([]);
  }
}

/// Provider pour le stream d'un utilisateur.
///
/// Sémantique de la valeur émise :
///   - ProfileEntity  → profil chargé
///   - null           → compte RÉELLEMENT introuvable (NotFoundFailure) →
///                      l'UI peut afficher « Profil supprimé »
///   - AsyncError     → erreur transitoire (réseau, RLS, session non établie) →
///                      l'UI affiche un état d'erreur/réessayer, jamais « supprimé »
final userStreamProvider = StreamProvider.family<ProfileEntity?, String>((
  ref,
  userId,
) {
  return ref
      .watch(profileRepositoryProvider)
      .getUserStream(userId)
      .map(
        (either) => either.fold((failure) {
          // Seul un profil réellement absent devient null (= supprimé).
          if (failure is NotFoundFailure) return null;
          // Toute autre erreur est propagée comme erreur du stream.
          throw failure;
        }, (profile) => profile),
      );
});
