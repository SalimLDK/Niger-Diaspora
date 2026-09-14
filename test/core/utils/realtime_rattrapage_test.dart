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
