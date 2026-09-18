import 'dart:io';

import 'package:diaspo_niger/core/services/notification_pile_messages.dart';
import 'package:diaspo_niger/core/services/notification_service.dart';
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

/// Aujourd'hui à [heure]:[minute], heure locale.
///
/// Les dates de ce banc ne peuvent pas être écrites en dur : la pile expire ses
/// lignes au bout de 24 h (`PileMessagesNotifiees.duree`) en les comparant à
/// `DateTime.now()`, et `texteHorodate` compare le JOUR CIVIL à `DateTime.now()`
/// pour écrire « hier ». Un `DateTime(2026, 9, 16, …)` passait le jour où il a
/// été écrit et cassait le lendemain, sans qu'aucun code n'ait changé.
///
/// « Aujourd'hui à HH:MM » reste dans la fenêtre de 24 h quelle que soit
/// l'heure du test : `maintenant - 24 h` tombe la veille, et une heure encore
/// à venir n'est pas expirée. Une seule exception, le jour du passage à
/// l'heure d'hiver (journée de 25 h) : avant 01:00, une ligne peut déjà être
/// expirée en fin de journée. Pas d'heure plus matinale que ça avec la pile.
DateTime _aujourdhui(int heure, [int minute = 0]) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day, heure, minute);
}

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

  group('un même expéditeur qui envoie plusieurs messages', () {
    test('les trois sont gardés, chacun avec son heure', () async {
      final base = _aujourdhui(9, 58);
      for (var n = 0; n < 3; n++) {
        await PileMessagesNotifiees.empiler(
          conversationId: 'c1',
          messageId: 'm$n',
          texte: 'ligne $n',
          expediteur: 'Alice',
          expediteurId: 'uid-alice',
          quand: base.add(Duration(minutes: n * 3)),
        );
      }
      final pile = await PileMessagesNotifiees.lire('c1');
      expect(pile.map((m) => m.texte), ['ligne 0', 'ligne 1', 'ligne 2']);
      expect(pile.map((m) => texteHorodate(m.quand, m.texte)),
          ['ligne 0 · 09:58', 'ligne 1 · 10:01', 'ligne 2 · 10:04']);
    });

    test('ils portent tous la MÊME clé d’identité', () async {
      // C'est par elle qu'Android regroupe les messages consécutifs d'une
      // même personne sous un seul en-tête. Une clé qui change au milieu
      // répèterait l'en-tête à chaque ligne.
      for (var n = 0; n < 3; n++) {
        await PileMessagesNotifiees.empiler(
          conversationId: 'c1', messageId: 'm$n', texte: 't$n',
          expediteur: 'Alice', expediteurId: 'uid-alice');
      }
      final cles = (await PileMessagesNotifiees.lire('c1'))
          .map((m) => m.cleIdentite).toSet();
      expect(cles, {'uid-alice'});
    });

    test('la clé tient même si le nom manque sur une charge', () async {
      // En groupe, le chemin d'arrière-plan retombe sur le TITRE quand
      // `senderName` manque — c'est-à-dire le nom du groupe. Sans identifiant,
      // ce message-là se serait retrouvé sous un autre expéditeur au milieu
      // de la pile.
      await PileMessagesNotifiees.empiler(
          conversationId: 'c1', messageId: 'm1', texte: 'a',
          expediteur: 'Alice', expediteurId: 'uid-alice');
      await PileMessagesNotifiees.empiler(
          conversationId: 'c1', messageId: 'm2', texte: 'b',
          expediteur: 'Groupe Banc', expediteurId: 'uid-alice');
      final cles = (await PileMessagesNotifiees.lire('c1'))
          .map((m) => m.cleIdentite).toSet();
      expect(cles, {'uid-alice'});
    });

    test('deux homónymes restent deux personnes', () async {
      await PileMessagesNotifiees.empiler(
          conversationId: 'c1', messageId: 'm1', texte: 'a',
          expediteur: 'Sim A', expediteurId: 'uid-1');
      await PileMessagesNotifiees.empiler(
          conversationId: 'c1', messageId: 'm2', texte: 'b',
          expediteur: 'Sim A', expediteurId: 'uid-2');
      final cles = (await PileMessagesNotifiees.lire('c1'))
          .map((m) => m.cleIdentite).toSet();
      expect(cles, {'uid-1', 'uid-2'});
    });

    test('une pile écrite AVANT ce champ retombe sur le nom', () async {
      await PileMessagesNotifiees.empiler(
          conversationId: 'c1', messageId: 'm1', texte: 'a', expediteur: 'Alice');
      expect((await PileMessagesNotifiees.lire('c1')).single.cleIdentite, 'Alice');
    });
  });

  group('l’ordre est celui de la conversation', () {
    test('du plus ancien au plus récent, quel que soit l’ordre d’arrivée', () async {
      // Au retour du réseau, plusieurs messages arrivent d'un coup et pas
      // toujours dans l'ordre où ils ont été écrits. C'est l'heure du serveur
      // qui tranche, pas l'ordre d'empilement.
      final base = _aujourdhui(10);
      await PileMessagesNotifiees.empiler(
          conversationId: 'c1', messageId: 'm3', texte: 'troisième',
          expediteur: 'A', quand: base.add(const Duration(minutes: 2)));
      await PileMessagesNotifiees.empiler(
          conversationId: 'c1', messageId: 'm1', texte: 'premier',
          expediteur: 'A', quand: base);
      await PileMessagesNotifiees.empiler(
          conversationId: 'c1', messageId: 'm2', texte: 'deuxième',
          expediteur: 'A', quand: base.add(const Duration(minutes: 1)));
      final pile = await PileMessagesNotifiees.lire('c1');
      expect(pile.map((m) => m.texte), ['premier', 'deuxième', 'troisième']);
    });

    test('l’heure posée est bien celle qu’on a donnée', () async {
      final quand = _aujourdhui(8, 30);
      await PileMessagesNotifiees.empiler(
          conversationId: 'c1', messageId: 'm1', texte: 'a',
          expediteur: 'A', quand: quand);
      expect((await PileMessagesNotifiees.lire('c1')).single.quand, quand);
    });
  });

  group('une édition corrige la ligne, sans en créer', () {
    test('le texte change, la place et l’heure ne bougent pas', () async {
      final base = _aujourdhui(10);
      await PileMessagesNotifiees.empiler(
          conversationId: 'c1', messageId: 'm1', texte: 'rdv à 17h',
          expediteur: 'Alice', expediteurId: 'uid-a', quand: base);
      await PileMessagesNotifiees.empiler(
          conversationId: 'c1', messageId: 'm2', texte: 'ok',
          expediteur: 'Bob', expediteurId: 'uid-b',
          quand: base.add(const Duration(minutes: 5)));

      final pile = await PileMessagesNotifiees.remplacer(
          conversationId: 'c1', messageId: 'm1', texte: 'rdv à 18h');

      expect(pile, isNotNull);
      expect(pile!.map((m) => m.texte), ['rdv à 18h', 'ok']);
      // L'heure reste celle de l'ENVOI : la ligne ne saute pas de place parce
      // qu'une faute a été corrigée.
      expect(pile.first.quand, base);
      expect(pile.first.expediteurId, 'uid-a');
    });

    test('un message absent de la pile ne crée RIEN', () async {
      // Le point le plus important : faire réapparaître une conversation déjà
      // lue parce qu'une faute a été rectifiée serait pire que le défaut.
      await PileMessagesNotifiees.empiler(
          conversationId: 'c1', messageId: 'm1', texte: 'a', expediteur: 'A');
      expect(
        await PileMessagesNotifiees.remplacer(
            conversationId: 'c1', messageId: 'inconnu', texte: 'b'),
        isNull,
      );
      expect(
        await PileMessagesNotifiees.remplacer(
            conversationId: 'c-vide', messageId: 'm1', texte: 'b'),
        isNull,
      );
      expect((await PileMessagesNotifiees.lire('c-vide')), isEmpty);
    });

    test('corriger par le même texte ne réécrit rien', () async {
      await PileMessagesNotifiees.empiler(
          conversationId: 'c1', messageId: 'm1', texte: 'idem', expediteur: 'A');
      final pile = await PileMessagesNotifiees.remplacer(
          conversationId: 'c1', messageId: 'm1', texte: 'idem');
      expect(pile, isNotNull);
      expect(pile!.single.texte, 'idem');
    });

    test('sans identifiant de message, on ne corrige rien', () async {
      await PileMessagesNotifiees.empiler(
          conversationId: 'c1', messageId: '', texte: 'a', expediteur: 'A');
      expect(
        await PileMessagesNotifiees.remplacer(
            conversationId: 'c1', messageId: '', texte: 'b'),
        isNull,
      );
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

  group('chaque ligne porte son heure', () {
    test('l’heure ferme la ligne, en 24 h', () {
      // `MessagingStyle` reçoit bien un horodatage par message, mais Android
      // ne le rend PAS dans le volet du téléphone : il ne s'en sert que pour
      // trier. L'en-tête ne porte donc qu'une seule heure, celle du dernier —
      // et dans une pile de six, on ne sait pas de quand datent les cinq
      // autres. D'où l'heure dans le texte.
      expect(texteHorodate(_aujourdhui(9, 5), 'Salut'), 'Salut · 09:05');
      expect(texteHorodate(_aujourdhui(14, 30), 'Coucou'), 'Coucou · 14:30');
    });

    test('un message d’HIER le dit, sinon l’ordre paraît faux', () {
      // La pile garde 24 h : elle traverse minuit. À 00:10, un message de
      // 23:50 et un de 00:05 y sont tous deux, et l'heure seule ferait passer
      // le plus ancien (23:50) pour le plus tardif.
      final nuit = DateTime(2026, 9, 16, 0, 10);
      expect(
        texteHorodate(DateTime(2026, 9, 15, 23, 50), 'avant minuit', maintenant: nuit),
        'avant minuit · hier 23:50',
      );
      expect(
        texteHorodate(DateTime(2026, 9, 16, 0, 5), 'après minuit', maintenant: nuit),
        'après minuit · 00:05',
      );
    });

    test('c’est le JOUR CIVIL qui tranche, pas l’écart de 24 h', () {
      // Un message de vingt minutes peut dater d'hier.
      expect(
        texteHorodate(DateTime(2026, 9, 15, 23, 55), 'a',
            maintenant: DateTime(2026, 9, 16, 0, 15)),
        'a · hier 23:55',
      );
      // Et un message de vingt-trois heures peut dater d'aujourd'hui.
      expect(
        texteHorodate(DateTime(2026, 9, 16, 0, 5), 'b',
            maintenant: DateTime(2026, 9, 16, 23, 5)),
        'b · 00:05',
      );
    });

    test('au-delà d’hier, la date courte', () {
      // Inatteignable avec la fenêtre de 24 h, mais elle peut changer.
      expect(
        texteHorodate(DateTime(2026, 9, 14, 8, 0), 'vieux',
            maintenant: DateTime(2026, 9, 16, 10, 0)),
        'vieux · 14/09 08:00',
      );
    });

    test('minuit et midi ne se confondent pas', () {
      expect(texteHorodate(_aujourdhui(0), 'a'), 'a · 00:00');
      expect(texteHorodate(_aujourdhui(12), 'b'), 'b · 12:00');
    });
  });

  group('le nom de l’expéditeur ne sort pas deux fois', () {
    test('le préfixe posé par le serveur en groupe est retiré', () {
      // Les deux déclencheurs préfixent le corps en groupe
      // (`v_sender_name || ' : ' || v_body`), et `MessagingStyle` affiche
      // l'expéditeur de son côté.
      expect(sansPrefixeExpediteur('Alice : Salut', 'Alice'), 'Salut');
      expect(sansPrefixeExpediteur('Alice: Salut', 'Alice'), 'Salut');
    });

    test('un 1:1 n’est pas touché', () {
      expect(sansPrefixeExpediteur('Salut', 'Alice'), 'Salut');
    });

    test('un texte qui commence par le nom sans séparateur reste entier', () {
      // « Alice a raison » n'est pas un préfixe d'expéditeur.
      expect(sansPrefixeExpediteur('Alice a raison', 'Alice'), 'Alice a raison');
    });

    test('un expéditeur inconnu ne fait rien perdre', () {
      expect(sansPrefixeExpediteur('Bob : Salut', ''), 'Bob : Salut');
    });
  });

  group('câblage', () {
    test('le chemin d’arrière-plan empile, puis pose la bannière', () {
      // Les deux gestes ont été séparés : une édition ne réempile rien, elle
      // corrige une ligne déjà là et repose la MÊME bannière.
      final source = _lire(service);
      final i = source.indexOf('Future<void> _showFallbackMessageNotification(');
      expect(i, greaterThan(-1));
      final corps = source.substring(
          i, source.indexOf('Future<void> _posterBanniereMessagerie(', i));
      expect(corps, contains('PileMessagesNotifiees.empiler('));
      expect(corps, contains('_posterBanniereMessagerie('));
      expect(corps, contains('silencieux: false'));
      // La correction de l'expéditeur en double se fait à l'empilement.
      expect(corps, contains('sansPrefixeExpediteur(body,'));
      expect(corps, contains("expediteurId: data['senderId']"));
    });

    test('la bannière elle-même porte le style, le compteur et l’heure', () {
      final source = _lire(service);
      final i = source.indexOf('Future<void> _posterBanniereMessagerie(');
      expect(i, greaterThan(-1));
      final corps = source.substring(i, source.indexOf('\n}\n', i));
      expect(corps, contains('MessagingStyleInformation('));
      expect(corps, contains('styleInformation: styleMessagerie'));
      expect(corps, contains('number: pile.length'));
      expect(corps, contains('texteHorodate(m.quand, m.texte)'));
      expect(corps, contains('key: m.cleIdentite'));
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

    test('la bannière porte l’heure du MESSAGE, pas celle de la livraison', () {
      final source = _lire(service);
      // Une seule lecture de l'heure, partagée par les deux chemins.
      expect(source, contains('DateTime heureDuMessage(Map<String, dynamic> data)'));
      expect(source, contains("data['sentAt']"));
      // Et elle est AFFICHÉE : ce chemin-ci ne renseignait pas `when`.
      expect(source, contains('when: quand.millisecondsSinceEpoch'));
      expect(source.contains('when: DateTime.now().millisecondsSinceEpoch'), isFalse,
          reason: 'plus aucun `when` sur l’heure de livraison');
    });

    test('la pile s’affiche du plus ancien au plus récent', () {
      // `.take(10)` gardait les dix plus ANCIENNES — celles qu'on veut laisser
      // tomber — et `.reversed` mettait la plus récente en HAUT. Bannière à
      // l'envers, signalée sur appareil.
      final source = _lire(service);
      final i = source.indexOf('_buildMessagingStyle(');
      expect(i, greaterThan(-1));
      final corps = source.substring(i, source.indexOf('String _formatMessagePreview(', i));
      expect(corps.contains('messages.reversed'), isFalse);
      expect(corps.contains('group.notifications.take(10)'), isFalse);
      expect(corps, contains('sublist(group.notifications.length - 10)'));
    });

    test('une correction repose la bannière SANS la faire sonner', () {
      final source = _lire(service);
      final i = source.indexOf('Future<void> _corrigerBanniereApresEdition(');
      expect(i, greaterThan(-1));
      final corps = source.substring(
          i, source.indexOf('Future<void> _posterBanniereMessagerie(', i));
      expect(corps, contains('PileMessagesNotifiees.remplacer('));
      expect(corps, contains('silencieux: true'));
      // Et elle n'en crée jamais : pile absente = on s'arrête.
      expect(corps, contains('if (pile == null || pile.isEmpty) return;'));
      // On ne retire pas la bannière pour la reposer : ça la ferait re-sonner.
      expect(corps.contains('plugin.cancel'), isFalse);
    });

    test('`onlyAlertOnce` suit le caractère silencieux', () {
      final source = _lire(service);
      expect(source, contains('onlyAlertOnce: silencieux'));
    });

    test('une édition chiffrée passe par la copie jetable', () {
      // Corriger une bannière ne doit pas consommer une génération du cliquet,
      // pas plus que l'aperçu.
      final preview = _lire('lib/core/crypto/mls/mls_notification_preview.dart');
      final i = preview.indexOf('static Future<({String cible, String texte})?> edition(');
      expect(i, greaterThan(-1));
      expect(preview.substring(i, i + 400), contains('_dechiffrer(data)'));
      expect(preview, contains('apercuSansEtat('));
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
