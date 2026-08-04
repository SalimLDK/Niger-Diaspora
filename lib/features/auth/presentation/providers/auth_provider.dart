import 'dart:async';
import 'dart:developer' as dev;
import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../../core/errors/failures.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/sign_in_with_email.dart';
import '../../domain/usecases/sign_in_with_google.dart';
import '../../domain/usecases/sign_up.dart';
import '../../domain/usecases/sign_out.dart';
import '../../domain/usecases/send_password_reset_email.dart';
import '../../../../core/services/e2ee/e2ee_backup_coordinator.dart';
import '../../../../core/services/session_service.dart';
import '../../../../core/services/cache_service.dart';
import '../../../../core/services/file_download_service.dart';
import '../../../../core/services/preferences_service.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../onboarding/presentation/providers/onboarding_provider.dart';
import 'auth_state.dart';

part 'auth_provider.g.dart';

const String _tag = 'AuthProvider';

/// Accès au SDK Firebase Auth, isolé derrière un provider.
///
/// `FirebaseAuth.instance` est un singleton statique qui lève tant que
/// `Firebase.initializeApp()` n'a pas tourné : impossible de tester
/// [AuthNotifier] tant qu'il y était appelé en dur. Ce provider est le seul
/// point à surcharger dans un test.
@riverpod
FirebaseAuth firebaseAuth(Ref ref) => FirebaseAuth.instance;

@riverpod
AuthRepository authRepository(Ref ref) {
  final remoteDataSource = AuthRemoteDataSourceImpl(
    firebaseAuth: FirebaseAuth.instance,
    googleSignIn: GoogleSignIn.instance,
  );

  return AuthRepositoryImpl(remoteDataSource: remoteDataSource);
}

@riverpod
SignInWithEmail signInWithEmailUseCase(Ref ref) {
  return SignInWithEmail(ref.watch(authRepositoryProvider));
}

@riverpod
SignInWithGoogle signInWithGoogleUseCase(Ref ref) {
  return SignInWithGoogle(ref.watch(authRepositoryProvider));
}

@riverpod
SignUp signUpUseCase(Ref ref) {
  return SignUp(ref.watch(authRepositoryProvider));
}

@riverpod
SignOut signOutUseCase(Ref ref) {
  return SignOut(ref.watch(authRepositoryProvider));
}

@riverpod
SendPasswordResetEmail sendPasswordResetEmailUseCase(Ref ref) {
  return SendPasswordResetEmail(ref.watch(authRepositoryProvider));
}

@riverpod
class AuthNotifier extends _$AuthNotifier {
  /// Au-delà, on considère le profil serveur injoignable et on démarre sur la
  /// session Firebase locale. Le routeur maintient `/splash` tant que
  /// `isAuthLoading` : sans borne, un démarrage hors ligne y restait bloqué
  /// plus de deux minutes (constaté sur appareil le 2026-08-04).
  static const _profileTimeout = Duration(seconds: 8);

  bool _disposed = false;

  @override
  AuthState build() {
    ref.onDispose(() => _disposed = true);
    _initAuthState();
    return const AuthState.initial();
  }

  Future<void> _initAuthState() async {
    // Attendre que Firebase Auth restaure la session depuis le stockage local
    // authStateChanges émet immédiatement l'état actuel une fois Firebase prêt
    final firebaseUser =
        await ref.read(firebaseAuthProvider).authStateChanges().first;

    if (firebaseUser == null) {
      state = const AuthState.unauthenticated();
      return;
    }

    // Utilisateur Firebase trouvé, récupérer les données complètes depuis Firestore
    await _loadUserData(firebaseUser.uid);
  }

  /// Amorce le Signal Protocol pour [userId] via le coordinateur E2EE.
  ///
  /// Le coordinateur décide s'il faut initialiser, proposer une sauvegarde
  /// (clés neuves) ou une restauration (backup distant existant) — sans jamais
  /// écraser une identité restaurable. Best-effort et non bloquant : en cas
  /// d'échec, les envois retombent sur le repli AES prévu par l'architecture
  /// plutôt que d'empêcher la connexion.
  void _initializeE2EE(String userId) {
    ref
        .read(e2eeBackupCoordinatorProvider.notifier)
        .bootstrap(userId)
        .catchError((Object e) => dev.log('E2EE bootstrap failed: $e'));
  }

  Future<void> _loadUserData(String userId) async {
    final repository = ref.read(authRepositoryProvider);
    // `getCurrentUser()` enchaîne trois allers-retours Supabase (échange du
    // jeton Firebase, upsert du compte, lecture du profil). Hors ligne, aucun
    // ne rend la main : c'est là que se jouaient les deux minutes de splash.
    final pending = repository.getCurrentUser();
    final Either<Failure, UserEntity?> result;
    try {
      result = await pending.timeout(_profileTimeout);
    } on TimeoutException {
      _startFromLocalSession();
      // La requête n'est pas annulée par `timeout` : si elle finit par
      // aboutir (réseau revenu), le profil complet remplacera de lui-même la
      // session minimale, sans second appel ni action de l'utilisateur.
      //
      // Une réponse tardive en ÉCHEC, elle, est ignorée : `_applyUser`
      // basculerait sur `unauthenticated` et jetterait dehors quelqu'un déjà
      // entré dans l'app. La décision a été prise à l'expiration.
      unawaited(
        pending
            .then((late) => late.fold((_) {}, (user) {
                  if (user != null) _applyUser(late);
                }))
            .catchError((Object _) {}),
      );
      return;
    }
    _applyUser(result);
  }

  /// Démarre sur ce que la session Firebase locale nous apprend, faute de
  /// pouvoir joindre le profil serveur.
  ///
  /// On ne bascule surtout pas sur `unauthenticated` : le routeur enverrait
  /// vers `/auth/login`, or se reconnecter exige le réseau — précisément ce
  /// qui manque. L'utilisateur se retrouverait dehors sans pouvoir rentrer.
  void _startFromLocalSession() {
    // Appelé après un délai : le notifier peut avoir été détruit entre-temps,
    // et `ref.read` sur un conteneur disposé lève.
    if (_disposed) return;
    final firebaseUser = ref.read(firebaseAuthProvider).currentUser;
    if (firebaseUser == null) {
      _setState(const AuthState.unauthenticated());
      return;
    }
    dev.log('$_tag: profil serveur injoignable, démarrage sur la session locale');
    _setState(
      AuthState.authenticated(
        UserEntity(
          id: firebaseUser.uid,
          email: firebaseUser.email,
          displayName: firebaseUser.displayName,
          photoUrl: firebaseUser.photoURL,
          phoneNumber: firebaseUser.phoneNumber,
          // `adminRole` reste `none` : aucun privilège n'est accordé sur la
          // seule foi d'une session locale, il faut le profil serveur.
        ),
      ),
    );
    // Consentement, onboarding, config de profil : tout est en
    // SharedPreferences, donc lisible hors ligne. Sans ce refresh, le routeur
    // resterait sur /splash à l'étape `onboardingState.isLoading`.
    ref.read(onboardingNotifierProvider.notifier).refresh();
  }

  /// Peut être appelé tardivement (requête revenue après l'expiration), donc
  /// après la destruction du notifier : écrire `state` lèverait alors.
  void _setState(AuthState next) {
    if (_disposed) return;
    state = next;
  }

  void _applyUser(Either<Failure, UserEntity?> result) {
    if (_disposed) return;
    result.fold((failure) => state = const AuthState.unauthenticated(), (user) {
      if (user != null) {
        state = AuthState.authenticated(user);
        // Resume session monitoring
        SessionService.instance.initialize(user.id, isNewLogin: false);

        // Initialise le Signal Protocol pour cet utilisateur. SANS CET APPEL,
        // `MessagingE2EEService.isInitialized` reste faux et _encryptContent
        // rejette TOUT message texte avec « Chiffrement E2EE non disponible » :
        // le service était construit par son provider mais jamais initialisé.
        // Best-effort : un échec ne doit pas bloquer la connexion, les envois
        // retomberont sur le repli AES prévu par l'architecture.
        _initializeE2EE(user.id);

        // Mettre à jour lastLoginAt pour que l'utilisateur apparaisse en ligne
        ref.read(profileRemoteDataSourceProvider).updateLastLogin(user.id);

        // Refresh onboarding status now that user is authenticated
        ref.read(onboardingNotifierProvider.notifier).refresh();
      } else {
        state = const AuthState.unauthenticated();
      }
    });
  }

  Future<void> _checkCurrentUser() async {
    await _loadUserData(ref.read(firebaseAuthProvider).currentUser!.uid);
  }

  /// Refresh user data from Firebase Auth without invalidating the provider
  /// This is called after profile updates to sync displayName and photoUrl
  Future<void> refreshUserData() async {
    await _checkCurrentUser();
  }

  Future<void> signInWithEmail(String email, String password) async {
    state = const AuthState.loading();

    final result = await ref
        .read(signInWithEmailUseCaseProvider)
        .call(email: email, password: password);

    result.fold((failure) => state = AuthState.error(failure.message), (user) {
      state = AuthState.authenticated(user);
      SessionService.instance.initialize(user.id, isNewLogin: true);
      _initializeE2EE(user.id);
      ref.read(profileRemoteDataSourceProvider).updateLastLogin(user.id);
      // Refresh onboarding status now that user is authenticated
      ref.read(onboardingNotifierProvider.notifier).refresh();
    });
  }

  Future<void> signInWithGoogle() async {
    dev.log('=== AuthNotifier.signInWithGoogle: DEBUT ===', name: _tag);
    state = const AuthState.loading();
    dev.log('AuthNotifier.signInWithGoogle: state = loading', name: _tag);

    try {
      dev.log('AuthNotifier.signInWithGoogle: appel du use case...', name: _tag);
      final result = await ref.read(signInWithGoogleUseCaseProvider).call();
      dev.log('AuthNotifier.signInWithGoogle: use case termine', name: _tag);

      result.fold(
        (failure) {
          dev.log('AuthNotifier.signInWithGoogle: ECHEC - ${failure.message}', name: _tag);
          state = AuthState.error(failure.message);
        },
        (user) {
          dev.log('AuthNotifier.signInWithGoogle: SUCCES - user.id=${user.id}, email=${user.email}', name: _tag);
          state = AuthState.authenticated(user);
          dev.log('AuthNotifier.signInWithGoogle: state = authenticated', name: _tag);
          SessionService.instance.initialize(user.id, isNewLogin: true);
          _initializeE2EE(user.id);
          dev.log('AuthNotifier.signInWithGoogle: SessionService initialise', name: _tag);
          ref.read(profileRemoteDataSourceProvider).updateLastLogin(user.id);
          dev.log('AuthNotifier.signInWithGoogle: lastLogin mis a jour', name: _tag);
          // Refresh onboarding status now that user is authenticated
          ref.read(onboardingNotifierProvider.notifier).refresh();
          dev.log('=== AuthNotifier.signInWithGoogle: FIN SUCCES ===', name: _tag);
        },
      );
    } catch (e, stackTrace) {
      dev.log('AuthNotifier.signInWithGoogle: EXCEPTION - ${e.toString()}', name: _tag, error: e, stackTrace: stackTrace);
      state = AuthState.error('Erreur inattendue: ${e.toString()}');
    }
  }

  Future<void> signUp(String email, String password, String displayName) async {
    state = const AuthState.loading();

    final result = await ref
        .read(signUpUseCaseProvider)
        .call(email: email, password: password, displayName: displayName);

    result.fold((failure) => state = AuthState.error(failure.message), (user) {
      state = AuthState.authenticated(user);
      SessionService.instance.initialize(user.id, isNewLogin: true);
      _initializeE2EE(user.id);
    });
  }

  Future<void> signOut() async {
    SessionService.instance.dispose();

    // Vider le cache local pour éviter les données obsolètes
    await CacheService.instance.clearAllCache();
    // …et ce que la personne a écrit ou accumulé dans les préférences
    // (brouillons, hashtags suivis…) : aucune de ces clés ne porte d'uid, le
    // compte suivant sur ce téléphone en héritait.
    await PreferencesService.instance.clearUserData();
    // …et les pieces jointes telechargees, en clair sur le disque, avec leur
    // index `media_dl_<messageId>` (cles dynamiques, hors de clearUserData).
    await FileDownloadService().clearDownloadedFiles();

    final result = await ref.read(signOutUseCaseProvider).call();

    result.fold(
      (failure) => state = AuthState.error(failure.message),
      (_) => state = const AuthState.unauthenticated(),
    );
  }

  Future<bool> deleteAccount() async {
    final repository = ref.read(authRepositoryProvider);

    // Try to delete account
    final result = await repository.deleteAccount();

    return result.fold(
      (failure) {
        // Check if reauthentication is required
        if (failure.message.contains('mot de passe') ||
            failure.message.contains('sécurité')) {
          // Reauthentication needed - set a special error state
          state = AuthState.error('REAUTH_REQUIRED:${failure.message}');
          return false;
        }
        state = AuthState.error(failure.message);
        return false;
      },
      (_) async {
        SessionService.instance.dispose();
        await CacheService.instance.clearAllCache();
        await PreferencesService.instance.clearUserData();
        await FileDownloadService().clearDownloadedFiles();
        state = const AuthState.unauthenticated();
        return true;
      },
    );
  }

  Future<bool> reauthenticateAndDelete(String password) async {
    final repository = ref.read(authRepositoryProvider);

    // First reauthenticate
    final reauth = await repository.reauthenticateWithPassword(password);

    final reauthSuccess = reauth.fold((failure) {
      state = AuthState.error(failure.message);
      return false;
    }, (_) => true);

    if (!reauthSuccess) return false;

    // Then try to delete again
    return deleteAccount();
  }

  Future<void> sendPasswordResetEmail(String email) async {
    // Note: We don't set loading state here to avoid disrupting the UI state too much
    // or we could use a separate state if needed, but for now we just return the result
    // actually, let's keep it simple and just make the call.
    // The UI can handle its own loading state or we can add it here if we want to block the UI.
    // Let's rely on the UI to show a loader because we don't want to change the whole auth state
    // just for a password reset email request which might happen when unauthenticated.

    final result = await ref
        .read(sendPasswordResetEmailUseCaseProvider)
        .call(email);

    return result.fold(
      (failure) => throw Exception(failure.message),
      (_) => null,
    );
  }
}

@riverpod
Stream<UserEntity?> currentUser(Ref ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
}

/// StreamProvider wrapper for easy AsyncValue access to current user
@riverpod
Stream<UserEntity?> currentUserAsync(Ref ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
}
