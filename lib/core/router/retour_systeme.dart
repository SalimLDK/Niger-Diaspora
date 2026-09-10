import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Le retour **système** d'Android — bouton ou geste — sur une route atteinte
/// par lien profond.
///
/// Une telle route est **seule dans la pile** : le routeur rejoue la
/// destination par un `go`, qui remplace la pile au lieu de l'empiler. Le geste
/// système ne passe alors ni par la flèche de l'en-tête ni par un
/// `context.pop()` métier — il descend jusqu'à Android, qui **quitte
/// l'application**. Mesuré sur SM A515F le 2026-09-09 :
/// `diasponiger:///services` puis retour système renvoyait au lanceur, alors
/// que l'utilisateur venait juste d'entrer dans l'app.
///
/// **Deux pièces sont nécessaires, et la seconde est celle qu'on oublie.**
///
/// 1. [didPopRoute] traite le geste quand personne d'autre ne l'a fait.
/// 2. [surNavigation] **réclame** le geste auprès d'Android. Sans elle la
///    première ne s'exécute jamais : `android:enableOnBackInvokedCallback` vaut
///    `true` (obligatoire à partir de targetSdk 36), donc Android ne route le
///    retour vers Flutter que si le framework s'est annoncé preneur, via
///    `SystemNavigator.setFrameworkHandlesBack`. Or c'est le `Navigator` qui
///    répond à cette question, et sur une pile d'une seule route il répond
///    « non ». Première version livrée sans cette pièce : dispatcher branché,
///    tests verts, et le retour quittait toujours l'app sur appareil.
///
/// Le repli est volontairement `/home` et non le parent de la route,
/// contrairement à celui des flèches d'en-tête. Deux raisons : le parent d'un
/// chemin n'est pas toujours une route déclarée (`/p/u/<id>`, `/services`), et
/// le geste système n'a pas la précision d'une flèche — « ramène-moi dans
/// l'app » est ce qu'il veut dire ici.
///
/// Les écrans qui portent déjà un `PopScope` gardent la main : `popRoute()`
/// passe par `maybePop()`, qui les consulte et rend `true`. On n'arrive au
/// repli que lorsque personne n'a traité le geste.
class RetourSystemeVersAccueil extends RootBackButtonDispatcher {
  RetourSystemeVersAccueil(this._routeur);

  final GoRouter _routeur;

  /// Routes où quitter l'application **est** le bon comportement : les cinq
  /// onglets de la barre du bas (rien au-dessous d'eux) et le parcours
  /// d'entrée, où renvoyer sur `/home` ne ferait que rebondir sur la garde du
  /// routeur — le retour paraîtrait mort au lieu de sortir.
  static const _sansRepli = <String>{
    '/home',
    '/map',
    '/groups',
    '/messages',
    '/profile',
    '/splash',
    '/consent',
    '/profile-config',
    '/onboarding/intro',
    '/maintenance',
  };

  /// Y a-t-il un repli à offrir depuis l'écran courant ?
  bool get peutRattraper {
    final chemin = _routeur.state.matchedLocation;
    return !_sansRepli.contains(chemin) && !chemin.startsWith('/auth');
  }

  /// À brancher sur `MaterialApp.onNavigationNotification`.
  ///
  /// Reprend le comportement par défaut de `WidgetsApp` — y compris son garde
  /// de cycle de vie, qui évite de parler au moteur avant qu'il soit prêt — en
  /// ajoutant notre cas : le `Navigator` n'a rien à dépiler, mais nous, si.
  bool surNavigation(NavigationNotification notification) {
    final etat = WidgetsBinding.instance.lifecycleState;
    if (etat == null || etat == AppLifecycleState.detached) return true;

    SystemNavigator.setFrameworkHandlesBack(
      notification.canHandlePop || peutRattraper,
    );
    return true;
  }

  @override
  Future<bool> didPopRoute() async {
    if (await super.didPopRoute()) return true;
    if (!peutRattraper) return false;

    _routeur.go('/home');
    return true;
  }
}
