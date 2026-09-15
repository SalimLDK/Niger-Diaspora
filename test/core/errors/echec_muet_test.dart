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
/// ## Ce que ce garde a lui-même raté
///
/// Écrit le 2026-09-14, il ne connaissait qu'une graphie — `mounted && ok)`.
/// Mesuré le 2026-09-15 : **une** occurrence de celle-là dans `lib/`, contre
/// **seize** de la graphie inverse, `ok && mounted)`. Il ne regardait donc
/// qu'un site sur dix-sept. La session « blocage » l'avait signalé le jour
/// même en trouvant une branche muette que le motif ne voyait pas ; c'est
/// resté noté et non fait.
///
/// Deux changements depuis : les **deux** graphies sont reconnues, et une
/// occurrence n'est retenue que si aucune branche d'échec ne suit. Sans ce
/// second point, les seize crieraient toutes — or plusieurs ont bel et bien
/// leur `else if (mounted)`. Un garde qui crie à tort finit désactivé, et
/// c'est ce qui était en train de lui arriver.
///
/// **Limites assumées.** Le test lit la source, pas un arbre syntaxique :
/// - le bloc est délimité en comptant les accolades, pas par une fenêtre de
///   lignes. La première version lisait 22 lignes après le `if` : trop court
///   pour `edit_event_screen`, dont le bloc de succès fait quarante lignes —
///   son `else` existait et le garde criait quand même. Une fenêtre fixe
///   accuse les blocs longs, ce qui est précisément la mauvaise moitié ;
/// - le comptage est naïf : une accolade dans un commentaire le déséquilibre.
///   L'interpolation `${…}` s'équilibre seule, donc ne gêne pas ;
/// - il n'attrape ni `if (!ok) return;` sans message, ni un `catch` vide, ni
///   un `bool` ignoré. Un `bool` rendu par une action reste une invitation au
///   silence, que Dart ne sait pas refuser.
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
    // context.mounted`, que le motif ne voyait pas. Les deux passent
    // maintenant par un `_annoncer` local.
  };

  test('aucune action n\'annonce seulement son succès', () {
    // Les deux graphies, et seulement les noms de drapeau réellement employés
    // ici. `mounted && \w+` attraperait `mounted && _controller.value
    // .isInitialized`, qui n'a rien à voir.
    const drapeaux = r'(success|ok|succes|reussi)';
    // `(?<![!\w.])` écarte `if (!ok && context.mounted)`, qui n'annonce QUE
    // l'échec — l'inverse exact du défaut — et `isOk`, `_lastOk` et consorts.
    // Sans lui, `groups_screen.dart` était accusé pour une ligne juste.
    // L'autre graphie n'a pas besoin de la garde : `mounted && !ok)` ne
    // correspond simplement pas.
    final motif = RegExp(
      '(mounted && $drapeaux\\)'
      '|(?<![!\\w.])$drapeaux && (context\\.)?mounted\\))',
    );
    final coupables = <String>[];
    for (final entite in Directory('lib').listSync(recursive: true)) {
      if (entite is! File || !entite.path.endsWith('.dart')) continue;
      final chemin = entite.path.replaceAll(r'\', '/');
      if (exceptions.containsKey(chemin)) continue;

      final lignes = entite.readAsLinesSync();
      for (var i = 0; i < lignes.length; i++) {
        if (!motif.hasMatch(lignes[i])) continue;
        if (!_suiviDUneBrancheDEchec(lignes, i)) {
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

/// Vrai si le bloc ouvert à [depart] est suivi d'un `else`.
///
/// On suit les accolades jusqu'à la fermeture du bloc, puis on regarde si un
/// `else` la suit — sur la même ligne (`} else {`) ou sur la suivante.
bool _suiviDUneBrancheDEchec(List<String> lignes, int depart) {
  const plafond = 300; // une méthode raisonnable ; évite de lire un fichier
  var profondeur = 0;
  var ouvert = false;

  for (var i = depart; i < lignes.length && i - depart < plafond; i++) {
    final ligne = lignes[i];
    for (var j = 0; j < ligne.length; j++) {
      final c = ligne[j];
      if (c == '{') {
        profondeur++;
        ouvert = true;
      } else if (c == '}') {
        profondeur--;
        if (ouvert && profondeur == 0) {
          // Fermeture du bloc : le `else` est ici, ou au début de la suivante.
          final reste = ligne.substring(j);
          if (reste.contains('else')) return true;
          for (var k = i + 1; k < lignes.length && k <= i + 2; k++) {
            final suivante = lignes[k].trim();
            if (suivante.isEmpty) continue;
            return suivante.startsWith('else');
          }
          return false;
        }
      }
    }
  }
  // Bloc jamais refermé dans le plafond : on ne conclut pas à un défaut.
  return true;
}
