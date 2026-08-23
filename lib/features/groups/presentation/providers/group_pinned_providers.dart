import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../feed/domain/entities/post_entity.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../data/datasources/group_supabase_datasource.dart';
import '../../domain/entities/group_pinned_item_entity.dart';

final _groupSupabaseDataSourceProvider = Provider<GroupSupabaseDataSource>(
  (ref) => GroupSupabaseDataSource(),
);

final conversationPinnedItemsProvider =
    StreamProvider.autoDispose.family<List<GroupPinnedItemEntity>, String>(
  (ref, conversationId) {
    final ds = ref.watch(_groupSupabaseDataSourceProvider);
    return ds.getPinnedItemsStream(conversationId: conversationId).map(
          (models) => models.map((m) => m.toEntity()).toList(),
        );
  },
);

class GroupPinActionsNotifier extends AutoDisposeNotifier<void> {
  @override
  void build() {}

  Future<bool> pinItem({
    // `groupId` désactivé : voir GroupSupabaseDataSource.pinItem.
    // String? groupId,
    String? conversationId,
    required GroupPinnedItemType itemType,
    required String itemId,
    required String pinnedBy,
  }) async {
    try {
      await ref.read(_groupSupabaseDataSourceProvider).pinItem(
            // groupId: groupId,
            conversationId: conversationId,
            itemType: itemType.value,
            itemId: itemId,
            pinnedBy: pinnedBy,
          );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> unpinItem(String pinnedItemId) async {
    try {
      await ref.read(_groupSupabaseDataSourceProvider).unpinItem(pinnedItemId);
      return true;
    } catch (_) {
      return false;
    }
  }
}

final groupPinActionsNotifierProvider =
    NotifierProvider.autoDispose<GroupPinActionsNotifier, void>(
  GroupPinActionsNotifier.new,
);

/// Membres d'un groupe, prêts à être proposés derrière un `@`.
///
/// Remplace `groupMemberNamesProvider`, qui ne rendait que le nom affiché.
/// La poignée publique est nécessaire ici : c'est elle qui sert de pseudo de
/// mention quand la personne en a choisi une (cf. `mentionTokenFor`).
final groupMentionCandidatesProvider =
    FutureProvider.autoDispose.family<List<MentionCandidate>, List<String>>(
  (ref, memberIds) async {
    final candidates = <MentionCandidate>[];
    for (final id in memberIds) {
      final profile = ref.watch(profileNotifierProvider(id)).valueOrNull;
      final name = profile?.displayName?.trim();
      candidates.add(
        MentionCandidate(
          id: id,
          // Le profil n'est pas encore chargé au premier build : l'identifiant
          // tient lieu de nom, comme avant, et la liste se recompose quand il
          // arrive.
          displayName: (name != null && name.isNotEmpty) ? name : id,
          handle: profile?.handle,
        ),
      );
    }
    return candidates;
  },
);
