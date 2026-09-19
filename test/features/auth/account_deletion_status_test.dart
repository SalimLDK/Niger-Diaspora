import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/core/errors/failures.dart';
import 'package:diaspo_niger/core/services/effacement_local_differe.dart';
import 'package:diaspo_niger/features/auth/domain/entities/account_deletion_status.dart';
import 'package:diaspo_niger/features/auth/domain/entities/user_entity.dart';
import 'package:diaspo_niger/features/auth/domain/repositories/auth_repository.dart';
import 'package:diaspo_niger/features/auth/presentation/providers/account_deletion_provider.dart';
import 'package:diaspo_niger/features/auth/presentation/providers/auth_provider.dart';
import 'package:diaspo_niger/features/auth/presentation/providers/auth_state.dart';

/// Une personne dont la suppression est en cours doit tomber sur l'écran
/// d'annulation, pas dans l'application (voir la migration 20260918224100).
///
/// Ce qui est verrouillé ici, c'est la frontière entre trois réponses que le
/// serveur peut donner et qu'un client naïf confond :
///   · « aucune suppression »   → `null`, on entre ;
///   · « suppression en cours » → un statut, on est renvoyé sur l'écran ;
///   · « je n'ai pas pu lire »  → une ERREUR, jamais `null` — sans session,
///     RLS rend zéro ligne, exactement ce que rendrait un compte sans demande.

class _AuthFactice extends AuthNotifier {
  _AuthFactice(this._etat);
  final AuthState _etat;

  @override
  AuthState build() => _etat;
}

class _Depot implements AuthRepository {
  _Depot({
    this.statut,
    this.echecLecture,
    this.annulationAboutit = true,
    this.demande,
    this.echecReauth,
  });

  final AccountDeletionStatus? statut;
  final Failure? echecLecture;
  final bool annulationAboutit;

  /// Ce que répond `requestAccountDeletion` (défaut : refus quelconque).
  final Either<Failure, DateTime>? demande;

  /// Non nul : la ré-authentification par mot de passe échoue avec cela.
  final Failure? echecReauth;

  int lectures = 0;
  int annulations = 0;
  int demandes = 0;
  int reauths = 0;

  @override
  Future<Either<Failure, DateTime>> requestAccountDeletion() async {
    demandes++;
    return demande ?? const Left(ServerFailure('refusée'));
  }

  @override
  Future<Either<Failure, void>> reauthenticateWithPassword(String password) async {
    reauths++;
    final echec = echecReauth;
    return echec != null ? Left(echec) : const Right(null);
  }

  @override
  Future<Either<Failure, AccountDeletionStatus?>> accountDeletionStatus() async {
    lectures++;
    final echec = echecLecture;
    return echec != null ? Left(echec) : Right(statut);
  }

  @override
  Future<Either<Failure, void>> cancelAccountDeletion() async {
    annulations++;
    return annulationAboutit
        ? const Right(null)
        : const Left(ServerFailure('refusée'));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _moi = UserEntity(id: 'uid-de-test');

/// Le magasin de marqueurs d'effacement local, en mémoire : ni SharedPreferences
/// ni Supabase ni disque. `programmations` et `annulations` gardent la trace des
/// appels, `marqueurs` ce qui est stocké.
class _Magasin {
  String? stocke;

  List<String> get marqueurs => stocke == null
      ? []
      : [for (final m in jsonDecode(stocke!) as List) (m as Map)['uid'] as String];

  EffacementLocalDiffere get service => EffacementLocalDiffere(
    lire: () async => stocke,
    ecrire: (v) async => stocke = v,
    suppressionMenee: (_) async => false,
    effacerMateriel: (_) async {},
  );

  /// Un marqueur déjà posé, comme après une demande de suppression.
  Future<void> poser(String uid) =>
      service.programmer(uid, DateTime.utc(2026, 10, 18, 9));
}

AccountDeletionStatus _enCours([
  AccountDeletionPhase phase = AccountDeletionPhase.pending,
]) => AccountDeletionStatus(
  phase: phase,
  executeAt: DateTime(2026, 10, 18, 9),
);

ProviderContainer _conteneur({
  required AuthState auth,
  required _Depot depot,
  _Magasin? magasin,
}) {
  final c = ProviderContainer(
    overrides: [
      authNotifierProvider.overrideWith(() => _AuthFactice(auth)),
      authRepositoryProvider.overrideWithValue(depot),
      // Jamais le vrai service : il toucherait SharedPreferences et Supabase.
      effacementLocalDiffereProvider.overrideWithValue(
        (magasin ?? _Magasin()).service,
      ),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('AccountDeletionPhase', () {
    test('trois statuts serveur sont lisibles, tous les autres sont « rien »', () {
      expect(AccountDeletionPhase.fromDb('pending'), AccountDeletionPhase.pending);
      expect(AccountDeletionPhase.fromDb('blocked'), AccountDeletionPhase.blocked);
      expect(AccountDeletionPhase.fromDb('deleting'), AccountDeletionPhase.deleting);
      // Annulée : ne gêne plus personne. Menée à terme : plus de compte pour
      // la lire. Inconnu : aucun écran n'a rien à en dire.
      expect(AccountDeletionPhase.fromDb('cancelled'), isNull);
      expect(AccountDeletionPhase.fromDb('completed'), isNull);
      expect(AccountDeletionPhase.fromDb('quelque_chose_de_neuf'), isNull);
      expect(AccountDeletionPhase.fromDb(null), isNull);
    });

    test('on annule pendant le délai et quand c\'est bloqué, plus une fois engagée', () {
      expect(AccountDeletionPhase.pending.cancellable, isTrue);
      // La personne n'a pas à porter un obstacle qu'elle ne voit pas.
      expect(AccountDeletionPhase.blocked.cancellable, isTrue);
      // La purge est engagée, le compte Firebase est en cours de suppression.
      expect(AccountDeletionPhase.deleting.cancellable, isFalse);
    });
  });

  group('accountDeletionStatusProvider', () {
    test('sans session : `null`, et le serveur n\'est même pas interrogé', () async {
      final depot = _Depot(statut: _enCours());
      final c = _conteneur(
        auth: const AuthState.unauthenticated(),
        depot: depot,
      );

      expect(await c.read(accountDeletionStatusProvider.future), isNull);
      expect(depot.lectures, 0);
    });

    test('connecté sans suppression : `null`, on entre', () async {
      final depot = _Depot();
      final c = _conteneur(
        auth: const AuthState.authenticated(_moi),
        depot: depot,
      );

      expect(await c.read(accountDeletionStatusProvider.future), isNull);
      expect(depot.lectures, 1);
    });

    test('connecté avec une suppression en cours : le statut, pour le routeur', () async {
      final c = _conteneur(
        auth: const AuthState.authenticated(_moi),
        depot: _Depot(statut: _enCours()),
      );

      final statut = await c.read(accountDeletionStatusProvider.future);

      expect(statut, _enCours());
      expect(statut!.cancellable, isTrue);
    });

    test('une lecture qui échoue est une ERREUR, jamais « rien en cours »', () async {
      final c = _conteneur(
        auth: const AuthState.authenticated(_moi),
        depot: _Depot(echecLecture: const ServerFailure('Session non établie')),
      );

      await expectLater(
        c.read(accountDeletionStatusProvider.future),
        throwsException,
      );

      final etat = c.read(accountDeletionStatusProvider);
      expect(etat.hasError, isTrue);
      // C'est ce que lit le routeur : `valueOrNull`, jamais `.value`, qui
      // relancerait l'erreur en Riverpod 2. Une lecture ratée laisse entrer
      // plutôt qu'enfermer la personne hors de son compte — celui-ci est déjà
      // masqué côté serveur quoi que le client en pense.
      expect(etat.valueOrNull, isNull);
    });

    test('annuler : le statut disparaît, le routeur renvoie sur l\'accueil', () async {
      final depot = _Depot(statut: _enCours());
      final c = _conteneur(
        auth: const AuthState.authenticated(_moi),
        depot: depot,
      );
      expect(await c.read(accountDeletionStatusProvider.future), isNotNull);

      final ok = await c.read(accountDeletionStatusProvider.notifier).cancel();

      expect(ok, isTrue);
      expect(depot.annulations, 1);
      expect(c.read(accountDeletionStatusProvider).valueOrNull, isNull);
    });

    test('une annulation refusée ne fait PAS disparaître le statut', () async {
      final depot = _Depot(statut: _enCours(), annulationAboutit: false);
      final c = _conteneur(
        auth: const AuthState.authenticated(_moi),
        depot: depot,
      );
      await c.read(accountDeletionStatusProvider.future);

      final ok = await c.read(accountDeletionStatusProvider.notifier).cancel();

      // L'écran garde ses boutons : la personne peut réessayer, et le compte
      // reste bien celui qu'il est côté serveur.
      expect(ok, isFalse);
      expect(c.read(accountDeletionStatusProvider).valueOrNull, _enCours());
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // Un échec de la demande n'est PAS une erreur d'authentification
  // ═══════════════════════════════════════════════════════════════════════
  //
  // Le routeur traite tout `AuthState.error` comme « non authentifié » et
  // renvoie sur l'écran de connexion. Une demande refusée (compte plateforme,
  // obligation financière) ou une ré-authentification demandée laissait la
  // personne, toujours connectée, sur un écran de connexion qui ne disait
  // rien. Le résultat est donc rendu à l'appelant, jamais posé dans l'état.
  group("requestAccountDeletion : l'état d'authentification n'en est jamais touché", () {
    bool enErreur(ProviderContainer c) => c
        .read(authNotifierProvider)
        .maybeWhen(error: (_) => true, orElse: () => false);

    test("un refus est rendu, l'état reste authentifié", () async {
      final depot = _Depot(
        demande: const Left(ServerFailure('Ce compte administre les groupes officiels')),
      );
      final c = _conteneur(auth: const AuthState.authenticated(_moi), depot: depot);
      c.listen(authNotifierProvider, (_, __) {}, fireImmediately: true);

      final issue = await c.read(authNotifierProvider.notifier).requestAccountDeletion();

      expect(issue, isA<AccountDeletionRefused>());
      expect(
        (issue as AccountDeletionRefused).message,
        'Ce compte administre les groupes officiels',
      );
      expect(enErreur(c), isFalse, reason: 'le routeur renverrait sur la connexion');
      expect(c.read(authNotifierProvider), const AuthState.authenticated(_moi));
    });

    test("la ré-authentification demandée est rendue, l'état reste authentifié", () async {
      final depot = _Depot(
        demande: const Left(
          AuthFailure('confirmez votre mot de passe', code: 'requires-recent-login'),
        ),
      );
      final c = _conteneur(auth: const AuthState.authenticated(_moi), depot: depot);
      c.listen(authNotifierProvider, (_, __) {}, fireImmediately: true);

      final issue = await c.read(authNotifierProvider.notifier).requestAccountDeletion();

      expect(issue, isA<AccountDeletionNeedsReauth>());
      expect(enErreur(c), isFalse);
      expect(c.read(authNotifierProvider), const AuthState.authenticated(_moi));
    });

    test('seul le CODE décide de la ré-authentification, pas le texte', () async {
      // L'ancienne détection cherchait « mot de passe » ou « sécurité » dans le
      // message : « Email ou mot de passe incorrect » la déclenchait à tort.
      final depot = _Depot(
        demande: const Left(AuthFailure('Email ou mot de passe incorrect')),
      );
      final c = _conteneur(auth: const AuthState.authenticated(_moi), depot: depot);
      c.listen(authNotifierProvider, (_, __) {}, fireImmediately: true);

      final issue = await c.read(authNotifierProvider.notifier).requestAccountDeletion();

      expect(issue, isA<AccountDeletionRefused>());
    });

    test("un mot de passe faux : refus, et la demande n'est même pas tentée", () async {
      final depot = _Depot(echecReauth: const AuthFailure('Mot de passe incorrect'));
      final c = _conteneur(auth: const AuthState.authenticated(_moi), depot: depot);
      c.listen(authNotifierProvider, (_, __) {}, fireImmediately: true);

      final issue = await c
          .read(authNotifierProvider.notifier)
          .reauthenticateAndRequestDeletion('faux');

      expect(issue, isA<AccountDeletionRefused>());
      expect((issue as AccountDeletionRefused).message, 'Mot de passe incorrect');
      expect(depot.reauths, 1);
      expect(depot.demandes, 0, reason: 'rien ne doit être désactivé sur un mot de passe faux');
      expect(enErreur(c), isFalse);
    });

    test('mot de passe juste puis refus de la base : la demande a bien été tentée une fois', () async {
      final depot = _Depot(
        demande: const Left(ServerFailure('Des opérations financières sont liées à ce compte')),
      );
      final c = _conteneur(auth: const AuthState.authenticated(_moi), depot: depot);
      c.listen(authNotifierProvider, (_, __) {}, fireImmediately: true);

      final issue = await c
          .read(authNotifierProvider.notifier)
          .reauthenticateAndRequestDeletion('juste');

      expect(issue, isA<AccountDeletionRefused>());
      expect(depot.reauths, 1);
      expect(depot.demandes, 1);
      expect(enErreur(c), isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // Le marqueur d'effacement local suit le sort de la suppression
  // ═══════════════════════════════════════════════════════════════════════
  //
  // La demande pose un marqueur (uid + échéance) que le démarrage suivant
  // interrogera ; annuler — ici ou ailleurs — doit le retirer, sinon le
  // téléphone finirait par effacer les clés d'un compte VIVANT. Le serveur
  // confirme de toute façon avant d'effacer : ce marqueur en trop coûterait une
  // requête, pas les clés. Mais rien ne justifie de le laisser.
  group("effacement local : le marqueur suit la suppression", () {
    test("annuler la suppression retire le marqueur de CE compte, et de lui seul", () async {
      final magasin = _Magasin();
      await magasin.poser('uid-de-test');
      await magasin.poser('uid-autre-compte');
      final c = _conteneur(
        auth: const AuthState.authenticated(_moi),
        depot: _Depot(statut: _enCours()),
        magasin: magasin,
      );
      await c.read(accountDeletionStatusProvider.future);
      expect(magasin.marqueurs, contains('uid-de-test'),
          reason: 'une suppression en cours garde son marqueur');

      final ok = await c.read(accountDeletionStatusProvider.notifier).cancel();

      expect(ok, isTrue);
      expect(magasin.marqueurs, ['uid-autre-compte']);
    });

    test("une annulation REFUSÉE garde le marqueur", () async {
      final magasin = _Magasin();
      await magasin.poser('uid-de-test');
      final c = _conteneur(
        auth: const AuthState.authenticated(_moi),
        depot: _Depot(statut: _enCours(), annulationAboutit: false),
        magasin: magasin,
      );
      await c.read(accountDeletionStatusProvider.future);

      final ok = await c.read(accountDeletionStatusProvider.notifier).cancel();

      expect(ok, isFalse);
      expect(magasin.marqueurs, ['uid-de-test']);
    });

    test("annulée AILLEURS : une lecture qui ne trouve plus de suppression retire le marqueur", () async {
      final magasin = _Magasin();
      await magasin.poser('uid-de-test');
      final c = _conteneur(
        auth: const AuthState.authenticated(_moi),
        depot: _Depot(), // aucune suppression en cours
        magasin: magasin,
      );

      expect(await c.read(accountDeletionStatusProvider.future), isNull);
      // `unawaited` : laisser la microtâche d'annulation se terminer.
      await Future<void>.delayed(Duration.zero);

      expect(magasin.marqueurs, isEmpty);
    });

    test("une lecture QUI ÉCHOUE ne retire rien : on n'a pas lu, on ne conclut pas", () async {
      final magasin = _Magasin();
      await magasin.poser('uid-de-test');
      final c = _conteneur(
        auth: const AuthState.authenticated(_moi),
        depot: _Depot(echecLecture: const ServerFailure('Session non établie')),
        magasin: magasin,
      );

      await expectLater(c.read(accountDeletionStatusProvider.future), throwsException);
      await Future<void>.delayed(Duration.zero);

      expect(magasin.marqueurs, ['uid-de-test'],
          reason: 'sans session, RLS rend zéro ligne : exactement ce que rendrait '
              'un compte sans demande');
    });

    test("une suppression toujours en cours garde son marqueur", () async {
      final magasin = _Magasin();
      await magasin.poser('uid-de-test');
      final c = _conteneur(
        auth: const AuthState.authenticated(_moi),
        depot: _Depot(statut: _enCours()),
        magasin: magasin,
      );

      await c.read(accountDeletionStatusProvider.future);
      await Future<void>.delayed(Duration.zero);

      expect(magasin.marqueurs, ['uid-de-test']);
    });

    test("la demande aboutie pose le marqueur AVANT la déconnexion", () async {
      final magasin = _Magasin();
      final echeance = DateTime.utc(2026, 10, 18, 9);
      final c = _conteneur(
        auth: const AuthState.authenticated(_moi),
        depot: _Depot(demande: Right(echeance)),
        magasin: magasin,
      );
      c.listen(authNotifierProvider, (_, __) {}, fireImmediately: true);

      // La déconnexion touche des singletons (cache, préférences) qu'un test
      // n'initialise pas : elle peut lever. Ce qui compte ici est que le marqueur
      // soit déjà posé quand elle s'exécute.
      try {
        await c.read(authNotifierProvider.notifier).requestAccountDeletion();
      } catch (_) {}

      expect(magasin.marqueurs, ['uid-de-test']);
      final m = (jsonDecode(magasin.stocke!) as List).single as Map;
      expect(DateTime.parse(m['echeance'] as String), echeance);
    });

    test("un refus de la demande ne pose AUCUN marqueur", () async {
      final magasin = _Magasin();
      final c = _conteneur(
        auth: const AuthState.authenticated(_moi),
        depot: _Depot(demande: const Left(ServerFailure('refusée'))),
        magasin: magasin,
      );
      c.listen(authNotifierProvider, (_, __) {}, fireImmediately: true);

      await c.read(authNotifierProvider.notifier).requestAccountDeletion();

      expect(magasin.stocke, isNull,
          reason: "rien n'a été désactivé : il n'y a rien à effacer plus tard");
    });
  });
}
