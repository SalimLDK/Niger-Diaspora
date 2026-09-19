import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/core/errors/failures.dart';
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
  _Depot({this.statut, this.echecLecture, this.annulationAboutit = true});

  final AccountDeletionStatus? statut;
  final Failure? echecLecture;
  final bool annulationAboutit;

  int lectures = 0;
  int annulations = 0;

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

AccountDeletionStatus _enCours([
  AccountDeletionPhase phase = AccountDeletionPhase.pending,
]) => AccountDeletionStatus(
  phase: phase,
  executeAt: DateTime(2026, 10, 18, 9),
);

ProviderContainer _conteneur({
  required AuthState auth,
  required _Depot depot,
}) {
  final c = ProviderContainer(
    overrides: [
      authNotifierProvider.overrideWith(() => _AuthFactice(auth)),
      authRepositoryProvider.overrideWithValue(depot),
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
        depot: _Depot(echecLecture: const ServerFailure('Session Supabase non établie')),
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
}
