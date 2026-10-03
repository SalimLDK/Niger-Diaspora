import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:diaspo_niger/core/errors/failures.dart';
import 'package:diaspo_niger/features/auth/domain/entities/user_entity.dart';
import 'package:diaspo_niger/features/auth/presentation/providers/auth_provider.dart';
import 'package:diaspo_niger/features/messages/domain/repositories/message_repository.dart';
import 'package:diaspo_niger/features/messages/presentation/providers/message_pagination_state.dart';
import 'package:diaspo_niger/features/messages/presentation/providers/message_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// « Supprimer pour moi » sur une sélection de messages.
///
/// La sélection passait par `MessageDeletionService.deleteMultipleForMe`, qui
/// écrivait `deletedFor` dans Firebase RTDB — que plus rien ne lit depuis la
/// migration vers Supabase. L'écran masquait les messages, puis ils
/// revenaient au rechargement. Elle suit désormais le chemin du message seul.
void main() {
  ProviderContainer conteneur(_Depot depot, _Ecran ecran) {
    final c = ProviderContainer(overrides: [
      currentUserAsyncProvider
          .overrideWith((ref) => Stream.value(const UserEntity(id: 'u1'))),
      messageRepositoryProvider.overrideWithValue(depot),
      paginatedMessagesProvider.overrideWith((ref, id) => ecran),
    ]);
    addTearDown(c.dispose);
    c.listen(paginatedMessagesProvider('c1'), (_, __) {});
    return c;
  }

  test('chaque message passe par le dépôt, et se masque à l\'écran', () async {
    final depot = _Depot();
    final ecran = _Ecran();
    final c = conteneur(depot, ecran);

    final n = await c.read(deleteMessageProvider.notifier).deleteManyForMe(
          conversationId: 'c1',
          messageIds: ['m1', 'm2', 'm3'],
        );

    expect(n, 3);
    expect(depot.supprimes, ['c1/m1/u1', 'c1/m2/u1', 'c1/m3/u1']);
    expect(ecran.masques, ['m1', 'm2', 'm3']);
    expect(c.read(deleteMessageProvider).hasError, isFalse);
  });

  test('au premier échec : on s\'arrête, l\'erreur est dite, l\'écran relu',
      () async {
    final depot = _Depot(echoueSur: 'm2');
    final ecran = _Ecran();
    final c = conteneur(depot, ecran);

    final n = await c.read(deleteMessageProvider.notifier).deleteManyForMe(
          conversationId: 'c1',
          messageIds: ['m1', 'm2', 'm3'],
        );

    expect(n, 1);
    expect(depot.supprimes, ['c1/m1/u1']);
    expect(c.read(deleteMessageProvider).hasError, isTrue);
  });

  test('l\'écran n\'utilise plus le service RTDB', () {
    final ecranSource = File(
      'lib/features/messages/presentation/screens/conversation_screen.dart',
    ).readAsStringSync();
    expect(ecranSource, isNot(contains('deleteMultipleForMe')));
    expect(ecranSource, contains('deleteManyForMe('));
  });
}

class _Depot implements MessageRepository {
  _Depot({this.echoueSur});

  final String? echoueSur;
  final supprimes = <String>[];

  @override
  Future<Either<Failure, void>> deleteMessageForMe({
    required String conversationId,
    required String messageId,
    required String userId,
  }) async {
    if (messageId == echoueSur) return const Left(ServerFailure('refusé'));
    supprimes.add('$conversationId/$messageId/$userId');
    return const Right(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Ecran extends StateNotifier<MessagePaginationState>
    implements PaginatedMessagesNotifier {
  _Ecran() : super(const MessagePaginationState());

  final masques = <String>[];

  @override
  void markMessageDeletedForMe(String messageId, String userId) =>
      masques.add(messageId);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
