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
    _loadOnboardingStatus();
    return const OnboardingState();
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

      // Load consent and profile config status from Firestore
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();

        if (userDoc.exists) {
          final data = userDoc.data();
          hasGivenConsent = data?['hasGivenConsent'] == true;
          profileConfigComplete = data?['profileConfigComplete'] == true;
        }
      } catch (_) {
        // Silently fail, defaults remain false
      }

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
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .set({
          'hasGivenConsent': true,
          'consentDate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      state = state.copyWith(hasGivenConsent: true);
    } catch (e) {
      // Still update local state
      state = state.copyWith(hasGivenConsent: true);
    }
  }

  Future<void> markProfileConfigComplete() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .set({
          'profileConfigComplete': true,
        }, SetOptions(merge: true));
      }
      state = state.copyWith(profileConfigComplete: true);
    } catch (e) {
      // Still update local state
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
