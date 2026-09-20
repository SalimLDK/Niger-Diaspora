import 'dart:developer' as dev;
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../crypto/mls/mls_chemin_base.dart';
import 'crypto/derived_key_store.dart';
import 'e2ee/secure_key_storage.dart';

/// Ce qui a été retiré, pour le journal et pour les tests.
class ResumeEffacement {
  const ResumeEffacement({required this.fichiers, required this.preferences});

  /// Fichiers de la base MLS supprimés (`.sqlite`, `-wal`, `-shm`, `-journal`).
  final int fichiers;

  /// Clés SharedPreferences retirées (vérifications, curseurs de lecture).
  final int preferences;
}

/// Détruit ce que ce téléphone garde d'UN compte : la base MLS, les clés Signal,
/// les clés dérivées, les vérifications et les curseurs.
///
/// **Pourquoi ce service existe.** Aucune déconnexion ni suppression n'efface la
/// base MLS locale — un fichier par compte, **en clair** (voir
/// `mls_engine_provider.dart`). Après la suppression définitive d'un compte, son
/// historique lisible et ses secrets de groupe restaient sur le téléphone jusqu'à
/// la désinstallation.
///
/// **Ce n'est jamais appelé directement.** Seul [EffacementLocalDiffere] le
/// déclenche, et seulement quand le serveur a confirmé que la suppression est
/// MENÉE À TERME : effacer ces clés d'un compte qu'on aurait annulé ailleurs
/// serait une perte définitive.
///
/// **Un échec est une levée.** Chaque étape est tentée, puis, si l'une a échoué,
/// l'ensemble lève : le marqueur reste, et l'effacement est retenté au démarrage
/// suivant. Ne rien signaler laisserait des clés sur un téléphone en croyant les
/// avoir détruites.
class MaterielLocal {
  MaterielLocal({
    Future<Directory> Function()? dossierMls,
    Future<SharedPreferences> Function()? preferences,
    Future<void> Function(String uid)? effacerSignal,
    Future<void> Function()? viderClesDerivees,
  })  : _dossierMls = dossierMls ?? dossierBaseMls,
        _preferences = preferences ?? SharedPreferences.getInstance,
        _effacerSignal = effacerSignal ?? _effacerSignalParDefaut,
        _viderClesDerivees = viderClesDerivees ?? _viderClesDeriveesParDefaut;

  final Future<Directory> Function() _dossierMls;
  final Future<SharedPreferences> Function() _preferences;
  final Future<void> Function(String uid) _effacerSignal;
  final Future<void> Function() _viderClesDerivees;

  /// Les fichiers qu'un moteur SQLite laisse à côté de la base.
  static const _suffixes = ['', '-wal', '-shm', '-journal'];

  /// Préfixes des clés SharedPreferences qui portent l'uid — `mls_code_securite`
  /// (« vérifié ») et `mls_conversation_service` (curseur de lecture).
  static List<String> prefixesDe(String uid) =>
      ['mls_verif_${uid}_', 'mls_curseur_${uid}_'];

  Future<ResumeEffacement> effacer(String uid) async {
    if (uid.isEmpty) {
      // Un préfixe vide effacerait les clés de TOUS les comptes.
      throw ArgumentError('uid vide : refusé');
    }

    final echecs = <String>[];
    var fichiers = 0;
    var prefs = 0;

    // 1. La base MLS de CE compte, et seulement la sienne.
    try {
      final dossier = await _dossierMls();
      for (final suffixe in _suffixes) {
        final f = File('${dossier.path}/${nomFichierBaseMls(uid)}$suffixe');
        if (await f.exists()) {
          await f.delete();
          fichiers++;
        }
      }
    } catch (e) {
      echecs.add('base MLS ($e)');
    }

    // 2. Vérifications de sécurité et curseurs de lecture MLS.
    try {
      final p = await _preferences();
      for (final cle in p.getKeys().toList()) {
        if (prefixesDe(uid).any(cle.startsWith)) {
          await p.remove(cle);
          prefs++;
        }
      }
    } catch (e) {
      echecs.add('préférences ($e)');
    }

    // 3. Clés Signal du repli historique.
    try {
      await _effacerSignal(uid);
    } catch (e) {
      echecs.add('clés Signal ($e)');
    }

    // 4. Clés dérivées du repli AES : rappelées du serveur à la demande, donc
    //    sans danger pour un autre compte du même téléphone.
    try {
      await _viderClesDerivees();
    } catch (e) {
      echecs.add('clés dérivées ($e)');
    }

    if (echecs.isNotEmpty) {
      dev.log('MaterielLocal: effacement incomplet: ${echecs.join(', ')}');
      throw StateError('effacement incomplet : ${echecs.join(', ')}');
    }
    return ResumeEffacement(fichiers: fichiers, preferences: prefs);
  }

  static Future<void> _effacerSignalParDefaut(String uid) async {
    final stockage = SecureKeyStorage.instance;
    await stockage.initialize();
    await stockage.clearAllData(uid);
  }

  static Future<void> _viderClesDeriveesParDefaut() =>
      DerivedKeyStore.instance.vider();
}
