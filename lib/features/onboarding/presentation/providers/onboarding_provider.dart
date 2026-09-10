import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/errors/failures.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
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
  /// Ce qu'on retient d'un drapeau quand la lecture n'établit rien.
  ///
  /// **Un échec de lecture n'est pas « jamais vu ».** Les quatre drapeaux
  /// repliaient sur `false`, ce qui rejouait tout l'onboarding d'un compte
  /// qui l'avait terminé — dans l'ordre du routeur (étapes 6, 7, 8) : le
  /// consentement, qui réécrit `consent_date` par-dessus la date réelle ;
  /// l'assistant de profil en 4 étapes, qui **écrit dans le profil et peut
  /// renommer le compte** ; puis les cinq écrans d'intro.
  ///
  /// Ce n'est pas un cas de bord : `ensureReadableSession` rend la main au
  /// bout de 3 s sans session, en laissant la synchronisation finir en tâche
  /// de fond. Un démarrage à froid sur réseau lent dépasse ce budget, et les
  /// quatre drapeaux tombaient ensemble.
  ///
  /// Le repli est donc « ne rien imposer ». Se tromper de ce côté-là coûte
  /// cinq écrans d'intro qu'un nouveau venu ne verra pas ; se tromper de
  /// l'autre côté réécrit son profil. Et le repli n'est jamais mémorisé, ni
  /// en local ni en base (cf. `OnboardingRepositoryImpl._lireDrapeau`) : la
  /// première lecture qui aboutit corrige l'état, y compris vers `false`.
  static const bool _repliSiIndetermine = true;

  /// Délai avant la reprise d'une lecture indéterminée. Assez long pour que la
  /// synchronisation Supabase lancée en tâche de fond ait abouti.
  @visibleForTesting
  static Duration delaiDeReprise = const Duration(seconds: 4);

  /// Vrai une fois le notifier disposé : une reprise en vol ne doit pas
  /// écrire dans un `state` mort.
  bool _dispose = false;

  /// La reprise n'a lieu qu'une fois par instance.
  bool _repriseFaite = false;

  @override
  OnboardingState build() {
    // Passe par le provider (et non `FirebaseAuth.instance`) pour rester
    // testable : cf. `firebaseAuthProvider`.
    final user = ref.read(firebaseAuthProvider).currentUser;

    ref.onDispose(() => _dispose = true);

    if (user != null) {
      _loadOnboardingStatus();
    }

    _listenToAuthChanges();

    // Tant qu'aucune lecture n'a abouti, on n'impose rien — même repli que
    // ci-dessus, et il compte : le `catch` de `_loadOnboardingStatus` lève
    // `isLoading` sans avoir rien lu, ce qui rend ces valeurs visibles au
    // routeur. `isLoading` reste vrai ici, l'étape 3 tient donc /splash.
    return const OnboardingState(
      hasSeenIntro: _repliSiIndetermine,
      hasSeenCoachMarks: _repliSiIndetermine,
      hasGivenConsent: _repliSiIndetermine,
      profileConfigComplete: _repliSiIndetermine,
    );
  }

  void _listenToAuthChanges() {
    ref.read(firebaseAuthProvider).authStateChanges().listen((user) {
      if (user != null) {
        _loadOnboardingStatus();
      }
    });
  }

  Future<void> _loadOnboardingStatus({bool reprise = false}) async {
    try {
      // Wait for Firebase Auth to be ready
      final currentUser = ref.read(firebaseAuthProvider).currentUser;

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

      var indetermine = false;

      // Un `Left` ne dit pas « pas fait », il dit « je n'ai pas pu savoir ».
      // On garde alors ce qu'on tenait déjà — la valeur d'une lecture qui,
      // elle, avait abouti, et à défaut `_repliSiIndetermine`.
      bool lire(Either<Failure, bool> resultat, bool valeurTenue) =>
          resultat.fold((_) {
            indetermine = true;
            return valeurTenue;
          }, (value) => value);

      // Les quatre lectures sont asynchrones : le notifier a pu être détruit
      // pendant. Écrire dans un `state` mort lève, et la levée retomberait
      // dans le `catch` ci-dessous, qui écrit lui aussi dans `state`.
      if (_dispose) return;

      state = state.copyWith(
        hasSeenIntro: lire(hasSeenOnboardingResult, state.hasSeenIntro),
        hasSeenCoachMarks: lire(
          hasSeenCoachMarksResult,
          state.hasSeenCoachMarks,
        ),
        hasGivenConsent: lire(hasGivenConsentResult, state.hasGivenConsent),
        profileConfigComplete: lire(
          hasCompletedProfileConfigResult,
          state.profileConfigComplete,
        ),
        isLoading: false,
      );

      // Une lecture indéterminée, c'est presque toujours le pont Supabase pas
      // encore prêt ; sa synchronisation continue en tâche de fond et profite
      // à l'appelant suivant. Une seule reprise suffit donc au cas courant —
      // et surtout, elle referme la fenêtre où un compte *neuf* franchirait le
      // consentement sur la foi du repli optimiste. `isLoading` est déjà levé :
      // on ne retient pas /splash pendant ce temps, et si la reprise corrige un
      // drapeau, le `ref.listen` du routeur le renverra sur le bon écran.
      if (indetermine && !reprise && !_repriseFaite) {
        _repriseFaite = true;
        await Future<void>.delayed(delaiDeReprise);
        if (_dispose) return;
        await _loadOnboardingStatus(reprise: true);
      }
    } catch (e) {
      if (_dispose) return;
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
