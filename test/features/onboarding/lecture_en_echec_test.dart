import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/core/errors/exceptions.dart';
import 'package:diaspo_niger/core/errors/failures.dart';
import 'package:diaspo_niger/features/auth/presentation/providers/auth_provider.dart';
import 'package:diaspo_niger/features/onboarding/data/datasources/onboarding_local_datasource.dart';
import 'package:diaspo_niger/features/onboarding/data/datasources/onboarding_remote_datasource.dart';
import 'package:diaspo_niger/features/onboarding/data/repositories/onboarding_repository_impl.dart';
import 'package:diaspo_niger/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:diaspo_niger/features/onboarding/presentation/providers/onboarding_provider.dart';
import 'package:diaspo_niger/features/onboarding/presentation/providers/onboarding_state.dart';

/// Une lecture en échec n'est pas « jamais vu ».
///
/// Les quatre drapeaux d'onboarding se lisaient en repliant sur `false` à la
/// moindre contrariété — `fold((failure) => x = false, ...)` côté notifier, et
/// deux `return false` de plus en amont dans `OnboardingRemoteDataSourceImpl`.
/// Or `false` n'est pas une valeur neutre ici : c'est l'ordre de tout rejouer,
/// dans l'ordre du routeur (étapes 6, 7, 8) — le consentement, qui réécrit
/// `consent_date` par-dessus la date réelle ; l'assistant de profil en 4
/// étapes, qui écrit dans le profil et peut renommer le compte ; puis les
/// cinq écrans d'intro.
///
/// Le déclencheur n'a rien de théorique : `ensureReadableSession` rend la main
/// au bout de 3 s **sans** session, en laissant la synchronisation Supabase
/// finir en tâche de fond. Un démarrage à froid sur réseau lent dépasse ce
/// budget, et les quatre drapeaux tombaient ensemble.
///
/// Ce que ces tests fixent :
/// - une lecture indéterminée remonte en `Left`, jamais en `Right(false)` ;
/// - un `Left` ne fait jamais redescendre un drapeau ;
/// - un `false` **lu** reste un `false` — l'onboarding d'un compte neuf n'est
///   pas sacrifié au passage.
class _FauxUtilisateur implements User {
  @override
  String get uid => 'u1';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FauxFirebaseAuth implements FirebaseAuth {
  _FauxFirebaseAuth(this._user);

  final User? _user;

  @override
  User? get currentUser => _user;

  @override
  Stream<User?> authStateChanges() => Stream<User?>.value(_user);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Dépôt local en mémoire, fidèle sur le point qui compte : il ne rend `true`
/// que pour ce qui y a été explicitement écrit.
class _FauxLocal implements OnboardingLocalDataSource {
  final Set<String> ecrits = <String>{};

  bool _lu(String cle) => ecrits.contains(cle);
  Future<void> _ecrire(String cle) async => ecrits.add(cle);

  @override
  Future<bool> hasSeenOnboarding(String userId) async => _lu('intro');
  @override
  Future<void> setOnboardingComplete(String userId) => _ecrire('intro');
  @override
  Future<bool> hasSeenCoachMarks(String userId) async => _lu('coach');
  @override
  Future<void> setCoachMarksComplete(String userId) => _ecrire('coach');
  @override
  Future<bool> hasGivenConsent(String userId) async => _lu('consent');
  @override
  Future<void> setConsentGiven(String userId) => _ecrire('consent');
  @override
  Future<bool> hasCompletedProfileConfig(String userId) async => _lu('profil');
  @override
  Future<void> setProfileConfigComplete(String userId) => _ecrire('profil');
}

/// Réponse distante d'un drapeau : une valeur, un `null` (indéterminé), ou une
/// exception.
class _Reponse {
  const _Reponse.valeur(this.valeur) : leve = false;
  const _Reponse.indetermine() : valeur = null, leve = false;
  const _Reponse.exception() : valeur = null, leve = true;

  final bool? valeur;
  final bool leve;

  Future<bool?> rendre(String nom) async {
    if (leve) throw ServerException('Erreur lors de la lecture de $nom');
    return valeur;
  }
}

/// Source distante dont chaque drapeau s'arme individuellement : les tests
/// vérifient un drapeau à la fois, les trois autres restant nominaux.
class _FauxDistant implements OnboardingRemoteDataSource {
  _Reponse intro = const _Reponse.valeur(true);
  _Reponse coach = const _Reponse.valeur(true);
  _Reponse consent = const _Reponse.valeur(true);
  _Reponse profil = const _Reponse.valeur(true);

  @override
  Future<bool?> hasSeenOnboarding() => intro.rendre('has_seen_onboarding');
  @override
  Future<bool?> hasSeenCoachMarks() => coach.rendre('has_seen_coach_marks');
  @override
  Future<bool?> hasGivenConsent() => consent.rendre('has_given_consent');
  @override
  Future<bool?> hasCompletedProfileConfig() =>
      profil.rendre('profile_config_complete');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Dépôt de haut niveau piloté drapeau par drapeau, pour les tests du
/// notifier. Chaque drapeau consomme sa file de réponses ; la dernière se
/// répète, ce qui laisse la reprise interne du notifier se dérouler.
class _FauxDepot implements OnboardingRepository {
  _FauxDepot({
    List<Either<Failure, bool>>? intro,
    List<Either<Failure, bool>>? coach,
    List<Either<Failure, bool>>? consent,
    List<Either<Failure, bool>>? profil,
  }) : _intro = intro ?? [const Right(true)],
       _coach = coach ?? [const Right(true)],
       _consent = consent ?? [const Right(true)],
       _profil = profil ?? [const Right(true)];

  final List<Either<Failure, bool>> _intro;
  final List<Either<Failure, bool>> _coach;
  final List<Either<Failure, bool>> _consent;
  final List<Either<Failure, bool>> _profil;

  Either<Failure, bool> _suivant(List<Either<Failure, bool>> file) =>
      file.length == 1 ? file.first : file.removeAt(0);

  @override
  Future<Either<Failure, bool>> hasSeenOnboarding() async => _suivant(_intro);
  @override
  Future<Either<Failure, bool>> hasSeenCoachMarks() async => _suivant(_coach);
  @override
  Future<Either<Failure, bool>> hasGivenConsent() async => _suivant(_consent);
  @override
  Future<Either<Failure, bool>> hasCompletedProfileConfig() async =>
      _suivant(_profil);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const echec = Left<Failure, bool>(ServerFailure('indetermine'));

  /// L'écran que le routeur imposerait, tel que `app_router.dart` le décide
  /// (étapes 6, 7 puis 8). Recopié plutôt que le routeur monté en entier :
  /// c'est cette suite d'`if` que la régression traversait, et l'ordre y est
  /// la moitié du sujet.
  String? ecranImpose(OnboardingState s) {
    if (!s.hasGivenConsent) return '/consent';
    if (!s.profileConfigComplete) return '/profile-config';
    if (!s.hasSeenIntro) return '/onboarding/intro';
    return null;
  }

  group('depot : une lecture indeterminee remonte en Left', () {
    OnboardingRepositoryImpl depot(_FauxDistant distant, _FauxLocal local) =>
        OnboardingRepositoryImpl(
          localDataSource: local,
          remoteDataSource: distant,
          firebaseAuth: _FauxFirebaseAuth(_FauxUtilisateur()),
        );

    /// Les quatre drapeaux, chacun avec sa lecture et le crochet qui arme sa
    /// réponse distante — pour que chaque cas soit vérifié quatre fois plutôt
    /// qu'une fois sur le premier venu.
    final drapeaux = <String, ({
      Future<Either<Failure, bool>> Function(OnboardingRepository) lire,
      void Function(_FauxDistant, _Reponse) armer,
      String cleLocale,
    })>{
      'has_seen_onboarding': (
        lire: (d) => d.hasSeenOnboarding(),
        armer: (d, r) => d.intro = r,
        cleLocale: 'intro',
      ),
      'has_seen_coach_marks': (
        lire: (d) => d.hasSeenCoachMarks(),
        armer: (d, r) => d.coach = r,
        cleLocale: 'coach',
      ),
      'has_given_consent': (
        lire: (d) => d.hasGivenConsent(),
        armer: (d, r) => d.consent = r,
        cleLocale: 'consent',
      ),
      'profile_config_complete': (
        lire: (d) => d.hasCompletedProfileConfig(),
        armer: (d, r) => d.profil = r,
        cleLocale: 'profil',
      ),
    };

    for (final entree in drapeaux.entries) {
      final nom = entree.key;
      final cas = entree.value;

      test('$nom : indetermine -> Left, et rien n\'est memorise', () async {
        final distant = _FauxDistant();
        cas.armer(distant, const _Reponse.indetermine());
        final local = _FauxLocal();

        final resultat = await cas.lire(depot(distant, local));

        expect(resultat.isLeft(), isTrue, reason: 'Right(false) rejouerait $nom');
        // Le repli ne doit jamais se figer en local : il court-circuiterait
        // toutes les lectures suivantes, y compris celles qui aboutissent.
        expect(local.ecrits, isNot(contains(cas.cleLocale)));
      });

      test('$nom : exception -> Left', () async {
        final distant = _FauxDistant();
        cas.armer(distant, const _Reponse.exception());

        final resultat = await cas.lire(depot(distant, _FauxLocal()));

        expect(resultat.isLeft(), isTrue);
      });

      test('$nom : false lu reste false (compte neuf)', () async {
        final distant = _FauxDistant();
        cas.armer(distant, const _Reponse.valeur(false));
        final local = _FauxLocal();

        final resultat = await cas.lire(depot(distant, local));

        expect(resultat, const Right<Failure, bool>(false));
        expect(local.ecrits, isNot(contains(cas.cleLocale)));
      });

      test('$nom : true lu est memorise en local', () async {
        final distant = _FauxDistant();
        cas.armer(distant, const _Reponse.valeur(true));
        final local = _FauxLocal();

        final resultat = await cas.lire(depot(distant, local));

        expect(resultat, const Right<Failure, bool>(true));
        expect(local.ecrits, contains(cas.cleLocale));
      });
    }

    test('sans utilisateur connecte : Left, pas Right(false)', () async {
      final sansUser = OnboardingRepositoryImpl(
        localDataSource: _FauxLocal(),
        remoteDataSource: _FauxDistant(),
        firebaseAuth: _FauxFirebaseAuth(null),
      );

      expect((await sansUser.hasSeenOnboarding()).isLeft(), isTrue);
      expect((await sansUser.hasSeenCoachMarks()).isLeft(), isTrue);
      expect((await sansUser.hasGivenConsent()).isLeft(), isTrue);
      expect((await sansUser.hasCompletedProfileConfig()).isLeft(), isTrue);
    });
  });

  group('notifier : un Left ne fait jamais redescendre un drapeau', () {
    late Duration delaiInitial;

    setUp(() {
      delaiInitial = OnboardingNotifier.delaiDeReprise;
      // La reprise est vérifiée pour ce qu'elle décide, pas pour sa durée.
      OnboardingNotifier.delaiDeReprise = const Duration(milliseconds: 1);
    });

    tearDown(() => OnboardingNotifier.delaiDeReprise = delaiInitial);

    ProviderContainer conteneur(OnboardingRepository depot) {
      final c = ProviderContainer(
        overrides: [
          firebaseAuthProvider.overrideWithValue(
            _FauxFirebaseAuth(_FauxUtilisateur()),
          ),
          onboardingRepositoryProvider.overrideWith((ref) => depot),
        ],
      );
      addTearDown(c.dispose);
      // `onboardingNotifierProvider` est auto-dispose : sans abonnement il
      // meurt dès la fin du `read`.
      c.listen(onboardingNotifierProvider, (_, __) {}, fireImmediately: true);
      return c;
    }

    Future<OnboardingState> etatApresChargement(OnboardingRepository d) async {
      final c = conteneur(d);
      // Deux passes de lecture (build + authStateChanges) puis la reprise.
      for (var i = 0; i < 6; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      return c.read(onboardingNotifierProvider);
    }

    test('les quatre lectures echouent : aucun ecran n\'est impose', () async {
      final etat = await etatApresChargement(
        _FauxDepot(
          intro: [echec],
          coach: [echec],
          consent: [echec],
          profil: [echec],
        ),
      );

      expect(etat.hasSeenIntro, isTrue);
      expect(etat.hasSeenCoachMarks, isTrue);
      expect(etat.hasGivenConsent, isTrue);
      expect(etat.profileConfigComplete, isTrue);
      expect(etat.isLoading, isFalse, reason: '/splash ne doit pas rester');
      expect(
        ecranImpose(etat),
        isNull,
        reason: 'c\'est le parcours complet qui etait rejoue',
      );
    });

    test('les quatre lectures rendent false : l\'onboarding a bien lieu', () async {
      final etat = await etatApresChargement(
        _FauxDepot(
          intro: [const Right(false)],
          coach: [const Right(false)],
          consent: [const Right(false)],
          profil: [const Right(false)],
        ),
      );

      expect(etat.hasSeenIntro, isFalse);
      expect(etat.hasGivenConsent, isFalse);
      expect(etat.profileConfigComplete, isFalse);
      // Le repli optimiste ne doit pas avaler le cas d'un compte neuf.
      expect(ecranImpose(etat), '/consent');
    });

    test('un seul drapeau en echec n\'entraine pas les autres', () async {
      final etat = await etatApresChargement(
        _FauxDepot(
          intro: [const Right(false)],
          coach: [const Right(false)],
          consent: [const Right(false)],
          profil: [echec],
        ),
      );

      expect(etat.hasSeenIntro, isFalse);
      expect(etat.hasGivenConsent, isFalse);
      // Seul l'assistant de profil — le seul qui ecrive dans le profil — est
      // epargne, parce que lui seul n'a pas pu etre lu.
      expect(etat.profileConfigComplete, isTrue);
      expect(ecranImpose(etat), '/consent');
    });

    test('un echec apres une lecture reussie garde la valeur lue', () async {
      // `has_given_consent` est lu a false (compte neuf), puis la lecture
      // suivante echoue : le consentement reste du. Un repli aveugle a `true`
      // le ferait sauter.
      final etat = await etatApresChargement(
        _FauxDepot(
          intro: [const Right(true)],
          coach: [const Right(true)],
          consent: [const Right(false), echec],
          profil: [const Right(true)],
        ),
      );

      expect(etat.hasGivenConsent, isFalse);
      expect(ecranImpose(etat), '/consent');
    });
  });
}
