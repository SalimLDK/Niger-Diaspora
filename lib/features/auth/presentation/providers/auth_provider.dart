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

    result.fold(
      (failure) => state = AuthState.error(failure.message),
      (user) => state = AuthState.authenticated(user),
    );
  }

  Future<void> signInWithGoogle() async {
    state = const AuthState.loading();

    final result = await ref.read(signInWithGoogleUseCaseProvider).call();

    result.fold(
      (failure) => state = AuthState.error(failure.message),
      (user) => state = AuthState.authenticated(user),
    );
  }

  Future<void> signUp(String email, String password, String displayName) async {
    state = const AuthState.loading();

    final result = await ref
        .read(signUpUseCaseProvider)
        .call(email: email, password: password, displayName: displayName);

    result.fold(
      (failure) => state = AuthState.error(failure.message),
      (user) => state = AuthState.authenticated(user),
    );
  }

  Future<void> signOut() async {
    final result = await ref.read(signOutUseCaseProvider).call();

    result.fold(
      (failure) => state = AuthState.error(failure.message),
      (_) => state = const AuthState.unauthenticated(),
    );
  }

  Future<bool> deleteAccount() async {
    state = const AuthState.loading();

    final repository = ref.read(authRepositoryProvider);
    final result = await repository.deleteAccount();

    return result.fold(
      (failure) {
        state = AuthState.error(failure.message);
        return false;
      },
      (_) {
        state = const AuthState.unauthenticated();
        return true;
      },
    );
  }
}

@riverpod
Stream<UserEntity?> currentUser(Ref ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
}
