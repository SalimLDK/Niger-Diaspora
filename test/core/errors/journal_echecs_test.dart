import 'package:flutter_test/flutter_test.dart';
import 'package:diaspo_niger/core/errors/journal_echecs.dart';
import 'package:diaspo_niger/core/errors/message_erreur.dart';

/// Ce qui part dans Crashlytics quand un écran annonce un échec.
///
/// Deux choses seulement méritent d'être figées ici, et aucune ne demande
/// Firebase : ce que le message laisse passer, et à quelle fréquence il part.
void main() {
  setUp(reinitialiserJournalEchecs);
  tearDown(() => brancherObservateurEchec(null));

  group('caviardage', () {
    test('un uid Firebase ne sort pas', () {
      // Le message réel d'un refus Firestore porte le chemin du document,
      // donc l'uid du compte.
      const brut =
          '[cloud_firestore/permission-denied] ... '
          'users/U64HKfrjM5NwR6HO00XPKo6168z2/friends/DgHD6guYAwVepbUmIAt9P2mJeQ52';
      final propre = caviarder(brut);

      expect(propre, isNot(contains('U64HKfrjM5NwR6HO00XPKo6168z2')));
      expect(propre, isNot(contains('DgHD6guYAwVepbUmIAt9P2mJeQ52')));
      // La FORME reste : c'est elle qui sert au diagnostic.
      expect(propre, contains('users/<ID>/friends/<ID>'));
      expect(propre, contains('permission-denied'));
    });

    test('le projet Supabase et l\'uuid ne sortent pas', () {
      const brut =
          'ClientException with SocketException: Failed host lookup: '
          "'zyrfkcjjrhddpfxcgezo.supabase.co', "
          'uri=https://zyrfkcjjrhddpfxcgezo.supabase.co/rest/v1/events'
          '?id=eq.fea8bc43-1c4e-4f0a-9d21-3b8e5c7a0f11';
      final propre = caviarder(brut);

      expect(propre, isNot(contains('zyrfkcjjrhddpfxcgezo')));
      expect(propre, isNot(contains('fea8bc43-1c4e-4f0a-9d21-3b8e5c7a0f11')));
      expect(propre, contains('Failed host lookup'));
      expect(propre, contains('/rest/v1/events'));
    });

    test('une adresse e-mail et un JWT ne sortent pas', () {
      final propre = caviarder(
        'auth: test.diaspo@example.com jeton=eyJhbGciOi.eyJzdWIiOjEyMzQ1.QWxsRw',
      );
      expect(propre, isNot(contains('@example.com')));
      expect(propre, contains('<EMAIL>'));
      expect(propre, contains('<JWT>'));
    });

    test('un message court et anodin traverse intact', () {
      expect(caviarder('42501 permission denied for table friends'),
          '42501 permission denied for table friends');
    });

    test('un message géant est tronqué', () {
      expect(caviarder('x' * 900).length, lessThanOrEqualTo(401));
    });
  });

  group('dedoublonnage', () {
    test('la même panne ne part qu\'une fois dans la fenêtre', () {
      final t0 = DateTime(2026, 9, 14, 12);

      expect(aSignaler('droits|ServerFailure|refus', t0), isTrue);
      expect(aSignaler('droits|ServerFailure|refus', t0), isFalse);
      expect(
        aSignaler('droits|ServerFailure|refus',
            t0.add(fenetreDeDoublon - const Duration(seconds: 1))),
        isFalse,
      );
      expect(
        aSignaler('droits|ServerFailure|refus',
            t0.add(fenetreDeDoublon + const Duration(seconds: 1))),
        isTrue,
        reason: 'passé la fenêtre, on veut revoir la panne — c\'est son '
            'volume qui dit si elle empire',
      );
    });

    test('deux pannes différentes partent toutes les deux', () {
      final t0 = DateTime(2026, 9, 14, 12);
      expect(aSignaler('droits|ServerFailure|refus', t0), isTrue);
      expect(aSignaler('reseau|ServerFailure|coupure', t0), isTrue);
    });
  });

  group('branchement', () {
    test('afficher un message prévient l\'observateur, avec sa famille', () {
      final vues = <FamilleEchec>[];
      brancherObservateurEchec((_, famille) => vues.add(famille));

      messageErreurUsager('SocketException: Failed host lookup');
      messageErreurUsager('42501 permission denied');
      messageErreurUsager('quelque chose d\'autre');

      expect(vues, [
        FamilleEchec.reseau,
        FamilleEchec.droits,
        FamilleEchec.autre,
      ]);
    });

    test('un observateur qui lève n\'empêche pas le message', () {
      brancherObservateurEchec((_, __) => throw StateError('boum'));

      // L'usager passe avant la télémétrie : le message doit sortir quand même.
      expect(
        messageErreurUsager('42501 permission denied'),
        "Vous n'avez pas les droits nécessaires pour cette action.",
      );
    });
  });
}
