// Trois défauts vus sur SM A515F le 2026-09-22 (build Play 1.2.2+26), voir
// TESTS_APPAREIL_A_FAIRE.md : « Recherche, favoris et galerie d'une
// conversation chiffrée » et « Nom et avatar du correspondant dans la liste
// des discussions ».
import 'dart:io';

import 'package:diaspo_niger/core/services/e2ee/undecryptable_placeholders.dart';
import 'package:diaspo_niger/features/messages/data/datasources/message_supabase_datasource.dart';
import 'package:diaspo_niger/features/messages/data/models/message_model.dart';
import 'package:flutter_test/flutter_test.dart';

MessageModel _msg(String id, String contenu) => MessageModel.fromJson({
      'id': id,
      'senderId': 'u1',
      'content': contenu,
      'type': 'text',
      'createdAt': '2026-09-15T10:00:00.000Z',
    });

void main() {
  group('Recherche : le serveur cherche dans le chiffré', () {
    test('un ciphertext qui contient le mot n\'est pas une réponse', () {
      // Relevé tel quel sur l'écran de recherche, « Yo » en majuscules dans
      // le base64.
      final chiffre = _msg(
        'a',
        'v1:/YO6lTZ8e0b69CLOgLRo7Q==:SEEiIX1HmTJx1tvwwBabcdefghijklmn==',
      );
      final clair = _msg('b', 'Yo');
      final res = garderSiLeClairContient([chiffre, clair], 'Yo');
      expect(res.map((m) => m.id), ['b']);
    });

    test('ancien format sans version, et AES-GCM, écartés aussi', () {
      final res = garderSiLeClairContient([
        _msg('a', 'AAAAAAAAAAAAAAAAAAAAAA==:yoyoyoyoyoyoyoyoyoyoyo=='),
        _msg('b', 'gcm:AAAAAAAAAAAA:yoyoyoyoyoyo'),
      ], 'yo');
      expect(res, isEmpty);
    });

    test('un marqueur d\'échec qui contient le mot n\'est pas une réponse', () {
      final res = garderSiLeClairContient([
        _msg('a', kAesUndecryptablePlaceholder),
        _msg('b', kEncryptedMessagePlaceholder),
        _msg('c', 'un vrai message'),
      ], 'message');
      expect(res.map((m) => m.id), ['c']);
    });

    test('le clair est trouvé sans casse, et deux points ne le trahissent pas',
        () {
      final res = garderSiLeClairContient([
        _msg('a', 'Rendez-vous : 18h à la mosquée'),
        _msg('b', 'Salim L. a raison PJ2'),
      ], 'pj2');
      expect(res.map((m) => m.id), ['b']);
      expect(
        garderSiLeClairContient([_msg('a', 'Rendez-vous : 18h')], 'rendez'),
        hasLength(1),
      );
    });

    test('recherche vide : rien', () {
      expect(garderSiLeClairContient([_msg('a', 'x')], '  '), isEmpty);
    });

    test('la source applique le filtre après déchiffrement', () {
      final src = File(
        'lib/features/messages/data/datasources/message_supabase_datasource.dart',
      ).readAsStringSync();
      final debut = src.indexOf('Future<List<MessageModel>> searchMessagesInConversation(');
      final fin = src.indexOf('Future<List<MessageModel>> getMessagesSince(');
      final corps = src.substring(debut, fin);
      expect(corps, contains('_msgFromRowAsync'),
          reason: 'sans déchiffrement, le filtre ne voit que du chiffré');
      expect(corps, contains('garderSiLeClairContient('));
      expect(corps, isNot(contains('rows.map(_msgFromRow)')));
    });
  });

  group('Favoris : la liste suit les étoiles', () {
    final src = File(
      'lib/features/messages/presentation/providers/message_provider.dart',
    ).readAsStringSync();

    test('le provider se libère avec l\'écran', () {
      // Sans autoDispose, la liste était calculée une fois par processus :
      // une étoile retirée restait affichée jusqu'à la relance.
      expect(
        src,
        contains('final starredMessagesProvider = FutureProvider.autoDispose.family'),
      );
    });

    test('basculer une étoile invalide la liste de la conversation', () {
      final debut = src.indexOf('Future<void> toggleStar(String messageId)');
      final fin = src.indexOf('void markAllAsReadLocally(', debut);
      expect(
        src.substring(debut, fin),
        contains('invalidate(starredMessagesProvider(conversationId))'),
      );
    });
  });

  group('Contacts récents : le nom vient du profil', () {
    test('la tuile lit le profil du correspondant, pas conversation.name seul',
        () {
      final src = File(
        'lib/features/messages/presentation/screens/new_conversation_screen.dart',
      ).readAsStringSync();
      final debut = src.indexOf('Widget _buildRecentTile(');
      final corps = src.substring(debut, src.indexOf('return GestureDetector', debut));
      expect(corps, contains('userStreamProvider('),
          reason: 'un 1:1 n\'a pas de name : sans profil, chaque ligne '
              'affiche « Utilisateur »');
      expect(corps, isNot(contains('final name = conversation.name ??')));
    });
  });
}
