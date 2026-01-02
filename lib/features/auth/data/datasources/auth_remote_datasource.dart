import 'dart:developer' as dev;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/user_model.dart';

const String _tag = 'AuthRemoteDataSource';

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

      // Ensure user document exists and update last login
      await _createOrUpdateUserDocument(
        credential.user!,
        email: credential.user!.email,
      );

      return _getUserDataFromFirestore(credential.user!);
    } on FirebaseAuthException catch (e) {
      throw ServerException(_mapFirebaseAuthError(e.code));
    } catch (e) {
      throw ServerException('Echec de la connexion: ${e.toString()}');
    }
  }

  @override
  Future<UserModel> signInWithGoogle() async {
    dev.log('=== DEBUT signInWithGoogle ===', name: _tag);
    try {
      dev.log('Etape 1: Appel de _googleSignIn.signIn()...', name: _tag);
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        dev.log('ERREUR: googleUser est null - connexion annulee par l\'utilisateur', name: _tag);
        throw ServerException('Connexion Google annulee');
      }

      dev.log('Etape 2: googleUser obtenu - email: ${googleUser.email}, id: ${googleUser.id}', name: _tag);

      dev.log('Etape 3: Recuperation des tokens d\'authentification...', name: _tag);
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      dev.log('Etape 4: Tokens obtenus - accessToken: ${googleAuth.accessToken != null ? "present" : "null"}, idToken: ${googleAuth.idToken != null ? "present" : "null"}', name: _tag);

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      dev.log('Etape 5: Credential Google cree, appel de Firebase signInWithCredential...', name: _tag);

      final userCredential = await _firebaseAuth.signInWithCredential(
        credential,
      );

      dev.log('Etape 6: Firebase signInWithCredential reussi', name: _tag);

      if (userCredential.user == null) {
        dev.log('ERREUR: userCredential.user est null apres signInWithCredential', name: _tag);
        throw ServerException('User is null after Google sign in');
      }

      dev.log('Etape 7: User Firebase obtenu - uid: ${userCredential.user!.uid}, email: ${userCredential.user!.email}, displayName: ${userCredential.user!.displayName}', name: _tag);

      dev.log('Etape 8: Creation/mise a jour du document Firestore...', name: _tag);
      await _createOrUpdateUserDocument(
        userCredential.user!,
        displayName: userCredential.user!.displayName,
        email: userCredential.user!.email,
        photoUrl: userCredential.user!.photoURL,
      );
      dev.log('Etape 9: Document Firestore mis a jour', name: _tag);

      dev.log('Etape 10: Recuperation des donnees depuis Firestore...', name: _tag);
      // Fetch from Firestore to get isAdmin and other fields
      final userModel = await _getUserDataFromFirestore(userCredential.user!);
      dev.log('=== FIN signInWithGoogle - SUCCES === user: ${userModel.id}', name: _tag);
      return userModel;
    } on FirebaseAuthException catch (e) {
      dev.log('ERREUR FirebaseAuthException: code=${e.code}, message=${e.message}', name: _tag, error: e);
      throw ServerException(_mapFirebaseAuthError(e.code));
    } catch (e, stackTrace) {
      dev.log('ERREUR Exception: ${e.toString()}', name: _tag, error: e, stackTrace: stackTrace);
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
    dev.log('_createOrUpdateUserDocument: debut pour uid=${user.uid}', name: _tag);
    try {
      final userDoc = _firestore.collection('users').doc(user.uid);

      final docSnapshot = await userDoc.get();
      dev.log('_createOrUpdateUserDocument: document existe=${docSnapshot.exists}', name: _tag);

      if (!docSnapshot.exists) {
        dev.log('_createOrUpdateUserDocument: creation nouveau document...', name: _tag);
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
        dev.log('_createOrUpdateUserDocument: nouveau document cree avec succes', name: _tag);
      } else {
        dev.log('_createOrUpdateUserDocument: mise a jour document existant...', name: _tag);
        final data = docSnapshot.data() ?? {};
        final updates = <String, dynamic>{
          'lastLoginAt': FieldValue.serverTimestamp(),
        };

        // Initialize onboarding fields if missing (for existing users before these fields were added)
        if (data['hasSeenOnboarding'] == null) {
          updates['hasSeenOnboarding'] = false;
        }
        if (data['hasGivenConsent'] == null) {
          updates['hasGivenConsent'] = false;
        }
        if (data['profileConfigComplete'] == null) {
          updates['profileConfigComplete'] = false;
        }

        // If we have explicit fresh data, make sure existing doc is updated too
        if (displayName != null) updates['displayName'] = displayName;
        if (photoUrl != null) updates['photoUrl'] = photoUrl;

        await userDoc.set(updates, SetOptions(merge: true));
        dev.log('_createOrUpdateUserDocument: document mis a jour avec succes', name: _tag);
      }
    } catch (e, stackTrace) {
      dev.log('_createOrUpdateUserDocument: ERREUR ${e.toString()}', name: _tag, error: e, stackTrace: stackTrace);
      rethrow;
    }
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
    dev.log('_getUserDataFromFirestore: debut pour uid=${firebaseUser.uid}', name: _tag);
    try {
      final doc =
          await _firestore.collection('users').doc(firebaseUser.uid).get();

      dev.log('_getUserDataFromFirestore: document existe=${doc.exists}', name: _tag);

      if (doc.exists) {
        final userModel = UserModel.fromFirestore(doc).copyWith(
          // Ensure these fields are up to date from Auth if missing in Firestore
          email: firebaseUser.email,
          // We prioritize values from Firestore if they exist, but fallback to Auth
        );
        dev.log('_getUserDataFromFirestore: UserModel cree depuis Firestore - id=${userModel.id}, email=${userModel.email}', name: _tag);
        return userModel;
      }

      // If doc doesn't exist, fallback to Auth data
      dev.log('_getUserDataFromFirestore: document non trouve, fallback sur Auth data', name: _tag);
      return _mapFirebaseUserToModel(firebaseUser);
    } catch (e, stackTrace) {
      // Fallback if read fails
      dev.log('_getUserDataFromFirestore: ERREUR ${e.toString()}, fallback sur Auth data', name: _tag, error: e, stackTrace: stackTrace);
      return _mapFirebaseUserToModel(firebaseUser);
    }
  }
}
