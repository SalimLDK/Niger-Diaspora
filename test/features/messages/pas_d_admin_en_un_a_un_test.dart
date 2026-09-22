import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Un 1:1 n'a pas d'administrateur.
///
/// La bulle recevait `isAdmin` vrai pour « celui qui a créé la conversation »,
/// et la boîte de suppression offrait alors « Supprimer pour tous » sur les
/// messages de L'AUTRE. Le serveur refuse (`mls_supprimer_pour_tous` exige
/// l'expéditeur) — mais rien ne le disait à l'écran. Vu le 2026-09-21 sur
/// SM A515F : Sim, créateur du 1:1, se voyait proposer de supprimer pour tous
/// un message de Salim.
void main() {
  test('le rôle admin de la bulle ne vient que du groupe', () {
    final source = File(
      'lib/features/messages/presentation/screens/conversation_screen.dart',
    ).readAsStringSync().replaceAll('\r\n', '\n');
    // Le calcul transmis à `MessageBubble` : celui qui voisine avec
    // `groupForAdminCheck`.
    final debut = source.indexOf('final isAdmin =\n            _isGroup &&');
    expect(debut, isNot(-1),
        reason: 'isAdmin doit commencer par `_isGroup &&` : hors groupe, faux');
    final bloc = source.substring(debut, source.indexOf(';', debut));
    expect(bloc, isNot(contains('createdBy')),
        reason: 'créer un 1:1 ne donne aucun droit sur les messages de l\'autre');
  });

  test('un échec de « supprimer pour tous » se dit', () {
    final source = File(
      'lib/features/messages/presentation/widgets/delete_message_modal.dart',
    ).readAsStringSync();
    expect(source, contains('deleteForEveryoneFailed'));
  });
}
