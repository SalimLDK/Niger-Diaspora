import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart'
    show FieldValue, FirebaseFirestore, DocumentSnapshot, Query;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/message_erreur.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../core/services/session_service.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../businesses/data/models/business_model.dart';
import '../../../businesses/domain/entities/business_entity.dart';
import '../../../events/data/models/event_model.dart';
import '../../../events/domain/entities/event_entity.dart';
import '../../../events/presentation/providers/event_provider.dart';
import '../../../../core/services/cache_service.dart';
import '../../../groups/data/models/group_model.dart';
import '../../../groups/domain/entities/group_entity.dart';
import '../../../marketplace/data/models/product_model.dart';
import '../../../marketplace/domain/entities/product_entity.dart';
import '../../../transfers/data/models/transaction_model.dart';
import '../../../transfers/domain/entities/transaction_entity.dart';
import '../../domain/constants/moderation_signalements.dart';
import '../fusion_paginee.dart';
import '../signalement_firestore.dart';
import 'refus_callable.dart';
import 'package:diaspo_niger/features/admin/presentation/recherche_serveur.dart';

// ---------------------------------------------------------------------------
// Supabase client accessor
// ---------------------------------------------------------------------------

SupabaseClient get _supabase => Supabase.instance.client;

/// Suffixe des erreurs « zéro ligne ». PostgREST ne lève rien quand une policy
/// RLS filtre toutes les lignes d'un `update` ou d'un `delete` : sans
/// `.select('id')` derrière l'écriture, le refus passait pour un succès, et
/// l'écran l'annonçait comme tel. Côté Postgres, rembourser, compléter ou
/// échouer une transaction, désactiver ou supprimer un produit, supprimer un
/// groupe n'ont aucune policy admin : zéro ligne à chaque fois (audit du
/// 2026-10-14, § 5). Chaque écriture relit donc `id` et rend faux si vide,
/// sur le modèle de `deleteEvent`.
const String _aucuneLigne =
    'aucune ligne modifiée (droits insuffisants ou cible introuvable)';

// ---------------------------------------------------------------------------
// Row → camelCase mappers (Supabase snake_case → model fromJson keys)
// ---------------------------------------------------------------------------

Map<String, dynamic> _mapUser(Map<String, dynamic> row) => {
  'id': row['id'],
  'email': row['email'],
  'displayName': row['display_name'],
  'photoUrl': row['avatar_url'],
  'phoneNumber': row['phone_number'],
  'createdAt': row['created_at'],
  'lastLoginAt': row['last_active_at'],
  'adminRole': row['admin_role'],
  'isAdmin': row['is_admin'] ?? false,
  'isBanned': row['is_banned'] ?? false,
  'banReason': row['ban_reason'],
  'bannedAt': row['banned_at'],
  'isVerified': row['is_verified'] ?? false,
};

Map<String, dynamic> _mapBusiness(Map<String, dynamic> row) => {
  'id': row['id'],
  'ownerId': row['owner_id'],
  'name': row['name'],
  'description': row['description'] ?? '',
  'category': row['category'] ?? 'other',
  'photoUrls': (row['images'] as List?)?.cast<String>() ?? [],
  'logoUrl': row['avatar_url'],
  'phone': row['phone'],
  'email': row['email'],
  'website': row['website_url'],
  'address': row['address'],
  'city': row['city'],
  'country': row['country_code'],
  'latitude': (row['latitude'] as num?)?.toDouble(),
  'longitude': (row['longitude'] as num?)?.toDouble(),
  'openingHours':
      (row['opening_hours'] as Map?)?.cast<String, dynamic>() ?? {},
  'isVerified': row['is_verified'] ?? false,
  'isBoosted': row['is_boosted'] ?? false,
  'boostExpiresAt': row['boost_expires_at'],
  'averageRating': (row['rating'] as num?)?.toDouble() ?? 0.0,
  'reviewCount': row['review_count'] ?? 0,
  'viewCount': row['view_count'] ?? 0,
  'tags': (row['tags'] as List?)?.cast<String>() ?? [],
  'services': (row['services'] as List?)?.cast<String>() ?? [],
  'createdAt': row['created_at'],
  'updatedAt': row['updated_at'],
};

Map<String, dynamic> _mapEvent(Map<String, dynamic> row) => {
  'id': row['id'],
  'title': row['title'],
  'description': row['description'] ?? '',
  'startDate': row['starts_at'],
  'endDate': row['ends_at'],
  'location': row['address'],
  'address': row['address'],
  'country': row['country_code'],
  'latitude': (row['latitude'] as num?)?.toDouble(),
  'longitude': (row['longitude'] as num?)?.toDouble(),
  'organizerId': row['organizer_id'],
  'organizerName': row['organizer_name'] ?? '',
  'organizerPhotoUrl': row['organizer_photo_url'],
  'posterUrls': (row['poster_urls'] as List?)?.cast<String>() ?? [],
  'attendeeIds': (row['attendee_ids'] as List?)?.cast<String>() ?? [],
  'maxAttendees': row['max_attendees'],
  'isOnline': row['is_online'] ?? false,
  'onlineLink': row['online_link'],
  'category': row['category'] ?? 'general',
  'status': row['status'] ?? 'upcoming',
  'createdAt': row['created_at'],
  'recapPhotoUrls':
      (row['recap_photo_urls'] as List?)?.cast<String>() ?? [],
  'recapDescription': row['recap_description'],
  'recapCreatedAt': row['recap_created_at'],
};

Map<String, dynamic> _mapGroup(Map<String, dynamic> row) => {
  'id': row['id'],
  'name': row['name'],
  'description': row['description'] ?? '',
  'imageUrl': row['avatar_url'],
  'creatorId': row['creator_id'],
  'creatorName': row['creator_name'],
  'adminIds': (row['admin_ids'] as List?)?.cast<String>() ?? [],
  'memberIds': (row['member_ids'] as List?)?.cast<String>() ?? [],
  'category': row['category'] ?? 'general',
  'isPrivate': row['is_private'] ?? false,
  'location': row['group_location'],
  'tags': (row['tags'] as List?)?.cast<String>() ?? [],
  'country': row['country_code'],
  'originRegion': row['origin_region'],
  'createdAt': row['created_at'],
  'memberCount': row['member_count'] ?? 0,
};

const _zeroDecimalCurrencies = {
  'bif', 'clp', 'gnf', 'jpy', 'kmf', 'krw', 'mga', 'pyg',
  'rwf', 'ugx', 'vnd', 'vuv', 'xaf', 'xof', 'xpf',
};

double _fromBaseUnits(int amount, String currency) =>
    _zeroDecimalCurrencies.contains(currency.toLowerCase())
        ? amount.toDouble()
        : amount / 100.0;

Map<String, dynamic> _mapProduct(Map<String, dynamic> row) {
  final currency = row['currency'] as String? ?? 'XOF';
  return {
    'id': row['id'],
    'sellerId': row['seller_id'],
    'title': row['title'],
    'description': row['description'] ?? '',
    'price': _fromBaseUnits((row['price'] as int?) ?? 0, currency),
    'currency': currency,
    'imageUrls': (row['images'] as List?)
            ?.map((e) => (e as Map)['url']?.toString() ?? '')
            .where((u) => u.isNotEmpty)
            .toList() ??
        [],
    'category': row['category'] ?? 'other',
    'condition': row['condition'] ?? 'newProduct',
    'country': row['country_code'],
    'location': row['city'],
    'isAvailable': row['is_available'] ?? true,
    'quantity': row['stock_quantity'] ?? 0,
    'viewCount': row['view_count'] ?? 0,
    'tags': (row['tags'] as List?)?.cast<String>() ?? [],
    'createdAt': row['created_at'],
    'updatedAt': row['updated_at'],
  };
}

Map<String, dynamic> _mapTransaction(Map<String, dynamic> row) {
  final currency = row['currency'] as String? ?? 'XOF';
  final amountBase = (row['amount'] as int?) ?? 0;
  return {
    'id': row['id'],
    'senderId': row['sender_id'],
    'recipientId': row['recipient_id'] ?? '',
    'amount': _fromBaseUnits(amountBase, currency),
    'currency': currency,
    'exchangeRate': (row['exchange_rate'] as num?)?.toDouble() ?? 1.0,
    'amountInXof': (row['amount_in_xof'] as num?)?.toDouble() ?? 0.0,
    'fee': (row['fee'] as num?)?.toDouble() ?? 0.0,
    'totalCharged': (row['total_charged'] as num?)?.toDouble() ?? 0.0,
    'status': row['status'] ?? 'pending',
    'provider': row['payment_provider'] ?? 'stripe',
    'paymentIntentId': row['stripe_payment_intent_id'],
    'failureReason': row['failure_reason'],
    'notes': row['notes'],
    'createdAt': row['created_at'],
    'completedAt': row['completed_at'],
    ...((row['metadata'] as Map?)?.cast<String, dynamic>() ?? {}),
  };
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value.toLocal();
  if (value is String) return DateTime.tryParse(value)?.toLocal();
  return null;
}

// ============================================================================
// CURRENT ADMIN PROVIDER - Provides current admin info for audit logging
// ============================================================================

class CurrentAdmin extends Equatable {
  final String id;
  final String? name;
  final String? email;

  const CurrentAdmin({required this.id, this.name, this.email});

  @override
  List<Object?> get props => [id, name, email];
}

final currentAdminProvider = Provider<CurrentAdmin?>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;
  return CurrentAdmin(id: user.uid, name: user.displayName, email: user.email);
});

// ============================================================================
// ADMIN DASHBOARD STATE
// ============================================================================

class AdminDashboardState extends Equatable {
  final int totalUsers;
  final int activeSessions;
  final int totalEvents;
  final int totalGroups;
  final int totalBusinesses;
  final int totalProducts;
  final int totalTransactions;
  final int pendingReports;
  final List<UserEntity> recentUsers;
  final List<dynamic> recentContent;
  final bool isLoading;
  final String? error;

  const AdminDashboardState({
    this.totalUsers = 0,
    this.activeSessions = 0,
    this.totalEvents = 0,
    this.totalGroups = 0,
    this.totalBusinesses = 0,
    this.totalProducts = 0,
    this.totalTransactions = 0,
    this.pendingReports = 0,
    this.recentUsers = const [],
    this.recentContent = const [],
    this.isLoading = false,
    this.error,
  });

  AdminDashboardState copyWith({
    int? totalUsers,
    int? activeSessions,
    int? totalEvents,
    int? totalGroups,
    int? totalBusinesses,
    int? totalProducts,
    int? totalTransactions,
    int? pendingReports,
    List<UserEntity>? recentUsers,
    List<dynamic>? recentContent,
    bool? isLoading,
    String? error,
  }) {
    return AdminDashboardState(
      totalUsers: totalUsers ?? this.totalUsers,
      activeSessions: activeSessions ?? this.activeSessions,
      totalEvents: totalEvents ?? this.totalEvents,
      totalGroups: totalGroups ?? this.totalGroups,
      totalBusinesses: totalBusinesses ?? this.totalBusinesses,
      totalProducts: totalProducts ?? this.totalProducts,
      totalTransactions: totalTransactions ?? this.totalTransactions,
      pendingReports: pendingReports ?? this.pendingReports,
      recentUsers: recentUsers ?? this.recentUsers,
      recentContent: recentContent ?? this.recentContent,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  @override
  List<Object?> get props => [
    totalUsers,
    activeSessions,
    totalEvents,
    totalGroups,
    totalBusinesses,
    totalProducts,
    totalTransactions,
    pendingReports,
    recentUsers,
    recentContent,
    isLoading,
    error,
  ];
}

final adminDashboardNotifierProvider =
    NotifierProvider<AdminDashboardNotifier, AdminDashboardState>(
      AdminDashboardNotifier.new,
    );

class AdminDashboardNotifier extends Notifier<AdminDashboardState> {
  /// Referme le bandeau d'erreur d'un écran qui a encore sa liste.
  /// `copyWith` efface `error` dès qu'on ne le repasse pas — c'est le seul
  /// champ ainsi —, donc n'importe quel chargement l'efface aussi.
  void effacerErreur() => state = state.copyWith(error: null);

  @override
  AdminDashboardState build() {
    return const AdminDashboardState();
  }

  Future<void> loadDashboardStats() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      Future<int> tableCount(String table) async {
        try {
          final resp = await _supabase
              .from(table)
              .select('id')
              .count(CountOption.exact);
          return resp.count;
        } catch (_) {
          return 0;
        }
      }

      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(hours: 24));

      final results = await Future.wait([
        tableCount('users'),
        tableCount('events'),
        tableCount('groups'),
        tableCount('businesses'),
        tableCount('products'),
        tableCount('transactions'),
        // pending reports count : les avis (Supabase) + ce que l'app signale
        // (Firestore)
        Future.wait<int>([
          _supabase
              .from('reports')
              .select('id')
              .inFilter('status', statutsSignalementEnAttente)
              .count(CountOption.exact)
              .then((r) => r.count)
              .catchError((_) => 0),
          compterSignalementsFirestore('pending'),
        ]).then((n) => n[0] + n[1]),
        // active sessions: users active in last 24 h
        _supabase
            .from('users')
            .select('id')
            .gte('last_active_at', yesterday.toUtc().toIso8601String())
            .count(CountOption.exact)
            .then((r) => r.count)
            .catchError((_) => 0),
      ]);

      state = state.copyWith(
        totalUsers: results[0],
        totalEvents: results[1],
        totalGroups: results[2],
        totalBusinesses: results[3],
        totalProducts: results[4],
        totalTransactions: results[5],
        pendingReports: results[6],
        activeSessions: results[7],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> fetchRecentUsers() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // `profils_admin()` et non `select()` : le back-office tourne sous le
      // rôle `authenticated`, comme tout le monde, et perdra e-mail, téléphone
      // et motif de bannissement une fois la fermeture 1.1b appliquée. La
      // fonction les lui sert, et lève 42501 à qui n'est pas administrateur.
      // Même tri, même troncature.
      final rows = await _supabase.rpc(
        'profils_admin',
        params: {'p_limite': 20},
      );

      final users = (rows as List)
          .map((row) => UserModel.fromJson(_mapUser(row)).toEntity())
          .toList();

      state = state.copyWith(isLoading: false, recentUsers: users);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> forceLogoutUser(
    String userId, {
    required String adminId,
    String? adminName,
  }) async {
    try {
      // Sentinelle lue par `SessionService` sur la ligne `public.users` de
      // l'usager, via Realtime. La constante vient de la, pas d'ici : c'est
      // ce qui relie les deux moities. Ecrire `session_id` dans Firestore a
      // la place ne marcherait pas — `firestore.rules` n'ouvre l'update d'un
      // document `users` qu'a son proprietaire, et le refus serait muet.
      final newSessionId =
          '${SessionService.prefixeForceLogout}${DateTime.now().millisecondsSinceEpoch}';
      final updated = await _supabase
          .from('users')
          .update({'session_id': newSessionId})
          .eq('id', userId)
          .select('id');
      if ((updated as List).isEmpty) {
        state = state.copyWith(error: 'Déconnexion non forcée : $_aucuneLigne');
        return false;
      }

      final echecJournal = await AdminAuditHelper.log(
        adminId: adminId,
        adminName: adminName,
        action: 'force_logout',
        targetType: 'user',
        targetId: userId,
      );

      if (echecJournal != null) {
        state = state.copyWith(error: echecJournal);
        return false;
      }
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Failed to logout user: $e');
      return false;
    }
  }

  Future<void> fetchRecentContent() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final eventsRows = await _supabase
          .from('events')
          .select()
          .order('created_at', ascending: false)
          .limit(10);

      final events = (eventsRows as List)
          .map((row) => EventModel.fromJson(_mapEvent(row)).toEntity())
          .toList();

      final groupsRows = await _supabase
          .from('groups')
          .select()
          .order('created_at', ascending: false)
          .limit(10);

      final groups = (groupsRows as List)
          .map((row) => GroupModel.fromJson(_mapGroup(row)).toEntity())
          .toList();

      final allContent = [...events, ...groups]..sort((a, b) {
        final dateA =
            a is EventEntity ? a.createdAt : (a as GroupEntity).createdAt;
        final dateB =
            b is EventEntity ? b.createdAt : (b as GroupEntity).createdAt;
        return (dateB ?? DateTime(0)).compareTo(dateA ?? DateTime(0));
      });

      state = state.copyWith(isLoading: false, recentContent: allContent);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

// ============================================================================
// BUSINESS MANAGEMENT
// ============================================================================

/// Les trois listes de l'écran Commerces, chacune une requête paginée : « En
/// attente » n'est plus les non-vérifiés parmi les 50 derniers, mais tous.
enum FiltreCommerces { tous, enAttente, boostes }

/// Taille d'une page de l'écran Commerces.
const int taillePageCommerces = 50;

class AdminBusinessState extends Equatable {
  final List<BusinessEntity> businesses;
  final List<BusinessEntity> pendingVerification;
  final List<BusinessEntity> boosted;
  final Set<FiltreCommerces> encorePlus;
  final FiltreCommerces? chargementPlus;

  /// Recherche (nom, ville, catégorie, e-mail), appliquée côté serveur.
  final String recherche;
  final bool isLoading;
  final String? error;

  const AdminBusinessState({
    this.businesses = const [],
    this.pendingVerification = const [],
    this.boosted = const [],
    this.encorePlus = const {},
    this.chargementPlus,
    this.recherche = '',
    this.isLoading = false,
    this.error,
  });

  List<BusinessEntity> liste(FiltreCommerces f) => switch (f) {
        FiltreCommerces.tous => businesses,
        FiltreCommerces.enAttente => pendingVerification,
        FiltreCommerces.boostes => boosted,
      };

  AdminBusinessState copyWith({
    List<BusinessEntity>? businesses,
    List<BusinessEntity>? pendingVerification,
    List<BusinessEntity>? boosted,
    Set<FiltreCommerces>? encorePlus,
    FiltreCommerces? chargementPlus,
    bool finChargementPlus = false,
    String? recherche,
    bool? isLoading,
    String? error,
  }) {
    return AdminBusinessState(
      businesses: businesses ?? this.businesses,
      pendingVerification: pendingVerification ?? this.pendingVerification,
      boosted: boosted ?? this.boosted,
      encorePlus: encorePlus ?? this.encorePlus,
      chargementPlus:
          finChargementPlus ? null : (chargementPlus ?? this.chargementPlus),
      recherche: recherche ?? this.recherche,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  @override
  List<Object?> get props => [
    businesses,
    pendingVerification,
    boosted,
    encorePlus,
    chargementPlus,
    recherche,
    isLoading,
    error,
  ];
}

/// Les fiches archivées parmi celles chargées (`is_active = false`). L'entité
/// partagée avec l'application ne porte pas ce drapeau ; le panneau le tient à
/// part plutôt que d'élargir un modèle généré qui n'est pas le sien.
final commercesArchivesProvider = StateProvider<Set<String>>((ref) => {});

final adminBusinessNotifierProvider =
    NotifierProvider<AdminBusinessNotifier, AdminBusinessState>(
      AdminBusinessNotifier.new,
    );

class AdminBusinessNotifier extends Notifier<AdminBusinessState> {
  /// Referme le bandeau d'erreur d'un écran qui a encore sa liste.
  /// `copyWith` efface `error` dès qu'on ne le repasse pas — c'est le seul
  /// champ ainsi —, donc n'importe quel chargement l'efface aussi.
  void effacerErreur() => state = state.copyWith(error: null);

  @override
  AdminBusinessState build() {
    return const AdminBusinessState();
  }

  /// Lignes **lues** par liste (et non conservées) : une ligne illisible est
  /// sautée de l'affichage mais compte pour le décalage de la page suivante.
  final Map<FiltreCommerces, int> _lues = {};

  /// Recharge la première page des trois listes.
  Future<void> fetchAllBusinesses() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final pages = await Future.wait([
        for (final f in FiltreCommerces.values) _pageCommerces(f, 0),
      ]);
      state = state.copyWith(
        isLoading: false,
        businesses: pages[0].commerces,
        pendingVerification: pages[1].commerces,
        boosted: pages[2].commerces,
        encorePlus: {
          for (var i = 0; i < pages.length; i++)
            if (pages[i].lues >= taillePageCommerces)
              FiltreCommerces.values[i],
        },
        finChargementPlus: true,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Applique [texte] (nom, ville, catégorie, e-mail) côté serveur et recharge.
  /// L'écran l'appelle après un délai de frappe.
  Future<void> rechercher(String texte) {
    state = state.copyWith(recherche: texte.trim());
    return fetchAllBusinesses();
  }

  /// Ajoute la page suivante de [filtre] à sa liste.
  Future<void> chargerPlus(FiltreCommerces filtre) async {
    if (state.chargementPlus != null || !state.encorePlus.contains(filtre)) {
      return;
    }
    state = state.copyWith(chargementPlus: filtre);
    try {
      final suite = await _pageCommerces(filtre, _lues[filtre] ?? 0);
      final toutes = [...state.liste(filtre), ...suite.commerces];
      final encore = {...state.encorePlus};
      if (suite.lues >= taillePageCommerces) {
        encore.add(filtre);
      } else {
        encore.remove(filtre);
      }
      state = state.copyWith(
        businesses: filtre == FiltreCommerces.tous ? toutes : null,
        pendingVerification:
            filtre == FiltreCommerces.enAttente ? toutes : null,
        boosted: filtre == FiltreCommerces.boostes ? toutes : null,
        encorePlus: encore,
        finChargementPlus: true,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString(), finChargementPlus: true);
    }
  }

  Future<({List<BusinessEntity> commerces, int lues})> _pageCommerces(
    FiltreCommerces filtre,
    int decalage,
  ) async {
    var requete = _supabase.from('businesses').select();
    switch (filtre) {
      case FiltreCommerces.tous:
        break;
      case FiltreCommerces.enAttente:
        requete = requete.eq('is_verified', false);
      case FiltreCommerces.boostes:
        requete = requete.eq('is_boosted', true);
    }
    final motif = motifRecherche(state.recherche);
    if (motif != null) {
      requete = requete.or(
        clauseRecherche(['name', 'city', 'category', 'email'], motif),
      );
    }
    final rows = await requete
        .order('created_at', ascending: false)
        .range(decalage, decalage + taillePageCommerces - 1) as List;

    final commerces = <BusinessEntity>[];
    final archivees = {...ref.read(commercesArchivesProvider)};
    for (final row in rows) {
      final id = row['id'] as String?;
      if (id != null) {
        if (row['is_active'] == false) {
          archivees.add(id);
        } else {
          archivees.remove(id);
        }
      }
      try {
        commerces.add(BusinessModel.fromJson(_mapBusiness(row)).toEntity());
      } catch (e) {
        // Ligne illisible : sautée de l'affichage, comptée dans `_lues`.
      }
    }
    ref.read(commercesArchivesProvider.notifier).state = archivees;
    _lues[filtre] = decalage + rows.length;
    return (commerces: commerces, lues: rows.length);
  }

  /// Appelle une RPC d'administration de l'annuaire, recharge, et dit pourquoi
  /// en cas de refus. Les écritures directes sur `businesses` n'existent plus
  /// pour un administrateur (policies et exemption du déclencheur retirées par
  /// la migration 20261018190000) : tout passe par ces fonctions, qui exigent
  /// la permission, une base ou un motif, et écrivent l'audit.
  Future<bool> _rpcAnnuaire(String fonction, Map<String, dynamic> params) async {
    try {
      await _supabase.rpc(fonction, params: params);
      await fetchAllBusinesses();
      return true;
    } on PostgrestException catch (e) {
      // Recharger d'abord : `fetchAllBusinesses` efface `error`.
      await fetchAllBusinesses();
      state = state.copyWith(error: messageAnnuaireAdmin(e));
      return false;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Le refus du serveur, en clair. Son texte n'est repris que pour une saisie
  /// refusée (22023), où il dit quoi corriger.
  static String messageAnnuaireAdmin(PostgrestException e) => switch (e.code) {
        '42501' => "Vous n'avez pas la permission d'effectuer cette action.",
        '55000' => 'La fiche a changé entre-temps (${e.message}). Liste rechargée.',
        'P0002' => 'Fiche introuvable.',
        '22023' || '22001' => e.message,
        _ => 'Action impossible : ${e.message}',
      };

  /// Pose le badge « vérifié » ; [source] dit sur quoi (obligatoire).
  Future<bool> verifyBusiness(String businessId, {required String source}) =>
      _rpcAnnuaire('business_admin_verify', {'p_id': businessId, 'p_source': source});

  Future<bool> unverifyBusiness(String businessId, {required String motif}) =>
      _rpcAnnuaire('business_admin_unverify', {'p_id': businessId, 'p_reason': motif});

  Future<bool> toggleBoost(
    String businessId,
    bool boost, {
    int days = 30,
    required String motif,
  }) =>
      _rpcAnnuaire('business_admin_set_boost', {
        'p_id': businessId,
        'p_boosted': boost,
        'p_days': boost ? days : null,
        'p_reason': motif,
      });

  Future<bool> archiveBusiness(String businessId, {required String motif}) =>
      _rpcAnnuaire('business_admin_archive', {'p_id': businessId, 'p_reason': motif});

  Future<bool> restoreBusiness(String businessId, {required String motif}) =>
      _rpcAnnuaire('business_admin_restore', {'p_id': businessId, 'p_reason': motif});

  Future<bool> deleteBusiness(String businessId, {required String motif}) =>
      _rpcAnnuaire('business_admin_delete', {'p_id': businessId, 'p_reason': motif});
}

// ============================================================================
// CONTENT MODERATION (Events & Groups)
// ============================================================================

class AdminContentState extends Equatable {
  final List<EventEntity> events;
  final List<GroupEntity> groups;
  final bool isLoading;
  final String? error;

  const AdminContentState({
    this.events = const [],
    this.groups = const [],
    this.isLoading = false,
    this.error,
  });

  AdminContentState copyWith({
    List<EventEntity>? events,
    List<GroupEntity>? groups,
    bool? isLoading,
    String? error,
  }) {
    return AdminContentState(
      events: events ?? this.events,
      groups: groups ?? this.groups,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  @override
  List<Object?> get props => [events, groups, isLoading, error];
}

final adminContentNotifierProvider =
    NotifierProvider<AdminContentNotifier, AdminContentState>(
      AdminContentNotifier.new,
    );

class AdminContentNotifier extends Notifier<AdminContentState> {
  /// Referme le bandeau d'erreur d'un écran qui a encore sa liste.
  /// `copyWith` efface `error` dès qu'on ne le repasse pas — c'est le seul
  /// champ ainsi —, donc n'importe quel chargement l'efface aussi.
  void effacerErreur() => state = state.copyWith(error: null);

  @override
  AdminContentState build() {
    return const AdminContentState();
  }

  Future<void> fetchAllContent() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final eventsRows = await _supabase
          .from('events')
          .select()
          .order('created_at', ascending: false)
          .limit(50);

      final events = <EventEntity>[];
      for (final row in (eventsRows as List)) {
        try {
          events.add(EventModel.fromJson(_mapEvent(row)).toEntity());
        } catch (e) {
          // Skip problematic rows
        }
      }

      final groupsRows = await _supabase
          .from('groups')
          .select()
          .order('created_at', ascending: false)
          .limit(50);

      final groups = <GroupEntity>[];
      for (final row in (groupsRows as List)) {
        try {
          groups.add(GroupModel.fromJson(_mapGroup(row)).toEntity());
        } catch (e) {
          // Skip problematic rows
        }
      }

      state = state.copyWith(isLoading: false, events: events, groups: groups);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Supprime un événement par `event_admin_delete` : superAdmin seul, motif
  /// obligatoire, historique conservé. Plus de `DELETE` direct (la policy est
  /// retirée) ; le serveur écrit l'audit dans la même transaction.
  Future<bool> deleteEvent(String eventId, {required String motif}) async {
    try {
      await _supabase.rpc('event_admin_delete',
          params: {'p_id': eventId, 'p_reason': motif});
      await CacheService.instance.removeCachedEvent(eventId);
      forgetDeletedEvent(ref, eventId);
      await fetchAllContent();
      return true;
    } on PostgrestException catch (e) {
      // Recharger d'abord : `fetchAllContent` efface `error`.
      await fetchAllContent();
      state = state.copyWith(error: messageEvenementAdmin(e));
      return false;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Annule un événement par `event_admin_cancel` : motif obligatoire, ancienne
  /// et nouvelle valeur consignées dans l'historique de l'événement.
  Future<bool> cancelEvent(String eventId, {required String motif}) async {
    try {
      await _supabase.rpc('event_admin_cancel',
          params: {'p_id': eventId, 'p_reason': motif});
      await fetchAllContent();
      return true;
    } on PostgrestException catch (e) {
      await fetchAllContent();
      state = state.copyWith(error: messageEvenementAdmin(e));
      return false;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Le refus du serveur, en clair. Le texte du serveur n'est repris que pour
  /// une saisie refusée (22023), où il dit quoi corriger.
  static String messageEvenementAdmin(PostgrestException e) => switch (e.code) {
        '42501' => "Vous n'avez pas la permission d'effectuer cette action.",
        '55000' =>
          "L'événement a changé entre-temps (déjà annulé ou terminé). Liste rechargée.",
        'P0002' => 'Événement introuvable.',
        '22023' || '22001' => e.message,
        _ => 'Action impossible : ${e.message}',
      };

  Future<bool> deleteGroup(
    String groupId, {
    required String adminId,
    String? adminName,
  }) async {
    try {
      final deleted = await _supabase
          .from('groups')
          .delete()
          .eq('id', groupId)
          .select('id');
      if ((deleted as List).isEmpty) {
        state = state.copyWith(error: 'Groupe non supprimé : $_aucuneLigne');
        return false;
      }

      final echecJournal = await AdminAuditHelper.log(
        adminId: adminId,
        adminName: adminName,
        action: 'delete_group',
        targetType: 'group',
        targetId: groupId,
      );

      await fetchAllContent();
      if (echecJournal != null) {
        state = state.copyWith(error: echecJournal);
        return false;
      }
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> toggleGroupPrivacy(
    String groupId,
    bool isPrivate, {
    required String adminId,
    String? adminName,
  }) async {
    try {
      final updated = await _supabase
          .from('groups')
          .update({
            'is_private': isPrivate,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', groupId)
          .select('id');
      if ((updated as List).isEmpty) {
        state = state.copyWith(
          error: 'Confidentialité du groupe non modifiée : $_aucuneLigne',
        );
        return false;
      }

      final echecJournal = await AdminAuditHelper.log(
        adminId: adminId,
        adminName: adminName,
        action: 'toggle_privacy',
        targetType: 'group',
        targetId: groupId,
        details: {'isPrivate': isPrivate},
      );

      await fetchAllContent();
      if (echecJournal != null) {
        state = state.copyWith(error: echecJournal);
        return false;
      }
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }
}

// ============================================================================
// REPORTS MANAGEMENT
// ============================================================================

class ContentSnapshotData {
  final String? text;
  final String? imageUrl;
  final String? videoUrl;
  final String? fileUrl;
  final String? fileName;
  final String? contentType;
  final Map<String, dynamic>? metadata;
  final DateTime? capturedAt;

  const ContentSnapshotData({
    this.text,
    this.imageUrl,
    this.videoUrl,
    this.fileUrl,
    this.fileName,
    this.contentType,
    this.metadata,
    this.capturedAt,
  });

  factory ContentSnapshotData.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const ContentSnapshotData();
    return ContentSnapshotData(
      text: data['text'] as String?,
      imageUrl: data['imageUrl'] as String?,
      videoUrl: data['videoUrl'] as String?,
      fileUrl: data['fileUrl'] as String?,
      fileName: data['fileName'] as String?,
      contentType: data['contentType'] as String?,
      metadata: data['metadata'] as Map<String, dynamic>?,
      capturedAt: _parseDateTime(data['capturedAt']),
    );
  }

  bool get hasContent =>
      text != null || imageUrl != null || videoUrl != null || fileUrl != null;
}

/// Nombre de signalements de l'app dans Firestore (`count()`, sans lire les
/// documents), ou zéro si la lecture est refusée : un compteur ne doit pas
/// faire tomber l'écran.
Future<int> compterSignalementsFirestore([String? statut]) async {
  try {
    Query<Map<String, dynamic>> q =
        FirebaseFirestore.instance.collection('reports');
    if (statut != null) q = q.where('status', isEqualTo: statut);
    return (await q.count().get()).count ?? 0;
  } catch (_) {
    return 0;
  }
}

class ReportEntity extends Equatable {
  final String id;
  final String reporterId;
  final String? reporterName;
  final String targetType;
  final String targetId;
  final String? targetName;
  final String? conversationId;
  final String reason;
  final String? description;
  final ContentSnapshotData? contentSnapshot;
  final String? reportedUserId;
  final String status;
  final String? adminNote;
  final String? reviewedBy;
  final DateTime? createdAt;
  final DateTime? reviewedAt;
  final bool reportedUserNotified;

  /// D'où vient la ligne : `firestore` (ce que l'app signale) ou `supabase`
  /// (les avis). Décide où le panneau écrit sa décision.
  final String source;

  const ReportEntity({
    required this.id,
    required this.reporterId,
    this.reporterName,
    required this.targetType,
    required this.targetId,
    this.targetName,
    this.conversationId,
    required this.reason,
    this.description,
    this.contentSnapshot,
    this.reportedUserId,
    this.status = 'pending',
    this.adminNote,
    this.reviewedBy,
    this.createdAt,
    this.reviewedAt,
    this.reportedUserNotified = false,
    this.source = 'supabase',
  });

  @override
  List<Object?> get props => [
    id,
    reporterId,
    reporterName,
    targetType,
    targetId,
    targetName,
    conversationId,
    reason,
    description,
    contentSnapshot,
    reportedUserId,
    status,
    adminNote,
    reviewedBy,
    createdAt,
    reviewedAt,
    reportedUserNotified,
    source,
  ];
}

/// Statuts d'un signalement tant qu'il n'est pas décidé : l'onglet « En
/// attente » les réunit (le workflow a ajouté `reviewing` et `escalated`).
const List<String> statutsSignalementEnAttente = [
  'pending',
  'reviewing',
  'escalated',
];

/// Statuts d'un signalement décidé : l'onglet « Traités ».
const List<String> statutsSignalementDecides = ['resolved', 'dismissed'];

/// Les trois onglets de l'écran Signalements, chacun une requête paginée.
enum FiltreSignalements { enAttente, traites, tous }

/// Taille d'une page de l'écran Signalements.
const int taillePageSignalements = 50;

/// Compteurs réels de la table `reports` (requêtes `count`), indépendants des
/// pages chargées et des filtres de l'écran.
class CompteursSignalements extends Equatable {
  const CompteursSignalements({
    this.total = 0,
    this.enAttente = 0,
    this.traites = 0,
    this.rejetes = 0,
  });

  final int total;
  final int enAttente;

  /// Statut `resolved`.
  final int traites;

  /// Statut `dismissed`.
  final int rejetes;

  @override
  List<Object?> get props => [total, enAttente, traites, rejetes];
}

class AdminReportsState extends Equatable {
  /// Onglet « Tous ».
  final List<ReportEntity> reports;
  final List<ReportEntity> pendingReports;

  /// Onglet « Traités » : tout ce qui n'est plus `pending`.
  final List<ReportEntity> treatedReports;
  final CompteursSignalements compteurs;

  /// Recherche (texte libre) et type de cible, appliqués côté serveur.
  final String recherche;
  final String? typeFiltre;

  final Set<FiltreSignalements> encorePlus;
  final FiltreSignalements? chargementPlus;
  final bool isLoading;
  final String? error;

  const AdminReportsState({
    this.reports = const [],
    this.pendingReports = const [],
    this.treatedReports = const [],
    this.compteurs = const CompteursSignalements(),
    this.recherche = '',
    this.typeFiltre,
    this.encorePlus = const {},
    this.chargementPlus,
    this.isLoading = false,
    this.error,
  });

  List<ReportEntity> liste(FiltreSignalements f) => switch (f) {
        FiltreSignalements.enAttente => pendingReports,
        FiltreSignalements.traites => treatedReports,
        FiltreSignalements.tous => reports,
      };

  AdminReportsState copyWith({
    List<ReportEntity>? reports,
    List<ReportEntity>? pendingReports,
    List<ReportEntity>? treatedReports,
    CompteursSignalements? compteurs,
    String? recherche,
    String? typeFiltre,
    bool effacerTypeFiltre = false,
    Set<FiltreSignalements>? encorePlus,
    FiltreSignalements? chargementPlus,
    bool finChargementPlus = false,
    bool? isLoading,
    String? error,
  }) {
    return AdminReportsState(
      reports: reports ?? this.reports,
      pendingReports: pendingReports ?? this.pendingReports,
      treatedReports: treatedReports ?? this.treatedReports,
      compteurs: compteurs ?? this.compteurs,
      recherche: recherche ?? this.recherche,
      typeFiltre: effacerTypeFiltre ? null : (typeFiltre ?? this.typeFiltre),
      encorePlus: encorePlus ?? this.encorePlus,
      chargementPlus:
          finChargementPlus ? null : (chargementPlus ?? this.chargementPlus),
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  @override
  List<Object?> get props => [
    reports,
    pendingReports,
    treatedReports,
    compteurs,
    recherche,
    typeFiltre,
    encorePlus,
    chargementPlus,
    isLoading,
    error,
  ];
}

/// Motif `ilike` d'une recherche de signalements, ou null si elle est vide.
///
/// Il part dans un filtre `or(...)` de PostgREST, où la virgule, les
/// parenthèses et les guillemets sont de la syntaxe : on les retire plutôt que
/// de laisser une saisie réécrire le filtre. `%` et `_` saisis sont des
/// caractères, pas des jokers.
String? motifRechercheSignalements(String saisie) {
  final propre = saisie
      .replaceAll(RegExp(r'[,()"\\*]'), ' ')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_')
      .trim();
  if (propre.isEmpty) return null;
  return '%$propre%';
}

/// Clause `or(...)` qui cherche [motif] dans les cinq champs que l'écran
/// cherchait déjà côté client.
String clauseRechercheSignalements(String motif) => [
      'target_name',
      'reporter_name',
      'reason',
      'target_id',
      'description',
    ].map((c) => '$c.ilike.$motif').join(',');

final adminReportsNotifierProvider =
    NotifierProvider<AdminReportsNotifier, AdminReportsState>(
      AdminReportsNotifier.new,
    );

class AdminReportsNotifier extends Notifier<AdminReportsState> {
  /// Referme le bandeau d'erreur d'un écran qui a encore sa liste.
  /// `copyWith` efface `error` dès qu'on ne le repasse pas — c'est le seul
  /// champ ainsi —, donc n'importe quel chargement l'efface aussi.
  void effacerErreur() => state = state.copyWith(error: null);

  @override
  AdminReportsState build() {
    return const AdminReportsState();
  }

  /// Une fusion par onglet : elle tient les curseurs des deux sources.
  final Map<FiltreSignalements, FusionPaginee<ReportEntity>> _fusions = {};

  /// Ce que Firestore a répondu de faux au dernier chargement, ou null.
  /// Une panne de Firestore (règle, index) ne vide pas la liste Supabase : elle
  /// se dit en bandeau.
  String? _avertissementFirestore;

  FusionPaginee<ReportEntity> _nouvelleFusion(FiltreSignalements f) {
    DocumentSnapshot<Map<String, dynamic>>? curseur;
    var decalageSupabase = 0;
    return FusionPaginee<ReportEntity>(
      avant: plusRecentDabord,
      sources: [
        () async {
          try {
            final lot = await _lotFirestore(f, curseur);
            curseur = lot.curseur ?? curseur;
            return (items: lot.items, fini: lot.fini);
          } catch (e) {
            _avertissementFirestore =
                'Signalements de l\'app illisibles : ${messageErreurUsager(e)}';
            return (items: <ReportEntity>[], fini: true);
          }
        },
        () async {
          final items = await _pageSupabase(f, decalageSupabase);
          decalageSupabase += items.length;
          return (items: items, fini: items.length < taillePageSignalements);
        },
      ],
    );
  }

  /// Recharge la première page des trois onglets et les compteurs, avec la
  /// recherche et le type courants.
  Future<void> fetchAllReports() async {
    state = state.copyWith(isLoading: true, error: null);
    _avertissementFirestore = null;
    try {
      _fusions
        ..clear()
        ..addEntries([
          for (final f in FiltreSignalements.values)
            MapEntry(f, _nouvelleFusion(f)),
        ]);
      final pages = await Future.wait([
        for (final f in FiltreSignalements.values)
          _fusions[f]!.prochainePage(taillePageSignalements),
      ]);
      final compteurs = await _compteursSignalements();
      state = state.copyWith(
        isLoading: false,
        pendingReports: pages[0],
        treatedReports: pages[1],
        reports: pages[2],
        compteurs: compteurs,
        encorePlus: {
          for (final f in FiltreSignalements.values)
            if (_fusions[f]!.encorePlus) f,
        },
        error: _avertissementFirestore,
        finChargementPlus: true,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Applique [texte] côté serveur et recharge. L'écran l'appelle après un
  /// délai de frappe.
  Future<void> rechercher(String texte) {
    state = state.copyWith(recherche: texte.trim());
    return fetchAllReports();
  }

  /// Filtre par type de cible (`user`, `message`…), ou null pour tous.
  Future<void> filtrerType(String? type) {
    state = type == null
        ? state.copyWith(effacerTypeFiltre: true)
        : state.copyWith(typeFiltre: type);
    return fetchAllReports();
  }

  /// Retire la recherche et le type d'un seul rechargement.
  Future<void> viderFiltres() {
    state = state.copyWith(recherche: '', effacerTypeFiltre: true);
    return fetchAllReports();
  }

  /// Ajoute la page suivante de [filtre] à son onglet.
  Future<void> chargerPlus(FiltreSignalements filtre) async {
    final fusion = _fusions[filtre];
    if (fusion == null ||
        state.chargementPlus != null ||
        !state.encorePlus.contains(filtre)) {
      return;
    }
    state = state.copyWith(chargementPlus: filtre);
    _avertissementFirestore = null;
    try {
      final suite = await fusion.prochainePage(taillePageSignalements);
      final toutes = [...state.liste(filtre), ...suite];
      final encore = {...state.encorePlus};
      if (fusion.encorePlus) {
        encore.add(filtre);
      } else {
        encore.remove(filtre);
      }
      state = state.copyWith(
        pendingReports: filtre == FiltreSignalements.enAttente ? toutes : null,
        treatedReports: filtre == FiltreSignalements.traites ? toutes : null,
        reports: filtre == FiltreSignalements.tous ? toutes : null,
        encorePlus: encore,
        error: _avertissementFirestore,
        finChargementPlus: true,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString(), finChargementPlus: true);
    }
  }

  /// Lots lus par une source Firestore avant d'en rendre la main : au-delà,
  /// une recherche rare sur une grosse collection lirait tout d'un coup.
  static const int _plafondLecturesFirestore = 500;

  /// Le lot suivant de `reports` (Firestore), dans l'ordre du plus récent.
  ///
  /// Le type et la recherche se filtrent ICI, sur les documents lus : les
  /// anciens écrivains de l'app posent `type` au lieu de `targetType`, donc
  /// une requête `where('targetType', …)` les raterait, et Firestore n'a de
  /// toute façon pas de `ilike`. Le statut, lui, part au serveur (index
  /// `status + createdAt`).
  Future<({List<ReportEntity> items, DocumentSnapshot<Map<String, dynamic>>? curseur, bool fini})>
  _lotFirestore(
    FiltreSignalements f,
    DocumentSnapshot<Map<String, dynamic>>? depuis,
  ) async {
    final garde = <ReportEntity>[];
    var curseur = depuis;
    var fini = false;
    var lus = 0;
    final type = state.typeFiltre;
    final recherche = state.recherche;

    while (garde.length < taillePageSignalements &&
        lus < _plafondLecturesFirestore) {
      Query<Map<String, dynamic>> q =
          FirebaseFirestore.instance.collection('reports');
      switch (f) {
        case FiltreSignalements.enAttente:
          q = q.where('status', isEqualTo: 'pending');
        case FiltreSignalements.traites:
          q = q.where('status', whereIn: statutsFirestoreTraites);
        case FiltreSignalements.tous:
          break;
      }
      q = q.orderBy('createdAt', descending: true);
      if (curseur != null) q = q.startAfterDocument(curseur);
      final snap = await q.limit(taillePageSignalements).get();
      lus += snap.docs.length;
      if (snap.docs.isNotEmpty) curseur = snap.docs.last;
      for (final doc in snap.docs) {
        final r = signalementDepuisFirestore(doc.id, doc.data());
        if (type != null && r.targetType != type) continue;
        if (!signalementCorrespond(r, recherche)) continue;
        garde.add(r);
      }
      if (snap.docs.length < taillePageSignalements) {
        fini = true;
        break;
      }
    }
    return (items: garde, curseur: curseur, fini: fini);
  }

  /// Une page de `public.reports` (Supabase) : les avis signalés.
  Future<List<ReportEntity>> _pageSupabase(
    FiltreSignalements filtre,
    int decalage,
  ) async {
    var requete = _supabase.from('reports').select();
    switch (filtre) {
      case FiltreSignalements.enAttente:
        requete = requete.inFilter('status', statutsSignalementEnAttente);
      case FiltreSignalements.traites:
        requete = requete.inFilter('status', statutsSignalementDecides);
      case FiltreSignalements.tous:
        break;
    }
    final type = state.typeFiltre;
    if (type != null) requete = requete.eq('target_type', type);
    final motif = motifRechercheSignalements(state.recherche);
    if (motif != null) requete = requete.or(clauseRechercheSignalements(motif));

    final rows = await requete
        .order('created_at', ascending: false)
        .range(decalage, decalage + taillePageSignalements - 1);
    return (rows as List).map(_signalementDepuisLigne).toList();
  }

  /// Compteurs réels des deux sources, additionnés. Une source qui répond
  /// mal compte zéro : les cartes ne tombent pas pour autant.
  Future<CompteursSignalements> _compteursSignalements() async {
    Future<int> supabase([List<String>? statuts]) async {
      try {
        var requete = _supabase.from('reports').select('id');
        if (statuts != null) requete = requete.inFilter('status', statuts);
        return (await requete.count(CountOption.exact)).count;
      } catch (_) {
        return 0;
      }
    }

    final r = await Future.wait([
      supabase(),
      supabase(statutsSignalementEnAttente),
      supabase(['resolved']),
      supabase(['dismissed']),
      compterSignalementsFirestore(),
      compterSignalementsFirestore('pending'),
      compterSignalementsFirestore('resolved'),
      compterSignalementsFirestore('dismissed'),
    ]);
    return CompteursSignalements(
      total: r[0] + r[4],
      enAttente: r[1] + r[5],
      traites: r[2] + r[6],
      rejetes: r[3] + r[7],
    );
  }

  ReportEntity _signalementDepuisLigne(dynamic row) {
    return ReportEntity(
      id: row['id'] as String,
      reporterId: row['reporter_id'] as String? ?? '',
      reporterName: row['reporter_name'] as String?,
      targetType: row['target_type'] as String? ?? 'unknown',
      targetId: row['target_id'] as String? ?? '',
      targetName: row['target_name'] as String?,
      conversationId: row['conversation_id'] as String?,
      reason: row['reason'] as String? ?? '',
      description: row['description'] as String?,
      contentSnapshot: row['content_snapshot'] != null
          ? ContentSnapshotData.fromMap(
              (row['content_snapshot'] as Map).cast<String, dynamic>(),
            )
          : null,
      reportedUserId: row['reported_user_id'] as String?,
      status: row['status'] as String? ?? 'pending',
      adminNote: row['admin_note'] as String?,
      reviewedBy: row['reviewed_by'] as String?,
      createdAt: _parseDateTime(row['created_at']),
      reviewedAt: _parseDateTime(row['reviewed_at']),
      reportedUserNotified: row['reported_user_notified'] as bool? ?? false,
    );
  }

  Future<bool> resolveReport(
    String reportId,
    String adminNote,
    String action, {
    required String adminId,
    String? adminName,
    String? reportedUserId,
    bool notifyUser = true,
    String? reasonCode,
  }) async {
    try {
      final firestore = _estFirestore(reportId);
      if (firestore) {
        // Un document absent LÈVE (not-found) : pas de « zéro ligne » muet.
        await FirebaseFirestore.instance
            .collection('reports')
            .doc(reportId)
            .update({
              'status': 'resolved',
              'adminNote': adminNote,
              'actionTaken': action,
              'reviewedBy': adminId,
              'reviewerName': adminName,
              'reviewedAt': FieldValue.serverTimestamp(),
            });
      } else {
        // Le serveur contrôle la transition, impose motif et justification,
        // et écrit l'audit dans la même transaction (`signalement_transition`).
        if (!await _decider(
          reportId,
          'resolved',
          motif: reasonCode,
          note: adminNote,
          action: action,
        )) {
          return false;
        }
      }

      // Firestore : pas de RPC, le journal reste écrit par le panneau.
      final echecJournal = firestore
          ? await AdminAuditHelper.log(
              adminId: adminId,
              adminName: adminName,
              action: 'resolve_report',
              targetType: 'report',
              targetId: reportId,
              details: {'actionTaken': action, 'note': adminNote},
            )
          : null;

      if (notifyUser && reportedUserId != null) {
        await _notifyReportedUser(
          reportId: reportId,
          reportedUserId: reportedUserId,
          resolution: adminNote,
          contentRemoved: false,
        );
      }

      await fetchAllReports();
      if (echecJournal != null) {
        state = state.copyWith(error: echecJournal);
        return false;
      }
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Le statut du signalement dans les trois onglets chargés, ou null.
  String? _statutConnu(String reportId) {
    for (final f in FiltreSignalements.values) {
      for (final r in state.liste(f)) {
        if (r.id == reportId) return r.status;
      }
    }
    return null;
  }

  /// Une transition de `signalement_transition`. Lève [PostgrestException].
  Future<void> _transitionner(
    String reportId,
    String vers, {
    String? motif,
    String? note,
    String? action,
  }) async {
    await _supabase.rpc('signalement_transition', params: {
      'p_report_id': reportId,
      'p_to': vers,
      'p_reason_code': motif,
      'p_note': note,
      'p_action_taken': action,
    });
  }

  /// Décide d'un signalement Supabase. Le workflow veut un dossier pris en
  /// charge avant d'être décidé : un dossier `pending` ou `escalated` passe
  /// d'abord à `reviewing` au nom de l'appelant. Si la prise en charge réussit
  /// et pas la décision, le message le dit — le dossier est alors à son nom.
  /// Rend vrai seulement si la décision est enregistrée.
  Future<bool> _decider(
    String reportId,
    String vers, {
    String? motif,
    String? note,
    String? action,
  }) async {
    var priseEnCharge = false;
    try {
      final statut = _statutConnu(reportId);
      if (statut == 'pending' || statut == 'escalated') {
        await _transitionner(reportId, 'reviewing');
        priseEnCharge = true;
      }
      await _transitionner(reportId, vers,
          motif: motif, note: note, action: action);
      return true;
    } on PostgrestException catch (e) {
      var message = messageTransitionSignalement(e);
      if (priseEnCharge) {
        message = '$message Le dossier est pris en charge à votre nom, '
            'mais pas décidé.';
      }
      // Recharger d'abord : `fetchAllReports` efface `error`.
      await fetchAllReports();
      state = state.copyWith(error: message);
      return false;
    }
  }

  /// Prend le dossier en charge (`pending`/`escalated` → `reviewing`, à votre
  /// nom) sans le décider : c'est ce qui ouvre les demandes d'informations.
  /// Rend vrai seulement si le serveur l'a accepté ; sinon `error` le dit.
  Future<bool> prendreEnCharge(String reportId) async {
    try {
      await _transitionner(reportId, 'reviewing');
      await fetchAllReports();
      return true;
    } on PostgrestException catch (e) {
      final message = messageTransitionSignalement(e);
      await fetchAllReports();
      state = state.copyWith(error: message);
      return false;
    }
  }

  /// Le signalement vient-il de Firestore ? Lu dans les trois onglets
  /// chargés ; un id inconnu est tenu pour Supabase, comme avant.
  bool _estFirestore(String reportId) {
    for (final f in FiltreSignalements.values) {
      for (final r in state.liste(f)) {
        if (r.id == reportId) return r.source == sourceFirestore;
      }
    }
    return false;
  }

  Future<void> _notifyReportedUser({
    required String reportId,
    required String reportedUserId,
    required String resolution,
    required bool contentRemoved,
  }) async {
    try {
      // RPC SECURITY DEFINER : un INSERT direct sur une notif destinée à un
      // AUTRE utilisateur (reportedUserId) est bloqué par la RLS notifications_own.
      await _supabase.rpc('create_user_notification', params: {
        'p_user_id': reportedUserId,
        'p_type': 'report_resolved',
        'p_title':
            contentRemoved ? 'Contenu supprime' : 'Signalement traite',
        'p_body': contentRemoved
            ? 'Un contenu que vous avez publie a ete signale et supprime pour violation de nos regles communautaires.'
            : "Un signalement concernant votre contenu a ete examine. Aucune action n'a ete prise.",
        'p_data': {
          'reportId': reportId,
          'resolution': resolution,
          'contentRemoved': contentRemoved,
          // Les deux écritures de la cible, comme partout ailleurs :
          // `NotificationSupabaseDataSource.fromRow` essaie `targetId` puis
          // `target_id`, et `NotificationReadSync` ne sait marquer lue qu'une
          // notification dont il retrouve la cible. Sans elles, celle-ci
          // restait non lue pour toujours.
          'targetId': reportId,
          'target_id': reportId,
        },
      });

      if (_estFirestore(reportId)) {
        await FirebaseFirestore.instance
            .collection('reports')
            .doc(reportId)
            .update({'reportedUserNotified': true});
      } else {
        await _supabase
            .from('reports')
            .update({'reported_user_notified': true})
            .eq('id', reportId);
      }
    } catch (e) {
      debugPrint('Failed to notify reported user: $e');
    }
  }

  Future<bool> dismissReport(
    String reportId,
    String reason, {
    required String adminId,
    String? adminName,
    String? reasonCode,
  }) async {
    try {
      final firestore = _estFirestore(reportId);
      if (firestore) {
        await FirebaseFirestore.instance
            .collection('reports')
            .doc(reportId)
            .update({
              'status': 'dismissed',
              'adminNote': reason,
              'reviewedBy': adminId,
              'reviewerName': adminName,
              'reviewedAt': FieldValue.serverTimestamp(),
            });
      } else {
        if (!await _decider(
          reportId,
          'dismissed',
          motif: reasonCode,
          note: reason,
        )) {
          return false;
        }
      }

      final echecJournal = firestore
          ? await AdminAuditHelper.log(
              adminId: adminId,
              adminName: adminName,
              action: 'dismiss_report',
              targetType: 'report',
              targetId: reportId,
              details: {'reason': reason},
            )
          : null;

      await fetchAllReports();
      if (echecJournal != null) {
        state = state.copyWith(error: echecJournal);
        return false;
      }
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Supprime le contenu visé par un signalement, et ne le dit que si une
  /// ligne a réellement disparu.
  ///
  /// Avant : `_getTableForType` rendait `null` en silence pour `user`,
  /// `conversation`, `post`, `comment` et `audio_room`, le `delete` partait
  /// sans `.select()` (zéro ligne sous RLS, aucune erreur), la fonction
  /// rendait vrai dans les deux cas et l'auteur recevait « Contenu supprimé »
  /// pour un contenu toujours en ligne (audit du 2026-10-14, § 8). La
  /// notification ne part plus qu'après une suppression effective.
  Future<bool> deleteReportedContent(
    String targetType,
    String targetId, {
    required String adminId,
    String? adminName,
    String? reportId,
    String? reportedUserId,
    bool notifyUser = true,
  }) async {
    try {
      final table = _tablesSupprimables[targetType];
      if (table == null) {
        final motif =
            _motifsNonSupprimables[targetType] ??
            'type de contenu inconnu du panneau';
        state = state.copyWith(
          error: 'Suppression impossible pour « $targetType » : $motif.',
        );
        return false;
      }

      final deleted = await _supabase
          .from(table)
          .delete()
          .eq('id', targetId)
          .select('id');
      if ((deleted as List).isEmpty) {
        state = state.copyWith(
          error: targetType == 'message'
              ? 'Message non supprimé : $_aucuneLigne — un message chiffré '
                    '(MLS) vit dans `mls_messages`, hors de portée du panneau'
              : 'Contenu non supprimé ($targetType) : $_aucuneLigne',
        );
        return false;
      }

      final echecJournal = await AdminAuditHelper.log(
        adminId: adminId,
        adminName: adminName,
        action: 'delete_content',
        targetType: targetType,
        targetId: targetId,
      );

      if (notifyUser && reportedUserId != null && reportId != null) {
        await _notifyReportedUser(
          reportId: reportId,
          reportedUserId: reportedUserId,
          resolution: 'Contenu supprime pour violation des regles',
          contentRemoved: true,
        );
      }

      if (echecJournal != null) {
        state = state.copyWith(error: echecJournal);
        return false;
      }
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Types de contenu que le panneau sait effacer, et la table de chacun.
  /// `message` vise `messages` : un message chiffré (MLS) vit dans
  /// `mls_messages` et n'y sera pas trouvé — la fonction rend alors faux au
  /// lieu de mentir.
  static const Map<String, String> _tablesSupprimables = {
    'message': 'messages',
    'event': 'events',
    'group': 'groups',
    'business': 'businesses',
    // Posé par `avis_signaler` ; la policy de retrait laisse l'admin
    // supprimer, et le déclencheur d'agrégat recalcule la note de la fiche.
    'business_review': 'business_reviews',
    'product': 'products',
  };

  /// Types signalables sans table effaçable depuis le panneau, avec le motif
  /// rendu à l'écran : tous ceux de `ReportTargetType` et du CHECK de
  /// `reports.target_type` qui ne sont pas dans `_tablesSupprimables`.
  static const Map<String, String> _motifsNonSupprimables = {
    'user':
        "un compte se bannit depuis l'écran Utilisateurs, il ne se "
        "supprime pas d'ici",
    'conversation':
        'une conversation appartient à ses participants ; signalez ses '
        'messages un par un',
    'post': 'aucune table « posts » côté Supabase',
    'comment': 'aucune table « comments » côté Supabase',
    'audio_room': 'aucune table « audio_rooms » côté Supabase',
  };
}

// ============================================================================
// MARKETPLACE MANAGEMENT
// ============================================================================

/// Les trois listes de l'écran Marketplace, chacune paginée.
enum ListeMarketplace { produits, commandes, litiges }

/// Taille d'une page de l'écran Marketplace.
const int taillePageMarketplace = 50;

class AdminMarketplaceState extends Equatable {
  final List<ProductEntity> products;
  final List<Map<String, dynamic>> orders;
  final List<Map<String, dynamic>> disputes;
  final Set<ListeMarketplace> encorePlus;
  final ListeMarketplace? chargementPlus;

  /// Recherche commune aux trois listes : titre, description et catégorie des
  /// produits ; noms de l'acheteur et du vendeur des commandes et des litiges.
  final String recherche;
  final bool isLoading;
  final String? error;

  const AdminMarketplaceState({
    this.products = const [],
    this.orders = const [],
    this.disputes = const [],
    this.encorePlus = const {},
    this.chargementPlus,
    this.recherche = '',
    this.isLoading = false,
    this.error,
  });

  AdminMarketplaceState copyWith({
    List<ProductEntity>? products,
    List<Map<String, dynamic>>? orders,
    List<Map<String, dynamic>>? disputes,
    Set<ListeMarketplace>? encorePlus,
    ListeMarketplace? chargementPlus,
    bool finChargementPlus = false,
    String? recherche,
    bool? isLoading,
    String? error,
  }) {
    return AdminMarketplaceState(
      products: products ?? this.products,
      orders: orders ?? this.orders,
      disputes: disputes ?? this.disputes,
      encorePlus: encorePlus ?? this.encorePlus,
      chargementPlus:
          finChargementPlus ? null : (chargementPlus ?? this.chargementPlus),
      recherche: recherche ?? this.recherche,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  @override
  List<Object?> get props => [
    products,
    orders,
    disputes,
    encorePlus,
    chargementPlus,
    recherche,
    isLoading,
    error,
  ];
}

final adminMarketplaceNotifierProvider =
    NotifierProvider<AdminMarketplaceNotifier, AdminMarketplaceState>(
      AdminMarketplaceNotifier.new,
    );

class AdminMarketplaceNotifier extends Notifier<AdminMarketplaceState> {
  /// Referme le bandeau d'erreur d'un écran qui a encore sa liste.
  /// `copyWith` efface `error` dès qu'on ne le repasse pas — c'est le seul
  /// champ ainsi —, donc n'importe quel chargement l'efface aussi.
  void effacerErreur() => state = state.copyWith(error: null);

  @override
  AdminMarketplaceState build() {
    return const AdminMarketplaceState();
  }

  /// Ajuste « il y a encore une page » pour [liste] selon la page reçue.
  Set<ListeMarketplace> _encore(ListeMarketplace liste, int recues) {
    final encore = {...state.encorePlus};
    if (recues >= taillePageMarketplace) {
      encore.add(liste);
    } else {
      encore.remove(liste);
    }
    return encore;
  }

  Future<List<ProductEntity>> _pageProduits(int decalage) async {
    var requete = _supabase.from('products').select();
    final motif = motifRecherche(state.recherche);
    if (motif != null) {
      requete = requete.or(
        clauseRecherche(['title', 'description', 'category'], motif),
      );
    }
    final rows = await requete
        .order('created_at', ascending: false)
        .range(decalage, decalage + taillePageMarketplace - 1);
    return (rows as List)
        .map((row) => ProductModel.fromJson(_mapProduct(row)).toEntity())
        .toList();
  }

  Future<List<Map<String, dynamic>>> _pageCommandes(
    int decalage, {
    bool litigesSeulement = false,
  }) async {
    var requete = _supabase.from('orders').select();
    if (litigesSeulement) requete = requete.eq('is_in_dispute', true);
    final motif = motifRecherche(state.recherche);
    if (motif != null) {
      requete = requete.or(
        clauseRecherche(['buyer_name', 'seller_name'], motif),
      );
    }
    final rows = await requete
        .order('created_at', ascending: false)
        .range(decalage, decalage + taillePageMarketplace - 1);
    return (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  /// Applique [texte] aux trois listes côté serveur et les recharge.
  Future<void> rechercher(String texte) async {
    state = state.copyWith(recherche: texte.trim());
    await Future.wait([fetchAllProducts(), fetchOrders(), fetchDisputes()]);
  }

  Future<void> fetchAllProducts() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final products = await _pageProduits(0);
      state = state.copyWith(
        isLoading: false,
        products: products,
        encorePlus: _encore(ListeMarketplace.produits, products.length),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> fetchOrders() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final orders = await _pageCommandes(0);
      state = state.copyWith(
        isLoading: false,
        orders: orders,
        encorePlus: _encore(ListeMarketplace.commandes, orders.length),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> fetchDisputes() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final disputes = await _pageCommandes(0, litigesSeulement: true);
      state = state.copyWith(
        isLoading: false,
        disputes: disputes,
        encorePlus: _encore(ListeMarketplace.litiges, disputes.length),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Ajoute la page suivante de [liste].
  Future<void> chargerPlus(ListeMarketplace liste) async {
    if (state.chargementPlus != null || !state.encorePlus.contains(liste)) {
      return;
    }
    state = state.copyWith(chargementPlus: liste);
    try {
      switch (liste) {
        case ListeMarketplace.produits:
          final suite = await _pageProduits(state.products.length);
          state = state.copyWith(
            products: [...state.products, ...suite],
            encorePlus: _encore(liste, suite.length),
            finChargementPlus: true,
          );
        case ListeMarketplace.commandes:
          final suite = await _pageCommandes(state.orders.length);
          state = state.copyWith(
            orders: [...state.orders, ...suite],
            encorePlus: _encore(liste, suite.length),
            finChargementPlus: true,
          );
        case ListeMarketplace.litiges:
          final suite = await _pageCommandes(
            state.disputes.length,
            litigesSeulement: true,
          );
          state = state.copyWith(
            disputes: [...state.disputes, ...suite],
            encorePlus: _encore(liste, suite.length),
            finChargementPlus: true,
          );
      }
    } catch (e) {
      state = state.copyWith(error: e.toString(), finChargementPlus: true);
    }
  }

  Future<bool> toggleProductAvailability(
    String productId,
    bool isAvailable, {
    required String adminId,
    String? adminName,
  }) async {
    try {
      final updated = await _supabase
          .from('products')
          .update({
            'is_available': isAvailable,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', productId)
          .select('id');
      if ((updated as List).isEmpty) {
        state = state.copyWith(
          error: 'Disponibilité du produit non modifiée : $_aucuneLigne',
        );
        return false;
      }

      final echecJournal = await AdminAuditHelper.log(
        adminId: adminId,
        adminName: adminName,
        action: 'toggle_product',
        targetType: 'product',
        targetId: productId,
        details: {'isAvailable': isAvailable},
      );

      await fetchAllProducts();
      if (echecJournal != null) {
        state = state.copyWith(error: echecJournal);
        return false;
      }
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> deleteProduct(
    String productId, {
    required String adminId,
    String? adminName,
  }) async {
    try {
      final deleted = await _supabase
          .from('products')
          .delete()
          .eq('id', productId)
          .select('id');
      if ((deleted as List).isEmpty) {
        state = state.copyWith(error: 'Produit non supprimé : $_aucuneLigne');
        return false;
      }

      final echecJournal = await AdminAuditHelper.log(
        adminId: adminId,
        adminName: adminName,
        action: 'delete_product',
        targetType: 'product',
        targetId: productId,
      );

      await fetchAllProducts();
      if (echecJournal != null) {
        state = state.copyWith(error: echecJournal);
        return false;
      }
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> resolveDispute(
    String orderId,
    String resolution,
    String adminNote, {
    required String adminId,
    String? adminName,
  }) async {
    try {
      final updated = await _supabase
          .from('orders')
          .update({
            'dispute_resolution': resolution,
            'dispute_note': adminNote,
            'dispute_resolved_by': adminId,
            'dispute_resolved_at': DateTime.now().toUtc().toIso8601String(),
            'is_in_dispute': false,
            'has_dispute': false,
          })
          .eq('id', orderId)
          .select('id');
      if ((updated as List).isEmpty) {
        state = state.copyWith(error: 'Litige non résolu : $_aucuneLigne');
        return false;
      }

      final echecJournal = await AdminAuditHelper.log(
        adminId: adminId,
        adminName: adminName,
        action: 'resolve_dispute',
        targetType: 'order',
        targetId: orderId,
        details: {'resolution': resolution, 'note': adminNote},
      );

      await fetchDisputes();
      if (echecJournal != null) {
        state = state.copyWith(error: echecJournal);
        return false;
      }
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }
}

// ============================================================================
// USER MANAGEMENT (Extended)
// ============================================================================

/// Arguments de la callable `setUserBanned` (`functions/bannissement.js`) :
/// `{uid, banned: true, reason}` pour bannir, `{uid, banned: false}` pour
/// débannir. Pas de `reason` au débannissement — le serveur remet
/// `ban_reason` à null lui-même — ni d'identité de l'admin : il la lit dans
/// le jeton de l'appel. Pure, pour être testée sans Firebase
/// (`test/features/admin/bannissement_callable_test.dart`).
Map<String, dynamic> argumentsSetUserBanned(
  String uid, {
  required bool banned,
  String? reason,
}) => {
  'uid': uid,
  'banned': banned,
  if (banned) 'reason': reason ?? '',
};

/// Ce que la réponse `{uid, banned, action, journalise}` de `setUserBanned`
/// dit au panneau : null si tout est fait, sinon le motif à montrer. Le
/// serveur ne lève pas quand seul le journal a été refusé (le ban, lui, est
/// posé) : le panneau le dit et rend faux, comme pour toute autre action
/// non journalisée. Une réponse d'une autre forme n'est pas un succès.
String? motifReponseSetUserBanned(dynamic reponse, {required bool banned}) {
  if (reponse is Map && reponse['journalise'] == true) return null;
  final action = banned ? 'ban_user' : 'unban_user';
  return 'Action « $action » effectuée, mais non journalisée dans '
      'admin_audit_logs.';
}

/// Les trois listes de l'écran Utilisateurs. Chacune est paginée et filtrée
/// **par le serveur** (`profils_admin_page`) : un onglet « Bannis » n'est plus
/// les bannis parmi les 50 derniers inscrits, mais tous les bannis.
enum FiltreUtilisateurs {
  tous('tous'),
  admins('admins'),
  bannis('bannis');

  const FiltreUtilisateurs(this.valeurRpc);
  final String valeurRpc;
}

/// Taille d'une page de l'écran Utilisateurs.
const int taillePageUtilisateurs = 50;

class AdminUsersState extends Equatable {
  final List<UserEntity> users;
  final List<UserEntity> bannedUsers;
  final List<UserEntity> admins;
  final bool isLoading;
  final String? error;

  /// Recherche en cours (nom ou e-mail), appliquée côté serveur.
  final String recherche;

  /// Une page de plus à demander, par liste : la dernière page reçue était
  /// pleine.
  final Set<FiltreUtilisateurs> encorePlus;

  /// Filtre dont on charge la page suivante, ou null.
  final FiltreUtilisateurs? chargementPlus;

  const AdminUsersState({
    this.users = const [],
    this.bannedUsers = const [],
    this.admins = const [],
    this.isLoading = false,
    this.error,
    this.recherche = '',
    this.encorePlus = const {},
    this.chargementPlus,
  });

  List<UserEntity> liste(FiltreUtilisateurs f) => switch (f) {
        FiltreUtilisateurs.tous => users,
        FiltreUtilisateurs.admins => admins,
        FiltreUtilisateurs.bannis => bannedUsers,
      };

  AdminUsersState copyWith({
    List<UserEntity>? users,
    List<UserEntity>? bannedUsers,
    List<UserEntity>? admins,
    bool? isLoading,
    String? error,
    String? recherche,
    Set<FiltreUtilisateurs>? encorePlus,
    FiltreUtilisateurs? chargementPlus,
    bool finChargementPlus = false,
  }) {
    return AdminUsersState(
      users: users ?? this.users,
      bannedUsers: bannedUsers ?? this.bannedUsers,
      admins: admins ?? this.admins,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      recherche: recherche ?? this.recherche,
      encorePlus: encorePlus ?? this.encorePlus,
      chargementPlus:
          finChargementPlus ? null : (chargementPlus ?? this.chargementPlus),
    );
  }

  @override
  List<Object?> get props => [
        users,
        bannedUsers,
        admins,
        isLoading,
        error,
        recherche,
        encorePlus,
        chargementPlus,
      ];
}

final adminUsersNotifierProvider =
    NotifierProvider<AdminUsersNotifier, AdminUsersState>(
      AdminUsersNotifier.new,
    );

class AdminUsersNotifier extends Notifier<AdminUsersState> {
  /// Referme le bandeau d'erreur d'un écran qui a encore sa liste.
  /// `copyWith` efface `error` dès qu'on ne le repasse pas — c'est le seul
  /// champ ainsi —, donc n'importe quel chargement l'efface aussi.
  void effacerErreur() => state = state.copyWith(error: null);

  @override
  AdminUsersState build() {
    return const AdminUsersState();
  }

  /// Recharge la première page des trois listes, avec la recherche courante.
  /// Une action (bannir, vérifier…) passe par ici pour que la liste reflète ce
  /// que le serveur a écrit.
  Future<void> fetchAllUsers() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final pages = await Future.wait([
        for (final f in FiltreUtilisateurs.values)
          _page(f, decalage: 0, recherche: state.recherche),
      ]);
      state = state.copyWith(
        isLoading: false,
        users: pages[0],
        admins: pages[1],
        bannedUsers: pages[2],
        encorePlus: {
          for (var i = 0; i < pages.length; i++)
            if (pages[i].length >= taillePageUtilisateurs)
              FiltreUtilisateurs.values[i],
        },
        finChargementPlus: true,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Applique [texte] (nom ou e-mail) côté serveur et recharge. L'écran
  /// l'appelle après un délai de frappe.
  Future<void> rechercher(String texte) {
    state = state.copyWith(recherche: texte.trim());
    return fetchAllUsers();
  }

  /// Ajoute la page suivante de [filtre] à sa liste.
  Future<void> chargerPlus(FiltreUtilisateurs filtre) async {
    if (state.chargementPlus != null || !state.encorePlus.contains(filtre)) {
      return;
    }
    state = state.copyWith(chargementPlus: filtre);
    try {
      final actuelle = state.liste(filtre);
      final suite = await _page(
        filtre,
        decalage: actuelle.length,
        recherche: state.recherche,
      );
      final toutes = [...actuelle, ...suite];
      final encore = {...state.encorePlus};
      if (suite.length >= taillePageUtilisateurs) {
        encore.add(filtre);
      } else {
        encore.remove(filtre);
      }
      state = state.copyWith(
        users: filtre == FiltreUtilisateurs.tous ? toutes : null,
        admins: filtre == FiltreUtilisateurs.admins ? toutes : null,
        bannedUsers: filtre == FiltreUtilisateurs.bannis ? toutes : null,
        encorePlus: encore,
        finChargementPlus: true,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString(), finChargementPlus: true);
    }
  }

  /// Une page de `profils_admin_page` : même porte que `profils_admin`
  /// (42501 hors administrateur), plus recherche, filtre et décalage.
  Future<List<UserEntity>> _page(
    FiltreUtilisateurs filtre, {
    required int decalage,
    required String recherche,
  }) async {
    final rows = await _supabase.rpc(
      'profils_admin_page',
      params: {
        'p_recherche': recherche.isEmpty ? null : recherche,
        'p_filtre': filtre.valeurRpc,
        'p_decalage': decalage,
        'p_limite': taillePageUtilisateurs,
      },
    );
    return (rows as List)
        .map((row) => UserModel.fromJson(_mapUser(row)).toEntity())
        .toList();
  }

  /// Bannit [userId] par la Cloud Function `setUserBanned`
  /// (`functions/bannissement.js`), plus par deux `update` Supabase directs.
  ///
  /// Le serveur fait tout, dans cet ordre : Postgres (`is_banned`,
  /// `ban_reason`, `banned_at`, `banned_by`, sentinelle `session_id` lue par
  /// `SessionService.prefixeBanni`), puis `updateUser({disabled: true})` et
  /// `revokeRefreshTokens` — ce que le panneau ne pouvait pas faire : un
  /// compte banni par le client seul gardait un jeton Firebase valide (audit
  /// du 2026-10-14, § 7.2) —, puis le journal `admin_audit_logs` par la clé
  /// de service. L'identité de l'admin vient de son jeton : rien à passer.
  ///
  /// Un refus arrive en [FirebaseFunctionsException] avec un message en
  /// français (rôle insuffisant, soi-même, un superAdmin, un admin visé par
  /// un contentMod, compte introuvable) : il est posé dans `state.error` et
  /// la méthode rend faux — l'écran n'annonce alors aucun succès.
  Future<bool> banUser(String userId, String reason) =>
      _appelerSetUserBanned(userId, banned: true, reason: reason);

  /// Débannit [userId] par `setUserBanned` : Postgres remis à zéro
  /// (`is_banned`, `ban_reason`, `banned_at`, `banned_by`, `session_id`) et
  /// compte Firebase réactivé. Voir [banUser].
  Future<bool> unbanUser(String userId) =>
      _appelerSetUserBanned(userId, banned: false);

  Future<bool> _appelerSetUserBanned(
    String userId, {
    required bool banned,
    String? reason,
  }) async {
    try {
      final reponse = await FirebaseFunctions.instance
          .httpsCallable('setUserBanned')
          .call<dynamic>(
            argumentsSetUserBanned(userId, banned: banned, reason: reason),
          );
      // Le serveur a écrit : la liste doit le refléter, journal refusé ou non.
      await fetchAllUsers();
      final motif = motifReponseSetUserBanned(reponse.data, banned: banned);
      if (motif != null) {
        state = state.copyWith(error: motif);
        return false;
      }
      return true;
    } on FirebaseFunctionsException catch (e) {
      state = state.copyWith(error: messageRefusCallable(e));
      return false;
    } catch (e) {
      state = state.copyWith(error: messageErreurUsager(e));
      return false;
    }
  }

  Future<bool> verifyProfile(
    String userId, {
    required String adminId,
    String? adminName,
  }) async {
    try {
      final updated = await _supabase
          .from('users')
          .update({
            'is_verified': true,
            'verified_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', userId)
          .select('id');
      if ((updated as List).isEmpty) {
        state = state.copyWith(error: 'Profil non vérifié : $_aucuneLigne');
        return false;
      }

      final echecJournal = await AdminAuditHelper.log(
        adminId: adminId,
        adminName: adminName,
        action: 'verify_profile',
        targetType: 'user',
        targetId: userId,
      );

      await fetchAllUsers();
      if (echecJournal != null) {
        state = state.copyWith(error: echecJournal);
        return false;
      }
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> revokeVerification(
    String userId, {
    required String adminId,
    String? adminName,
  }) async {
    try {
      final updated = await _supabase
          .from('users')
          .update({'is_verified': false, 'verified_at': null})
          .eq('id', userId)
          .select('id');
      if ((updated as List).isEmpty) {
        state = state.copyWith(
          error: 'Vérification non révoquée : $_aucuneLigne',
        );
        return false;
      }

      final echecJournal = await AdminAuditHelper.log(
        adminId: adminId,
        adminName: adminName,
        action: 'revoke_verification',
        targetType: 'user',
        targetId: userId,
      );

      await fetchAllUsers();
      if (echecJournal != null) {
        state = state.copyWith(error: echecJournal);
        return false;
      }
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getUserActivity(String userId) async {
    try {
      final rows = await _supabase
          .from('activity_logs')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50);

      return (rows as List).map((row) {
        return Map<String, dynamic>.from(row as Map);
      }).toList();
    } catch (e) {
      return [];
    }
  }
}

// ============================================================================
// TRANSACTIONS MONITORING
// ============================================================================

/// Les quatre onglets de l'écran Transferts. Chacun est une requête paginée
/// filtrée par le serveur : « Échouées » n'est plus les échecs parmi les 100
/// derniers transferts, mais tous les échecs.
enum FiltreTransferts {
  toutes(null),
  enAttente('pending'),
  echouees('failed'),
  completees('completed');

  const FiltreTransferts(this.statut);

  /// Valeur de `transactions.status`, ou null pour tout.
  final String? statut;
}

/// Taille d'une page de l'écran Transferts.
const int taillePageTransferts = 50;

class AdminTransactionsState extends Equatable {
  final List<TransactionEntity> transactions;
  final List<TransactionEntity> pendingTransactions;
  final List<TransactionEntity> failedTransactions;
  final List<TransactionEntity> completedTransactions;

  /// Nombres réels côté serveur (requêtes `count`), indépendants des pages
  /// chargées : ce sont eux que les cartes et les onglets affichent.
  final int nbEnAttente;
  final int nbEchouees;

  /// Onglets dont la dernière page reçue était pleine.
  final Set<FiltreTransferts> encorePlus;
  final FiltreTransferts? chargementPlus;

  /// Calculés sur les transferts **chargés** de l'onglet « Toutes » : ils
  /// grossissent à chaque « Charger plus ».
  final double totalVolumeUSD;
  final double totalFeesUSD;
  final Map<String, double> volumeByCurrency;
  final Map<String, double> feesByCurrency;
  final bool isLoading;
  final String? error;

  const AdminTransactionsState({
    this.transactions = const [],
    this.pendingTransactions = const [],
    this.failedTransactions = const [],
    this.completedTransactions = const [],
    this.nbEnAttente = 0,
    this.nbEchouees = 0,
    this.encorePlus = const {},
    this.chargementPlus,
    this.totalVolumeUSD = 0.0,
    this.totalFeesUSD = 0.0,
    this.volumeByCurrency = const {},
    this.feesByCurrency = const {},
    this.isLoading = false,
    this.error,
  });

  List<TransactionEntity> liste(FiltreTransferts f) => switch (f) {
        FiltreTransferts.toutes => transactions,
        FiltreTransferts.enAttente => pendingTransactions,
        FiltreTransferts.echouees => failedTransactions,
        FiltreTransferts.completees => completedTransactions,
      };

  AdminTransactionsState copyWith({
    List<TransactionEntity>? transactions,
    List<TransactionEntity>? pendingTransactions,
    List<TransactionEntity>? failedTransactions,
    List<TransactionEntity>? completedTransactions,
    int? nbEnAttente,
    int? nbEchouees,
    Set<FiltreTransferts>? encorePlus,
    FiltreTransferts? chargementPlus,
    bool finChargementPlus = false,
    double? totalVolumeUSD,
    double? totalFeesUSD,
    Map<String, double>? volumeByCurrency,
    Map<String, double>? feesByCurrency,
    bool? isLoading,
    String? error,
  }) {
    return AdminTransactionsState(
      transactions: transactions ?? this.transactions,
      pendingTransactions: pendingTransactions ?? this.pendingTransactions,
      failedTransactions: failedTransactions ?? this.failedTransactions,
      completedTransactions:
          completedTransactions ?? this.completedTransactions,
      nbEnAttente: nbEnAttente ?? this.nbEnAttente,
      nbEchouees: nbEchouees ?? this.nbEchouees,
      encorePlus: encorePlus ?? this.encorePlus,
      chargementPlus:
          finChargementPlus ? null : (chargementPlus ?? this.chargementPlus),
      totalVolumeUSD: totalVolumeUSD ?? this.totalVolumeUSD,
      totalFeesUSD: totalFeesUSD ?? this.totalFeesUSD,
      volumeByCurrency: volumeByCurrency ?? this.volumeByCurrency,
      feesByCurrency: feesByCurrency ?? this.feesByCurrency,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  @override
  List<Object?> get props => [
    transactions,
    pendingTransactions,
    failedTransactions,
    completedTransactions,
    nbEnAttente,
    nbEchouees,
    encorePlus,
    chargementPlus,
    totalVolumeUSD,
    totalFeesUSD,
    volumeByCurrency,
    feesByCurrency,
    isLoading,
    error,
  ];
}

final adminTransactionsNotifierProvider =
    NotifierProvider<AdminTransactionsNotifier, AdminTransactionsState>(
      AdminTransactionsNotifier.new,
    );

class AdminTransactionsNotifier extends Notifier<AdminTransactionsState> {
  /// Referme le bandeau d'erreur d'un écran qui a encore sa liste.
  /// `copyWith` efface `error` dès qu'on ne le repasse pas — c'est le seul
  /// champ ainsi —, donc n'importe quel chargement l'efface aussi.
  void effacerErreur() => state = state.copyWith(error: null);

  @override
  AdminTransactionsState build() {
    return const AdminTransactionsState();
  }

  /// Recharge la première page des quatre onglets et les deux compteurs.
  Future<void> fetchAllTransactions() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final pages = await Future.wait([
        for (final f in FiltreTransferts.values) _pageTransferts(f, 0),
      ]);
      final nbEnAttente = await _compter('pending');
      final nbEchouees = await _compter('failed');
      state = _avecTotaux(
        state.copyWith(
          isLoading: false,
          transactions: pages[0],
          pendingTransactions: pages[1],
          failedTransactions: pages[2],
          completedTransactions: pages[3],
          nbEnAttente: nbEnAttente,
          nbEchouees: nbEchouees,
          encorePlus: {
            for (var i = 0; i < pages.length; i++)
              if (pages[i].length >= taillePageTransferts)
                FiltreTransferts.values[i],
          },
          finChargementPlus: true,
        ),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Ajoute la page suivante de [filtre] à son onglet.
  Future<void> chargerPlus(FiltreTransferts filtre) async {
    if (state.chargementPlus != null || !state.encorePlus.contains(filtre)) {
      return;
    }
    state = state.copyWith(chargementPlus: filtre);
    try {
      final actuelle = state.liste(filtre);
      final suite = await _pageTransferts(filtre, actuelle.length);
      final toutes = [...actuelle, ...suite];
      final encore = {...state.encorePlus};
      if (suite.length >= taillePageTransferts) {
        encore.add(filtre);
      } else {
        encore.remove(filtre);
      }
      state = _avecTotaux(
        state.copyWith(
          transactions: filtre == FiltreTransferts.toutes ? toutes : null,
          pendingTransactions:
              filtre == FiltreTransferts.enAttente ? toutes : null,
          failedTransactions:
              filtre == FiltreTransferts.echouees ? toutes : null,
          completedTransactions:
              filtre == FiltreTransferts.completees ? toutes : null,
          encorePlus: encore,
          finChargementPlus: true,
        ),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString(), finChargementPlus: true);
    }
  }

  Future<List<TransactionEntity>> _pageTransferts(
    FiltreTransferts filtre,
    int decalage,
  ) async {
    var requete = _supabase.from('transactions').select();
    final statut = filtre.statut;
    if (statut != null) requete = requete.eq('status', statut);
    final rows = await requete
        .order('created_at', ascending: false)
        .range(decalage, decalage + taillePageTransferts - 1);
    return (rows as List)
        .map((row) => TransactionModel.fromJson(_mapTransaction(row)).toEntity())
        .toList();
  }

  Future<int> _compter(String statut) async {
    final r = await _supabase
        .from('transactions')
        .select('id')
        .eq('status', statut)
        .count(CountOption.exact);
    return r.count;
  }

  /// Volumes et frais des transferts complétés parmi ceux de « Toutes ».
  AdminTransactionsState _avecTotaux(AdminTransactionsState etat) {
    final currencyService = CurrencyService.instance;
    double totalVolumeUSD = 0;
    double totalFeesUSD = 0;
    final volumeByCurrency = <String, double>{};
    final feesByCurrency = <String, double>{};

    for (final t in etat.transactions.where(
      (t) => t.status == TransactionStatus.completed,
    )) {
      final currencyCode = t.currency.toUpperCase();
      final currency = CurrencyExtension.fromCode(currencyCode);

      volumeByCurrency[currencyCode] =
          (volumeByCurrency[currencyCode] ?? 0) + t.amount;
      feesByCurrency[currencyCode] = (feesByCurrency[currencyCode] ?? 0) + t.fee;

      totalVolumeUSD += currencyService.convert(t.amount, currency, Currency.usd);
      totalFeesUSD += currencyService.convert(t.fee, currency, Currency.usd);
    }
    return etat.copyWith(
      totalVolumeUSD: totalVolumeUSD,
      totalFeesUSD: totalFeesUSD,
      volumeByCurrency: volumeByCurrency,
      feesByCurrency: feesByCurrency,
    );
  }

  Future<bool> refundTransaction(
    String transactionId,
    String reason, {
    required String adminId,
    String? adminName,
  }) async {
    try {
      final updated = await _supabase
          .from('transactions')
          .update({
            'status': 'refunded',
            'refund_reason': reason,
            'refunded_by': adminId,
            'refunded_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', transactionId)
          .select('id');
      if ((updated as List).isEmpty) {
        state = state.copyWith(
          error: 'Transaction non marquée remboursée : $_aucuneLigne',
        );
        return false;
      }

      final echecJournal = await AdminAuditHelper.log(
        adminId: adminId,
        adminName: adminName,
        action: 'refund_transaction',
        targetType: 'transaction',
        targetId: transactionId,
        details: {'reason': reason},
      );

      await fetchAllTransactions();
      if (echecJournal != null) {
        state = state.copyWith(error: echecJournal);
        return false;
      }
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> markAsCompleted(
    String transactionId, {
    required String adminId,
    String? adminName,
  }) async {
    try {
      final updated = await _supabase
          .from('transactions')
          .update({
            'status': 'completed',
            'completed_by': adminId,
            'completed_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', transactionId)
          .select('id');
      if ((updated as List).isEmpty) {
        state = state.copyWith(
          error: 'Transaction non marquée complétée : $_aucuneLigne',
        );
        return false;
      }

      final echecJournal = await AdminAuditHelper.log(
        adminId: adminId,
        adminName: adminName,
        action: 'complete_transaction',
        targetType: 'transaction',
        targetId: transactionId,
      );

      await fetchAllTransactions();
      if (echecJournal != null) {
        state = state.copyWith(error: echecJournal);
        return false;
      }
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> markAsFailed(
    String transactionId,
    String reason, {
    required String adminId,
    String? adminName,
  }) async {
    try {
      final updated = await _supabase
          .from('transactions')
          .update({
            'status': 'failed',
            'failure_reason': reason,
            'failed_by': adminId,
          })
          .eq('id', transactionId)
          .select('id');
      if ((updated as List).isEmpty) {
        state = state.copyWith(
          error: 'Transaction non marquée échouée : $_aucuneLigne',
        );
        return false;
      }

      final echecJournal = await AdminAuditHelper.log(
        adminId: adminId,
        adminName: adminName,
        action: 'fail_transaction',
        targetType: 'transaction',
        targetId: transactionId,
        details: {'reason': reason},
      );

      await fetchAllTransactions();
      if (echecJournal != null) {
        state = state.copyWith(error: echecJournal);
        return false;
      }
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }
}

// ============================================================================
// ANALYTICS & REPORTS
// ============================================================================

class AnalyticsData extends Equatable {
  final Map<String, int> userGrowth;
  final Map<String, int> eventsByCategory;
  final Map<String, int> businessesByCategory;
  final int newUsersToday;
  final int newUsersThisWeek;
  final int newUsersThisMonth;

  const AnalyticsData({
    this.userGrowth = const {},
    this.eventsByCategory = const {},
    this.businessesByCategory = const {},
    this.newUsersToday = 0,
    this.newUsersThisWeek = 0,
    this.newUsersThisMonth = 0,
  });

  @override
  List<Object?> get props => [
    userGrowth,
    eventsByCategory,
    businessesByCategory,
    newUsersToday,
    newUsersThisWeek,
    newUsersThisMonth,
  ];
}

class AdminAnalyticsState extends Equatable {
  final AnalyticsData data;
  final bool isLoading;
  final String? error;

  const AdminAnalyticsState({
    this.data = const AnalyticsData(),
    this.isLoading = false,
    this.error,
  });

  AdminAnalyticsState copyWith({
    AnalyticsData? data,
    bool? isLoading,
    String? error,
  }) {
    return AdminAnalyticsState(
      data: data ?? this.data,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  @override
  List<Object?> get props => [data, isLoading, error];
}

final adminAnalyticsNotifierProvider =
    NotifierProvider<AdminAnalyticsNotifier, AdminAnalyticsState>(
      AdminAnalyticsNotifier.new,
    );

class AdminAnalyticsNotifier extends Notifier<AdminAnalyticsState> {
  @override
  AdminAnalyticsState build() {
    return const AdminAnalyticsState();
  }

  Future<void> loadAnalytics() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final now = DateTime.now();

      Future<int> countWhere(
        String table, {
        String? column,
        String? gte,
        String? lt,
      }) async {
        try {
          var q = _supabase.from(table).select('id');
          if (column != null && gte != null) {
            q = q.gte(column, gte);
          }
          if (column != null && lt != null) {
            q = (q as dynamic).lt(column, lt) as dynamic;
          }
          final resp = await (q as dynamic).count(CountOption.exact);
          return (resp as dynamic).count as int;
        } catch (_) {
          return 0;
        }
      }

      final todayStart = DateTime(now.year, now.month, now.day);
      final newUsersToday = await countWhere(
        'users',
        column: 'created_at',
        gte: todayStart.toUtc().toIso8601String(),
      );

      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final newUsersThisWeek = await countWhere(
        'users',
        column: 'created_at',
        gte: DateTime(weekStart.year, weekStart.month, weekStart.day)
            .toUtc().toIso8601String(),
      );

      final monthStart = DateTime(now.year, now.month, 1);
      final newUsersThisMonth = await countWhere(
        'users',
        column: 'created_at',
        gte: monthStart.toUtc().toIso8601String(),
      );

      // User growth by month (last 6 months)
      final userGrowth = <String, int>{};
      for (int i = 5; i >= 0; i--) {
        final month = DateTime(now.year, now.month - i, 1);
        final nextMonth = DateTime(now.year, now.month - i + 1, 1);
        try {
          final resp = await _supabase
              .from('users')
              .select('id')
              .gte('created_at', month.toUtc().toIso8601String())
              .lt('created_at', nextMonth.toUtc().toIso8601String())
              .count(CountOption.exact);
          final monthKey =
              '${month.year}-${month.month.toString().padLeft(2, '0')}';
          userGrowth[monthKey] = resp.count;
        } catch (_) {
          final monthKey =
              '${month.year}-${month.month.toString().padLeft(2, '0')}';
          userGrowth[monthKey] = 0;
        }
      }

      // Events by category
      final eventsRows = await _supabase
          .from('events')
          .select('category')
          .catchError((_) => <dynamic>[]);
      final eventsByCategory = <String, int>{};
      for (final row in (eventsRows as List)) {
        final category = (row as Map)['category'] as String? ?? 'other';
        eventsByCategory[category] = (eventsByCategory[category] ?? 0) + 1;
      }

      // Businesses by category
      final businessesRows = await _supabase
          .from('businesses')
          .select('category')
          .catchError((_) => <dynamic>[]);
      final businessesByCategory = <String, int>{};
      for (final row in (businessesRows as List)) {
        final category = (row as Map)['category'] as String? ?? 'other';
        businessesByCategory[category] =
            (businessesByCategory[category] ?? 0) + 1;
      }

      state = state.copyWith(
        isLoading: false,
        data: AnalyticsData(
          newUsersToday: newUsersToday,
          newUsersThisWeek: newUsersThisWeek,
          newUsersThisMonth: newUsersThisMonth,
          userGrowth: userGrowth,
          eventsByCategory: eventsByCategory,
          businessesByCategory: businessesByCategory,
        ),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

// ============================================================================
// GLOBAL NOTIFICATIONS
// ============================================================================

class AdminNotificationState extends Equatable {
  final List<Map<String, dynamic>> sentNotifications;
  final bool isLoading;
  final bool isSending;
  final String? error;
  final String? successMessage;

  const AdminNotificationState({
    this.sentNotifications = const [],
    this.isLoading = false,
    this.isSending = false,
    this.error,
    this.successMessage,
  });

  AdminNotificationState copyWith({
    List<Map<String, dynamic>>? sentNotifications,
    bool? isLoading,
    bool? isSending,
    String? error,
    String? successMessage,
  }) {
    return AdminNotificationState(
      sentNotifications: sentNotifications ?? this.sentNotifications,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      error: error,
      successMessage: successMessage,
    );
  }

  @override
  List<Object?> get props => [
    sentNotifications,
    isLoading,
    isSending,
    error,
    successMessage,
  ];
}

final adminNotificationNotifierProvider =
    NotifierProvider<AdminNotificationNotifier, AdminNotificationState>(
      AdminNotificationNotifier.new,
    );

class AdminNotificationNotifier extends Notifier<AdminNotificationState> {
  @override
  AdminNotificationState build() {
    return const AdminNotificationState();
  }

  Future<void> fetchSentNotifications() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final rows = await _supabase
          .from('admin_notifications')
          .select()
          .order('created_at', ascending: false)
          .limit(50);

      final notifications = (rows as List).map((row) {
        return Map<String, dynamic>.from(row as Map);
      }).toList();

      state = state.copyWith(
        isLoading: false,
        sentNotifications: notifications,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> sendGlobalNotification({
    required String title,
    required String body,
    String? targetGroup,
    Map<String, dynamic>? data,
    required String adminId,
    String? adminName,
  }) async {
    state = state.copyWith(isSending: true, error: null, successMessage: null);
    try {
      final inserted = await _supabase
          .from('admin_notifications')
          .insert({
            'sent_by': adminId,
            'title': title,
            'body': body,
            'target_type': targetGroup ?? 'all',
            'data': data ?? {},
          })
          .select('id')
          .single();

      final newId = (inserted as Map)['id'] as String? ?? '';

      final echecJournal = await AdminAuditHelper.log(
        adminId: adminId,
        adminName: adminName,
        action: 'send_notification',
        targetType: 'notification',
        targetId: newId,
        details: {'title': title, 'targetGroup': targetGroup ?? 'all'},
      );

      state = state.copyWith(
        isSending: false,
        successMessage: 'Notification envoyee avec succes',
      );
      await fetchSentNotifications();
      if (echecJournal != null) {
        state = state.copyWith(error: echecJournal);
        return false;
      }
      return true;
    } catch (e) {
      state = state.copyWith(isSending: false, error: e.toString());
      return false;
    }
  }

  Future<bool> sendTargetedNotification({
    required String title,
    required String body,
    required List<String> userIds,
    Map<String, dynamic>? data,
    required String adminId,
    String? adminName,
  }) async {
    state = state.copyWith(isSending: true, error: null, successMessage: null);
    try {
      final inserted = await _supabase
          .from('admin_notifications')
          .insert({
            'sent_by': adminId,
            'title': title,
            'body': body,
            'target_type': 'specific_users',
            'target_value': userIds.join(','),
            'data': {
              ...?data,
              'targetUserIds': userIds,
            },
          })
          .select('id')
          .single();

      final newId = (inserted as Map)['id'] as String? ?? '';

      final echecJournal = await AdminAuditHelper.log(
        adminId: adminId,
        adminName: adminName,
        action: 'send_notification',
        targetType: 'notification',
        targetId: newId,
        details: {'title': title, 'targetCount': userIds.length},
      );

      state = state.copyWith(
        isSending: false,
        successMessage:
            'Notification envoyee a ${userIds.length} utilisateurs',
      );
      await fetchSentNotifications();
      if (echecJournal != null) {
        state = state.copyWith(error: echecJournal);
        return false;
      }
      return true;
    } catch (e) {
      state = state.copyWith(isSending: false, error: e.toString());
      return false;
    }
  }

  void clearMessages() {
    state = state.copyWith(error: null, successMessage: null);
  }
}

// ============================================================================
// AUDIT LOGS
// ============================================================================

class AuditLogEntry extends Equatable {
  final String id;
  final String adminId;
  final String? adminName;
  final String action;
  final String targetType;
  final String? targetId;
  final Map<String, dynamic>? details;
  final DateTime? timestamp;

  const AuditLogEntry({
    required this.id,
    required this.adminId,
    this.adminName,
    required this.action,
    required this.targetType,
    this.targetId,
    this.details,
    this.timestamp,
  });

  @override
  List<Object?> get props => [
    id,
    adminId,
    adminName,
    action,
    targetType,
    targetId,
    details,
    timestamp,
  ];
}

class AdminAuditState extends Equatable {
  final List<AuditLogEntry> logs;
  final bool isLoading;
  final String? error;

  const AdminAuditState({
    this.logs = const [],
    this.isLoading = false,
    this.error,
  });

  AdminAuditState copyWith({
    List<AuditLogEntry>? logs,
    bool? isLoading,
    String? error,
  }) {
    return AdminAuditState(
      logs: logs ?? this.logs,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  @override
  List<Object?> get props => [logs, isLoading, error];
}

final adminAuditNotifierProvider =
    NotifierProvider<AdminAuditNotifier, AdminAuditState>(
      AdminAuditNotifier.new,
    );

class AdminAuditNotifier extends Notifier<AdminAuditState> {
  @override
  AdminAuditState build() {
    return const AdminAuditState();
  }

  Future<void> fetchAuditLogs({int limit = 100}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final rows = await _supabase
          .from('admin_audit_logs')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);

      final logs = (rows as List).map((row) {
        return AuditLogEntry(
          id: row['id'] as String,
          adminId: row['admin_id'] as String? ?? '',
          adminName: row['admin_name'] as String?,
          action: row['action'] as String? ?? '',
          targetType: row['target_type'] as String? ?? '',
          targetId: row['target_id'] as String?,
          details: (row['details'] as Map?)?.cast<String, dynamic>(),
          timestamp: _parseDateTime(row['created_at']),
        );
      }).toList();

      state = state.copyWith(isLoading: false, logs: logs);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> logAction({
    required String adminId,
    String? adminName,
    required String action,
    required String targetType,
    String? targetId,
    Map<String, dynamic>? details,
  }) async {
    try {
      await _ecrireAudit(
        action: action,
        targetType: targetType,
        targetId: targetId,
        details: details,
      );
    } catch (e) {
      // Silently fail for audit logs
    }
  }
}

/// Écrit une ligne du journal par la RPC `write_admin_audit`.
///
/// L'acteur et son nom viennent de la session côté serveur : `adminId` et
/// `adminName`, que les appelants passent encore, ne sont plus envoyés — un
/// client qui pouvait nommer l'auteur pouvait aussi en nommer un autre.
/// L'`INSERT` direct sur la table est fermé par supabase/
/// admin-audit-ecriture-par-rpc-cible.sql, à appliquer une fois ce build déployé.
Future<void> _ecrireAudit({
  required String action,
  required String targetType,
  String? targetId,
  Map<String, dynamic>? details,
}) async {
  await _supabase.rpc('write_admin_audit', params: {
    'p_action': action,
    'p_resource_type': targetType,
    'p_resource_id': targetId,
    'p_metadata': details ?? <String, dynamic>{},
  });
}

// ============================================================================
// AUDIT HELPER - Static utility for logging admin actions
// ============================================================================

/// Journal d'audit côté Supabase (`admin_audit_logs`).
///
/// `log` rend `null` quand la ligne est écrite, sinon le motif lisible, déjà
/// tracé par `debugPrint`. L'appelant le pose dans son `state.error` et rend
/// faux : un journal qui échoue doit se voir. Avant, le `catch` était vide,
/// et la table est sous RLS sans aucune policy (mesuré le 2026-09-20,
/// reconfirmé le 2026-10-14) : la piste d'audit n'a jamais rien enregistré,
/// sans qu'aucun écran le montre (audit du 2026-10-14, § 4 et § 5).
///
/// L'écriture métier précède toujours l'appel : le motif dit donc que
/// l'action a eu lieu, et que seule sa trace manque.
class AdminAuditHelper {
  static Future<String?> log({
    required String adminId,
    String? adminName,
    required String action,
    required String targetType,
    String? targetId,
    Map<String, dynamic>? details,
  }) async {
    try {
      await _ecrireAudit(
        action: action,
        targetType: targetType,
        targetId: targetId,
        details: details,
      );
      return null;
    } catch (e) {
      final motif =
          'Action « $action » effectuée, mais non journalisée dans '
          'admin_audit_logs : $e';
      debugPrint(motif);
      return motif;
    }
  }
}

// ============================================================================
// ERROR LOGS
// ============================================================================

class ErrorLogEntry extends Equatable {
  final String id;
  final String? userId;
  final String errorType;
  final String message;
  final String? stackTrace;
  final Map<String, dynamic>? context;
  final String severity;
  final String? platform;
  final DateTime? timestamp;

  const ErrorLogEntry({
    required this.id,
    this.userId,
    required this.errorType,
    required this.message,
    this.stackTrace,
    this.context,
    required this.severity,
    this.platform,
    this.timestamp,
  });

  @override
  List<Object?> get props => [
    id,
    userId,
    errorType,
    message,
    stackTrace,
    context,
    severity,
    platform,
    timestamp,
  ];
}

class AdminErrorLogsState extends Equatable {
  final List<ErrorLogEntry> logs;
  final bool isLoading;
  final String? error;

  const AdminErrorLogsState({
    this.logs = const [],
    this.isLoading = false,
    this.error,
  });

  AdminErrorLogsState copyWith({
    List<ErrorLogEntry>? logs,
    bool? isLoading,
    String? error,
  }) {
    return AdminErrorLogsState(
      logs: logs ?? this.logs,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  @override
  List<Object?> get props => [logs, isLoading, error];
}

final adminErrorLogsNotifierProvider =
    NotifierProvider<AdminErrorLogsNotifier, AdminErrorLogsState>(
      AdminErrorLogsNotifier.new,
    );

class AdminErrorLogsNotifier extends Notifier<AdminErrorLogsState> {
  @override
  AdminErrorLogsState build() {
    return const AdminErrorLogsState();
  }

  Future<void> fetchErrorLogs({int limit = 100}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final rows = await Supabase.instance.client
          .from('error_logs')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);

      final logs = (rows as List).map((row) {
        return ErrorLogEntry(
          id: row['id'] as String,
          userId: row['user_id'] as String?,
          errorType: row['error_type'] as String? ?? 'unknown',
          message: row['message'] as String? ?? '',
          stackTrace: row['stack_trace'] as String?,
          context: (row['context'] as Map?)?.cast<String, dynamic>(),
          severity: row['severity'] as String? ?? 'error',
          platform: row['platform'] as String?,
          timestamp: _parseDateTime(row['created_at']),
        );
      }).toList();

      state = state.copyWith(isLoading: false, logs: logs);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}
