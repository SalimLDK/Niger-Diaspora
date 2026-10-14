/// Rien de la couche données ne traverse un dépôt.
///
/// Fiche Crashlytics `PostgrestBuilder._parseResponse` lue le 2026-10-13 :
/// sur 90 jours, **36 événements, 9 usagers, 7 variantes**, tous comptés
/// FATALS — et aucun n'était un plantage de l'application. Dix-sept dépôts
/// n'attrapaient que `ServerException` ; une `PostgrestException` levée par
/// le client Supabase traversait dépôt, notifier et écran jusqu'à
/// `PlatformDispatcher.onError`. Trois formes vues en production :
///
/// - une contrainte `23514` à la création d'un commerce (11 événements le
///   11/10) ;
/// - « JWT expired » `PGRST303` : 5 événements d'un seul usager les 5 et
///   6/10, depuis trois écrans différents ;
/// - « error code: 522 » : une passerelle Cloudflare qui n'a pas joint
///   l'origine, sur la lecture des profils proches.
///
/// L'usager ne voyait rien — l'écran gardait son état, le bouton restait
/// muet — et la console comptait un plantage.
///
/// [garderAppel] est la seule frontière : un dépôt lui confie le corps de
/// chaque méthode, et toute exception connue de la couche données en ressort
/// en [Failure], message lisible et code conservé ([ServerFailure.code]).
///
/// Ce qu'il ne fait PAS : avaler l'inconnu. Une `TypeError` ou une
/// `FormatException` est un défaut de code ; sans [sinon], elle continue de
/// remonter avec sa pile, là où elle sera vue. Les dépôts qui avaient déjà
/// un filet générique le gardent, via [sinon].
///
/// Vérifié par `test/core/errors/depots_sous_garde_test.dart` : toute
/// méthode `Future<Either<…>>` d'un dépôt qui appelle une datasource le fait
/// sous cette garde.
library;

import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase
    show AuthException, FunctionException, PostgrestException, StorageException;

import '../services/supabase_auth_bridge.dart';
import 'classification_erreurs.dart';
import 'exceptions.dart';
import 'failures.dart';

/// Re-mint la session Supabase et dit si elle est à nouveau valide.
typedef Resynchronisation = Future<bool> Function();

/// Ce qu'on appelle sur « JWT expired ». Remplaçable dans les tests, qui
/// n'ont ni Firebase ni Supabase.
@visibleForTesting
Resynchronisation resynchroniserSession = _resynchroniserParLePont;

Future<bool> _resynchroniserParLePont() =>
    SupabaseAuthBridge.instance.resynchroniserApresJwtExpire();

/// Exécute [corps] et convertit en [Failure] toute exception de la couche
/// données qu'il laisse échapper.
///
/// Les familles converties sont celles de [failurePourException] : les
/// exceptions du projet (`ServerException` et ses sœurs) et celles du client
/// Supabase (`PostgrestException`, `AuthException`, `StorageException`,
/// `FunctionException`). Tout le reste passe par [sinon] s'il est fourni,
/// sinon remonte intact.
///
/// **« JWT expired » (`PGRST303`).** Le serveur dit que la session est
/// morte : on la re-mint tout de suite via [resynchroniserSession] — quoi
/// qu'en pense l'horloge locale — puis, si une session neuve est en place et
/// que [rejouerSiJwtExpire] le permet, on rejoue [corps] **une fois**. Au
/// second échec, le `Failure` sort normalement.
///
/// Le rejeu reprend le corps **en entier**. C'est sûr pour la forme usuelle
/// d'une méthode de dépôt — vérifier le réseau, appeler la datasource,
/// convertir — parce qu'un jeton expiré fait échouer le *premier* appel
/// Supabase : rien d'autre n'a encore eu lieu. Un corps qui fait avancer un
/// état local avant d'appeler le serveur (ratchet de chiffrement, cache
/// écrit par anticipation) passe `rejouerSiJwtExpire: false` : la session
/// est re-mintée quand même, pour l'appel suivant, mais rien n'est rejoué.
Future<Either<Failure, T>> garderAppel<T>(
  Future<Either<Failure, T>> Function() corps, {
  Failure Function(Object erreur)? sinon,
  bool rejouerSiJwtExpire = true,
}) async {
  var dejaResynchronise = false;
  while (true) {
    try {
      return await corps();
    } catch (e) {
      if (!dejaResynchronise && estJwtExpire(e)) {
        dejaResynchronise = true;
        final sessionNeuve = await _resynchroniser();
        if (sessionNeuve && rejouerSiJwtExpire) continue;
      }
      final echec = failurePourException(e) ?? sinon?.call(e);
      if (echec == null) rethrow;
      return Left(echec);
    }
  }
}

Future<bool> _resynchroniser() async {
  try {
    return await resynchroniserSession();
  } catch (e) {
    // Le pont lève tant que Supabase n'est pas initialisé (tests, démarrage) :
    // l'erreur d'origine reste celle qu'on rapporte, pas celle-ci.
    debugPrint('garderAppel: re-synchronisation impossible ($e)');
    return false;
  }
}

/// « JWT expired » tel que PostgREST le dit : code `PGRST303`.
///
/// Le texte est regardé aussi, parce que plusieurs datasources ré-emballent
/// l'exception en `ServerException(e.message)` et perdent le code en route.
bool estJwtExpire(Object erreur) {
  if (erreur is supabase.PostgrestException) {
    return erreur.code == 'PGRST303' || _ditJwtExpire(erreur.message);
  }
  if (erreur is ServerException) return _ditJwtExpire(erreur.message);
  return false;
}

bool _ditJwtExpire(String message) =>
    message.toLowerCase().contains('jwt expired');

/// Le [Failure] canonique d'une exception de la couche données, ou `null`
/// si elle n'en est pas une.
///
/// Les familles du projet gardent leur message tel quel : les notifiers le
/// lisent déjà (`failure.message`). `NotFoundException` est la seule à
/// mériter son propre `Failure` : une publication supprimée ou un identifiant
/// inexistant doit pouvoir s'afficher « introuvable », pas comme une panne
/// qu'on réessaierait sans fin.
///
/// Les exceptions Supabase deviennent des [ServerFailure] ou [AuthFailure]
/// dont le [ServerFailure.code] porte ce que le serveur a dit — SQLSTATE
/// `42501`, `PGRST116`, `PGRST303` — pour que l'appelant puisse décider sans
/// relire le texte.
///
/// Sauf la passerelle. Un statut 502/503/504 ou 520–524 ([estErreurDePasserelle])
/// n'est pas une réponse de PostgREST : Cloudflare ou le répartiteur n'a pas
/// joint l'origine. Il sort en [NetworkFailure], comme une coupure de réseau —
/// l'usager n'y peut rien d'autre que réessayer, et aucun écran ne doit le
/// traiter en défaut du serveur. Le `500`, lui, vient bien de l'origine.
///
/// Le texte du serveur reste dans `Failure.message`, borné, pour **classer**
/// la panne et la journaliser : `messageErreurUsager` y lit `42501`,
/// `permission denied`, « error code: 5xx ». Il n'est pas fait pour l'écran,
/// qui passe par `messageErreurUsager` et ne le rend jamais — PostgREST
/// recopie parfois la requête, hôte du projet et identifiant du compte
/// compris (`test/core/errors/message_erreur_test.dart`).
Failure? failurePourException(Object erreur) {
  return switch (erreur) {
    // Avant ServerException, dont elle hérite.
    E2EEException(:final message) => E2EEFailure(message),
    ServerException(:final message) => ServerFailure(message),
    NotFoundException(:final message) => NotFoundFailure(message),
    CacheException(:final message) => CacheFailure(message),
    NetworkException(:final message) => NetworkFailure(message),
    ValidationException(:final message) => ValidationFailure(message),
    AuthException(:final message, :final code) =>
      AuthFailure(message, code: code),
    // Avant le cas général : la passerelle n'est pas le serveur.
    supabase.PostgrestException() when estErreurDePasserelle(erreur) =>
      NetworkFailure(_messagePostgrest(erreur)),
    supabase.PostgrestException() => ServerFailure(
        _messagePostgrest(erreur),
        code: erreur.code,
      ),
    supabase.AuthException(:final message, :final code, :final statusCode) =>
      AuthFailure(message, code: code ?? statusCode),
    supabase.StorageException(:final message, :final statusCode) =>
      ServerFailure(message, code: statusCode),
    supabase.FunctionException(:final status, :final reasonPhrase) =>
      ServerFailure(
        (reasonPhrase == null || reasonPhrase.isEmpty)
            ? 'Fonction en erreur ($status)'
            : reasonPhrase,
        code: '$status',
      ),
    _ => null,
  };
}

/// Longueur au-delà de laquelle un message PostgREST n'apporte plus rien :
/// une passerelle peut renvoyer une page HTML entière en guise de message.
const int _longueurMaxMessage = 300;

/// Le message de PostgREST, borné, sur une ligne, suivi du code quand il n'y
/// figure pas déjà — « error code: 522 » le porte, « permission denied for
/// table users » non.
String _messagePostgrest(supabase.PostgrestException e) {
  final texte = e.message.replaceAll(RegExp(r'\s+'), ' ').trim();
  final borne = texte.length > _longueurMaxMessage
      ? '${texte.substring(0, _longueurMaxMessage)}…'
      : texte;
  final code = e.code;
  if (code == null || code.isEmpty) {
    return borne.isEmpty ? 'Erreur PostgREST' : borne;
  }
  if (borne.isEmpty) return 'Erreur PostgREST $code';
  return borne.contains(code) ? borne : '$borne (code $code)';
}
