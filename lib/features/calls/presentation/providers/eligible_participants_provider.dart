import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../friends/presentation/providers/friend_provider.dart';
import '../../../messages/presentation/providers/message_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../settings/presentation/providers/blocked_users_provider.dart';

/// Represents a user eligible to be added to a call
class EligibleParticipant {
  final String id;

  /// Vide quand le profil n'a pas pu être résolu — compte supprimé, profil
  /// privé, ou lecture hors ligne.
  ///
  /// Volontairement une chaîne vide plutôt qu'un « Utilisateur » en dur : un
  /// repli écrit ici serait du français figé dans un provider, et surtout il
  /// deviendrait indiscernable d'un vrai nom au moment d'écrire l'invitation.
  /// C'est à l'écran, qui a la locale, de le remplacer par `l10n.userDefault`.
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

  // Add conversation participants (if not already added as friends).
  //
  // Leur nom ne peut PAS venir de la conversation, et c'est ce que faisait le
  // code d'avant : il lisait `conversation.name` quand la conversation était
  // individuelle, et se rabattait sur « Utilisateur » sinon.
  //
  // Les deux branches tombaient sur le repli, toujours :
  //   - une conversation individuelle n'a **pas** de nom.
  //     `createIndividualConversation` insère `type`, `participant_ids`,
  //     `created_by` et `data{unreadCount, requestStatus}` — jamais de `name`
  //     ni d'image. Le reste de l'app l'a toujours su : `conversation_item`
  //     résout le correspondant par `userStreamProvider`, pas par le nom de la
  //     conversation ;
  //   - une conversation de **groupe** n'entrait même pas dans la branche,
  //     alors que la boucle offre chacun de ses participants. Un fil de
  //     21 personnes rendait donc 20 lignes anonymes d'un coup.
  //
  // Résultat mesuré sur SM A515F le 2026-09-14 : la feuille « Inviter un
  // membre » n'affichait que des « Utilisateur » à avatar gris, alors que la
  // recherche du même écran — qui passe par `searchProfiles` — nommait tout le
  // monde correctement.
  final aResoudre = <String>[];
  for (final conversation in conversations) {
    for (final participantId in conversation.participantIds) {
      if (!excludeSet.contains(participantId) &&
          !participantsMap.containsKey(participantId)) {
        participantsMap[participantId] = EligibleParticipant(
          id: participantId,
          displayName: '',
          photoUrl: null,
          isFriend: false,
        );
        aResoudre.add(participantId);
      }
    }
  }

  // Une seule requête pour toute la liste, jamais un `userStreamProvider` par
  // ligne : ce dernier est un flux temps réel dont la `family` n'est pas
  // `autoDispose`, donc ouvert pour le reste de la session — vingt lignes,
  // vingt abonnements, depuis une feuille qu'on referme aussitôt.
  if (aResoudre.isNotEmpty) {
    try {
      final profils = await ref
          .watch(profileRemoteDataSourceProvider)
          .getProfilesByIds(aResoudre);
      for (final profil in profils) {
        final nom = (profil.displayName ?? '').trim();
        participantsMap[profil.id] = EligibleParticipant(
          id: profil.id,
          displayName: nom,
          photoUrl: profil.photoUrl,
          isFriend: false,
        );
      }
    } catch (_) {
      // Hors ligne, ou session pas encore établie. Une liste de gens sans nom
      // reste utilisable — on y reconnaît au moins les amis, nommés par leur
      // copie locale. La faire échouer en entier remplacerait la feuille par
      // « Erreur de chargement », ce qui est strictement pire que le défaut
      // qu'on corrige ici.
    }
  }

  // Sort: friends first, then by name.
  //
  // Les sans-nom ferment la marche au lieu de l'ouvrir : une chaîne vide
  // remonte en tête d'un tri alphabétique, et ce sont justement les lignes sur
  // lesquelles on ne peut rien décider.
  final result = participantsMap.values.toList()
    ..sort((a, b) {
      if (a.isFriend != b.isFriend) return a.isFriend ? -1 : 1;
      final aAnonyme = a.displayName.isEmpty;
      final bAnonyme = b.displayName.isEmpty;
      if (aAnonyme != bAnonyme) return aAnonyme ? 1 : -1;
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
