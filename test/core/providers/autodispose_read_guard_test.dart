import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Garde-fou sur la lecture de `currentUserAsyncProvider`.
///
/// C'est un StreamProvider **autoDispose**. Le lire avec
/// `read(...).valueOrNull` depuis un écran qui ne le regarde pas démarre
/// l'abonnement à l'instant du tap et rend `AsyncLoading`, donc `null` : la
/// méthode sort alors sur son garde `if (user == null) return`, **avant**
/// d'atteindre le dépôt.
///
/// Signature du défaut, très reconnaissable et très coûteuse à diagnostiquer :
/// **bouton mort, pas de spinner, pas de message utile, rien dans logcat**
/// (Crashlytics remplace `onError`). Quand l'écran affiche quand même une
/// erreur, elle est *sans cause*, le `state` du notifier n'ayant jamais été
/// mis en erreur.
///
/// ~85 sites ont été convertis en `await read(...future)` le 2026-08-06, après
/// avoir constaté sur appareil que « Ouvrir la discussion » n'ouvrait rien, que
/// les messages ne se marquaient jamais comme lus, et que couper les
/// notifications ne coupait rien côté serveur.
///
/// Ce test lit la source plutôt que d'exercer les providers : les instancier
/// exigerait d'initialiser Firebase et Supabase. Il vérifie donc l'invariant
/// documenté, comme `profile_routes_order_test.dart`.
void main() {
  final lib = Directory('lib');

  List<({String path, int line, String text})> lignes() {
    final out = <({String path, int line, String text})>[];
    for (final f in lib.listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final lignes = f.readAsLinesSync();
      for (var i = 0; i < lignes.length; i++) {
        out.add((path: f.path.replaceAll(r'\', '/'), line: i + 1, text: lignes[i]));
      }
    }
    return out;
  }

  test('aucun `await read(...future)?.` : la précédence serait fausse', () {
    // `await x?.y` applique `await` à `x?.y`, pas à `x`. Le code ne compile pas
    // quand le résultat est utilisé, mais la forme est assez proche du correct
    // pour être écrite par réflexe — elle l'a été deux fois pendant la
    // conversion. Il faut `(await x)?.y`.
    final fautifs = lignes()
        .where((l) => RegExp(
              r'await\s+_?ref\.read\(currentUserAsyncProvider\.future\)\?\.',
            ).hasMatch(l.text))
        .map((l) => '${l.path}:${l.line}')
        .toList();

    expect(
      fautifs,
      isEmpty,
      reason: 'Parenthéser : (await ref.read(p.future))?.champ\n'
          '${fautifs.join('\n')}',
    );
  });

  test('aucune lecture synchrone suivie d\'un abandon silencieux', () {
    // C'est la COMBINAISON qui est dangereuse, pas la lecture seule : une
    // lecture dont le résultat est simplement affiché, ou qui a un repli, se
    // dégrade proprement. Le défaut naît du garde qui sort sans rien dire —
    // `return`, `return null`, `return false` — juste après.
    //
    // Les sites tolérés ci-dessous sont dans des méthodes NON `async`, où
    // `await` ne compilerait pas, et sur des chemins d'affichage ou
    // d'arrière-plan — pas sur une action utilisateur. Toute NOUVELLE
    // occurrence doit être convertie, ou ajoutée ici AVEC SA RAISON.
    const tolerees = <String>{
      // _preEstablishE2EESessions — préchauffage E2EE, void non async
      'lib/features/messages/presentation/providers/message_provider.dart',
      // _loadDefaultCountryFilter — pré-remplissage du filtre, void non async
      'lib/features/groups/presentation/screens/groups_screen.dart',
      // _loadDefaultCountryFromProfile — pré-remplissage, void non async
      'lib/features/groups/presentation/screens/create_group_screen.dart',
      // _checkIfLastParticipant — écouteur de participants, void non async
      'lib/features/group_calls/presentation/providers/group_call_provider.dart',
      // retryAudioConnection — void non async
      'lib/features/audio_rooms/presentation/providers/audio_room_provider.dart',
      // _startHeartbeat — void non async
      'lib/features/calls/presentation/providers/call_provider.dart',
    };

    final motif = RegExp(r'_?ref\.read\(currentUserAsyncProvider\)\.valueOrNull');
    // Un `return` NU sur la même ligne. Un `if (x == null) { … }` qui ouvre un
    // bloc n'est pas visé : c'est la forme d'un repli, pas d'un abandon.
    final abandon = RegExp(r'if\s*\(.*==\s*null\).*return[^;]*;');

    final toutes = lignes();
    final parFichier = <String, List<String>>{};
    for (var i = 0; i < toutes.length; i++) {
      final l = toutes[i];
      if (!motif.hasMatch(l.text)) continue;
      if (tolerees.any((t) => l.path.endsWith(t))) continue;
      // Le garde suit immédiatement, ou une ligne plus bas.
      final suite = [
        if (i + 1 < toutes.length && toutes[i + 1].path == l.path) toutes[i + 1].text,
        if (i + 2 < toutes.length && toutes[i + 2].path == l.path) toutes[i + 2].text,
      ];
      if (suite.any(abandon.hasMatch)) {
        parFichier.putIfAbsent(l.path, () => []).add('${l.path}:${l.line}');
      }
    }

    final inattendus = parFichier.values.expand((v) => v).toList()..sort();

    expect(
      inattendus,
      isEmpty,
      reason:
          'Lecture synchrone de currentUserAsyncProvider suivie d\'un abandon\n'
          'silencieux : l\'action échouera sans message ni trace.\n'
          'Si la méthode est `async` :\n'
          '  final user = await ref.read(currentUserAsyncProvider.future);\n'
          'et poser une VRAIE erreur si `user` est null.\n'
          '⚠️ Avec un accès derrière, parenthéser : (await ...)?.id\n'
          'Si elle ne peut pas être async, ajouter le fichier aux `tolerees`\n'
          'avec sa raison.\n'
          '${inattendus.join('\n')}',
    );
  });

  test('aucun abandon silencieux sur profileNotifierProvider', () {
    // Le piège ne se limite pas à `currentUserAsyncProvider` — c'est la leçon
    // la plus chère de la session. `profileNotifierProvider` est un
    // StateNotifierProvider **autoDispose** dont `_loadProfile()` ne pose
    // `state` de façon synchrone que s'il TROUVE UN CACHE. Sans cache, un
    // `read(...).valueOrNull` rend `null`, et il a piégé trois fois :
    // l'interrupteur maître des notifications n'écrivait pas son étage serveur
    // (le back-end continuait de pousser), l'enregistrement du profil échouait
    // au premier essai, et les bascules de préférence revenaient à leur
    // position sans explication.
    //
    // Un StateNotifierProvider n'expose pas de `.future` : le correctif est un
    // repli explicite sur le dépôt, pas un `await`. La forme
    // `if (x == null) { …charger… }` est donc ATTENDUE et n'est pas visée ici ;
    // seul le `return` nu l'est.
    const tolerees = <String>{
      // _suggestedGroupsCount — rend 0 pour un comptage d'affichage, méthode
      // synchrone : dégradation acceptable, aucune action n'est perdue.
      'lib/features/groups/presentation/screens/groups_screen.dart',
      // set() — l'abandon suit `_profil()`, qui a DÉJÀ tenté le dépôt : si le
      // profil manque encore, il est réellement introuvable.
      'lib/features/profile/presentation/providers/profile_preferences_provider.dart',
    };

    final motif = RegExp(r'_?ref\.read\(profileNotifierProvider\([^)]*\)\)\.valueOrNull');
    final abandon = RegExp(r'if\s*\(.*==\s*null\).*return[^;]*;');

    final toutes = lignes();
    final inattendus = <String>[];
    for (var i = 0; i < toutes.length; i++) {
      final l = toutes[i];
      if (!motif.hasMatch(l.text)) continue;
      if (tolerees.any((t) => l.path.endsWith(t))) continue;
      final suite = [
        if (i + 1 < toutes.length && toutes[i + 1].path == l.path) toutes[i + 1].text,
        if (i + 2 < toutes.length && toutes[i + 2].path == l.path) toutes[i + 2].text,
      ];
      if (suite.any(abandon.hasMatch)) inattendus.add('${l.path}:${l.line}');
    }
    inattendus.sort();

    expect(
      inattendus,
      isEmpty,
      reason:
          'Lecture de profileNotifierProvider suivie d\'un abandon silencieux.\n'
          'Ce provider rend `null` tant que le profil n\'est pas en cache.\n'
          'Retomber sur le dépôt plutôt qu\'abandonner :\n'
          '  var p = ref.read(profileNotifierProvider(id)).valueOrNull;\n'
          '  if (p == null) {\n'
          '    final r = await ref.read(profileRepositoryProvider).getProfile(id);\n'
          '    p = r.fold((_) => null, (v) => v);\n'
          '  }\n'
          '${inattendus.join('\n')}',
    );
  });
}
