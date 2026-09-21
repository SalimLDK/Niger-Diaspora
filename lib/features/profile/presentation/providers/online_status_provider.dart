import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/logger_service.dart';
import '../../../../core/services/online_status_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'profile_provider.dart';

part 'online_status_provider.g.dart';

/// Provider for the OnlineStatusService instance
@riverpod
OnlineStatusService onlineStatusService(Ref ref) {
  return OnlineStatusService.instance;
}

/// Provider that streams a specific user's online status
@riverpod
Stream<bool> userOnlineStatus(Ref ref, String userId) {
  final service = ref.watch(onlineStatusServiceProvider);
  return service.getUserOnlineStatus(userId);
}

/// Provider that streams a specific user's last seen timestamp
@riverpod
Stream<DateTime?> userLastSeen(Ref ref, String userId) {
  final service = ref.watch(onlineStatusServiceProvider);
  return service.getUserLastSeen(userId);
}

/// Provider for the current user's online status visibility preference
@riverpod
class CurrentUserOnlineStatusVisibility
    extends _$CurrentUserOnlineStatusVisibility {
  @override
  Future<bool> build() async {
    final currentUser = await ref.watch(currentUserAsyncProvider.future);
    if (currentUser == null) return true;

    // Get the current value from the profile
    final profile = await ref.watch(userStreamProvider(currentUser.id).future);
    return profile?.showOnlineStatus ?? true;
  }

  /// Toggle the current user's online status visibility
  Future<bool> toggle() => setValue(!(state.valueOrNull ?? true));

  /// Écrit la préférence. Rend `false` si le serveur ne l'a pas reçue.
  ///
  /// Écriture optimiste : l'interrupteur suit le doigt, puis on **remet la
  /// valeur d'avant** si l'écriture échoue — le commentaire disait « Revert on
  /// error », le code posait `AsyncValue.error`. C'était faux de deux façons :
  ///
  /// - un `AsyncError` sans valeur fait retomber les lecteurs sur `?? true`,
  ///   donc l'interrupteur revenait sur « visible » quelle que soit la vraie
  ///   valeur — pour un réglage de confidentialité, c'est le mauvais côté ;
  /// - l'écran Profil rend alors un interrupteur **désactivé** (« Erreur de
  ///   chargement »), verrouillé jusqu'à la reconstruction du provider.
  ///
  /// Rend un booléen plutôt que de relancer : l'écran Réglages appelle en
  /// `unawaited(...)`, où une exception deviendrait une erreur asynchrone que
  /// personne n'affiche. C'est à l'écran de dire l'échec (`reportIfFailed`).
  Future<bool> setValue(bool value) async {
    // Dernière valeur connue : c'est elle qu'on remet si le serveur refuse.
    final previous = state.valueOrNull;
    state = AsyncValue.data(value);

    try {
      final service = ref.read(onlineStatusServiceProvider);
      await service.updateOnlineStatusVisibility(value);
      // Le profil en mémoire doit le savoir : c'est lui que relit « Modifier
      // le profil », et il réécrit toutes les colonnes à l'enregistrement.
      final userId = ref.read(currentUserAsyncProvider).valueOrNull?.id;
      if (userId != null) {
        ref
            .read(profileNotifierProvider(userId).notifier)
            .appliquerSansEcrire((p) => p.copyWith(showOnlineStatus: value));
      }
      return true;
    } catch (e, stackTrace) {
      LoggerService.w(
        'CurrentUserOnlineStatusVisibility: écriture refusée',
        e,
        stackTrace,
      );
      if (previous != null) {
        state = AsyncValue.data(previous);
      } else {
        // Rien à remettre (chargement pas terminé) : relire la vérité.
        ref.invalidateSelf();
      }
      return false;
    }
  }
}
