import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Scelle une valeur avant qu'elle n'entre dans `SharedPreferences`.
///
/// `SharedPreferences` part dans la sauvegarde du téléphone — Google sur
/// Android (`shared_prefs/` n'est pas exclu : les préférences doivent suivre
/// l'utilisateur), iCloud sur iOS. Trois magasins y rangeaient du CLAIR :
/// la pile des bannières de messages (`PileMessagesNotifiees`, 24 h de
/// textes, messages chiffrés compris), les aperçus MLS déchiffrés
/// (`MlsNotificationPreview`) et la file des réponses depuis la notification
/// pas encore envoyées (`BackgroundReplyService`). Le chiffrement de bout en
/// bout s'arrêtait à la sauvegarde.
///
/// Scellé : AES-256-GCM, sous une clé tirée une fois et gardée par
/// `flutter_secure_storage` — Keystore Android, Trousseau iOS en
/// `first_unlock_this_device`. Ni l'une ni l'autre ne quitte l'appareil : une
/// sauvegarde restaurée ailleurs ne contient que du chiffré illisible, et
/// [desceller] y rend `null` — ce qui est juste : une bannière d'un autre
/// téléphone n'a rien à faire sur celui-ci. Le fichier du stockage sécurisé
/// est lui-même exclu de la sauvegarde (`regles_sauvegarde.xml`) : restauré,
/// il ferait lever chaque lecture au lieu de laisser naître une clé neuve.
///
/// Les deux isolates (app et notifications) tirent la même clé du même
/// stockage ; chacun la garde en mémoire après la première lecture.
///
/// **Ne lève jamais.** Si la clé est inaccessible, [sceller] rend le clair
/// tel quel — c'est l'état d'avant, pas une perte de message — et [desceller]
/// accepte toujours une valeur non scellée : les piles écrites par une
/// version précédente se lisent, puis se réécrivent scellées.
class ScelleLocal {
  ScelleLocal._();

  static const String _prefixe = 'sl1:';
  static const String _alias = 'scelle_local_cle_v1';
  static const int _longueurNonce = 12;

  static const FlutterSecureStorage _stockage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      keyCipherAlgorithm:
          KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static final AesGcm _aes = AesGcm.with256bits();
  static Future<SecretKey?>? _cle;
  static Future<SecretKey?> Function()? _fournisseurPourTests;

  /// Remplace la source de la clé (tests). `null` rétablit le stockage.
  @visibleForTesting
  static void remplacerClePourTests(Future<SecretKey?> Function()? fournisseur) {
    _fournisseurPourTests = fournisseur;
    _cle = null;
  }

  /// Vrai si [valeur] porte la marque du scellé.
  static bool estScelle(String? valeur) =>
      valeur != null && valeur.startsWith(_prefixe);

  static Future<SecretKey?> _lireOuCreerCle() async {
    final fournisseur = _fournisseurPourTests;
    if (fournisseur != null) return fournisseur();
    try {
      final existante = await _stockage.read(key: _alias);
      if (existante != null && existante.isNotEmpty) {
        return SecretKey(base64Decode(existante));
      }
      final rng = Random.secure();
      final octets =
          Uint8List.fromList(List<int>.generate(32, (_) => rng.nextInt(256)));
      await _stockage.write(key: _alias, value: base64Encode(octets));
      return SecretKey(octets);
    } catch (e) {
      debugPrint('ScelleLocal : clé inaccessible ($e)');
      return null;
    }
  }

  static Future<SecretKey?> _cleCourante() {
    final enCours = _cle ??= _lireOuCreerCle();
    // Un échec ne se fige pas : la prochaine demande retentera le stockage.
    return enCours.then((cle) {
      if (cle == null) _cle = null;
      return cle;
    });
  }

  /// [clair] scellé, ou [clair] lui-même si la clé est inaccessible.
  static Future<String> sceller(String clair) async {
    try {
      final cle = await _cleCourante();
      if (cle == null) return clair;
      final nonce = _aes.newNonce();
      final boite = await _aes.encrypt(
        utf8.encode(clair),
        secretKey: cle,
        nonce: nonce,
      );
      return _prefixe + base64Encode(boite.concatenation());
    } catch (e) {
      debugPrint('ScelleLocal : scellé impossible ($e)');
      return clair;
    }
  }

  /// Le clair de [valeur]. Une valeur non scellée (écrite avant ce
  /// mécanisme, ou faute de clé) est rendue telle quelle ; un scellé
  /// illisible — autre appareil, clé perdue, octets altérés — rend `null`.
  static Future<String?> desceller(String? valeur) async {
    if (valeur == null) return null;
    if (!estScelle(valeur)) return valeur;
    try {
      final cle = await _cleCourante();
      if (cle == null) return null;
      final octets = base64Decode(valeur.substring(_prefixe.length));
      final boite = SecretBox.fromConcatenation(
        octets,
        nonceLength: _longueurNonce,
        macLength: _aes.macAlgorithm.macLength,
      );
      return utf8.decode(await _aes.decrypt(boite, secretKey: cle));
    } catch (_) {
      return null;
    }
  }
}
