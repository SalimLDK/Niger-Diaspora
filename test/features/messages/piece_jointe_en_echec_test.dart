import 'dart:io';

import 'package:diaspo_niger/core/services/offline_queue_service.dart';
import 'package:diaspo_niger/features/messages/domain/entities/message_entity.dart';
import 'package:diaspo_niger/features/messages/presentation/providers/message_pagination_state.dart';
import 'package:diaspo_niger/features/messages/presentation/providers/message_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Une pièce jointe dont l'envoi échoue.
///
/// La bulle de progression disparaissait, et rien ne la remplaçait : pas de
/// bulle en échec, pas de « Renvoyer », rien dans la file d'attente — et
/// `retryFailedMessage` refusait de toute façon image, document et vidéo.
/// La pièce jointe était perdue sans un mot.
void main() {
  final refProvider = Provider<Ref>((ref) => ref);

  late Directory racine;
  setUp(() => racine = Directory.systemTemp.createTempSync('pj_echec'));
  tearDown(() {
    if (racine.existsSync()) racine.deleteSync(recursive: true);
  });

  MessageEntity echec(String chemin, {MessageType type = MessageType.image}) =>
      MessageEntity(
        id: 'temp_file_1',
        senderId: 'u1',
        senderName: 'Moi',
        content: 'la légende',
        type: type,
        status: MessageStatus.failed,
        createdAt: DateTime.utc(2026, 10, 3, 9),
        readBy: const [],
        readAt: const {},
        fileUrl: 'file://$chemin',
        localFilePath: chemin,
        fileName: chemin.split('/').last,
      );

  group('pieceJointeEnEchec', () {
    test('écran fermé : mise de côté avec son fichier local', () async {
      final file = _File();
      final conteneur = ProviderContainer(overrides: [
        offlineQueueServiceProvider.overrideWithValue(file),
      ]);
      addTearDown(conteneur.dispose);
      final chemin = '${racine.path}/photo.jpg';

      await pieceJointeEnEchec(conteneur.read(refProvider), 'c1', echec(chemin));

      final e = file.entrees.single;
      expect(e.filePath, chemin, reason: 'c\'est lui que le renvoi relira');
      expect(e.type, 'image');
      expect(e.content, 'la légende');
      expect(messageEnAttenteVersEntite(e)!.localFilePath, chemin);
    });

    test('écran ouvert : la bulle en échec apparaît', () async {
      final file = _File();
      final ecran = _Ecran();
      final conteneur = ProviderContainer(overrides: [
        offlineQueueServiceProvider.overrideWithValue(file),
        paginatedMessagesProvider.overrideWith((ref, id) => ecran),
      ]);
      addTearDown(conteneur.dispose);
      conteneur.listen(paginatedMessagesProvider('c1'), (_, __) {});

      await pieceJointeEnEchec(
          conteneur.read(refProvider), 'c1', echec('${racine.path}/a.jpg'));

      expect(ecran.ajoutes.single.status, MessageStatus.failed);
      expect(ecran.ajoutes.single.fileUrl, startsWith('file://'));
      expect(file.entrees, hasLength(1));
    });
  });

  group('retryFailedMessage', () {
    ProviderContainer conteneur(List<_Envois> envois, _Ecran ecran) {
      final c = ProviderContainer(overrides: [
        sendMessageProvider.overrideWith((ref) {
          final e = _Envois(ref);
          envois.add(e);
          return e;
        }),
        paginatedMessagesProvider.overrideWith((ref, id) => ecran),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    for (final type in [
      MessageType.image,
      MessageType.file,
      MessageType.video,
      MessageType.audio,
    ]) {
      test('${type.name} : repart de son fichier local', () async {
        final f = File('${racine.path}/piece.bin')..writeAsStringSync('x');
        final envois = <_Envois>[];
        final ecran = _Ecran();
        final c = conteneur(envois, ecran);

        final ok = await c.read(sendMessageProvider.notifier).retryFailedMessage(
              conversationId: 'c1',
              failedMessage: echec(f.path, type: type),
            );

        expect(ok, isTrue);
        expect(envois.single.fichiers.single, (f.path, type, 'la légende'),
            reason: 'un fichier audio importé n\'est pas une note vocale');
        expect(ecran.retires, ['temp_file_1']);
      });
    }

    test('fichier disparu : erreur dite, rien d\'envoyé, la bulle reste',
        () async {
      final envois = <_Envois>[];
      final ecran = _Ecran();
      final c = conteneur(envois, ecran);

      final ok = await c.read(sendMessageProvider.notifier).retryFailedMessage(
            conversationId: 'c1',
            failedMessage: echec('${racine.path}/disparu.jpg'),
          );

      expect(ok, isFalse);
      expect(envois.single.fichiers, isEmpty);
      expect(ecran.retires, isEmpty);
      expect(c.read(sendMessageProvider).hasError, isTrue);
    });
  });
}

class _File extends OfflineQueueService {
  final entrees = <PendingMessage>[];

  @override
  Future<void> init() async {}

  @override
  List<PendingMessage> getQueue() => List.of(entrees);

  @override
  bool isInQueue(String messageId) => entrees.any((m) => m.id == messageId);

  @override
  Future<void> enqueue(PendingMessage message) async => entrees.add(message);
}

class _Ecran extends StateNotifier<MessagePaginationState>
    implements PaginatedMessagesNotifier {
  _Ecran() : super(const MessagePaginationState());

  final ajoutes = <MessageEntity>[];
  final retires = <String>[];

  @override
  void addOptimisticMessage(MessageEntity message) => ajoutes.add(message);

  @override
  void updateMessageStatus(String messageId, MessageStatus newStatus) {}

  @override
  void removeMessageOptimistically(String messageId) => retires.add(messageId);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Le vrai `retryFailedMessage`, avec un `sendFile` qui note sans envoyer.
class _Envois extends SendMessageNotifier {
  _Envois(super.ref);

  final fichiers = <(String, MessageType, String?)>[];

  @override
  Future<bool> sendFile({
    required String conversationId,
    required File file,
    required MessageType type,
    String? caption,
    MessageEntity? replyToMessage,
    bool isForwarded = false,
    DateTime? ecritLe,
  }) async {
    fichiers.add((file.path, type, caption));
    return true;
  }
}
