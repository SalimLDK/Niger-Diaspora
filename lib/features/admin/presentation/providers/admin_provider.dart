import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/services/currency_service.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../events/data/models/event_model.dart';
import '../../../groups/data/models/group_model.dart';
import '../../../events/domain/entities/event_entity.dart';
import '../../../groups/domain/entities/group_entity.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../businesses/data/models/business_model.dart';
import '../../../businesses/domain/entities/business_entity.dart';
import '../../../marketplace/data/models/product_model.dart';
import '../../../marketplace/domain/entities/product_entity.dart';
import '../../../transfers/data/models/transaction_model.dart';
import '../../../transfers/domain/entities/transaction_entity.dart';

part 'admin_provider.freezed.dart';
part 'admin_provider.g.dart';

// ============================================================================
// CURRENT ADMIN PROVIDER - Provides current admin info for audit logging
// ============================================================================

@freezed
class CurrentAdmin with _$CurrentAdmin {
  const factory CurrentAdmin({
    required String id,
    String? name,
    String? email,
  }) = _CurrentAdmin;
}

@riverpod
CurrentAdmin? currentAdmin(Ref ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;
  return CurrentAdmin(
    id: user.uid,
    name: user.displayName,
    email: user.email,
  );
}

// ============================================================================
// ADMIN DASHBOARD STATE
// ============================================================================

@freezed
class AdminDashboardState with _$AdminDashboardState {
  const factory AdminDashboardState({
    @Default(0) int totalUsers,
    @Default(0) int activeSessions,
    @Default(0) int totalEvents,
    @Default(0) int totalGroups,
    @Default(0) int totalBusinesses,
    @Default(0) int totalProducts,
    @Default(0) int totalTransactions,
    @Default(0) int pendingReports,
    @Default([]) List<UserEntity> recentUsers,
    @Default([]) List<dynamic> recentContent,
    @Default(false) bool isLoading,
    String? error,
  }) = _AdminDashboardState;
}

@riverpod
class AdminDashboardNotifier extends _$AdminDashboardNotifier {
  @override
  AdminDashboardState build() {
    return const AdminDashboardState();
  }

  Future<void> loadDashboardStats() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final firestore = FirebaseFirestore.instance;

      // Helper function to safely get count
      Future<int> safeCount(Query query) async {
        try {
          final snapshot = await query.count().get();
          return snapshot.count ?? 0;
        } catch (e) {
          // Fallback: get docs and count them (slower but more compatible)
          try {
            final docs = await query.limit(1000).get();
            return docs.docs.length;
          } catch (_) {
            return 0;
          }
        }
      }

      // Helper for collection count
      Future<int> collectionCount(String collection) async {
        return safeCount(firestore.collection(collection));
      }

      // Fetch all counts in parallel
      final results = await Future.wait([
        collectionCount('users'),
        collectionCount('events'),
        collectionCount('groups'),
        collectionCount('businesses'),
        collectionCount('products'),
        collectionCount('transactions'),
        safeCount(firestore.collection('reports').where('status', isEqualTo: 'pending')),
        safeCount(firestore.collection('users').where(
          'lastLoginAt',
          isGreaterThan: Timestamp.fromDate(
            DateTime.now().subtract(const Duration(hours: 24)),
          ),
        )),
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
      final snapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .orderBy('createdAt', descending: true)
              .limit(20)
              .get();

      final users =
          snapshot.docs
              .map((doc) => UserModel.fromFirestore(doc).toEntity())
              .toList();

      state = state.copyWith(isLoading: false, recentUsers: users);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> forceLogoutUser(String userId, {required String adminId, String? adminName}) async {
    try {
      final newSessionId =
          "force_logout_${DateTime.now().millisecondsSinceEpoch}";
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'session_id': newSessionId,
      });

      await AdminAuditHelper.log(
        adminId: adminId,
        adminName: adminName,
        action: 'force_logout',
        targetType: 'user',
        targetId: userId,
      );

      return true;
    } catch (e) {
      state = state.copyWith(error: "Failed to logout user: $e");
      return false;
    }
  }

  Future<void> fetchRecentContent() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final eventsSnapshot =
          await FirebaseFirestore.instance
              .collection('events')
              .orderBy('createdAt', descending: true)
              .limit(10)
              .get();

      final events =
          eventsSnapshot.docs
              .map((doc) => EventModel.fromFirestore(doc).toEntity())
              .toList();

      final groupsSnapshot =
          await FirebaseFirestore.instance
              .collection('groups')
              .orderBy('createdAt', descending: true)
              .limit(10)
              .get();

      final groups =
          groupsSnapshot.docs
              .map((doc) => GroupModel.fromFirestore(doc).toEntity())
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

@freezed
class AdminBusinessState with _$AdminBusinessState {
  const factory AdminBusinessState({
    @Default([]) List<BusinessEntity> businesses,
    @Default([]) List<BusinessEntity> pendingVerification,
    @Default(false) bool isLoading,
    String? error,
  }) = _AdminBusinessState;
}

@riverpod
class AdminBusinessNotifier extends _$AdminBusinessNotifier {
  @override
  AdminBusinessState build() {
    return const AdminBusinessState();
  }

  Future<void> fetchAllBusinesses() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('businesses')
              .orderBy('createdAt', descending: true)
              .limit(50)
              .get();

      final businesses = <BusinessEntity>[];
      for (final doc in snapshot.docs) {
        try {
          businesses.add(BusinessModel.fromFirestore(doc).toEntity());
        } catch (e) {
          debugPrint('Error parsing business ${doc.id}: $e');
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

  Future<bool> verifyBusiness(String businessId, {required String adminId, String? adminName}) async {
    try {
      await FirebaseFirestore.instance
          .collection('businesses')
          .doc(businessId)
          .update({
            'isVerified': true,
            'updatedAt': FieldValue.serverTimestamp(),
          });

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

  Future<bool> unverifyBusiness(String businessId, {required String adminId, String? adminName}) async {
    try {
      await FirebaseFirestore.instance
          .collection('businesses')
          .doc(businessId)
          .update({
            'isVerified': false,
            'updatedAt': FieldValue.serverTimestamp(),
          });

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
        'isBoosted': boost,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (boost) {
        updates['boostExpiresAt'] = Timestamp.fromDate(
          DateTime.now().add(Duration(days: days)),
        );
      } else {
        updates['boostExpiresAt'] = null;
      }

      await FirebaseFirestore.instance
          .collection('businesses')
          .doc(businessId)
          .update(updates);

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

  Future<bool> deleteBusiness(String businessId, {required String adminId, String? adminName}) async {
    try {
      await FirebaseFirestore.instance
          .collection('businesses')
          .doc(businessId)
          .delete();

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

@freezed
class AdminContentState with _$AdminContentState {
  const factory AdminContentState({
    @Default([]) List<EventEntity> events,
    @Default([]) List<GroupEntity> groups,
    @Default(false) bool isLoading,
    String? error,
  }) = _AdminContentState;
}

@riverpod
class AdminContentNotifier extends _$AdminContentNotifier {
  @override
  AdminContentState build() {
    return const AdminContentState();
  }

  Future<void> fetchAllContent() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // Fetch events with safe parsing
      final eventsSnapshot =
          await FirebaseFirestore.instance
              .collection('events')
              .orderBy('createdAt', descending: true)
              .limit(50)
              .get();

      final events = <EventEntity>[];
      for (final doc in eventsSnapshot.docs) {
        try {
          events.add(EventModel.fromFirestore(doc).toEntity());
        } catch (e) {
          // Skip problematic documents
          debugPrint('Error parsing event ${doc.id}: $e');
        }
      }

      // Fetch groups with safe parsing
      final groupsSnapshot =
          await FirebaseFirestore.instance
              .collection('groups')
              .orderBy('createdAt', descending: true)
              .limit(50)
              .get();

      final groups = <GroupEntity>[];
      for (final doc in groupsSnapshot.docs) {
        try {
          groups.add(GroupModel.fromFirestore(doc).toEntity());
        } catch (e) {
          // Skip problematic documents
          debugPrint('Error parsing group ${doc.id}: $e');
        }
      }

      state = state.copyWith(isLoading: false, events: events, groups: groups);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> deleteEvent(String eventId, {required String adminId, String? adminName}) async {
    try {
      await FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .delete();

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

  Future<bool> cancelEvent(String eventId, {required String adminId, String? adminName}) async {
    try {
      await FirebaseFirestore.instance.collection('events').doc(eventId).update(
        {'status': 'cancelled', 'updatedAt': FieldValue.serverTimestamp()},
      );

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

  Future<bool> deleteGroup(String groupId, {required String adminId, String? adminName}) async {
    try {
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId)
          .delete();

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

  Future<bool> toggleGroupPrivacy(String groupId, bool isPrivate, {required String adminId, String? adminName}) async {
    try {
      await FirebaseFirestore.instance.collection('groups').doc(groupId).update(
        {'isPrivate': isPrivate, 'updatedAt': FieldValue.serverTimestamp()},
      );

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

@freezed
class ReportEntity with _$ReportEntity {
  const factory ReportEntity({
    required String id,
    required String reporterId,
    String? reporterName,
    required String
    targetType, // 'user', 'message', 'event', 'group', 'business', 'product'
    required String targetId,
    String? targetName,
    required String reason,
    String? description,
    @Default('pending')
    String status, // 'pending', 'reviewed', 'resolved', 'dismissed'
    String? adminNote,
    String? reviewedBy,
    DateTime? createdAt,
    DateTime? reviewedAt,
  }) = _ReportEntity;
}

@freezed
class AdminReportsState with _$AdminReportsState {
  const factory AdminReportsState({
    @Default([]) List<ReportEntity> reports,
    @Default([]) List<ReportEntity> pendingReports,
    @Default(false) bool isLoading,
    String? error,
  }) = _AdminReportsState;
}

@riverpod
class AdminReportsNotifier extends _$AdminReportsNotifier {
  @override
  AdminReportsState build() {
    return const AdminReportsState();
  }

  Future<void> fetchAllReports() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('reports')
              .orderBy('createdAt', descending: true)
              .limit(100)
              .get();

      final reports =
          snapshot.docs.map((doc) {
            final data = doc.data();
            return ReportEntity(
              id: doc.id,
              reporterId: data['reporterId'] ?? '',
              reporterName: data['reporterName'],
              targetType: data['targetType'] ?? 'unknown',
              targetId: data['targetId'] ?? '',
              targetName: data['targetName'],
              reason: data['reason'] ?? '',
              description: data['description'],
              status: data['status'] ?? 'pending',
              adminNote: data['adminNote'],
              reviewedBy: data['reviewedBy'],
              createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
              reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
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
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('reports')
          .doc(reportId)
          .update({
            'status': 'resolved',
            'adminNote': adminNote,
            'actionTaken': action,
            'reviewedBy': adminId,
            'reviewedAt': FieldValue.serverTimestamp(),
          });

      await AdminAuditHelper.log(
        adminId: adminId,
        adminName: adminName,
        action: 'resolve_report',
        targetType: 'report',
        targetId: reportId,
        details: {'actionTaken': action, 'note': adminNote},
      );

      await fetchAllReports();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> dismissReport(String reportId, String reason, {required String adminId, String? adminName}) async {
    try {
      await FirebaseFirestore.instance
          .collection('reports')
          .doc(reportId)
          .update({
            'status': 'dismissed',
            'adminNote': reason,
            'reviewedBy': adminId,
            'reviewedAt': FieldValue.serverTimestamp(),
          });

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

  Future<bool> deleteReportedContent(String targetType, String targetId, {required String adminId, String? adminName}) async {
    try {
      final collection = _getCollectionForType(targetType);
      if (collection != null) {
        await FirebaseFirestore.instance
            .collection(collection)
            .doc(targetId)
            .delete();

        await AdminAuditHelper.log(
          adminId: adminId,
          adminName: adminName,
          action: 'delete_content',
          targetType: targetType,
          targetId: targetId,
        );
      }
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  String? _getCollectionForType(String type) {
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

@freezed
class AdminMarketplaceState with _$AdminMarketplaceState {
  const factory AdminMarketplaceState({
    @Default([]) List<ProductEntity> products,
    @Default([]) List<Map<String, dynamic>> orders,
    @Default([]) List<Map<String, dynamic>> disputes,
    @Default(false) bool isLoading,
    String? error,
  }) = _AdminMarketplaceState;
}

@riverpod
class AdminMarketplaceNotifier extends _$AdminMarketplaceNotifier {
  @override
  AdminMarketplaceState build() {
    return const AdminMarketplaceState();
  }

  Future<void> fetchAllProducts() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('products')
              .orderBy('createdAt', descending: true)
              .limit(50)
              .get();

      final products =
          snapshot.docs
              .map((doc) => ProductModel.fromFirestore(doc).toEntity())
              .toList();

      state = state.copyWith(isLoading: false, products: products);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> fetchOrders() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('orders')
              .orderBy('createdAt', descending: true)
              .limit(50)
              .get();

      final orders =
          snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
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
      final snapshot =
          await FirebaseFirestore.instance
              .collection('orders')
              .where('hasDispute', isEqualTo: true)
              .orderBy('createdAt', descending: true)
              .limit(50)
              .get();

      final disputes =
          snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
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
      await FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .update({
            'isAvailable': isAvailable,
            'updatedAt': FieldValue.serverTimestamp(),
          });

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

  Future<bool> deleteProduct(String productId, {required String adminId, String? adminName}) async {
    try {
      await FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .delete();

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
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .update({
            'disputeResolution': resolution,
            'disputeNote': adminNote,
            'disputeResolvedBy': adminId,
            'disputeResolvedAt': FieldValue.serverTimestamp(),
            'hasDispute': false,
          });

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

@freezed
class AdminUsersState with _$AdminUsersState {
  const factory AdminUsersState({
    @Default([]) List<UserEntity> users,
    @Default([]) List<UserEntity> bannedUsers,
    @Default([]) List<UserEntity> admins,
    @Default(false) bool isLoading,
    String? error,
  }) = _AdminUsersState;
}

@riverpod
class AdminUsersNotifier extends _$AdminUsersNotifier {
  @override
  AdminUsersState build() {
    return const AdminUsersState();
  }

  Future<void> fetchAllUsers({int limit = 50}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .orderBy('createdAt', descending: true)
              .limit(limit)
              .get();

      final users =
          snapshot.docs
              .map((doc) => UserModel.fromFirestore(doc).toEntity())
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

  Future<bool> banUser(String userId, String reason, {required String adminId, String? adminName}) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'isBanned': true,
        'banReason': reason,
        'bannedAt': FieldValue.serverTimestamp(),
      });

      // Force logout the banned user
      final newSessionId = "banned_${DateTime.now().millisecondsSinceEpoch}";
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'session_id': newSessionId,
      });

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

  Future<bool> unbanUser(String userId, {required String adminId, String? adminName}) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'isBanned': false,
        'banReason': FieldValue.delete(),
        'bannedAt': FieldValue.delete(),
      });

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

  Future<bool> promoteToAdmin(String userId, {required String adminId, String? adminName}) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'isAdmin': true,
      });

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

  Future<bool> demoteFromAdmin(String userId, {required String adminId, String? adminName}) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'isAdmin': false,
      });

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

  Future<bool> verifyProfile(String userId, {required String adminId, String? adminName}) async {
    try {
      // Use set with merge to handle case where profile doc doesn't exist
      await FirebaseFirestore.instance
          .collection('profiles')
          .doc(userId)
          .set({
            'isVerified': true,
            'verifiedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      await AdminAuditHelper.log(
        adminId: adminId,
        adminName: adminName,
        action: 'verify_profile',
        targetType: 'user',
        targetId: userId,
      );

      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getUserActivity(String userId) async {
    try {
      final activitySnapshot =
          await FirebaseFirestore.instance
              .collection('activity_logs')
              .where('userId', isEqualTo: userId)
              .orderBy('timestamp', descending: true)
              .limit(50)
              .get();

      return activitySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      return [];
    }
  }
}

// ============================================================================
// TRANSACTIONS MONITORING
// ============================================================================

@freezed
class AdminTransactionsState with _$AdminTransactionsState {
  const factory AdminTransactionsState({
    @Default([]) List<TransactionEntity> transactions,
    @Default([]) List<TransactionEntity> pendingTransactions,
    @Default([]) List<TransactionEntity> failedTransactions,
    @Default(0.0) double totalVolumeUSD, // Total converted to USD
    @Default(0.0) double totalFeesUSD, // Fees converted to USD
    @Default(<String, double>{}) Map<String, double> volumeByCurrency, // Volume per currency
    @Default(<String, double>{}) Map<String, double> feesByCurrency, // Fees per currency
    @Default(false) bool isLoading,
    String? error,
  }) = _AdminTransactionsState;
}

@riverpod
class AdminTransactionsNotifier extends _$AdminTransactionsNotifier {
  @override
  AdminTransactionsState build() {
    return const AdminTransactionsState();
  }

  Future<void> fetchAllTransactions({int limit = 100}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('transactions')
              .orderBy('createdAt', descending: true)
              .limit(limit)
              .get();

      final transactions =
          snapshot.docs
              .map((doc) => TransactionModel.fromFirestore(doc).toEntity())
              .toList();

      final pending =
          transactions
              .where((t) => t.status == TransactionStatus.pending)
              .toList();
      final failed =
          transactions
              .where((t) => t.status == TransactionStatus.failed)
              .toList();

      // Calculate totals with proper currency conversion to USD
      final currencyService = CurrencyService.instance;
      double totalVolumeUSD = 0;
      double totalFeesUSD = 0;
      final volumeByCurrency = <String, double>{};
      final feesByCurrency = <String, double>{};

      for (final t in transactions.where(
        (t) => t.status == TransactionStatus.completed,
      )) {
        // Get the currency from the transaction
        final currencyCode = t.currency.toUpperCase();
        final currency = CurrencyExtension.fromCode(currencyCode);

        // Add to per-currency totals
        volumeByCurrency[currencyCode] = (volumeByCurrency[currencyCode] ?? 0) + t.amount;
        feesByCurrency[currencyCode] = (feesByCurrency[currencyCode] ?? 0) + t.fee;

        // Convert to USD for global total
        final amountInUSD = currencyService.convert(t.amount, currency, Currency.usd);
        final feeInUSD = currencyService.convert(t.fee, currency, Currency.usd);
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

  Future<bool> refundTransaction(String transactionId, String reason, {required String adminId, String? adminName}) async {
    try {
      await FirebaseFirestore.instance
          .collection('transactions')
          .doc(transactionId)
          .update({
            'status': 'refunded',
            'refundReason': reason,
            'refundedBy': adminId,
            'refundedAt': FieldValue.serverTimestamp(),
          });

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

  Future<bool> markAsCompleted(String transactionId, {required String adminId, String? adminName}) async {
    try {
      await FirebaseFirestore.instance
          .collection('transactions')
          .doc(transactionId)
          .update({
            'status': 'completed',
            'completedBy': adminId,
            'completedAt': FieldValue.serverTimestamp(),
          });

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

  Future<bool> markAsFailed(String transactionId, String reason, {required String adminId, String? adminName}) async {
    try {
      await FirebaseFirestore.instance
          .collection('transactions')
          .doc(transactionId)
          .update({
            'status': 'failed',
            'failureReason': reason,
            'failedBy': adminId,
          });

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

@freezed
class AnalyticsData with _$AnalyticsData {
  const factory AnalyticsData({
    @Default({}) Map<String, int> userGrowth,
    @Default({}) Map<String, int> eventsByCategory,
    @Default({}) Map<String, int> businessesByCategory,
    @Default({}) Map<String, double> transactionVolume,
    @Default({}) Map<String, int> activeUsersByDay,
    @Default(0) int newUsersToday,
    @Default(0) int newUsersThisWeek,
    @Default(0) int newUsersThisMonth,
  }) = _AnalyticsData;
}

@freezed
class AdminAnalyticsState with _$AdminAnalyticsState {
  const factory AdminAnalyticsState({
    @Default(AnalyticsData()) AnalyticsData data,
    @Default(false) bool isLoading,
    String? error,
  }) = _AdminAnalyticsState;
}

@riverpod
class AdminAnalyticsNotifier extends _$AdminAnalyticsNotifier {
  @override
  AdminAnalyticsState build() {
    return const AdminAnalyticsState();
  }

  Future<void> loadAnalytics() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final firestore = FirebaseFirestore.instance;
      final now = DateTime.now();

      // Helper function to safely get count (web compatible)
      Future<int> safeCount(Query query) async {
        try {
          final snapshot = await query.count().get();
          return snapshot.count ?? 0;
        } catch (e) {
          // Fallback: get docs and count them (slower but more compatible)
          try {
            final docs = await query.limit(1000).get();
            return docs.docs.length;
          } catch (_) {
            return 0;
          }
        }
      }

      // New users today
      final todayStart = DateTime(now.year, now.month, now.day);
      final newUsersToday = await safeCount(
        firestore
            .collection('users')
            .where('createdAt', isGreaterThan: Timestamp.fromDate(todayStart)),
      );

      // New users this week
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final newUsersThisWeek = await safeCount(
        firestore
            .collection('users')
            .where('createdAt', isGreaterThan: Timestamp.fromDate(weekStart)),
      );

      // New users this month
      final monthStart = DateTime(now.year, now.month, 1);
      final newUsersThisMonth = await safeCount(
        firestore
            .collection('users')
            .where('createdAt', isGreaterThan: Timestamp.fromDate(monthStart)),
      );

      // User growth by month (last 6 months)
      final userGrowth = <String, int>{};
      for (int i = 5; i >= 0; i--) {
        final month = DateTime(now.year, now.month - i, 1);
        final nextMonth = DateTime(now.year, now.month - i + 1, 1);
        final count = await safeCount(
          firestore
              .collection('users')
              .where(
                'createdAt',
                isGreaterThanOrEqualTo: Timestamp.fromDate(month),
              )
              .where('createdAt', isLessThan: Timestamp.fromDate(nextMonth)),
        );
        final monthKey =
            '${month.year}-${month.month.toString().padLeft(2, '0')}';
        userGrowth[monthKey] = count;
      }

      // Events by category
      final eventsSnapshot = await firestore.collection('events').get();
      final eventsByCategory = <String, int>{};
      for (final doc in eventsSnapshot.docs) {
        final category = doc.data()['category'] as String? ?? 'other';
        eventsByCategory[category] = (eventsByCategory[category] ?? 0) + 1;
      }

      // Businesses by category
      final businessesSnapshot = await firestore.collection('businesses').get();
      final businessesByCategory = <String, int>{};
      for (final doc in businessesSnapshot.docs) {
        final category = doc.data()['category'] as String? ?? 'other';
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

@freezed
class AdminNotificationState with _$AdminNotificationState {
  const factory AdminNotificationState({
    @Default([]) List<Map<String, dynamic>> sentNotifications,
    @Default(false) bool isLoading,
    @Default(false) bool isSending,
    String? error,
    String? successMessage,
  }) = _AdminNotificationState;
}

@riverpod
class AdminNotificationNotifier extends _$AdminNotificationNotifier {
  @override
  AdminNotificationState build() {
    return const AdminNotificationState();
  }

  Future<void> fetchSentNotifications() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('admin_notifications')
              .orderBy('sentAt', descending: true)
              .limit(50)
              .get();

      final notifications =
          snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
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
    String? targetGroup, // null = all, 'admins', 'verified', etc.
    Map<String, dynamic>? data,
    required String adminId,
    String? adminName,
  }) async {
    state = state.copyWith(isSending: true, error: null, successMessage: null);
    try {
      // Store the notification record
      final docRef = await FirebaseFirestore.instance.collection('admin_notifications').add({
        'title': title,
        'body': body,
        'targetGroup': targetGroup ?? 'all',
        'data': data,
        'sentBy': adminId,
        'sentAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      await AdminAuditHelper.log(
        adminId: adminId,
        adminName: adminName,
        action: 'send_notification',
        targetType: 'notification',
        targetId: docRef.id,
        details: {'title': title, 'targetGroup': targetGroup ?? 'all'},
      );

      // Note: Actual push notification sending would be handled by Cloud Functions
      // triggered by the above Firestore write

      state = state.copyWith(
        isSending: false,
        successMessage: 'Notification envoyée avec succès',
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
      final docRef = await FirebaseFirestore.instance.collection('admin_notifications').add({
        'title': title,
        'body': body,
        'targetType': 'specific_users',
        'targetUserIds': userIds,
        'data': data,
        'sentBy': adminId,
        'sentAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      await AdminAuditHelper.log(
        adminId: adminId,
        adminName: adminName,
        action: 'send_notification',
        targetType: 'notification',
        targetId: docRef.id,
        details: {'title': title, 'targetCount': userIds.length},
      );

      state = state.copyWith(
        isSending: false,
        successMessage: 'Notification envoyée à ${userIds.length} utilisateurs',
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

@freezed
class AuditLogEntry with _$AuditLogEntry {
  const factory AuditLogEntry({
    required String id,
    required String adminId,
    String? adminName,
    required String action,
    required String targetType,
    String? targetId,
    Map<String, dynamic>? details,
    DateTime? timestamp,
  }) = _AuditLogEntry;
}

@freezed
class AdminAuditState with _$AdminAuditState {
  const factory AdminAuditState({
    @Default([]) List<AuditLogEntry> logs,
    @Default(false) bool isLoading,
    String? error,
  }) = _AdminAuditState;
}

@riverpod
class AdminAuditNotifier extends _$AdminAuditNotifier {
  @override
  AdminAuditState build() {
    return const AdminAuditState();
  }

  Future<void> fetchAuditLogs({int limit = 100}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('admin_audit_logs')
              .orderBy('timestamp', descending: true)
              .limit(limit)
              .get();

      final logs =
          snapshot.docs.map((doc) {
            final data = doc.data();
            return AuditLogEntry(
              id: doc.id,
              adminId: data['adminId'] ?? '',
              adminName: data['adminName'],
              action: data['action'] ?? '',
              targetType: data['targetType'] ?? '',
              targetId: data['targetId'],
              details: data['details'] as Map<String, dynamic>?,
              timestamp: (data['timestamp'] as Timestamp?)?.toDate(),
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
      await FirebaseFirestore.instance.collection('admin_audit_logs').add({
        'adminId': adminId,
        'adminName': adminName,
        'action': action,
        'targetType': targetType,
        'targetId': targetId,
        'details': details,
        'timestamp': FieldValue.serverTimestamp(),
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
      await FirebaseFirestore.instance.collection('admin_audit_logs').add({
        'adminId': adminId,
        'adminName': adminName,
        'action': action,
        'targetType': targetType,
        'targetId': targetId,
        'details': details,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Failed to log audit action: $e');
    }
  }
}
