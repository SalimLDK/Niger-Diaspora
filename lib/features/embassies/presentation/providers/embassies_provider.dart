import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/network_info.dart';
import '../../data/datasources/embassies_local_datasource.dart';
import '../../data/datasources/embassy_remote_datasource.dart';
import '../../data/repositories/embassies_repository_impl.dart';
import '../../domain/entities/embassy_entity.dart';
import '../../domain/repositories/embassies_repository.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';

part 'embassies_provider.g.dart';

// Data Source Provider
@riverpod
EmbassiesLocalDataSource embassiesLocalDataSource(Ref ref) {
  return EmbassiesLocalDataSource();
}

// Repository Provider
@riverpod
EmbassiesRepository embassiesRepository(Ref ref) {
  final remoteDataSource = EmbassyRemoteDataSourceImpl();
  final localDataSource = ref.watch(embassiesLocalDataSourceProvider);
  final networkInfo = ref.watch(networkInfoProvider);

  // EmbassyRepositoryImpl should implement EmbassiesRepository
  return EmbassiesRepositoryImpl(
    remoteDataSource: remoteDataSource,
    localDataSource: localDataSource,
    networkInfo: networkInfo,
  );
}

// Imports moved to top

// Embassies List Provider
@Riverpod(keepAlive: true)
Future<List<EmbassyEntity>> embassiesList(Ref ref) async {
  // 1. Get Current User (for Admin check)
  final userAsync = ref.watch(currentUserAsyncProvider);
  final user = userAsync.value;

  if (user == null) return [];

  // 2. Get User Profile (for Location/Jurisdiction check)
  // We handle the AsyncValue from the stream provider
  final profileAsync = ref.watch(userStreamProvider(user.id));
  final profile = profileAsync.value;

  // 3. Fetch all embassies
  final repository = ref.watch(embassiesRepositoryProvider);
  // Force reload to ensure we get fresh data especially if local datasource changed
  final allEmbassies = await repository.getEmbassies();

  // 4. Admin Bypass
  if (user.isAdmin) {
    return allEmbassies;
  }

  // 5. Filter for Normal Users
  return allEmbassies.where((e) {
    // Must be verified and not suspended
    if (!e.isVerified || e.isSuspended) return false;

    // Check Jurisdiction
    if (e.jurisdictionCountries.isNotEmpty) {
      final userCountry = profile?.currentCountry;
      if (userCountry == null) {
        return false;
      }

      // Check if user's country is in jurisdiction
      // Case-insensitive check recommended
      return e.jurisdictionCountries.any(
        (c) => c.toLowerCase() == userCountry.toLowerCase(),
      );
    }

    // If no jurisdiction specified, assume global/visible
    return true;
  }).toList();
}

// Search/Filter Interface
class EmbassiesState {
  final AsyncValue<List<EmbassyEntity>> embassies;
  final String searchQuery;

  EmbassiesState({required this.embassies, this.searchQuery = ''});

  EmbassiesState copyWith({
    AsyncValue<List<EmbassyEntity>>? embassies,
    String? searchQuery,
  }) {
    return EmbassiesState(
      embassies: embassies ?? this.embassies,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

@riverpod
class EmbassiesController extends _$EmbassiesController {
  @override
  EmbassiesState build() {
    final embassiesAsync = ref.watch(embassiesListProvider);
    return EmbassiesState(embassies: embassiesAsync);
  }

  void search(String query) {
    state = state.copyWith(searchQuery: query);
  }

  List<EmbassyEntity> get filteredEmbassies {
    return state.embassies.when(
      data: (list) {
        if (state.searchQuery.isEmpty) return list;
        final lowerQuery = state.searchQuery.toLowerCase();
        return list.where((e) {
          return e.name.toLowerCase().contains(lowerQuery) ||
              e.country.toLowerCase().contains(lowerQuery) ||
              e.city.toLowerCase().contains(lowerQuery);
        }).toList();
      },
      loading: () => [],
      error: (_, __) => [],
    );
  }
}
