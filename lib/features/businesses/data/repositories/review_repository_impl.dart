import 'package:diaspo_niger/core/errors/app_error_messages.dart';
import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
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
    try {
      final reviews = await remoteDataSource.getReviewsForBusiness(
        businessId,
        limit: limit,
        lastReviewId: lastReviewId,
      );
      return Right(reviews.map((r) => r.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, ReviewEntity?>> getUserReviewForBusiness(
    String userId,
    String businessId,
  ) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }
    try {
      final review = await remoteDataSource.getUserReviewForBusiness(
        userId,
        businessId,
      );
      return Right(review?.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<ReviewEntity>>> getUserReviews(
    String userId,
  ) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }
    try {
      final reviews = await remoteDataSource.getUserReviews(userId);
      return Right(reviews.map((r) => r.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, ReviewEntity>> createReview(
    ReviewEntity review,
  ) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }
    try {
      final reviewModel = ReviewModel.fromEntity(review);
      final created = await remoteDataSource.createReview(reviewModel);
      return Right(created.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, ReviewEntity>> updateReview(
    ReviewEntity review,
  ) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }
    try {
      final reviewModel = ReviewModel.fromEntity(review);
      final updated = await remoteDataSource.updateReview(reviewModel);
      return Right(updated.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> deleteReview(String reviewId) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }
    try {
      await remoteDataSource.deleteReview(reviewId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> markHelpful(
    String reviewId,
    String userId,
  ) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }
    try {
      await remoteDataSource.markHelpful(reviewId, userId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> unmarkHelpful(
    String reviewId,
    String userId,
  ) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }
    try {
      await remoteDataSource.unmarkHelpful(reviewId, userId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> reportReview(
    String reviewId,
    String reason,
    String reporterId,
  ) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }
    try {
      await remoteDataSource.reportReview(reviewId, reason, reporterId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
