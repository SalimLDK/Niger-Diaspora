import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/core/utils/logs_release.dart';

/// Vérifie qu'aucune sortie console ne subsiste en release.
///
/// Contexte : `debugPrint` écrit **aussi** en release (doc du SDK,
/// `foundation/print.dart`), et `print` n'a jamais prétendu le contraire. Sur
/// l'APK de production, les deux partent dans logcat sous le tag `flutter`,
/// lisibles par quiconque branche l'appareil. Trois fuites concrètes avaient
/// déjà été trouvées par ce chemin — valeur du jeton VoIP, coordonnées GPS
/// d'un partage de position (deux fois).
///
/// Limite assumée pour le second groupe : ce test lit la source. Il ne peut
/// rien dire des paquets tiers, et c'est justement pour eux qu'existe le
/// verrou de zone testé dans le premier groupe.
void main() {
  group('la zone de release avale toute sortie console', () {
    /// Capture ce qui sortirait vraiment : on entoure d'une zone qui collecte,
    /// et on met la zone muette à l'intérieur. Si elle laisse passer quoi que
    /// ce soit, la collecte le voit.
    List<String> sortiesDepuis(void Function() corps) {
      final captees = <String>[];
      runZoned(
        () => runZoned(corps, zoneSpecification: zoneSansSortieConsole()),
        zoneSpecification: ZoneSpecification(
          print: (_, __, ___, String ligne) => captees.add(ligne),
        ),
      );
      return captees;
    }

    test('`print` brut ne sort pas', () {
      // ignore: avoid_print — c'est précisément ce qu'on veut voir avalé.
      expect(sortiesDepuis(() => print('fuite')), isEmpty);
    });

    test('`debugPrint` ne sort pas non plus — il passe par `print`', () {
      expect(
        sortiesDepuis(() => debugPrintSynchronously('fuite')),
        isEmpty,
      );
    });

    test('sans la zone, la même sortie serait bien visible', () {
      // Contrôle : sans ce test, les deux précédents passeraient aussi avec un
      // mécanisme de capture cassé qui ne voit jamais rien.
      final captees = <String>[];
      runZoned(
        // ignore: avoid_print — témoin : cette sortie DOIT être visible.
        () => print('temoin'),
        zoneSpecification: ZoneSpecification(
          print: (_, __, ___, String ligne) => captees.add(ligne),
        ),
      );
      expect(captees, ['temoin']);
    });
  });

  group('aucun `print` brut dans lib/', () {
    test('la source ne contient pas de print() hors debugPrint', () {
      final coupables = <String>[];
      final motif = RegExp(r'(?<![\w.])print\s*\(');

      for (final entite in Directory('lib').listSync(recursive: true)) {
        if (entite is! File || !entite.path.endsWith('.dart')) continue;
        final lignes = entite.readAsLinesSync();
        for (var i = 0; i < lignes.length; i++) {
          final ligne = lignes[i];
          if (ligne.trimLeft().startsWith('//')) continue;
          if (!motif.hasMatch(ligne)) continue;
          coupables.add('${entite.path}:${i + 1}: ${ligne.trim()}');
        }
      }

      expect(
        coupables,
        isEmpty,
        reason:
            'Un `print()` brut échappe au verrou 1 (la réassignation de '
            '`debugPrint`). Il resterait muet grâce au verrou 2 (la zone), '
            'mais on ne veut pas dépendre du filet : utiliser `debugPrint` '
            'ou `LoggerService`.\n${coupables.join('\n')}',
      );
    });
  });
}
