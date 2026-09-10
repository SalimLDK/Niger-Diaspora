/// Une panne d'environnement n'est pas un plantage de l'application.
///
/// `PlatformDispatcher.onError` enregistrait **tout** en `fatal: true`.
/// Constaté dans la console Crashlytics le 2026-09-10 : sur les quatre
/// « plantages » ouverts, **trois** étaient de simples pertes de réseau —
/// `Failed host lookup` sur `fonts.gstatic.com` (4 événements, 3 utilisateurs)
/// et sur `zyrfkcjjrhddpfxcgezo.supabase.co` (2 événements). Le taux
/// « utilisateurs sans plantage » affichait 80,95 %, en baisse de 19 points :
/// il mesurait la couverture réseau des utilisateurs, pas la stabilité de
/// l'app. Un vrai plantage y devenait indiscernable du bruit.
///
/// Ces erreurs restent envoyées — on veut les voir, et leur volume — mais en
/// **non-fatal**, comme les erreurs de rendu que `recordFlutterError` classe
/// déjà ainsi.
///
/// ⚠️ **Le test porte sur le texte, pas sur le type.** `dart:io` — donc
/// `SocketException` — n'est pas importable ici : `web/` est une cible réelle
/// du projet, et l'import casserait la compilation web. Reconnaître par
/// libellé est fragile par nature ; c'est pourquoi
/// `test/core/errors/classification_erreurs_test.dart` fige les messages
/// **réellement observés en production**, et non des exemples inventés.
library;

/// Motifs de panne réseau, tels qu'ils apparaissent dans `error.toString()`.
///
/// Volontairement en minuscules : la comparaison est insensible à la casse.
const List<String> _motifsReseau = <String>[
  'socketexception',
  'failed host lookup',
  'clientexception',
  'timeoutexception',
  'connection closed',
  'connection reset',
  'connection refused',
  'network is unreachable',
  'software caused connection abort',
  'handshakeexception',
];

/// Vrai si [error] traduit une panne de réseau plutôt qu'un défaut de l'app.
///
/// Sert à décider du drapeau `fatal` envoyé à Crashlytics — jamais à masquer
/// l'erreur, qui part dans tous les cas.
bool estPanneReseau(Object? error) {
  if (error == null) return false;
  final texte = error.toString().toLowerCase();
  for (final motif in _motifsReseau) {
    if (texte.contains(motif)) return true;
  }
  return false;
}
