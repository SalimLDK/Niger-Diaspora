import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Garde-fou : un écran atteint par `push` doit montrer comment en sortir.
///
/// Quatre écrans du menu principal — Notifications, Annuaire des entreprises,
/// Événements et Ambassades — n'avaient aucune flèche de retour. Deux causes,
/// toutes deux invisibles à la relecture de l'écran seul :
///
/// - `DesignScreenHeader` rend sa flèche facultative (`leading`), parce que
///   les cinq onglets racines n'en veulent pas. Un écran poussé qui recopie
///   l'en-tête d'un onglet hérite donc de son absence de flèche.
/// - `automaticallyImplyLeading: false` sur une `AppBar` supprime la flèche
///   que Flutter aurait posée seul. Le drapeau se justifie sur un onglet ; il
///   avait été recopié sur deux écrans poussés.
///
/// Le test lit le routeur, pas les écrans : c'est la route qui dit si l'écran
/// est poussé ou racine, et c'est cette information-là qui manquait.
///
/// Limite assumée : on vérifie la *présence* d'un contrôle de sortie dans le
/// fichier, pas qu'il soit branché ni visible à l'écran. Monter chaque écran
/// en test widget demanderait l10n, GoRouter et des dizaines de providers.
/// Ce garde attrape la famille de défauts observée — la flèche absente — et
/// pas une flèche mal câblée.
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
    '/consent': 'consentement obligatoire avant usage',
    '/onboarding/intro': 'entrée du parcours de découverte',

    // Sorties dédiées, plus explicites qu'une flèche.
    '/calls/:callId': 'sortie par le bouton raccrocher',

    // Présenté comme feuille par `MainShell`, jamais empilé comme page.
    '/share': 'feuille modale, sortie par glissement',

    // Page du tableau de bord admin, routée mais poussée par personne : elle
    // rend une `Column` nue, sans `Scaffold` ni en-tête.
    '/admin/embassies': 'page interne du tableau de bord admin',
  };

  /// Contrôles de sortie acceptés. `keyboard_arrow_down` est celui des
  /// lecteurs plein écran (replay), `close` celui des visionneuses.
  final sorties = RegExp(
    r'DesignBackLeading|arrow_back|BackButton\(|chevron_left|'
    r'AppIcon\.arrowBack|Icons\.close|AppIcon\.close|keyboard_arrow_down',
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
    final declaration = RegExp(r'^class\s+([A-Z][A-Za-z0-9_]*)\b', multiLine: true);
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

  test('chaque écran poussé expose un contrôle de sortie', () {
    final fichiers = declarations();
    final coupables = <String>[];

    routes().forEach((chemin, classe) {
      if (exceptions.containsKey(chemin)) return;
      final fichier = fichiers[classe];
      if (fichier == null) return;
      final texte = fichier.readAsStringSync();
      // Une `AppBar` sans `leading` explicite pose la flèche toute seule.
      final barreImplicite = RegExp(r'AppBar\(').hasMatch(texte) &&
          !RegExp(r'automaticallyImplyLeading:\s*false').hasMatch(texte);
      if (barreImplicite || sorties.hasMatch(texte)) return;
      coupables.add('$chemin ($classe)');
    });

    expect(
      coupables,
      isEmpty,
      reason:
          'Ces routes sont atteintes par `push` mais leur écran ne montre '
          'aucun moyen de revenir. Posez `leading: const DesignBackLeading()` '
          'sur son DesignScreenHeader ou son AppBar.',
    );
  });

  test('les écrans corrigés gardent une sortie visible pile vide', () {
    // La flèche *implicite* de l'AppBar (`automaticallyImplyLeading`)
    // disparaît quand `Navigator.canPop()` est faux — vérifié sur SM A515F
    // le 2026-09-08 : `diasponiger:///events` en démarrage à froid affichait
    // Événements sans aucune sortie. Ces cinq écrans ont donc un contrôle
    // explicite ; ne pas les « simplifier » en retirant le `leading`.
    const explicites = <String>[
      '/notifications',
      '/businesses',
      '/events',
      '/embassies',
      '/settings',
    ];
    final controle = RegExp(r'DesignBackLeading|BackButton\(');
    final fichiers = declarations();
    final coupables = <String>[];

    final table = routes();
    for (final chemin in explicites) {
      final classe = table[chemin];
      if (classe == null) {
        coupables.add('$chemin (route disparue du routeur)');
        continue;
      }
      final fichier = fichiers[classe];
      if (fichier == null) continue;
      if (!controle.hasMatch(fichier.readAsStringSync())) {
        coupables.add('$chemin ($classe)');
      }
    }

    expect(
      coupables,
      isEmpty,
      reason:
          'Ces écrans ont perdu leur contrôle de sortie explicite. La flèche '
          "implicite de l'AppBar ne suffit pas : elle disparaît en entrée "
          'par lien profond ou par notification.',
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
          'explicite — `leading: const DesignBackLeading()`.',
    );
  });
}
