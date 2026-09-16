import 'dart:io';

import 'package:diaspo_niger/features/groups/data/models/group_model.dart';
import 'package:diaspo_niger/features/messages/domain/entities/message_entity.dart';
import 'package:diaspo_niger/features/messages/presentation/providers/message_provider.dart'
    show sansMessagesAvantArrivee;
import 'package:flutter_test/flutter_test.dart';

/// Ce que ces tests protègent
/// --------------------------
/// Dans un groupe privé, un nouveau membre ne voit pas ce qui a été dit avant
/// son arrivée (`_setupPrivateGroupFilter`, `conversation_screen.dart`). La
/// règle existait dans le code ; elle ne s'appliquait **jamais** : la date
/// d'arrivée vit dans `group_members.joined_at`, et la chaîne était coupée en
/// trois endroits —
///
/// 1. `_membershipFor` ne demandait que `group_id, user_id, role` ;
/// 2. `GroupModel` n'avait pas de champ pour la recevoir ;
/// 3. `toEntity` ne pouvait donc rien transmettre à `GroupEntity.memberJoinedAt`.
///
/// Seul l'ancien datasource Firestore l'alimentait. Depuis le passage à
/// Supabase, la carte était toujours vide.
///
/// Mesuré en production le 2026-09-16 avant de rebrancher : dates fiables
/// (aucun membre n'a écrit avant sa date d'arrivée, aucune arrivée antérieure
/// à la création du groupe, une date distincte par membre), et lisibles par un
/// membre ordinaire sous le rôle `authenticated`. Effet réel : dans le groupe
/// privé `2b24986f`, le membre arrivé le 11/09 cesse de voir 6 messages.
///
/// Le filtre lui-même n'était passé qu'à la page réseau : cache, fusion MLS,
/// pagination et temps réel l'ignoraient. Rebrancher la date sans le
/// centraliser faisait surgir ces messages du cache à chaque ouverture.
String _lire(String chemin) =>
    File(chemin).readAsStringSync().replaceAll('\r\n', '\n');

MessageEntity _m(String id, DateTime quand) => MessageEntity(
      id: id,
      senderId: 'x',
      senderName: 'x',
      content: id,
      type: MessageType.text,
      status: MessageStatus.sent,
      createdAt: quand,
    );

void main() {
  group('GroupModel porte la date d\'arrivée jusqu\'à l\'entité', () {
    test('lue telle que PostgREST la rend, et transmise', () {
      final modele = GroupModel.fromJson({
        'id': 'g',
        'name': 'Groupe',
        'description': '',
        'creatorId': 'a',
        'memberJoinedAt': {
          'a': '2026-08-06T07:21:27.333091+00:00',
          'b': '2026-09-11T12:23:56.176632+00:00',
        },
      });

      final entite = modele.toEntity();
      expect(entite.memberJoinedAt.keys, containsAll(['a', 'b']));
      expect(
        entite.memberJoinedAt['b']!.toUtc(),
        DateTime.utc(2026, 9, 11, 12, 23, 56, 176, 632),
      );
    });

    test('absente ou illisible : carte vide, sans lever', () {
      expect(
        GroupModel.fromJson({'id': 'g', 'name': 'n', 'description': '', 'creatorId': 'a'})
            .memberJoinedAt,
        isEmpty,
      );
      final partielle = GroupModel.fromJson({
        'id': 'g',
        'name': 'n',
        'description': '',
        'creatorId': 'a',
        'memberJoinedAt': {'a': 'pas une date', 'b': '2026-09-11T12:23:56Z'},
      });
      expect(partielle.memberJoinedAt.keys, ['b']);
    });

    test('elle survit à fromEntity et à copyWith', () {
      final modele = GroupModel.fromJson({
        'id': 'g',
        'name': 'n',
        'description': '',
        'creatorId': 'a',
        'memberJoinedAt': {'a': '2026-09-11T12:23:56Z'},
      });
      expect(GroupModel.fromEntity(modele.toEntity()).memberJoinedAt, modele.memberJoinedAt);
      expect(modele.copyWith(name: 'autre').memberJoinedAt, modele.memberJoinedAt);
    });

    test('toJson ne l\'envoie pas à Firestore', () {
      // Son seul appelant écrit le document du groupe, où la carte vit en
      // Timestamp : l'y envoyer en chaînes l'écraserait.
      final modele = GroupModel.fromJson({
        'id': 'g',
        'name': 'n',
        'description': '',
        'creatorId': 'a',
        'memberJoinedAt': {'a': '2026-09-11T12:23:56Z'},
      });
      expect(modele.toJson().containsKey('memberJoinedAt'), isFalse);
    });
  });

  group('le datasource Supabase lit joined_at', () {
    late String source;
    setUpAll(() => source = _lire(
          'lib/features/groups/data/datasources/group_supabase_datasource.dart',
        ));

    test('la requête d\'appartenance demande la colonne', () {
      expect(source, contains(".select('group_id, user_id, role, joined_at')"));
    });

    test('la ligne décodée la porte, sous le nom que le modèle lit', () {
      expect(source, contains("patched['member_joined_at'] = entry.joinedAt;"));
      expect(source, contains("'memberJoinedAt': row['member_joined_at']"));
    });
  });

  group('sansMessagesAvantArrivee', () {
    final arrivee = DateTime.utc(2026, 9, 11, 12);

    test('rien de ce qui précède l\'arrivée', () {
      final fil = [
        _m('avant', arrivee.subtract(const Duration(minutes: 1))),
        _m('pile', arrivee),
        _m('apres', arrivee.add(const Duration(minutes: 1))),
      ];
      // Borne stricte, comme le filtre réseau d'origine (`isAfter`).
      expect(sansMessagesAvantArrivee(fil, arrivee).map((m) => m.id), ['apres']);
    });

    test('sans borne, la liste passe telle quelle', () {
      final fil = [_m('a', arrivee)];
      expect(identical(sansMessagesAvantArrivee(fil, null), fil), isTrue);
    });

    test('rien à retirer : même liste, pas de copie', () {
      final fil = [_m('a', arrivee.add(const Duration(hours: 1)))];
      expect(identical(sansMessagesAvantArrivee(fil, arrivee), fil), isTrue);
    });
  });

  group('la borne tient sur tous les chemins du fil', () {
    late String source;
    setUpAll(() => source = _lire(
          'lib/features/messages/presentation/providers/message_provider.dart',
        ));

    test('appliquée dans le setter de state, pas écriture par écriture', () {
      final debut = source.indexOf('set state(MessagePaginationState valeur) {');
      expect(debut, isNot(-1), reason: 'le point unique a disparu');
      final corps = source.substring(debut, source.indexOf('\n  }\n', debut));
      expect(corps, contains('sansMessagesAvantArrivee(valeur.messages, borne)'));
      expect(corps, contains('final borne = _filterAfterDate;'));
    });

    test('poser la date refiltre aussitôt ce qui est déjà affiché', () {
      final debut = source.indexOf('void setFilterDate(DateTime? date) {');
      final corps = source.substring(debut, source.indexOf('\n  }\n', debut));
      expect(corps.indexOf('state = state;'), lessThan(corps.indexOf('loadInitial();')));
    });
  });
}
