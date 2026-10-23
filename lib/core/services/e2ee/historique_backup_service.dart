import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cache_service.dart';
import 'device_label.dart';
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

/// Sauvegarde **manuelle** du texte déjà déchiffré des discussions.
///
/// **Pourquoi pas la base MLS.** Elle porte la clé privée de l'appareil : la
/// restaurer ailleurs ferait siéger la même identité en double dans les mêmes
/// groupes (voir `mls_chemin_base.dart`). Le moteur ne sait de toute façon pas
/// relire un message qu'il a déjà déchiffré. Ce qui survit, c'est le clair que
/// l'appareil a gardé dans son cache : c'est lui, et lui seul, qu'on emporte.
///
/// **Ce qui n'est PAS sauvegardé** : les médias, les messages supprimés pour
/// tous ou pour soi, les éphémères, les placeholders « Message chiffré ». Un
/// message éphémère ou supprimé ne doit pas survivre à son effacement sur un
/// serveur que l'utilisateur ne contrôle pas.
///
/// Même protection que la sauvegarde des clés (PBKDF2 200 000 itérations,
/// AES-256-GCM, sel aléatoire), mais **une passphrase et un fichier à part** :
/// l'un ne rend pas l'autre lisible.
class HistoriqueBackupService {
  final CacheService _cache;

  /// Lu à l'usage : le provider est instancié bien avant Firebase.
  FirebaseStorage get _stockage => FirebaseStorage.instance;

  final _aesGcm = AesGcm.with256bits();
  final _alea = Random.secure();

  static const int version = 1;
  static const int _iterations = 200000;
  static const int _tailleSel = 32;

  /// `storage.rules` plafonne `key_backups/**` à 5 Mo ; le JSON de l'enveloppe
  /// grossit le chiffré d'un tiers (base64). On vise donc ce plafond sur le
  /// gzip, avec une marge.
  static const int tailleGzipMax = 3 * 1024 * 1024;

  static const _aad = 'diaspo-historique-v1';

  HistoriqueBackupService({required CacheService cache}) : _cache = cache;

  String _chemin(String userId) => 'key_backups/$userId/historique.enc';

  // ============================================================
  // SÉLECTION (pure)
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

  // ============================================================
  // ENVELOPPE (pure, testable sans Firebase)
  // ============================================================

  /// Chiffre [contenu] sous [passphrase]. L'enveloppe rendue est le fichier
  /// tel qu'il part sur Storage.
  @visibleForTesting
  Future<Uint8List> sceller(
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

  /// Inverse de [sceller]. Lève [PassphraseException] si la passphrase est
  /// fausse ou le fichier altéré — GCM ne distingue pas les deux.
  @visibleForTesting
  Future<Map<String, dynamic>> ouvrir(
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
          if (e.value.any((m) => (m['createdAt'] as String? ?? '').compareTo(seuil) > 0))
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
  // SAUVEGARDER / RESTAURER
  // ============================================================

  Future<ResultatSauvegardeHistorique> sauvegarder(
    String userId,
    String passphrase,
  ) async {
    if (passphrase.length < 8) {
      throw ArgumentError('Passphrase must be at least 8 characters');
    }
    final brut = {
      for (final id in _cache.conversationsEnCache())
        id: _cache.getCachedMessages(id),
    };
    final selection = selectionner(brut, userId);
    if (selection.isEmpty) throw const RienASauvegarderException();

    final ajuste = ajusterALaTaille(selection);
    final messages = ajuste.retenu.values.fold<int>(0, (n, l) => n + l.length);
    if (messages == 0) throw const RienASauvegarderException();

    final appareil = await currentDeviceLabel();
    final fichier = await sceller(
      {'conversations': ajuste.retenu},
      passphrase,
      appareil: appareil,
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
    return ResultatSauvegardeHistorique(
      messages: messages,
      conversations: ajuste.retenu.length,
      tronque: ajuste.tronque,
    );
  }

  /// Rend le nombre de messages réellement ajoutés au cache.
  Future<int> restaurer(String userId, String passphrase) async {
    final Uint8List? fichier;
    try {
      fichier = await _stockage.ref(_chemin(userId)).getData(20 * 1024 * 1024);
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') {
        throw BackupNotFoundException('No history backup found');
      }
      rethrow;
    }
    if (fichier == null) {
      throw BackupNotFoundException('No history backup found');
    }

    final contenu = await ouvrir(fichier, passphrase);
    final conversations =
        (contenu['conversations'] as Map<String, dynamic>? ?? {});
    var ajoutes = 0;
    for (final e in conversations.entries) {
      final messages = [
        for (final m in (e.value as List))
          if (m is Map<String, dynamic>) m,
      ];
      // Le fichier vient du serveur : on le re-filtre comme à l'aller.
      final sains = selectionner({e.key: messages}, userId)[e.key];
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

  Future<SecretKey> _deriver(String passphrase, List<int> sel, int iterations) {
    return Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    ).deriveKey(secretKey: SecretKey(utf8.encode(passphrase)), nonce: sel);
  }

  Uint8List _octetsAleatoires(int n) =>
      Uint8List.fromList(List.generate(n, (_) => _alea.nextInt(256)));
}
