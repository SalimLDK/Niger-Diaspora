import 'package:diaspo_niger/core/errors/app_error_messages.dart';
import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/garde_appel.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/review_entity.dart';
import '../../domain/repositories/review_repository.dart';
import '../datasources/review_remote_datasource.dart';
import '../models/review_model.dart';

class ReviewRepositoryImpl implements ReviewRepository {
  final ReviewRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  ReviewRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, List<ReviewEntity>>> getReviewsForBusiness(
    String businessId, {
    int limit = 20,
    String? lastReviewId,
  }) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }
    return garderAppel(() async {
      final reviews = await remoteDataSource.getReviewsForBusiness(
        businessId,
        limit: limit,
        lastReviewId: lastReviewId,
      );
      return Right(reviews.map((r) => r.toEntity()).toList());
    });
  }

  @override
  Future<Either<Failure, ReviewEntity?>> getUserReviewForBusiness(
    String userId,
    String businessId,
  ) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }
    return garderAppel(() async {
      final review = await remoteDataSource.getUserReviewForBusiness(
        userId,
        businessId,
      );
      return Right(review?.toEntity());
    });
  }

  @override
  Future<Either<Failure, List<ReviewEntity>>> getUserReviews(
    String userId,
  ) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }
    return garderAppel(() async {
      final reviews = await remoteDataSource.getUserReviews(userId);
      return Right(reviews.map((r) => r.toEntity()).toList());
    });
  }

  @override
  Future<Either<Failure, ReviewEntity>> createReview(
    ReviewEntity review,
  ) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }
    return garderAppel(() async {
      final reviewModel = ReviewModel.fromEntity(review);
      final created = await remoteDataSource.createReview(reviewModel);
      return Right(created.toEntity());
    });
  }

  @override
  Future<Either<Failure, ReviewEntity>> updateReview(
    ReviewEntity review,
  ) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }
    return garderAppel(() async {
      final reviewModel = ReviewModel.fromEntity(review);
      final updated = await remoteDataSource.updateReview(reviewModel);
      return Right(updated.toEntity());
    });
  }

  @override
  Future<Either<Failure, void>> deleteReview(String reviewId) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }
    return garderAppel(() async {
      await remoteDataSource.deleteReview(reviewId);
      return const Right(null);
    });
  }

  @override
  Future<Either<Failure, void>> markHelpful(String reviewId) =>
      garderAppel(() => _geste(() => remoteDataSource.markHelpful(reviewId)));

  @override
  Future<Either<Failure, void>> unmarkHelpful(String reviewId) =>
      garderAppel(() => _geste(() => remoteDataSource.unmarkHelpful(reviewId)));

  @override
  Future<Either<Failure, void>> replyToReview(String reviewId, String? reply) =>
      garderAppel(
        () => _geste(() => remoteDataSource.replyToReview(reviewId, reply)),
      );

  @override
  Future<Either<Failure, void>> reportReview(String reviewId, String reason) =>
      garderAppel(
        () => _geste(() => remoteDataSource.reportReview(reviewId, reason)),
      );

  /// Réseau d'abord, puis le geste. La garde est posée par l'appelant, pour
  /// qu'elle se lise au même endroit que l'appel à la datasource — c'est ce
  /// que vérifie `depots_sous_garde_test.dart`.
  Future<Either<Failure, void>> _geste(Future<void> Function() corps) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }
    await corps();
    return const Right(null);
  }
}
