import 'dart:math' as math;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/app_error_messages.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/connectivity_service.dart';
import '../../../../core/services/supabase_auth_bridge.dart';
import '../models/business_boost_model.dart';
import '../models/business_model.dart';
import '../models/business_post_model.dart';
import 'business_remote_datasource.dart';

/// L'annuaire, lu et écrit sur `public.businesses`.
///
/// Le module vivait entièrement sur Firestore pendant que les entreprises
/// vivaient dans `public.businesses` : ouvrir `/businesses/<uuid>` — par lien
/// profond, par QR ou depuis l'annuaire — cherchait un document Firestore
/// absent et affichait « Entreprise non trouvée ». Constaté sur SM A515F le
/// 2026-09-09, exactement la même famille de défaut que les événements.
///
/// Les **images** restent des URL déjà téléversées par les écrans : ce
/// datasource ne touche pas au stockage, comme celui des événements.
class BusinessSupabaseDataSource implements BusinessRemoteDataSource {
  BusinessSupabaseDataSource({SupabaseClient? client})
    : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;
  final ConnectivityService _connectivity = ConnectivityService.instance;

  /// Colonnes de `businesses` + le nom du propriétaire, que le modèle expose
  /// mais que la table ne porte pas. L'embed s'appuie sur la clé étrangère
  /// `businesses.owner_id → users.id`.
  static const String _select = '*, users(display_name)';

  static const String _selectPost = '*';

  // ── Garde commune ──────────────────────────────────────────────────────

  /// Hors ligne, l'appel partirait quand même et échouerait sur un délai :
  /// autant le dire tout de suite, avec le message que le reste de l'app
  /// emploie déjà.
  Future<void> _garde() async {
    if (!await _connectivity.isConnected()) {
      throw ServerException(AppErrorMessages.networkError);
    }
    // Sans session Supabase, RLS refuse en silence : l'appel « réussit » et
    // rend zéro ligne. Voir `project_supabase_write_auth_guard`.
    await SupabaseAuthBridge.instance.ensureAuthenticated();
  }

  // ── Correspondance ligne ⇄ modèle ──────────────────────────────────────

  BusinessModel _versModele(Map<String, dynamic> row) => BusinessModel.fromJson({
    'id': row['id'],
    'ownerId': row['owner_id'],
    'ownerName': (row['users'] as Map?)?['display_name'],
    'name': row['name'] ?? '',
    'description': row['description'] ?? '',
    'category': row['category'] ?? 'other',
    'photoUrls': _listeDeTextes(row['images'], repli: row['cover_url']),
    'logoUrl': row['logo_url'] ?? row['avatar_url'],
    'phone': row['phone'],
    'email': row['email'],
    'website': row['website_url'],
    'address': row['address'],
    'city': row['city'],
    // `country_code` côté base, `country` côté modèle : la colonne porte un
    // code ISO, que l'app affiche tel quel.
    'country': row['country_code'],
    'latitude': row['latitude'],
    'longitude': row['longitude'],
    'openingHours': row['opening_hours'] is Map ? row['opening_hours'] : {},
    'isVerified': row['is_verified'] ?? false,
    'isBoosted': row['is_boosted'] ?? false,
    'boostExpiresAt': row['boost_expires_at'],
    'averageRating': (row['rating'] as num?)?.toDouble() ?? 0.0,
    'reviewCount': row['review_count'] ?? 0,
    'viewCount': row['view_count'] ?? 0,
    'tags': _listeDeTextes(row['tags']),
    'services': _listeDeTextes(row['services']),
    'createdAt': row['created_at'],
    'updatedAt': row['updated_at'],
  });

  /// Colonnes à écrire. `id`, `created_at`, `name_lower`, `rating`,
  /// `review_count`, `follower_count` et `view_count` sont exclus : la base
  /// les tient (génération, triggers d'agrégat). Les réécrire depuis le client
  /// écraserait des compteurs justes par des valeurs périmées.
  Map<String, dynamic> _versLigne(BusinessModel b) => {
    'owner_id': b.ownerId,
    'name': b.name,
    'description': b.description,
    'category': b.category,
    'images': b.photoUrls,
    'logo_url': b.logoUrl,
    'phone': b.phone,
    'email': b.email,
    'website_url': b.website,
    'address': b.address,
    'city': b.city,
    'country_code': b.country,
    'latitude': b.latitude,
    'longitude': b.longitude,
    'opening_hours': b.openingHours,
    'is_verified': b.isVerified,
    'is_boosted': b.isBoosted,
    'boost_expires_at': b.boostExpiresAt?.toUtc().toIso8601String(),
    'tags': b.tags,
    'services': b.services,
  };

  BusinessPostModel _versModelePost(Map<String, dynamic> row) =>
      BusinessPostModel.fromJson({
        'id': row['id'],
        'businessId': row['business_id'],
        'title': row['title'] ?? '',
        'content': row['content'] ?? '',
        'type': row['type'] ?? 'announcement',
        'imageUrls': _listeDeTextes(row['image_urls']),
        'originalPrice': (row['original_price'] as num?)?.toDouble(),
        'discountedPrice': (row['discounted_price'] as num?)?.toDouble(),
        'discountPercent': row['discount_percent'],
        'offerStartDate': row['offer_start_date']?.toString(),
        'offerEndDate': row['offer_end_date']?.toString(),
        'promoCode': row['promo_code'],
        'viewCount': row['view_count'] ?? 0,
        'likeCount': row['like_count'] ?? 0,
        'isActive': row['is_active'] ?? true,
        'createdAt': row['created_at']?.toString(),
        'updatedAt': row['updated_at']?.toString(),
      });

  Map<String, dynamic> _versLignePost(BusinessPostModel p) => {
    'business_id': p.businessId,
    'title': p.title,
    'content': p.content,
    'type': p.type,
    'image_urls': p.imageUrls,
    'original_price': p.originalPrice,
    'discounted_price': p.discountedPrice,
    'discount_percent': p.discountPercent,
    'offer_start_date': p.offerStartDate,
    'offer_end_date': p.offerEndDate,
    'promo_code': p.promoCode,
    'is_active': p.isActive,
  };

  BusinessBoostModel _versModeleBoost(Map<String, dynamic> row) =>
      BusinessBoostModel.fromJson({
        'id': row['id'],
        'businessId': row['business_id'],
        'userId': row['user_id'],
        'type': row['type'] ?? 'standard',
        'duration': row['duration'] ?? 'days7',
        'amount': (row['amount'] as num?)?.toDouble() ?? 0.0,
        'currency': row['currency'] ?? 'XOF',
        'startDate': row['start_date'],
        'endDate': row['end_date'],
        'status': row['status'] ?? 'active',
        'paymentReference': row['payment_reference'],
        'createdAt': row['created_at'],
      });

  /// `images`, `tags` et `services` sont des colonnes de tableau : PostgREST
  /// rend une liste, mais une ligne écrite à la main peut porter une chaîne ou
  /// `null`. `repli` récupère `cover_url` pour les lignes importées, qui ne
  /// remplissent que celle-là.
  static List<String> _listeDeTextes(Object? value, {Object? repli}) {
    if (value is List) {
      final valeurs = value.whereType<String>().toList();
      if (valeurs.isNotEmpty) return valeurs;
    }
    if (value is String && value.isNotEmpty) return [value];
    if (repli is String && repli.isNotEmpty) return [repli];
    return const [];
  }

  List<BusinessModel> _modelesDepuis(Object? rows) =>
      (rows as List)
          .cast<Map<String, dynamic>>()
          .map(_versModele)
          .toList(growable: false);

  // ── Lecture ────────────────────────────────────────────────────────────

  @override
  Future<List<BusinessModel>> getBusinesses({
    bool featuredFirst = true,
    int limit = 20,
  }) async {
    await _garde();
    final requete = _supabase.from('businesses').select(_select).eq('is_active', true);
    final rows = featuredFirst
        ? await requete
              .order('is_boosted', ascending: false)
              .order('created_at', ascending: false)
              .limit(limit)
        : await requete.order('created_at', ascending: false).limit(limit);
    return _modelesDepuis(rows);
  }

  @override
  Future<List<BusinessModel>> getBusinessesByCategory(String category) async {
    await _garde();
    final rows = await _supabase
        .from('businesses')
        .select(_select)
        .eq('is_active', true)
        .eq('category', category)
        .order('is_boosted', ascending: false)
        .order('created_at', ascending: false);
    return _modelesDepuis(rows);
  }

  @override
  Future<List<BusinessModel>> searchBusinesses(String query) async {
    await _garde();
    final terme = query.trim();
    if (terme.isEmpty) return const [];
    // `ilike` sur `name` : la table porte `name_lower` et son index trigram,
    // mais PostgREST ne sait pas viser une colonne générée autrement.
    final rows = await _supabase
        .from('businesses')
        .select(_select)
        .eq('is_active', true)
        .ilike('name', '%$terme%')
        .order('is_boosted', ascending: false)
        .limit(50);
    return _modelesDepuis(rows);
  }

  @override
  Future<List<BusinessModel>> getNearbyBusinesses(
    double lat,
    double lng,
    double radiusKm,
  ) async {
    await _garde();
    // Pré-filtre par boîte englobante côté base — un degré de latitude vaut
    // ~111 km — puis distance exacte côté client. PostGIS n'est pas installé,
    // et ramener tout l'annuaire pour le filtrer ici ne passerait pas à
    // l'échelle.
    final deltaLat = radiusKm / 111.0;
    // Près des pôles, le cosinus tend vers zéro et la boîte s'ouvrirait à
    // l'infini : le plancher garde un delta fini.
    final cosLat = math.cos(lat * math.pi / 180).abs();
    final deltaLng = radiusKm / (111.0 * (cosLat < 0.01 ? 0.01 : cosLat));

    final rows = await _supabase
        .from('businesses')
        .select(_select)
        .eq('is_active', true)
        .gte('latitude', lat - deltaLat)
        .lte('latitude', lat + deltaLat)
        .gte('longitude', lng - deltaLng)
        .lte('longitude', lng + deltaLng);

    final proches = _modelesDepuis(rows).where((b) {
      final bLat = b.latitude;
      final bLng = b.longitude;
      if (bLat == null || bLng == null) return false;
      return _distanceKm(lat, lng, bLat, bLng) <= radiusKm;
    }).toList();

    proches.sort(
      (a, b) => _distanceKm(lat, lng, a.latitude!, a.longitude!).compareTo(
        _distanceKm(lat, lng, b.latitude!, b.longitude!),
      ),
    );
    return proches;
  }

  @override
  Future<List<BusinessModel>> getBusinessesByLocation({
    String? country,
    String? city,
  }) async {
    await _garde();
    var requete = _supabase.from('businesses').select(_select).eq('is_active', true);
    if (country != null && country.isNotEmpty) {
      requete = requete.eq('country_code', country);
    }
    if (city != null && city.isNotEmpty) {
      requete = requete.eq('city', city);
    }
    final rows = await requete.order('is_boosted', ascending: false);
    return _modelesDepuis(rows);
  }

  @override
  Future<BusinessModel> getBusinessById(String id) async {
    await _garde();
    // `.single()` et non `.maybeSingle()` : l'absence de ligne — supprimée,
    // désactivée, identifiant d'une autre base — doit remonter comme un échec,
    // pas comme un `null` que l'écran prendrait pour un chargement en cours.
    final row = await _supabase
        .from('businesses')
        .select(_select)
        .eq('id', id)
        .single();
    return _versModele(row);
  }

  @override
  Future<BusinessModel?> getMyBusiness(String ownerId) async {
    final miennes = await getMyBusinesses(ownerId);
    return miennes.isEmpty ? null : miennes.first;
  }

  @override
  Future<List<BusinessModel>> getMyBusinesses(String ownerId) async {
    await _garde();
    // Pas de filtre `is_active` : son propriétaire doit voir sa fiche même
    // désactivée, sinon elle disparaît sans explication et il la recrée.
    final rows = await _supabase
        .from('businesses')
        .select(_select)
        .eq('owner_id', ownerId)
        .order('created_at', ascending: false);
    return _modelesDepuis(rows);
  }

  // ── Écriture ───────────────────────────────────────────────────────────

  @override
  Future<BusinessModel> createBusiness(BusinessModel business) async {
    await _garde();
    final row = await _supabase
        .from('businesses')
        .insert(_versLigne(business))
        .select(_select)
        .single();
    return _versModele(row);
  }

  @override
  Future<BusinessModel> updateBusiness(BusinessModel business) async {
    await _garde();
    final row = await _supabase
        .from('businesses')
        .update({..._versLigne(business), 'updated_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', business.id)
        .select(_select)
        .single();
    return _versModele(row);
  }

  @override
  Future<void> deleteBusiness(String id) async {
    await _garde();
    await _supabase.from('businesses').delete().eq('id', id);
  }

  @override
  Future<void> incrementViewCount(String businessId) async {
    // Volontairement sans `_garde()` : un compteur de vues ne doit jamais
    // empêcher l'affichage d'une fiche. L'erreur est avalée pour la même
    // raison.
    try {
      await _supabase.rpc(
        'increment_business_view_count',
        params: {'p_business_id': businessId},
      );
    } catch (_) {
      // Compteur perdu, fiche affichée : le bon compromis.
    }
  }

  // ── Boosts ─────────────────────────────────────────────────────────────

  @override
  Future<BusinessBoostModel> createBoost(BusinessBoostModel boost) async {
    await _garde();
    final row = await _supabase
        .from('business_boosts')
        .insert({
          'business_id': boost.businessId,
          'user_id': boost.userId,
          'type': boost.type,
          'duration': boost.duration,
          'amount': boost.amount,
          'currency': boost.currency,
          'start_date': boost.startDate.toUtc().toIso8601String(),
          'end_date': boost.endDate.toUtc().toIso8601String(),
          'status': boost.status,
          'payment_reference': boost.paymentReference,
        })
        .select()
        .single();
    return _versModeleBoost(row);
  }

  @override
  Future<List<BusinessBoostModel>> getBoostHistory(String businessId) async {
    await _garde();
    final rows = await _supabase
        .from('business_boosts')
        .select()
        .eq('business_id', businessId)
        .order('created_at', ascending: false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(_versModeleBoost)
        .toList(growable: false);
  }

  @override
  Future<BusinessBoostModel?> getActiveBoost(String businessId) async {
    await _garde();
    final rows = await _supabase
        .from('business_boosts')
        .select()
        .eq('business_id', businessId)
        .eq('status', 'active')
        .gte('end_date', DateTime.now().toUtc().toIso8601String())
        .order('end_date', ascending: false)
        .limit(1);
    final liste = (rows as List).cast<Map<String, dynamic>>();
    return liste.isEmpty ? null : _versModeleBoost(liste.first);
  }

  @override
  Future<void> updateBusinessBoostStatus(
    String businessId,
    bool isBoosted,
    DateTime? expiresAt,
  ) async {
    await _garde();
    await _supabase
        .from('businesses')
        .update({
          'is_boosted': isBoosted,
          'boost_expires_at': expiresAt?.toUtc().toIso8601String(),
        })
        .eq('id', businessId);
  }

  // ── Publications ───────────────────────────────────────────────────────

  @override
  Future<List<BusinessPostModel>> getBusinessPosts(
    String businessId, {
    int limit = 20,
  }) async {
    await _garde();
    final rows = await _supabase
        .from('business_posts')
        .select(_selectPost)
        .eq('business_id', businessId)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(_versModelePost)
        .toList(growable: false);
  }

  @override
  Future<List<BusinessPostModel>> getActiveOffers(String businessId) async {
    await _garde();
    final rows = await _supabase
        .from('business_posts')
        .select(_selectPost)
        .eq('business_id', businessId)
        .eq('type', 'offer')
        .eq('is_active', true)
        .order('created_at', ascending: false);
    final maintenant = DateTime.now();
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(_versModelePost)
        // La fin d'offre est filtrée ici et non en base : la colonne accepte
        // aussi bien une date qu'un `null` (offre sans fin), et un filtre SQL
        // sur `null` écarterait ces dernières.
        .where((p) {
          final fin = DateTime.tryParse(p.offerEndDate ?? '');
          return fin == null || fin.isAfter(maintenant);
        })
        .toList(growable: false);
  }

  @override
  Future<BusinessPostModel> createPost(BusinessPostModel post) async {
    await _garde();
    final row = await _supabase
        .from('business_posts')
        .insert(_versLignePost(post))
        .select(_selectPost)
        .single();
    return _versModelePost(row);
  }

  @override
  Future<BusinessPostModel> updatePost(BusinessPostModel post) async {
    await _garde();
    final row = await _supabase
        .from('business_posts')
        .update({
          ..._versLignePost(post),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', post.id)
        .select(_selectPost)
        .single();
    return _versModelePost(row);
  }

  @override
  Future<void> deletePost(String postId) async {
    await _garde();
    await _supabase.from('business_posts').delete().eq('id', postId);
  }

  // ── Géométrie ──────────────────────────────────────────────────────────

  static double _distanceKm(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const rayonTerre = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLng = (lng2 - lng1) * math.pi / 180;
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return rayonTerre * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }
}
