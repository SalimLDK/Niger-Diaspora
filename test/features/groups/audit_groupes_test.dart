import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:diaspo_niger/core/errors/exceptions.dart';
import 'package:diaspo_niger/core/errors/failures.dart';
import 'package:diaspo_niger/core/network/network_info.dart';
import 'package:diaspo_niger/core/services/cache_service.dart';
import 'package:diaspo_niger/features/groups/data/datasources/group_remote_datasource.dart';
import 'package:diaspo_niger/features/groups/data/datasources/group_request_datasource.dart';
import 'package:diaspo_niger/features/groups/data/models/group_model.dart';
import 'package:diaspo_niger/features/groups/data/models/group_request_model.dart';
import 'package:diaspo_niger/features/groups/data/repositories/group_repository_impl.dart';
import 'package:diaspo_niger/features/messages/domain/repositories/message_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Audit du module groupes (2026-10-14), côté application.
///
/// 1. `Stream.handleError` jette la valeur que rend son rappel : les
///    `Left(...)` qu'y posait le dépôt n'étaient jamais émis, l'erreur
///    disparaissait, et l'écran des demandes restait en chargement ou
///    affichait « Aucune demande en attente ».
/// 2. L'écran de modification construisait le groupe de zéro : permissions et
///    modérateurs retombaient sur leurs valeurs par défaut, et `updateGroup`
///    les écrivait à chaque enregistrement.
/// 3. `createGroup` posait l'uuid Supabase comme membre et admin, là où tout
///    le reste emploie l'identifiant Firebase (`creator_id`).
void main() {
  group('les erreurs des flux remontent', () {
    late GroupRepositoryImpl depot;

    setUp(() {
      depot = GroupRepositoryImpl(
        remoteDataSource: _Groupes(),
        requestDataSource: _Demandes(),
        networkInfo: _Reseau(),
        messageRepository: _Messages(),
        cacheService: _Cache(),
      );
    });

    test('demandes en attente : un Left, pas le silence', () async {
      final emis = await depot.getPendingRequests('g1').toList();
      expect(emis, hasLength(1));
      expect(emis.single.isLeft(), isTrue);
      expect(
        emis.single.fold((f) => f.message, (_) => ''),
        'lecture refusée',
      );
    });

    test('mes demandes : un Left', () async {
      final emis = await depot.getMyGroupRequests('u1').toList();
      expect(emis.single.isLeft(), isTrue);
    });

    test('flux du groupe : un Left', () async {
      final emis = await depot.getGroupStream('g1').toList();
      expect(emis.single, isA<Left<Failure, dynamic>>());
    });
  });

  group('source', () {
    String lire(String chemin) => File(chemin).readAsStringSync();

    test('l\'écran de modification reprend ce qu\'il n\'édite pas', () {
      final source = lire(
        'lib/features/groups/presentation/screens/edit_group_screen.dart',
      );
      for (final champ in [
        'permissions: widget.group.permissions',
        'moderatorIds: widget.group.moderatorIds',
        'memberJoinedAt: widget.group.memberJoinedAt',
        'isOfficial: widget.group.isOfficial',
      ]) {
        expect(source, contains(champ));
      }
    });

    test('createGroup prend le créateur de la ligne, pas l\'uuid Supabase', () {
      final source = lire(
        'lib/features/groups/data/datasources/group_supabase_datasource.dart',
      );
      final debut = source.indexOf('Future<GroupModel> createGroup(');
      final corps = source.substring(debut, source.indexOf('\n  }\n', debut));
      expect(corps, contains("row['creator_id']"));
      expect(corps, isNot(contains('auth.currentUser?.id')));
    });

    test('les flux de demandes et d\'invitations attendent la session', () {
      final source = lire(
        'lib/features/groups/data/datasources/'
        'group_request_supabase_datasource.dart',
      );
      for (final signature in [
        'getPendingRequests(String groupId) async* {',
        'getMyGroupRequests(String userId) async* {',
        'getReceivedInvites(String userId) async* {',
        'getSentInvites(String groupId) async* {',
      ]) {
        final debut = source.indexOf(signature);
        expect(debut, isNot(-1), reason: signature);
        final corps = source.substring(debut, source.indexOf('\n  }\n', debut));
        expect(
          corps.indexOf('ensureAuthenticated()'),
          lessThan(corps.indexOf('yield*')),
          reason: signature,
        );
      }
    });

    test('accepter une invitation : l\'adhésion avant le statut', () {
      final source = lire(
        'lib/features/groups/data/datasources/'
        'group_request_supabase_datasource.dart',
      );
      final debut = source.indexOf('Future<void> acceptGroupInvite(');
      final corps = source.substring(debut, source.indexOf('\n  }\n', debut));
      expect(
        corps.indexOf("from('group_members')"),
        lessThan(corps.indexOf("'status': 'accepted'")),
      );
    });

    test('la liste des groupes signale l\'échec d\'une adhésion', () {
      final source = lire(
        'lib/features/groups/presentation/screens/groups_screen.dart',
      );
      final debut = source.indexOf('Future<void> _joinGroup(');
      final corps = source.substring(debut, source.indexOf('\n  }\n', debut));
      expect(corps, contains('messageErreurUsager('));
    });

    test('updateGroup rend le groupe avec son appartenance', () {
      final source = lire(
        'lib/features/groups/data/datasources/group_supabase_datasource.dart',
      );
      final debut = source.indexOf('Future<GroupModel> updateGroup(');
      final corps = source.substring(debut, source.indexOf('\n  }\n', debut));
      expect(corps, contains('_membershipFor([group.id])'));
    });
  });
}

class _Demandes implements GroupRequestDataSource {
  @override
  Stream<List<GroupRequestModel>> getPendingRequests(String groupId) =>
      Stream.error(ServerException('lecture refusée'));

  @override
  Stream<List<GroupRequestModel>> getMyGroupRequests(String userId) =>
      Stream.error(ServerException('lecture refusée'));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Groupes implements GroupRemoteDataSource {
  @override
  Stream<GroupModel?> getGroupStream(String groupId) =>
      Stream.error(StateError('réseau'));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Reseau implements NetworkInfo {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Messages implements MessageRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Cache implements CacheService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
