import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:diaspo_niger/core/utils/licences_polices.dart';

/// Les polices sont embarquées dans l'APK, et plus téléchargées au premier
/// affichage.
///
/// Avant le 2026-09-11, google_fonts allait chercher chaque graisse sur
/// fonts.gstatic.com : hors ligne, texte en police système et
/// `Failed host lookup: 'fonts.gstatic.com'` dans Crashlytics (4 événements,
/// 3 utilisateurs). Le paquet consulte les assets AVANT le réseau, à condition
/// que le fichier porte exactement le nom attendu (`Inter-SemiBold.ttf`) — une
/// faute de nom et il repart silencieusement sur le réseau.
///
/// Le premier groupe le prouve par le comportement : réseau interdit
/// (`allowRuntimeFetching = false`), chaque variante doit se charger. Un nom de
/// fichier faux, une graisse oubliée, et le paquet lève.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('chaque variante se charge depuis les assets, réseau interdit', () {
    setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
    tearDownAll(() => GoogleFonts.config.allowRuntimeFetching = true);

    const normal = FontStyle.normal;
    const w400a700 = [
      FontWeight.w400,
      FontWeight.w500,
      FontWeight.w600,
      FontWeight.w700,
    ];

    // Des fabriques, pas des styles : appeler GoogleFonts.inter() ici, à la
    // déclaration du groupe, lancerait le chargement AVANT que setUpAll coupe
    // le réseau — et une police absente des assets passerait inaperçue.
    final variantes = <String, List<TextStyle> Function()>{
      'Inter': () => [
            for (final w in w400a700) GoogleFonts.inter(fontWeight: w),
          ],
      'Playfair Display': () => [
            for (final w in w400a700) GoogleFonts.playfairDisplay(fontWeight: w),
          ],
      'Roboto Mono': () => [
            for (final w in w400a700) GoogleFonts.robotoMono(fontWeight: w),
          ],
      'Instrument Sans': () => [
            for (final w in w400a700) GoogleFonts.instrumentSans(fontWeight: w),
          ],
      'Figtree': () => [
            for (final w in w400a700) GoogleFonts.figtree(fontWeight: w),
          ],
      'Instrument Serif': () => [
            GoogleFonts.instrumentSerif(fontStyle: normal),
            GoogleFonts.instrumentSerif(fontStyle: FontStyle.italic),
          ],
      'IBM Plex Mono': () => [GoogleFonts.ibmPlexMono()],
      'Caprasimo': () => [GoogleFonts.caprasimo()],
    };

    for (final entree in variantes.entries) {
      test(entree.key, () async {
        expect(GoogleFonts.config.allowRuntimeFetching, isFalse);
        final styles = entree.value();
        await expectLater(GoogleFonts.pendingFonts(styles), completes);
      });
    }
  });

  group('fichiers et licences', () {
    final dossier = Directory('assets/google_fonts');
    final polices = dossier
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .where((n) => n.endsWith('.ttf'))
        .toList();

    test('les 24 fichiers attendus sont dans le dossier source', () {
      // Le groupe de chargement ci-dessus peut être aveuglé en local :
      // `flutter test` ne reconstruit pas build/unit_test_assets quand on
      // SUPPRIME un fichier d'un dossier d'assets. Constaté le 2026-09-11 —
      // Inter-SemiBold.ttf retiré, le test de chargement passait encore sur
      // l'ancienne copie. Ce test-ci lit le dossier source : aucun cache ne
      // peut le tromper.
      const quatreGraisses = ['Regular', 'Medium', 'SemiBold', 'Bold'];
      final attendus = [
        for (final famille in [
          'Inter',
          'PlayfairDisplay',
          'RobotoMono',
          'InstrumentSans',
          'Figtree',
        ])
          for (final g in quatreGraisses) '$famille-$g.ttf',
        'InstrumentSerif-Regular.ttf',
        'InstrumentSerif-Italic.ttf',
        'IBMPlexMono-Regular.ttf',
        'Caprasimo-Regular.ttf',
      ];
      final manquants = attendus
          .where((n) => !File('assets/google_fonts/$n').existsSync())
          .toList();
      expect(manquants, isEmpty, reason: 'Absents : ${manquants.join(', ')}');
      expect(attendus, hasLength(24));
    });

    test('le dossier est déclaré dans pubspec.yaml', () {
      expect(
        File('pubspec.yaml').readAsStringSync(),
        contains('- assets/google_fonts/'),
      );
    });

    test('chaque police a sa famille déclarée et sa licence', () {
      final prefixes = {
        for (final f in famillesPoliceEmbarquees) f.fichier,
      };
      for (final nom in polices) {
        final prefixe = nom.substring(0, nom.indexOf('-'));
        expect(prefixes, contains(prefixe), reason: '$nom sans famille déclarée');
      }
      for (final famille in famillesPoliceEmbarquees) {
        final licence = File('assets/google_fonts/LICENCE-${famille.fichier}.txt');
        expect(licence.existsSync(), isTrue, reason: '${famille.nom} sans licence');
        expect(
          licence.readAsStringSync(),
          contains('SIL OPEN FONT LICENSE'),
          reason: '${famille.nom} : texte de licence méconnaissable',
        );
        expect(
          polices.any((n) => n.startsWith('${famille.fichier}-')),
          isTrue,
          reason: '${famille.nom} déclarée mais aucun fichier',
        );
      }
    });
  });

  group('le code n’appelle aucune famille non embarquée', () {
    // Nom de la fabrique GoogleFonts -> préfixe de fichier embarqué.
    const embarquees = {
      'inter': 'Inter',
      'interTextTheme': 'Inter',
      'playfairDisplay': 'PlayfairDisplay',
      'robotoMono': 'RobotoMono',
      'instrumentSerif': 'InstrumentSerif',
      'instrumentSans': 'InstrumentSans',
      'ibmPlexMono': 'IBMPlexMono',
      'caprasimo': 'Caprasimo',
      'figtree': 'Figtree',
    };
    // Graisses littérales hors de 400-700 : le fichier ne serait pas là.
    const hors = ['w100', 'w200', 'w300', 'w800', 'w900'];

    final appel = RegExp(r'GoogleFonts\.([a-zA-Z]+)\(');
    final sources = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));

    test('toute famille appelée est dans assets/google_fonts', () {
      final inconnues = <String>[];
      for (final f in sources) {
        for (final m in appel.allMatches(f.readAsStringSync())) {
          final nom = m.group(1)!;
          if (nom == 'pendingFonts' || nom == 'config') continue;
          if (!embarquees.containsKey(nom)) inconnues.add('${f.path}: $nom');
        }
      }
      expect(
        inconnues,
        isEmpty,
        reason: 'Famille non embarquée : elle repartirait sur le réseau au '
            'premier affichage. Ajouter ses fichiers et sa licence.\n'
            '${inconnues.join('\n')}',
      );
    });

    test('aucune graisse littérale hors 400-700 sur une famille embarquée', () {
      final fautives = <String>[];
      for (final f in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        final texte = f.readAsStringSync();
        for (final m in appel.allMatches(texte)) {
          // Les arguments de l'appel, jusqu'à la parenthèse fermante.
          var profondeur = 0, i = m.end - 1;
          for (; i < texte.length; i++) {
            if (texte[i] == '(') profondeur++;
            if (texte[i] == ')' && --profondeur == 0) break;
          }
          final args = texte.substring(m.end, i);
          for (final w in hors) {
            if (args.contains('FontWeight.$w')) {
              fautives.add('${f.path}: GoogleFonts.${m.group(1)} FontWeight.$w');
            }
          }
        }
      }
      // Limite assumée : une graisse passée par variable (`fontWeight: w`)
      // n'est pas visible ici. Les fabriques concernées (DNText, FeedText,
      // AppTextStyles) ne reçoivent aujourd'hui que 400 à 700.
      expect(fautives, isEmpty, reason: fautives.join('\n'));
    });
  });
}
