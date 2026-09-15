// Le cycle de vie d'une demande d'ami : une demande ne se traite qu'une fois,
// on ne s'ajoute pas soi-même, et le document ne survit pas à son traitement.
//
// Ces trois règles n'existaient nulle part avant le 2026-09-15. Leur absence
// n'avait rien cassé de visible, mais chacune laissait une porte ouverte :
// un écran resté ouvert pouvait rejouer une demande déjà traitée, la garde
// « pas soi-même » ne vivait que dans un bouton, et les documents
// s'accumulaient indéfiniment.
//
// Le pendant côté règles — ce que Firestore accepte réellement, y compris
// d'un client modifié — est `tools/rules_tests/acceptation_ami.mjs`, blocs 5
// et 6. Ici on fige le comportement du client.

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diaspo_niger/core/errors/exceptions.dart';
import 'package:diaspo_niger/features/friends/data/datasources/friend_remote_datasource.dart';
import 'package:diaspo_niger/features/friends/data/models/friend_request_model.dart';
import 'package:diaspo_niger/features/friends/domain/entities/friend_request_entity.dart';

const expediteur = 'uid_expediteur_A';
const destinataire = 'uid_destinataire_B';
const idDemande = 'demande_1';

Future<FakeFirebaseFirestore> avecUneDemande(String statut) async {
  final base = FakeFirebaseFirestore();
  await base.collection('friend_requests').doc(idDemande).set({
    'senderId': expediteur,
    'senderName': 'Amadou',
    'receiverId': destinataire,
    'receiverName': 'Fatima',
    'status': statut,
  });
  return base;
}

void main() {
  group('une demande ne se traite qu\'une fois', () {
    for (final (statut, mot) in [
      ('accepted', 'a déjà été acceptée'),
      ('declined', 'a déjà été refusée'),
      ('cancelled', 'a été annulée'),
    ]) {
      test('accepter une demande « $statut » est refusé', () async {
        final base = await avecUneDemande(statut);
        final source = FriendRemoteDataSourceImpl(firestore: base);

        await expectLater(
          source.acceptFriendRequest(idDemande),
          throwsA(
            isA<ServerException>().having((e) => e.message, 'message', contains(mot)),
          ),
        );

        // Et surtout : rien n'a bougé.
        final apres =
            await base.collection('friend_requests').doc(idDemande).get();
        expect(apres.data()!['status'], statut);
        expect(
          (await base
                  .collection('users')
                  .doc(expediteur)
                  .collection('friends')
                  .doc(destinataire)
                  .get())
              .exists,
          isFalse,
          reason: 'aucune amitié ne doit naître d\'une demande déjà traitée',
        );
      });
    }

    test('refuser une demande déjà refusée est refusé', () async {
      final base = await avecUneDemande('declined');
      await expectLater(
        FriendRemoteDataSourceImpl(firestore: base)
            .declineFriendRequest(idDemande),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('le document ne survit pas à son traitement', () {
    test('accepter le supprime', () async {
      final base = await avecUneDemande('pending');
      await FriendRemoteDataSourceImpl(firestore: base)
          .acceptFriendRequest(idDemande);

      expect(
        (await base.collection('friend_requests').doc(idDemande).get()).exists,
        isFalse,
        reason: 'les documents traités s\'accumulaient indéfiniment',
      );
      // L'amitié, elle, est bien là : c'est elle qui compte.
      expect(
        (await base
                .collection('users')
                .doc(destinataire)
                .collection('friends')
                .doc(expediteur)
                .get())
            .exists,
        isTrue,
      );
    });

    for (final geste in ['refuser', 'annuler']) {
      test('$geste le supprime aussi', () async {
        final base = await avecUneDemande('pending');
        final source = FriendRemoteDataSourceImpl(firestore: base);
        if (geste == 'refuser') {
          await source.declineFriendRequest(idDemande);
        } else {
          await source.cancelFriendRequest(idDemande);
        }
        expect(
          (await base.collection('friend_requests').doc(idDemande).get()).exists,
          isFalse,
        );
      });
    }
  });

  group('on ne s\'ajoute pas soi-même', () {
    test('envoyer une demande à soi-même est refusé', () async {
      final base = FakeFirebaseFirestore();
      await expectLater(
        FriendRemoteDataSourceImpl(firestore: base).sendFriendRequest(
          senderId: expediteur,
          senderName: 'Amadou',
          receiverId: expediteur,
          receiverName: 'Amadou',
        ),
        throwsA(isA<ServerException>()),
      );
      expect(
        (await base.collection('friend_requests').get()).docs, isEmpty,
        reason: 'rien ne doit être écrit',
      );
    });
  });

  group('`cancelled` est une valeur connue du modèle', () {
    // Le `default` du parseur la rendait comme `pending` : une demande annulée
    // se lisait comme en attente.
    test('elle ne se lit plus comme « en attente »', () {
      final modele = FriendRequestModel.fromJson(const {
        'id': idDemande,
        'senderId': expediteur,
        'senderName': 'Amadou',
        'receiverId': destinataire,
        'receiverName': 'Fatima',
        'status': 'cancelled',
      });
      expect(modele.toEntity().status, FriendRequestStatus.cancelled);
    });

    test('une valeur vraiment inattendue retombe sur « en attente »', () {
      final modele = FriendRequestModel.fromJson(const {
        'id': idDemande,
        'senderId': expediteur,
        'senderName': 'Amadou',
        'receiverId': destinataire,
        'receiverName': 'Fatima',
        'status': 'quelque_chose_de_neuf',
      });
      expect(modele.toEntity().status, FriendRequestStatus.pending);
    });
  });
}
