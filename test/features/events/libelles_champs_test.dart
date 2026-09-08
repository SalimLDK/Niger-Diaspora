import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Garde-fou : un libellé de champ ne doit pas être un message d'erreur.
///
/// `descriptionRequired` vaut « La description est requise » — une phrase de
/// validation. Utilisée comme libellé, elle s'affiche telle quelle au-dessus
/// du champ, avant même que l'utilisateur ait touché à quoi que ce soit : le
/// formulaire a l'air de reprocher quelque chose qui n'a pas encore eu lieu.
/// Vu sur SM A515F le 2026-09-08 sur « Modifier l'événement ».
///
/// La clé ne peut pas être corrigée à la source : trois autres écrans
/// (`create_business_screen`, `create_group_screen`, `edit_group_screen`) s'en
/// servent bel et bien comme message d'erreur, ce pour quoi elle est faite.
/// C'est donc l'appel qui doit changer — `l10n.description` — et c'est ce que
/// ce test tient.
///
/// L'écran de création portait déjà le correctif et sa note ; l'écran
/// d'édition, non. D'où le garde-fou sur les deux.
void main() {
  const ecrans = [
    'lib/features/events/presentation/screens/edit_event_screen.dart',
    'lib/features/events/presentation/screens/create_event_screen.dart',
  ];

  /// Clés dont la valeur est une phrase de validation, pas un nom de champ.
  const messagesDErreur = ['descriptionRequired'];

  for (final chemin in ecrans) {
    test('aucun message d\'erreur en libellé de champ — $chemin', () {
      final source = File(chemin).readAsStringSync();
      final code = source
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');

      for (final cle in messagesDErreur) {
        expect(
          code.contains('_buildLabel(l10n.$cle)'),
          isFalse,
          reason:
              '`$cle` est un message de validation : il ne peut pas servir de '
              'libellé. Utiliser `l10n.description`.',
        );
      }
    });
  }
}
