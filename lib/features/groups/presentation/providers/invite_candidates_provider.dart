import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../calls/presentation/providers/eligible_participants_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../settings/presentation/providers/blocked_users_provider.dart';

/// Personne proposée à l'invitation dans un groupe.
class InviteCandidate {
  const InviteCandidate({
    required this.id,
    required this.displayName,
    this.photoUrl,
    this.subtitle,
    this.isFriend = false,
  });

  final String id;
  final String displayName;
  final String? photoUrl;

  /// Ligne secondaire de la tuile (profession). Absente des suggestions, que
  /// l'on tire d'une liste d'amis et de conversations sans profil complet.
  final String? subtitle;

  final bool isFriend;
}

/// Suggestions d'invitation : amis et personnes avec qui on a déjà discuté,
/// hors membres du groupe.
///
/// Réutilise `eligibleParticipantsProvider` (module Appels) plutôt que de
/// redéfinir la même liste : la question posée est la même — « qui puis-je
/// ajouter ici ? » — et l'exclusion de soi-même comme des comptes bloqués y est
/// déjà faite. Deux copies de cette règle, ce serait deux endroits où un compte
/// bloqué peut réapparaître.
///
/// ⚠️ La clé de famille est une `List`, que Dart compare par identité et non
/// par contenu : une liste reconstruite à chaque `build` créerait un provider
/// par frame. L'appelant doit la figer une fois (cf.
/// `_InviteMembersSheetState._excludeIds`).
final inviteSuggestionsProvider =
    FutureProvider.family<List<InviteCandidate>, List<String>>((
  ref,
  excludeIds,
) async {
  final eligible = await ref.watch(
    eligibleParticipantsProvider(excludeIds).future,
  );
  return [
    for (final p in eligible)
      InviteCandidate(
        id: p.id,
        displayName: p.displayName,
        photoUrl: p.photoUrl,
        isFriend: p.isFriend,
      ),
  ];
});

/// Recherche de personnes à inviter, par nom affiché.
///
/// Ne retire pas les membres déjà présents : l'appelant s'en charge, pour que
/// la clé de famille reste une simple `String` — une clé qui contiendrait la
/// liste des membres se comparerait par identité, avec le même piège que
/// ci-dessus.
///
/// Limite connue : `searchProfiles` filtre sur `is_visible`, donc quelqu'un qui
/// a masqué son profil reste introuvable ici. Il faut alors passer par le lien
/// de partage du groupe.
final inviteSearchProvider =
    FutureProvider.family<List<InviteCandidate>, String>((ref, query) async {
  final trimmed = query.trim();
  // Deux caractères au minimum : `searchProfiles` fait un `ilike '%q%'` borné à
  // 30 lignes triées par nom, donc une lettre seule ne rend à peu près que les
  // mêmes profils en tête d'alphabet — du bruit, pas un résultat.
  if (trimmed.length < 2) return const [];

  final me = await ref.watch(currentUserAsyncProvider.future);
  final blocked = ref.watch(blockedUsersProvider).valueOrNull ?? [];
  final blockedIds = {for (final u in blocked) u.id};

  final profiles =
      await ref.watch(profileRemoteDataSourceProvider).searchProfiles(trimmed);

  return [
    for (final p in profiles)
      if (p.id != me?.id && !blockedIds.contains(p.id))
        InviteCandidate(
          id: p.id,
          displayName: (p.displayName ?? '').trim().isEmpty
              ? 'Utilisateur'
              : p.displayName!.trim(),
          photoUrl: p.photoUrl,
          subtitle: p.profession,
        ),
  ];
});
