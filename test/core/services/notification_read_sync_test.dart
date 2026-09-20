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
  });

  /// Le marqueur est inutile s'il n'est pas appelé. Ces écrans sont lourds à
  /// monter dans un test (Firebase, Supabase, routeur) ; on vérifie donc le
  /// câblage à la source, comme les bancs voisins.
  group('câblage', () {
    String source(String chemin) => File(chemin).readAsStringSync();

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
      for (final chemin in [
        'lib/features/messages/presentation/screens/conversation_screen.dart',
        'lib/core/services/notification_read_sync.dart',
      ]) {
        expect(source(chemin), isNot(contains("'messageMention'")),
            reason: chemin);
      }
    });
  });
}
