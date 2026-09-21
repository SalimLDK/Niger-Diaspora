import '../models/review_model.dart';

/// Source des avis sur les entreprises. Seule implémentation :
/// `ReviewSupabaseDataSource` (la collection Firestore `business_reviews` n'est
/// plus lue ni écrite depuis le 2026-09-21).
///
/// Les gestes qui touchent l'avis d'un AUTRE (« utile », réponse du gérant,
/// signalement) ne prennent pas d'identifiant d'utilisateur : le serveur le
/// tire de la session. Le passer depuis le client n'aurait servi qu'à le
/// falsifier.
abstract class ReviewRemoteDataSource {
  // Lecture
  Future<List<ReviewModel>> getReviewsForBusiness(
    String businessId, {
    int limit = 20,
    String? lastReviewId,
  });
  Future<ReviewModel?> getUserReviewForBusiness(String userId, String businessId);
  Future<List<ReviewModel>> getUserReviews(String userId);

  // Son propre avis
  Future<ReviewModel> createReview(ReviewModel review);
  Future<ReviewModel> updateReview(ReviewModel review);
  Future<void> deleteReview(String reviewId);

  // L'avis d'un autre
  Future<void> markHelpful(String reviewId);
  Future<void> unmarkHelpful(String reviewId);

  /// Réponse du gérant de la fiche ; `null` ou vide la retire.
  Future<void> replyToReview(String reviewId, String? reply);
  Future<void> reportReview(String reviewId, String reason);
}
