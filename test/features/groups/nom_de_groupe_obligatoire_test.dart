import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/core/errors/failures.dart';
import 'package:diaspo_niger/core/network/network_info.dart';
import 'package:diaspo_niger/features/groups/data/datasources/group_remote_datasource.dart';
import 'package:diaspo_niger/features/groups/data/datasources/group_request_datasource.dart';
import 'package:diaspo_niger/features/messages/domain/repositories/message_repository.dart';
import 'package:diaspo_niger/features/groups/data/repositories/group_repository_impl.dart';
import 'package:diaspo_niger/features/groups/domain/entities/group_entity.dart';

/// Deux groupes au nom vide ont existé en production (2026-09-17 et
/// 2026-10-01). Les écrans valident le champ, mais la règle est tenue au
/// point de passage unique : le dépôt refuse avant tout accès réseau ou base.
/// Les doublures lèvent sur tout appel, ce qui prouve que rien n'est touché.
Never _interdit(Invocation i) =>
    throw StateError('accès inattendu : ${i.memberName}');

class _Distant implements GroupRemoteDataSource {
  @override
  dynamic noSuchMethod(Invocation i) => _interdit(i);
}

class _Demandes implements GroupRequestDataSource {
  @override
  dynamic noSuchMethod(Invocation i) => _interdit(i);
}

class _Reseau implements NetworkInfo {
  @override
  dynamic noSuchMethod(Invocation i) => _interdit(i);
}

class _Messages implements MessageRepository {
  @override
  dynamic noSuchMethod(Invocation i) => _interdit(i);
}

GroupEntity _groupe(String nom) => GroupEntity(
      id: 'g1',
      name: nom,
      description: 'Une description assez longue',
      creatorId: 'u1',
    );

void main() {
  final depot = GroupRepositoryImpl(
    remoteDataSource: _Distant(),
    requestDataSource: _Demandes(),
    networkInfo: _Reseau(),
    messageRepository: _Messages(),
  );

  for (final nom in ['', '   ', 'ab', '  a ']) {
    test('création refusée pour le nom « $nom »', () async {
      final r = await depot.createGroup(_groupe(nom));
      expect(r.fold((f) => f, (_) => null), isA<ValidationFailure>());
    });
    test('renommage refusé pour le nom « $nom »', () async {
      final r = await depot.updateGroup(_groupe(nom));
      expect(r.fold((f) => f, (_) => null), isA<ValidationFailure>());
    });
  }
}
