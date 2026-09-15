import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/firebase_collections.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/journal_echecs.dart';
import '../../../messages/data/datasources/message_remote_datasource.dart';
import '../../domain/repositories/friend_repository.dart';
import '../models/friend_model.dart';
import '../models/friend_request_model.dart';

abstract class FriendRemoteDataSource {
  // Friend Requests
  Future<void> sendFriendRequest({
    required String senderId,
    required String senderName,
    String? senderPhotoUrl,
    required String receiverId,
    required String receiverName,
    String? receiverPhotoUrl,
  });

  Future<void> acceptFriendRequest(String requestId);
  Future<void> declineFriendRequest(String requestId);
  Future<void> cancelFriendRequest(String requestId);
  Future<FriendRequestModel> getRequestById(String requestId);

  Stream<List<FriendRequestModel>> getReceivedRequests(String userId);
  Stream<List<FriendRequestModel>> getSentRequests(String userId);

  Future<FriendshipStatus> getFriendshipStatus(String userId1, String userId2);

  // Friends List
  Stream<List<FriendModel>> getFriends(String userId);
  Future<void> removeFriend(String userId, String friendId);
  Future<bool> areFriends(String userId1, String userId2);
  Future<List<FriendModel>> searchFriends(String userId, String query);
}

class FriendRemoteDataSourceImpl implements FriendRemoteDataSource {
  final FirebaseFirestore _firestore;
  final MessageRemoteDataSource? _messageDataSource;

  FriendRemoteDataSourceImpl({
    FirebaseFirestore? firestore,
    MessageRemoteDataSource? messageDataSource,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _messageDataSource = messageDataSource;

  @override
  Future<void> sendFriendRequest({
    required String senderId,
    required String senderName,
    String? senderPhotoUrl,
    required String receiverId,
    required String receiverName,
    String? receiverPhotoUrl,
  }) async {
    try {
      // S'ajouter soi-même n'a aucun sens, et le lot d'acceptation qui
      // suivrait écrirait `users/X/friends/X`. La garde existait seulement
      // dans le bouton de la fiche de profil (`_isCurrentUser`) : un autre
      // appelant, ou un client modifié, n'en rencontrait aucune.
      if (senderId == receiverId) {
        throw ServerException('On ne peut pas s\'ajouter soi-même');
      }

      // Check if a request already exists
      final existingRequest =
          await _firestore
              .collection(FirebaseCollections.friendRequests)
              .where('senderId', isEqualTo: senderId)
              .where('receiverId', isEqualTo: receiverId)
              .where('status', isEqualTo: 'pending')
              .get();

      if (existingRequest.docs.isNotEmpty) {
        throw ServerException('Une demande est déjà en attente');
      }

      // Check if reverse request exists
      final reverseRequest =
          await _firestore
              .collection(FirebaseCollections.friendRequests)
              .where('senderId', isEqualTo: receiverId)
              .where('receiverId', isEqualTo: senderId)
              .where('status', isEqualTo: 'pending')
              .get();

      if (reverseRequest.docs.isNotEmpty) {
        // Auto-accept if the other person already sent a request
        await acceptFriendRequest(reverseRequest.docs.first.id);
        return;
      }

      // Check if already friends
      final alreadyFriends = await areFriends(senderId, receiverId);
      if (alreadyFriends) {
        throw ServerException('Vous êtes déjà amis');
      }

      // Create the friend request
      await _firestore.collection(FirebaseCollections.friendRequests).add({
        'senderId': senderId,
        'senderName': senderName,
        'senderPhotoUrl': senderPhotoUrl,
        'receiverId': receiverId,
        'receiverName': receiverName,
        'receiverPhotoUrl': receiverPhotoUrl,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw ServerException(
        e.message ?? 'Erreur lors de l\'envoi de la demande',
      );
    }
  }

  @override
  Future<void> acceptFriendRequest(String requestId) async {
    try {
      final requestDoc =
          await _firestore
              .collection(FirebaseCollections.friendRequests)
              .doc(requestId)
              .get();

      if (!requestDoc.exists) {
        throw ServerException('Demande non trouvée');
      }

      final data = requestDoc.data()!;
      // Ni le datasource ni les règles ne vérifiaient que la demande était
      // encore en attente : un écran resté ouvert pouvait accepter une demande
      // que l'expéditeur venait d'annuler, ou en réaccepter une déjà traitée.
      _exigerEnAttente(data['status'], 'accepter');

      final senderId = data['senderId'] as String;
      final senderName = data['senderName'] as String;
      final senderPhotoUrl = data['senderPhotoUrl'] as String?;
      final receiverId = data['receiverId'] as String;
      final receiverName = data['receiverName'] as String;
      final receiverPhotoUrl = data['receiverPhotoUrl'] as String?;

      final batch = _firestore.batch();

      // Update request status
      batch.update(requestDoc.reference, {
        'status': 'accepted',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Add friend to sender's friends list
      final senderFriendRef = _firestore
          .collection(FirebaseCollections.users)
          .doc(senderId)
          .collection(FirebaseCollections.friends)
          .doc(receiverId);

      batch.set(senderFriendRef, {
        'id': receiverId,
        'displayName': receiverName,
        'photoUrl': receiverPhotoUrl,
        'addedAt': FieldValue.serverTimestamp(),
      });

      // Add friend to receiver's friends list
      final receiverFriendRef = _firestore
          .collection(FirebaseCollections.users)
          .doc(receiverId)
          .collection(FirebaseCollections.friends)
          .doc(senderId);

      batch.set(receiverFriendRef, {
        'id': senderId,
        'displayName': senderName,
        'photoUrl': senderPhotoUrl,
        'addedAt': FieldValue.serverTimestamp(),
      });

      // Le tableau `friendIds` des deux profils N'EST PLUS ÉCRIT ICI, et le
      // lot se limite aux trois documents ci-dessus.
      //
      // Il n'était lu par personne : la liste d'amis de l'app vient de la
      // sous-collection `friends` (`getFriends`, `areFriends`), l'audience
      // « Amis » du fil vient de `public.friends` côté Supabase — que
      // `mirrorFriendToSupabase` alimente à partir de cette même
      // sous-collection, pas du tableau. Seul le nettoyage de suppression de
      // compte le balayait encore, en Admin SDK, pour les données d'avant.
      //
      // Et il faisait échouer TOUTE l'acceptation. `set(merge)` sur un
      // document absent est une CRÉATION, et `users/{autrui}` n'autorise la
      // création qu'à son propriétaire — à raison. Or plus rien ne crée les
      // documents `users` Firestore depuis la migration vers Supabase : ils
      // sont absents pour la quasi-totalité des comptes. Le lot étant
      // atomique, ce seul refus annulait les trois autres écritures, et
      // l'usager lisait « Erreur de chargement » sans que rien ne bouge.
      // Mesuré par `tools/rules_tests/acceptation_ami.mjs`, bloc 2.
      await batch.commit();
      await _oublierDemande(requestDoc.reference);

      // Create a conversation between the new friends
      if (_messageDataSource != null) {
        try {
          await _messageDataSource.createIndividualConversation(
            currentUserId: receiverId,
            otherUserId: senderId,
          );
        } catch (_) {
          // Don't fail the friend request if conversation creation fails
          // The conversation can be created later when they start chatting
        }
      }
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors de l\'acceptation');
    }
  }

  @override
  Future<void> declineFriendRequest(String requestId) async {
    await _cloreDemande(requestId, 'declined', 'refuser');
  }

  @override
  Future<void> cancelFriendRequest(String requestId) async {
    await _cloreDemande(requestId, 'cancelled', 'annuler');
  }

  /// Passe la demande dans son état terminal, puis la supprime.
  ///
  /// Les deux gestes faisaient exactement la même chose à un mot près.
  Future<void> _cloreDemande(
    String requestId,
    String statut,
    String geste,
  ) async {
    final reference = _firestore
        .collection(FirebaseCollections.friendRequests)
        .doc(requestId);
    try {
      final doc = await reference.get();
      if (!doc.exists) throw ServerException('Demande non trouvée');
      _exigerEnAttente(doc.data()?['status'], geste);

      await reference.update({
        'status': statut,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await _oublierDemande(reference);
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors de l\'opération');
    }
  }

  /// Refuse d'agir sur une demande qui n'est plus en attente.
  ///
  /// Le message nomme l'état trouvé : « cette demande a déjà été acceptée »
  /// se comprend, « erreur » non.
  void _exigerEnAttente(Object? statut, String geste) {
    final valeur = statut is String ? statut : 'pending';
    if (valeur == 'pending') return;
    const dejaFait = {
      'accepted': 'a déjà été acceptée',
      'declined': 'a déjà été refusée',
      'cancelled': 'a été annulée',
    };
    throw ServerException(
      'Impossible de $geste : cette demande '
      '${dejaFait[valeur] ?? "n’est plus en attente"}.',
    );
  }

  /// Supprime la demande une fois qu'elle a servi.
  ///
  /// Les documents s'accumulaient indéfiniment — acceptés, refusés, annulés —
  /// alors que plus rien ne les lit : la liste d'amis vit dans la
  /// sous-collection `friends`, et les deux flux de l'écran Amis filtrent
  /// `status == 'pending'`. Les règles autorisaient déjà cette suppression
  /// (statut terminal, par l'une des deux parties), personne ne l'appelait.
  ///
  /// **Au mieux** : un échec ici ne doit pas défaire une acceptation réussie.
  /// Il ne reste alors qu'un document inerte de plus — exactement l'état
  /// d'avant. Mais il est signalé, plutôt que perdu.
  ///
  /// Contrepartie assumée : on perd la trace de qui avait demandé quoi. Rien
  /// ne s'en sert aujourd'hui, et renvoyer une demande n'a jamais regardé les
  /// documents terminaux — `sendFriendRequest` ne cherche que `pending`.
  Future<void> _oublierDemande(DocumentReference<Map<String, dynamic>> ref) async {
    try {
      await ref.delete();
    } catch (e) {
      signalerEchecSilencieux(e, contexte: 'menage demande d\'ami');
    }
  }

  @override
  Future<FriendRequestModel> getRequestById(String requestId) async {
    try {
      final doc =
          await _firestore
              .collection(FirebaseCollections.friendRequests)
              .doc(requestId)
              .get();

      if (!doc.exists) {
        throw ServerException('Demande non trouvée');
      }

      final data = doc.data()!;
      data['id'] = doc.id;
      if (data['createdAt'] is Timestamp) {
        data['createdAt'] =
            (data['createdAt'] as Timestamp).toDate().toUtc().toIso8601String();
      }
      if (data['updatedAt'] is Timestamp) {
        data['updatedAt'] =
            (data['updatedAt'] as Timestamp).toDate().toUtc().toIso8601String();
      }
      return FriendRequestModel.fromJson(data);
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors de la récupération');
    }
  }

  @override
  Stream<List<FriendRequestModel>> getReceivedRequests(String userId) {
    return _firestore
        .collection(FirebaseCollections.friendRequests)
        .where('receiverId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            if (data['createdAt'] is Timestamp) {
              data['createdAt'] =
                  (data['createdAt'] as Timestamp).toDate().toUtc().toIso8601String();
            }
            if (data['updatedAt'] is Timestamp) {
              data['updatedAt'] =
                  (data['updatedAt'] as Timestamp).toDate().toUtc().toIso8601String();
            }
            return FriendRequestModel.fromJson(data);
          }).toList();
        });
  }

  @override
  Stream<List<FriendRequestModel>> getSentRequests(String userId) {
    return _firestore
        .collection(FirebaseCollections.friendRequests)
        .where('senderId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            if (data['createdAt'] is Timestamp) {
              data['createdAt'] =
                  (data['createdAt'] as Timestamp).toDate().toUtc().toIso8601String();
            }
            if (data['updatedAt'] is Timestamp) {
              data['updatedAt'] =
                  (data['updatedAt'] as Timestamp).toDate().toUtc().toIso8601String();
            }
            return FriendRequestModel.fromJson(data);
          }).toList();
        });
  }

  @override
  Future<FriendshipStatus> getFriendshipStatus(
    String userId1,
    String userId2,
  ) async {
    try {
      // Check if already friends
      final friendDoc =
          await _firestore
              .collection(FirebaseCollections.users)
              .doc(userId1)
              .collection(FirebaseCollections.friends)
              .doc(userId2)
              .get();

      if (friendDoc.exists) {
        return FriendshipStatus.friends;
      }

      // Check for pending request sent by userId1
      final sentRequest =
          await _firestore
              .collection(FirebaseCollections.friendRequests)
              .where('senderId', isEqualTo: userId1)
              .where('receiverId', isEqualTo: userId2)
              .where('status', isEqualTo: 'pending')
              .get();

      if (sentRequest.docs.isNotEmpty) {
        return FriendshipStatus.pendingSent;
      }

      // Check for pending request received by userId1
      final receivedRequest =
          await _firestore
              .collection(FirebaseCollections.friendRequests)
              .where('senderId', isEqualTo: userId2)
              .where('receiverId', isEqualTo: userId1)
              .where('status', isEqualTo: 'pending')
              .get();

      if (receivedRequest.docs.isNotEmpty) {
        return FriendshipStatus.pendingReceived;
      }

      return FriendshipStatus.none;
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors de la vérification');
    }
  }

  @override
  Stream<List<FriendModel>> getFriends(String userId) {
    return _firestore
        .collection(FirebaseCollections.users)
        .doc(userId)
        .collection(FirebaseCollections.friends)
        .orderBy('addedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            if (data['addedAt'] is Timestamp) {
              data['addedAt'] =
                  (data['addedAt'] as Timestamp).toDate().toUtc().toIso8601String();
            }
            return FriendModel.fromJson(data);
          }).toList();
        });
  }

  @override
  Future<void> removeFriend(String userId, String friendId) async {
    try {
      final batch = _firestore.batch();

      // Remove from user's friends list
      final userFriendRef = _firestore
          .collection(FirebaseCollections.users)
          .doc(userId)
          .collection(FirebaseCollections.friends)
          .doc(friendId);
      batch.delete(userFriendRef);

      // Remove from friend's friends list
      final friendFriendRef = _firestore
          .collection(FirebaseCollections.users)
          .doc(friendId)
          .collection(FirebaseCollections.friends)
          .doc(userId);
      batch.delete(friendFriendRef);

      // `friendIds` n'est plus écrit ici non plus — même raison qu'à
      // l'acceptation, et même panne : `set(merge)` sur le profil de l'ami,
      // absent, est une création que `users/{autrui}` refuse, et le lot étant
      // atomique, retirer un ami échouait en entier. Les deux suppressions
      // ci-dessus sont ce que l'app lit, et ce que le miroir Supabase suit.
      await batch.commit();
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors de la suppression');
    }
  }

  @override
  Future<bool> areFriends(String userId1, String userId2) async {
    try {
      final doc =
          await _firestore
              .collection(FirebaseCollections.users)
              .doc(userId1)
              .collection(FirebaseCollections.friends)
              .doc(userId2)
              .get();

      return doc.exists;
    } on FirebaseException {
      return false;
    }
  }

  @override
  Future<List<FriendModel>> searchFriends(String userId, String query) async {
    try {
      if (query.trim().isEmpty) {
        return [];
      }

      final lowerQuery = query.toLowerCase();

      // Récupérer tous les amis et filtrer localement (insensible à la casse)
      final snapshot = await _firestore
          .collection(FirebaseCollections.users)
          .doc(userId)
          .collection(FirebaseCollections.friends)
          .get();

      final friends = <FriendModel>[];

      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          data['id'] = doc.id;
          if (data['addedAt'] is Timestamp) {
            data['addedAt'] =
                (data['addedAt'] as Timestamp).toDate().toUtc().toIso8601String();
          } else if (data['addedAt'] == null) {
            // Si addedAt n'existe pas, utiliser la date actuelle
            data['addedAt'] = DateTime.now().toUtc().toIso8601String();
          }

          final displayName = (data['displayName'] as String? ?? '').toLowerCase();

          if (displayName.contains(lowerQuery)) {
            friends.add(FriendModel.fromJson(data));
          }
        } catch (_) {
          // Ignorer les documents malformés
          continue;
        }
      }

      // Limiter les résultats
      if (friends.length > 20) {
        return friends.sublist(0, 20);
      }

      return friends;
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors de la recherche');
    } catch (e) {
      throw ServerException('Erreur lors de la recherche: $e');
    }
  }
}
