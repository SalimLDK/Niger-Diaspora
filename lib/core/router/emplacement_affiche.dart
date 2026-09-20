import 'package:go_router/go_router.dart';

/// Le chemin de la page réellement affichée, tout en haut de la pile — `null`
/// tant que le routeur n'a rien affiché.
///
/// **Ni `currentConfiguration.uri`, ni `routeInformationProvider.value`.** Dans
/// go_router 14, `RouteMatchList.uri` « ne reflète que les correspondances qui
/// ne sont pas impératives » : après un `context.push('/feed/abc')` — la façon
/// dont l'app ouvre presque tous ses écrans de détail —, il rend encore l'écran
/// de DESSOUS. `last` descend jusqu'à la feuille, à travers les coquilles
/// (`ShellRoute`), et pour une page poussée son `matchedLocation` est celui de
/// la page poussée. Vérifié par `emplacement_affiche_test.dart`, contre le vrai
/// routeur.
///
/// Le chemin est résolu (`/feed/abc`, pas `/feed/:id`) et sans requête.
String? emplacementAffiche(GoRouter routeur) =>
    routeur.routerDelegate.currentConfiguration.lastOrNull?.matchedLocation;
