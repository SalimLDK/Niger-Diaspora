import 'package:flutter_test/flutter_test.dart';
import 'package:diaspo_niger/features/messages/data/models/message_model.dart';
import 'package:diaspo_niger/features/messages/domain/entities/message_entity.dart';

/// La bulle de sondage ne transporte QUE `pollId` : la question, les options
/// et les compteurs sont relus depuis `post_polls`. Si `pollId` se perd dans
/// la sérialisation, la bulle n'a plus rien à afficher — et l'écran ne
/// signale rien, il montre une carte vide. D'où ces tests.
void main() {
  group('bulle de sondage : le type et son id survivent au transport', () {
    test('un message Supabase de type poll se relit en MessageType.poll', () {
      final model = MessageModel.fromJson({
        'id': 'm1',
        'senderId': 'u1',
        'senderName': 'Sim A',
        'content': 'Qui vient samedi ?',
        'type': 'poll',
        'pollId': 'cc6f0d55-1eac-4816-bfa3-795eb5f244d3',
        'createdAt': '2026-08-24T02:59:01.000Z',
      });

      // `MessageModel.type` reste la chaine brute : c'est `toEntity()` qui
      // la traduit en enum. Les deux moities sont verifiees.
      expect(model.type, 'poll');
      expect(model.toEntity().type, MessageType.poll);
      expect(model.pollId, 'cc6f0d55-1eac-4816-bfa3-795eb5f244d3');
      expect(model.content, 'Qui vient samedi ?');
    });

    test('toJson réémet pollId', () {
      final model = MessageModel.fromJson({
        'id': 'm1',
        'senderId': 'u1',
        'senderName': 'Sim A',
        'content': 'Qui vient samedi ?',
        'type': 'poll',
        'pollId': 'poll-42',
      });

      expect(model.toJson()['pollId'], 'poll-42');
      expect(model.toJson()['type'], 'poll');
    });

    test('toEntity porte pollId, et isPoll répond oui', () {
      final entity = MessageModel.fromJson({
        'id': 'm1',
        'senderId': 'u1',
        'senderName': 'Sim A',
        'content': 'Qui vient samedi ?',
        'type': 'poll',
        'pollId': 'poll-42',
      }).toEntity();

      expect(entity.isPoll, isTrue);
      expect(entity.pollId, 'poll-42');
    });

    test('un type inconnu retombe sur texte, sans emporter poll avec lui', () {
      final model = MessageModel.fromJson({
        'id': 'm1',
        'senderId': 'u1',
        'senderName': 'Sim A',
        'content': 'x',
        'type': 'type_qui_nexiste_pas',
      });

      expect(model.toEntity().type, MessageType.text);
      expect(model.pollId, isNull);
    });

    test('un message sans pollId reste affichable : la question sert de repli',
        () {
      final entity = MessageModel.fromJson({
        'id': 'm1',
        'senderId': 'u1',
        'senderName': 'Sim A',
        'content': 'Question orpheline',
        'type': 'poll',
      }).toEntity();

      expect(entity.isPoll, isTrue);
      expect(entity.pollId, isNull);
      expect(entity.content, 'Question orpheline');
    });
  });
}
