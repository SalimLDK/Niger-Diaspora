import 'dart:io';

import 'package:diaspo_niger/core/services/session_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ce que ces tests protègent
/// --------------------------
/// `AdminProvider.forceLogoutUser` et `banUser` écrivent une sentinelle dans
/// `public.users.session_id` (Supabase). L'écouteur historique, lui, regardait
/// Firestore `users/<uid>`. Les deux actions **n'éjectaient donc personne**,
/// en silence — et `AdminAuditHelper` enregistrait un succès. Mesuré le
/// 2026-09-16 : la colonne existe bien côté Postgres, personne ne la lisait.
///
/// La panne n'était pas une erreur de logique : c'était deux moitiés écrites
/// dans deux bases différentes, sans rien pour les relier. D'où la forme de ce
/// banc — il vérifie la décision, **et** que les deux moitiés parlent encore
/// de la même chose.
///
/// L'asymétrie qui compte ici est l'inverse de celle de la session unique :
/// ne pas éjecter quand il faudrait laisse un banni actif dans l'app, avec ses
/// messages et ses notifications, pendant que la console affiche « banni ».

void main() {
  /// Exactement ce que la console écrit dans la colonne.
  String sentinelle(String prefixe) =>
      '$prefixe${DateTime.now().millisecondsSinceEpoch}';

  group('Décision administrative', () {
    test('une expulsion forcée éjecte', () {
      expect(
        SessionService.doitEjecterSurDecisionAdmin(
          sessionDistante: sentinelle(SessionService.prefixeForceLogout),
          banni: false,
          multiAppareil: false,
        ),
        isTrue,
      );
    });

    test('la sentinelle de bannissement éjecte', () {
      expect(
        SessionService.doitEjecterSurDecisionAdmin(
          sessionDistante: sentinelle(SessionService.prefixeBanni),
          banni: false,
          multiAppareil: false,
        ),
        isTrue,
      );
    });

    test('`is_banned` seul éjecte, sans sentinelle', () {
      // `setUserBanned` (functions/bannissement.js) pose `is_banned` et la
      // sentinelle dans la même écriture ; mais quelqu'un peut bannir
      // directement en base, sans sentinelle — le compte doit sortir quand
      // même.
      expect(
        SessionService.doitEjecterSurDecisionAdmin(
          sessionDistante: 'b0a1c2d3-0000-4000-8000-000000000000',
          banni: true,
          multiAppareil: false,
        ),
        isTrue,
      );
    });
  });

  group('Ce qui ne doit surtout pas éjecter', () {
    test('une session ordinaire, même différente de la sienne', () {
      // LA distinction avec `doitEjecter` : ce canal-ci ne porte QUE des
      // décisions admin. Y remettre la comparaison d'identifiants ferait
      // appliquer « une seule session » à 46 comptes qui y échappent
      // aujourd'hui — un durcissement livré en fraude dans un correctif.
      expect(
        SessionService.doitEjecterSurDecisionAdmin(
          sessionDistante: '3f1a77c0-1111-4000-8000-000000000000',
          banni: false,
          multiAppareil: false,
        ),
        isFalse,
      );
    });

    test('une colonne vide', () {
      expect(
        SessionService.doitEjecterSurDecisionAdmin(
          sessionDistante: null,
          banni: false,
          multiAppareil: false,
        ),
        isFalse,
      );
    });

    test('un identifiant qui contient la sentinelle sans commencer par elle', () {
      expect(
        SessionService.doitEjecterSurDecisionAdmin(
          sessionDistante: 'session-force_logout_42',
          banni: false,
          multiAppareil: false,
        ),
        isFalse,
      );
    });
  });

  group('Multi-appareil autorisé : exemption totale', () {
    test('rien n\'éjecte, bannissement compris', () {
      // Choix du 2026-09-16 : la liste `multiAppareilComptes` dit « laissez ce
      // compte tranquille », sans exception. Elle ne contient que des comptes
      // de test ; un banni qui y figure ne sort qu'à sa prochaine connexion.
      for (final distante in <String?>[
        null,
        'ordinaire',
        'force_logout_1',
        'banned_1',
      ]) {
        for (final banni in const [false, true]) {
          expect(
            SessionService.doitEjecterSurDecisionAdmin(
              sessionDistante: distante,
              banni: banni,
              multiAppareil: true,
            ),
            isFalse,
            reason: 'distante=$distante banni=$banni',
          );
        }
      }
    });
  });

  group('Les deux moitiés parlent de la même chose', () {
    // Le compilateur relie déjà les deux côtés (la console lit les constantes
    // ici). Ce test garde la porte : réintroduire un littéral côté console,
    // c'est refaire la panne, et rien d'autre ne le signalerait.
    //
    // Depuis le 2026-10-14, la sentinelle de bannissement n'est plus écrite
    // par la console mais par la Cloud Function `setUserBanned`
    // (functions/bannissement.js) — en JavaScript, hors de portée du
    // compilateur Dart : là, seul ce test relie encore les deux moitiés.
    const console =
        'lib/features/admin/presentation/providers/admin_provider.dart';
    const serveur = 'functions/bannissement.js';

    test('la console n\'écrit plus de sentinelle en littéral', () {
      final source = File(console).readAsStringSync();
      for (final litteral in const [
        "'force_logout_\${",
        "'banned_\${",
        '"force_logout_\${',
        '"banned_\${',
      ]) {
        expect(
          source.contains(litteral),
          isFalse,
          reason:
              'Sentinelle en dur dans $console : passer par '
              'SessionService.prefixeForceLogout / prefixeBanni.',
        );
      }
    });

    test("la console n'écrit plus aucune sentinelle : elle appelle le serveur",
        () {
      final source = File(console).readAsStringSync();
      expect(
        source.contains('\${SessionService.prefixeBanni}'),
        isFalse,
        reason: 'Le bannissement est serveur (setUserBanned) : la console '
            "n'écrit plus la sentinelle, elle appelle la callable.",
      );
      expect(
        source.contains('\${SessionService.prefixeForceLogout}'),
        isFalse,
        reason: "L'expulsion forcée passe par member_admin_force_logout : "
            "la sentinelle s'écrit dans Postgres, plus dans la console.",
      );
      expect(source.contains('member_admin_force_logout'), isTrue);
    });

    test("la migration des membres écrit les sentinelles que l'app lit", () {
      // Même raisonnement que pour le serveur JavaScript : une fonction SQL
      // est hors de portée du compilateur Dart, seul ce test relie les deux.
      final source = File(
        'supabase/migrations/20261019170000_membres_moderation.sql',
      ).readAsStringSync();
      expect(
        source.contains("'${SessionService.prefixeForceLogout}' ||"),
        isTrue,
        reason: 'member_admin_force_logout doit poser '
            "'${SessionService.prefixeForceLogout}' || <ms>",
      );
      expect(
        source.contains("'${SessionService.prefixeBanni}' ||"),
        isTrue,
        reason: "member_admin_suspend doit poser '${SessionService.prefixeBanni}' || <ms>",
      );
    });

    test("le serveur écrit la sentinelle de bannissement que l'app lit", () {
      final source = File(serveur).readAsStringSync();
      final constante = RegExp(r'const PREFIXE_SESSION_BANNIE = "([^"]*)";')
          .firstMatch(source);
      expect(
        constante,
        isNotNull,
        reason: 'PREFIXE_SESSION_BANNIE introuvable dans $serveur',
      );
      expect(constante!.group(1), SessionService.prefixeBanni);
    });
  });
}
