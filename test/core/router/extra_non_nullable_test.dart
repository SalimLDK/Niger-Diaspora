import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Garde-fou : aucune route ne doit transtyper `state.extra` vers un type
/// **non nullable**.
///
/// `state.extra` est nul par construction sur un lien profond et sur une
/// notification — c'est une famille de défauts déjà bien documentée du
/// projet. Le transtypage `state.extra as Truc` (sans `?`) ne dégrade pas :
/// il lève un `TypeError` avant même que l'écran ne se monte, donc l'écran
/// rouge est **systématique** sur ces chemins-là, jamais intermittent.
///
/// Trois routes en portaient un, corrigées le 2026-09-08 :
/// `/events/:eventId/edit`, `/events/:eventId/recap` et
/// `/groups/:groupId/edit`.
///
/// Deux formes restent permises :
/// - `as Truc?`, qui rend `null` proprement — à charge pour la route de
///   résoudre l'identifiant, ce que vérifient les tests widget ;
/// - `state.extra is Truc ? state.extra as Truc : null`, où le cast est gardé
///   par un test de type juste avant (`/events/create`).
///
/// Limite assumée : ce test lit le fichier du routeur. Il attrape la forme
/// dangereuse, pas une route qui résoudrait mal son identifiant.
void main() {
  test('aucune route ne caste state.extra vers un type non nullable', () {
    final source = File('lib/core/router/app_router.dart').readAsStringSync();

    // Les commentaires du routeur citent la forme fautive pour expliquer le
    // correctif : les retirer avant de chercher, sinon l'explication
    // déclencherait l'alarme qu'elle documente.
    final code = source
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');

    // `as <Type>`, génériques compris, non suivi de `?`.
    //
    // Le `<` dans la classe interdite n'est pas decoratif : sans lui, le
    // moteur retombe sur `Map` seul devant `Map<String, dynamic>?` et le
    // declare fautif. Le `\w` interdit de meme le repli sur `TrucEntit`
    // devant `TrucEntity?`.
    final casts = RegExp(
      r'state\.extra\s+as\s+([A-Za-z_][A-Za-z0-9_]*(?:<[^>]*>)?)(?![\w?<])',
    ).allMatches(code);

    final fautifs = <String>[];
    for (final m in casts) {
      final type = m.group(1)!;
      final avant = code.substring(
        (m.start - 120).clamp(0, code.length),
        m.start,
      );
      if (avant.contains('state.extra is $type')) continue;
      fautifs.add(type);
    }

    expect(
      fautifs,
      isEmpty,
      reason:
          'Ces transtypages plantent par lien profond (extra nul) : '
          '${fautifs.join(', ')}. Résoudre l\'identifiant depuis '
          '`state.pathParameters` à la place.',
    );
  });
}
