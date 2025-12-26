import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/sign_in_with_email.dart';
import '../../domain/usecases/sign_in_with_google.dart';
import '../../domain/usecases/sign_up.dart';
import '../../domain/usecases/sign_out.dart';
import '../../../../core/services/session_service.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import 'auth_state.dart';

part 'auth_provider.g.dart';

@riverpod
AuthRepository authRepository(Ref ref) {
  final remoteDataSource = AuthRemoteDataSourceImpl(
    firebaseAuth: FirebaseAuth.instance,
    firestore: FirebaseFirestore.instance,
    googleSignIn: GoogleSignIn(),
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
class AuthNotifier extends _$AuthNotifier {
  @override
  AuthState build() {
    _checkCurrentUser();
    return const AuthState.initial();
  }

  Future<void> _checkCurrentUser() async {
    final repository = ref.read(authRepositoryProvider);
    final result = await repository.getCurrentUser();

    result.fold((failure) => state = const AuthState.unauthenticated(), (user) {
      if (user != null) {
        state = AuthState.authenticated(user);
        // Resume session monitoring
        SessionService.instance.initialize(user.id, isNewLogin: false);

        // Mettre à jour lastLoginAt pour que l'utilisateur apparaisse en ligne
        ref.read(profileRemoteDataSourceProvider).updateLastLogin(user.id);
      } else {
        state = const AuthState.unauthenticated();
      }
    });
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
      ref.read(profileRemoteDataSourceProvider).updateLastLogin(user.id);
    });
  }

  Future<void> signInWithGoogle() async {
    state = const AuthState.loading();

    final result = await ref.read(signInWithGoogleUseCaseProvider).call();

    result.fold((failure) => state = AuthState.error(failure.message), (user) {
      state = AuthState.authenticated(user);
      SessionService.instance.initialize(user.id, isNewLogin: true);
      ref.read(profileRemoteDataSourceProvider).updateLastLogin(user.id);
    });
  }

  Future<void> signUp(String email, String password, String displayName) async {
    state = const AuthState.loading();

    final result = await ref
        .read(signUpUseCaseProvider)
        .call(email: email, password: password, displayName: displayName);

    result.fold((failure) => state = AuthState.error(failure.message), (user) {
      state = AuthState.authenticated(user);
      SessionService.instance.initialize(user.id, isNewLogin: true);
    });
  }

  Future<void> signOut() async {
    SessionService.instance.dispose();
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
      (_) {
        SessionService.instance.dispose();
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
