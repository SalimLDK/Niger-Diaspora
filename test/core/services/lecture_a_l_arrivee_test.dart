import 'dart:io';

import 'package:diaspo_niger/core/services/lecture_a_l_arrivee.dart';
import 'package:flutter_test/flutter_test.dart';

/// Une notification qui ARRIVE pendant que son écran est ouvert est lue — et
/// seulement dans ce cas.
///
/// Le risque n'est pas de ne pas la marquer (c'était le comportement d'avant :
/// elle attendait la prochaine ouverture) mais de la marquer À TORT : une
/// notification arrivée application en arrière-plan, ou pour un autre écran,
/// disparaîtrait sans que personne l'ait vue. Ce banc tient donc autant les
/// refus que l'acceptation — et, pour chaque refus, SA raison : un garde qui
/// refuse pour une autre raison que celle qu'on croit tester ne prouve rien.
void main() {
  late List<String> marquees;
  late List<String> traces;
  late bool premierPlan;
  late String? ici;
  late Object? panne;
  late bool ecriture;
  late List<String> ecransMarques;
  late bool? resultatEcran;

  LectureALArrivee lecteur() => LectureALArrivee(
    emplacement: () => ici,
    auPremierPlan: () => premierPlan,
    marquer: (id) async {
      if (panne != null) throw panne!;
      marquees.add(id);
      return ecriture;
    },
    marquerEcran: (emplacement) async {
      if (panne != null) throw panne!;
      ecransMarques.add(emplacement);
      return resultatEcran;
    },
    trace: traces.add,
  );

  Map<String, dynamic> ligne({
    String id = 'n1',
    String type = 'postCommented',
    Object? data = const {'postId': 'p1', 'targetId': 'p1'},
    bool? lue,
  }) => {
    'id': id,
    'type': type,
    'data': data,
    if (lue != null) 'is_read': lue,
  };

  setUp(() {
    marquees = [];
    traces = [];
    premierPlan = true;
    ici = '/feed/p1';
    panne = null;
    ecriture = true;
    ecransMarques = [];
    resultatEcran = true;
  });

  group('elle est lue', () {
    test('au premier plan, sur l\'écran de sa cible', () async {
      expect(await lecteur().surInsertion(ligne()), isTrue);
      expect(marquees, ['n1']);
      expect(traces.single, contains('postCommented sur /feed/… — marquée lue'));
    });

    test('quel que soit l\'écran destinataire', () async {
      ici = '/events/e1';
      final r = await lecteur().surInsertion(
        ligne(type: 'eventAttendance', data: {'eventId': 'e1'}),
      );
      expect(r, isTrue);

      ici = '/marketplace/my-orders';
      final s = await lecteur().surInsertion(
        ligne(id: 'n2', type: 'orderPaid', data: const {}),
      );
      expect(s, isTrue);
      expect(marquees, ['n1', 'n2']);
    });

    test('chaque arrivée est jugée à SON moment', () async {
      final l = lecteur();
      expect(await l.surInsertion(ligne(id: 'a')), isTrue);
      ici = '/home'; // la personne est partie
      expect(await l.surInsertion(ligne(id: 'b')), isFalse);
      ici = '/feed/p1'; // et revenue
      expect(await l.surInsertion(ligne(id: 'c')), isTrue);
      expect(marquees, ['a', 'c']);
    });
  });

  group('elle n\'est PAS lue — et pour la bonne raison', () {
    test('application en arrière-plan ou écran éteint', () async {
      // Personne n'a rien vu : la marquer lue la ferait disparaître.
      premierPlan = false;
      expect(await lecteur().surInsertion(ligne()), isFalse);
      expect(marquees, isEmpty);
      expect(traces.single, contains('pas au premier plan'));
    });

    test('un autre écran est affiché', () async {
      ici = '/feed/p2';
      expect(await lecteur().surInsertion(ligne()), isFalse);
      ici = '/home';
      expect(await lecteur().surInsertion(ligne()), isFalse);
      expect(marquees, isEmpty);
      expect(traces, hasLength(2));
      for (final t in traces) {
        expect(t, contains('pas la destination de l\'écran'));
      }
    });

    test('l\'écran de sa cible n\'est qu\'ouvert dessous', () async {
      // `emplacement` rend la page du DESSUS : par-dessus la publication, un
      // profil est affiché — la notification de la publication n'est pas vue.
      ici = '/profile/u9';
      expect(await lecteur().surInsertion(ligne()), isFalse);
      expect(marquees, isEmpty);
      expect(traces.single, contains('pas la destination'));
    });

    test('on ne sait pas quel écran est affiché', () async {
      ici = null;
      expect(await lecteur().surInsertion(ligne()), isFalse);
      expect(marquees, isEmpty);
      expect(traces.single, contains('écran affiché inconnu'));
    });

    test('la messagerie, même sur un écran de même identifiant', () async {
      for (final type in [
        'message',
        'messageReaction',
        'messageMention',
        'messageEdited',
      ]) {
        final r = await lecteur().surInsertion(
          ligne(type: type, data: {'targetId': 'p1', 'conversationId': 'p1'}),
        );
        expect(r, isFalse, reason: type);
      }
      expect(marquees, isEmpty);
      expect(traces, hasLength(4));
      for (final t in traces) {
        expect(t, contains('pas la destination'));
      }
    });

    test('ce qui appelle un geste', () async {
      ici = '/groups/g1';
      final r = await lecteur().surInsertion(
        ligne(type: 'groupInvite', data: {'groupId': 'g1'}),
      );
      expect(r, isFalse);
      expect(marquees, isEmpty);
      expect(traces.single, contains('groupInvite sur /groups/…'));
    });

    test('elle est déjà lue : rien à écrire', () async {
      expect(await lecteur().surInsertion(ligne(lue: true)), isFalse);
      expect(marquees, isEmpty);
      expect(traces.single, contains('déjà lue'));
    });

    test('une ligne incomplète ne plante pas', () async {
      final l = lecteur();
      final incompletes = <Map<String, dynamic>>[
        {},
        {'id': 'n1'},
        {'type': 'postCommented'},
        {'id': '', 'type': 'postCommented'},
        {'id': 'n1', 'type': ''},
      ];
      for (final incomplete in incompletes) {
        expect(await l.surInsertion(incomplete), isFalse, reason: '$incomplete');
      }
      expect(marquees, isEmpty);
      expect(traces, hasLength(incompletes.length));
      for (final t in traces) {
        expect(t, contains('incomplète'));
      }
    });

    test('`data` absent, nul ou d\'une forme inattendue : traité comme vide', () async {
      final l = lecteur();
      for (final data in <Object?>[null, 'pas une carte', 42]) {
        final r = await l.surInsertion(
          {'id': 'n1', 'type': 'postCommented', 'data': data},
        );
        expect(r, isFalse, reason: '$data');
      }
      expect(await l.surInsertion({'id': 'n1', 'type': 'postCommented'}), isFalse);
      expect(marquees, isEmpty);
      for (final t in traces) {
        expect(t, contains('pas la destination'));
      }
    });
  });

  group('une écriture qui échoue ne se dit pas réussie', () {
    test('elle lève', () async {
      panne = StateError('réseau');
      expect(await lecteur().surInsertion(ligne()), isFalse);
      expect(traces.single, contains('erreur inattendue'));
    });

    test('elle n\'a pas abouti (`NotificationReadSync` avale ses erreurs)',
        () async {
      // Sans ce cas, le verdict dirait « marquée lue » d'une ligne que la base
      // n'a jamais reçue — au moment précis où la trace sert à comprendre.
      ecriture = false;
      expect(await lecteur().surInsertion(ligne()), isFalse);
      expect(marquees, ['n1']); // elle a bien été tentée
      expect(traces.single, contains('ÉCHEC de l\'écriture'));
      expect(traces.single, isNot(contains('marquée lue')));
    });
  });

  group('un écouteur de canal ne lève jamais', () {
    test('l\'emplacement lève', () async {
      final l = LectureALArrivee(
        emplacement: () => throw StateError('routeur'),
        auPremierPlan: () => true,
        marquer: (_) async => true,
        trace: traces.add,
      );
      expect(await l.surInsertion(ligne()), isFalse);
      expect(traces.single, contains('erreur inattendue'));
    });

    test('le premier plan lève', () async {
      final l = LectureALArrivee(
        emplacement: () => ici,
        auPremierPlan: () => throw StateError('pas de binding'),
        marquer: (_) async => true,
        trace: traces.add,
      );
      expect(await l.surInsertion(ligne()), isFalse);
      expect(traces.single, contains('erreur inattendue'));
    });
  });

  /// Ce qui est arrivé application en arrière-plan n'a pas été jugé à l'arrivée.
  /// Au retour, l'écran affiché lit ses notifications comme à son ouverture.
  group('la reprise', () {
    test('sur l\'écran d\'une destination, au premier plan : lues', () async {
      ici = '/events/e1';
      expect(await lecteur().surReprise(), isTrue);
      expect(ecransMarques, ['/events/e1']);
      expect(
        traces.single,
        contains('reprise sur /events/… — notifications de l\'écran marquées lues'),
      );
    });

    test('pas au premier plan : rien', () async {
      premierPlan = false;
      expect(await lecteur().surReprise(), isFalse);
      expect(ecransMarques, isEmpty);
      expect(traces.single, contains('pas au premier plan'));
    });

    test('écran affiché inconnu : rien', () async {
      ici = null;
      expect(await lecteur().surReprise(), isFalse);
      expect(ecransMarques, isEmpty);
      expect(traces.single, contains('écran affiché inconnu'));
    });

    test('un écran qui n\'est la destination de rien', () async {
      // `marquerEcran` rend `null` : rien n'a été écrit, et la trace le dit.
      ici = '/home';
      resultatEcran = null;
      expect(await lecteur().surReprise(), isFalse);
      expect(traces.single, contains('reprise sur /home — ignorée'));
      expect(traces.single, contains('destination d\'aucune notification'));
    });

    test('une écriture qui n\'a pas abouti ne se dit pas réussie', () async {
      resultatEcran = false;
      expect(await lecteur().surReprise(), isFalse);
      expect(traces.single, contains('ÉCHEC de l\'écriture'));
      expect(traces.single, isNot(contains('marquées lues')));
    });

    test('elle ne lève jamais', () async {
      panne = StateError('réseau');
      expect(await lecteur().surReprise(), isFalse);
      expect(traces.single, contains('erreur inattendue'));
    });

    test('la trace ne porte aucun identifiant', () async {
      ici = '/profile/U64HKfrjM5NwR6HO00XPKo6168z2';
      await lecteur().surReprise();
      expect(traces.single, isNot(contains('U64HKfrj')));
      expect(traces.single, contains('reprise sur /profile/…'));
    });
  });

  /// Un garde silencieux qui refuse ne laisse aucune trace : c'est ce qui a
  /// coûté trois builds le 2026-09-16 (un garde de visibilité, toujours faux
  /// sur appareil, sans une ligne de journal). Chaque arrivée dit donc ce
  /// qu'elle a décidé — sans y mettre d'identifiant.
  group('la trace', () {
    test('une ligne par arrivée, quel que soit le verdict', () async {
      final l = lecteur();
      await l.surInsertion(ligne(id: 'a')); // lue
      premierPlan = false;
      await l.surInsertion(ligne(id: 'b')); // arrière-plan
      premierPlan = true;
      ici = null;
      await l.surInsertion(ligne(id: 'c')); // inconnu
      ici = '/home';
      await l.surInsertion(ligne(id: 'd')); // autre écran
      await l.surInsertion(ligne(id: 'e', lue: true)); // déjà lue
      await l.surInsertion({}); // incomplète
      expect(traces, hasLength(6));
    });

    test('ne porte ni identifiant de notification, ni de cible, ni de compte',
        () async {
      ici = '/profile/U64HKfrjM5NwR6HO00XPKo6168z2';
      final r = await lecteur().surInsertion(
        ligne(
          id: 'aaaaaaaa-1111-2222-3333-bbbbbbbbbbbb',
          type: 'friendAccepted',
          data: {'receiverId': 'U64HKfrjM5NwR6HO00XPKo6168z2'},
        ),
      );
      expect(r, isTrue);
      expect(traces.single, isNot(contains('U64HKfrj')));
      expect(traces.single, isNot(contains('aaaaaaaa')));
      expect(traces.single, contains('friendAccepted sur /profile/… — marquée lue'));
    });

    test('la forme de l\'écran : un segment, deux segments, la racine', () async {
      for (final (chemin, forme) in [
        ('/home', '/home'),
        ('/feed/p1', '/feed/…'),
        ('/marketplace/my-orders', '/marketplace/…'),
        ('/', '/'),
        ('/feed/p1?depuis=x', '/feed/…'),
      ]) {
        traces.clear();
        ici = chemin;
        await lecteur().surInsertion(ligne(type: 'newPost'));
        expect(traces.single, contains('newPost sur $forme —'), reason: chemin);
      }
    });
  });

  /// Le branchement au temps réel n'est pas montable dans un test (Supabase,
  /// Firebase, cycle de vie) : ce qui décide de la sécurité du dispositif est
  /// donc tenu à la source.
  group('câblage', () {
    String source(String chemin) => File(chemin).readAsStringSync();

    test('surveillé à la racine, sinon le canal ne s\'ouvre jamais', () {
      expect(
        source('lib/app.dart'),
        contains('ref.watch(lectureALArriveeProvider)'),
      );
    });

    test('le premier plan est STRICT, et l\'uid est observé', () {
      final src = source('lib/core/providers/lecture_a_l_arrivee_provider.dart');
      // `inactive` (volet système, permission) et `paused` (écran éteint) ne
      // sont pas un regard.
      expect(src, contains('lifecycleState == AppLifecycleState.resumed'));
      // Lu à la construction, l'uid se figerait à `null` au démarrage à froid.
      expect(src, contains('ref.watch(uidFirebaseProvider)'));
      // L'emplacement est celui de la page du DESSUS, pas `currentConfiguration.uri`.
      expect(src, contains('emplacementAffiche('));
      expect(src, isNot(contains('currentConfiguration.uri')));
    });

    test('le canal n\'écoute que les insertions du compte', () {
      final src = source('lib/core/providers/lecture_a_l_arrivee_provider.dart');
      expect(src, contains('PostgresChangeEvent.insert'));
      expect(src, contains("column: 'user_id'"));
      // Une session lisible avant de s'abonner : en `anon`, la RLS ne livre rien.
      expect(src, contains('ensureReadableSession()'));
    });

    test('le retour au premier plan déclenche la reprise, et se désinscrit', () {
      final src = source('lib/core/providers/lecture_a_l_arrivee_provider.dart');
      expect(src, contains('WidgetsBinding.instance.addObserver(reprise)'));
      expect(src, contains('WidgetsBinding.instance.removeObserver(reprise)'));
      expect(src, contains('lecteur.surReprise()'));
      // Seulement au retour au premier plan, pas à chaque changement d'état.
      expect(src, contains('if (state == AppLifecycleState.resumed)'));
    });

    test('une session illisible ne laisse pas un canal muet', () {
      final src = source('lib/core/providers/lecture_a_l_arrivee_provider.dart');
      // Le résultat est LU, et son échec replanifie au lieu de s'abonner quand
      // même : un canal ouvert en `anon` se dit `subscribed` et ne livre rien.
      expect(src, contains('final prete = await'));
      expect(src, contains('if (!prete)'));
    });
  });
}
