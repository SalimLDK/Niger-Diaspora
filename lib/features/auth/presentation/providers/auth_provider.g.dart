// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$firebaseAuthHash() => r'8f84097cccd00af817397c1715c5f537399ba780';

/// Accès au SDK Firebase Auth, isolé derrière un provider.
///
/// `FirebaseAuth.instance` est un singleton statique qui lève tant que
/// `Firebase.initializeApp()` n'a pas tourné : impossible de tester
/// [AuthNotifier] tant qu'il y était appelé en dur. Ce provider est le seul
/// point à surcharger dans un test.
///
/// Copied from [firebaseAuth].
@ProviderFor(firebaseAuth)
final firebaseAuthProvider = AutoDisposeProvider<FirebaseAuth>.internal(
  firebaseAuth,
  name: r'firebaseAuthProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$firebaseAuthHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef FirebaseAuthRef = AutoDisposeProviderRef<FirebaseAuth>;
String _$authRepositoryHash() => r'f93e100ab001d68de91839bb5d12400ac5f5ba9a';

/// See also [authRepository].
@ProviderFor(authRepository)
final authRepositoryProvider = AutoDisposeProvider<AuthRepository>.internal(
  authRepository,
  name: r'authRepositoryProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$authRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AuthRepositoryRef = AutoDisposeProviderRef<AuthRepository>;
String _$signInWithEmailUseCaseHash() =>
    r'460a61e793a9e338771390265a3c56e36ab2578e';

/// See also [signInWithEmailUseCase].
@ProviderFor(signInWithEmailUseCase)
final signInWithEmailUseCaseProvider =
    AutoDisposeProvider<SignInWithEmail>.internal(
      signInWithEmailUseCase,
      name: r'signInWithEmailUseCaseProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$signInWithEmailUseCaseHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SignInWithEmailUseCaseRef = AutoDisposeProviderRef<SignInWithEmail>;
String _$signInWithGoogleUseCaseHash() =>
    r'6001dd6f5babe8a3a80b9160392511ac27a1eed7';

/// See also [signInWithGoogleUseCase].
@ProviderFor(signInWithGoogleUseCase)
final signInWithGoogleUseCaseProvider =
    AutoDisposeProvider<SignInWithGoogle>.internal(
      signInWithGoogleUseCase,
      name: r'signInWithGoogleUseCaseProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$signInWithGoogleUseCaseHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SignInWithGoogleUseCaseRef = AutoDisposeProviderRef<SignInWithGoogle>;
String _$signUpUseCaseHash() => r'4dce6a82e98236d7e035a5d98ba2c80590b0e9f2';

/// See also [signUpUseCase].
@ProviderFor(signUpUseCase)
final signUpUseCaseProvider = AutoDisposeProvider<SignUp>.internal(
  signUpUseCase,
  name: r'signUpUseCaseProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$signUpUseCaseHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SignUpUseCaseRef = AutoDisposeProviderRef<SignUp>;
String _$signOutUseCaseHash() => r'b625f35bebc61e8c1a7e7d0f6b3ba99912b8d1fc';

/// See also [signOutUseCase].
@ProviderFor(signOutUseCase)
final signOutUseCaseProvider = AutoDisposeProvider<SignOut>.internal(
  signOutUseCase,
  name: r'signOutUseCaseProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$signOutUseCaseHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SignOutUseCaseRef = AutoDisposeProviderRef<SignOut>;
String _$sendPasswordResetEmailUseCaseHash() =>
    r'771eadae47d686e92afc4d9c2a1119ceffe9038d';

/// See also [sendPasswordResetEmailUseCase].
@ProviderFor(sendPasswordResetEmailUseCase)
final sendPasswordResetEmailUseCaseProvider =
    AutoDisposeProvider<SendPasswordResetEmail>.internal(
      sendPasswordResetEmailUseCase,
      name: r'sendPasswordResetEmailUseCaseProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$sendPasswordResetEmailUseCaseHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SendPasswordResetEmailUseCaseRef =
    AutoDisposeProviderRef<SendPasswordResetEmail>;
String _$currentUserHash() => r'3578808cf73813fa908cac5fce6872262b34aae2';

/// See also [currentUser].
@ProviderFor(currentUser)
final currentUserProvider = AutoDisposeStreamProvider<UserEntity?>.internal(
  currentUser,
  name: r'currentUserProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$currentUserHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CurrentUserRef = AutoDisposeStreamProviderRef<UserEntity?>;
String _$currentUserAsyncHash() => r'fd1f558df99b1ac6354201ad736d9aba8a65cdfc';

/// StreamProvider wrapper for easy AsyncValue access to current user
///
/// Copied from [currentUserAsync].
@ProviderFor(currentUserAsync)
final currentUserAsyncProvider =
    AutoDisposeStreamProvider<UserEntity?>.internal(
      currentUserAsync,
      name: r'currentUserAsyncProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$currentUserAsyncHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CurrentUserAsyncRef = AutoDisposeStreamProviderRef<UserEntity?>;
String _$authNotifierHash() => r'122d876dab3e8c3b68ea7044f88d6b4bc7dd5418';

/// See also [AuthNotifier].
@ProviderFor(AuthNotifier)
final authNotifierProvider =
    AutoDisposeNotifierProvider<AuthNotifier, AuthState>.internal(
      AuthNotifier.new,
      name: r'authNotifierProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$authNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$AuthNotifier = AutoDisposeNotifier<AuthState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
