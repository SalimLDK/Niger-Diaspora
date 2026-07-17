import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/currency_service.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../businesses/data/models/business_model.dart';
import '../../../businesses/domain/entities/business_entity.dart';
import '../../../events/data/models/event_model.dart';
import '../../../events/domain/entities/event_entity.dart';
import '../../../groups/data/models/group_model.dart';
import '../../../groups/domain/entities/group_entity.dart';
import '../../../marketplace/data/models/product_model.dart';
import '../../../marketplace/domain/entities/product_entity.dart';
import '../../../transfers/data/models/transaction_model.dart';
import '../../../transfers/domain/entities/transaction_entity.dart';

// ---------------------------------------------------------------------------
// Supabase client accessor
// ---------------------------------------------------------------------------

SupabaseClient get _supabase => Supabase.instance.client;

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
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
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
        // pending reports count
        _supabase
            .from('reports')
            .select('id')
            .eq('status', 'pending')
            .count(CountOption.exact)
            .then((r) => r.count)
            .catchError((_) => 0),
        // active sessions: users active in last 24 h
        _supabase
            .from('users')
            .select('id')
            .gte('last_active_at', yesterday.toIso8601String())
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
      final rows = await _supabase
          .from('users')
          .select()
          .order('created_at', ascending: false)
          .limit(20);

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
      final newSessionId =
          'force_logout_${DateTime.now().millisecondsSinceEpoch}';
      await _supabase
          .from('users')
          .update({'session_id': newSessionId})
          .eq('id', userId);

      await AdminAuditHelper.log(
        adminId: adminId,
        adminName: adminName,
        action: 'force_logout',
        targetType: 'user',
        targetId: userId,
      );

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

class AdminBusinessState extends Equatable {
  final List<BusinessEntity> businesses;
  final List<BusinessEntity> pendingVerification;
  final bool isLoading;
  final String? error;

  const AdminBusinessState({
    this.businesses = const [],
    this.pendingVerification = const [],
    this.isLoading = false,
    this.error,
  });

  AdminBusinessState copyWith({
    List<BusinessEntity>? businesses,
    List<BusinessEntity>? pendingVerification,
    bool? isLoading,
    String? error,
  }) {
    return AdminBusinessState(
      businesses: businesses ?? this.businesses,
      pendingVerification: pendingVerification ?? this.pendingVerification,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  @override
  List<Object?> get props => [
    businesses,
    pendingVerification,
    isLoading,
    error,
  ];
}

final adminBusinessNotifierProvider =
    NotifierProvider<AdminBusinessNotifier, AdminBusinessState>(
      AdminBusinessNotifier.new,
    );

class AdminBusinessNotifier extends Notifier<AdminBusinessState> {
  @override
  AdminBusinessState build() {
    return const AdminBusinessState();
  }

  Future<void> fetchAllBusinesses() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final rows = await _supabase
          .from('businesses')
          .select()
          .order('created_at', ascending: false)
          .limit(50);

      final businesses = <BusinessEntity>[];
      for (final row in (rows as List)) {
        try {
          businesses
              .add(BusinessModel.fromJson(_mapBusiness(row)).toEntity());
        } catch (e) {
          // Skip problematic rows
        }
      }

      final pending = businesses.where((b) => !b.isVerified).toList();

      state = state.copyWith(
        isLoading: false,
        businesses: businesses,
        pendingVerification: pending,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> verifyBusiness(
    String businessId, {
    required String adminId,
    String? adminName,
  }) async {
    try {
      await _supabase
          .from('businesses')
          .update({
            'is_verified': true,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', businessId);

      await AdminAuditHelper.log(
        adminId: adminId,
        adminName: adminName,
        action: 'verify_business',
        targetType: 'business',
        targetId: businessId,
      );

      await fetchAllBusinesses();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> unverifyBusiness(
    String businessId, {
    required String adminId,
    String? adminName,
  }) async {
    try {
      await _supabase
          .from('businesses')
          .update({
            'is_verified': false,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', businessId);

      await AdminAuditHelper.log(
        adminId: adminId,
        adminName: adminName,
        action: 'unverify_business',
        targetType: 'business',
        targetId: businessId,
      );

      await fetchAllBusinesses();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> toggleBoost(
    String businessId,
    bool boost, {
    int days = 30,
    required String adminId,
    String? adminName,
  }) async {
    try {
      final updates = <String, dynamic>{
        'is_boosted': boost,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (boost) {
        updates['boost_expires_at'] = DateTime.now()
            .add(Duration(days: days))
            .toIso8601String();
      } else {
        updates['boost_expires_at'] = null;
      }

      await _supabase
          .from('businesses')
          .update(updates)
          .eq('id', businessId);

      await AdminAuditHelper.log(
        adminId: adminId,
        adminName: adminName,
        action: 'toggle_boost',
        targetType: 'business',
        targetId: businessId,
        details: {'boost': boost, 'days': days},
      );

      await fetchAllBusinesses();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> deleteBusiness(
    String businessId, {
    required String adminId,
    String? adminName,
  }) async {
    try {
      await _supabase.from('businesses').delete().eq('id', businessId);

      await AdminAuditHelper.log(
        adminId: adminId,
        adminName: adminName,
        action: 'delete_business',
        targetType: 'business',
        targetId: businessId,
      );

      await fetchAllBusinesses();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }
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

  Future<bool> deleteEvent(
    String eventId, {
    required String adminId,
    String? adminName,
  }) async {
    try {
      await _supabase.from('events').delete().eq('id', eventId);

      await AdminAuditHelper.log(
        adminId: adminId,
        adminName: adminName,
        action: 'delete_event',
        targetType: 'event',
        targetId: eventId,
      );

      await fetchAllContent();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> cancelEvent(
    String eventId, {
    required String adminId,
    String? adminName,
  }) async {
    try {
      await _supabase
          .from('events')
          .update({
            'status': 'cancelled',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', eventId);

      await AdminAuditHelper.log(
        adminId: adminId,
        adminName: adminName,
        action: 'cancel_event',
        targetType: 'event',
        targetId: eventId,
      );

      await fetchAllContent();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> deleteGroup(
    String groupId, {
    required String adminId,
    String? adminName,
  }) async {
    try {
      await _supabase.from('groups').delete().eq('id', groupId);

      await AdminAuditHelper.log(
        adminId: adminId,
        adminName: adminName,
        action: 'delete_group',
        targetType: 'group',
        targetId: groupId,
      );

      await fetchAllContent();
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
      await _supabase
          .from('groups')
          .update({
            'is_private': isPrivate,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', groupId);

      await AdminAuditHelper.log(
        adminId: adminId,
        adminName: adminName,
        action: 'toggle_privacy',
        targetType: 'group',
        targetId: groupId,
        details: {'isPrivate': isPrivate},
      );

      await fetchAllContent();
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
  ];
}

class AdminReportsState extends Equatable {
  final List<ReportEntity> reports;
  final List<ReportEntity> pendingReports;
  final bool isLoading;
  final String? error;

  const AdminReportsState({
    this.reports = const [],
    this.pendingReports = const [],
    this.isLoading = false,
    this.error,
  });

  AdminReportsState copyWith({
    List<ReportEntity>? reports,
    List<ReportEntity>? pendingReports,
    bool? isLoading,
    String? error,
  }) {
    return AdminReportsState(
      reports: reports ?? this.reports,
      pendingReports: pendingReports ?? this.pendingReports,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  @override
  List<Object?> get props => [reports, pendingReports, isLoading, error];
}

final adminReportsNotifierProvider =
    NotifierProvider<AdminReportsNotifier, AdminReportsState>(
      AdminReportsNotifier.new,
    );

class AdminReportsNotifier extends Notifier<AdminReportsState> {
  @override
  AdminReportsState build() {
    return const AdminReportsState();
  }

  Future<void> fetchAllReports() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final rows = await _supabase
          .from('reports')
          .select()
          .order('created_at', ascending: false)
          .limit(100);

      final reports = (rows as List).map((row) {
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
          reportedUserNotified:
              row['reported_user_notified'] as bool? ?? false,
        );
      }).toList();

      final pending = reports.where((r) => r.status == 'pending').toList();

      state = state.copyWith(
        isLoading: false,
        reports: reports,
        pendingReports: pending,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> resolveReport(
    String reportId,
    String adminNote,
    String action, {
    required String adminId,
    String? adminName,
    String? reportedUserId,
    bool notifyUser = true,
  }) async {
    try {
      await _supabase
          .from('reports')
          .update({
            'status': 'resolved',
            'admin_note': adminNote,
            'action_taken': action,
            'reviewed_by': adminId,
            'reviewed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', reportId);

      await AdminAuditHelper.log(
        adminId: adminId,
        adminName: adminName,
        action: 'resolve_report',
        targetType: 'report',
        targetId: reportId,
        details: {'actionTaken': action, 'note': adminNote},
      );

      if (notifyUser && reportedUserId != null) {
        await _notifyReportedUser(
          reportId: reportId,
          reportedUserId: reportedUserId,
          resolution: adminNote,
          contentRemoved: false,
        );
      }

      await fetchAllReports();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
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
        },
      });

      await _supabase
          .from('reports')
          .update({'reported_user_notified': true})
          .eq('id', reportId);
    } catch (e) {
      debugPrint('Failed to notify reported user: $e');
    }
  }

  Future<bool> dismissReport(
    String reportId,
    String reason, {
    required String adminId,
    String? adminName,
  }) async {
    try {
      await _supabase
          .from('reports')
          .update({
            'status': 'dismissed',
            'admin_note': reason,
            'reviewed_by': adminId,
            'reviewed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', reportId);

      await AdminAuditHelper.log(
        adminId: adminId,
        adminName: adminName,
        action: 'dismiss_report',
        targetType: 'report',
        targetId: reportId,
        details: {'reason': reason},
      );

      await fetchAllReports();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

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
      final table = _getTableForType(targetType);
      if (table != null) {
        await _supabase.from(table).delete().eq('id', targetId);

        await AdminAuditHelper.log(
          adminId: adminId,
          adminName: adminName,
          action: 'delete_content',
          targetType: targetType,
          targetId: targetId,
        );
      }

      if (notifyUser && reportedUserId != null && reportId != null) {
        await _notifyReportedUser(
          reportId: reportId,
          reportedUserId: reportedUserId,
          resolution: 'Contenu supprime pour violation des regles',
          contentRemoved: true,
        );
      }

      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  String? _getTableForType(String type) {
    switch (type) {
      case 'message':
        return 'messages';
      case 'event':
        return 'events';
      case 'group':
        return 'groups';
      case 'business':
        return 'businesses';
      case 'product':
        return 'products';
      default:
        return null;
    }
  }
}

// ============================================================================
// MARKETPLACE MANAGEMENT
// ============================================================================

class AdminMarketplaceState extends Equatable {
  final List<ProductEntity> products;
  final List<Map<String, dynamic>> orders;
  final List<Map<String, dynamic>> disputes;
  final bool isLoading;
  final String? error;

  const AdminMarketplaceState({
    this.products = const [],
    this.orders = const [],
    this.disputes = const [],
    this.isLoading = false,
    this.error,
  });

  AdminMarketplaceState copyWith({
    List<ProductEntity>? products,
    List<Map<String, dynamic>>? orders,
    List<Map<String, dynamic>>? disputes,
    bool? isLoading,
    String? error,
  }) {
    return AdminMarketplaceState(
      products: products ?? this.products,
      orders: orders ?? this.orders,
      disputes: disputes ?? this.disputes,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  @override
  List<Object?> get props => [products, orders, disputes, isLoading, error];
}

final adminMarketplaceNotifierProvider =
    NotifierProvider<AdminMarketplaceNotifier, AdminMarketplaceState>(
      AdminMarketplaceNotifier.new,
    );

class AdminMarketplaceNotifier extends Notifier<AdminMarketplaceState> {
  @override
  AdminMarketplaceState build() {
    return const AdminMarketplaceState();
  }

  Future<void> fetchAllProducts() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final rows = await _supabase
          .from('products')
          .select()
          .order('created_at', ascending: false)
          .limit(50);

      final products = (rows as List)
          .map((row) => ProductModel.fromJson(_mapProduct(row)).toEntity())
          .toList();

      state = state.copyWith(isLoading: false, products: products);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> fetchOrders() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final rows = await _supabase
          .from('orders')
          .select()
          .order('created_at', ascending: false)
          .limit(50);

      final orders = (rows as List).map((row) {
        final data = Map<String, dynamic>.from(row as Map);
        return data;
      }).toList();

      state = state.copyWith(isLoading: false, orders: orders);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> fetchDisputes() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final rows = await _supabase
          .from('orders')
          .select()
          .eq('is_in_dispute', true)
          .order('created_at', ascending: false)
          .limit(50);

      final disputes = (rows as List).map((row) {
        final data = Map<String, dynamic>.from(row as Map);
        return data;
      }).toList();

      state = state.copyWith(isLoading: false, disputes: disputes);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> toggleProductAvailability(
    String productId,
    bool isAvailable, {
    required String adminId,
    String? adminName,
  }) async {
    try {
      await _supabase
          .from('products')
          .update({
            'is_available': isAvailable,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', productId);

      await AdminAuditHelper.log(
        adminId: adminId,
        adminName: adminName,
        action: 'toggle_product',
        targetType: 'product',
        targetId: productId,
        details: {'isAvailable': isAvailable},
      );

      await fetchAllProducts();
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
      await _supabase.from('products').delete().eq('id', productId);

      await AdminAuditHelper.log(
        adminId: adminId,
        adminName: adminName,
        action: 'delete_product',
        targetType: 'product',
        targetId: productId,
      );

      await fetchAllProducts();
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
      await _supabase
          .from('orders')
          .update({
            'dispute_resolution': resolution,
            'dispute_note': adminNote,
            'dispute_resolved_by': adminId,
            'dispute_resolved_at': DateTime.now().toIso8601String(),
            'is_in_dispute': false,
            'has_dispute': false,
          })
          .eq('id', orderId);

      await AdminAuditHelper.log(
        adminId: adminId,
        adminName: adminName,
        action: 'resolve_dispute',
        targetType: 'order',
        targetId: orderId,
        details: {'resolution': resolution, 'note': adminNote},
      );

      await fetchDisputes();
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

class AdminUsersState extends Equatable {
  final List<UserEntity> users;
  final List<UserEntity> bannedUsers;
  final List<UserEntity> admins;
  final bool isLoading;
  final String? error;

  const AdminUsersState({
    this.users = const [],
    this.bannedUsers = const [],
    this.admins = const [],
    this.isLoading = false,
    this.error,
  });

  AdminUsersState copyWith({
    List<UserEntity>? users,
    List<UserEntity>? bannedUsers,
    List<UserEntity>? admins,
    bool? isLoading,
    String? error,
  }) {
    return AdminUsersState(
      users: users ?? this.users,
      bannedUsers: bannedUsers ?? this.bannedUsers,
      admins: admins ?? this.admins,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  @override
  List<Object?> get props => [users, bannedUsers, admins, isLoading, error];
}

final adminUsersNotifierProvider =
    NotifierProvider<AdminUsersNotifier, AdminUsersState>(
      AdminUsersNotifier.new,
    );

class AdminUsersNotifier extends Notifier<AdminUsersState> {
  @override
  AdminUsersState build() {
    return const AdminUsersState();
  }

  Future<void> fetchAllUsers({int limit = 50}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final rows = await _supabase
          .from('users')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);

      final users = (rows as List)
          .map((row) => UserModel.fromJson(_mapUser(row)).toEntity())
          .toList();

      final banned = users.where((u) => u.isBanned).toList();
      final admins = users.where((u) => u.isAdmin).toList();

      state = state.copyWith(
        isLoading: false,
        users: users,
        bannedUsers: banned,
        admins: admins,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> banUser(
    String userId,
    String reason, {
    required String adminId,
    String? adminName,
  }) async {
    try {
      await _supabase.from('users').update({
        'is_banned': true,
        'ban_reason': reason,
        'banned_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      final newSessionId = 'banned_${DateTime.now().millisecondsSinceEpoch}';
      await _supabase
          .from('users')
          .update({'session_id': newSessionId})
          .eq('id', userId);

      await AdminAuditHelper.log(
        adminId: adminId,
        adminName: adminName,
        action: 'ban_user',
        targetType: 'user',
        targetId: userId,
        details: {'reason': reason},
      );

      await fetchAllUsers();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> unbanUser(
    String userId, {
    required String adminId,
    String? adminName,
  }) async {
    try {
      await _supabase.from('users').update({
        'is_banned': false,
        'ban_reason': null,
        'banned_at': null,
      }).eq('id', userId);

      await AdminAuditHelper.log(
        adminId: adminId,
        adminName: adminName,
        action: 'unban_user',
        targetType: 'user',
        targetId: userId,
      );

      await fetchAllUsers();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> promoteToAdmin(
    String userId, {
    required String adminId,
    String? adminName,
  }) async {
    try {
      await _supabase
          .from('users')
          .update({'is_admin': true})
          .eq('id', userId);

      await AdminAuditHelper.log(
        adminId: adminId,
        adminName: adminName,
        action: 'promote_admin',
        targetType: 'user',
        targetId: userId,
      );

      await fetchAllUsers();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> demoteFromAdmin(
    String userId, {
    required String adminId,
    String? adminName,
  }) async {
    try {
      await _supabase
          .from('users')
          .update({'is_admin': false})
          .eq('id', userId);

      await AdminAuditHelper.log(
        adminId: adminId,
        adminName: adminName,
        action: 'demote_admin',
        targetType: 'user',
        targetId: userId,
      );

      await fetchAllUsers();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> verifyProfile(
    String userId, {
    required String adminId,
    String? adminName,
  }) async {
    try {
      await _supabase.from('users').update({
        'is_verified': true,
        'verified_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      await AdminAuditHelper.log(
        adminId: adminId,
        adminName: adminName,
        action: 'verify_profile',
        targetType: 'user',
        targetId: userId,
      );

      await fetchAllUsers();
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
      await _supabase.from('users').update({
        'is_verified': false,
        'verified_at': null,
      }).eq('id', userId);

      await AdminAuditHelper.log(
        adminId: adminId,
        adminName: adminName,
        action: 'revoke_verification',
        targetType: 'user',
        targetId: userId,
      );

      await fetchAllUsers();
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

class AdminTransactionsState extends Equatable {
  final List<TransactionEntity> transactions;
  final List<TransactionEntity> pendingTransactions;
  final List<TransactionEntity> failedTransactions;
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
    this.totalVolumeUSD = 0.0,
    this.totalFeesUSD = 0.0,
    this.volumeByCurrency = const {},
    this.feesByCurrency = const {},
    this.isLoading = false,
    this.error,
  });

  AdminTransactionsState copyWith({
    List<TransactionEntity>? transactions,
    List<TransactionEntity>? pendingTransactions,
    List<TransactionEntity>? failedTransactions,
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
  @override
  AdminTransactionsState build() {
    return const AdminTransactionsState();
  }

  Future<void> fetchAllTransactions({int limit = 100}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final rows = await _supabase
          .from('transactions')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);

      final transactions = (rows as List)
          .map(
            (row) => TransactionModel.fromJson(_mapTransaction(row)).toEntity(),
          )
          .toList();

      final pending = transactions
          .where((t) => t.status == TransactionStatus.pending)
          .toList();
      final failed = transactions
          .where((t) => t.status == TransactionStatus.failed)
          .toList();

      final currencyService = CurrencyService.instance;
      double totalVolumeUSD = 0;
      double totalFeesUSD = 0;
      final volumeByCurrency = <String, double>{};
      final feesByCurrency = <String, double>{};

      for (final t in transactions.where(
        (t) => t.status == TransactionStatus.completed,
      )) {
        final currencyCode = t.currency.toUpperCase();
        final currency = CurrencyExtension.fromCode(currencyCode);

        volumeByCurrency[currencyCode] =
            (volumeByCurrency[currencyCode] ?? 0) + t.amount;
        feesByCurrency[currencyCode] =
            (feesByCurrency[currencyCode] ?? 0) + t.fee;

        final amountInUSD = currencyService.convert(
          t.amount,
          currency,
          Currency.usd,
        );
        final feeInUSD =
            currencyService.convert(t.fee, currency, Currency.usd);
        totalVolumeUSD += amountInUSD;
        totalFeesUSD += feeInUSD;
      }

      state = state.copyWith(
        isLoading: false,
        transactions: transactions,
        pendingTransactions: pending,
        failedTransactions: failed,
        totalVolumeUSD: totalVolumeUSD,
        totalFeesUSD: totalFeesUSD,
        volumeByCurrency: volumeByCurrency,
        feesByCurrency: feesByCurrency,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> refundTransaction(
    String transactionId,
    String reason, {
    required String adminId,
    String? adminName,
  }) async {
    try {
      await _supabase
          .from('transactions')
          .update({
            'status': 'refunded',
            'refund_reason': reason,
            'refunded_by': adminId,
            'refunded_at': DateTime.now().toIso8601String(),
          })
          .eq('id', transactionId);

      await AdminAuditHelper.log(
        adminId: adminId,
        adminName: adminName,
        action: 'refund_transaction',
        targetType: 'transaction',
        targetId: transactionId,
        details: {'reason': reason},
      );

      await fetchAllTransactions();
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
      await _supabase
          .from('transactions')
          .update({
            'status': 'completed',
            'completed_by': adminId,
            'completed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', transactionId);

      await AdminAuditHelper.log(
        adminId: adminId,
        adminName: adminName,
        action: 'complete_transaction',
        targetType: 'transaction',
        targetId: transactionId,
      );

      await fetchAllTransactions();
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
      await _supabase
          .from('transactions')
          .update({
            'status': 'failed',
            'failure_reason': reason,
            'failed_by': adminId,
          })
          .eq('id', transactionId);

      await AdminAuditHelper.log(
        adminId: adminId,
        adminName: adminName,
        action: 'fail_transaction',
        targetType: 'transaction',
        targetId: transactionId,
        details: {'reason': reason},
      );

      await fetchAllTransactions();
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
  final Map<String, double> transactionVolume;
  final Map<String, int> activeUsersByDay;
  final int newUsersToday;
  final int newUsersThisWeek;
  final int newUsersThisMonth;

  const AnalyticsData({
    this.userGrowth = const {},
    this.eventsByCategory = const {},
    this.businessesByCategory = const {},
    this.transactionVolume = const {},
    this.activeUsersByDay = const {},
    this.newUsersToday = 0,
    this.newUsersThisWeek = 0,
    this.newUsersThisMonth = 0,
  });

  @override
  List<Object?> get props => [
    userGrowth,
    eventsByCategory,
    businessesByCategory,
    transactionVolume,
    activeUsersByDay,
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
        gte: todayStart.toIso8601String(),
      );

      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final newUsersThisWeek = await countWhere(
        'users',
        column: 'created_at',
        gte: DateTime(weekStart.year, weekStart.month, weekStart.day)
            .toIso8601String(),
      );

      final monthStart = DateTime(now.year, now.month, 1);
      final newUsersThisMonth = await countWhere(
        'users',
        column: 'created_at',
        gte: monthStart.toIso8601String(),
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
              .gte('created_at', month.toIso8601String())
              .lt('created_at', nextMonth.toIso8601String())
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

      await AdminAuditHelper.log(
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

      await AdminAuditHelper.log(
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
      await _supabase.from('admin_audit_logs').insert({
        'admin_id': adminId,
        'admin_name': adminName,
        'action': action,
        'target_type': targetType,
        'target_id': targetId,
        'details': details ?? {},
      });
    } catch (e) {
      // Silently fail for audit logs
    }
  }
}

// ============================================================================
// AUDIT HELPER - Static utility for logging admin actions
// ============================================================================

class AdminAuditHelper {
  static Future<void> log({
    required String adminId,
    String? adminName,
    required String action,
    required String targetType,
    String? targetId,
    Map<String, dynamic>? details,
  }) async {
    try {
      await _supabase.from('admin_audit_logs').insert({
        'admin_id': adminId,
        'admin_name': adminName,
        'action': action,
        'target_type': targetType,
        'target_id': targetId,
        'details': details ?? {},
      });
    } catch (e) {
      // debugPrint('Failed to log audit action: $e');
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
