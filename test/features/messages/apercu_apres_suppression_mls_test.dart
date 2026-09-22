import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/core/crypto/mls/mls_gateway.dart';
import 'package:diaspo_niger/core/network/network_info.dart';
import 'package:diaspo_niger/core/services/cache_service.dart';
import 'package:diaspo_niger/features/messages/data/datasources/message_remote_datasource.dart';
import 'package:diaspo_niger/features/messages/data/models/conversation_model.dart';
import 'package:diaspo_niger/features/messages/data/repositories/message_repository_impl.dart';
import 'package:diaspo_niger/features/messages/domain/entities/conversation_entity.dart';
import 'package:diaspo_niger/features/messages/domain/entities/message_entity.dart';

/// « Supprimer pour tous » son dernier message chiffré laissait son texte
/// dans la liste des discussions — vu le 2026-09-21 sur Pixel 10 Pro XL :
/// « Vous: PA6SECRET » deux minutes après la suppression, jusqu'à la relance.
///
/// L'aperçu d'une conversation chiffrée vient du cache local du fil ; la
/// suppression n'écrit que dans `mls_messages`, la ligne `conversations` ne
/// bouge pas, et rien ne faisait recalculer la liste. Même trou pour une
/// modification : la tuile gardait l'ancien texte.

final _quand = DateTime.utc(2026, 9, 21, 22, 14, 38);

Map<String, dynamic> _dernier(String contenu) => {
  'id': 'm1',
  'senderId': 'moi',
  'content': contenu,
  'type': 'text',
  'createdAt': _quand.toIso8601String(),
  'deletedForEveryone': false,
};

class _Source implements MessageRemoteDataSource {
  @override
  Stream<List<ConversationModel>> getConversations(String userId) =>
      Stream<List<ConversationModel>>.value([
        ConversationModel(
          id: 'c1',
          createdBy: 'moi',
          participantIds: const ['moi', 'autre'],
          // Conversation basculée : le serveur n'a jamais le clair.
          lastMessage: null,
          lastMessageAt: _quand,
          lastMessageType: MessageType.text,
        ),
      ]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Cache implements CacheService {
  final Map<String, Map<String, Map<String, dynamic>>> parConversation = {};

  @override
  Future<void> cacheConversations(
    List<Map<String, dynamic>> conversations,
  ) async {}

  /// Fusionne par id, comme le vrai.
  @override
  Future<void> cacheMessages(
    String conversationId,
    List<Map<String, dynamic>> messages,
  ) async {
    final fil = parConversation.putIfAbsent(conversationId, () => {});
    for (final m in messages) {
      fil[m['id'] as String] = m;
    }
  }

  @override
  List<Map<String, dynamic>> getCachedMessages(
    String conversationId, {
    int? limit,
    String? beforeMessageId,
  }) => [...?parConversation[conversationId]?.values];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Passerelle implements MlsGateway {
  final supprimes = <String>[];

  @override
  bool get actif => true;

  @override
  bool get aDesConversationsBasculees => true;

  @override
  Future<void> amorcerBascules(Iterable<String> conversationIds) async {}

  @override
  Future<Map<String, String>> apercusDejaDechiffres(
    Iterable<String> conversationIds,
  ) async => const {};

  @override
  Future<List<String>> conversationsARattraper(
    Iterable<String> conversationIds, {
    int maximum = 3,
  }) async => const [];

  @override
  Future<Map<String, ({int nonLus, int mentions})>> nonLus() async =>
      const {};

  @override
  Stream<void> get lecturesAvancees => const Stream<void>.empty();

  @override
  Future<bool> estMlsMessage(String conversationId, String messageId) async =>
      true;

  @override
  Future<void> supprimerPourTous(String messageId) async =>
      supprimes.add(messageId);

  @override
  Future<void> modifier({
    required String conversationId,
    required String messageId,
    required String nouveauTexte,
  }) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Reseau implements NetworkInfo {
  @override
  Future<bool> get isConnected async => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _Cache cache;
  late _Passerelle passerelle;
  late MessageRepositoryImpl depot;
  late List<ConversationEntity> vues;
  late StreamSubscription<void> sub;

  setUp(() async {
    cache = _Cache();
    await cache.cacheMessages('c1', [_dernier('PA6SECRET')]);
    passerelle = _Passerelle();
    depot = MessageRepositoryImpl(
      remoteDataSource: _Source(),
      networkInfo: _Reseau(),
      cacheService: cache,
      mlsGateway: passerelle,
    );
    vues = [];
    sub = depot.getConversations('moi').listen((e) {
      e.fold((_) {}, (liste) => vues.add(liste.single));
    });
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(vues.last.lastMessage, 'PA6SECRET',
        reason: 'point de départ : la tuile montre le dernier message');
  });

  tearDown(() => sub.cancel());

  test('supprimer pour tous : la tuile dit « supprimé » et perd le texte, '
      'sans attendre le serveur', () async {
    final r = await depot.deleteMessageForEveryone(
      conversationId: 'c1',
      messageId: 'm1',
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(r.isRight(), isTrue);
    expect(passerelle.supprimes, ['m1']);
    expect(vues.last.lastMessage ?? '', isNot(contains('PA6SECRET')),
        reason: 'le texte supprimé ne doit plus être dans la liste');
    expect(vues.last.apercuEfface, ApercuEfface.supprime);
    expect(cache.getCachedMessages('c1').single['content'], isEmpty,
        reason: 'la copie locale du texte est retirée, pas seulement marquée');
  });

  test('supprimer pour tous : l\'entrée du cache perd aussi la clé du média, '
      'le fichier, la carte et la citation', () async {
    // Une photo chiffrée qui citait un message et portait un aperçu de lien.
    // Seul `content` était vidé : le reste attendait sur le disque le
    // passage suivant du fil — jamais venu si l'app était tuée entre-temps.
    await cache.cacheMessages('c1', [
      {
        ..._dernier('PA6SECRET'),
        'type': 'image',
        'fileUrl': 'https://exemple.test/blob',
        'fileName': 'vacances.jpg',
        'mediaChiffre': {
          'v': 1,
          'storagePath': 'encrypted_media/c1/moi/x',
          'encryptedUrl': 'https://exemple.test/blob',
          'fileKey': 'Q0xFRlNFQ1JFVEU=',
          'iv': 'SVY=',
          'fileName': 'vacances.jpg',
          'mimeType': 'image/jpeg',
          'size': 42,
        },
        'replyToId': 'm0',
        'replyToMessageData': {'content': 'citation'},
        'linkPreviewData': {'url': 'https://exemple.test'},
        'readBy': ['moi', 'autre'],
      },
    ]);

    await depot.deleteMessageForEveryone(conversationId: 'c1', messageId: 'm1');

    final entree = cache.getCachedMessages('c1').single;
    expect(entree['deletedForEveryone'], isTrue);
    expect(entree['content'], isEmpty);
    for (final cle in [
      'fileUrl',
      'fileName',
      'mediaChiffre',
      'replyToId',
      'replyToMessageData',
      'linkPreviewData',
    ]) {
      expect(entree[cle], isNull, reason: '« $cle » resté sur le disque');
    }
    expect(entree.toString(), isNot(contains('Q0xFRlNFQ1JFVEU=')));
    // Ce qui fait la bulle reste : identifiant, date, lecture.
    expect(entree['id'], 'm1');
    expect(DateTime.parse(entree['createdAt'] as String), _quand);
    expect(entree['readBy'], ['moi', 'autre']);
  });

  test('modifier son dernier message : la tuile prend le nouveau texte',
      () async {
    final r = await depot.editMessage(
      conversationId: 'c1',
      messageId: 'm1',
      newContent: 'PA6 corrigé',
      oldContent: 'PA6SECRET',
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(r.isRight(), isTrue);
    expect(vues.last.lastMessage, 'PA6 corrigé');
  });
}
