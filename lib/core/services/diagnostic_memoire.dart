/// Dit, dans Crashlytics, qui tournait et combien de tas Java restait.
///
/// Huit `OutOfMemoryError` en 30 jours (1.2.2), aux piles toutes différentes,
/// sur des Tecno/Infinix avec 600 Mio à 1 Gio de RAM libre : c'est le plafond
/// du TAS JAVA du processus qui cédait, pas la RAM du téléphone. Les onglets
/// Clés et Journaux de ces fiches étaient vides, donc impossible de dire qui
/// remplissait le tas (plusieurs moteurs Flutter d'arrière-plan ? l'app au
/// premier plan ?). Ce fichier ne corrige rien : il rend le prochain OOM lisible.
///
/// **Les clés Crashlytics sont par PROCESSUS, pas par isolat.** Les isolats
/// d'arrière-plan (FCM, service de localisation, réponse rapide) tournent dans
/// le même processus que l'app : la clé `isolat` vaut donc le DERNIER isolat à
/// s'être signalé, pas forcément celui qui plante. Les journaux (`log`) sont
/// ordonnés et nomment chaque isolat à son ouverture : ils complètent la clé.
///
/// Ne lève jamais : l'instrumentation ne doit pas faire planter l'app. Doit
/// être appelé APRÈS `Firebase.initializeApp` (sinon `FirebaseCrashlytics`
/// lève — avalé ici, mais alors rien n'est posé).
///
/// Aucune donnée personnelle : ni identifiant, ni texte, ni position.
library;

import 'dart:async';
import 'dart:io' show ProcessInfo;

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// L'isolat principal et les isolats d'arrière-plan, nommés comme dans Crashlytics.
enum Isolat {
  principal('principal'),
  fcmArrierePlan('fcm_arriere_plan'),
  serviceLocalisation('service_localisation'),
  reponseRapide('reponse_rapide'),
  // Pas d'isolat propre aujourd'hui : l'aperçu de notification (MLS) tourne
  // DANS l'isolat FCM. Gardé pour qu'un futur isolat dédié ait déjà son nom.
  apercuNotification('apercu_notification');

  const Isolat(this.nom);
  final String nom;
}

/// Ce que le service sait écrire : `setCustomKey` et `log` de Crashlytics.
abstract class EnregistreurDiagnostic {
  Future<void> poserCle(String cle, Object valeur);
  Future<void> journaliser(String message);
}

class _EnregistreurCrashlytics implements EnregistreurDiagnostic {
  const _EnregistreurCrashlytics();

  @override
  Future<void> poserCle(String cle, Object valeur) =>
      FirebaseCrashlytics.instance.setCustomKey(cle, valeur);

  @override
  Future<void> journaliser(String message) =>
      FirebaseCrashlytics.instance.log(message);
}

/// Lit la mémoire Java via le plugin natif ; `null` si indisponible (iOS,
/// moteur sans plugin, erreur).
typedef LecteurMemoireJava = Future<Map<String, Object?>?> Function();

Future<Map<String, Object?>?> _lireMemoireJavaNative() async {
  const canal = MethodChannel('diaspo_niger/diagnostic_memoire');
  return canal.invokeMapMethod<String, Object?>('lireMemoire');
}

class DiagnosticMemoire {
  DiagnosticMemoire._();

  @visibleForTesting
  static EnregistreurDiagnostic enregistreur = const _EnregistreurCrashlytics();

  @visibleForTesting
  static LecteurMemoireJava lecteurMemoireJava = _lireMemoireJavaNative;

  @visibleForTesting
  static int Function() lecteurRssMio = _rssMio;

  static int _rssMio() => ProcessInfo.currentRss ~/ (1024 * 1024);

  static Isolat? _isolat;
  static bool? _auPremierPlan;
  static bool? _serviceLocalisationActif;

  @visibleForTesting
  static void reinitialiser() {
    enregistreur = const _EnregistreurCrashlytics();
    lecteurMemoireJava = _lireMemoireJavaNative;
    lecteurRssMio = _rssMio;
    _isolat = null;
    _auPremierPlan = null;
    _serviceLocalisationActif = null;
  }

  /// À l'ouverture d'un isolat : pose l'identité de l'isolat et la mémoire.
  static Future<void> ouvrirIsolat(
    Isolat isolat, {
    bool? serviceLocalisationActif,
    bool? auPremierPlan,
  }) async {
    _isolat = isolat;
    if (serviceLocalisationActif != null) {
      _serviceLocalisationActif = serviceLocalisationActif;
    }
    if (auPremierPlan != null) _auPremierPlan = auPremierPlan;
    await journaliser('isolat ouvert : ${isolat.nom}');
    await poser();
  }

  /// Change l'état du service de localisation, puis repose les clés.
  static Future<void> serviceLocalisationChange(bool actif) async {
    _serviceLocalisationActif = actif;
    await poser();
  }

  /// Change l'état premier plan / arrière-plan, puis repose les clés.
  static Future<void> premierPlanChange(bool premierPlan) async {
    _auPremierPlan = premierPlan;
    await poser();
  }

  /// Repose toutes les clés connues (une lecture native, pas de boucle).
  static Future<void> poser() async {
    try {
      final cles = <String, Object>{};
      final isolat = _isolat;
      if (isolat != null) cles['isolat'] = isolat.nom;
      final actif = _serviceLocalisationActif;
      if (actif != null) cles['service_localisation_actif'] = actif;
      final premierPlan = _auPremierPlan;
      if (premierPlan != null) cles['appli_au_premier_plan'] = premierPlan;

      try {
        cles['rss_mio'] = lecteurRssMio();
      } catch (_) {
        // dart:io indisponible (web) : la clé manque, rien d'autre.
      }
      cles.addAll(await _clesMemoireJava());

      for (final e in cles.entries) {
        try {
          await enregistreur.poserCle(e.key, e.value);
        } catch (_) {
          // Firebase pas prêt, ou Crashlytics indisponible : on abandonne ce
          // coup-ci sans bruit, l'instrumentation ne doit jamais faire planter.
        }
      }
    } catch (_) {}
  }

  static Future<Map<String, Object>> _clesMemoireJava() async {
    final cles = <String, Object>{};
    try {
      final m = await lecteurMemoireJava();
      if (m == null) return cles;
      final max = _entier(m['tasMaxMio']);
      final alloue = _entier(m['tasAlloueMio']);
      final libre = _entier(m['tasLibreMio']);
      if (max != null) cles['tas_max_mio'] = max;
      if (alloue != null) cles['tas_alloue_mio'] = alloue;
      if (libre != null) cles['tas_libre_mio'] = libre;
      // Ce qui compte pour un OOM : combien le processus peut encore prendre.
      if (max != null && alloue != null && libre != null) {
        cles['tas_restant_mio'] = max - (alloue - libre);
      }
      final classe = _entier(m['classeMemoireMio']);
      if (classe != null) cles['classe_memoire_mio'] = classe;
      final grande = _entier(m['largeClasseMemoireMio']);
      if (grande != null) cles['grande_classe_memoire_mio'] = grande;
      final peuDeRam = m['appareilPeuDeRam'];
      if (peuDeRam is bool) cles['appareil_peu_de_ram'] = peuDeRam;
    } catch (_) {
      // MissingPluginException (iOS, moteur sans plugin) ou erreur native.
    }
    return cles;
  }

  static int? _entier(Object? v) => v is num ? v.toInt() : null;

  /// Journal court, sans donnée personnelle. Ne lève jamais.
  static Future<void> journaliser(String message) async {
    try {
      await enregistreur.journaliser(message);
    } catch (_) {}
  }
}

/// Repose les clés à chaque passage premier plan / arrière-plan.
///
/// Une classe dédiée (pas `with WidgetsBindingObserver` sur l'app) : elle se
/// teste sans arbre de widgets.
class ObservateurDiagnosticMemoire extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final premierPlan = state == AppLifecycleState.resumed;
    unawaited(DiagnosticMemoire.journaliser(
        'cycle de vie : ${premierPlan ? 'premier plan' : 'arrière-plan'}'));
    unawaited(DiagnosticMemoire.premierPlanChange(premierPlan));
  }
}
