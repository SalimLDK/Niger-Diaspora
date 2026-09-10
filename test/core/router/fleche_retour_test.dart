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

      // `path:` ne porte pas toujours un littéral. `PodcastsRoutes` déclare
      // ses chemins en constantes (`path: detail`), et la version précédente
      // de ce garde, qui découpait sur `path: '`, ne voyait donc **aucune**
      // des cinq routes podcasts — dont deux sont les cibles de liens que
      // l'app génère elle-même (`generatePodcastLink`, `generateEpisodeLink`).
      // Les cinq écrans n'avaient aucune sortie, et aucun test ne le disait.
      final constantes = <String, String>{};
      for (final m in RegExp(
        r"static const String (\w+)\s*=\s*'([^']*)'",
      ).allMatches(texte)) {
        constantes[m.group(1)!] = m.group(2)!;
      }

      final blocs = texte.split(RegExp(r'\n\s*path:\s*'));
      for (final bloc in blocs.skip(1)) {
        final String chemin;
        if (bloc.startsWith("'")) {
          chemin = bloc.substring(1).split("'").first;
        } else {
          // `path: detail` ou `path: PodcastsRoutes.detail`.
          final ident = RegExp(r'^(?:\w+\.)?(\w+)').firstMatch(bloc)?.group(1);
          final resolu = ident == null ? null : constantes[ident];
          if (resolu == null) continue;
          chemin = resolu;
        }
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

  test('les écrans dont la barre vit dans le contenu couvrent leurs états', () {
    // Troisième forme du défaut, trouvée sur appareil le 2026-09-08 et
    // invisible aux deux tests précédents : la fiche entreprise pose sa
    // `SliverAppBar` **à l'intérieur** de la branche « données ». Son
    // `Scaffold` n'a pas d'`appBar`, donc les états chargement / erreur /
    // « non trouvé » n'ont aucune sortie. `/businesses/<id>` sur une
    // entreprise absente affichait « Entreprise non trouvée » et rien pour
    // revenir — alors que le fichier contenait bien un `BackButton`, d'où
    // l'aveuglement d'un test qui raisonne au fichier.
    //
    // Liste nommée plutôt que détection structurelle : la version
    // structurelle écrite d'abord ne se déclenchait pas (elle laissait
    // passer le cas qu'elle visait), et un garde qui ne tombe jamais vaut
    // moins que rien. Limite assumée : **un nouvel écran de cette forme ne
    // sera pas attrapé** — s'il en apparaît un, l'ajouter ici.
    const aCouvrir = <String, String>{
      'lib/features/businesses/presentation/screens/business_detail_screen.dart':
          'SliverAppBar dans la branche données',
      'lib/features/marketplace/presentation/screens/product_detail_screen.dart':
          'SliverAppBar dans la branche données',
      'lib/features/transfers/presentation/screens/transfer_screen.dart':
          'Scaffold de chargement sans barre quand le profil manque',
      'lib/features/podcasts/presentation/screens/podcast_detail_screen.dart':
          'SliverAppBar dans la branche données',
      'lib/features/podcasts/presentation/screens/episode_detail_screen.dart':
          'SliverAppBar dans la branche données',
    };

    final coupables = <String>[];
    aCouvrir.forEach((chemin, raison) {
      final fichier = File(chemin);
      if (!fichier.existsSync()) {
        coupables.add('$chemin (fichier disparu)');
        return;
      }
      if (!fichier.readAsStringSync().contains('DesignExitOnlyBody')) {
        coupables.add('$chemin — $raison');
      }
    });

    expect(
      coupables,
      isEmpty,
      reason:
          'Ces écrans posent leur barre dans la branche « données » : leurs '
          'états chargement / erreur / « non trouvé » se retrouvent sans '
          'aucune sortie. Enveloppez ces états dans `DesignExitOnlyBody`.',
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
  test('la sortie de retour retombe sur une route, jamais sur un `pop()` nu', () {
    // **Quatrième forme**, mesurée sur SM A515F le 2026-09-09 et invisible
    // aux trois tests ci-dessus : la sortie est bien là, visible, et elle ne
    // fait rien.
    //
    // Les trois premiers gardes vérifient la *présence* d'un contrôle de
    // sortie ; celui-ci vérifie son *câblage*. Sur une pile d'une seule
    // route — ce qu'est toujours une route atteinte par lien profond ou par
    // notification — `context.pop()` n'a rien à dépiler : go_router 14.8.1
    // lève `GoError('There is nothing to pop')` (`delegate.dart:100`), que
    // rien n'attrape et que logcat ne montre pas (Crashlytics remplace
    // `FlutterError.onError`). `diasponiger:///services` puis un appui sur la
    // flèche : l'écran ne bouge pas. Le commentaire de
    // `group_members_screen.dart` note l'autre issue observée le même jour,
    // sur Pixel — la flèche renvoyait au lanceur.
    //
    // D'où l'invariant : toute sortie de retour porte le repli maison
    // `context.canPop() ? context.pop() : context.go(<parent>)`.
    //
    // **On ancre sur le rappel, pas sur l'icône.** La première version de ce
    // garde partait du marqueur visuel et cherchait le `onPressed:` qui suit —
    // elle ratait les `IconButton` qui déclarent `onPressed:` **avant**
    // `icon:`, soit deux écrans de la messagerie. L'ordre des arguments
    // nommés est libre en Dart ; seul le rappel est un point fixe.
    const exceptions = <String, String>{
      'lib/features/transfers/presentation/screens/transaction_history_screen.dart':
          'la croix ferme la feuille de filtres (showModalBottomSheet), '
              'pas la route : `Navigator.pop` y est le bon geste',
    };

    /// Retire les `//…` en gardant la longueur, pour que les index restent
    /// valides. Plusieurs commentaires du dépôt citent le motif fautif en
    /// exemple — les lire ferait tomber le garde sur des écrans corrigés.
    String sansCommentaires(String texte) {
      return texte
          .split('\n')
          .map((ligne) {
            final i = ligne.indexOf('//');
            if (i < 0) return ligne;
            final avant = ligne.substring(0, i);
            if ('"'.allMatches(avant).length.isOdd ||
                "'".allMatches(avant).length.isOdd) {
              return ligne;
            }
            return avant + ' ' * (ligne.length - i);
          })
          .join('\n');
    }

    // Le marqueur visuel et le repli tiennent tous deux à portée du rappel ;
    // au-delà on lit le widget voisin et on fabrique des faux positifs.
    const portee = 300;
    final rappelPop = RegExp(
      r'on(?:Pressed|Tap)\s*:\s*(?:\([^)]*\)\s*(?:async\s*)?=>\s*)?'
      r'(?:context\.pop\(\)|Navigator\.of\(context\)\.pop\(\)|'
      r'Navigator\.pop\(context\))',
    );

    final fichiers = declarations();
    final coupables = <String>[];
    final vus = <String>{};

    routes().forEach((chemin, classe) {
      final fichier = fichiers[classe];
      if (fichier == null) return;
      final rel = fichier.path.replaceAll('\\', '/');
      if (exceptions.keys.any(rel.endsWith)) return;
      if (!vus.add(rel)) return;

      final texte = sansCommentaires(fichier.readAsStringSync());
      for (final m in rappelPop.allMatches(texte)) {
        final zone = texte.substring(
          (m.start - portee).clamp(0, texte.length),
          (m.end + portee).clamp(0, texte.length),
        );
        // Sans marqueur autour, ce `pop()` ferme un dialogue ou une feuille,
        // pas la route : ce n'est pas la sortie de l'écran.
        if (!sorties.hasMatch(zone)) continue;
        // `if (context.canPop()) …` compte aussi : la sortie est alors
        // simplement masquée quand il n'y a rien à dépiler.
        if (zone.contains('canPop')) continue;

        final ligne = '\n'.allMatches(texte.substring(0, m.start)).length + 1;
        coupables.add('$rel:$ligne ($chemin)');
      }
    });

    expect(
      coupables,
      isEmpty,
      reason:
          'Ces sorties sont visibles mais mortes dès que la pile ne contient '
          "qu'elles — l'entrée par lien profond et par notification. "
          'Remplacez le `pop()` nu par '
          '`context.canPop() ? context.pop() : context.go(<parent>)`, avec le '
          'parent logique de la route, pas un `/home` uniforme.',
    );
  });
  test('aucune sortie n\'est masquée quand la pile est vide', () {
    // **Cinquième forme.** Une sortie peut être posée sous
    // `if (context.canPop()) …` : elle disparaît alors exactement dans le cas
    // qu'elle devait couvrir — l'entrée par lien profond ou par notification,
    // où la pile ne contient que cet écran.
    //
    // Les quatre gardes précédents la laissaient passer : le fichier contient
    // bien un marqueur de sortie (test 1) et le rappel voisine un `canPop`
    // (test 4). Deux écrans vivaient dessous, `/feed` et `/calls/history`,
    // tous deux avec la même justification écrite — « on n'y arrive que par un
    // push ». Fausse pour les deux : le point d'entrée de `/calls/history`
    // dans le profil est commenté, donc le lien profond et la notification
    // étaient les seules façons d'ouvrir cet écran.
    //
    // Liste d'exceptions volontairement vide : si un écran a besoin de cacher
    // sa sortie, la raison s'écrit ici.
    const exceptions = <String, String>{};

    final conditionnelle = RegExp(r'if\s*\(\s*context\.canPop\(\)\s*\)');
    const portee = 500;

    final fichiers = declarations();
    final coupables = <String>[];
    final vus = <String>{};

    routes().forEach((chemin, classe) {
      final fichier = fichiers[classe];
      if (fichier == null) return;
      final rel = fichier.path.replaceAll('\\', '/');
      if (exceptions.keys.any(rel.endsWith)) return;
      if (!vus.add(rel)) return;

      final texte = fichier.readAsStringSync();
      for (final m in conditionnelle.allMatches(texte)) {
        final zone = texte.substring(
          m.start,
          (m.start + portee).clamp(0, texte.length),
        );
        if (!sorties.hasMatch(zone)) continue;

        final ligne = '\n'.allMatches(texte.substring(0, m.start)).length + 1;
        coupables.add('$rel:$ligne ($chemin)');
      }
    });

    expect(
      coupables,
      isEmpty,
      reason:
          'Ces écrans ne montrent leur sortie que si la pile a de quoi '
          'dépiler — donc jamais par lien profond ni par notification, les '
          'deux entrées où elle est indispensable. Montrez-la toujours, avec '
          'le repli `canPop() ? pop() : go(<parent>)`.',
    );
  });
}
