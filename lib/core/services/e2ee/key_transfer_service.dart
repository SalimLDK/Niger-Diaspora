import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase_auth_bridge.dart';
import 'secure_key_storage.dart';

/// Transfert des clés E2EE d'un téléphone à l'autre, sans passphrase.
///
/// La seule reprise existante passe par une sauvegarde chiffrée par passphrase.
/// Une passphrase perdue laisse un appareil neuf en « à restaurer » à vie —
/// pire que pas de sauvegarde du tout, puisque le coordinateur refuse alors de
/// générer une identité neuve. Ici, rien à retenir : le nouveau téléphone
/// affiche un QR, l'ancien le lit, et les clés voyagent chiffrées par une clé
/// qui n'a jamais quitté le canal optique.
///
/// **Ce que le serveur voit** : un blob AES-256-GCM et un horodatage. La clé est
/// dans le QR, pas dans la requête. La ligne est en plus protégée par RLS, ce
/// qui rend une photo du QR seule inoffensive : il faut aussi être connecté sur
/// le compte pour lire le blob.
///
/// **Pourquoi l'ancien téléphone oublie ses clés à la fin.** Le transfert
/// recopie l'identité ET le `deviceId`. Deux appareils vivants sur un même
/// ratchet finissent par se voler leurs clés de message : chacun fait avancer sa
/// copie de la chaîne, et le destinataire ne peut plus ordonner ce qu'il reçoit.
/// C'est le geste « je change de téléphone », pas « j'en ajoute un » — pour
/// ajouter un appareil, il suffit de s'y connecter : `encrypt1to1` chiffre déjà
/// une copie par appareil actif.
final keyTransferServiceProvider = Provider<KeyTransferService>((ref) {
  return KeyTransferService(storage: ref.watch(secureKeyStorageProvider));
});

/// Rendez-vous affiché en QR par l'appareil qui reçoit les clés.
///
/// Porte le compte visé : sans lui, l'ancien téléphone accepterait de livrer ses
/// clés au QR de n'importe qui.
class KeyTransferInvite {
  const KeyTransferInvite({
    required this.id,
    required this.userId,
    required this.key,
  });

  /// Identifiant de la ligne de rendez-vous.
  final String id;

  /// Compte auquel les clés appartiennent.
  final String userId;

  /// Clé AES-256 tirée au sort par le receveur. Ne transite que par le QR.
  final List<int> key;

  static const _prefix = 'dn-e2ee-transfer';
  static const _version = '1';

  String encode() => '$_prefix:$_version:$id:$userId:${base64Url.encode(key)}';

  /// Rend `null` sur tout ce qui n'est pas une invitation de cette version — la
  /// caméra lit aussi bien les QR de partage de profil que ceux du voisin.
  static KeyTransferInvite? tryParse(String raw) {
    final parts = raw.trim().split(':');
    if (parts.length != 5) return null;
    if (parts[0] != _prefix || parts[1] != _version) return null;
    if (parts[2].isEmpty || parts[3].isEmpty) return null;
    try {
      final key = base64Url.decode(parts[4]);
      if (key.length != 32) return null;
      return KeyTransferInvite(id: parts[2], userId: parts[3], key: key);
    } catch (_) {
      return null;
    }
  }
}

/// Le QR scanné vise un autre compte.
class KeyTransferAccountMismatch implements Exception {
  const KeyTransferAccountMismatch();
}

/// Session Supabase indisponible : sans elle, RLS refuse la ligne en silence.
class KeyTransferNotAuthenticated implements Exception {
  const KeyTransferNotAuthenticated();
}

/// Cet appareil n'a aucune clé à transférer.
class KeyTransferNoKeys implements Exception {
  const KeyTransferNoKeys();
}

/// Le blob ne se déchiffre pas avec la clé du QR (rendez-vous corrompu).
class KeyTransferCorrupted implements Exception {
  const KeyTransferCorrupted();
}

class KeyTransferService {
  KeyTransferService({required SecureKeyStorage storage}) : _storage = storage;

  final SecureKeyStorage _storage;
  final SupabaseClient _supabase = Supabase.instance.client;
  final AesGcm _aesGcm = AesGcm.with256bits();
  final Random _random = Random.secure();

  static const String _table = 'e2ee_key_transfers';

  /// Fenêtre pendant laquelle le QR reste valable côté client. La ligne, elle,
  /// est purgée au bout de 15 minutes par un trigger.
  static const Duration defaultTimeout = Duration(minutes: 3);

  static const Duration _pollInterval = Duration(seconds: 2);

  /// Nouveau téléphone : prépare le rendez-vous à afficher.
  KeyTransferInvite createInvite(String userId) {
    return KeyTransferInvite(
      id: _randomHex(16),
      userId: userId,
      key: _randomBytes(32),
    );
  }

  /// Ancien téléphone : chiffre l'export complet et le dépose au rendez-vous.
  Future<void> sendKeys({
    required KeyTransferInvite invite,
    required String userId,
  }) async {
    if (invite.userId != userId) throw const KeyTransferAccountMismatch();

    await _storage.initialize();
    if (!await _storage.hasE2EEKeys(userId)) throw const KeyTransferNoKeys();

    if (!await SupabaseAuthBridge.instance.ensureAuthenticated()) {
      throw const KeyTransferNotAuthenticated();
    }

    final export = await _storage.exportAllKeys(userId);
    final clear = utf8.encode(jsonEncode(export));
    final box = await _aesGcm.encrypt(clear, secretKey: SecretKey(invite.key));

    await _supabase.from(_table).insert({
      'id': invite.id,
      'user_id': userId,
      'payload': base64Encode(box.cipherText),
      'nonce': base64Encode(box.nonce),
      'mac': base64Encode(box.mac.bytes),
    });
    debugPrint('KeyTransferService: payload deposited for ${invite.id}');
  }

  /// Nouveau téléphone : attend la charge, l'importe, puis accuse réception.
  ///
  /// L'accusé (`consumed_at`) est ce qui autorise l'ancien téléphone à oublier
  /// ses clés : sans lui, un échec d'import laisserait le compte sans aucune
  /// copie de l'identité.
  Future<bool> awaitAndImport({
    required KeyTransferInvite invite,
    Duration timeout = defaultTimeout,
  }) async {
    if (!await SupabaseAuthBridge.instance.ensureAuthenticated()) {
      throw const KeyTransferNotAuthenticated();
    }

    final row = await _poll(
      timeout: timeout,
      read: () async => await _supabase
          .from(_table)
          .select('payload, nonce, mac')
          .eq('id', invite.id)
          .maybeSingle(),
    );
    if (row == null) return false;

    final List<int> clear;
    try {
      clear = await _aesGcm.decrypt(
        SecretBox(
          base64Decode(row['payload'] as String),
          nonce: base64Decode(row['nonce'] as String),
          mac: Mac(base64Decode(row['mac'] as String)),
        ),
        secretKey: SecretKey(invite.key),
      );
    } catch (e) {
      debugPrint('KeyTransferService: decrypt failed: $e');
      throw const KeyTransferCorrupted();
    }

    await _storage.initialize();
    await _storage.importAllKeys(
      invite.userId,
      jsonDecode(utf8.decode(clear)) as Map<String, dynamic>,
    );

    await _supabase
        .from(_table)
        .update({'consumed_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', invite.id);
    return true;
  }

  /// Ancien téléphone : attend l'accusé de réception du nouveau.
  Future<bool> awaitConsumed({
    required KeyTransferInvite invite,
    Duration timeout = defaultTimeout,
  }) async {
    final row = await _poll(
      timeout: timeout,
      read: () async {
        final r = await _supabase
            .from(_table)
            .select('consumed_at')
            .eq('id', invite.id)
            .maybeSingle();
        return (r != null && r['consumed_at'] != null) ? r : null;
      },
    );
    return row != null;
  }

  /// Ancien téléphone, une fois l'accusé reçu : oublie l'identité transférée.
  ///
  /// Voir l'en-tête : deux appareils sur un même ratchet se cassent mutuellement
  /// le déchiffrement. Le blob de rendez-vous part avec.
  Future<void> forgetLocalKeys({
    required KeyTransferInvite invite,
    required String userId,
  }) async {
    await _storage.initialize();
    await _storage.clearAllData(userId);
    try {
      await _supabase.from(_table).delete().eq('id', invite.id);
    } catch (e) {
      // Le trigger de purge finira le travail ; rien à signaler à l'utilisateur.
      debugPrint('KeyTransferService: rendezvous cleanup failed: $e');
    }
  }

  /// Répète [read] jusqu'à une valeur non nulle ou l'expiration de [timeout].
  Future<Map<String, dynamic>?> _poll({
    required Duration timeout,
    required Future<Map<String, dynamic>?> Function() read,
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      try {
        final row = await read();
        if (row != null) return row;
      } catch (e) {
        // Coupure réseau passagère : on retente jusqu'à l'échéance plutôt que
        // d'abandonner un transfert que l'autre appareil croit en cours.
        debugPrint('KeyTransferService: poll failed: $e');
      }
      await Future<void>.delayed(_pollInterval);
    }
    return null;
  }

  String _randomHex(int bytes) =>
      _randomBytes(bytes).map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  List<int> _randomBytes(int length) =>
      List<int>.generate(length, (_) => _random.nextInt(256));
}
