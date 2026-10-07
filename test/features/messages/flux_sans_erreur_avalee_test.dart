import 'dart:async';
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:diaspo_niger/core/errors/failures.dart';
import 'package:diaspo_niger/core/network/network_info.dart';
import 'package:diaspo_niger/core/services/cache_service.dart';
import 'package:diaspo_niger/features/messages/data/datasources/message_remote_datasource.dart';
import 'package:diaspo_niger/features/messages/data/models/message_model.dart';
import 'package:diaspo_niger/features/messages/data/repositories/message_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

/// Les flux temps réel d'une discussion ne mangent plus leurs erreurs.
///
/// `getNewMessagesStream` et `getMessageUpdatesStream` finissaient par
/// `.handleError((e) { return Left(...); })`. Or `Stream.handleError` ignore
/// la valeur de retour de son rappel : le `Left` n'était jamais émis, l'erreur
/// disparaissait, et l'écran l'écoutait avec `(failure) {}`. Côté source, un
/// message illisible dans le rappel temps réel était noté « livré » AVANT
/// d'être décodé : l'exception se perdait dans la zone, et le message ne
/// revenait plus — ni par le direct, ni par le rattrapage.
void main() {
  late StreamController<List<MessageModel>> nouveaux;
  late StreamController<MessageModel> majs;
  late MessageRepositoryImpl depot;

  setUp(() {
    nouveaux = StreamController<List<MessageModel>>();
    majs = StreamController<MessageModel>();
    depot = MessageRepositoryImpl(
      remoteDataSource: _Source(nouveaux.stream, majs.stream),
      networkInfo: _Reseau(),
      cacheService: _Cache(),
    );
  });

  MessageModel m(String id) => MessageModel(
        id: id,
        senderId: 'u2',
        senderName: 'Amina',
        content: 'message $id',
        createdAt: DateTime.utc(2026, 10, 7, 9),
      );

  test('nouveaux messages : l\'erreur devient un Left, le flux continue',
      () async {
    final recus = <Either<Failure, List<String>>>[];
    final fin = Completer<void>();
    depot
        .getNewMessagesStream(conversationId: 'c1', afterTimestamp: DateTime(2026))
        .listen(
          (e) => recus.add(e.map((l) => l.map((x) => x.id).toList())),
          onDone: fin.complete,
        );

    nouveaux
      ..addError(Exception('ligne illisible'))
      ..add([m('apres')]);
    await nouveaux.close();
    await fin.future;

    expect(recus, hasLength(2));
    expect(recus.first.isLeft(), isTrue);
    expect(recus.last.getOrElse(() => []), ['apres']);
  });

  test('mises à jour : l\'erreur devient un Left, le flux continue', () async {
    final recus = <Either<Failure, String>>[];
    final fin = Completer<void>();
    depot.getMessageUpdatesStream(conversationId: 'c1').listen(
          (e) => recus.add(e.map((x) => x.id)),
          onDone: fin.complete,
        );

    majs
      ..addError(Exception('coupure'))
      ..add(m('m1'));
    await majs.close();
    await fin.future;

    expect(recus.map((e) => e.isLeft()), [true, false]);
  });

  test('source : un message illisible redevient rattrapable, et le dit', () {
    final source = File(
      'lib/features/messages/data/datasources/message_supabase_datasource.dart',
    ).readAsStringSync();
    final debut = source.indexOf('Stream<List<MessageModel>> getNewMessagesStream(');
    final corps = source.substring(debut, source.indexOf('\n  }\n', debut));
    // Dans le rappel ET dans le rattrapage, ligne par ligne.
    expect('livres.remove(id);'.allMatches(corps), hasLength(2));
    expect('controller.addError('.allMatches(corps), hasLength(2));
  });

  test('l\'écran ne jette plus l\'échec dans un rappel vide', () {
    final source = File(
      'lib/features/messages/presentation/providers/message_provider.dart',
    ).readAsStringSync();
    for (final ancre in [
      'void _listenForNewMessages(',
      'void _listenForMessageUpdates(',
    ]) {
      final debut = source.indexOf(ancre);
      final corps = source.substring(debut, source.indexOf('\n  }\n', debut));
      expect(corps, isNot(contains('(failure) {}')), reason: ancre);
      expect(corps, contains('signalerEchecSilencieux('), reason: ancre);
    }
  });
}

class _Source implements MessageRemoteDataSource {
  _Source(this.nouveaux, this.majs);

  final Stream<List<MessageModel>> nouveaux;
  final Stream<MessageModel> majs;

  @override
  Stream<List<MessageModel>> getNewMessagesStream({
    required String conversationId,
    required DateTime afterTimestamp,
  }) =>
      nouveaux;

  @override
  Stream<MessageModel> getMessageUpdatesStream({
    required String conversationId,
  }) =>
      majs;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Cache implements CacheService {
  @override
  List<Map<String, dynamic>> getCachedMessages(
    String conversationId, {
    int? limit,
    String? beforeMessageId,
  }) =>
      const [];

  @override
  Future<void> cacheMessages(
    String conversationId,
    List<Map<String, dynamic>> messages,
  ) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Reseau implements NetworkInfo {
  @override
  Future<bool> get isConnected async => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
