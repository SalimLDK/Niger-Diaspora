import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:diaspo_niger/core/utils/realtime_rattrapage.dart';

void main() {
  group('rattrapageAuRejoint', () {
    test('le premier abonnement ne relit pas — l\'appelant vient de le faire', () {
      var relectures = 0;
      final rappel = rattrapageAuRejoint(() => relectures++);

      rappel(RealtimeSubscribeStatus.subscribed, null);

      expect(relectures, 0);
    });

    test('un rejoint après coupure déclenche le rattrapage', () {
      var relectures = 0;
      final rappel = rattrapageAuRejoint(() => relectures++);

      rappel(RealtimeSubscribeStatus.subscribed, null);
      rappel(RealtimeSubscribeStatus.closed, null);
      rappel(RealtimeSubscribeStatus.subscribed, null);

      expect(relectures, 1);
    });

    test(
      'un rejoint sans passage par un échec rattrape quand même',
      () {
        // Le client realtime ne signale pas toujours la coupure : selon la
        // façon dont le socket meurt, on ne voit que le `subscribed` du
        // rejoint. C'est bien un rattrapage qu'il faut, pas un premier
        // chargement — sinon la liste reste figée précisément dans le cas
        // qu'on cherche à couvrir.
        var relectures = 0;
        final rappel = rattrapageAuRejoint(() => relectures++);

        rappel(RealtimeSubscribeStatus.subscribed, null);
        rappel(RealtimeSubscribeStatus.subscribed, null);

        expect(relectures, 1);
      },
    );

    test('chaque reconnexion suivante relit à son tour', () {
      var relectures = 0;
      final rappel = rattrapageAuRejoint(() => relectures++);

      rappel(RealtimeSubscribeStatus.subscribed, null);
      for (var i = 0; i < 3; i++) {
        rappel(RealtimeSubscribeStatus.channelError, 'réseau');
        rappel(RealtimeSubscribeStatus.subscribed, null);
      }

      expect(relectures, 3);
    });

    test('un échec seul ne relit rien — il n\'y a rien à rattraper encore', () {
      var relectures = 0;
      final rappel = rattrapageAuRejoint(() => relectures++);

      rappel(RealtimeSubscribeStatus.timedOut, null);
      rappel(RealtimeSubscribeStatus.channelError, 'boum');

      expect(relectures, 0);
    });

    test(
      'lecture initiale en échec : le premier rejoint charge, lui',
      () {
        // Écran ouvert alors que l'appareil est déjà hors ligne : la lecture
        // initiale a échoué et rien ne la retente. Le premier `subscribed`
        // n'arrive qu'au retour du réseau — c'est la première occasion
        // d'afficher quoi que ce soit, pas un doublon.
        var relectures = 0;
        var enEchec = true;
        final rappel = rattrapageAuRejoint(
          () => relectures++,
          lectureInitialeEnEchec: () => enEchec,
        );

        rappel(RealtimeSubscribeStatus.subscribed, null);

        expect(relectures, 1);
      },
    );

    test(
      'lecture initiale réussie : le premier rejoint ne double pas la requête',
      () {
        var relectures = 0;
        final rappel = rattrapageAuRejoint(
          () => relectures++,
          lectureInitialeEnEchec: () => false,
        );

        rappel(RealtimeSubscribeStatus.subscribed, null);

        expect(relectures, 0);
      },
    );

    test(
      'lecture initiale encore en vol : on ne relit pas — elle finira seule',
      () {
        // Le prédicat dit « en échec », pas « pas encore faite » : un `fetch`
        // plus lent que l'abonnement ne doit pas déclencher une seconde
        // requête à chaque démarrage.
        var relectures = 0;
        var enEchec = false; // rien n'a encore échoué
        final rappel = rattrapageAuRejoint(
          () => relectures++,
          lectureInitialeEnEchec: () => enEchec,
        );

        rappel(RealtimeSubscribeStatus.subscribed, null);
        expect(relectures, 0);

        // …et une coupure plus tard rattrape quand même.
        rappel(RealtimeSubscribeStatus.channelError, 'réseau');
        rappel(RealtimeSubscribeStatus.subscribed, null);
        expect(relectures, 1);
      },
    );

    test('deux canaux gardent leur compte séparément', () {
      var a = 0;
      var b = 0;
      final rappelA = rattrapageAuRejoint(() => a++);
      final rappelB = rattrapageAuRejoint(() => b++);

      rappelA(RealtimeSubscribeStatus.subscribed, null);
      rappelA(RealtimeSubscribeStatus.subscribed, null);
      rappelB(RealtimeSubscribeStatus.subscribed, null);

      expect(a, 1);
      expect(b, 0);
    });
  });
}
