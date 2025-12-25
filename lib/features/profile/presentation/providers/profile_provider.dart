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
  AsyncValue<ProfileEntity?> build() {
    return const AsyncValue.data(null);
  }

  Future<void> loadProfile(String userId) async {
    state = const AsyncValue.loading();

    final repository = ref.read(profileRepositoryProvider);
    final result = await repository.getProfile(userId);

    result.fold(
      (failure) =>
          state = AsyncValue.error(failure.message, StackTrace.current),
      (profile) => state = AsyncValue.data(profile),
    );
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
        // No need to refresh AuthNotifier - screens already watch ProfileNotifier
        // which updates immediately. AuthNotifier will sync naturally on next app start.
      },
    );
  }

  Future<String?> uploadPhoto(String userId, String filePath) async {
    final repository = ref.read(profileRepositoryProvider);
    final result = await repository.uploadProfilePhoto(userId, filePath);

    return result.fold((failure) => null, (url) {
      // No need to refresh AuthNotifier - photo URL will be updated
      // in ProfileNotifier when profile is reloaded or updated
      return url;
    });
  }

  Future<void> updateLocation(String userId, double lat, double lng) async {
    final repository = ref.read(profileRepositoryProvider);
    await repository.updateLocation(userId, lat, lng);
  }
}

@riverpod
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
      (profiles) => state = AsyncValue.data(profiles),
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
