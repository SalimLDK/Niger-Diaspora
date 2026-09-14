import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/core/services/offline_queue_service.dart';
import 'package:diaspo_niger/features/messages/data/models/message_model.dart';
import 'package:diaspo_niger/features/messages/domain/entities/message_entity.dart';
import 'package:diaspo_niger/features/messages/presentation/providers/message_provider.dart';

/// Un message jamais parti doit pouvoir repartir **tel qu'il était**.
///
/// Les champs plats de `PendingMessage` ne décrivaient qu'un texte nu, et
/// codaient même le type « text » en dur : une réponse citée ou une carte de
/// publication aurait été renvoyée amputée. D'où le blob `messageJson`, et
/// d'où ces tests — c'est la seule partie de la garde qui se vérifie sans
/// téléphone.
MessageEntity _message({
  String id = 'temp_1',
  MessageType type = MessageType.text,
  String contenu = 'bonjour',
  String? replyToId,
  Map<String, dynamic>? replyToMessageData,
  Map<String, dynamic>? postData,
  String? localFilePath,
}) {
  return MessageEntity(
    id: id,
    senderId: 'moi',
    senderName: 'Sim',
    content: contenu,
    type: type,
    status: MessageStatus.failed,
    createdAt: DateTime(2026, 9, 14, 4, 57),
    readBy: const [],
    readAt: const {},
    replyToId: replyToId,
    replyToMessageData: replyToMessageData,
    postData: postData,
    localFilePath: localFilePath,
  );
}

PendingMessage _enFile(MessageEntity message, {String? filePath}) {
  return PendingMessage(
    id: message.id,
    conversationId: 'conv-1',
    senderId: message.senderId,
    senderName: message.senderName,
    content: message.content,
    type: message.type.name,
    filePath: filePath,
    createdAt: message.createdAt,
    messageJson: jsonEncode(MessageModel.fromEntity(message).toJson()),
  );
}

void main() {
  group('messageEnAttenteVersEntite', () {
    test('un texte simple revient identique', () {
      final origine = _message(contenu: 'RATTRAPAGE-CONV-1');

      final rendu = messageEnAttenteVersEntite(_enFile(origine));

      expect(rendu, isNotNull);
      expect(rendu!.id, origine.id);
      expect(rendu.content, 'RATTRAPAGE-CONV-1');
      expect(rendu.type, MessageType.text);
      expect(rendu.status, MessageStatus.failed);
    });

    test('une réponse citée survit — les champs plats la perdaient', () {
      final origine = _message(
        replyToId: 'msg-cité',
        replyToMessageData: const {
          'id': 'msg-cité',
          'senderId': 'autre',
          'senderName': 'Salim L.',
          'content': 'le message d\'origine',
          'type': 'text',
        },
      );

      final rendu = messageEnAttenteVersEntite(_enFile(origine));

      expect(rendu!.replyToId, 'msg-cité');
      expect(rendu.replyToMessageData?['senderName'], 'Salim L.');
    });

    test('une carte de publication survit', () {
      final origine = _message(
        postData: const {'postId': 'p-1', 'authorName': 'Salim L.'},
      );

      final rendu = messageEnAttenteVersEntite(_enFile(origine));

      expect(rendu!.postData?['postId'], 'p-1');
    });

    test('le type n\'est plus « text » en dur', () {
      final origine = _message(id: 'temp_img', type: MessageType.image);

      final rendu = messageEnAttenteVersEntite(_enFile(origine));

      expect(rendu!.type, MessageType.image);
    });

    test(
      'le chemin du média est restitué — il ne vit pas dans le modèle',
      () {
        // `MessageModel` ne porte pas `localFilePath` : sans la reprise
        // explicite depuis `filePath`, un média à renvoyer n'aurait plus rien
        // à téléverser.
        final origine = _message(id: 'temp_img', type: MessageType.image);

        final rendu = messageEnAttenteVersEntite(
          _enFile(origine, filePath: '/data/user/0/cache/photo.jpg'),
        );

        expect(rendu!.localFilePath, '/data/user/0/cache/photo.jpg');
      },
    );

    test('une entrée d\'une ancienne version reste renvoyable en texte', () {
      // Écrite avant l'ajout de `messageJson` : on ne peut pas mieux faire
      // que le texte, mais il ne faut surtout pas la jeter.
      final ancienne = PendingMessage(
        id: 'pending_vieux',
        conversationId: 'conv-1',
        senderId: 'moi',
        senderName: 'Sim',
        content: 'écrit par une version précédente',
      );

      final rendu = messageEnAttenteVersEntite(ancienne);

      expect(rendu, isNotNull);
      expect(rendu!.content, 'écrit par une version précédente');
      expect(rendu.type, MessageType.text);
    });

    test('un blob illisible ne fait pas tomber le renvoi', () {
      final abime = PendingMessage(
        id: 'pending_abime',
        conversationId: 'conv-1',
        senderId: 'moi',
        senderName: 'Sim',
        content: 'repli sur le texte',
        messageJson: '{ceci n\'est pas du json',
      );

      final rendu = messageEnAttenteVersEntite(abime);

      expect(rendu!.content, 'repli sur le texte');
    });

    test('une entrée sans rien à renvoyer est écartée', () {
      final vide = PendingMessage(
        id: 'pending_vide',
        conversationId: 'conv-1',
        senderId: 'moi',
        senderName: 'Sim',
        content: '',
      );

      expect(messageEnAttenteVersEntite(vide), isNull);
    });
  });

  group('fenêtre de renvoi automatique', () {
    test('24 h par défaut, et une fenêtre nulle la désactive', () {
      // Le renvoi compare `now - createdAt` à cette constante ; une fenêtre
      // nulle rend la comparaison inopérante, donc le renvoi inconditionnel.
      expect(kFenetreRenvoiAutomatique, const Duration(hours: 24));
      expect(kFenetreRenvoiAutomatique > Duration.zero, isTrue);
    });
  });
}
