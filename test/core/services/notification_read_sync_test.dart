import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/core/services/notification_read_sync.dart';
import 'package:diaspo_niger/features/notifications/domain/entities/notification_entity.dart';

/// Le filtre PostgREST interpole l'identifiant de la cible : il ne doit
/// accepter que ce qu'un identifiant peut être.
void main() {
  group('NotificationReadSync.targetFilter', () {
    test('uuid Supabase et id Firestore, sous chaque clé', () {
      expect(
        NotificationReadSync.targetFilter(
          'd8888ee4-3017-41a9-a9eb-32bad0c4f10d',
          const ['postId', 'targetId'],
        ),
        'data->>postId.eq.d8888ee4-3017-41a9-a9eb-32bad0c4f10d,'
        'data->>targetId.eq.d8888ee4-3017-41a9-a9eb-32bad0c4f10d',
      );
      expect(
        NotificationReadSync.targetFilter(
          'U64HKfrjM5NwR6HO00XPKo6168z2',
          const ['senderId'],
        ),
        'data->>senderId.eq.U64HKfrjM5NwR6HO00XPKo6168z2',
      );
    });

    test('refuse ce qui changerait le sens du filtre', () {
      for (final id in [
        '',
        'a,is_read.eq.true',
        'a)',
        'a.b',
        'a b',
        'x' * 129,
      ]) {
        expect(
          NotificationReadSync.targetFilter(id, const ['targetId']),
          isNull,
          reason: id,
        );
      }
    });

    test('refuse une clé hors liste, ou aucune clé', () {
      expect(
        NotificationReadSync.targetFilter('abc', const ['user_id']),
        isNull,
      );
      expect(NotificationReadSync.targetFilter('abc', const []), isNull);
    });

    test('accepte receiverId, la clé de friendAccepted', () {
      expect(
        NotificationReadSync.targetFilter('abc', const ['receiverId']),
        'data->>receiverId.eq.abc',
      );
    });
  });

  /// Les familles portent des chaînes, pas des `NotificationType` : les
  /// écrans n'importent pas l'entité de notification, seulement ce service.
  /// Une faute de frappe ne casserait rien — le filtre ne trouverait
  /// simplement jamais de ligne.
  group('familles de types lues à l\'ouverture', () {
    final noms = NotificationType.values.map((t) => t.name).toSet();
    final familles = {
      'fiche de groupe': NotificationReadSync.typesLusParLaFicheDeGroupe,
      'profil': NotificationReadSync.typesLusParLeProfil,
      'mes commandes': NotificationReadSync.typesLusParMesCommandes,
    };

    test('chaque chaîne est le name d\'un NotificationType', () {
      familles.forEach((famille, types) {
        for (final type in types) {
          expect(noms, contains(type), reason: '$famille : « $type »');
        }
      });
    });

    test('aucune famille ne recoupe une autre', () {
      final vus = <String>{};
      familles.forEach((famille, types) {
        for (final type in types) {
          expect(vus.add(type), isTrue, reason: '$famille : « $type » en double');
        }
      });
    });

    test('les types qui appellent un geste n\'y sont pas', () {
      // Accepter/refuser : ouvrir l'écran ne règle rien, et la ligne doit
      // rester tant que la demande est en attente.
      const gestes = {
        'groupInvite',
        'groupJoinRequest',
        'friendRequest',
        // Et la messagerie, qui a sa propre lecture (curseur, RPC).
        'message',
        'messageReaction',
        'messageMention',
        'messageEdited',
      };
      familles.forEach((famille, types) {
        expect(
          types.toSet().intersection(gestes),
          isEmpty,
          reason: famille,
        );
      });
    });

    test('mes commandes couvre tous les types de commande', () {
      // Le routeur de l'écran Notifications et celui des bannières envoient
      // ces huit types-là vers `/marketplace/my-orders`. Un neuvième type
      // `order…` ajouté à l'enum sans passer ici resterait non lu.
      final commandes =
          noms.where((n) => n.startsWith('order') || n == 'newOrder').toSet();
      expect(
        NotificationReadSync.typesLusParMesCommandes.toSet(),
        commandes,
      );
    });

    test('la messagerie : les types de l\'écran écartés, plus les mentions', () {
      // `kTypesHorsEcranNotifications` écarte de l'écran ce qui a déjà sa liste
      // ; `messageMention` s'y ajoute ici, car elle EST affichée mais se lit
      // avec la discussion. Un type de messagerie oublié dans cette liste
      // serait lu par n'importe quel écran dont l'identifiant coïncide.
      final attendus = {
        ...kTypesHorsEcranNotifications.map((t) => t.name),
        'messageMention',
      };
      expect(NotificationReadSync.typesDeLaMessagerie.toSet(), attendus);
      for (final type in NotificationReadSync.typesDeLaMessagerie) {
        expect(noms, contains(type), reason: type);
      }
    });
  });

  /// À l'ARRIVÉE d'une notification, l'écran affiché est-il sa destination ?
  ///
  /// Les chemins sont ceux que rend `emplacementAffiche`. La même table sert à
  /// l'ouverture (`mark…Opened`) : ce banc en tient les lignes.
  group('l\'écran affiché est-il la destination de la notification ?', () {
    bool designe(String chemin, String type, Map<String, dynamic> data) =>
        NotificationReadSync.designeLEcranAffiche(chemin, type: type, data: data);

    test('publication : tout ce qui porte sur CETTE publication', () {
      for (final type in [
        'postCommented',
        'commentReply',
        'mentioned',
        'groupMention',
        'postLiked',
        'postReposted',
        'newPost',
      ]) {
        expect(
          designe('/feed/p1', type, {'postId': 'p1', 'targetId': 'p1'}),
          isTrue,
          reason: type,
        );
      }
    });

    test('publication : une autre, la liste ou un sous-écran ne comptent pas', () {
      const data = {'postId': 'p1', 'targetId': 'p1'};
      expect(designe('/feed/p2', 'postCommented', data), isFalse);
      expect(designe('/feed', 'postCommented', data), isFalse);
      expect(designe('/feed/p1/reposts', 'postCommented', data), isFalse);
      expect(designe('/feed/p1/edit', 'postCommented', data), isFalse);
    });

    test('l\'identifiant peut vivre sous n\'importe laquelle des clés', () {
      for (final data in [
        {'postId': 'p1'},
        {'targetId': 'p1'},
        {'target_id': 'p1'},
      ]) {
        expect(designe('/feed/p1', 'postCommented', data), isTrue, reason: '$data');
      }
      // Et pas sous une clé qui n'en est pas une.
      expect(designe('/feed/p1', 'postCommented', {'senderId': 'p1'}), isFalse);
    });

    test('événement', () {
      expect(designe('/events/e1', 'eventAttendance', {'eventId': 'e1'}), isTrue);
      expect(designe('/events/e1', 'eventReminder', {'targetId': 'e1'}), isTrue);
      expect(designe('/events/e2', 'eventAttendance', {'eventId': 'e1'}), isFalse);
    });

    test('groupe : les annonces, pas ce qui appelle un geste', () {
      for (final type in NotificationReadSync.typesLusParLaFicheDeGroupe) {
        expect(designe('/groups/g1', type, {'groupId': 'g1'}), isTrue, reason: type);
      }
      // Accepter/refuser : la notification doit rester tant que rien n'est fait.
      expect(designe('/groups/g1', 'groupInvite', {'groupId': 'g1'}), isFalse);
      expect(designe('/groups/g1', 'groupJoinRequest', {'groupId': 'g1'}), isFalse);
      // Un `groupId` porte aussi les notifications de message du groupe.
      expect(designe('/groups/g1', 'message', {'groupId': 'g1'}), isFalse);
      // Un sous-écran du groupe n'est pas sa fiche.
      expect(
        designe('/groups/g1/members', 'cityGroupInvite', {'groupId': 'g1'}),
        isFalse,
      );
    });

    test('profil : l\'acceptation, sous receiverId comme sous target_id', () {
      expect(designe('/profile/u1', 'friendAccepted', {'receiverId': 'u1'}), isTrue);
      expect(designe('/profile/u1', 'friendAccepted', {'target_id': 'u1'}), isTrue);
      expect(
        designe('/profile/u1', 'friendRequestAccepted', {'targetId': 'u1'}),
        isTrue,
      );
      // Une demande à traiter appelle un geste, même sur le profil de l'auteur.
      expect(
        designe('/profile/u1', 'friendRequest', {'senderId': 'u1', 'targetId': 'u1'}),
        isFalse,
      );
      expect(designe('/profile/u2', 'friendAccepted', {'receiverId': 'u1'}), isFalse);
    });

    test('mes commandes : toute la famille, sans identifiant', () {
      for (final type in NotificationReadSync.typesLusParMesCommandes) {
        expect(designe('/marketplace/my-orders', type, {}), isTrue, reason: type);
      }
      expect(designe('/marketplace/my-orders', 'paymentFailed', {}), isFalse);
      expect(designe('/marketplace/my-orders', 'postCommented', {}), isFalse);
      expect(designe('/marketplace', 'orderPaid', {}), isFalse);
    });

    test('la messagerie n\'est jamais lue par un autre écran', () {
      // Même identifiant, même clé : `targetId` d'un message est une
      // conversation, et lire une discussion est le travail du curseur.
      for (final type in NotificationReadSync.typesDeLaMessagerie) {
        for (final chemin in ['/feed/x', '/events/x', '/groups/x', '/profile/x']) {
          expect(
            designe(chemin, type, {'targetId': 'x', 'groupId': 'x'}),
            isFalse,
            reason: '$type sur $chemin',
          );
        }
      }
    });

    test('la requête et la barre finale sont tolérées', () {
      const data = {'postId': 'p1'};
      expect(designe('/feed/p1?depuis=notification', 'postCommented', data), isTrue);
      expect(designe('/feed/p1/', 'postCommented', data), isTrue);
    });

    test('un écran qui n\'est la destination de rien', () {
      const data = {'postId': 'p1', 'targetId': 'p1', 'groupId': 'p1'};
      for (final chemin in ['/', '/home', '/notifications', '/messages/p1', '/feed']) {
        expect(designe(chemin, 'postCommented', data), isFalse, reason: chemin);
      }
    });
  });

  /// La REPRISE : au retour au premier plan, l'écran affiché lit ses
  /// notifications comme à son ouverture. Ce que `cibleAffichee` rend est ce
  /// que la requête écrira — la fonction est pure pour qu'on puisse le lire.
  group('ce que la reprise lit : la cible de l\'écran affiché', () {
    test('un écran à identifiant : le filtre sur son objet, et ses types', () {
      final evenement = NotificationReadSync.cibleAffichee('/events/e1');
      expect(
        evenement?.filtre,
        'data->>eventId.eq.e1,data->>targetId.eq.e1,data->>target_id.eq.e1',
      );
      expect(evenement?.types, isNull); // tout type : la table dit `null`

      final groupe = NotificationReadSync.cibleAffichee('/groups/g1');
      expect(groupe?.filtre, contains('data->>groupId.eq.g1'));
      expect(groupe?.types, NotificationReadSync.typesLusParLaFicheDeGroupe);

      final profil = NotificationReadSync.cibleAffichee('/profile/u1');
      expect(profil?.filtre, contains('data->>receiverId.eq.u1'));
      expect(profil?.types, NotificationReadSync.typesLusParLeProfil);
    });

    test('« Mes commandes » : pas de cible, toute la famille', () {
      final c = NotificationReadSync.cibleAffichee('/marketplace/my-orders');
      expect(c, isNotNull);
      expect(c!.filtre, isNull);
      expect(c.types, NotificationReadSync.typesLusParMesCommandes);
    });

    test('la requête et la barre finale n\'y changent rien', () {
      final nu = NotificationReadSync.cibleAffichee('/feed/p1');
      expect(NotificationReadSync.cibleAffichee('/feed/p1?depuis=x')?.filtre, nu?.filtre);
      expect(NotificationReadSync.cibleAffichee('/feed/p1/')?.filtre, nu?.filtre);
    });

    test('un écran qui n\'est la destination de rien : rien à écrire', () {
      for (final chemin in [
        '/',
        '/home',
        '/feed',
        '/notifications',
        '/messages/c1',
        '/groups/g1/members',
        '/feed/p1/reposts',
      ]) {
        expect(NotificationReadSync.cibleAffichee(chemin), isNull, reason: chemin);
      }
    });

    test('un identifiant qui changerait le sens du filtre : rien à écrire', () {
      // L'identifiant est interpolé dans `or=(…)` : une virgule, une
      // parenthèse ou un point n'ont rien à y faire.
      for (final chemin in ['/feed/a,is_read.eq.true', '/feed/a)', '/feed/a.b']) {
        expect(NotificationReadSync.cibleAffichee(chemin), isNull, reason: chemin);
      }
    });
  });

  /// Une push touchée désigne une cible, une conversation, ou — pour une
  /// annonce — un code. Les deux premiers cas existaient ; le test les fige.
  group('ce que désigne une push touchée', () {
    Map<String, dynamic> push(String type, Map<String, String> plus) =>
        {'type': type, ...plus};

    test('un message : toute la discussion', () {
      final c = NotificationReadSync.cibleDeLaPush(
        push('message', {'conversationId': 'c1', 'targetId': 'c1'}),
      );
      expect(c?.id, 'c1');
      expect(c?.keys, ['conversationId']);
      expect(c?.type, 'message');
      expect(c?.annonce, isNull);
    });

    test('un type à cible : son targetId, sous les deux clés', () {
      final c = NotificationReadSync.cibleDeLaPush(
        push('eventAttendance', {'targetId': 'e1'}),
      );
      expect(c?.id, 'e1');
      expect(c?.keys, ['targetId', 'target_id']);
      expect(c?.type, 'eventAttendance');
      expect(c?.annonce, isNull);
    });

    test('une annonce system, sans cible : son code', () {
      // Le cas réel du 2026-09-15 : `targetId` sort à '', `annonce` reste.
      final c = NotificationReadSync.cibleDeLaPush(
        push('system', {'targetId': '', 'annonce': 'maj-1.2.1-chiffrement'}),
      );
      expect(c?.annonce, 'maj-1.2.1-chiffrement');
      expect(c?.id, isNull);
      expect(c?.type, 'system');
    });

    test('une cible l\'emporte sur un code d\'annonce', () {
      final c = NotificationReadSync.cibleDeLaPush(
        push('system', {'targetId': 't1', 'annonce': 'x'}),
      );
      expect(c?.id, 't1');
      expect(c?.annonce, isNull);
    });

    test('ce qui ne désigne rien', () {
      expect(NotificationReadSync.cibleDeLaPush({}), isNull);
      expect(NotificationReadSync.cibleDeLaPush(push('', {})), isNull);
      expect(NotificationReadSync.cibleDeLaPush(push('system', {})), isNull);
      expect(
        NotificationReadSync.cibleDeLaPush(push('system', {'annonce': ''})),
        isNull,
      );
      // Le code d'une annonce n'identifie que les annonces.
      expect(
        NotificationReadSync.cibleDeLaPush(push('eventReminder', {'annonce': 'x'})),
        isNull,
      );
    });
  });

  group('le code d\'une annonce', () {
    test('lettres, chiffres, point, tiret, souligné', () {
      for (final code in ['maj-1.2.1-chiffrement', 'a', 'A_b-1.0', 'x' * 128]) {
        expect(NotificationReadSync.codeDAnnonceSur(code), isTrue, reason: code);
      }
    });

    test('rien qui change le sens d\'un filtre ou d\'une URL', () {
      for (final code in [
        '',
        'a b',
        'a,b',
        'a)',
        "a'b",
        'a=b',
        'a&b',
        'a%20b',
        'é',
        'x' * 129,
      ]) {
        expect(NotificationReadSync.codeDAnnonceSur(code), isFalse, reason: code);
      }
    });
  });

  /// Le marqueur est inutile s'il n'est pas appelé. Ces écrans sont lourds à
  /// monter dans un test (Firebase, Supabase, routeur) ; on vérifie donc le
  /// câblage à la source, comme les bancs voisins.
  group('câblage', () {
    String source(String chemin) => File(chemin).readAsStringSync();

    test('la publication et l\'événement marquent par la même table', () {
      // Les clés ne sont plus recopiées dans les écrans : ce sont celles de la
      // table que lit aussi l'arrivée d'une notification.
      expect(
        source(
          'lib/features/feed/presentation/screens/post_detail_screen.dart',
        ),
        contains('NotificationReadSync.markPostOpened(widget.postId)'),
      );
      expect(
        source(
          'lib/features/events/presentation/screens/event_detail_screen.dart',
        ),
        contains('NotificationReadSync.markEventOpened(widget.eventId)'),
      );
    });

    test('la fiche de groupe, le profil et « Mes commandes » marquent', () {
      expect(
        source(
          'lib/features/groups/presentation/screens/group_detail_screen.dart',
        ),
        contains('NotificationReadSync.markGroupOpened(widget.groupId)'),
      );
      expect(
        source(
          'lib/features/profile/presentation/screens/profile_view_screen.dart',
        ),
        contains('NotificationReadSync.markProfileOpened(widget.userId)'),
      );
      expect(
        source(
          'lib/features/marketplace/presentation/screens/my_orders_screen.dart',
        ),
        contains('NotificationReadSync.markOrdersOpened()'),
      );
    });

    test('la fiche de notification se marque lue à l\'ouverture', () {
      final src = source(
        'lib/features/notifications/presentation/screens/'
        'notification_detail_screen.dart',
      );
      // Le point d'accroche est posé dans le corps affiché…
      expect(src, contains('_MarqueLueALOuverture(notification: notification)'));
      // …et il marque dans `initState`, une seule fois par ouverture.
      final marque = RegExp(
        r'_MarqueLueALOuvertureState[\s\S]*?void initState\(\)[\s\S]*?'
        r'\.markAsRead\(widget\.notification\.id\)',
      );
      expect(marque.hasMatch(src), isTrue);
    });

    test('les mentions d\'une discussion ne sont plus marquées côté client', () {
      // Une seule source : `marquer_lus_jusqua` et `mark_messages_as_read`
      // (20260919120000), qui joignent le message par son identifiant. Le
      // marquage client d'avant devinait sur une date, avec 2 s de marge, et
      // ne couvrait pas l'action « Marquer comme lu » de la bannière. La garde
      // de cette source unique est `mentions_lues_par_le_serveur_test.dart`.
      expect(
        source(
          'lib/features/messages/presentation/screens/conversation_screen.dart',
        ),
        isNot(contains("'messageMention'")),
      );
      // `NotificationReadSync` cite bien `messageMention`, mais dans
      // `typesDeLaMessagerie`, la liste de ce qu'il ne marque JAMAIS. Qu'aucune
      // famille lue à l'ouverture ne la contienne est tenu plus haut (« les
      // types qui appellent un geste n'y sont pas »).
    });
  });
}
