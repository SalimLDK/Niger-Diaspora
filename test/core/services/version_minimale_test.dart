import 'package:diaspo_niger/core/services/version_minimale.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ce que ces tests protègent
/// --------------------------
/// Le verrou de version minimale est la seule pièce du projet dont la panne
/// n'est pas symétrique. S'il se tait à tort, une mise à jour se fait tard.
/// S'il bloque à tort, l'application devient inutilisable **pour tout le
/// monde**, sans recours — republier la configuration ne rouvre rien tant que
/// l'appareil bloqué ne va pas la relire.
///
/// Chaque cas ci-dessous est un scénario de fermeture abusive qu'il faut
/// rendre impossible, pas une préférence de comportement.

void main() {
  group('Refuser de bloquer', () {
    test('aucune version minimale : l\'état par défaut ne bloque pas', () {
      expect(
        miseAJourObligatoire(
            installee: '1.2.1+19', minimale: null, publiee: '1.3.0+21'),
        isFalse,
      );
      expect(
        miseAJourObligatoire(
            installee: '1.2.1+19', minimale: '', publiee: '1.3.0+21'),
        isFalse,
      );
    });

    test('version minimale illisible : une faute de frappe ne ferme rien', () {
      for (final brut in const ['bientôt', 'v.next', '..', '1.2.x']) {
        expect(
          miseAJourObligatoire(
              installee: '1.0.0+1', minimale: brut, publiee: '1.3.0+21'),
          isFalse,
          reason: brut,
        );
      }
    });

    test('version installée illisible : jamais fermer sur sa propre ignorance',
        () {
      expect(
        miseAJourObligatoire(
            installee: null, minimale: '1.3.0+21', publiee: '1.3.0+21'),
        isFalse,
      );
    });

    test('LE garde qui compte : exiger une version que le store n\'a pas', () {
      // La faute la plus probable — poser la version minimale avant d'avoir
      // publié. Bloquer enfermerait tout le monde devant un store qui n'offre
      // rien d'assez récent.
      expect(
        miseAJourObligatoire(
            installee: '1.2.1+19', minimale: '1.4.0+30', publiee: '1.3.0+21'),
        isFalse,
      );
    });

    test('version publiée inconnue : on ne bloque pas sans issue vérifiée', () {
      expect(
        miseAJourObligatoire(
            installee: '1.2.1+19', minimale: '1.3.0+21', publiee: null),
        isFalse,
      );
    });

    test('déjà à la version exigée : l\'égalité ne bloque pas', () {
      expect(
        miseAJourObligatoire(
            installee: '1.3.0+21', minimale: '1.3.0+21', publiee: '1.3.0+21'),
        isFalse,
      );
    });

    test('plus récent que la version exigée : le cas du build de dev', () {
      expect(
        miseAJourObligatoire(
            installee: '1.4.0+30', minimale: '1.3.0+21', publiee: '1.3.0+21'),
        isFalse,
      );
    });
  });

  group('Bloquer', () {
    test('trop ancien, et le store offre la version exigée', () {
      expect(
        miseAJourObligatoire(
            installee: '1.2.1+19', minimale: '1.3.0+21', publiee: '1.3.0+21'),
        isTrue,
      );
    });

    test('le store est même plus récent que la version exigée', () {
      expect(
        miseAJourObligatoire(
            installee: '1.2.1+19', minimale: '1.3.0+21', publiee: '1.5.0+40'),
        isTrue,
      );
    });

    test('le numéro de build seul suffit à départager', () {
      // `1.3.0+20` et `1.3.0+21` portent le même nom : sans le build, le
      // verrou ne saurait pas les distinguer.
      expect(
        miseAJourObligatoire(
            installee: '1.3.0+20', minimale: '1.3.0+21', publiee: '1.3.0+21'),
        isTrue,
      );
    });
  });

  group('L\'état du 2026-09-15, tel quel', () {
    test('rien n\'est publié comme minimum : personne n\'est bloqué', () {
      // `DERNIERE_VERSION_APP` vaut `1.2.1+19`, soit la version du
      // `pubspec.yaml`, et `VERSION_MINIMALE_APP` n'existe pas encore.
      expect(
        miseAJourObligatoire(
            installee: '1.2.1+19', minimale: null, publiee: '1.2.1+19'),
        isFalse,
      );
    });
  });
}
