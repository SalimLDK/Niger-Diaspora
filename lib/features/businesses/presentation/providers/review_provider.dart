import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/network/network_info.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/review_remote_datasource.dart';
import '../../data/repositories/review_repository_impl.dart';
import '../../domain/entities/review_entity.dart';
import '../../domain/repositories/review_repository.dart';

part 'review_provider.g.dart';

// Data sources and repositories

@riverpod
ReviewRemoteDataSource reviewRemoteDataSource(Ref ref) {
  return ReviewRemoteDataSourceImpl();
}

@riverpod
ReviewRepository reviewRepository(Ref ref) {
  return ReviewRepositoryImpl(
    remoteDataSource: ref.watch(reviewRemoteDataSourceProvider),
    networkInfo: ref.watch(networkInfoProvider),
  );
}

// Reviews for a business

@riverpod
class BusinessReviewsNotifier extends _$BusinessReviewsNotifier {
  @override
  AsyncValue<List<ReviewEntity>> build(String businessId) {
    loadReviews(businessId);
    return const AsyncValue.loading();
  }

  Future<void> loadReviews(String businessId) async {
    state = const AsyncValue.loading();
    final repository = ref.read(reviewRepositoryProvider);
    final result = await repository.getReviewsForBusiness(businessId);
    result.fold(
      (failure) => state = AsyncValue.error(failure.message, StackTrace.current),
      (reviews) => state = AsyncValue.data(reviews),
    );
  }

  Future<void> refresh(String businessId) async {
    await loadReviews(businessId);
  }
}

// User's review for a specific business (to check if they already reviewed)

@riverpod
class UserBusinessReviewNotifier extends _$UserBusinessReviewNotifier {
  @override
  AsyncValue<ReviewEntity?> build(String businessId) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    if (user != null) {
      loadUserReview(businessId, user.id);
    }
    return const AsyncValue.loading();
  }

  Future<void> loadUserReview(String businessId, String userId) async {
    state = const AsyncValue.loading();
    final repository = ref.read(reviewRepositoryProvider);
    final result = await repository.getUserReviewForBusiness(userId, businessId);
    result.fold(
      (failure) => state = AsyncValue.error(failure.message, StackTrace.current),
      (review) => state = AsyncValue.data(review),
    );
  }
}

// User's reviews (all reviews by the current user)

@riverpod
class UserReviewsNotifier extends _$UserReviewsNotifier {
  @override
  AsyncValue<List<ReviewEntity>> build() {
    final user = ref.watch(currentUserProvider).valueOrNull;
    if (user != null) {
      loadUserReviews(user.id);
    }
    return const AsyncValue.loading();
  }

  Future<void> loadUserReviews(String userId) async {
    state = const AsyncValue.loading();
    final repository = ref.read(reviewRepositoryProvider);
    final result = await repository.getUserReviews(userId);
    result.fold(
      (failure) => state = AsyncValue.error(failure.message, StackTrace.current),
      (reviews) => state = AsyncValue.data(reviews),
    );
  }
}

// Review actions (create, update, delete, helpful, report)

@riverpod
class ReviewActionsNotifier extends _$ReviewActionsNotifier {
  @override
  FutureOr<void> build() {}

  Future<ReviewEntity?> createReview(ReviewEntity review) async {
    state = const AsyncLoading();
    final repository = ref.read(reviewRepositoryProvider);
    final result = await repository.createReview(review);
    return result.fold(
      (failure) {
        state = AsyncError(failure.message, StackTrace.current);
        return null;
      },
      (created) {
        state = const AsyncData(null);
        // Refresh the business reviews list
        ref.invalidate(businessReviewsNotifierProvider(review.businessId));
        // Refresh user's review for this business
        ref.invalidate(userBusinessReviewNotifierProvider(review.businessId));
        // Refresh user's reviews list
        ref.invalidate(userReviewsNotifierProvider);
        return created;
      },
    );
  }

  Future<bool> updateReview(ReviewEntity review) async {
    state = const AsyncLoading();
    final repository = ref.read(reviewRepositoryProvider);
    final result = await repository.updateReview(review);
    return result.fold(
      (failure) {
        state = AsyncError(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncData(null);
        // Refresh lists
        ref.invalidate(businessReviewsNotifierProvider(review.businessId));
        ref.invalidate(userBusinessReviewNotifierProvider(review.businessId));
        ref.invalidate(userReviewsNotifierProvider);
        return true;
      },
    );
  }

  Future<bool> deleteReview(String reviewId, String businessId) async {
    state = const AsyncLoading();
    final repository = ref.read(reviewRepositoryProvider);
    final result = await repository.deleteReview(reviewId);
    return result.fold(
      (failure) {
        state = AsyncError(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncData(null);
        // Refresh lists
        ref.invalidate(businessReviewsNotifierProvider(businessId));
        ref.invalidate(userBusinessReviewNotifierProvider(businessId));
        ref.invalidate(userReviewsNotifierProvider);
        return true;
      },
    );
  }

  Future<bool> toggleHelpful(String reviewId, String businessId, bool currentlyHelpful) async {
    final repository = ref.read(reviewRepositoryProvider);
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return false;

    final result = currentlyHelpful
        ? await repository.unmarkHelpful(reviewId, user.id)
        : await repository.markHelpful(reviewId, user.id);

    return result.fold(
      (failure) => false,
      (_) {
        // Refresh the reviews list to update helpful count
        ref.invalidate(businessReviewsNotifierProvider(businessId));
        return true;
      },
    );
  }

  Future<bool> reportReview(String reviewId, String reason, String businessId) async {
    final repository = ref.read(reviewRepositoryProvider);
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return false;

    final result = await repository.reportReview(reviewId, reason, user.id);
    return result.fold(
      (failure) => false,
      (_) {
        // Refresh the reviews list
        ref.invalidate(businessReviewsNotifierProvider(businessId));
        return true;
      },
    );
  }
}
