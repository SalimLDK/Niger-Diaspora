import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../events/data/models/event_model.dart';
import '../../../groups/data/models/group_model.dart';
import '../../../events/domain/entities/event_entity.dart';
import '../../../groups/domain/entities/group_entity.dart';
import '../../../auth/data/models/user_model.dart';

part 'admin_provider.freezed.dart';
part 'admin_provider.g.dart';

@freezed
class AdminDashboardState with _$AdminDashboardState {
  const factory AdminDashboardState({
    @Default(0) int totalUsers,
    @Default(0) int activeSessions,
    @Default(0) int totalEvents,
    @Default(0) int totalGroups,
    @Default([]) List<UserEntity> recentUsers,
    @Default([]) List<dynamic> recentContent, // Events and Groups
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

      // This is a naive implementation. For production, use aggregation queries or specialized counters.

      // Users count
      final usersSnapshot = await firestore.collection('users').count().get();
      final totalUsers = usersSnapshot.count ?? 0;

      // Events count
      final eventsSnapshot = await firestore.collection('events').count().get();
      final totalEvents = eventsSnapshot.count ?? 0;

      // Groups count
      final groupsSnapshot = await firestore.collection('groups').count().get();
      final totalGroups = groupsSnapshot.count ?? 0;

      // Helper to get active sessions - this is tricky without real-time tracking,
      // but we can query users where session_id matches current valid sessions if we had a separate sessions collection.
      // For now, we'll just mock it or query users who logged in recently (last 24h)
      // We can check 'lastLoginAt'
      final yesterday = DateTime.now().subtract(const Duration(hours: 24));
      final activeUsersSnapshot =
          await firestore
              .collection('users')
              .where(
                'lastLoginAt',
                isGreaterThan: Timestamp.fromDate(yesterday),
              )
              .count()
              .get();
      final activeSessions = activeUsersSnapshot.count ?? 0;

      state = state.copyWith(
        totalUsers: totalUsers,
        totalEvents: totalEvents,
        totalGroups: totalGroups,
        activeSessions: activeSessions,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> fetchRecentUsers() async {
    // Only fetching last 20 users for now
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

  Future<bool> forceLogoutUser(String userId) async {
    try {
      // To force logout, we scramble the session_id in Firestore
      // This will cause the user's local session_id (which is unchanged) to mismatch the remove one
      // triggering the SessionService listener to logout the app.

      final newSessionId =
          "force_logout_${DateTime.now().millisecondsSinceEpoch}";
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'session_id': newSessionId,
      });

      return true;
    } catch (e) {
      state = state.copyWith(error: "Failed to logout user: $e");
      return false;
    }
  }

  Future<void> fetchRecentContent() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // Fetch recent events
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

      // Fetch recent groups
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

      // Combine and sort by date descending
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
