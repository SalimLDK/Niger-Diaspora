import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../feed/domain/entities/post_entity.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import 'group_provider.dart';
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
/// **La clé de la `family` est l'identifiant du groupe, surtout pas la liste
/// des membres.** Une `family` Riverpod compare ses clés avec `==`, et deux
/// `List<String>` de même contenu ne sont jamais égales en Dart. La version
/// précédente était donc appelée avec une NOUVELLE liste à chaque `build` de
/// l'écran, ce qui créait une NOUVELLE instance de provider, qui repartait en
/// chargement : `.valueOrNull` rendait `null` indéfiniment. Vérifié sur
/// appareil le 2026-08-23 — taper `@` dans un groupe n'ouvrait aucune liste de
/// suggestions, et n'en avait probablement jamais ouvert, quelle que soit la
/// forme du pseudo.
///
/// C'est aussi pourquoi ce n'est plus un `FutureProvider` : tout ce qu'il fait
/// est de lire d'autres providers, il n'y a rien à attendre. Un `Future` qui
/// n'aboutit pas ressemble à une liste vide, et une liste vide ressemble à
/// « ce groupe n'a personne à mentionner ».
final groupMentionCandidatesProvider =
    Provider.autoDispose.family<List<MentionCandidate>, String>((ref, groupId) {
  final group = ref.watch(groupStreamProvider(groupId)).valueOrNull;
  if (group == null) return const [];

  final currentUserId = ref.watch(currentUserProvider).valueOrNull?.id;
  final candidates = <MentionCandidate>[];

  for (final id in group.memberIds) {
    if (id == currentUserId) continue;
    final profile = ref.watch(profileNotifierProvider(id)).valueOrNull;
    final name = profile?.displayName?.trim();
    candidates.add(
      MentionCandidate(
        id: id,
        // Le profil n'est pas encore chargé au premier build : l'identifiant
        // tient lieu de nom, et la liste se recompose quand il arrive.
        displayName: (name != null && name.isNotEmpty) ? name : id,
        handle: profile?.handle,
      ),
    );
  }
  return candidates;
});
