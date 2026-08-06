import 'dart:developer' as dev;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/services.dart' show PlatformException;
import 'package:google_sign_in/google_sign_in.dart';
// AuthException est masquee : celle du projet (core/errors) porte le code
// Firebase, celle de Supabase n est pas utilisee ici.
import 'package:supabase_flutter/supabase_flutter.dart' hide User, AuthException;
import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/secure_preferences_service.dart';
import '../../../../core/services/supabase_auth_bridge.dart';
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

  Future<void> sendPhoneOtp(String phoneNumber);

  Future<void> verifyPhoneOtp({
    required String phoneNumber,
    required String code,
  });
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  final String? _serverClientId;
  bool _googleSignInInitialized = false;

  AuthRemoteDataSourceImpl({
    required FirebaseAuth firebaseAuth,
    required GoogleSignIn googleSignIn,
    String? serverClientId,
  }) : _firebaseAuth = firebaseAuth,
       _googleSignIn = googleSignIn,
       _serverClientId = serverClientId;

  SupabaseClient get _supabase => Supabase.instance.client;

  Future<void> _ensureGoogleSignInInitialized() async {
    if (!_googleSignInInitialized) {
      await _googleSignIn.initialize(serverClientId: _serverClientId);
      _googleSignInInitialized = true;
    }
  }

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

      final user = credential.user!;

      await SupabaseAuthBridge.instance.syncWithFirebase(user);
      try {
        await _upsertUserToSupabase(user, email: user.email);
      } catch (_) {}

      return _getUserDataFromSupabase(user);
    } on FirebaseAuthException catch (e) {
      throw ServerException(_mapFirebaseAuthError(e.code));
    } catch (e) {
      throw ServerException('Echec de la connexion: ${e.toString()}');
    }
  }

  @override
  Future<UserModel> signInWithGoogle() async {
    if (kDebugMode) dev.log('=== DEBUT signInWithGoogle ===', name: _tag);
    try {
      // Step 0: Ensure GoogleSignIn is initialized (required for 7.x)
      if (kDebugMode) dev.log('Etape 0: Initialisation de GoogleSignIn...', name: _tag);
      await _ensureGoogleSignInInitialized();

      // Step 0b: Disconnect any previous session to reset state
      // This helps prevent NullPointerException on some devices (especially OnePlus)
      // where SignInHubActivity may have corrupted state from a previous session
      if (kDebugMode) dev.log('Etape 0b: Deconnexion de la session precedente...', name: _tag);
      try {
        await _googleSignIn.disconnect();
      } catch (e) {
        // Ignore disconnect errors - user might not be signed in
        if (kDebugMode) dev.log('Etape 0b: disconnect() ignore (normal si pas de session): $e', name: _tag);
      }

      if (kDebugMode) dev.log('Etape 1: Appel de _googleSignIn.authenticate()...', name: _tag);
      final GoogleSignInAccount googleUser;
      try {
        googleUser = await _googleSignIn.authenticate();
      } on GoogleSignInException catch (e) {
        if (e.code == GoogleSignInExceptionCode.canceled) {
          if (kDebugMode) dev.log('ERREUR: connexion annulee par l\'utilisateur', name: _tag);
          throw ServerException('Connexion Google annulee');
        }
        rethrow;
      }

      if (kDebugMode) dev.log('Etape 2: googleUser obtenu - email: ${googleUser.email}, id: ${googleUser.id}', name: _tag);

      if (kDebugMode) dev.log('Etape 3: Recuperation des tokens d\'authentification...', name: _tag);
      final googleAuth = googleUser.authentication;

      if (kDebugMode) dev.log('Etape 4: Tokens obtenus - idToken: ${googleAuth.idToken != null ? 'present' : 'null'}', name: _tag);

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      if (kDebugMode) dev.log('Etape 5: Credential Google cree, appel de Firebase signInWithCredential...', name: _tag);

      final userCredential = await _firebaseAuth.signInWithCredential(
        credential,
      );

      if (kDebugMode) dev.log('Etape 6: Firebase signInWithCredential reussi', name: _tag);

      if (userCredential.user == null) {
        if (kDebugMode) dev.log('ERREUR: userCredential.user est null apres signInWithCredential', name: _tag);
        throw ServerException('User is null after Google sign in');
      }

      final user = userCredential.user!;
      if (kDebugMode) dev.log('Etape 7: User Firebase obtenu - uid: ${user.uid}, email: ${user.email}, displayName: ${user.displayName}', name: _tag);

      if (kDebugMode) dev.log('Etape 8: Sync JWT Supabase...', name: _tag);
      await SupabaseAuthBridge.instance.syncWithFirebase(user);
      if (kDebugMode) dev.log('Etape 9: Upsert vers Supabase...', name: _tag);
      try {
        await _upsertUserToSupabase(
          user,
          displayName: user.displayName,
          email: user.email,
          photoUrl: user.photoURL,
        );
        if (kDebugMode) dev.log('Etape 10: Upsert Supabase effectue', name: _tag);
      } catch (e) {
        if (kDebugMode) dev.log('Etape 10: Upsert Supabase echoue (non-fatal): $e', name: _tag);
      }

      if (kDebugMode) dev.log('Etape 11: Recuperation des donnees depuis Supabase...', name: _tag);
      final userModel = await _getUserDataFromSupabase(user);
      if (kDebugMode) dev.log('=== FIN signInWithGoogle - SUCCES === user: ${userModel.id}', name: _tag);
      return userModel;
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) dev.log('ERREUR FirebaseAuthException: code=${e.code}, message=${e.message}', name: _tag, error: e);
      throw ServerException(_mapFirebaseAuthError(e.code));
    } on PlatformException catch (e, stackTrace) {
      // Handle PlatformException which wraps native Android exceptions
      // This includes NullPointerException from SignInHubActivity on OnePlus devices
      if (kDebugMode) dev.log('ERREUR PlatformException: code=${e.code}, message=${e.message}', name: _tag, error: e, stackTrace: stackTrace);

      // Check for specific error patterns
      if (e.message?.contains('NullPointerException') == true ||
          e.message?.contains('getClass()') == true ||
          e.code == 'sign_in_failed') {
        // This is likely the OnePlus SignInHubActivity crash
        throw ServerException(
          'Erreur de connexion Google. Veuillez réessayer ou redémarrer l\'application.',
        );
      }
      throw ServerException('Echec de la connexion Google: ${e.message}');
    } catch (e, stackTrace) {
      if (kDebugMode) dev.log('ERREUR Exception: ${e.toString()}', name: _tag, error: e, stackTrace: stackTrace);
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
      await credential.user!.reload(); // Reload to ensure displayName is updated

      // Get fresh user object after reload
      final updatedUser = _firebaseAuth.currentUser!;

      // Pass displayName explicitly to ensure it's saved even if user.displayName is not yet updated locally
      await SupabaseAuthBridge.instance.syncWithFirebase(updatedUser);
      try {
        await _upsertUserToSupabase(
          updatedUser,
          displayName: displayName,
          email: email,
        );
      } catch (_) {}

      // Fetch from Supabase to get all fields (for consistency with other methods)
      return _getUserDataFromSupabase(updatedUser);
    } on FirebaseAuthException catch (e) {
      throw ServerException(_mapFirebaseAuthError(e.code));
    } catch (e) {
      throw ServerException('Echec de l\'inscription: ${e.toString()}');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _ensureGoogleSignInInitialized();
      await SupabaseAuthBridge.instance.signOut();
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
      await _ensureGoogleSignInInitialized();
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        throw ServerException('Aucun utilisateur connecté');
      }

      final userId = user.uid;

      // Clean up Supabase data FIRST, then delete Auth.
      // If Supabase cleanup fails, the user can retry — their account still exists.
      // If Auth were deleted first, a failure would leave orphaned data with no recovery.

      // 1. Delete user from Supabase users table
      //    (cascades to related data via FK ON DELETE CASCADE where configured)
      await _supabase.from('users').delete().eq('id', userId);

      // 2. Handle conversations the user participated in
      final conversations = await _supabase
          .from('conversations')
          .select('id, participant_ids')
          .contains('participant_ids', [userId]);

      for (final conv in conversations) {
        final participants = List<String>.from(conv['participant_ids'] as List);
        if (participants.length <= 2) {
          await _supabase.from('conversations').delete().eq('id', conv['id'] as String);
        } else {
          participants.remove(userId);
          await _supabase
              .from('conversations')
              .update({'participant_ids': participants})
              .eq('id', conv['id'] as String);
        }
      }

      // 3. Remove user from groups they are a member of
      final groups = await _supabase
          .from('groups')
          .select('id, member_ids, created_by')
          .contains('member_ids', [userId]);

      for (final group in groups) {
        final memberIds = List<String>.from(group['member_ids'] as List);
        memberIds.remove(userId);
        if (group['created_by'] == userId && memberIds.isEmpty) {
          await _supabase.from('groups').delete().eq('id', group['id'] as String);
        } else {
          await _supabase
              .from('groups')
              .update({'member_ids': memberIds})
              .eq('id', group['id'] as String);
        }
      }

      // 4. Delete Firebase Auth user LAST
      try {
        await user.delete();
      } on FirebaseAuthException catch (e) {
        if (e.code == 'requires-recent-login') {
          // Rethrow this specific error so UI can handle reauthentication
          rethrow;
        }
        throw ServerException(_mapFirebaseAuthError(e.code));
      }

      // 5. Sign out from Google and Supabase
      await SupabaseAuthBridge.instance.signOut();
      await _googleSignIn.signOut();

      // 6. Security: clean up secure storage on account deletion
      await SecurePreferencesService.instance.clearAll();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        // Le code Firebase est conserve : c est lui qui doit declencher la
        // re-authentification en amont. Le message ne sert qu a l affichage
        // et ne doit jamais etre relu pour decider quoi que ce soit.
        throw AuthException(
          'Pour des raisons de sécurité, veuillez confirmer votre mot de passe',
          code: e.code,
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
    await SupabaseAuthBridge.instance.syncWithFirebase(user);
    try {
      await _upsertUserToSupabase(user, email: user.email);
    } catch (_) {}
    return _getUserDataFromSupabase(user);
  }

  @override
  Stream<UserModel?> get authStateChanges {
    return _firebaseAuth.authStateChanges().asyncMap((user) async {
      if (user == null) return null;
      await SupabaseAuthBridge.instance.syncWithFirebase(user);
      try {
        await _upsertUserToSupabase(user, email: user.email);
      } catch (_) {}
      return _getUserDataFromSupabase(user);
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

  Future<void> _upsertUserToSupabase(
    User user, {
    String? displayName,
    String? email,
    String? photoUrl,
  }) async {
    if (kDebugMode) dev.log('_upsertUserToSupabase: debut pour uid=${user.uid}', name: _tag);
    try {
      final ok = await SupabaseAuthBridge.instance.ensureAuthenticated();
      if (!ok) {
        throw Exception('Supabase session introuvable');
      }
      await _supabase.from('users').upsert({
        'id': user.uid,
        'email': email ?? user.email,
        'display_name': displayName ?? user.displayName,
        'avatar_url': photoUrl ?? user.photoURL,
        'phone_number': user.phoneNumber,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'id',);
      if (kDebugMode) dev.log('_upsertUserToSupabase: upsert effectue avec succes', name: _tag);
    } catch (e, stackTrace) {
      if (kDebugMode) dev.log('_upsertUserToSupabase: ERREUR ${e.toString()}', name: _tag, error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<UserModel> _getUserDataFromSupabase(User firebaseUser) async {
    if (kDebugMode) dev.log('_getUserDataFromSupabase: debut pour uid=${firebaseUser.uid}', name: _tag);
    try {
      final row = await _supabase
          .from('users')
          .select()
          .eq('id', firebaseUser.uid)
          .maybeSingle();

      if (kDebugMode) dev.log('_getUserDataFromSupabase: row trouvee=${row != null}', name: _tag);

      if (row != null) {
        // Supabase columns are snake_case; UserModel.fromJson expects camelCase.
        // Merge with Firebase Auth data so null Supabase fields fall back to
        // the values Firebase already knows about (email, displayName, photoUrl).
        final mapped = <String, dynamic>{
          'id': firebaseUser.uid,
          'email': row['email'] ?? firebaseUser.email,
          'displayName': row['display_name'] ?? firebaseUser.displayName,
          'photoUrl': row['avatar_url'] ?? firebaseUser.photoURL,
          'phoneNumber': row['phone_number'] ?? firebaseUser.phoneNumber,
          'createdAt': row['created_at'],
          'lastLoginAt': row['last_active_at'],
          'adminRole': row['admin_role'],
          'isBanned': row['is_banned'] ?? false,
          'banReason': row['ban_reason'],
          'bannedAt': row['banned_at'],
          'isVerified': row['is_verified'] ?? false,
        };
        final userModel = UserModel.fromJson(mapped);
        if (kDebugMode) dev.log('_getUserDataFromSupabase: UserModel cree depuis Supabase - id=${userModel.id}, email=${userModel.email}', name: _tag);
        return userModel;
      }

      // If row doesn't exist, fallback to Auth data
      if (kDebugMode) dev.log('_getUserDataFromSupabase: row non trouvee, fallback sur Auth data', name: _tag);
      return _mapFirebaseUserToModel(firebaseUser);
    } catch (e, stackTrace) {
      // Fallback if read fails
      if (kDebugMode) dev.log('_getUserDataFromSupabase: ERREUR ${e.toString()}, fallback sur Auth data', name: _tag, error: e, stackTrace: stackTrace);
      return _mapFirebaseUserToModel(firebaseUser);
    }
  }

  String _mapFirebaseAuthError(String code) {
    switch (code) {
      case 'user-not-found':
      case 'wrong-password':
        // Security: unified error message prevents user enumeration
        return 'Email ou mot de passe incorrect';
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

  @override
  Future<void> sendPhoneOtp(String phoneNumber) async {
    try {
      await SupabaseAuthBridge.instance.ensureAuthenticated();
      final response = await _supabase.functions.invoke(
        'send-phone-otp',
        body: {'phone_number': phoneNumber},
      );
      if (response.status != 200) {
        final error = (response.data as Map<String, dynamic>?)?['error'] as String?
            ?? 'Echec de l\'envoi du SMS';
        throw ServerException(error);
      }
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Echec de l\'envoi du code: ${e.toString()}');
    }
  }

  @override
  Future<void> verifyPhoneOtp({
    required String phoneNumber,
    required String code,
  }) async {
    try {
      await SupabaseAuthBridge.instance.ensureAuthenticated();
      final response = await _supabase.functions.invoke(
        'verify-phone-otp',
        body: {'phone_number': phoneNumber, 'code': code},
      );
      if (response.status != 200) {
        final error = (response.data as Map<String, dynamic>?)?['error'] as String?
            ?? 'Code invalide ou expiré';
        throw ServerException(error);
      }
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Echec de la verification: ${e.toString()}');
    }
  }
}
