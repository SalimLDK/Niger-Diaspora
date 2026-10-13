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
///
/// Seule exception au « texte, pas le type » : `PostgrestException`, qui est
/// du Dart pur et porte un **code**. Fiche Crashlytics du 2026-10-13 : un
/// « error code: 522 » — Cloudflare n'a pas joint l'origine Supabase — était
/// compté plantage de l'app, comme l'aurait été un 503 pendant une
/// maintenance. La passerelle n'est pas l'app.
library;

import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

/// Statuts HTTP qui disent « la passerelle n'a pas pu joindre l'origine » :
/// 502/503/504 côté HTTP, 520 à 524 côté Cloudflare. Un 500, lui, vient de
/// l'origine — un déclencheur qui lève, une fonction qui plante — et reste
/// un défaut à regarder.
const Set<String> _codesDePasserelle = <String>{
  '502',
  '503',
  '504',
  '520',
  '521',
  '522',
  '523',
  '524',
};

/// Corps que Cloudflare renvoie à un client qui n'accepte pas le HTML.
final RegExp _motifErreurDePasserelle = RegExp(r'error code: 5\d\d');

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
  if (error is PostgrestException && estErreurDePasserelle(error)) return true;
  final texte = error.toString().toLowerCase();
  if (_motifErreurDePasserelle.hasMatch(texte)) return true;
  for (final motif in _motifsReseau) {
    if (texte.contains(motif)) return true;
  }
  return false;
}

/// Vrai si [e] vient de la passerelle (Cloudflare, répartiteur) et non de
/// PostgREST ou de Postgres : code dans [_codesDePasserelle], ou corps
/// « error code: 5xx ». Un `23514`, un `42501` ou un `PGRST303` sont, eux,
/// des réponses de l'origine.
bool estErreurDePasserelle(PostgrestException e) {
  final code = e.code;
  if (code != null && _codesDePasserelle.contains(code)) return true;
  return _motifErreurDePasserelle.hasMatch(e.message.toLowerCase());
}
