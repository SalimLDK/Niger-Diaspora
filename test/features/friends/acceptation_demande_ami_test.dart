// Ce que le lot d'acceptation a le droit d'écrire, et rien de plus.
//
// Le lot est atomique : un seul refus annule tout. Écrire le profil `users` de
// QUELQU'UN D'AUTRE le faisait refuser en entier dès que ce document n'existait
// pas — c'est-à-dire pour la quasi-totalité des comptes, plus rien ne créant de
// documents `users` Firestore depuis la migration vers Supabase. À l'écran :
// « Erreur de chargement », et rien qui bouge en base.
//
// Ce test fige donc la liste exacte des documents touchés. Le pendant côté
// règles — ce que Firestore accepte réellement — est
// `tools/rules_tests/acceptation_ami.mjs` ; celui-ci n'a pas besoin
// d'émulateur.

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diaspo_niger/features/friends/data/datasources/friend_remote_datasource.dart';

const expediteur = 'uid_expediteur_A';
const destinataire = 'uid_destinataire_B';
const idDemande = 'demande_1';

Future<FakeFirebaseFirestore> avecUneDemandeEnAttente() async {
  final base = FakeFirebaseFirestore();
  await base.collection('friend_requests').doc(idDemande).set({
    'senderId': expediteur,
    'senderName': 'Amadou',
    'senderPhotoUrl': null,
    'receiverId': destinataire,
    'receiverName': 'Fatima',
    'receiverPhotoUrl': null,
    'status': 'pending',
  });
  return base;
}

void main() {
  group('acceptFriendRequest', () {
    test('ne touche AUCUN document `users` — ni le sien, ni celui de l\'autre',
        () async {
      final base = await avecUneDemandeEnAttente();

      await FriendRemoteDataSourceImpl(firestore: base)
          .acceptFriendRequest(idDemande);

      // C'est la régression à empêcher : `set(merge)` sur un profil absent est
      // une CRÉATION, que `users/{userId}` n'autorise qu'à son propriétaire.
      expect(
        (await base.collection('users').doc(expediteur).get()).exists,
        isFalse,
        reason: 'le profil de l\'expéditeur ne doit pas être créé par le lot',
      );
      expect(
        (await base.collection('users').doc(destinataire).get()).exists,
        isFalse,
        reason: 'le profil du destinataire non plus : rien ne lit `friendIds`',
      );
    });

    test('écrit l\'amitié des deux côtés et passe la demande en `accepted`',
        () async {
      final base = await avecUneDemandeEnAttente();

      await FriendRemoteDataSourceImpl(firestore: base)
          .acceptFriendRequest(idDemande);

      // Depuis le 2026-09-15, la demande est **supprimée** une fois acceptée :
      // elle est passée par `accepted` dans le lot, puis oubliée. Les
      // documents traités s'accumulaient sans que rien ne les lise. Ce que
      // cette assertion vérifiait — « l'acceptation a bien eu lieu » — est
      // couvert plus bas par les deux entrées `friends`, qui sont la vraie
      // trace de l'amitié.
      expect(
        (await base.collection('friend_requests').doc(idDemande).get()).exists,
        isFalse,
      );

      // La sous-collection `friends` est la seule source : c'est elle que lit
      // `getFriends`/`areFriends`, et elle que `mirrorFriendToSupabase` reflète
      // vers `public.friends` pour l'audience « Amis » du fil.
      final chezExpediteur = await base
          .collection('users')
          .doc(expediteur)
          .collection('friends')
          .doc(destinataire)
          .get();
      expect(chezExpediteur.exists, isTrue);
      expect(chezExpediteur.data()!['displayName'], 'Fatima');

      final chezDestinataire = await base
          .collection('users')
          .doc(destinataire)
          .collection('friends')
          .doc(expediteur)
          .get();
      expect(chezDestinataire.exists, isTrue);
      expect(chezDestinataire.data()!['displayName'], 'Amadou');
    });
  });

  group('removeFriend', () {
    test('supprime les deux entrées sans toucher aux profils', () async {
      final base = FakeFirebaseFirestore();
      for (final (proprietaire, ami) in [
        (expediteur, destinataire),
        (destinataire, expediteur),
      ]) {
        await base
            .collection('users')
            .doc(proprietaire)
            .collection('friends')
            .doc(ami)
            .set({'id': ami});
      }

      await FriendRemoteDataSourceImpl(firestore: base)
          .removeFriend(destinataire, expediteur);

      for (final (proprietaire, ami) in [
        (expediteur, destinataire),
        (destinataire, expediteur),
      ]) {
        expect(
          (await base
                  .collection('users')
                  .doc(proprietaire)
                  .collection('friends')
                  .doc(ami)
                  .get())
              .exists,
          isFalse,
        );
      }

      expect(
        (await base.collection('users').doc(expediteur).get()).exists,
        isFalse,
        reason: 'retirer un ami échouait en entier pour la même raison',
      );
    });
  });
}
