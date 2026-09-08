import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Garde-fou : un écran atteint par `push` doit montrer comment en sortir,
/// **y compris quand la pile ne contient que lui**.
///
/// Trois défauts distincts se sont succédé sur cette seule question, tous
/// invisibles en lisant l'écran seul :
///
/// - `DesignScreenHeader.leading` est facultatif, parce que les cinq onglets
///   racines n'en veulent pas. Un écran poussé qui recopie l'en-tête d'un
///   onglet hérite donc de son absence de flèche (Notifications, Annuaire).
/// - `automaticallyImplyLeading: false` supprime la flèche que Flutter aurait
///   posée seul. Le drapeau se justifie sur un onglet ; il avait été recopié
///   sur deux écrans poussés (Événements, Ambassades).
/// - **Et retirer ce drapeau ne suffit pas** : Flutter ne pose sa flèche
///   implicite que si `Navigator.canPop()` est vrai. Par lien profond ou par
///   notification système, la pile ne contient que cet écran — l'écran n'a
///   alors aucune sortie. Vérifié sur SM A515F le 2026-09-08 :
///   `diasponiger:///events` en démarrage à froid, drapeau retiré, affichait
///   Événements sans flèche.
///
/// D'où l'invariant tenu ici : **une sortie explicite**, pas la flèche
/// implicite. `DesignBackLeading` pour les en-têtes `DesignScreenHeader`,
/// `BackButton` pour les `AppBar`, les deux avec le repli
/// `canPop() ? pop() : go(<parent>)`.
///
/// Le test lit le routeur, pas les écrans : c'est la route qui dit si l'écran
/// est poussé ou racine, et c'est cette information-là qui manquait.
///
/// Limite assumée : on vérifie la *présence* d'un contrôle de sortie dans le
/// fichier, pas qu'il soit branché ni visible. Monter chaque écran en test
/// widget demanderait l10n, GoRouter et des dizaines de providers. Ce garde
/// attrape la famille de défauts observée — la sortie absente — pas une
/// sortie mal câblée.
void main() {
  /// Routes qui n'ont légitimement pas de flèche, avec la raison.
  /// Cette liste ne peut que rétrécir : rien ne s'y ajoute sans raison écrite.
  const exceptions = <String, String>{
    // Les cinq onglets de la barre du bas : rien à dépiler sous eux.
    '/home': 'onglet racine',
    '/map': 'onglet racine',
    '/groups': 'onglet racine',
    '/messages': 'onglet racine',
    '/profile': 'onglet racine',

    // Parcours d'entrée : on ne revient pas en arrière dans une connexion.
    '/splash': 'écran de lancement',
    '/maintenance': 'écran bloquant',
    '/auth/login': 'entrée du parcours de connexion',
    '/auth/register': 'entrée du parcours de connexion',
    '/auth/forgot-password': 'entrée du parcours de connexion',
    '/consent': 'consentement obligatoire avant usage',
    '/onboarding/intro': 'entrée du parcours de découverte',
    '/profile-config': 'configuration obligatoire du profil',

    // Sortie dédiée, plus explicite qu'une flèche.
    '/calls/:callId': 'sortie par le bouton raccrocher',

    // Présenté comme feuille par `MainShell`, jamais empilé comme page.
    '/share': 'feuille modale, sortie par glissement',
  };

  /// Contrôles de sortie **visibles même quand la pile est vide**. La flèche
  /// implicite de l'AppBar n'en fait délibérément pas partie : c'est tout
  /// l'objet de ce garde. `keyboard_arrow_down` est la sortie des lecteurs
  /// plein écran (replay), `close` celle des visionneuses.
  final sorties = RegExp(
    r'DesignBackLeading|BackButton\(|arrow_back|AppIcon\.arrowBack|'
    r'chevron_left|Icons\.close|AppIcon\.close|keyboard_arrow_down',
  );

  /// Routes du routeur, associées à l'écran qu'elles construisent.
  Map<String, String> routes() {
    final sources = <File>[
      File('lib/core/router/app_router.dart'),
      ...Directory('lib/core/router/routes')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart')),
    ];

    final resultat = <String, String>{};
    final ecran = RegExp(r'\b([A-Z][A-Za-z0-9_]*(?:Screen|Page|View))\b');
    // `NoTransitionPage` et consorts enveloppent l'écran : ce sont des pages
    // de GoRouter, pas des écrans du projet.
    const enveloppes = {
      'NoTransitionPage',
      'MaterialPage',
      'CustomTransitionPage',
      'ShellPage',
    };

    for (final source in sources) {
      final texte = source.readAsStringSync();
      final blocs = texte.split(RegExp(r"\n\s*path:\s*'"));
      for (final bloc in blocs.skip(1)) {
        final chemin = bloc.split("'").first;
        final classes = ecran
            .allMatches(bloc.length > 4000 ? bloc.substring(0, 4000) : bloc)
            .map((m) => m.group(1)!)
            .where((c) => !enveloppes.contains(c));
        if (classes.isNotEmpty) resultat[chemin] = classes.first;
      }
    }
    return resultat;
  }

  /// Fichier déclarant chaque classe de `lib/`.
  Map<String, File> declarations() {
    final resultat = <String, File>{};
    final declaration = RegExp(
      r'^class\s+([A-Z][A-Za-z0-9_]*)\b',
      multiLine: true,
    );
    for (final fichier in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      for (final m in declaration.allMatches(fichier.readAsStringSync())) {
        resultat.putIfAbsent(m.group(1)!, () => fichier);
      }
    }
    return resultat;
  }

  test('chaque écran poussé a une sortie visible même pile vide', () {
    final fichiers = declarations();
    final coupables = <String>[];

    routes().forEach((chemin, classe) {
      if (exceptions.containsKey(chemin)) return;
      final fichier = fichiers[classe];
      if (fichier == null) return;
      if (sorties.hasMatch(fichier.readAsStringSync())) return;
      coupables.add('$chemin ($classe)');
    });

    expect(
      coupables,
      isEmpty,
      reason:
          'Ces routes sont atteintes par `push` mais leur écran ne montre '
          'aucune sortie explicite. La flèche implicite de l\'AppBar ne '
          'compte pas : elle disparaît en entrée par lien profond ou par '
          'notification. Posez `leading: const DesignBackLeading()` sur le '
          'DesignScreenHeader, ou `leading: BackButton(onPressed: () => '
          'context.canPop() ? context.pop() : context.go(<parent>))` sur '
          'l\'AppBar.',
    );
  });

  test('aucun écran poussé ne supprime la flèche que Flutter poserait', () {
    final fichiers = declarations();
    final coupables = <String>[];

    routes().forEach((chemin, classe) {
      if (exceptions.containsKey(chemin)) return;
      final fichier = fichiers[classe];
      if (fichier == null) return;
      final texte = fichier.readAsStringSync();
      if (!RegExp(r'automaticallyImplyLeading:\s*false').hasMatch(texte)) return;
      if (sorties.hasMatch(texte)) return;
      coupables.add('$chemin ($classe)');
    });

    expect(
      coupables,
      isEmpty,
      reason:
          '`automaticallyImplyLeading: false` retire la flèche de retour de '
          "l'AppBar. Sur un écran poussé, il faut alors un contrôle de sortie "
          'explicite.',
    );
  });
}
