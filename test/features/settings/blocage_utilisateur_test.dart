// Ce que le blocage a le droit d'écrire, et rien de plus.
//
// Le lot était atomique : un seul refus annulait tout. Il touchait deux
// documents `users` en plus de l'entrée qu'il devait poser, et chacun le
// condamnait à lui seul —
//
//   - `update(users/{moi})` sur un document ABSENT échoue en `NOT_FOUND`,
//     indépendamment des règles ;
//   - `set(merge)` sur `users/{cible}` absent est une CRÉATION, que
//     `users/{userId}` n'autorise qu'à son propriétaire.
//
// Plus rien ne créant de documents `users` Firestore depuis la migration vers
// Supabase, ils sont absents pour la quasi-totalité des comptes : bloquer
// quelqu'un n'écrivait donc rien, nulle part. Et le miroir Supabase étant
// appelé APRÈS `commit()`, la ligne `public.blocked_users` — celle que lisent
// les policies du fil — n'était jamais posée non plus.
//
// Ce test fige donc la liste exacte des documents touchés, et l'indépendance
// des deux moitiés. Le pendant côté règles — ce que Firestore accepte
// réellement — est `tools/rules_tests/blocage_utilisateur.mjs` ; celui-ci n'a
// pas besoin d'émulateur.
//
// Même défaut, même forme que
// `test/features/friends/acceptation_demande_ami_test.dart`.

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diaspo_niger/core/errors/exceptions.dart';
import 'package:diaspo_niger/features/settings/data/datasources/blocked_users_datasource.dart';

const moi = 'uid_bloqueur_M';
const cible = 'uid_bloque_C';

/// Enregistre les appels du miroir Supabase, et peut les faire échouer.
///
/// Le vrai miroir ([refleterBlocageDansSupabase]) touche `Supabase.instance`,
/// absent d'un test unitaire — d'où la couture par constructeur.
class MiroirEspion {
  MiroirEspion({this.echec});

  /// Cause rendue par le miroir ; `null` = succès.
  final Object? echec;
  final appels = <({String bloqueur, String bloque, bool bloquer})>[];

  Future<Object?> call({
    required String currentUserId,
    required String targetUserId,
    required bool bloquer,
  }) async {
    appels.add((
      bloqueur: currentUserId,
      bloque: targetUserId,
      bloquer: bloquer,
    ));
    return echec;
  }
}

BlockedUsersDataSourceImpl source(FakeFirebaseFirestore base, MiroirEspion m) =>
    BlockedUsersDataSourceImpl(firestore: base, miroir: m.call);

Future<bool> profilExiste(FakeFirebaseFirestore base, String uid) async =>
    (await base.collection('users').doc(uid).get()).exists;

Future<bool> entreeExiste(FakeFirebaseFirestore base) async =>
    (await base
            .collection('users')
            .doc(moi)
            .collection('blocked_users')
            .doc(cible)
            .get())
        .exists;

void main() {
  group('blockUser', () {
    test('ne touche AUCUN document `users` — ni le mien, ni celui de la cible', () async {
      final base = FakeFirebaseFirestore();
      final miroir = MiroirEspion();

      await source(base, miroir).blockUser(moi, cible, 'Fatima', null);

      // C'est la régression à empêcher. Le premier `update` échouait en
      // `NOT_FOUND` sur mon propre profil absent ; le second créait celui de
      // la cible, ce que les règles refusent à juste titre.
      expect(
        await profilExiste(base, moi),
        isFalse,
        reason:
            'mon profil ne doit pas être créé par le blocage — '
            '`blockedUserIds` n\'est lu par personne',
      );
      expect(
        await profilExiste(base, cible),
        isFalse,
        reason:
            'celui de la cible non plus : le sens inverse passe par '
            '`public.blocked_users`, pas par `blockedByUserIds`',
      );
    });

    test('écrit l\'entrée que l\'app lit, et la reflète dans Supabase', () async {
      final base = FakeFirebaseFirestore();
      final miroir = MiroirEspion();

      await source(base, miroir).blockUser(
        moi,
        cible,
        'Fatima',
        'https://exemple.test/f.jpg',
      );

      // La sous-collection est la seule source de « qui j'ai bloqué » :
      // `getBlockedUsers` la lit, et c'est elle qui alimente
      // `blockedUsersProvider`, donc les Réglages et les filtres client.
      final entree =
          await base
              .collection('users')
              .doc(moi)
              .collection('blocked_users')
              .doc(cible)
              .get();
      expect(entree.exists, isTrue);
      expect(entree.data()!['displayName'], 'Fatima');
      expect(entree.data()!['photoUrl'], 'https://exemple.test/f.jpg');

      // Et le miroir, lui, est ce que le SERVEUR applique : sans cette ligne,
      // les publications de la personne bloquée restent dans le fil.
      expect(miroir.appels, [(bloqueur: moi, bloque: cible, bloquer: true)]);
    });

    test('le miroir est écrit même quand Firestore refuse', () async {
      // Le miroir était appelé après `batch.commit()` : le lot levant
      // toujours, la ligne `public.blocked_users` n'était jamais posée. Les
      // deux moitiés sont maintenant indépendantes.
      final base = FakeFirebaseFirestore(securityRules: _toutRefuser);
      final miroir = MiroirEspion();

      await expectLater(
        source(base, miroir).blockUser(moi, cible, 'Fatima', null),
        throwsA(isA<ServerException>()),
      );

      expect(
        miroir.appels,
        [(bloqueur: moi, bloque: cible, bloquer: true)],
        reason: 'un refus Firestore ne doit plus emporter le miroir',
      );
    });

    test('un miroir en échec est annoncé, pas avalé', () async {
      // Un blocage à moitié posé n'est pas un blocage : la personne
      // apparaîtrait dans les Réglages sans que ses publications disparaissent
      // du fil. Le taire est le défaut qu'on corrige.
      final base = FakeFirebaseFirestore();
      final miroir = MiroirEspion(echec: 'session Supabase absente');

      await expectLater(
        source(base, miroir).blockUser(moi, cible, 'Fatima', null),
        throwsA(isA<ServerException>()),
      );

      expect(
        await entreeExiste(base),
        isTrue,
        reason: 'la moitié Firestore reste écrite — réessayer est idempotent',
      );
    });
  });

  group('unblockUser', () {
    test('supprime l\'entrée sans toucher aux profils', () async {
      final base = FakeFirebaseFirestore();
      await base
          .collection('users')
          .doc(moi)
          .collection('blocked_users')
          .doc(cible)
          .set({'id': cible, 'displayName': 'Fatima'});
      final miroir = MiroirEspion();

      await source(base, miroir).unblockUser(moi, cible);

      expect(await entreeExiste(base), isFalse);
      expect(
        await profilExiste(base, moi),
        isFalse,
        reason:
            'débloquer échouait en entier pour la même raison — '
            '`arrayRemove` au lieu d\'`arrayUnion` ne change rien',
      );
      expect(await profilExiste(base, cible), isFalse);
      expect(miroir.appels, [(bloqueur: moi, bloque: cible, bloquer: false)]);
    });
  });
}

/// Rejoue un refus d'écriture côté Firestore.
///
/// `FakeFirebaseFirestore` accepte tout par défaut ; sans ces règles, rien ne
/// permettrait d'éprouver que le miroir survit au refus.
const _toutRefuser = '''
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read: if true;
      allow write: if false;
    }
  }
}
''';
