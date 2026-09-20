import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/effacement_local_differe.dart';
import '../../domain/entities/account_deletion_status.dart';
import 'auth_provider.dart';

/// Suppression de compte en cours pour la personne connectée, ou `null`.
///
/// Lue dès que la session s'établit : `request_account_deletion` désactive le
/// compte, mais ne fait rien de plus sur les autres appareils que révoquer leur
/// session Supabase. Une personne qui se reconnecte pendant le délai de grâce
/// doit tomber sur l'écran d'annulation, pas dans l'application.
///
/// ÉCHEC = `AsyncError`, et le routeur le traite comme « pas de suppression » :
/// mieux vaut laisser entrer une personne qu'on n'a pas pu vérifier que
/// l'enfermer hors de son compte sur une lecture ratée. Le compte, lui, reste
/// masqué côté serveur quoi que le client en pense.
final accountDeletionStatusProvider =
    AsyncNotifierProvider<AccountDeletionStatusNotifier, AccountDeletionStatus?>(
      AccountDeletionStatusNotifier.new,
    );

class AccountDeletionStatusNotifier
    extends AsyncNotifier<AccountDeletionStatus?> {
  static const _tag = 'AccountDeletionStatus';

  @override
  Future<AccountDeletionStatus?> build() async {
    // Une session neuve, une lecture neuve : `select` évite de relire à chaque
    // changement d'état d'authentification qui ne change pas de personne.
    final uid = ref.watch(
      authNotifierProvider.select(
        (s) => s.maybeWhen(authenticated: (u) => u.id, orElse: () => null),
      ),
    );
    if (uid == null) return null;

    final result = await ref.read(authRepositoryProvider).accountDeletionStatus();
    return result.fold((failure) {
      dev.log('Lecture impossible: ${failure.message}', name: _tag);
      // Une exception, pas `null` : « je n'ai pas pu lire » n'est pas « il n'y
      // a rien ».
      throw Exception(failure.message);
    }, (status) {
      // Lecture RÉUSSIE et aucune suppression en cours : si ce téléphone avait
      // noté un effacement différé pour ce compte, il a été annulé ailleurs. On
      // n'effacera rien. (Jamais sur une lecture ratée : ce serait conclure à
      // l'absence sans avoir lu.)
      if (status == null) {
        unawaited(ref.read(effacementLocalDiffereProvider).annuler(uid));
      }
      return status;
    });
  }

  /// Annule la suppression. `true` si elle est annulée ; sinon l'état reste
  /// tel quel et l'écran garde ses boutons.
  Future<bool> cancel() async {
    final uid = ref
        .read(authNotifierProvider)
        .maybeWhen(authenticated: (u) => u.id, orElse: () => null);
    final result = await ref.read(authRepositoryProvider).cancelAccountDeletion();
    final annulee = result.fold((failure) {
      dev.log('Annulation refusée: ${failure.message}', name: _tag);
      return false;
    }, (_) => true);
    if (!annulee) return false;

    state = const AsyncData(null);
    // Le compte reste vivant : le matériel local de ce téléphone ne sera jamais
    // effacé pour lui.
    if (uid != null) {
      await ref.read(effacementLocalDiffereProvider).annuler(uid);
    }
    return true;
  }
}
