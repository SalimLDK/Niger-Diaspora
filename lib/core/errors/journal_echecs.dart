/// Les échecs **attrapés** n'atteignaient Crashlytics par aucun chemin.
///
/// `FlutterError.onError` et `PlatformDispatcher.onError` ne voient que les
/// erreurs **non** rattrapées. Or un refus de permission Firestore, un `42501`
/// de la RLS ou un `NOT_FOUND` sont attrapés : ils deviennent un
/// `ServerException`, puis un `ServerFailure`, puis un `bool false`. Ils ne
/// quittaient jamais le téléphone.
///
/// Ce que ça a coûté : accepter une demande d'ami était impossible **pendant
/// des mois**, sur un `PERMISSION_DENIED` que seul logcat voyait — donc
/// seulement si quelqu'un regardait, au moment précis du tap. Le défaut a été
/// trouvé deux fois à la main, jamais par un rapport.
///
/// Ce fichier branche la seule chose qui aurait pu le dire sans appareil :
/// chaque fois qu'un écran s'apprête à annoncer un échec à l'usager, un
/// non-fatal part dans Crashlytics.
///
/// **Ce qu'il ne verra pas**, et c'est important de ne pas s'y fier : un échec
/// jamais affiché, et surtout un **succès qui n'a rien fait** — un `UPDATE`
/// PostgREST qui ne matche aucune ligne rend 200, une lecture refusée par la
/// RLS réussit à vide. Ceux-là se trouvent par la forme de la donnée
/// (`tools/invariants_donnees.py`).
library;

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import 'message_erreur.dart';

/// Fenêtre pendant laquelle une même panne n'est signalée qu'une fois.
///
/// `messageErreurUsager` est aussi appelé depuis des `build` : la branche
/// `error` d'un `AsyncValue` le rappelle à **chaque** reconstruction. Sans
/// cette fenêtre, un écran en erreur hors ligne inonderait la console et
/// ferait passer le vrai signal pour du bruit.
const Duration fenetreDeDoublon = Duration(minutes: 5);

/// Dernière fois qu'une signature a été envoyée.
final Map<String, DateTime> _dejaVu = <String, DateTime>{};

/// Branche la remontée. Appelé une fois, depuis `main.dart`.
void installerJournalEchecs() {
  brancherObservateurEchec(_signaler);
}

@visibleForTesting
void reinitialiserJournalEchecs() => _dejaVu.clear();

/// Signale un échec qu'on a **délibérément avalé** — jamais montré, donc
/// invisible même pour l'observateur branché sur `messageErreurUsager`.
///
/// Certains `catch` sont justifiés : rater la notification qui prévient
/// quelqu'un qu'on a accepté sa demande d'ami ne doit pas faire échouer
/// l'acceptation elle-même. Mais « ne pas faire échouer » n'est pas
/// « ne rien dire » : jusqu'ici ces échecs ne laissaient qu'un `debugPrint`,
/// que personne ne lit en production.
///
/// [contexte] nomme l'endroit, en clair et sans donnée personnelle — il sert
/// à regrouper dans la console : « notification entre utilisateurs ».
void signalerEchecSilencieux(Object? erreur, {required String contexte}) {
  final texte = caviarder(erreur?.toString() ?? 'null');
  final type = erreur?.runtimeType.toString() ?? 'null';
  if (!aSignaler('silencieux|$contexte|$type|$texte', DateTime.now())) return;

  try {
    FirebaseCrashlytics.instance.recordError(
      'echec avale ($contexte) : $type : $texte',
      StackTrace.current,
      fatal: false,
      reason: 'echec_silencieux',
    );
  } catch (_) {
    // Crashlytics indisponible : on ne casse surtout pas l'appelant, dont tout
    // l'intérêt était de continuer malgré cet échec.
  }
}

void _signaler(Object? erreur, FamilleEchec famille) {
  final texte = caviarder(erreur?.toString() ?? 'null');
  final type = erreur?.runtimeType.toString() ?? 'null';
  final signature = '${famille.name}|$type|$texte';

  if (!aSignaler(signature, DateTime.now())) return;

  try {
    final crashlytics = FirebaseCrashlytics.instance;
    crashlytics.setCustomKey('famille_echec', famille.name);
    crashlytics.recordError(
      // Le message **caviardé**, jamais l'exception d'origine : PostgREST met
      // l'URL complète dans ses messages et Firebase y met le chemin du
      // document — donc l'uid du compte. La console Crashlytics est privée,
      // mais la règle du projet est de ne jamais journaliser de donnée
      // personnelle, et un uid en est une.
      'echec affiche (${famille.name}) : $type : $texte',
      StackTrace.current,
      fatal: false,
      // Les échecs affichés ne sont pas des plantages : ils regroupés à part
      // des exceptions non rattrapées.
      reason: 'echec_affiche',
    );
  } catch (_) {
    // Crashlytics non initialisé (tests, web, démarrage) : on n'a rien à dire
    // de plus, et surtout rien à casser.
  }
}

/// Vrai si cette [signature] n'a pas déjà été signalée dans la fenêtre.
///
/// Exposé pour le test : c'est la seule logique de ce fichier qui mérite d'être
/// figée, et elle ne demande pas Firebase.
@visibleForTesting
bool aSignaler(String signature, DateTime maintenant) {
  final vue = _dejaVu[signature];
  if (vue != null && maintenant.difference(vue) < fenetreDeDoublon) {
    return false;
  }
  _dejaVu[signature] = maintenant;
  // Le dictionnaire ne doit pas grandir indéfiniment sur une session longue.
  if (_dejaVu.length > 200) {
    final limite = maintenant.subtract(fenetreDeDoublon);
    _dejaVu.removeWhere((_, quand) => quand.isBefore(limite));
  }
  return true;
}

/// Remplace ce qui identifie une personne ou un projet par un marqueur.
///
/// Le texte garde sa **forme** — c'est elle qui sert au diagnostic : « refus
/// sur `users/<ID>` » dit tout ce qu'il faut sans dire de qui.
@visibleForTesting
String caviarder(String texte) {
  var sortie = texte;
  for (final regle in _reglesDeCaviardage) {
    sortie = sortie.replaceAll(regle.motif, regle.remplacement);
  }
  return sortie.length <= 400 ? sortie : '${sortie.substring(0, 400)}…';
}

class _Regle {
  const _Regle(this.motif, this.remplacement);
  final RegExp motif;
  final String remplacement;
}

final List<_Regle> _reglesDeCaviardage = <_Regle>[
  // Adresses e-mail.
  _Regle(
    RegExp(r'[\w.+-]+@[\w-]+\.[\w.-]+'),
    '<EMAIL>',
  ),
  // Jeton JWT (trois segments base64url) — avant la règle des identifiants,
  // qui le découperait en morceaux.
  _Regle(
    RegExp(r'\beyJ[\w-]+\.[\w-]+\.[\w-]+'),
    '<JWT>',
  ),
  // Sous-domaine du projet Supabase.
  _Regle(
    RegExp(r'\b[a-z]{20}\.supabase\.co\b'),
    '<PROJET>.supabase.co',
  ),
  // uid Firebase (28 caractères) et uuid Postgres.
  _Regle(
    RegExp(
      r'\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b',
      caseSensitive: false,
    ),
    '<ID>',
  ),
  _Regle(
    RegExp(r'\b[A-Za-z0-9]{20,}\b'),
    '<ID>',
  ),
];
