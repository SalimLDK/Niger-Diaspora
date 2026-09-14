import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Garde-fou contre le retour de l'**échec muet**.
///
/// Le motif : une action rend `Future<bool>` — elle ne lève pas — et l'écran
/// n'annonce que le succès.
///
/// ```dart
/// final success = await notifier.acceptRequest(id);
/// if (context.mounted && success) {          // ← rien dans le cas false
///   ScaffoldMessenger.of(context).showSnackBar(...);
/// }
/// ```
///
/// Ce qu'il coûte : un refus de permission devient, à l'écran, un tap qui n'a
/// pas pris. Le bouton reprend son état, la carte reste là, à l'identique.
/// Rien n'est journalisé — ces échecs sont **attrapés**, donc ils ne passent
/// ni par `FlutterError.onError` ni par Crashlytics. Personne ne peut le
/// savoir, ni l'usager, ni nous.
///
/// Ce qu'il a coûté ici, deux fois au même endroit :
///
/// - accepter une demande d'ami était **impossible pendant des mois**, sur un
///   `PERMISSION_DENIED` que seul logcat voyait. Trouvé le 2026-08-05 en
///   testant le bouton à la main, pas par un rapport ;
/// - et de nouveau le 2026-09-14, pour une autre règle : le premier correctif
///   n'avait été appliqué qu'à **un** écran, alors que trois appellent la même
///   action.
///
/// La règle : une action qui peut échouer le dit. `messageErreurUsager`
/// (core/errors/message_erreur.dart) fournit le texte sans divulguer le
/// message brut, qui porte le chemin du document et l'uid.
///
/// **Limite assumée.** Ce test lit la source et ne connaît qu'une graphie,
/// `mounted && <nom>)`. Il n'attrape ni `if (!ok) return;` sans message, ni un
/// `catch` vide, ni un `bool` ignoré — un `bool` rendu par une action reste
/// une invitation au silence, que Dart ne sait pas refuser. Il ferme la porte
/// par laquelle le défaut est passé deux fois, pas toutes les portes.
void main() {
  /// Usages légitimes : le drapeau garde autre chose qu'une annonce à
  /// l'usager. Cette liste ne peut que rétrécir — n'y ajoutez rien sans une
  /// raison écrite, et jamais un `showSnackBar`.
  const exceptions = <String, String>{
    'lib/features/messages/presentation/screens/conversation_screen.dart':
        'garde un `_scrollToBottom()`, pas un message : il n\'y a rien à '
            'annoncer quand l\'envoi échoue ici, la bulle porte déjà son état.',
    // `business_reviews_screen.dart` est sorti de cette liste le 2026-09-14,
    // en passant sur le blocage — il avait DEUX branches muettes, pas la
    // seule que la note d'exception décrivait : la suppression d'un avis
    // (attrapée par le motif) et la réponse du gérant, écrite `ok &&
    // context.mounted`, que le motif ne voit pas. Les deux passent maintenant
    // par un `_annoncer` local. Le signalement d'un avis, lui, annonçait déjà
    // les deux cas : la note était périmée.
  };

  test('aucune action n\'annonce seulement son succès', () {
    // `success` / `ok` / `succes` : les noms effectivement employés ici. Un
    // motif plus large (`mounted && \w+`) attraperait
    // `mounted && _controller.value.isInitialized`, qui n'a rien à voir — et
    // un garde qui crie à tort finit désactivé.
    final motif = RegExp(r'mounted && (success|ok|succes|reussi)\)');

    final coupables = <String>[];
    for (final entite in Directory('lib').listSync(recursive: true)) {
      if (entite is! File || !entite.path.endsWith('.dart')) continue;
      final chemin = entite.path.replaceAll(r'\', '/');
      if (exceptions.containsKey(chemin)) continue;

      final lignes = entite.readAsLinesSync();
      for (var i = 0; i < lignes.length; i++) {
        if (motif.hasMatch(lignes[i])) {
          coupables.add('$chemin:${i + 1}');
        }
      }
    }

    expect(
      coupables,
      isEmpty,
      reason:
          'Ces branches n\'annoncent que le succès ; l\'échec y est muet.\n'
          'Annoncer les deux — voir `_annoncer` dans '
          'friend_request_item.dart :\n'
          '  if (context.mounted) {\n'
          '    final erreur = ref.read(unNotifierProvider).error;\n'
          '    ...Text(succes ? message : messageErreurUsager(erreur))\n'
          '  }\n'
          'Sites : ${coupables.join(', ')}',
    );
  });
}
