import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Garde-fou sur l'ordre de déclaration des routes `/profile/*`.
///
/// GoRouter résout dans l'ordre de déclaration. Si `/profile/:userId` est
/// déclarée avant les sous-routes statiques, « my-posts » est capturé comme
/// un userId : ProfileViewScreen charge un profil inexistant et affiche
/// « Profil supprimé ». La régression a déjà eu lieu une fois.
///
/// Limite assumée : ce test lit la source au lieu de construire le routeur.
/// `routerProvider` dépend des providers d'authentification, donc l'instancier
/// exigerait d'initialiser Firebase. Il vérifie donc l'invariant documenté
/// dans app_router.dart, pas le comportement de résolution de GoRouter.
void main() {
  test('les sous-routes /profile statiques précèdent /profile/:userId', () {
    final source = File('lib/core/router/app_router.dart').readAsStringSync();

    final catchAll = source.indexOf("path: '/profile/:userId'");
    expect(
      catchAll,
      isNonNegative,
      reason: 'route /profile/:userId introuvable — test à réviser',
    );

    for (final staticPath in const [
      '/profile/edit',
      '/profile/my-posts',
      '/profile/saved-posts',
      '/profile/reposts',
    ]) {
      final index = source.indexOf("path: '$staticPath'");
      expect(
        index,
        isNonNegative,
        reason: 'route $staticPath introuvable — supprimée ou renommée ?',
      );
      expect(
        index,
        lessThan(catchAll),
        reason: '$staticPath doit être déclarée AVANT /profile/:userId, '
            'sinon GoRouter la capture comme un userId',
      );
    }
  });
}
