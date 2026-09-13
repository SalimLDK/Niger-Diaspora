import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/core/services/notification_read_sync.dart';

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
  });
}
