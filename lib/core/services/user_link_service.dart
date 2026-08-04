import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/friends/data/datasources/friend_remote_datasource.dart';
import '../../features/friends/presentation/providers/friend_provider.dart';
import '../../features/groups/domain/entities/group_entity.dart';

/// Type of link between two users
enum UserLinkType {
  /// No relationship exists
  none,

  /// Users are friends
  friend,

  /// Users have exchanged messages (accepted conversation)
  messageExchange,
}

/// Service to check relationship links between users
class UserLinkService {
  final FriendRemoteDataSource _friendDataSource;

  UserLinkService({required FriendRemoteDataSource friendDataSource})
      : _friendDataSource = friendDataSource;

  SupabaseClient get _supabase => Supabase.instance.client;

  /// Check if a link exists between two users.
  Future<UserLinkType> checkLink(String userId1, String userId2) async {
    final areFriends = await _friendDataSource.areFriends(userId1, userId2);
    if (areFriends) return UserLinkType.friend;

    final hasMessageExchange = await _hasAcceptedConversation(userId1, userId2);
    if (hasMessageExchange) return UserLinkType.messageExchange;

    return UserLinkType.none;
  }

  /// Check if two users have an accepted conversation between them.
  Future<bool> _hasAcceptedConversation(
      String userId1, String userId2,) async {
    try {
      final rows = await _supabase
          .from('conversations')
          .select('participant_ids, data')
          .eq('type', 'individual')
          .contains('participant_ids', [userId1],);

      for (final row in rows) {
        final participants =
            List<String>.from(row['participant_ids'] as List? ?? []);
        if (!participants.contains(userId2)) continue;

        final data = row['data'] as Map<String, dynamic>? ?? {};
        final requestStatus = data['request_status'] as String? ?? 'none';
        if (requestStatus == 'none' || requestStatus == 'accepted') {
          return true;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Get common groups between two users.
  Future<List<GroupEntity>> getCommonGroups(
      String userId1, String userId2,) async {
    try {
      final rows = await _supabase
          .from('groups')
          .select('id, name, description, image_url, creator_id, admin_ids, member_ids, country, origin_region, category, is_private, created_at')
          .contains('member_ids', [userId1],);

      return rows
          .where((row) {
            final memberIds =
                List<String>.from(row['member_ids'] as List? ?? []);
            return memberIds.contains(userId2);
          })
          .map(_parseGroupEntity)
          .toList();
    } catch (_) {
      return [];
    }
  }

  GroupEntity _parseGroupEntity(Map<String, dynamic> row) {
    return GroupEntity(
      id: row['id'] as String,
      name: row['name'] as String? ?? '',
      description: row['description'] as String? ?? '',
      imageUrl: row['image_url'] as String?,
      creatorId: row['creator_id'] as String? ?? '',
      adminIds: List<String>.from(row['admin_ids'] as List? ?? []),
      memberIds: List<String>.from(row['member_ids'] as List? ?? []),
      country: row['country'] as String?,
      originRegion: row['origin_region'] as String?,
      category: _parseGroupCategory(row['category'] as String?),
      isPrivate: row['is_private'] as bool? ?? false,
      memberJoinedAt: const {},
      createdAt: row['created_at'] != null
          ? DateTime.parse(row['created_at'] as String).toLocal()
          : DateTime.now(),
    );
  }

  GroupCategory _parseGroupCategory(String? value) {
    if (value == null) return GroupCategory.other;
    return GroupCategory.values.firstWhere(
      (e) => e.name == value,
      orElse: () => GroupCategory.other,
    );
  }
}

/// Provider for UserLinkService
final userLinkServiceProvider = Provider<UserLinkService>((ref) {
  return UserLinkService(
    friendDataSource: ref.watch(friendRemoteDataSourceProvider),
  );
});

/// Check link status between current user and another user
final userLinkProvider = FutureProvider.family<UserLinkType,
    ({String currentUserId, String otherUserId})>(
  (ref, params) async {
    final service = ref.watch(userLinkServiceProvider);
    return service.checkLink(params.currentUserId, params.otherUserId);
  },
);

/// Get common groups between current user and another user
final commonGroupsProvider = FutureProvider.family<List<GroupEntity>,
    ({String currentUserId, String otherUserId})>(
  (ref, params) async {
    final service = ref.watch(userLinkServiceProvider);
    return service.getCommonGroups(params.currentUserId, params.otherUserId);
  },
);
