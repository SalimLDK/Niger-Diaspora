import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../friends/presentation/providers/friend_provider.dart';
import '../../../messages/presentation/providers/message_provider.dart';
import '../../../settings/presentation/providers/blocked_users_provider.dart';

/// Represents a user eligible to be added to a call
class EligibleParticipant {
  final String id;
  final String displayName;
  final String? photoUrl;
  final bool isFriend;

  const EligibleParticipant({
    required this.id,
    required this.displayName,
    this.photoUrl,
    required this.isFriend,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EligibleParticipant && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Provider that returns all users eligible to be added to a call.
/// These are users who are either:
/// - In the current user's friend list
/// - Have exchanged messages with the current user (conversation participants)
///
/// Filtered to exclude:
/// - The current user
/// - Users passed in the [excludeIds] parameter (e.g., already in the call)
/// - Blocked users
final eligibleParticipantsProvider = FutureProvider.family<
    List<EligibleParticipant>,
    List<String>>((ref, excludeIds) async {
  final currentUser = await ref.watch(currentUserAsyncProvider.future);
  if (currentUser == null) return [];

  final currentUserId = currentUser.id;

  // Get friends
  final friendsAsync = ref.watch(friendsProvider);
  final friends = friendsAsync.valueOrNull ?? [];

  // Get conversations to extract participant IDs
  final conversationsAsync = ref.watch(conversationsProvider);
  final conversations = conversationsAsync.valueOrNull ?? [];

  // Get blocked users
  final blockedUsersAsync = ref.watch(blockedUsersProvider);
  final blockedUsers = blockedUsersAsync.valueOrNull ?? [];
  final blockedUserIds = blockedUsers.map((u) => u.id).toSet();

  // Build exclusion set
  final excludeSet = <String>{
    currentUserId,
    ...excludeIds,
    ...blockedUserIds,
  };

  // Build map of eligible participants
  final participantsMap = <String, EligibleParticipant>{};

  // Add friends first (they have priority as they include full info)
  for (final friend in friends) {
    if (!excludeSet.contains(friend.id)) {
      participantsMap[friend.id] = EligibleParticipant(
        id: friend.id,
        displayName: friend.displayName,
        photoUrl: friend.photoUrl,
        isFriend: true,
      );
    }
  }

  // Add conversation participants (if not already added as friends)
  for (final conversation in conversations) {
    for (final participantId in conversation.participantIds) {
      if (!excludeSet.contains(participantId) &&
          !participantsMap.containsKey(participantId)) {
        // For conversation participants who are not friends, we need to fetch
        // their info from profile. For now, use conversation name if individual.
        String displayName = 'Utilisateur';
        String? photoUrl;

        if (conversation.isIndividual &&
            conversation.participantIds.length == 2) {
          // Use conversation name/image for the other participant
          displayName = conversation.name ?? 'Utilisateur';
          photoUrl = conversation.imageUrl;
        }

        participantsMap[participantId] = EligibleParticipant(
          id: participantId,
          displayName: displayName,
          photoUrl: photoUrl,
          isFriend: false,
        );
      }
    }
  }

  // Sort: friends first, then by name
  final result = participantsMap.values.toList()
    ..sort((a, b) {
      if (a.isFriend && !b.isFriend) return -1;
      if (!a.isFriend && b.isFriend) return 1;
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });

  return result;
});

/// Provider that filters eligible participants by search query
final filteredEligibleParticipantsProvider = Provider.family<
    List<EligibleParticipant>,
    ({List<String> excludeIds, String searchQuery})>((ref, params) {
  final participantsAsync =
      ref.watch(eligibleParticipantsProvider(params.excludeIds));
  final participants = participantsAsync.valueOrNull ?? [];

  if (params.searchQuery.isEmpty) {
    return participants;
  }

  final query = params.searchQuery.toLowerCase();
  return participants
      .where((p) => p.displayName.toLowerCase().contains(query))
      .toList();
});
