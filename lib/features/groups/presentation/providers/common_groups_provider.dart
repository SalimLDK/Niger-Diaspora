import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/group_entity.dart';
import 'group_provider.dart';

/// Groupes en commun (§10c) entre l'utilisateur courant et [otherUserId].
///
/// Dérivé de [myGroupsNotifierProvider] (déjà chargé) : les groupes du user
/// courant portent leurs `memberIds`, il suffit donc de garder ceux dont
/// l'autre utilisateur est aussi membre. Aucune requête ni RPC supplémentaire.
final commonGroupsProvider =
    Provider.autoDispose.family<AsyncValue<List<GroupEntity>>, String>(
  (ref, otherUserId) {
    final myGroups = ref.watch(myGroupsNotifierProvider);
    return myGroups.whenData(
      (groups) =>
          groups.where((g) => g.memberIds.contains(otherUserId)).toList(),
    );
  },
);
