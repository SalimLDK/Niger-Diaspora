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
/// générer une identité neuve. Ici, rien à retenir : l'ancien téléphone dépose
/// ses clés chiffrées et affiche un QR, le neuf le lit et va les chercher.
///
/// **Pourquoi l'ancien affiche et le neuf scanne**, et pas l'inverse. L'app
/// n'autorise qu'une session par compte : `SessionService` écrit un identifiant
/// de session neuf à chaque connexion, et l'appareil qui ne le porte plus se
/// déconnecte (« Connecté ailleurs »). Se connecter sur le téléphone neuf
/// éjecte donc l'ancien à l'instant même — s'il devait déposer après ça, il ne
/// le pourrait plus. Le dépôt vient donc en premier, tant que l'ancien a encore
/// sa session ; le neuf scanne **avant** de se connecter, retient le
/// rendez-vous, puis se connecte et va chercher la charge.
///
/// **Ce que le serveur voit** : un blob AES-256-GCM et un horodatage. La clé est
/// dans le QR, pas dans la requête. La ligne est en plus protégée par RLS, ce
/// qui rend une photo du QR seule inoffensive : il faut aussi être connecté sur
/// le compte pour lire le blob.
final keyTransferServiceProvider = Provider<KeyTransferService>((ref) {
  return KeyTransferService(storage: ref.watch(secureKeyStorageProvider));
});

/// Rendez-vous affiché en QR par l'appareil qui détient les clés.
///
/// Porte le compte visé : le téléphone neuf n'est pas encore connecté quand il
/// scanne, c'est le QR qui lui apprend de quel compte il s'agit.
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

  /// Clé AES-256 tirée au sort par l'ancien téléphone. Ne transite que par le
  /// QR.
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

/// Le compte connecté n'est pas celui que vise le QR scanné.
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

/// Le rendez-vous n'existe plus (expiré, ou déjà consommé).
class KeyTransferExpired implements Exception {
  const KeyTransferExpired();
}

/// Le blob ne se déchiffre pas avec la clé du QR (rendez-vous corrompu).
class KeyTransferCorrupted implements Exception {
  const KeyTransferCorrupted();
}

class KeyTransferService {
  KeyTransferService({required SecureKeyStorage storage}) : _storage = storage;

  final SecureKeyStorage _storage;

  /// Lu à l'usage, pas à la construction : le provider est instancié bien avant
  /// que Supabase le soit (et jamais du tout sous test).
  SupabaseClient get _supabase => Supabase.instance.client;
  final AesGcm _aesGcm = AesGcm.with256bits();
  final Random _random = Random.secure();

  static const String _table = 'e2ee_key_transfers';

  /// Durée de vie d'un QR affiché. Au-delà, l'ancien téléphone dépose une
  /// charge neuve, chiffrée par une clé neuve : un code laissé sur une table ne
  /// reste pas indéfiniment valable.
  static const Duration rotateEvery = Duration(seconds: 90);

  /// Rendez-vous encore ouverts parmi ceux déjà déposés : le courant et le
  /// précédent.
  ///
  /// Garder le précédent ferme la course où le téléphone neuf scanne le code à
  /// l'instant exact où il tourne. Les plus anciens sont supprimés par
  /// [pruneDeposits] ; le trigger de purge s'occupe du reste au bout d'un quart
  /// d'heure.
  static List<KeyTransferInvite> keepValid(List<KeyTransferInvite> issued) =>
      issued.length <= 2 ? issued : issued.sublist(issued.length - 2);

  /// Ancien téléphone : chiffre l'export complet, le dépose, et rend le
  /// rendez-vous à afficher en QR.
  Future<KeyTransferInvite> deposit(String userId) async {
    await _storage.initialize();
    if (!await _storage.hasE2EEKeys(userId)) throw const KeyTransferNoKeys();

    if (!await SupabaseAuthBridge.instance.ensureAuthenticated()) {
      throw const KeyTransferNotAuthenticated();
    }

    final invite = KeyTransferInvite(
      id: _randomHex(16),
      userId: userId,
      key: _randomBytes(32),
    );

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
    return invite;
  }

  /// Supprime les dépôts qui ne sont plus offerts, en gardant [keep].
  ///
  /// Sans ça, chaque renouvellement laisserait derrière lui une copie chiffrée
  /// de l'identité, valable jusqu'à la purge — autant en laisser le moins
  /// possible.
  Future<void> pruneDeposits({
    required String userId,
    required List<KeyTransferInvite> keep,
  }) async {
    try {
      final gardes = keep.map((i) => i.id).toList();
      var query = _supabase.from(_table).delete().eq('user_id', userId);
      if (gardes.isNotEmpty) {
        query = query.not('id', 'in', '(${gardes.join(',')})');
      }
      await query;
    } catch (e) {
      // Le trigger de purge finira le travail ; rien à signaler ici.
      debugPrint('KeyTransferService: prune failed: $e');
    }
  }

  /// Téléphone neuf, une fois connecté : va chercher la charge et l'importe.
  ///
  /// [userId] est le compte réellement connecté ; il doit être celui que vise
  /// le QR, sinon RLS refuserait la lecture de toute façon — autant le dire
  /// clairement.
  Future<void> claim({
    required KeyTransferInvite invite,
    required String userId,
  }) async {
    if (invite.userId != userId) throw const KeyTransferAccountMismatch();

    if (!await SupabaseAuthBridge.instance.ensureAuthenticated()) {
      throw const KeyTransferNotAuthenticated();
    }

    final row = await _supabase
        .from(_table)
        .select('payload, nonce, mac')
        .eq('id', invite.id)
        .maybeSingle();
    if (row == null) throw const KeyTransferExpired();

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
      userId,
      jsonDecode(utf8.decode(clear)) as Map<String, dynamic>,
    );

    // La charge n'a plus lieu d'exister : une copie chiffrée de l'identité qui
    // traîne est une copie de trop.
    try {
      await _supabase.from(_table).delete().eq('id', invite.id);
    } catch (e) {
      debugPrint('KeyTransferService: rendezvous cleanup failed: $e');
    }
  }

  /// Retient le rendez-vous scanné avant la connexion.
  ///
  /// Le téléphone neuf scanne alors qu'il n'a pas encore de session : il ne peut
  /// donc pas lire la ligne tout de suite. Le rendez-vous attend ici que la
  /// connexion ait lieu, puis `E2EEBackupCoordinator` le reprend.
  Future<void> rememberPending(KeyTransferInvite invite) async {
    await _storage.initialize();
    await _storage.storePendingTransfer(invite.encode());
  }

  Future<KeyTransferInvite?> pendingInvite() async {
    await _storage.initialize();
    final raw = await _storage.readPendingTransfer();
    return raw == null ? null : KeyTransferInvite.tryParse(raw);
  }

  Future<void> forgetPending() async {
    await _storage.initialize();
    await _storage.clearPendingTransfer();
  }

  /// Ancien téléphone, quand la personne déclare avoir fini : oublie
  /// l'identité, avec une copie de secours de sept jours.
  ///
  /// Rien ne l'impose — sous la règle d'une seule session par compte, les deux
  /// appareils ne peuvent pas se disputer le ratchet en même temps. C'est une
  /// hygiène : un téléphone qu'on donne ou qu'on revend ne doit pas partir avec
  /// de quoi lire les messages.
  Future<void> forgetLocalKeys(String userId) async {
    await _storage.initialize();
    await _storage.storeTransferUndo(
      userId,
      await _storage.exportAllKeys(userId),
    );
    await _storage.clearAllData(userId);
  }

  /// La copie de secours en attente, ou `null` (absente ou périmée).
  Future<({DateTime at, Map<String, dynamic> keys})?> pendingUndo(
    String userId,
  ) async {
    await _storage.initialize();
    return _storage.readTransferUndo(userId);
  }

  /// Remet les clés mises de côté sur cet appareil.
  Future<bool> undoTransfer(String userId) async {
    await _storage.initialize();
    final undo = await _storage.readTransferUndo(userId);
    if (undo == null) return false;
    await _storage.importAllKeys(userId, undo.keys);
    await _storage.clearTransferUndo(userId);
    return true;
  }

  /// Renonce à la marche arrière : la copie de secours est effacée maintenant
  /// au lieu d'attendre l'expiration.
  Future<void> discardUndo(String userId) async {
    await _storage.initialize();
    await _storage.clearTransferUndo(userId);
  }

  String _randomHex(int bytes) =>
      _randomBytes(bytes).map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  List<int> _randomBytes(int length) =>
      List<int>.generate(length, (_) => _random.nextInt(256));
}
