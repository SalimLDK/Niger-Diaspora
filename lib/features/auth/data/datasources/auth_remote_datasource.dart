import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
  });

  Future<UserModel> signInWithGoogle();

  Future<UserModel> signUp({
    required String email,
    required String password,
    required String displayName,
  });

  Future<void> signOut();

  Future<void> deleteAccount();

  Future<void> reauthenticateWithPassword(String password);

  Future<UserModel?> getCurrentUser();

  Stream<UserModel?> get authStateChanges;

  Future<void> sendPasswordResetEmail(String email);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;

  AuthRemoteDataSourceImpl({
    required FirebaseAuth firebaseAuth,
    required FirebaseFirestore firestore,
    required GoogleSignIn googleSignIn,
  }) : _firebaseAuth = firebaseAuth,
       _firestore = firestore,
       _googleSignIn = googleSignIn;

  @override
  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user == null) {
        throw ServerException('User is null after sign in');
      }

      await _updateLastLogin(credential.user!.uid);

      return _getUserDataFromFirestore(credential.user!);
    } on FirebaseAuthException catch (e) {
      throw ServerException(_mapFirebaseAuthError(e.code));
    } catch (e) {
      throw ServerException('Echec de la connexion: ${e.toString()}');
    }
  }

  @override
  Future<UserModel> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        throw ServerException('Connexion Google annulee');
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _firebaseAuth.signInWithCredential(
        credential,
      );

      if (userCredential.user == null) {
        throw ServerException('User is null after Google sign in');
      }

      await _createOrUpdateUserDocument(
        userCredential.user!,
        displayName: userCredential.user!.displayName,
        email: userCredential.user!.email,
        photoUrl: userCredential.user!.photoURL,
      );

      // Fetch from Firestore to get isAdmin and other fields
      return _getUserDataFromFirestore(userCredential.user!);
    } on FirebaseAuthException catch (e) {
      throw ServerException(_mapFirebaseAuthError(e.code));
    } catch (e) {
      throw ServerException('Echec de la connexion Google: ${e.toString()}');
    }
  }

  @override
  Future<UserModel> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user == null) {
        throw ServerException('User is null after sign up');
      }

      await credential.user!.updateDisplayName(displayName);
      await credential.user!
          .reload(); // Reload to ensure displayName is updated

      // Get fresh user object after reload
      final updatedUser = _firebaseAuth.currentUser!;

      // Pass displayName explicitly to ensure it's saved even if user.displayName is not yet updated locally
      await _createOrUpdateUserDocument(
        updatedUser,
        displayName: displayName,
        email: email,
      );

      // Fetch from Firestore to get all fields (for consistency with other methods)
      return _getUserDataFromFirestore(updatedUser);
    } on FirebaseAuthException catch (e) {
      throw ServerException(_mapFirebaseAuthError(e.code));
    } catch (e) {
      throw ServerException('Echec de l\'inscription: ${e.toString()}');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await Future.wait([_firebaseAuth.signOut(), _googleSignIn.signOut()]);
    } catch (e) {
      throw ServerException('Echec de la deconnexion');
    }
  }

  @override
  Future<void> reauthenticateWithPassword(String password) async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null || user.email == null) {
        throw ServerException('Aucun utilisateur connecté');
      }

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );

      await user.reauthenticateWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw ServerException(_mapFirebaseAuthError(e.code));
    } catch (e) {
      throw ServerException('Echec de la réauthentification: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteAccount() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        throw ServerException('Aucun utilisateur connecté');
      }

      final userId = user.uid;

      // 1. Delete user profile from Firestore
      await _firestore.collection('users').doc(userId).delete();

      // 2. Delete user's conversations (where they are the only participant or leave group)
      final conversationsQuery =
          await _firestore
              .collection('conversations')
              .where('participantIds', arrayContains: userId)
              .get();

      final batch = _firestore.batch();
      for (final doc in conversationsQuery.docs) {
        final data = doc.data();
        final participantIds = List<String>.from(data['participantIds'] ?? []);

        if (participantIds.length <= 2) {
          // Individual conversation or small group - delete entirely
          batch.delete(doc.reference);
          // Delete all messages in this conversation
          final messagesQuery =
              await doc.reference.collection('messages').get();
          for (final messageDoc in messagesQuery.docs) {
            batch.delete(messageDoc.reference);
          }
        } else {
          // Group conversation - just remove user from participants
          participantIds.remove(userId);
          batch.update(doc.reference, {'participantIds': participantIds});
        }
      }
      await batch.commit();

      // 3. Remove user from groups they are member of
      final groupsQuery =
          await _firestore
              .collection('groups')
              .where('memberIds', arrayContains: userId)
              .get();

      final groupBatch = _firestore.batch();
      for (final doc in groupsQuery.docs) {
        final data = doc.data();
        final memberIds = List<String>.from(data['memberIds'] ?? []);
        memberIds.remove(userId);

        if (data['createdBy'] == userId && memberIds.isEmpty) {
          // User created the group and is the only member - delete group
          groupBatch.delete(doc.reference);
        } else {
          groupBatch.update(doc.reference, {'memberIds': memberIds});
        }
      }
      await groupBatch.commit();

      // 4. Delete events created by user
      final eventsQuery =
          await _firestore
              .collection('events')
              .where('organizerId', isEqualTo: userId)
              .get();

      final eventBatch = _firestore.batch();
      for (final doc in eventsQuery.docs) {
        eventBatch.delete(doc.reference);
      }
      await eventBatch.commit();

      // 5. Remove user from events they are attending
      final attendingEventsQuery =
          await _firestore
              .collection('events')
              .where('attendeeIds', arrayContains: userId)
              .get();

      final attendeeBatch = _firestore.batch();
      for (final doc in attendingEventsQuery.docs) {
        final data = doc.data();
        final attendeeIds = List<String>.from(data['attendeeIds'] ?? []);
        attendeeIds.remove(userId);
        attendeeBatch.update(doc.reference, {'attendeeIds': attendeeIds});
      }
      await attendeeBatch.commit();

      // 6. Delete Firebase Auth user
      try {
        await user.delete();
      } on FirebaseAuthException catch (e) {
        if (e.code == 'requires-recent-login') {
          // Rethrow this specific error so UI can handle reauthentication
          rethrow;
        }
        throw ServerException(_mapFirebaseAuthError(e.code));
      }

      // 7. Sign out from Google if applicable
      await _googleSignIn.signOut();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw ServerException(
          'Pour des raisons de sécurité, veuillez confirmer votre mot de passe',
        );
      }
      throw ServerException(_mapFirebaseAuthError(e.code));
    } catch (e) {
      throw ServerException(
        'Echec de la suppression du compte: ${e.toString()}',
      );
    }
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return null;
    // Fetch from Firestore to get isAdmin and other fields
    return _getUserDataFromFirestore(user);
  }

  @override
  Stream<UserModel?> get authStateChanges {
    return _firebaseAuth.authStateChanges().asyncMap((user) async {
      if (user == null) return null;
      // Fetch from Firestore to get isAdmin and other fields
      return _getUserDataFromFirestore(user);
    });
  }

  UserModel _mapFirebaseUserToModel(User user) {
    return UserModel(
      id: user.uid,
      email: user.email,
      displayName: user.displayName,
      photoUrl: user.photoURL,
      phoneNumber: user.phoneNumber,
      createdAt: user.metadata.creationTime,
      lastLoginAt: user.metadata.lastSignInTime,
    );
  }

  Future<void> _createOrUpdateUserDocument(
    User user, {
    String? displayName,
    String? email,
    String? photoUrl,
  }) async {
    final userDoc = _firestore.collection('users').doc(user.uid);

    final docSnapshot = await userDoc.get();

    if (!docSnapshot.exists) {
      await userDoc.set({
        'email': email ?? user.email,
        'displayName': displayName ?? user.displayName,
        'photoUrl': photoUrl ?? user.photoURL,
        'phoneNumber': user.phoneNumber,
        'hasSeenOnboarding': false,
        'hasGivenConsent': false,
        'profileConfigComplete': false,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
      });
    } else {
      final updates = <String, dynamic>{
        'lastLoginAt': FieldValue.serverTimestamp(),
      };

      // If we have explicit fresh data, make sure existing doc is updated too
      // (in case it existed but was incomplete)
      if (displayName != null) updates['displayName'] = displayName;
      if (photoUrl != null) updates['photoUrl'] = photoUrl;

      await userDoc.update(updates);
    }
  }

  Future<void> _updateLastLogin(String userId) async {
    await _firestore.collection('users').doc(userId).update({
      'lastLoginAt': FieldValue.serverTimestamp(),
    });
  }

  String _mapFirebaseAuthError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'Aucun utilisateur trouve avec cet email';
      case 'wrong-password':
        return 'Mot de passe incorrect';
      case 'email-already-in-use':
        return 'Cet email est deja utilise';
      case 'invalid-email':
        return 'Email invalide';
      case 'weak-password':
        return 'Le mot de passe est trop faible';
      case 'user-disabled':
        return 'Ce compte a ete desactive';
      case 'too-many-requests':
        return 'Trop de tentatives. Reessayez plus tard';
      case 'invalid-credential':
        return 'Email ou mot de passe incorrect';
      default:
        return 'Une erreur est survenue ($code)';
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw ServerException(_mapFirebaseAuthError(e.code));
    } catch (e) {
      throw ServerException('Echec de l\'envoi de l\'email: ${e.toString()}');
    }
  }

  Future<UserModel> _getUserDataFromFirestore(User firebaseUser) async {
    try {
      final doc =
          await _firestore.collection('users').doc(firebaseUser.uid).get();

      if (doc.exists) {
        return UserModel.fromFirestore(doc).copyWith(
          // Ensure these fields are up to date from Auth if missing in Firestore
          email: firebaseUser.email,
          // We prioritize values from Firestore if they exist, but fallback to Auth
        );
      }

      // If doc doesn't exist, fallback to Auth data
      return _mapFirebaseUserToModel(firebaseUser);
    } catch (e) {
      // Fallback if read fails
      return _mapFirebaseUserToModel(firebaseUser);
    }
  }
}
