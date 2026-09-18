import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/core/services/online_status_service.dart';
import 'package:diaspo_niger/features/auth/domain/entities/user_entity.dart';
import 'package:diaspo_niger/features/auth/presentation/providers/auth_provider.dart';
import 'package:diaspo_niger/features/profile/domain/entities/profile_entity.dart';
import 'package:diaspo_niger/features/profile/presentation/providers/online_status_provider.dart';
import 'package:diaspo_niger/features/profile/presentation/providers/profile_provider.dart';

/// Visibilité du statut en ligne : que devient l'interrupteur quand le serveur
/// refuse l'écriture ?
///
/// `setValue` posait `AsyncValue.error` sans valeur, sous un commentaire qui
/// disait « Revert on error ». Les deux lecteurs de ce provider en tirent des
/// conséquences opposées à ce qu'on attend d'un retour en arrière :
///
/// - Réglages lit `valueOrNull ?? true` : l'interrupteur retombait sur
///   « visible », quelle que soit la vraie valeur ;
/// - Profil rend, pour un `AsyncError`, un interrupteur **désactivé** affichant
///   « Erreur de chargement » : verrouillé jusqu'à la reconstruction.
///
/// Et le `catch` ne se déclenchait de toute façon jamais en vrai : le service
/// avalait lui-même toute erreur. Ce banc fixe la moitié qu'il peut voir — le
/// provider — avec un service qui, lui, lève.
class _FauxService implements OnlineStatusService {
  bool refuse = false;

  /// Valeurs reçues, dans l'ordre.
  final recus = <bool>[];

  @override
  Future<void> updateOnlineStatusVisibility(bool showStatus) async {
    recus.add(showStatus);
    if (refuse) throw StateError('refusé par le serveur');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const userId = 'u1';

  /// [visibleSurLeServeur] est la valeur que le profil serveur porte AVANT le
  /// geste — celle qu'on doit retrouver quand l'écriture échoue.
  Future<ProviderContainer> conteneur(
    _FauxService service, {
    required bool visibleSurLeServeur,
  }) async {
    final c = ProviderContainer(
      overrides: [
        onlineStatusServiceProvider.overrideWithValue(service),
        currentUserAsyncProvider.overrideWith(
          (ref) => Stream.value(const UserEntity(id: userId)),
        ),
        userStreamProvider(userId).overrideWith(
          (ref) => Stream.value(
            ProfileEntity(id: userId, showOnlineStatus: visibleSurLeServeur),
          ),
        ),
      ],
    );
    addTearDown(c.dispose);
    // Provider autoDispose : sans abonnement retenu il se recrée à chaque
    // lecture et repart en chargement.
    c.listen(
      currentUserOnlineStatusVisibilityProvider,
      (_, __) {},
      fireImmediately: true,
    );
    await c.read(currentUserOnlineStatusVisibilityProvider.future);
    return c;
  }

  test('écriture refusée : l\'interrupteur revient à la vraie valeur, pas à '
      '« visible »', () async {
    // Le cas qui piégeait : l'utilisateur est MASQUÉ sur le serveur. Il tente
    // de se rendre visible, le serveur refuse. L'ancien code posait une erreur
    // sans valeur, que les écrans lisaient `?? true`.
    final service = _FauxService()..refuse = true;
    final c = await conteneur(service, visibleSurLeServeur: false);

    final ok = await c
        .read(currentUserOnlineStatusVisibilityProvider.notifier)
        .setValue(true);

    final etat = c.read(currentUserOnlineStatusVisibilityProvider);
    expect(ok, isFalse, reason: 'l\'échec doit être rapporté à l\'appelant');
    expect(
      etat.hasError,
      isFalse,
      reason:
          'un AsyncError verrouille l\'interrupteur du Profil sur « Erreur '
          'de chargement »',
    );
    expect(
      etat.valueOrNull,
      isFalse,
      reason:
          'la valeur d\'avant devait revenir. Un AsyncError sans valeur fait '
          'lire `?? true` aux écrans : « visible », l\'inverse du serveur.',
    );
  });

  test('écriture refusée depuis « visible » : reste visible, sans erreur',
      () async {
    final service = _FauxService()..refuse = true;
    final c = await conteneur(service, visibleSurLeServeur: true);

    final ok = await c
        .read(currentUserOnlineStatusVisibilityProvider.notifier)
        .setValue(false);

    final etat = c.read(currentUserOnlineStatusVisibilityProvider);
    expect(ok, isFalse);
    expect(etat.hasError, isFalse);
    expect(etat.valueOrNull, isTrue);
  });

  test('écriture acceptée : la nouvelle valeur est retenue', () async {
    final service = _FauxService();
    final c = await conteneur(service, visibleSurLeServeur: true);

    final ok = await c
        .read(currentUserOnlineStatusVisibilityProvider.notifier)
        .setValue(false);

    expect(ok, isTrue);
    expect(service.recus, [false]);
    expect(c.read(currentUserOnlineStatusVisibilityProvider).valueOrNull, false);
  });

  test('toggle passe par le même chemin, échec compris', () async {
    final service = _FauxService()..refuse = true;
    final c = await conteneur(service, visibleSurLeServeur: false);

    final ok = await c
        .read(currentUserOnlineStatusVisibilityProvider.notifier)
        .toggle();

    expect(service.recus, [true], reason: 'toggle devait inverser « masqué »');
    expect(ok, isFalse);
    expect(
      c.read(currentUserOnlineStatusVisibilityProvider).valueOrNull,
      isFalse,
      reason: 'toggle avait sa propre copie du même défaut',
    );
  });
}
