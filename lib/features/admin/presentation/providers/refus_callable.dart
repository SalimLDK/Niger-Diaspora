/// Ce que le panneau montre quand une Cloud Function callable refuse.
///
/// Les callables du panneau — `setAdminRole` (`functions/roles_admin.js`) et
/// `setUserBanned` (`functions/bannissement.js`) — refusent par une
/// `HttpsError` dont le message est écrit pour être lu : en français, sans
/// identifiant ni URL (« Un superAdmin ne se bannit pas : lui retirer son
/// rôle d'abord »). Pour ces codes-là, le message du serveur est montré tel
/// quel : c'est lui qui sait *pourquoi*. Tout autre code passe par
/// [messageErreurUsager], qui ne divulgue rien.
///
/// Une seule source pour les deux providers (`role_management_provider.dart`,
/// `admin_provider.dart`) : la liste des codes et la règle de repli ne
/// doivent pas diverger d'un écran à l'autre.
library;

import 'package:cloud_functions/cloud_functions.dart';

import '../../../../core/errors/message_erreur.dart';

/// Codes dont le message vient du serveur et peut être montré tel quel.
///
/// `unavailable` n'y est **pas**, bien que `bannissement.js` et
/// `roles_admin.js` le lèvent (« Base de données injoignable ») : le SDK
/// client emploie le même code pour ses propres pannes réseau, avec un
/// message en anglais (`UNAVAILABLE` sur Android). Les deux cas se traitent
/// pareil pour l'usager — réessayer plus tard — et [messageErreurUsager]
/// classe `unavailable` en panne réseau, en français.
const Set<String> codesRefusAffichables = {
  'permission-denied',
  'not-found',
  'failed-precondition',
  'invalid-argument',
  'internal',
};

/// Message à montrer pour un refus de code [code] et de message [message].
///
/// Pure, et séparée de [messageRefusCallable] parce que le constructeur de
/// [FirebaseFunctionsException] est `@protected` : un test unitaire ne peut
/// pas en fabriquer une (`test/features/admin/bannissement_callable_test.dart`).
/// [erreur] ne sert qu'à **classer** la panne quand le message n'est pas
/// montrable ; à défaut, le code seul suffit à `messageErreurUsager`
/// (`permission-denied` → droits, `unavailable` → réseau).
String messageRefusDepuisCode(String code, String? message, {Object? erreur}) {
  if (codesRefusAffichables.contains(code) &&
      message != null &&
      message.trim().isNotEmpty) {
    return message;
  }
  return messageErreurUsager(erreur ?? code);
}

/// Le message à poser dans `state.error` pour un refus [e] d'une callable.
String messageRefusCallable(FirebaseFunctionsException e) =>
    messageRefusDepuisCode(e.code, e.message, erreur: e);
