import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'effacement_materiel_local.dart';

/// Un compte dont la suppression a été demandée sur CE téléphone.
class MarqueurEffacement {
  const MarqueurEffacement({required this.uid, required this.echeance});

  final String uid;

  /// Date de suppression définitive annoncée par le serveur.
  final DateTime echeance;

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'echeance': echeance.toUtc().toIso8601String(),
      };

  /// `null` pour tout ce qui n'est pas exactement un marqueur : un marqueur
  /// illisible ne doit jamais faire effacer quoi que ce soit.
  static MarqueurEffacement? tenter(Object? brut) {
    if (brut is! Map) return null;
    final uid = brut['uid'];
    final echeance = DateTime.tryParse('${brut['echeance']}');
    if (uid is! String || uid.isEmpty || echeance == null) return null;
    return MarqueurEffacement(uid: uid, echeance: echeance.toUtc());
  }
}

/// Ce qu'un passage a fait, pour le journal et pour les tests.
class ResultatEffacementDiffere {
  const ResultatEffacementDiffere({
    required this.effaces,
    required this.enAttente,
  });

  /// Uid dont le matériel local a été détruit.
  final List<String> effaces;

  /// Marqueurs conservés (pas encore échus, serveur silencieux, ou pas confirmé).
  final int enAttente;
}

/// Efface le matériel cryptographique local d'un compte SUPPRIMÉ — à retardement,
/// et seulement sur confirmation du serveur.
///
/// **Le problème.** Ni la déconnexion ni la suppression d'un compte n'effacent la
/// base MLS locale (en clair) ni les clés du téléphone. Pendant le délai de grâce,
/// les garder est voulu : une annulation les perdrait. Après la suppression
/// définitive, plus rien ne les détruisait — et le téléphone, déconnecté, n'est
/// pas joignable.
///
/// **Le mécanisme.**
/// 1. La demande de suppression pose ici un marqueur (uid + échéance) —
///    [programmer].
/// 2. Aux démarrages suivants, une fois l'échéance + [delaiApresEcheance]
///    passée, [executerSiEchu] demande au serveur, sans compte, si la suppression
///    est MENÉE À TERME (`account_deletion_completed`, un booléen).
/// 3. Seulement si oui, [MaterielLocal.effacer] détruit la base MLS et les clés.
///
/// **La confirmation serveur est le garde-fou.** Sur un autre appareil, la
/// personne a pu annuler : son compte est vivant, et ses clés locales ici lui
/// servent encore. Sans confirmation, ce téléphone les détruirait.
///
/// **Quatre choses que ce service ne fait jamais.**
/// - Effacer sur une réponse « non » ou sur une erreur réseau : le marqueur reste
///   et le prochain démarrage réessaie.
/// - Effacer le compte actuellement connecté ([uidCourant]), quoi que réponde le
///   serveur.
/// - Effacer sur un marqueur qu'il ne sait pas lire.
/// - Lever : c'est un travail de fond, jamais un motif de planter au démarrage.
class EffacementLocalDiffere {
  EffacementLocalDiffere({
    required this.lire,
    required this.ecrire,
    required this.suppressionMenee,
    required this.effacerMateriel,
    this.uidCourant,
    DateTime Function()? maintenant,
  }) : _maintenant = maintenant ?? DateTime.now;

  /// Le seul chemin de production.
  factory EffacementLocalDiffere.parDefaut() {
    final materiel = MaterielLocal();
    return EffacementLocalDiffere(
      lire: () async =>
          (await SharedPreferences.getInstance()).getString(cle),
      ecrire: (valeur) async =>
          (await SharedPreferences.getInstance()).setString(cle, valeur),
      // `anon` a le droit d'exécuter cette fonction : le téléphone n'a plus de
      // session. La réponse est un booléen, jamais l'état intermédiaire.
      suppressionMenee: (uid) async {
        final reponse = await Supabase.instance.client
            .rpc('account_deletion_completed', params: {'p_uid': uid})
            .timeout(const Duration(seconds: 8));
        return reponse == true;
      },
      effacerMateriel: (uid) async {
        await materiel.effacer(uid);
      },
      uidCourant: () => FirebaseAuth.instance.currentUser?.uid,
    );
  }

  /// Clé SharedPreferences. `PreferencesService.clearUserData` ne retire qu'une
  /// liste blanche de clés : celle-ci survit à la déconnexion, c'est le but.
  static const String cle = 'effacement_local_differe_v1';

  /// Marge après l'échéance : la fonction planifiée tourne toutes les heures, et
  /// une purge en échec est reprise après 30 minutes, dix fois.
  static const Duration delaiApresEcheance = Duration(days: 1);

  /// Au-delà, on cesse d'interroger : un an après l'échéance, la suppression
  /// n'aboutira pas.
  static const Duration abandonApresEcheance = Duration(days: 365);

  /// Plafond de marqueurs conservés (le plus ancien est écarté) : un téléphone
  /// partagé n'en portera jamais autant.
  static const int maxMarqueurs = 10;

  final Future<String?> Function() lire;
  final Future<void> Function(String valeur) ecrire;
  final Future<bool> Function(String uid) suppressionMenee;
  final Future<void> Function(String uid) effacerMateriel;
  final String? Function()? uidCourant;
  final DateTime Function() _maintenant;

  Future<ResultatEffacementDiffere>? _enCours;

  /// Note qu'un compte est en délai de grâce sur ce téléphone. À appeler AVANT la
  /// déconnexion : après, on ne sait plus qui était connecté.
  Future<void> programmer(String uid, DateTime echeance) async {
    try {
      final marqueurs = (await _charger()).where((m) => m.uid != uid).toList()
        ..add(MarqueurEffacement(uid: uid, echeance: echeance.toUtc()));
      marqueurs.sort((a, b) => a.echeance.compareTo(b.echeance));
      while (marqueurs.length > maxMarqueurs) {
        marqueurs.removeAt(0);
      }
      await _enregistrer(marqueurs);
    } catch (e) {
      // Ne jamais faire échouer une demande de suppression pour ça.
      dev.log('EffacementLocalDiffere: marqueur non posé ($e)');
    }
  }

  /// La suppression est annulée (ici ou ailleurs) : on n'effacera rien.
  Future<void> annuler(String uid) async {
    try {
      final marqueurs = await _charger();
      final restants = marqueurs.where((m) => m.uid != uid).toList();
      if (restants.length != marqueurs.length) await _enregistrer(restants);
    } catch (e) {
      dev.log('EffacementLocalDiffere: marqueur non retiré ($e)');
    }
  }

  /// Un passage : interroge le serveur pour chaque marqueur échu, et efface ce
  /// qu'il confirme. Deux appels simultanés partagent le même passage.
  Future<ResultatEffacementDiffere> executerSiEchu() =>
      _enCours ??= _passage().whenComplete(() => _enCours = null);

  Future<ResultatEffacementDiffere> _passage() async {
    final effaces = <String>[];
    final restants = <MarqueurEffacement>[];
    try {
      final marqueurs = await _charger();
      final maintenant = _maintenant().toUtc();
      for (final m in marqueurs) {
        final echu = maintenant.isAfter(m.echeance.add(delaiApresEcheance));
        if (!echu) {
          restants.add(m);
          continue;
        }
        if (maintenant.isAfter(m.echeance.add(abandonApresEcheance))) {
          continue; // abandon : on cesse d'interroger
        }
        // Jamais le compte connecté, quoi que dise le serveur.
        if (uidCourant?.call() == m.uid) {
          restants.add(m);
          continue;
        }

        final bool menee;
        try {
          menee = await suppressionMenee(m.uid);
        } catch (e) {
          dev.log('EffacementLocalDiffere: serveur injoignable ($e)');
          restants.add(m);
          continue;
        }
        if (!menee) {
          restants.add(m);
          continue;
        }

        try {
          await effacerMateriel(m.uid);
          effaces.add(m.uid);
        } catch (e) {
          // Effacement incomplet : on garde le marqueur, on retentera.
          dev.log('EffacementLocalDiffere: effacement échoué ($e)');
          restants.add(m);
        }
      }
      if (restants.length != marqueurs.length) await _enregistrer(restants);
    } catch (e) {
      dev.log('EffacementLocalDiffere: passage interrompu ($e)');
    }
    return ResultatEffacementDiffere(effaces: effaces, enAttente: restants.length);
  }

  Future<List<MarqueurEffacement>> _charger() async {
    final brut = await lire();
    if (brut == null || brut.isEmpty) return [];
    try {
      final liste = jsonDecode(brut);
      if (liste is! List) return [];
      return [
        for (final e in liste)
          if (MarqueurEffacement.tenter(e) case final m?) m,
      ];
    } catch (_) {
      // Du JSON corrompu vaut « aucun marqueur » — jamais une raison d'effacer.
      return [];
    }
  }

  Future<void> _enregistrer(List<MarqueurEffacement> marqueurs) =>
      ecrire(jsonEncode([for (final m in marqueurs) m.toJson()]));
}

/// Le service de production. Surchargeable dans un test.
final effacementLocalDiffereProvider = Provider<EffacementLocalDiffere>(
  (ref) => EffacementLocalDiffere.parDefaut(),
);
