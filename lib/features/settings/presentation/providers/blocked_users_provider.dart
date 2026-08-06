import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/blocked_by_supabase_datasource.dart';
import '../../data/datasources/blocked_users_datasource.dart';
import '../../data/repositories/blocked_users_repository_impl.dart';
import '../../domain/entities/blocked_user_entity.dart';
import '../../domain/repositories/blocked_users_repository.dart';

part 'blocked_users_provider.g.dart';

@riverpod
BlockedUsersDataSource blockedUsersDataSource(Ref ref) {
  return BlockedUsersDataSourceImpl();
}

@riverpod
BlockedUsersRepository blockedUsersRepository(Ref ref) {
  return BlockedUsersRepositoryImpl(
    dataSource: ref.watch(blockedUsersDataSourceProvider),
  );
}

@riverpod
Stream<List<BlockedUserEntity>> blockedUsers(Ref ref) {
  final currentUser = ref.watch(currentUserProvider).valueOrNull;
  if (currentUser == null) {
    return Stream.value([]);
  }

  final repository = ref.watch(blockedUsersRepositoryProvider);
  return repository
      .getBlockedUsers(currentUser.id)
      .map((either) => either.fold((_) => [], (users) => users));
}

/// Les identifiants qui **m'ont bloqué**.
///
/// Le pendant de [blockedUsers], qui donne le sens direct. Celui-ci n'existait
/// pas : les dix endroits qui posent la question lisaient
/// `profil.blockedByUserIds`, un champ que `_mapProfile` code en dur à vide
/// depuis que les profils viennent de Supabase. La réponse était donc toujours
/// non, et une personne qui vous a bloqué continuait d'apparaître sur la carte,
/// en ligne, et de recevoir vos messages.
///
/// Rend un ensemble vide tant que rien n'est chargé — c'est le défaut sûr côté
/// affichage : on ne masque personne à tort pendant le chargement.
@riverpod
Stream<Set<String>> usersWhoBlockedMe(Ref ref) {
  final currentUser = ref.watch(currentUserProvider).valueOrNull;
  if (currentUser == null) {
    return Stream.value(<String>{});
  }
  return BlockedBySupabaseDataSource()
      .watchBlockedBy(currentUser.id)
      // Un flux en erreur (RLS, réseau) ne doit pas casser les écrans qui
      // l'écoutent : on retombe sur « personne ne m'a bloqué », l'état d'avant
      // ce correctif.
      .handleError((Object _) {})
      .map((ids) => ids);
}

@riverpod
class BlockUserNotifier extends _$BlockUserNotifier {
  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }

  Future<bool> blockUser({
    required String targetUserId,
    required String targetDisplayName,
    String? targetPhotoUrl,
  }) async {
    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser == null) return false;

    state = const AsyncValue.loading();

    final repository = ref.read(blockedUsersRepositoryProvider);
    final result = await repository.blockUser(
      currentUser.id,
      targetUserId,
      targetDisplayName,
      targetPhotoUrl,
    );

    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        return true;
      },
    );
  }

  Future<bool> unblockUser(String targetUserId) async {
    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser == null) return false;

    state = const AsyncValue.loading();

    final repository = ref.read(blockedUsersRepositoryProvider);
    final result = await repository.unblockUser(currentUser.id, targetUserId);

    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        return true;
      },
    );
  }
}
