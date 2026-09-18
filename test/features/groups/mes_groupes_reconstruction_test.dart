import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/core/errors/failures.dart';
import 'package:diaspo_niger/features/auth/domain/entities/user_entity.dart';
import 'package:diaspo_niger/features/auth/presentation/providers/auth_provider.dart';
import 'package:diaspo_niger/features/groups/domain/entities/group_entity.dart';
import 'package:diaspo_niger/features/groups/domain/repositories/group_repository.dart';
import 'package:diaspo_niger/features/groups/presentation/providers/group_provider.dart';

/// « Mes groupes » reste vide pour toujours si le notifier est RECONSTRUIT
/// avant la fin de sa première lecture.
///
/// `build()` observe `currentUserProvider`, un flux : il s'exécute une
/// première fois alors que l'utilisateur n'est pas encore arrivé (donc sans
/// rien charger), puis une seconde fois quand il arrive. Or `ref.onDispose`
/// se déclenche **à chaque recalcul**, pas seulement à la destruction — et
/// pour un `Notifier`, c'est la MÊME instance qui est réutilisée. Le drapeau
/// `_disposed` passait donc à `true` sur un notifier bien vivant, et n'était
/// jamais remis à `false` : la lecture se terminait, tombait sur
/// `if (_disposed) return;` et n'écrivait rien.
///
/// Conséquence vue sur SM A515F le 2026-09-14 : « Mes groupes · 0 » alors que
/// le compte était membre de deux groupes, et l'onglet Découvrir figé sur ses
/// cartes squelettes — `_buildDiscoverTab` s'arrête sur
/// `myGroupsAsync.isLoading`. Rien dans les journaux : l'état ne devient
/// jamais une erreur, il reste « en cours de chargement » pour toujours.
///
/// Le compte d'à côté ne le voyait pas : quand l'authentification est déjà
/// résolue au moment où l'écran demande la liste, `build()` ne s'exécute
/// qu'une fois et rien ne casse. C'est une course, pas une panne franche.
class _FauxDepot implements GroupRepository {
  _FauxDepot(this.groupes);

  final List<GroupEntity> groupes;
  int lectures = 0;

  @override
  Future<Either<Failure, List<GroupEntity>>> getMyGroups(String userId) async {
    lectures++;
    // Une lecture réseau ne revient pas dans le même tour de boucle.
    await Future<void>.delayed(const Duration(milliseconds: 10));
    return Right(groupes);
  }

  @override
  Stream<void> watchMyMemberships(String userId) => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} hors du banc');
}

void main() {
  final groupes = [
    GroupEntity(
      id: 'g1',
      name: 'Diaspora Niger — Canada',
      description: '',
      creatorId: 'u1',
      createdAt: DateTime(2026, 9, 14),
    ),
  ];

  test(
      'une reconstruction avant la fin de la lecture ne doit pas figer la liste',
      () async {
    final depot = _FauxDepot(groupes);
    final utilisateurs = StreamController<UserEntity?>();
    final container = ProviderContainer(
      overrides: [
        groupRepositoryProvider.overrideWithValue(depot),
        currentUserProvider.overrideWith((ref) => utilisateurs.stream),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await utilisateurs.close();
    });

    // Un écouteur ouvert, comme l'écran des groupes : sans lui le fournisseur
    // ne se recalcule pas quand l'utilisateur arrive.
    container.listen(myGroupsNotifierProvider, (_, __) {}, fireImmediately: true);

    // Premier build : l'utilisateur n'est pas encore arrivé.
    expect(container.read(myGroupsNotifierProvider).isLoading, isTrue);
    expect(depot.lectures, 0, reason: 'rien à charger sans utilisateur');

    // L'utilisateur arrive : le notifier est RECONSTRUIT, et c'est là que
    // `onDispose` du build précédent se déclenchait sur l'instance vivante.
    utilisateurs.add(const UserEntity(id: 'u1', email: 'u1@exemple.test'));
    await Future<void>.delayed(const Duration(milliseconds: 150));

    expect(depot.lectures, greaterThan(0), reason: 'la lecture doit partir');
    final etat = container.read(myGroupsNotifierProvider);
    expect(
      etat.isLoading,
      isFalse,
      reason: 'la liste reste « en chargement » pour toujours : '
          '`_disposed` a été posé par une reconstruction, pas par une mort',
    );
    expect(etat.valueOrNull, hasLength(1));
  });
}
