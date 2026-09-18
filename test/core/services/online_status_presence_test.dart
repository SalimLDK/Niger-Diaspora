import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/core/services/online_status_service.dart';

/// Ré-afficher son statut en ligne après l'avoir masqué doit rétablir la
/// présence tout de suite.
///
/// `_setupPresenceForUser` retient l'uid AVANT de lire la préférence de
/// visibilité, puis sort sans poser d'écoute si le statut est masqué. Sa garde
/// « déjà suivi » ne regardait que l'uid : après un masquage, ré-afficher
/// (`updateOnlineStatusVisibility(true)`) retombait dessus et ne faisait rien.
/// L'utilisateur ne repassait « en ligne » qu'au prochain retour au premier
/// plan — et sans gestionnaire de déconnexion, donc restait « en ligne » si
/// l'app était tuée.
///
/// Le service tient des singletons Firebase et ne se monte pas en test : ce
/// banc fige le prédicat qui décide, pas le câblage complet — celui-ci reste à
/// voir sur appareil (voir « Un refus du serveur ne ment plus » dans
/// `TESTS_APPAREIL_A_FAIRE.md`).
void main() {
  bool suivi({
    required String? retenu,
    String uid = 'u1',
    required bool ecoute,
  }) => OnlineStatusService.isPresenceTracked(
    trackedUserId: retenu,
    userId: uid,
    hasConnectionListener: ecoute,
  );

  test('statut masqué (uid retenu, aucune écoute) : PAS « déjà suivi »', () {
    // C'est le cas qui piégeait : sans cette réponse, ré-afficher son statut
    // ne rétablissait rien.
    expect(suivi(retenu: 'u1', ecoute: false), isFalse);
  });

  test('statut visible et suivi : « déjà suivi », pas de double abonnement', () {
    expect(suivi(retenu: 'u1', ecoute: true), isTrue);
  });

  test('autre compte, même avec une écoute posée : pas « déjà suivi »', () {
    // Changement de compte : la présence de l'ancien ne vaut pas pour le
    // nouveau.
    expect(suivi(retenu: 'u1', uid: 'u2', ecoute: true), isFalse);
  });

  test('rien de retenu : pas « déjà suivi »', () {
    expect(suivi(retenu: null, ecoute: false), isFalse);
    expect(suivi(retenu: null, ecoute: true), isFalse);
  });
}
