/// Ce qu'on montre à l'usager quand quelque chose échoue.
///
/// Le message brut d'une exception n'est **jamais** montrable. Vu sur
/// SM A515F le 2026-09-08, réseau coupé, sur l'écran des ambassades :
///
///     Erreur: ServerFailure(ClientException with SocketException: Failed
///     host lookup: 'zyrfkcjjrhddpfxcgezo.supabase.co',
///     uri=.../rest/v1/users?select=%2A&id=eq.<UID>)
///
/// Soit l'identifiant du projet Supabase **et** celui du compte, affichés à
/// qui regarde l'écran. Ça vaut pour toutes les couches : PostgREST met
/// l'URL complète dans ses messages, Firebase y met le chemin du document.
///
/// À ne pas confondre avec `construireEcranErreurNeutre` (`main.dart`), qui
/// traite l'autre écran d'erreur : celui que **Flutter** peint quand un
/// `build` lève. Ici on traite ceux que les écrans rendent eux-mêmes, à
/// partir d'un `AsyncValue.error` ou d'un `catch` — `ErrorWidget.builder`
/// n'y peut rien, ce ne sont pas des levées.
library;

/// Message affichable pour [erreur], sans rien en divulguer.
///
/// Le texte de l'exception est lu pour **classer** la panne, jamais pour être
/// rendu. Trois familles, parce que ce sont les trois seules qui appellent
/// une conduite différente de la part de l'usager :
///
/// - réseau : il peut agir (se reconnecter) ;
/// - droits : il ne peut rien, inutile de lui faire réessayer en boucle ;
/// - le reste : réessayer est le seul conseil honnête.
String messageErreurUsager(Object? erreur) {
  final texte = erreur?.toString().toLowerCase() ?? '';

  if (_contientUn(texte, _marqueursReseau)) {
    return 'Connexion indisponible. Vérifiez votre réseau, puis réessayez.';
  }
  if (_contientUn(texte, _marqueursDroits)) {
    return "Vous n'avez pas les droits nécessaires pour cette action.";
  }
  return 'Une erreur est survenue. Réessayez.';
}

/// Variante préfixée d'un libellé de contexte, pour les cas où l'écran veut
/// dire *ce qui* a échoué : `messageErreurUsager` ne le sait pas.
///
/// `messageErreurContextuel('Envoi impossible', e)`
///   → « Envoi impossible. Connexion indisponible. Vérifiez… »
String messageErreurContextuel(String contexte, Object? erreur) =>
    '$contexte. ${messageErreurUsager(erreur)}';

bool _contientUn(String texte, List<String> marqueurs) =>
    marqueurs.any(texte.contains);

/// Marqueurs relevés dans les pannes réellement observées sur ce projet :
/// `SocketException` et `ClientException` (http/postgrest), le
/// `Failed host lookup` d'Android hors ligne, les délais dépassés, et le
/// `UnknownHostException` que remonte le SDK Firebase.
const _marqueursReseau = <String>[
  'socketexception',
  'clientexception',
  'failed host lookup',
  'no address associated',
  'unknownhostexception',
  'timeoutexception',
  'connection closed',
  'connection refused',
  'network is unreachable',
  'networkexception',
  'unavailable',
];

/// Refus d'autorisation : le 42501 de PostgreSQL (RLS ou GRANT), les codes
/// PostgREST, et les formulations Firebase.
const _marqueursDroits = <String>[
  '42501',
  'insufficient_privilege',
  'permission denied',
  'permission-denied',
  'not authorized',
  'unauthorized',
  'row-level security',
  'violates row-level',
];
