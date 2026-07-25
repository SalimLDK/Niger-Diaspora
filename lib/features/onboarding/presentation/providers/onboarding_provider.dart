import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/datasources/onboarding_local_datasource.dart';
import '../../data/datasources/onboarding_remote_datasource.dart';
import '../../data/repositories/onboarding_repository_impl.dart';
import '../../domain/repositories/onboarding_repository.dart';
import 'onboarding_state.dart';

part 'onboarding_provider.g.dart';

@riverpod
Future<OnboardingRepository> onboardingRepository(Ref ref) async {
  final prefs = await SharedPreferences.getInstance();

  final localDataSource = OnboardingLocalDataSourceImpl(prefs: prefs);
  final remoteDataSource = OnboardingRemoteDataSourceImpl(
    firestore: FirebaseFirestore.instance,
    auth: FirebaseAuth.instance,
  );

  return OnboardingRepositoryImpl(
    localDataSource: localDataSource,
    remoteDataSource: remoteDataSource,
    firebaseAuth: FirebaseAuth.instance,
  );
}

@riverpod
class OnboardingNotifier extends _$OnboardingNotifier {
  @override
  OnboardingState build() {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      _loadOnboardingStatus();
    }

    _listenToAuthChanges();

    return const OnboardingState();
  }

  void _listenToAuthChanges() {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _loadOnboardingStatus();
      }
    });
  }

  Future<void> _loadOnboardingStatus() async {
    try {
      // Wait for Firebase Auth to be ready
      final currentUser = FirebaseAuth.instance.currentUser;

      // If no user yet, stay in loading state - will be refreshed when auth changes
      if (currentUser == null) {
        return;
      }

      final repository = await ref.read(onboardingRepositoryProvider.future);

      final hasSeenOnboardingResult = await repository.hasSeenOnboarding();
      final hasSeenCoachMarksResult = await repository.hasSeenCoachMarks();
      final hasGivenConsentResult = await repository.hasGivenConsent();
      final hasCompletedProfileConfigResult =
          await repository.hasCompletedProfileConfig();

      bool hasSeenOnboarding = false;
      bool hasSeenCoachMarks = false;
      bool hasGivenConsent = false;
      bool profileConfigComplete = false;

      hasSeenOnboardingResult.fold(
        (failure) => hasSeenOnboarding = false,
        (value) => hasSeenOnboarding = value,
      );

      hasSeenCoachMarksResult.fold(
        (failure) => hasSeenCoachMarks = false,
        (value) => hasSeenCoachMarks = value,
      );

      hasGivenConsentResult.fold(
        (failure) => hasGivenConsent = false,
        (value) => hasGivenConsent = value,
      );

      hasCompletedProfileConfigResult.fold(
        (failure) => profileConfigComplete = false,
        (value) => profileConfigComplete = value,
      );

      state = state.copyWith(
        hasSeenIntro: hasSeenOnboarding,
        hasSeenCoachMarks: hasSeenCoachMarks,
        hasGivenConsent: hasGivenConsent,
        profileConfigComplete: profileConfigComplete,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> completeIntro() async {
    try {
      final repository = await ref.read(onboardingRepositoryProvider.future);
      await repository.markOnboardingComplete();
      state = state.copyWith(hasSeenIntro: true);
    } catch (e) {
      // Still update local state even if remote fails
      state = state.copyWith(hasSeenIntro: true);
    }
  }

  Future<void> completeCoachMarks() async {
    try {
      final repository = await ref.read(onboardingRepositoryProvider.future);
      await repository.markCoachMarksComplete();
      state = state.copyWith(hasSeenCoachMarks: true);
    } catch (e) {
      state = state.copyWith(hasSeenCoachMarks: true);
    }
  }

  Future<void> skipAll() async {
    await completeIntro();
    await completeCoachMarks();
  }

  Future<void> markConsentGiven() async {
    try {
      final repository = await ref.read(onboardingRepositoryProvider.future);
      await repository.markConsentGiven();
      state = state.copyWith(hasGivenConsent: true);
    } catch (e) {
      state = state.copyWith(hasGivenConsent: true);
    }
  }

  Future<void> markProfileConfigComplete() async {
    try {
      final repository = await ref.read(onboardingRepositoryProvider.future);
      await repository.markProfileConfigComplete();
      state = state.copyWith(profileConfigComplete: true);
    } catch (e) {
      state = state.copyWith(profileConfigComplete: true);
    }
  }

  void setCurrentPage(int page) {
    state = state.copyWith(currentPage: page);
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    await _loadOnboardingStatus();
  }
}
