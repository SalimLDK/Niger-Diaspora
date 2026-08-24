import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../../core/network/network_info.dart';
import '../../data/datasources/business_remote_datasource.dart';
import '../../data/models/business_post_model.dart';
import '../../data/repositories/business_repository_impl.dart';
import '../../domain/entities/business_entity.dart';
import '../../domain/entities/business_boost_entity.dart';
import '../../domain/entities/business_post_entity.dart';
import '../../domain/repositories/business_repository.dart';

part 'business_provider.g.dart';

// Data sources and repositories

@riverpod
BusinessRemoteDataSource businessRemoteDataSource(Ref ref) {
  return BusinessRemoteDataSourceImpl();
}

@riverpod
BusinessRepository businessRepository(Ref ref) {
  return BusinessRepositoryImpl(
    remoteDataSource: ref.watch(businessRemoteDataSourceProvider),
    networkInfo: ref.watch(networkInfoProvider),
  );
}

// All businesses list

@Riverpod(keepAlive: true)
class BusinessesNotifier extends _$BusinessesNotifier {
  @override
  AsyncValue<List<BusinessEntity>> build() {
    loadBusinesses();
    return const AsyncValue.loading();
  }

  Future<void> loadBusinesses({bool featuredFirst = true}) async {
    state = const AsyncValue.loading();
    final repository = ref.read(businessRepositoryProvider);
    final result = await repository.getBusinesses(featuredFirst: featuredFirst);
    result.fold(
      (failure) =>
          state = AsyncValue.error(failure.message, StackTrace.current),
      (businesses) => state = AsyncValue.data(businesses),
    );
  }

  Future<void> loadByCategory(BusinessCategory category) async {
    state = const AsyncValue.loading();
    final repository = ref.read(businessRepositoryProvider);
    final result = await repository.getBusinessesByCategory(category);
    result.fold(
      (failure) =>
          state = AsyncValue.error(failure.message, StackTrace.current),
      (businesses) => state = AsyncValue.data(businesses),
    );
  }

  Future<void> searchBusinesses(String query) async {
    if (query.isEmpty) {
      await loadBusinesses();
      return;
    }
    state = const AsyncValue.loading();
    final repository = ref.read(businessRepositoryProvider);
    final result = await repository.searchBusinesses(query);
    result.fold(
      (failure) =>
          state = AsyncValue.error(failure.message, StackTrace.current),
      (businesses) => state = AsyncValue.data(businesses),
    );
  }

  Future<void> loadNearbyBusinesses(
    double lat,
    double lng, {
    double radiusKm = 50,
  }) async {
    state = const AsyncValue.loading();
    final repository = ref.read(businessRepositoryProvider);
    final result = await repository.getNearbyBusinesses(lat, lng, radiusKm);
    result.fold(
      (failure) =>
          state = AsyncValue.error(failure.message, StackTrace.current),
      (businesses) => state = AsyncValue.data(businesses),
    );
  }

  Future<void> loadByLocation({String? country, String? city}) async {
    state = const AsyncValue.loading();
    final repository = ref.read(businessRepositoryProvider);
    final result = await repository.getBusinessesByLocation(
      country: country,
      city: city,
    );
    result.fold(
      (failure) =>
          state = AsyncValue.error(failure.message, StackTrace.current),
      (businesses) => state = AsyncValue.data(businesses),
    );
  }

  Future<void> refresh() async {
    await loadBusinesses();
  }
}

// Single business detail

@riverpod
class BusinessDetailNotifier extends _$BusinessDetailNotifier {
  @override
  AsyncValue<BusinessEntity?> build() {
    return const AsyncValue.data(null);
  }

  Future<void> loadBusiness(String id) async {
    state = const AsyncValue.loading();
    final repository = ref.read(businessRepositoryProvider);
    final result = await repository.getBusinessById(id);
    result.fold(
      (failure) =>
          state = AsyncValue.error(failure.message, StackTrace.current),
      (business) {
        state = AsyncValue.data(business);
        // Increment view count in background
        repository.incrementViewCount(id);
      },
    );
  }
}

// Current user's business

@Riverpod(keepAlive: true)
class MyBusinessNotifier extends _$MyBusinessNotifier {
  @override
  AsyncValue<BusinessEntity?> build() {
    final user = ref.watch(currentUserProvider).valueOrNull;
    if (user != null) {
      loadMyBusiness(user.id);
    }
    return const AsyncValue.loading();
  }

  Future<void> loadMyBusiness(String ownerId) async {
    state = const AsyncValue.loading();
    final repository = ref.read(businessRepositoryProvider);
    final result = await repository.getMyBusiness(ownerId);
    result.fold(
      (failure) =>
          state = AsyncValue.error(failure.message, StackTrace.current),
      (business) => state = AsyncValue.data(business),
    );
  }

  Future<bool> createBusiness(BusinessEntity business) async {
    final repository = ref.read(businessRepositoryProvider);
    final result = await repository.createBusiness(business);
    return result.fold((failure) => false, (created) {
      state = AsyncValue.data(created);
      // Refresh the global list
      ref.read(businessesNotifierProvider.notifier).refresh();
      ref.invalidate(myBusinessesNotifierProvider);
      return true;
    });
  }

  Future<bool> updateBusiness(BusinessEntity business) async {
    final repository = ref.read(businessRepositoryProvider);
    final result = await repository.updateBusiness(business);
    return result.fold((failure) => false, (updated) {
      state = AsyncValue.data(updated);
      // Refresh the global list
      ref.read(businessesNotifierProvider.notifier).refresh();
      ref.invalidate(myBusinessesNotifierProvider);
      return true;
    });
  }

  Future<bool> deleteBusiness(String id) async {
    final repository = ref.read(businessRepositoryProvider);
    final result = await repository.deleteBusiness(id);
    return result.fold((failure) => false, (_) {
      state = const AsyncValue.data(null);
      // Refresh the global list
      ref.read(businessesNotifierProvider.notifier).refresh();
      ref.invalidate(myBusinessesNotifierProvider);
      return true;
    });
  }
}

// Current user's businesses — liste (§19c : un propriétaire peut en avoir
// plusieurs). Provider manuel pour éviter un cycle build_runner.
final myBusinessesNotifierProvider =
    AsyncNotifierProvider<MyBusinessesNotifier, List<BusinessEntity>>(
  MyBusinessesNotifier.new,
);

class MyBusinessesNotifier extends AsyncNotifier<List<BusinessEntity>> {
  @override
  Future<List<BusinessEntity>> build() async {
    final user = ref.watch(currentUserProvider).valueOrNull;
    if (user == null) return const [];
    final repository = ref.read(businessRepositoryProvider);
    final result = await repository.getMyBusinesses(user.id);
    return result.fold(
      (failure) => throw Exception(failure.message),
      (businesses) => businesses,
    );
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    ref.invalidateSelf();
    await future;
  }
}

// Boost management

@riverpod
class BoostNotifier extends _$BoostNotifier {
  @override
  AsyncValue<BusinessBoostEntity?> build() {
    return const AsyncValue.data(null);
  }

  Future<void> loadActiveBoost(String businessId) async {
    state = const AsyncValue.loading();
    final repository = ref.read(businessRepositoryProvider);
    final result = await repository.getActiveBoost(businessId);
    result.fold(
      (failure) =>
          state = AsyncValue.error(failure.message, StackTrace.current),
      (boost) => state = AsyncValue.data(boost),
    );
  }

  Future<bool> purchaseBoost({
    required String businessId,
    required BoostType type,
    required BoostDuration duration,
    String paymentMethod = 'stripe',
  }) async {
    final repository = ref.read(businessRepositoryProvider);
    final result = await repository.purchaseBoost(
      businessId: businessId,
      type: type,
      duration: duration,
      paymentMethod: paymentMethod, // Selected payment method
    );
    return result.fold((failure) => false, (boost) {
      state = AsyncValue.data(boost);
      // Refresh the business to reflect boost status
      ref
          .read(myBusinessNotifierProvider.notifier)
          .loadMyBusiness(ref.read(currentUserAsyncProvider).valueOrNull?.id ?? '');
      ref.read(businessesNotifierProvider.notifier).refresh();
      return true;
    });
  }
}

// Boost history

@riverpod
class BoostHistoryNotifier extends _$BoostHistoryNotifier {
  @override
  AsyncValue<List<BusinessBoostEntity>> build() {
    return const AsyncValue.data([]);
  }

  Future<void> loadBoostHistory(String businessId) async {
    state = const AsyncValue.loading();
    final repository = ref.read(businessRepositoryProvider);
    final result = await repository.getBoostHistory(businessId);
    result.fold(
      (failure) =>
          state = AsyncValue.error(failure.message, StackTrace.current),
      (boosts) => state = AsyncValue.data(boosts),
    );
  }
}

// Selected category filter

@riverpod
class SelectedBusinessCategory extends _$SelectedBusinessCategory {
  @override
  BusinessCategory? build() {
    return null;
  }

  void select(BusinessCategory? category) {
    state = category;
    if (category != null) {
      ref.read(businessesNotifierProvider.notifier).loadByCategory(category);
    } else {
      ref.read(businessesNotifierProvider.notifier).loadBusinesses();
    }
  }

  void clear() {
    state = null;
    ref.read(businessesNotifierProvider.notifier).loadBusinesses();
  }
}

// Location filter for businesses
class BusinessLocationFilter {
  final String? country;
  final String? city;
  final bool useMyLocation;

  const BusinessLocationFilter({
    this.country,
    this.city,
    this.useMyLocation = false,
  });

  bool get hasFilter => country != null || city != null || useMyLocation;

  BusinessLocationFilter copyWith({
    String? country,
    String? city,
    bool? useMyLocation,
  }) {
    return BusinessLocationFilter(
      country: country ?? this.country,
      city: city ?? this.city,
      useMyLocation: useMyLocation ?? this.useMyLocation,
    );
  }
}

@Riverpod(keepAlive: true)
class SelectedBusinessLocation extends _$SelectedBusinessLocation {
  @override
  BusinessLocationFilter build() {
    // Try to load user's location from profile
    _loadUserLocation();
    return const BusinessLocationFilter();
  }

  void _loadUserLocation() {
    final user = ref.read(currentUserAsyncProvider).valueOrNull;
    if (user != null) {
      final profile = ref.read(profileNotifierProvider(user.id)).valueOrNull;
      if (profile != null && profile.currentCountry != null) {
        state = BusinessLocationFilter(
          country: profile.currentCountry,
          city: profile.currentCity,
          useMyLocation: true,
        );
        _applyFilter();
      }
    }
  }

  void setCountry(String? country) {
    state = BusinessLocationFilter(
      country: country,
      city: state.city,
      useMyLocation: false,
    );
    _applyFilter();
  }

  void setCity(String? city) {
    state = BusinessLocationFilter(
      country: state.country,
      city: city,
      useMyLocation: false,
    );
    _applyFilter();
  }

  void useMyLocation() {
    final user = ref.read(currentUserAsyncProvider).valueOrNull;
    if (user != null) {
      final profile = ref.read(profileNotifierProvider(user.id)).valueOrNull;
      if (profile != null) {
        state = BusinessLocationFilter(
          country: profile.currentCountry,
          city: profile.currentCity,
          useMyLocation: true,
        );
        _applyFilter();
      }
    }
  }

  void clear() {
    state = const BusinessLocationFilter();
    ref.read(businessesNotifierProvider.notifier).loadBusinesses();
  }

  void _applyFilter() {
    final notifier = ref.read(businessesNotifierProvider.notifier);
    if (state.city != null && state.city!.isNotEmpty) {
      notifier.loadByLocation(country: state.country, city: state.city);
    } else if (state.country != null && state.country!.isNotEmpty) {
      notifier.loadByLocation(country: state.country);
    } else {
      notifier.loadBusinesses();
    }
  }
}

// ============ BUSINESS POSTS ============

@riverpod
class BusinessPostsNotifier extends _$BusinessPostsNotifier {
  @override
  AsyncValue<List<BusinessPostEntity>> build(String businessId) {
    loadPosts(businessId);
    return const AsyncValue.loading();
  }

  Future<void> loadPosts(String businessId) async {
    state = const AsyncValue.loading();
    try {
      final dataSource = ref.read(businessRemoteDataSourceProvider);
      final posts = await dataSource.getBusinessPosts(businessId);
      state = AsyncValue.data(posts.map((m) => m.toEntity()).toList());
    } catch (e) {
      state = AsyncValue.error(e.toString(), StackTrace.current);
    }
  }

  Future<void> refresh(String businessId) async {
    await loadPosts(businessId);
  }
}

@riverpod
class BusinessOffersNotifier extends _$BusinessOffersNotifier {
  @override
  AsyncValue<List<BusinessPostEntity>> build(String businessId) {
    loadOffers(businessId);
    return const AsyncValue.loading();
  }

  Future<void> loadOffers(String businessId) async {
    state = const AsyncValue.loading();
    try {
      final dataSource = ref.read(businessRemoteDataSourceProvider);
      final offers = await dataSource.getActiveOffers(businessId);
      state = AsyncValue.data(offers.map((m) => m.toEntity()).toList());
    } catch (e) {
      state = AsyncValue.error(e.toString(), StackTrace.current);
    }
  }
}

@riverpod
class BusinessPostActions extends _$BusinessPostActions {
  @override
  FutureOr<void> build() {}

  Future<BusinessPostEntity?> createPost(BusinessPostEntity post) async {
    state = const AsyncLoading();
    try {
      final dataSource = ref.read(businessRemoteDataSourceProvider);
      final model = BusinessPostModel.fromEntity(post);
      final created = await dataSource.createPost(model);
      state = const AsyncData(null);
      // Refresh the posts list
      ref.invalidate(businessPostsNotifierProvider(post.businessId));
      ref.invalidate(businessOffersNotifierProvider(post.businessId));
      return created.toEntity();
    } catch (e) {
      state = AsyncError(e.toString(), StackTrace.current);
      return null;
    }
  }

  Future<bool> deletePost(String postId, String businessId) async {
    state = const AsyncLoading();
    try {
      final dataSource = ref.read(businessRemoteDataSourceProvider);
      await dataSource.deletePost(postId);
      state = const AsyncData(null);
      // Refresh the posts list
      ref.invalidate(businessPostsNotifierProvider(businessId));
      ref.invalidate(businessOffersNotifierProvider(businessId));
      return true;
    } catch (e) {
      state = AsyncError(e.toString(), StackTrace.current);
      return false;
    }
  }
}
