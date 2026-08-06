import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// §9c — le nom d'un groupe était rogné par les pastilles de sa propre carte.
///
/// Réplique la géométrie de `_GroupCard` (`groups_screen.dart`) sans Riverpod
/// ni Firebase : la carte est privée et son écran tire une douzaine de
/// providers, alors que le défaut est purement une histoire de largeurs.
///
/// La chaîne mesurée sur un écran de 360 dp :
///
/// | poste | dp restants |
/// |---|---|
/// | écran | 360 |
/// | − marge d'écran (`horizontalPadding` = 16, ×2) | 328 |
/// | − padding de carte (14, ×2) | 300 |
/// | − avatar 52 + écart 14 | 234 |
/// | − écart 8 + bouton « Rejoindre » (~86) | ~140 |
///
/// Il reste donc ~140 dp à la colonne. L'ancienne ligne de titre y logeait, en
/// plus du nom, un cadenas (13), une pastille « Officiel », une épingle (14) et
/// une pastille ACTIF/CALME — les deux pastilles à largeur libre. **Le nom
/// était le seul enfant `Flexible` de la ligne, donc le seul à céder** ; et
/// quand les pastilles dépassaient à elles seules les 140 dp, la ligne
/// débordait carrément.
///
/// Les mesures absolues de largeur de texte ne sont volontairement pas
/// asserties : la police des tests rend un carré de `fontSize` par caractère,
/// sans rapport avec la police réelle. Ce qui est verrouillé ici est
/// structurel — qui déborde, et combien de dp le nom se voit attribuer.
const double kColumnWidth = 140;

/// Un nom réel de la base (`public.groups`, 2026-08-06).
const String kLongName = 'Diaspora Niger — Canada';

/// Ce que la nouvelle ligne de titre laisse au nom : la colonne, moins les
/// deux seuls indicateurs restants et leurs écarts (6 + 13 + 6 + 14).
const double kLargeurDuNom = kColumnWidth - 39;

const TextStyle _nameStyle =
    TextStyle(fontSize: 15, fontWeight: FontWeight.w700);

Widget _harness(Widget child, {TextScaler scaler = TextScaler.noScaling}) =>
    MediaQuery(
      data: MediaQueryData(size: const Size(360, 800), textScaler: scaler),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: SizedBox(width: kColumnWidth, child: child)),
      ),
    );

Widget _pill(String label) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );

/// Ligne de titre telle qu'elle était : nom `Flexible`, puis quatre
/// indicateurs dont deux à largeur libre.
Widget _ancienneLigne(String name) => Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  name,
                  style: _nameStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.lock_outline_rounded, size: 13),
              const SizedBox(width: 6),
              _pill('Officiel'),
            ],
          ),
        ),
        const SizedBox(width: 6),
        const Icon(Icons.push_pin, size: 14),
        const SizedBox(width: 8),
        _pill('ACTIF'),
      ],
    );

/// Ligne de titre corrigée : le nom sur deux lignes, accompagné des deux seuls
/// indicateurs à largeur bornée (13 et 14 dp). « Officiel » et ACTIF/CALME sont
/// descendus dans le `Wrap` de méta.
Widget _nouvelleLigne(String name) => Row(
      children: [
        Expanded(
          child: Text(
            name,
            style: _nameStyle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 6),
        const Icon(Icons.lock_outline_rounded, size: 13),
        const SizedBox(width: 6),
        const Icon(Icons.push_pin, size: 14),
      ],
    );

/// Le `Wrap` de méta, avec les deux pastilles rapatriées depuis le titre.
Widget _ligneDeMeta() => Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _pill('Officiel'),
        _pill('ACTIF'),
        _pill('Canada'),
        _pill('12'),
        _pill('Régional'),
      ],
    );

void main() {
  group('§9c — nom de groupe sur la carte', () {
    testWidgets('régression : les pastilles débordaient de la ligne de titre',
        (tester) async {
      await tester.pumpWidget(_harness(_ancienneLigne(kLongName)));
      expect(
        tester.takeException(),
        isA<FlutterError>().having(
          (e) => e.toString(),
          'message',
          contains('overflowed'),
        ),
        reason: 'les deux pastilles à largeur libre dépassent les 140 dp',
      );
    });

    testWidgets('le nom reçoit toute la largeur restante', (tester) async {
      await tester.pumpWidget(_harness(_nouvelleLigne(kLongName)));
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.text(kLongName)).width,
        kLargeurDuNom,
        reason: 'seuls le cadenas (13) et l’épingle (14) lui prennent de la place',
      );
    });

    testWidgets('et il dispose de deux lignes', (tester) async {
      await tester.pumpWidget(_harness(_nouvelleLigne(kLongName)));
      final paragraphe =
          tester.renderObject<RenderParagraph>(find.text(kLongName));
      expect(paragraphe.size.height, greaterThan(15 * 1.5));
    });

    testWidgets('la largeur du nom ne bouge pas à font_scale 1.1',
        (tester) async {
      await tester.pumpWidget(
        _harness(
          _nouvelleLigne(kLongName),
          scaler: const TextScaler.linear(1.1),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.text(kLongName)).width, kLargeurDuNom);
    });

    testWidgets('la ligne de méta passe à la ligne au lieu de déborder',
        (tester) async {
      await tester.pumpWidget(_harness(_ligneDeMeta()));
      expect(tester.takeException(), isNull);
    });

    testWidgets('régression : la même méta en Row déborderait', (tester) async {
      await tester.pumpWidget(
        _harness(
          Row(
            children: [
              _pill('Officiel'),
              _pill('ACTIF'),
              _pill('Canada'),
              _pill('12'),
              _pill('Régional'),
            ],
          ),
        ),
      );
      expect(
        tester.takeException(),
        isA<FlutterError>().having(
          (e) => e.toString(),
          'message',
          contains('overflowed'),
        ),
      );
    });
  });
}
