import '../../../auth/domain/repositories/auth_repository.dart';

/// Ce que l'écran écrit quand un compte sans droits d'administration a été
/// refusé et sa session refermée.
const String messageRefusNonAdmin =
    'Accès refusé. Compte administrateur requis.';

/// Compte authentifié mais sans droits d'administration : on referme sa
/// session, et on rend le message à écrire à l'écran.
///
/// `signOut` rend un `Either`, et un `Left` veut dire que la session est
/// **toujours ouverte**. Il était lancé en `unawaited(...)` et son résultat
/// jeté : l'écran affichait « Accès refusé » que la déconnexion ait eu lieu
/// ou non, et un compte sans droits restait connecté sur le panneau sans que
/// personne le sache. Le message n'est rendu qu'une fois le résultat connu,
/// et il dit quand la session n'a pas pu être fermée.
///
/// Partagé par l'écran de connexion et l'écran de défi du second facteur :
/// un compte sans droits qui a un facteur enrôlé arrive par le second, et
/// doit être refusé de la même façon.
Future<String> refuserNonAdmin(AuthRepository authRepo) async {
  var sessionFermee = false;
  try {
    sessionFermee = (await authRepo.signOut()).isRight();
  } catch (_) {
    // `signOut` ne lève pas en principe ; si cela arrive, la session est
    // aussi peu fermée que sur un `Left`.
  }
  return sessionFermee
      ? messageRefusNonAdmin
      : '$messageRefusNonAdmin '
          "La session n'a pas pu être fermée : réessayez.";
}
