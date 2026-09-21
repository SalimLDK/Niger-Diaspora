import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/app_error_messages.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/connectivity_service.dart';
import '../../../../core/services/supabase_auth_bridge.dart';
import '../models/review_model.dart';
import 'review_remote_datasource.dart';

/// Les avis sur les entreprises, lus et écrits sur `public.business_reviews`.
///
/// Jusqu'au 2026-09-21 ils vivaient dans Firestore alors que les entreprises
/// étaient passées sur Supabase le 2026-09-10 : la note recalculée par la
/// fonction Firestore visait un document qui n'existait plus, et l'annuaire
/// affichait 0 avis quoi qu'il arrive. Voir la migration
/// `20260921090000_avis_entreprises_sur_supabase.sql`.
///
/// Ce que ce datasource n'écrit JAMAIS, parce que la base le lui refuse (droits
/// par colonne) ou le calcule elle-même :
/// - `user_display_name` / `user_photo_url` : recopiés de `users` par un
///   déclencheur — sinon on signait au nom de n'importe qui ;
/// - `status`, `helpful_count`, `helpful_by_user_ids`, `owner_reply*` : ils
///   touchent l'avis d'un AUTRE et passent par des fonctions serveur
///   (`avis_marquer_utile`, `avis_repondre`, `avis_signaler`) ;
/// - la note et le nombre d'avis de l'entreprise : déclencheur d'agrégat.
class ReviewSupabaseDataSource implements ReviewRemoteDataSource {
  ReviewSupabaseDataSource({
    SupabaseClient? client,
    Future<void> Function()? garde,
  })  : _supabase = client ?? Supabase.instance.client,
        _garde = garde ?? _gardeParDefaut;

  final SupabaseClient _supabase;
  final Future<void> Function() _garde;

  static const String _table = 'business_reviews';

  /// Hors ligne, l'appel partirait quand même et échouerait sur un délai ;
  /// sans session Supabase, le RLS refuserait en silence (zéro ligne).
  static Future<void> _gardeParDefaut() async {
    if (!await ConnectivityService.instance.isConnected()) {
      throw ServerException(AppErrorMessages.networkError);
    }
    await SupabaseAuthBridge.instance.ensureAuthenticated();
  }

  /// Ligne ⇄ modèle. Les dates restent en ISO : `toEntity` les passe en local.
  static ReviewModel versModele(Map<String, dynamic> row) => ReviewModel(
        id: row['id'] as String,
        businessId: row['business_id'] as String,
        userId: row['user_id'] as String,
        userDisplayName: row['user_display_name'] as String? ?? '',
        userPhotoUrl: row['user_photo_url'] as String?,
        rating: (row['rating'] as num).toInt(),
        title: row['title'] as String?,
        content: row['content'] as String? ?? '',
        imageUrls: _textes(row['image_urls']),
        helpfulCount: (row['helpful_count'] as num?)?.toInt() ?? 0,
        helpfulByUserIds: _textes(row['helpful_by_user_ids']),
        status: row['status'] as String? ?? 'published',
        ownerReply: row['owner_reply'] as String?,
        ownerReplyAt: row['owner_reply_at']?.toString(),
        createdAt: row['created_at']?.toString(),
        updatedAt: row['updated_at']?.toString(),
      );

  /// Ce que l'auteur écrit de son avis — et rien d'autre : ce sont les seules
  /// colonnes que la base lui accorde en écriture.
  static Map<String, dynamic> _contenu(ReviewModel r) => {
        'rating': r.rating,
        'title': r.title,
        'content': r.content,
        'image_urls': r.imageUrls,
      };

  static List<String> _textes(Object? valeur) =>
      valeur is List ? valeur.map((e) => e.toString()).toList() : const [];

  Future<T> _appel<T>(Future<T> Function() corps) async {
    await _garde();
    try {
      return await corps();
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    }
  }

  // ── Lecture ────────────────────────────────────────────────────────────

  @override
  Future<List<ReviewModel>> getReviewsForBusiness(
    String businessId, {
    int limit = 20,
    String? lastReviewId,
  }) =>
      _appel(() async {
        var requete = _supabase
            .from(_table)
            .select()
            .eq('business_id', businessId)
            .eq('status', 'published');

        // Page suivante : après la date du dernier avis affiché.
        if (lastReviewId != null) {
          final dernier = await _supabase
              .from(_table)
              .select('created_at')
              .eq('id', lastReviewId)
              .maybeSingle();
          if (dernier != null) {
            requete = requete.lt('created_at', dernier['created_at'] as String);
          }
        }

        final rows = await requete
            .order('created_at', ascending: false)
            .limit(limit);
        return rows.map(versModele).toList();
      });

  @override
  Future<ReviewModel?> getUserReviewForBusiness(
    String userId,
    String businessId,
  ) =>
      _appel(() async {
        // Unicité `(business_id, user_id)` en base : au plus une ligne.
        final row = await _supabase
            .from(_table)
            .select()
            .eq('user_id', userId)
            .eq('business_id', businessId)
            .maybeSingle();
        return row == null ? null : versModele(row);
      });

  @override
  Future<List<ReviewModel>> getUserReviews(String userId) => _appel(() async {
        final rows = await _supabase
            .from(_table)
            .select()
            .eq('user_id', userId)
            .order('created_at', ascending: false);
        return rows.map(versModele).toList();
      });

  // ── Écriture de son propre avis ────────────────────────────────────────

  @override
  Future<ReviewModel> createReview(ReviewModel review) => _appel(() async {
        try {
          final row = await _supabase
              .from(_table)
              .insert({
                'business_id': review.businessId,
                'user_id': review.userId,
                ..._contenu(review),
              })
              .select()
              .single();
          return versModele(row);
        } on PostgrestException catch (e) {
          // Unicité `(business_id, user_id)` : un avis par compte et par fiche.
          if (e.code == '23505') {
            throw ServerException('Vous avez déjà laissé un avis pour cette entreprise');
          }
          rethrow;
        }
      });

  @override
  Future<ReviewModel> updateReview(ReviewModel review) => _appel(() async {
        final rows = await _supabase
            .from(_table)
            .update(_contenu(review))
            .eq('id', review.id)
            .select();
        // PostgREST rend 200 sur un UPDATE que le RLS réduit à zéro ligne :
        // sans ce contrôle, modifier l'avis d'autrui « réussirait ».
        if (rows.isEmpty) {
          throw ServerException('Avis introuvable ou non modifiable');
        }
        return versModele(rows.first);
      });

  @override
  Future<void> deleteReview(String reviewId) => _appel(() async {
        final rows = await _supabase
            .from(_table)
            .delete()
            .eq('id', reviewId)
            .select('id');
        if (rows.isEmpty) {
          throw ServerException('Avis introuvable ou non supprimable');
        }
      });

  // ── Gestes sur l'avis d'un autre : fonctions serveur ───────────────────

  @override
  Future<void> markHelpful(String reviewId) => _appel(() => _supabase.rpc(
        'avis_marquer_utile',
        params: {'p_review_id': reviewId, 'p_utile': true},
      ));

  @override
  Future<void> unmarkHelpful(String reviewId) => _appel(() => _supabase.rpc(
        'avis_marquer_utile',
        params: {'p_review_id': reviewId, 'p_utile': false},
      ));

  @override
  Future<void> replyToReview(String reviewId, String? reply) =>
      _appel(() => _supabase.rpc(
            'avis_repondre',
            params: {'p_review_id': reviewId, 'p_reponse': reply ?? ''},
          ));

  @override
  Future<void> reportReview(String reviewId, String reason) =>
      _appel(() => _supabase.rpc(
            'avis_signaler',
            params: {'p_review_id': reviewId, 'p_motif': reason},
          ));
}
