import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Magasin des clés dérivées du repli AES.
///
/// Le client ne dérive rien : il reçoit de l'Edge Function `crypto-keys` des
/// clés déjà dérivées, de portée réduite (une par conversation, une par
/// utilisateur). La racine ne quitte jamais le serveur, et le schéma HKDF n'est
/// donc implémenté qu'à deux endroits — l'Edge Function et `decrypt_aes_fallback`
/// côté Postgres — au lieu de trois. Un endroit de moins où diverger.
///
/// Ce que ce magasin garantit, et qui n'est pas évident :
///
/// - **Il ne renvoie jamais une clé par défaut.** Pas de clé = `null`, et
///   l'appelant doit refuser d'écrire. Une clé de repli « au cas où » ferait
///   exactement ce qu'on cherche à supprimer : deux clés en circulation et du
///   contenu illisible plus tard, sans que rien ne le signale.
/// - **Il persiste dans le keystore matériel**, pas en mémoire seule : sans ça
///   chaque démarrage rappellerait le réseau, et l'app deviendrait inutilisable
///   hors ligne pour envoyer un message.
/// - **« Une fois à l'installation » ne suffit pas.** Réinstallation, nouveau
///   téléphone, effacement des données, nouvelle conversation : autant de cas
///   où le cache est vide et où il faut rappeler l'endpoint. C'est pourquoi la
///   récupération est paresseuse et répétable, pas un rite d'inscription.
final derivedKeyStoreProvider = Provider<DerivedKeyStore>((ref) {
  return DerivedKeyStore.instance;
});

class DerivedKeyStore {
  static final DerivedKeyStore instance = DerivedKeyStore._();
  DerivedKeyStore._()
      : _supabaseInjecte = null,
        _stockageInjecte = null;

  @visibleForTesting
  DerivedKeyStore.pourTests({
    required SupabaseClient supabase,
    FlutterSecureStorage? stockage,
  })  : _supabaseInjecte = supabase,
        _stockageInjecte = stockage;

  static const String _nomFonction = 'crypto-keys';
  static const String _prefixe = 'aes_derivee_';
  static const String _cleVersion = '${_prefixe}version';

  final SupabaseClient? _supabaseInjecte;
  final FlutterSecureStorage? _stockageInjecte;

  static const FlutterSecureStorage _stockageParDefaut = FlutterSecureStorage(
    aOptions: AndroidOptions(
      keyCipherAlgorithm:
          KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  FlutterSecureStorage get _stockage => _stockageInjecte ?? _stockageParDefaut;
  SupabaseClient get _supabase => _supabaseInjecte ?? Supabase.instance.client;

  /// Cache mémoire, pour ne pas retraverser le keystore à chaque message.
  final Map<String, String> _memoire = <String, String>{};

  int? _versionCourante;

  /// Version de racine à utiliser POUR CHIFFRER, telle que le serveur la
  /// déclare. `null` tant qu'aucune récupération n'a abouti — l'appelant ne
  /// doit alors pas chiffrer avec le nouveau schéma.
  int? get versionCourante => _versionCourante;

  /// Clé (base64) d'une conversation, ou `null` si elle n'a pas pu être
  /// obtenue. Le `null` est un refus, pas un incident à contourner.
  Future<String?> cleConversation(String conversationId, {int? version}) {
    return _cle('conv:$conversationId', version: version);
  }

  /// Clé (base64) des données personnelles de l'utilisateur connecté.
  Future<String?> cleUtilisateur({int? version}) {
    return _cle('user', version: version);
  }

  Future<String?> _cle(String portee, {int? version}) async {
    final v = version ?? _versionCourante;

    // Sans version connue, on ne peut pas nommer l'entrée de cache : il faut
    // d'abord demander au serveur, qui répond aussi quelle version est courante.
    if (v == null) {
      final obtenues = await rafraichir(
        conversationIds: portee.startsWith('conv:')
            ? [portee.substring(5)]
            : const <String>[],
      );
      if (!obtenues) return null;
      return _memoire[_entree(portee, _versionCourante!)];
    }

    final entree = _entree(portee, v);

    final enMemoire = _memoire[entree];
    if (enMemoire != null) return enMemoire;

    final persistee = await _lireStockage(entree);
    if (persistee != null) {
      _memoire[entree] = persistee;
      return persistee;
    }

    // Absente localement : conversation nouvelle, réinstallation, ou cache vidé.
    final obtenues = await rafraichir(
      conversationIds: portee.startsWith('conv:')
          ? [portee.substring(5)]
          : const <String>[],
      versions: [v],
    );
    if (!obtenues) return null;
    return _memoire[entree];
  }

  /// Rappelle `crypto-keys` et met à jour cache mémoire + keystore.
  ///
  /// Retourne `false` sur tout échec — hors ligne, session absente, endpoint
  /// non déployé, racine manquante côté serveur. Aucun de ces cas ne doit
  /// produire une clé : mieux vaut ne pas écrire que d'écrire avec la mauvaise.
  Future<bool> rafraichir({
    List<String> conversationIds = const <String>[],
    List<int>? versions,
  }) async {
    try {
      final reponse = await _supabase.functions.invoke(
        _nomFonction,
        body: <String, dynamic>{
          if (conversationIds.isNotEmpty) 'conversationIds': conversationIds,
          if (versions != null && versions.isNotEmpty) 'versions': versions,
        },
      );

      final corps = reponse.data;
      if (corps is! Map || corps['success'] != true) {
        debugPrint('DerivedKeyStore: réponse inattendue de $_nomFonction');
        return false;
      }

      final version = corps['keyVersion'];
      if (version is int) {
        _versionCourante = version;
        await _ecrireStockage(_cleVersion, '$version');
      }

      final parVersion = corps['keys'];
      if (parVersion is! Map) return false;

      var enregistrees = 0;
      for (final entreeVersion in parVersion.entries) {
        final v = int.tryParse('${entreeVersion.key}');
        final charge = entreeVersion.value;
        if (v == null || charge is! Map) continue;

        final cleUser = charge['userKey'];
        if (cleUser is String && cleUser.isNotEmpty) {
          await _memoriser(_entree('user', v), cleUser);
          enregistrees++;
        }

        final clesConv = charge['conversationKeys'];
        if (clesConv is Map) {
          for (final e in clesConv.entries) {
            final valeur = e.value;
            if (valeur is String && valeur.isNotEmpty) {
              await _memoriser(_entree('conv:${e.key}', v), valeur);
              enregistrees++;
            }
          }
        }
      }

      if (corps['truncated'] == true) {
        // Le serveur a coupé la liste : les conversations manquantes seront
        // demandées une à une, au moment où elles servent.
        debugPrint('DerivedKeyStore: liste de conversations tronquée');
      }

      return enregistrees > 0;
    } catch (e) {
      // Volontairement muet vis-à-vis de l'appelant : l'échec se traduit par
      // l'absence de clé, jamais par une clé de substitution.
      debugPrint('DerivedKeyStore: récupération impossible ($e)');
      return false;
    }
  }

  /// Recharge la version courante depuis le keystore, sans réseau.
  ///
  /// À appeler au démarrage : permet de chiffrer hors ligne avec les clés déjà
  /// connues, au lieu d'attendre un aller-retour réseau qui peut ne pas venir.
  Future<void> reprendreDepuisLeCache() async {
    final brut = await _lireStockage(_cleVersion);
    final v = brut == null ? null : int.tryParse(brut);
    if (v != null) _versionCourante = v;
  }

  /// Oublie tout — déconnexion, ou changement de compte.
  ///
  /// Les clés d'un compte ne doivent pas rester lisibles par le suivant sur le
  /// même téléphone.
  Future<void> vider() async {
    _memoire.clear();
    _versionCourante = null;
    try {
      final tout = await _stockage.readAll();
      for (final cle in tout.keys) {
        if (cle.startsWith(_prefixe)) {
          await _stockage.delete(key: cle);
        }
      }
    } catch (e) {
      debugPrint('DerivedKeyStore: purge impossible ($e)');
    }
  }

  static String _entree(String portee, int version) =>
      '$_prefixe${version}_${base64Url.encode(utf8.encode(portee))}';

  Future<void> _memoriser(String entree, String valeurBase64) async {
    _memoire[entree] = valeurBase64;
    await _ecrireStockage(entree, valeurBase64);
  }

  Future<String?> _lireStockage(String cle) async {
    try {
      return await _stockage.read(key: cle);
    } catch (e) {
      // Keystore indisponible (appareil verrouillé au premier démarrage, par
      // exemple). Le cache mémoire prend le relais pour cette session.
      debugPrint('DerivedKeyStore: lecture keystore impossible ($e)');
      return null;
    }
  }

  Future<void> _ecrireStockage(String cle, String valeur) async {
    try {
      await _stockage.write(key: cle, value: valeur);
    } catch (e) {
      debugPrint('DerivedKeyStore: écriture keystore impossible ($e)');
    }
  }

  @visibleForTesting
  void viderMemoirePourTests() {
    _memoire.clear();
    _versionCourante = null;
  }
}
