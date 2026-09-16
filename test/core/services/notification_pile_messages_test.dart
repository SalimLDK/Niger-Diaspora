import 'dart:io';

import 'package:diaspo_niger/core/services/notification_pile_messages.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ce que ce banc protège
/// ----------------------
/// Quand l'application est en arrière-plan ou fermée — c'est-à-dire quand une
/// notification sert vraiment — la bannière est posée sous le couple
/// `(tag: 'msg_<conversation>', id: 0)`. Android identifie une notification par
/// ce couple : chaque message ÉCRASAIT le précédent. Cinq messages reçus, un
/// seul lisible, aucun compteur, et rien qui dise que les quatre autres ont
/// existé.
///
/// Le chemin premier plan savait déjà empiler, mais son cache vit en mémoire
/// dans le singleton : l'isolate de notification ne le voit pas.
String _lire(String chemin) =>
    File(chemin).readAsStringSync().replaceAll('\r\n', '\n');

void main() {
  const service = 'lib/core/services/notification_service.dart';

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('la pile accumule au lieu de remplacer', () {
    test('trois messages d’une même conversation tiennent ensemble', () async {
      for (final n in [1, 2, 3]) {
        await PileMessagesNotifiees.empiler(
          conversationId: 'c1',
          messageId: 'm$n',
          texte: 'message $n',
          expediteur: 'Sim A',
        );
      }
      final pile = await PileMessagesNotifiees.lire('c1');
      expect(pile.map((m) => m.texte), ['message 1', 'message 2', 'message 3']);
    });

    test('deux conversations ne se mélangent pas', () async {
      await PileMessagesNotifiees.empiler(
          conversationId: 'c1', messageId: 'm1', texte: 'un', expediteur: 'A');
      await PileMessagesNotifiees.empiler(
          conversationId: 'c2', messageId: 'm2', texte: 'deux', expediteur: 'B');
      expect((await PileMessagesNotifiees.lire('c1')).single.texte, 'un');
      expect((await PileMessagesNotifiees.lire('c2')).single.texte, 'deux');
    });

    test('au-delà du plafond, les plus anciens sortent', () async {
      for (var n = 0; n < PileMessagesNotifiees.maxParConversation + 3; n++) {
        await PileMessagesNotifiees.empiler(
            conversationId: 'c1', messageId: 'm$n', texte: 't$n', expediteur: 'A');
      }
      final pile = await PileMessagesNotifiees.lire('c1');
      expect(pile.length, PileMessagesNotifiees.maxParConversation);
      // Ce sont bien les plus RÉCENTS qui restent.
      expect(pile.last.texte, 't${PileMessagesNotifiees.maxParConversation + 2}');
      expect(pile.first.texte, 't3');
    });

    test('le même message empilé deux fois ne compte qu’une', () async {
      // Le même push peut arriver en double (réseau coupé puis rétabli, renvoi
      // FCM) : la bannière afficherait la même phrase deux fois.
      await PileMessagesNotifiees.empiler(
          conversationId: 'c1', messageId: 'm1', texte: 'coucou', expediteur: 'A');
      await PileMessagesNotifiees.empiler(
          conversationId: 'c1', messageId: 'm1', texte: 'coucou', expediteur: 'A');
      expect((await PileMessagesNotifiees.lire('c1')).length, 1);
    });

    test('un message sans identifiant n’est pas dédoublonné à tort', () async {
      // Sans `messageId`, on ne peut rien affirmer : mieux vaut deux lignes
      // qu'un message avalé.
      await PileMessagesNotifiees.empiler(
          conversationId: 'c1', messageId: '', texte: 'a', expediteur: 'A');
      await PileMessagesNotifiees.empiler(
          conversationId: 'c1', messageId: '', texte: 'b', expediteur: 'A');
      expect((await PileMessagesNotifiees.lire('c1')).length, 2);
    });

    test('une pile d’hier ne remonte pas sous un message d’aujourd’hui', () async {
      await PileMessagesNotifiees.empiler(
        conversationId: 'c1',
        messageId: 'vieux',
        texte: 'hier',
        expediteur: 'A',
        quand: DateTime.now().subtract(PileMessagesNotifiees.duree * 2),
      );
      await PileMessagesNotifiees.empiler(
          conversationId: 'c1', messageId: 'neuf', texte: 'maintenant', expediteur: 'A');
      final pile = await PileMessagesNotifiees.lire('c1');
      expect(pile.map((m) => m.texte), ['maintenant']);
    });
  });

  group('la pile se vide quand la conversation est vue', () {
    test('vider une conversation ne touche pas l’autre', () async {
      await PileMessagesNotifiees.empiler(
          conversationId: 'c1', messageId: 'm1', texte: 'un', expediteur: 'A');
      await PileMessagesNotifiees.empiler(
          conversationId: 'c2', messageId: 'm2', texte: 'deux', expediteur: 'B');
      await PileMessagesNotifiees.vider('c1');
      expect(await PileMessagesNotifiees.lire('c1'), isEmpty);
      expect((await PileMessagesNotifiees.lire('c2')).length, 1);
      expect(await PileMessagesNotifiees.conversationsEnAttente(), ['c2']);
    });

    test('la déconnexion emporte tout — c’est du texte en clair', () async {
      await PileMessagesNotifiees.empiler(
          conversationId: 'c1', messageId: 'm1', texte: 'secret', expediteur: 'A');
      await PileMessagesNotifiees.viderTout();
      expect(await PileMessagesNotifiees.lire('c1'), isEmpty);
      expect(await PileMessagesNotifiees.conversationsEnAttente(), isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getKeys().where((k) => k.startsWith('notif_pile_')),
        isEmpty,
        reason: 'aucune trace, pas même l\'index',
      );
    });

    test('une pile expirée ne compte pas comme en attente', () async {
      await PileMessagesNotifiees.empiler(
        conversationId: 'c1',
        messageId: 'vieux',
        texte: 'hier',
        expediteur: 'A',
        quand: DateTime.now().subtract(PileMessagesNotifiees.duree * 2),
      );
      expect(await PileMessagesNotifiees.conversationsEnAttente(), isEmpty);
    });
  });

  group('câblage', () {
    test('le chemin d’arrière-plan empile et pose un MessagingStyle', () {
      final source = _lire(service);
      final i = source.indexOf('Future<void> _showFallbackMessageNotification(');
      expect(i, greaterThan(-1));
      final corps = source.substring(i, source.indexOf('\n}\n', i));
      expect(corps, contains('PileMessagesNotifiees.empiler('));
      expect(corps, contains('MessagingStyleInformation('));
      expect(corps, contains('styleInformation: styleMessagerie'));
      // Le compteur de la pastille du lanceur.
      expect(corps, contains('number: pile.length'));
    });

    test('ouvrir la conversation vide la pile', () {
      final source = _lire(service);
      final i = source.indexOf('Future<void> clearConversationNotifications(');
      final corps = source.substring(i, source.indexOf('\n  }', i));
      expect(corps, contains('PileMessagesNotifiees.vider(conversationId)'));
    });

    test('le retrait depuis un autre appareil aussi', () {
      final source = _lire(service);
      final i = source.indexOf('Future<void> _cancelNotificationsForConversation(');
      final corps = source.substring(i, source.indexOf('\n}\n', i));
      expect(corps, contains('PileMessagesNotifiees.vider(conversationId)'));
    });

    test('les deux chemins d’affichage posent le MÊME groupe Android', () {
      // Sinon la même conversation se retrouve dans deux groupes selon que
      // l'application était ouverte ou non.
      final source = _lire(service);
      expect(source, contains("const String kPrefixeGroupeMessages = 'messages_';"));
      expect(source, contains('static const String _messageGroupPrefix = kPrefixeGroupeMessages;'));
      expect(source, contains("groupKey: '\$kPrefixeGroupeMessages\$conversationId'"));
    });
  });
}
