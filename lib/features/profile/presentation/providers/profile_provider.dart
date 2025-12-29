// import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/network/network_info.dart';
import '../../data/datasources/profile_remote_datasource.dart';
import '../../data/repositories/profile_repository_impl.dart';
import '../../domain/entities/profile_entity.dart';
import '../../domain/repositories/profile_repository.dart';

part 'profile_provider.g.dart';

@riverpod
ProfileRemoteDataSource profileRemoteDataSource(Ref ref) {
  return ProfileRemoteDataSourceImpl();
}

@riverpod
ProfileRepository profileRepository(Ref ref) {
  return ProfileRepositoryImpl(
    remoteDataSource: ref.watch(profileRemoteDataSourceProvider),
    networkInfo: ref.watch(networkInfoProvider),
  );
}

@Riverpod(keepAlive: true)
class ProfileNotifier extends _$ProfileNotifier {
  @override
  Future<ProfileEntity?> build(String userId) async {
    final repository = ref.read(profileRepositoryProvider);

    // 1. Tenter de charger depuis le cache
    // C'est la stratégie "Stale-While-Revalidate" : afficher le cache tout de suite,
    // puis rafraîchir en arrière-plan.
    final cachedResult = repository.getCachedProfile(userId);
    ProfileEntity? cachedProfile;

    cachedResult.fold((l) => null, (r) => cachedProfile = r);

    if (cachedProfile != null) {
      // Si on a un cache, on le retourne immédiatement pour l'affichage
      // Et on lance le rafraîchissement en arrière-plan
      Future.microtask(() => _fetchAndRefresh(userId));
      return cachedProfile;
    }

    // 2. Si pas de cache, on charge normalement (avec le loading UI par défaut)
    final result = await repository.getProfile(userId);

    return result.fold((failure) {
      throw Exception(failure.message);
    }, (profile) => profile);
  }

  Future<void> _fetchAndRefresh(String userId) async {
    try {
      final repository = ref.read(profileRepositoryProvider);
      final result = await repository.getProfile(userId);

      result.fold(
        (failure) {
          // En cas d'échec silencieux (pas de réseau par exemple),
          // on garde simplement la version en cache sans erreur.
          // debugPrint('⚠️ Profile refresh failed (keeping cache): ${failure.message}');
        },
        (profile) {
          // Mise à jour de l'état avec les données fraîches
          state = AsyncValue.data(profile);
        },
      );
    } catch (
      e //, stackTrace
    ) {
      // Erreur inattendue ignorée pour ne pas crasher l'UI qui a déjà des données (cache)
      // debugPrint('❌ Unexpected error refreshing profile: $e');
      // debugPrint('   Stack trace: $stackTrace');
    }
  }

  Future<void> updateProfile(ProfileEntity profile) async {
    state = const AsyncValue.loading();

    final repository = ref.read(profileRepositoryProvider);
    final result = await repository.updateProfile(profile);

    result.fold(
      (failure) =>
          state = AsyncValue.error(failure.message, StackTrace.current),
      (updatedProfile) {
        state = AsyncValue.data(updatedProfile);
      },
    );
  }

  Future<String?> uploadPhoto(String filePath) async {
    final repository = ref.read(profileRepositoryProvider);
    final result = await repository.uploadProfilePhoto(userId, filePath);

    return result.fold((failure) => null, (url) {
      // Force refresh or optimistic update?
      // The repository updateProfilePhoto typically prepares the backend.
      // We might want to reload the profile or manually update the state if we had the URL.
      // For now, let's reload to get the fresh profile with new photo
      ref.invalidateSelf();
      return url;
    });
  }

  Future<void> updateLocation(double lat, double lng) async {
    final repository = ref.read(profileRepositoryProvider);
    await repository.updateLocation(userId, lat, lng);
    // Silent update, no state change info needing reflect immediately usually
  }
}

@Riverpod(keepAlive: true)
class NearbyProfilesNotifier extends _$NearbyProfilesNotifier {
  @override
  AsyncValue<List<ProfileEntity>> build() {
    return const AsyncValue.data([]);
  }

  Future<void> loadNearbyProfiles(
    double lat,
    double lng, {
    double radiusKm = 50,
  }) async {
    state = const AsyncValue.loading();

    final repository = ref.read(profileRepositoryProvider);
    final result = await repository.getNearbyProfiles(lat, lng, radiusKm);

    result.fold(
      (failure) =>
          state = AsyncValue.error(failure.message, StackTrace.current),
      (profiles) {
        // Filter by presence:
        // 1. Online
        // 2. OR Location updated within last 5 minutes (as requested)
        final now = DateTime.now();
        final filteredProfiles =
            profiles.where((p) {
              if (p.isOnline) {
                // Determine if "Online" status is stale (Phantom user check)
                // App sends heartbeat every 10 min. If no update for 20 min, treat as offline.
                if (p.lastSeen != null) {
                  final diffOnline = now.difference(p.lastSeen!);
                  if (diffOnline.inMinutes < 20) return true;
                }
              }

              if (p.locationUpdatedAt != null) {
                final diffLocation = now.difference(p.locationUpdatedAt!);
                // Use 330 seconds (5m 30s) threshold
                // (background update is every 5 min + 30s margin)
                if (diffLocation.inSeconds < 330) return true;
              }

              return false;
            }).toList();

        state = AsyncValue.data(filteredProfiles);
      },
    );
  }
}

@riverpod
class SearchProfilesNotifier extends _$SearchProfilesNotifier {
  @override
  AsyncValue<List<ProfileEntity>> build() {
    return const AsyncValue.data([]);
  }

  Future<void> search(String query) async {
    if (query.isEmpty) {
      state = const AsyncValue.data([]);
      return;
    }

    state = const AsyncValue.loading();

    final repository = ref.read(profileRepositoryProvider);
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

@riverpod
Stream<ProfileEntity?> userStream(Ref ref, String userId) {
  return ref
      .watch(profileRepositoryProvider)
      .getUserStream(userId)
      .map((either) => either.fold((failure) => null, (profile) => profile));
}
