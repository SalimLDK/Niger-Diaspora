import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/review_entity.dart';

abstract class ReviewRepository {
  // Reviews - Read
  Future<Either<Failure, List<ReviewEntity>>> getReviewsForBusiness(
    String businessId, {
    int limit = 20,
    String? lastReviewId,
  });

  Future<Either<Failure, ReviewEntity?>> getUserReviewForBusiness(
    String userId,
    String businessId,
  );

  Future<Either<Failure, List<ReviewEntity>>> getUserReviews(String userId);

  // Reviews - Write
  Future<Either<Failure, ReviewEntity>> createReview(ReviewEntity review);
  Future<Either<Failure, ReviewEntity>> updateReview(ReviewEntity review);
  Future<Either<Failure, void>> deleteReview(String reviewId);

  // Reviews - Actions
  Future<Either<Failure, void>> markHelpful(String reviewId, String userId);
  Future<Either<Failure, void>> unmarkHelpful(String reviewId, String userId);
  Future<Either<Failure, void>> reportReview(
    String reviewId,
    String reason,
    String reporterId,
  );
}
