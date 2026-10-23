import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../cache_service.dart';
import 'device_label.dart';
import 'eff_wordlist.dart';
import 'key_backup_service.dart';

final historiqueBackupServiceProvider = Provider<HistoriqueBackupService>(
  (ref) => HistoriqueBackupService(cache: CacheService.instance),
);

/// Aucun message à sauvegarder sur cet appareil.
class RienASauvegarderException implements Exception {
  const RienASauvegarderException();
  @override
  String toString() => 'RienASauvegarderException';
}

/// La sauvegarde distante existe mais cette clé ne l'ouvre pas.
///
/// Arrive quand la clé a été remplacée ailleurs. La réécrire effacerait
/// l'historique qu'elle contient : la sauvegarde automatique s'arrête là, et
/// c'est à l'utilisateur de décider d'écraser (nouvelle activation).
class SauvegardeIllisibleException implements Exception {
  const SauvegardeIllisibleException();
  @override
  String toString() => 'SauvegardeIllisibleException';
}

/// Ce que la sauvegarde a emporté, pour le dire à l'utilisateur.
class ResultatSauvegardeHistorique {
  final int messages;
  final int conversations;

  /// Vrai si les plus anciens messages ont dû être laissés de côté pour tenir
  /// dans la taille que Storage accepte.
  final bool tronque;

  const ResultatSauvegardeHistorique({
    required this.messages,
    required this.conversations,
    required this.tronque,
  });
}

class InfosHistorique {
  final DateTime? creeLe;
  final int? messages;
  final String? appareil;
  final int? tailleOctets;

  const InfosHistorique({
    this.creeLe,
    this.messages,
    this.appareil,
    this.tailleOctets,
  });
}

/// Sauvegarde du texte déjà déchiffré des discussions, **automatique** une fois
/// activée, protégée par une clé de récupération que le serveur ne voit jamais.
///
/// **Pourquoi pas la base MLS.** Elle porte la clé privée de l'appareil : la
/// restaurer ailleurs ferait siéger la même identité en double dans les mêmes
/// groupes (voir `mls_chemin_base.dart`). Le moteur ne sait de toute façon pas
/// relire un message qu'il a déjà déchiffré — la clé de chaque message est
/// effacée après usage, c'est le secret de transmission. Ce qui survit, c'est
/// le clair que l'appareil a gardé dans son cache : c'est lui, et lui seul, qu'on
/// emporte. Un appareil réinstallé garde sa propre identité MLS, neuve.
///
/// **Ce qui n'est PAS sauvegardé** : les médias, les messages supprimés pour
/// tous ou pour soi, les éphémères, les placeholders « Message chiffré ». Un
/// message éphémère ou supprimé ne doit pas survivre à son effacement sur un
/// serveur que l'utilisateur ne contrôle pas.
///
/// **La clé de récupération.** Six mots tirés au hasard, affichés UNE fois. Elle
/// reste dans le Keystore/Keychain pour que les sauvegardes suivantes se fassent
/// sans rien demander ; elle ne se relit plus nulle part. Perdue avec le
/// téléphone, elle rend l'historique irrécupérable — c'est le prix de
/// l'absence de tiers de confiance.
///
/// **Une sauvegarde ne rétrécit jamais.** Après une réinstallation, le cache est
/// vide : réécrire la sauvegarde telle quelle détruirait l'historique qu'elle
/// contient. Chaque envoi relit donc l'ancien fichier et le fusionne avec le
/// cache local ([fusionner]).
class HistoriqueBackupService {
  final CacheService _cache;
  final FirebaseStorage? _stockageInjecte;
  final FlutterSecureStorage _secret;
  final Future<SharedPreferences> Function() _preferences;

  /// Lu à l'usage : le provider est instancié bien avant Firebase.
  FirebaseStorage get _stockage => _stockageInjecte ?? FirebaseStorage.instance;

  static final _aesGcm = AesGcm.with256bits();
  static final _alea = Random.secure();

  static const int version = 1;
  static const int _iterations = 200000;
  static const int _tailleSel = 32;

  /// `storage.rules` plafonne `key_backups/**` à 5 Mo ; le JSON de l'enveloppe
  /// grossit le chiffré d'un tiers (base64). On vise donc ce plafond sur le
  /// gzip, avec une marge.
  static const int tailleGzipMax = 3 * 1024 * 1024;

  /// Écart minimal entre deux sauvegardes automatiques.
  static const Duration intervalle = Duration(hours: 24);

  static const _aad = 'diaspo-historique-v1';

  bool _enCours = false;

  HistoriqueBackupService({
    required CacheService cache,
    FirebaseStorage? stockage,
    FlutterSecureStorage? secret,
    Future<SharedPreferences> Function()? preferences,
  }) : _cache = cache,
       _stockageInjecte = stockage,
       _secret =
           secret ??
           const FlutterSecureStorage(
             aOptions: AndroidOptions(encryptedSharedPreferences: true),
             iOptions: IOSOptions(
               accessibility: KeychainAccessibility.first_unlock_this_device,
             ),
           ),
       _preferences = preferences ?? SharedPreferences.getInstance;

  String _chemin(String userId) => 'key_backups/$userId/historique.enc';
  String _cleSecret(String userId) => 'historique_cle_$userId';
  String _cleActif(String userId) => 'historique_auto_$userId';
  String _cleDernier(String userId) => 'historique_auto_dernier_$userId';

  // ============================================================
  // CLÉ DE RÉCUPÉRATION ET ÉTAT
  // ============================================================

  /// Six mots et un nombre, comme la passphrase de la sauvegarde des clés.
  static String genererCle() {
    final mots = [
      for (var i = 0; i < 6; i++)
        kEffLargeWordlist[_alea.nextInt(kEffLargeWordlist.length)],
    ];
    return '${mots.join('-')}-${_alea.nextInt(100).toString().padLeft(2, '0')}';
  }

  /// La sauvegarde automatique est-elle en marche sur CET appareil ?
  ///
  /// Le drapeau seul ne suffit pas : les préférences partent dans la sauvegarde
  /// Google, la clé du Keystore non. Sur un téléphone restauré, le drapeau
  /// revient sans sa clé — et sans clé il n'y a rien à faire tourner.
  Future<bool> estActive(String userId) async {
    final prefs = await _preferences();
    if (prefs.getBool(_cleActif(userId)) != true) return false;
    return (await _lireCle(userId)) != null;
  }

  Future<String?> _lireCle(String userId) async {
    try {
      final cle = await _secret.read(key: _cleSecret(userId));
      return (cle == null || cle.isEmpty) ? null : cle;
    } catch (e) {
      // Keystore illisible (clé perdue à la restauration) : pas de clé.
      debugPrint('HistoriqueBackupService: clé illisible ($e)');
      return null;
    }
  }

  /// Met la sauvegarde automatique en marche avec [cle] (neuve si absente).
  ///
  /// Ne sauvegarde rien elle-même : l'appelant enchaîne avec
  /// [sauvegarderMaintenant]. Rend la clé, à montrer UNE fois.
  Future<String> activer(String userId, {String? cle}) async {
    final valeur = cle ?? genererCle();
    await _secret.write(key: _cleSecret(userId), value: valeur);
    final prefs = await _preferences();
    await prefs.setBool(_cleActif(userId), true);
    await prefs.remove(_cleDernier(userId));
    return valeur;
  }

  /// Arrête les envois et oublie la clé. La sauvegarde distante reste (elle se
  /// supprime à part) : elle sert encore à restaurer avec la clé notée.
  Future<void> desactiver(String userId) async {
    final prefs = await _preferences();
    await prefs.remove(_cleActif(userId));
    await prefs.remove(_cleDernier(userId));
    try {
      await _secret.delete(key: _cleSecret(userId));
    } catch (e) {
      debugPrint('HistoriqueBackupService: clé non effacée ($e)');
    }
  }

  // ============================================================
  // SÉLECTION ET FUSION (pures)
  // ============================================================

  /// Ne garde que ce qui a le droit de quitter l'appareil.
  ///
  /// Chiffrés de bout en bout (`encryptionLevel == 'e2ee'`) : le clair des
  /// autres discussions se relit sur le serveur, il n'a rien à faire ici.
  @visibleForTesting
  static Map<String, List<Map<String, dynamic>>> selectionner(
    Map<String, List<Map<String, dynamic>>> parConversation,
    String userId,
  ) {
    final sortie = <String, List<Map<String, dynamic>>>{};
    parConversation.forEach((conversation, messages) {
      final retenus = [
        for (final m in messages)
          if (_estSauvegardable(m, userId)) m,
      ];
      if (retenus.isNotEmpty) sortie[conversation] = retenus;
    });
    return sortie;
  }

  static bool _estSauvegardable(Map<String, dynamic> m, String userId) {
    if (m['id'] is! String || (m['id'] as String).isEmpty) return false;
    if (m['encryptionLevel'] != 'e2ee') return false;
    if ((m['type'] as String? ?? 'text') != 'text') return false;
    if (m['deletedForEveryone'] == true) return false;
    final pourMoi = m['deletedFor'];
    if (pourMoi is List && pourMoi.contains(userId)) return false;
    if (m['expiresAt'] != null) return false;
    if (m['mediaChiffre'] != null || m['fileUrl'] != null) return false;
    final contenu = m['content'] as String? ?? '';
    if (contenu.isEmpty || contenu.startsWith('🔐')) return false;
    return true;
  }

  /// Fusionne l'ancienne sauvegarde avec le cache local, pour qu'une
  /// sauvegarde ne perde jamais de message.
  ///
  /// - le cache local gagne sur l'ancienne copie d'un même identifiant
  ///   (message modifié depuis) ;
  /// - **un message que le cache connaît encore, mais qu'il n'a plus le droit
  ///   de sauvegarder (supprimé pour tous, expiré), est retiré de l'ancienne
  ///   copie** : sinon la fusion le ferait survivre à sa suppression ;
  /// - un message absent du cache est gardé : le cache est élagué (LRU), son
  ///   absence ne dit pas que le message a été supprimé.
  @visibleForTesting
  static Map<String, List<Map<String, dynamic>>> fusionner({
    required Map<String, List<Map<String, dynamic>>> ancien,
    required Map<String, List<Map<String, dynamic>>> local,
    required Set<String> idsInterdits,
  }) {
    final sortie = <String, Map<String, Map<String, dynamic>>>{};
    ancien.forEach((conversation, messages) {
      for (final m in messages) {
        final id = m['id'] as String;
        if (idsInterdits.contains(id)) continue;
        (sortie[conversation] ??= {})[id] = m;
      }
    });
    local.forEach((conversation, messages) {
      for (final m in messages) {
        (sortie[conversation] ??= {})[m['id'] as String] = m;
      }
    });
    return {
      for (final e in sortie.entries)
        if (e.value.isNotEmpty)
          e.key: (e.value.values.toList()
            ..sort(
              (a, b) => (a['createdAt'] as String? ?? '').compareTo(
                b['createdAt'] as String? ?? '',
              ),
            )),
    };
  }

  // ============================================================
  // ENVELOPPE (pure, testable sans Firebase)
  // ============================================================

  /// Chiffre [contenu] sous [passphrase]. L'enveloppe rendue est le fichier
  /// tel qu'il part sur Storage.
  @visibleForTesting
  static Future<Uint8List> sceller(
    Map<String, dynamic> contenu,
    String passphrase, {
    required String appareil,
    int iterations = _iterations,
  }) async {
    final sel = _octetsAleatoires(_tailleSel);
    final cle = await _deriver(passphrase, sel, iterations);
    final compresse = gzip.encode(utf8.encode(jsonEncode(contenu)));
    final boite = await _aesGcm.encrypt(
      compresse,
      secretKey: cle,
      aad: utf8.encode(_aad),
    );
    return Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'version': version,
          'kdf': 'pbkdf2-sha256',
          'iterations': iterations,
          'salt': base64Encode(sel),
          'iv': base64Encode(boite.nonce),
          'ciphertext': base64Encode(boite.cipherText),
          'authTag': base64Encode(boite.mac.bytes),
          'deviceInfo': appareil,
          'createdAt': DateTime.now().toUtc().toIso8601String(),
        }),
      ),
    );
  }

  /// Inverse de [sceller]. Lève [PassphraseException] si la clé est fausse ou
  /// le fichier altéré — GCM ne distingue pas les deux.
  @visibleForTesting
  static Future<Map<String, dynamic>> ouvrir(
    Uint8List fichier,
    String passphrase,
  ) async {
    final Map<String, dynamic> enveloppe;
    try {
      enveloppe = jsonDecode(utf8.decode(fichier)) as Map<String, dynamic>;
    } catch (_) {
      throw PassphraseException('Invalid passphrase or corrupted backup');
    }
    if (enveloppe['version'] != version) {
      throw PassphraseException('Unsupported backup version');
    }
    try {
      final cle = await _deriver(
        passphrase,
        base64Decode(enveloppe['salt'] as String),
        enveloppe['iterations'] as int,
      );
      final clair = await _aesGcm.decrypt(
        SecretBox(
          base64Decode(enveloppe['ciphertext'] as String),
          nonce: base64Decode(enveloppe['iv'] as String),
          mac: Mac(base64Decode(enveloppe['authTag'] as String)),
        ),
        secretKey: cle,
        aad: utf8.encode(_aad),
      );
      return jsonDecode(utf8.decode(gzip.decode(clair)))
          as Map<String, dynamic>;
    } catch (_) {
      throw PassphraseException('Invalid passphrase or corrupted backup');
    }
  }

  /// Écarte les plus anciens messages jusqu'à ce que le gzip tienne.
  ///
  /// Rend la sélection retenue et si quelque chose a été retiré.
  @visibleForTesting
  static ({Map<String, List<Map<String, dynamic>>> retenu, bool tronque})
  ajusterALaTaille(
    Map<String, List<Map<String, dynamic>>> selection, {
    int tailleMax = tailleGzipMax,
  }) {
    var courant = selection;
    var tronque = false;
    for (var tour = 0; tour < 20; tour++) {
      final taille = gzip.encode(utf8.encode(jsonEncode(courant))).length;
      if (taille <= tailleMax) break;
      tronque = true;
      final dates = <String>[
        for (final l in courant.values)
          for (final m in l) m['createdAt'] as String? ?? '',
      ]..sort();
      if (dates.isEmpty) break;
      // Les 25 % les plus anciens partent ; les dates ISO se trient en texte.
      final seuil = dates[(dates.length * 0.25).floor()];
      courant = {
        for (final e in courant.entries)
          if (e.value.any(
            (m) => (m['createdAt'] as String? ?? '').compareTo(seuil) > 0,
          ))
            e.key: [
              for (final m in e.value)
                if ((m['createdAt'] as String? ?? '').compareTo(seuil) > 0) m,
            ],
      };
      if (courant.isEmpty) break;
    }
    return (retenu: courant, tronque: tronque);
  }

  // ============================================================
  // SAUVEGARDER
  // ============================================================

  /// Sauvegarde le cache local **maintenant**, avec la clé gardée sur l'appareil.
  ///
  /// [ecraser] ignore l'ancienne sauvegarde au lieu de la fusionner : seulement
  /// juste après une activation avec une clé neuve, que l'utilisateur a
  /// acceptée en sachant que l'ancien fichier est remplacé.
  ///
  /// Lève [RienASauvegarderException] quand il n'y a rien à envoyer et
  /// [SauvegardeIllisibleException] quand l'ancien fichier ne s'ouvre pas avec
  /// cette clé (il n'est alors PAS touché).
  Future<ResultatSauvegardeHistorique> sauvegarderMaintenant(
    String userId, {
    bool ecraser = false,
  }) async {
    final cle = await _lireCle(userId);
    if (cle == null) throw StateError('sauvegarde automatique non activée');

    final brut = {
      for (final id in _cache.conversationsEnCache())
        id: _cache.getCachedMessages(id),
    };
    final local = selectionner(brut, userId);
    final interdits = {
      for (final l in brut.values)
        for (final m in l)
          if (m['id'] is String && !_estSauvegardable(m, userId))
            m['id'] as String,
    };

    var fusion = local;
    if (!ecraser) {
      final ancien = await _lireAncien(userId, cle);
      if (ancien != null) {
        fusion = fusionner(
          ancien: selectionner(ancien, userId),
          local: local,
          idsInterdits: interdits,
        );
      }
    }
    if (fusion.isEmpty) throw const RienASauvegarderException();

    final ajuste = ajusterALaTaille(fusion);
    final messages = ajuste.retenu.values.fold<int>(0, (n, l) => n + l.length);
    if (messages == 0) throw const RienASauvegarderException();

    final appareil = await currentDeviceLabel();
    // PBKDF2 à 200 000 tours bloquerait l'interface plusieurs secondes sur un
    // téléphone modeste : l'envoi se prépare dans un isolate.
    final fichier = await compute(
      _scellerEnIsolate,
      _ArgsSceller({'conversations': ajuste.retenu}, cle, appareil),
    );
    await _stockage
        .ref(_chemin(userId))
        .putData(
          fichier,
          SettableMetadata(
            contentType: 'application/json',
            customMetadata: {
              'version': version.toString(),
              'createdAt': DateTime.now().toUtc().toIso8601String(),
              'deviceInfo': appareil,
              'messages': messages.toString(),
            },
          ),
        );
    final prefs = await _preferences();
    await prefs.setString(
      _cleDernier(userId),
      DateTime.now().toUtc().toIso8601String(),
    );
    return ResultatSauvegardeHistorique(
      messages: messages,
      conversations: ajuste.retenu.length,
      tronque: ajuste.tronque,
    );
  }

  /// L'ancien fichier, déchiffré — ou `null` s'il n'y en a pas.
  Future<Map<String, List<Map<String, dynamic>>>?> _lireAncien(
    String userId,
    String cle,
  ) async {
    final fichier = await _telecharger(userId);
    if (fichier == null) return null;
    final Map<String, dynamic> contenu;
    try {
      contenu = await compute(_ouvrirEnIsolate, _ArgsOuvrir(fichier, cle));
    } on PassphraseException {
      throw const SauvegardeIllisibleException();
    }
    return _conversations(contenu);
  }

  static Map<String, List<Map<String, dynamic>>> _conversations(
    Map<String, dynamic> contenu,
  ) {
    final brut = (contenu['conversations'] as Map<String, dynamic>? ?? {});
    return {
      for (final e in brut.entries)
        e.key: [
          for (final m in (e.value as List))
            if (m is Map<String, dynamic>) m,
        ],
    };
  }

  Future<Uint8List?> _telecharger(String userId) async {
    try {
      return await _stockage.ref(_chemin(userId)).getData(20 * 1024 * 1024);
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') return null;
      rethrow;
    }
  }

  /// Appelée par le déclencheur de l'application : ne fait rien si la
  /// sauvegarde n'est pas activée ou si la dernière date de moins de
  /// [intervalle]. **N'échoue jamais bruyamment** : un envoi manqué se refait
  /// au prochain passage, et l'utilisateur n'a rien à y voir.
  Future<void> sauvegardeAutomatique(String userId) async {
    if (_enCours) return;
    _enCours = true;
    try {
      if (!await estActive(userId)) return;
      final prefs = await _preferences();
      final dernier = DateTime.tryParse(prefs.getString(_cleDernier(userId)) ?? '');
      if (dernier != null && DateTime.now().toUtc().difference(dernier) < intervalle) {
        return;
      }
      await sauvegarderMaintenant(userId);
    } on RienASauvegarderException {
      // Rien de neuf : pas une erreur.
    } on SauvegardeIllisibleException {
      debugPrint('HistoriqueBackupService: ancienne sauvegarde illisible, envoi suspendu');
    } catch (e) {
      debugPrint('HistoriqueBackupService: sauvegarde automatique échouée ($e)');
    } finally {
      _enCours = false;
    }
  }

  // ============================================================
  // RESTAURER, INFOS, SUPPRIMER
  // ============================================================

  /// Rend le nombre de messages réellement ajoutés au cache.
  Future<int> restaurer(String userId, String cle) async {
    final fichier = await _telecharger(userId);
    if (fichier == null) {
      throw BackupNotFoundException('No history backup found');
    }

    final contenu = await compute(_ouvrirEnIsolate, _ArgsOuvrir(fichier, cle));
    var ajoutes = 0;
    for (final e in _conversations(contenu).entries) {
      // Le fichier vient du serveur : on le re-filtre comme à l'aller.
      final sains = selectionner({e.key: e.value}, userId)[e.key];
      if (sains == null) continue;
      ajoutes += await _cache.restaurerMessages(e.key, sains);
    }
    return ajoutes;
  }

  Future<InfosHistorique?> infos(String userId) async {
    try {
      final m = await _stockage.ref(_chemin(userId)).getMetadata();
      final perso = m.customMetadata ?? const {};
      return InfosHistorique(
        creeLe: DateTime.tryParse(perso['createdAt'] ?? '')?.toLocal(),
        messages: int.tryParse(perso['messages'] ?? ''),
        appareil: perso['deviceInfo'],
        tailleOctets: m.size,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> supprimer(String userId) async {
    try {
      await _stockage.ref(_chemin(userId)).delete();
    } catch (e) {
      debugPrint('HistoriqueBackupService: suppression impossible ($e)');
      rethrow;
    }
  }

  // ============================================================
  // UTILITAIRES
  // ============================================================

  static Future<SecretKey> _deriver(
    String passphrase,
    List<int> sel,
    int iterations,
  ) {
    return Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    ).deriveKey(secretKey: SecretKey(utf8.encode(passphrase)), nonce: sel);
  }

  static Uint8List _octetsAleatoires(int n) =>
      Uint8List.fromList(List.generate(n, (_) => _alea.nextInt(256)));
}

class _ArgsSceller {
  final Map<String, dynamic> contenu;
  final String cle;
  final String appareil;
  const _ArgsSceller(this.contenu, this.cle, this.appareil);
}

class _ArgsOuvrir {
  final Uint8List fichier;
  final String cle;
  const _ArgsOuvrir(this.fichier, this.cle);
}

Future<Uint8List> _scellerEnIsolate(_ArgsSceller a) =>
    HistoriqueBackupService.sceller(a.contenu, a.cle, appareil: a.appareil);

Future<Map<String, dynamic>> _ouvrirEnIsolate(_ArgsOuvrir a) =>
    HistoriqueBackupService.ouvrir(a.fichier, a.cle);
