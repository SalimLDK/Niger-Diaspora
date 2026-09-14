import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:diaspo_niger/core/services/mise_a_jour_service.dart';

/// Notice « une nouvelle version est disponible ».
///
/// Le banc tient les deux bords, et le second compte davantage : une notice
/// qui manque est une gêne, une notice qui s'affiche à tort envoie la personne
/// sur le store chercher une mise à jour qui n'existe pas — et elle y
/// retournera à chaque démarrage. D'où la règle : **tout ce qui n'est pas
/// lisible se tait**.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VersionApp.parse', () {
    test('lit le format de pubspec.yaml', () {
      final v = VersionApp.parse('1.3.0+20')!;
      expect(v.nom, '1.3.0');
      expect(v.segments, [1, 3, 0]);
      expect(v.build, 20);
    });

    test('accepte un nom sans build', () {
      final v = VersionApp.parse('1.3.0')!;
      expect(v.build, isNull);
      expect(v.segments, [1, 3, 0]);
    });

    test('tolère les espaces autour de la valeur serveur', () {
      expect(VersionApp.parse('  1.3.0+20  ').toString(), '1.3.0+20');
    });

    test('coupe une pré-version au préfixe chiffré', () {
      // `-beta.2` ne s'ordonne pas numériquement ; ce projet n'en publie pas.
      expect(VersionApp.parse('1.3.0-beta.2')!.segments, [1, 3, 0]);
    });

    test('renvoie null sur ce qui n\'est pas exploitable', () {
      for (final brut in <String?>[null, '', '   ', 'bientôt', 'v', '+20']) {
        expect(VersionApp.parse(brut), isNull, reason: 'sur « $brut »');
      }
    });

    test('un build illisible ne jette pas la version', () {
      final v = VersionApp.parse('1.3.0+vingt')!;
      expect(v.segments, [1, 3, 0]);
      expect(v.build, isNull);
    });
  });

  group('VersionApp.compareTo', () {
    VersionApp v(String brut) => VersionApp.parse(brut)!;

    test('le nom décide avant le build', () {
      expect(v('1.3.0+5').compareTo(v('1.2.1+19')), greaterThan(0));
    });

    test('le build départage deux noms identiques', () {
      expect(v('1.2.1+20').compareTo(v('1.2.1+19')), greaterThan(0));
      expect(v('1.2.1+19').compareTo(v('1.2.1+20')), lessThan(0));
    });

    test('un build absent d\'un côté conclut à l\'égalité', () {
      // Ne prouve rien, donc ne déclenche rien.
      expect(v('1.2.1').compareTo(v('1.2.1+19')), 0);
    });

    test('les segments manquants valent zéro', () {
      expect(v('1.3').compareTo(v('1.3.0')), 0);
      expect(v('1.3.1').compareTo(v('1.3')), greaterThan(0));
    });
  });

  group('miseAJourDisponible', () {
    test('vrai quand la version publiée est postérieure', () {
      expect(
        miseAJourDisponible(installee: '1.2.1+19', publiee: '1.3.0+20'),
        isTrue,
      );
    });

    test('faux à version égale', () {
      expect(
        miseAJourDisponible(installee: '1.2.1+19', publiee: '1.2.1+19'),
        isFalse,
      );
    });

    test('faux quand l\'installée est en avance (build de développement)', () {
      expect(
        miseAJourDisponible(installee: '1.4.0+22', publiee: '1.3.0+20'),
        isFalse,
      );
    });

    test('faux dès qu\'une des deux est illisible', () {
      expect(miseAJourDisponible(installee: '1.2.1+19', publiee: null), isFalse);
      expect(miseAJourDisponible(installee: '1.2.1+19', publiee: ''), isFalse);
      expect(
        miseAJourDisponible(installee: '1.2.1+19', publiee: 'bientôt'),
        isFalse,
      );
      expect(miseAJourDisponible(installee: null, publiee: '9.9.9'), isFalse);
    });
  });

  group('CoordinateurMiseAJour', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    CoordinateurMiseAJour coordinateur({
      String? publiee,
      String installee = '1.2.1+19',
    }) {
      final c = CoordinateurMiseAJour(
        versionPubliee: () => publiee,
        versionInstallee: () async => installee,
        preferences: SharedPreferences.getInstance,
      );
      addTearDown(c.dispose);
      return c;
    }

    test('propose la mise à jour, avec le nom affichable seul', () async {
      final c = coordinateur(publiee: '1.3.0+20');
      await c.verifie();
      expect(c.state?.versionPubliee, '1.3.0');
      expect(c.state?.brut, '1.3.0+20');
    });

    test('se tait quand la clé serveur est absente', () async {
      // L'état d'aujourd'hui : le secret n'est pas encore posé.
      final c = coordinateur(publiee: null);
      await c.verifie();
      expect(c.state, isNull);
    });

    test('se tait quand la version publiée n\'est pas postérieure', () async {
      final c = coordinateur(publiee: '1.2.1+19');
      await c.verifie();
      expect(c.state, isNull);
    });

    test('« Pas maintenant » persiste et fait taire CETTE version', () async {
      final premier = coordinateur(publiee: '1.3.0+20');
      await premier.verifie();
      expect(premier.state, isNotNull);
      premier.ecarte();
      expect(premier.state, isNull);

      // Le prochain démarrage, même version : silence.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(CoordinateurMiseAJour.cleVersionEcartee),
          '1.3.0+20');
      final suivant = coordinateur(publiee: '1.3.0+20');
      await suivant.verifie();
      expect(suivant.state, isNull);
    });

    test('mais la version suivante reparle', () async {
      SharedPreferences.setMockInitialValues({
        CoordinateurMiseAJour.cleVersionEcartee: '1.3.0+20',
      });
      final c = coordinateur(publiee: '1.4.0+21');
      await c.verifie();
      expect(c.state?.versionPubliee, '1.4.0');
    });

    test('partir vers le store n\'écarte pas la version', () async {
      // Revenir du store sans avoir installé doit laisser la notice revenir au
      // démarrage suivant.
      final c = coordinateur(publiee: '1.3.0+20');
      await c.verifie();
      c.ouvre();
      expect(c.state, isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(CoordinateurMiseAJour.cleVersionEcartee), isNull);
    });

    test('ne vérifie qu\'une fois par session', () async {
      var appels = 0;
      final c = CoordinateurMiseAJour(
        versionPubliee: () {
          appels++;
          return '1.3.0+20';
        },
        versionInstallee: () async => '1.2.1+19',
        preferences: SharedPreferences.getInstance,
      );
      addTearDown(c.dispose);

      await c.verifie();
      c.ecarte();
      await c.verifie();
      expect(appels, 1);
      expect(c.state, isNull);
    });

    test('une lecture qui jette laisse l\'app sans notice, sans lever',
        () async {
      final c = CoordinateurMiseAJour(
        versionPubliee: () => '1.3.0+20',
        versionInstallee: () async => throw StateError('canal indisponible'),
        preferences: SharedPreferences.getInstance,
      );
      addTearDown(c.dispose);

      await expectLater(c.verifie(), completes);
      expect(c.state, isNull);
    });
  });
}
