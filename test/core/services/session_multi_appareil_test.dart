import 'package:diaspo_niger/core/services/session_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ce que ces tests protègent (plan MLS, phase 7)
/// ----------------------------------------------
/// « Une seule session par compte » éjecte l'appareil dont l'identifiant de
/// session n'est plus celui écrit en base. C'est cette règle qui interdit le
/// multi-appareil, et donc la phase 7.
///
/// La lever n'est pas une suppression : c'est une **autorisation par compte**.
/// Le défaut reste le comportement d'avant, pour tout le monde — lever une
/// posture de sécurité globalement, sur la foi d'un drapeau, est exactement ce
/// que ce dépôt a déjà payé ailleurs.
///
/// Les deux cas qui comptent sont asymétriques : ne pas éjecter quand il
/// faudrait laisse deux sessions vivre ; éjecter quand il ne faut pas
/// **déconnecte quelqu'un sans raison**, et il n'a aucun moyen de comprendre
/// pourquoi.

void main() {
  group('Règle d\'avant : une seule session', () {
    test('une session distante différente éjecte', () {
      expect(
        SessionService.doitEjecter(
          sessionDistante: 'session-B',
          sessionLocale: 'session-A',
          multiAppareil: false,
        ),
        isTrue,
      );
    });

    test('la même session n\'éjecte pas', () {
      expect(
        SessionService.doitEjecter(
          sessionDistante: 'session-A',
          sessionLocale: 'session-A',
          multiAppareil: false,
        ),
        isFalse,
      );
    });

    test('pas de session distante : on n\'éjecte pas sur une lecture vide', () {
      // Un document sans `session_id` — compte neuf, lecture partielle — ne
      // doit pas déconnecter : ce serait punir une absence d'information.
      expect(
        SessionService.doitEjecter(
          sessionDistante: null,
          sessionLocale: 'session-A',
          multiAppareil: false,
        ),
        isFalse,
      );
    });

    test('session locale absente et distante posée : éjecte', () {
      // L'appareil n'a plus son identifiant (préférences vidées) alors qu'une
      // session existe ailleurs : c'est bien un autre appareil qui tient le
      // compte.
      expect(
        SessionService.doitEjecter(
          sessionDistante: 'session-B',
          sessionLocale: null,
          multiAppareil: false,
        ),
        isTrue,
      );
    });
  });

  group('Multi-appareil autorisé', () {
    test('une session distante différente n\'éjecte plus', () {
      // LE test de la phase 7 : deux téléphones du même compte, chacun sa
      // session, aucun des deux ne chasse l'autre.
      expect(
        SessionService.doitEjecter(
          sessionDistante: 'session-B',
          sessionLocale: 'session-A',
          multiAppareil: true,
        ),
        isFalse,
      );
    });

    test('rien n\'éjecte, quelle que soit la combinaison', () {
      for (final distante in const [null, 'x', 'session-A']) {
        for (final locale in const [null, 'y', 'session-A']) {
          expect(
            SessionService.doitEjecter(
              sessionDistante: distante,
              sessionLocale: locale,
              multiAppareil: true,
            ),
            isFalse,
            reason: 'distante=$distante locale=$locale',
          );
        }
      }
    });
  });

  group('Le défaut', () {
    test('sans branchement, le service refuse le multi-appareil', () {
      // `multiAppareilAutorise` n'est branché que par `AuthNotifier`. Tant que
      // personne ne le pose, la règle d'avant s'applique — un drapeau qu'on
      // oublie de brancher ne doit pas ouvrir la porte.
      expect(SessionService.instance.multiAppareilAutorise(), isFalse);
    });
  });
}
