import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/network/network_info.dart';
import '../../data/datasources/business_remote_datasource.dart';
import '../../data/repositories/business_repository_impl.dart';
import '../../domain/entities/business_entity.dart';
import '../../domain/entities/business_boost_entity.dart';
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
      return true;
    });
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
