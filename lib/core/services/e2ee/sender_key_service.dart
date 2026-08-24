import 'dart:convert';
import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'messaging_e2ee_service.dart';
import 'models/e2ee_models.dart';
import 'secure_key_storage.dart';

/// Provider pour le service Sender Keys
final senderKeyServiceProvider = Provider<SenderKeyService>((ref) {
  final storage = ref.watch(secureKeyStorageProvider);
  final e2eeService = ref.watch(messagingE2EEServiceProvider);
  return SenderKeyService(storage: storage, e2eeService: e2eeService);
});

/// Service de gestion des Sender Keys pour les groupes E2EE
///
/// Le protocole Sender Keys permet de chiffrer un message une seule fois
/// pour tout le groupe, au lieu de O(n) chiffrements individuels.
///
/// Flow:
/// 1. Chaque membre génère une Sender Key unique pour le groupe
/// 2. La Sender Key est distribuée à tous les membres via E2EE 1-1
/// 3. Quand un membre envoie un message, il le chiffre avec sa Sender Key
/// 4. Tous les membres peuvent déchiffrer avec la Sender Key de l'expéditeur
/// 5. Quand un membre quitte, TOUS les membres régénèrent leur Sender Key
class SenderKeyService {
  final SecureKeyStorage _storage;
  final MessagingE2EEService _e2eeService;
  final SupabaseClient _supabase = Supabase.instance.client;

  // Algorithmes cryptographiques
  final _aesGcm = AesGcm.with256bits();
  final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
  final _random = Random.secure();

  // Info pour HKDF
  static final _senderKeyInfo = utf8.encode('DiaspoNiger_SenderKey');

  SenderKeyService({
    required SecureKeyStorage storage,
    required MessagingE2EEService e2eeService,
  })  : _storage = storage,
        _e2eeService = e2eeService;

  // ============================================================
  // GÉNÉRATION DE SENDER KEY
  // ============================================================

  /// Génère une nouvelle Sender Key pour un groupe
  Future<E2EESenderKey> createSenderKey(String groupId) async {
    final userId = _e2eeService.currentUserId;
    if (userId == null) {
      throw StateError('E2EE service not initialized');
    }

    final deviceIdStr = await _storage.getDeviceId(userId);
    final deviceId = int.tryParse(deviceIdStr ?? '1') ?? 1;

    // Générer une clé de chaîne aléatoire (32 bytes)
    final chainKey = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      chainKey[i] = _random.nextInt(256);
    }

    // Générer une paire de clés de signature
    final signatureKeyPair = await _generateSignatureKeyPair();

    final senderKey = E2EESenderKey(
      groupId: groupId,
      senderId: userId,
      senderDeviceId: deviceId,
      keyId: _random.nextInt(0x7FFFFFFF),
      chainKey: chainKey,
      signatureKeyPublic: signatureKeyPair.publicKey,
      signatureKeyPrivate: signatureKeyPair.privateKey,
      chainIndex: 0,
    );

    // Stocker localement
    await _storage.storeSenderKey(senderKey);

    debugPrint('SenderKeyService: Created sender key for group $groupId');
    return senderKey;
  }

  /// Generates a proper X25519 key pair for Sender Key signatures.
  /// Security: uses real asymmetric key derivation instead of HMAC with hardcoded secret.
  Future<({Uint8List publicKey, Uint8List privateKey})> _generateSignatureKeyPair() async {
    final keyPair = await X25519().newKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    final privateKeyBytes = await keyPair.extractPrivateKeyBytes();

    return (
      publicKey: Uint8List.fromList(publicKey.bytes),
      privateKey: Uint8List.fromList(privateKeyBytes),
    );
  }

  // ============================================================
  // DISTRIBUTION DES SENDER KEYS
  // ============================================================

  /// Distribue notre Sender Key à un membre du groupe via E2EE 1-1.
  ///
  /// Renvoie `true` seulement si la remise a effectivement eu lieu. Elle échoue
  /// silencieusement quand aucune session Signal n'existe avec ce membre —
  /// `encryptMessage` rend alors `null` — et l'appelant DOIT le savoir : une
  /// clé partiellement distribuée ne doit pas servir à chiffrer.
  Future<bool> distributeSenderKey(String groupId, String recipientId) async {
    final userId = _e2eeService.currentUserId;
    if (userId == null) return false;

    final deviceIdStr = await _storage.getDeviceId(userId);
    final deviceId = int.tryParse(deviceIdStr ?? '1') ?? 1;

    // Récupérer notre Sender Key pour ce groupe
    var senderKey = await _storage.getSenderKey(groupId, userId, deviceId);

    // Créer si n'existe pas — ici c'est légitime : on est sur le point de la
    // distribuer, contrairement au chemin d'émission.
    senderKey ??= await createSenderKey(groupId);

    // Créer le message de distribution
    final distributionMessage = _createDistributionMessage(senderKey);

    // Chiffrer et envoyer via E2EE 1-1.
    //
    // ⚠️ Cet appel LÈVE quand les clés publiées du membre ne vérifient pas
    // (« Signed pre-key signature verification failed »). Sans ce try, un seul
    // membre dans ce cas faisait avorter la boucle de `distributeSenderKeyToGroup`,
    // l'exception remontait jusqu'au `catch` de `MessageCryptoService`, et le
    // groupe restait en AES sans qu'aucun compte rendu ne soit produit — donc
    // sans que rien ne soit signalé à l'utilisateur. Constaté sur appareil le
    // 2026-08-23 avec le compte plateforme.
    final E2EEEncryptedMessage? encrypted;
    try {
      encrypted = await _e2eeService.encryptMessage(
        recipientId,
        jsonEncode(distributionMessage),
      );
    } catch (e) {
      debugPrint(
        'SenderKeyService: distribution vers $recipientId impossible — $e',
      );
      return false;
    }

    if (encrypted != null) {
      await _supabase.from('e2ee_sender_key_distributions').upsert({
        'group_id': groupId,
        'sender_id': userId,
        'sender_device_id': deviceId,
        'recipient_id': recipientId,
        'encrypted_distribution': encrypted.toFirebaseString(),
        'created_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'group_id,sender_id,recipient_id',);

      debugPrint('SenderKeyService: Distributed sender key to $recipientId');
      return true;
    }

    debugPrint(
      'SenderKeyService: aucune session Signal avec $recipientId — '
      'Sender Key NON distribuée',
    );
    return false;
  }

  /// Distribue notre Sender Key à tous les membres d'un groupe.
  ///
  /// La clé n'est marquée distribuée que si **chaque** autre membre l'a reçue.
  /// Sinon on reste en repli AES : un message qu'une partie du groupe ne peut
  /// pas lire est pire qu'un message chiffré avec la clé partagée — d'autant
  /// que son auteur ne pourrait pas le relire non plus.
  Future<SenderKeyDistribution> distributeSenderKeyToGroup(
    String groupId,
    List<String> memberIds,
  ) async {
    final userId = _e2eeService.currentUserId;
    if (userId == null) {
      return const SenderKeyDistribution(delivered: 0, missingMemberIds: []);
    }

    final recipients = memberIds.where((id) => id != userId).toList();
    final missing = <String>[];
    var delivered = 0;
    for (final memberId in recipients) {
      if (await distributeSenderKey(groupId, memberId)) {
        delivered++;
      } else {
        missing.add(memberId);
      }
    }

    final result = SenderKeyDistribution(
      delivered: delivered,
      missingMemberIds: missing,
    );
    if (result.isComplete) await _markSenderKeyDistributed(groupId);

    debugPrint(
      'SenderKeyService: Sender Key remise à $delivered/${recipients.length} '
      'membres de $groupId — '
      '${result.isComplete ? "chiffrement de groupe actif" : "repli AES maintenu"}',
    );
    return result;
  }

  /// Note que notre Sender Key de [groupId] est entre les mains de tous les
  /// membres : elle peut désormais servir à chiffrer.
  Future<void> _markSenderKeyDistributed(String groupId) async {
    final userId = _e2eeService.currentUserId;
    if (userId == null) return;
    final deviceIdStr = await _storage.getDeviceId(userId);
    final deviceId = int.tryParse(deviceIdStr ?? '1') ?? 1;

    final senderKey = await _storage.getSenderKey(groupId, userId, deviceId);
    if (senderKey == null || senderKey.isDistributed) return;
    await _storage.storeSenderKey(senderKey.copyWith(isDistributed: true));
  }

  /// Crée le message de distribution de Sender Key
  Map<String, dynamic> _createDistributionMessage(E2EESenderKey senderKey) {
    return {
      'type': 'sender_key_distribution',
      'groupId': senderKey.groupId,
      'keyId': senderKey.keyId,
      'chainKey': base64Encode(senderKey.chainKey),
      'signatureKeyPublic': base64Encode(senderKey.signatureKeyPublic),
      'chainIndex': senderKey.chainIndex,
    };
  }

  /// Traite un message de distribution de Sender Key reçu
  Future<void> processDistributionMessage(
    String senderId,
    int senderDeviceId,
    Map<String, dynamic> distribution,
  ) async {
    final groupId = distribution['groupId'] as String;
    final keyId = distribution['keyId'] as int;
    final chainKey = base64Decode(distribution['chainKey'] as String);
    final signatureKeyPublic = base64Decode(distribution['signatureKeyPublic'] as String);
    final chainIndex = distribution['chainIndex'] as int;

    // Créer et stocker la Sender Key reçue (sans clé privée de signature)
    final senderKey = E2EESenderKey(
      groupId: groupId,
      senderId: senderId,
      senderDeviceId: senderDeviceId,
      keyId: keyId,
      chainKey: chainKey,
      signatureKeyPublic: signatureKeyPublic,
      signatureKeyPrivate: null, // On ne reçoit pas la clé privée
      chainIndex: chainIndex,
    );

    await _storage.storeSenderKey(senderKey);
    debugPrint('SenderKeyService: Received sender key from $senderId for group $groupId');
  }

  // ============================================================
  // CHIFFREMENT / DÉCHIFFREMENT AVEC SENDER KEY
  // ============================================================

  /// Chiffre un message avec notre Sender Key pour le groupe
  Future<SenderKeyEncryptedMessage?> encryptWithSenderKey(
    String groupId,
    String plaintext,
  ) async {
    final userId = _e2eeService.currentUserId;
    if (userId == null) return null;

    final deviceIdStr = await _storage.getDeviceId(userId);
    final deviceId = int.tryParse(deviceIdStr ?? '1') ?? 1;

    // Notre Sender Key — et seulement si elle a été distribuée.
    //
    // ⚠️ Il y avait ici `senderKey ??= await createSenderKey(groupId)`. L'envoi
    // fabriquait donc une clé à la volée et chiffrait avec, SANS la remettre à
    // personne : le message était illisible par tout le groupe, définitivement.
    // Pas rattrapable après coup non plus — `decryptWithSenderKey` refuse un
    // index de chaîne passé, et le ratchet avance à l'émission, donc distribuer
    // ensuite arrive toujours trop tard d'un cran.
    //
    // Rendre `null` fait retomber `MessageCryptoService.encryptGroup` sur le
    // repli AES, que son propre commentaire annonçait déjà (« AES-GCM fallback
    // for groups without established Sender Keys ») mais que cette ligne
    // rendait inatteignable. Le message est alors lisible par tout le monde, et
    // la distribution lancée à l'ouverture de la conversation fait passer les
    // suivants en vrai chiffrement de groupe.
    final senderKey = await _storage.getSenderKey(groupId, userId, deviceId);
    if (senderKey == null || !senderKey.isDistributed) {
      debugPrint(
        'SenderKeyService: pas de Sender Key distribuée pour $groupId — repli AES',
      );
      return null;
    }

    // Dériver la clé de message à partir de la chain key
    final messageKey = await _deriveMessageKey(senderKey.chainKey, senderKey.chainIndex);

    // Chiffrer le message avec AES-GCM
    final plaintextBytes = utf8.encode(plaintext);
    final secretBox = await _aesGcm.encrypt(
      plaintextBytes,
      secretKey: SecretKey(messageKey),
    );

    // Construire le ciphertext
    final ciphertext = Uint8List.fromList([
      ...secretBox.nonce,
      ...secretBox.cipherText,
      ...secretBox.mac.bytes,
    ]);

    // Avancer la chaîne (ratchet)
    final newChainKey = await _ratchetChainKey(senderKey.chainKey);
    final newSenderKey = senderKey.copyWith(
      chainKey: newChainKey,
      chainIndex: senderKey.chainIndex + 1,
    );
    await _storage.storeSenderKey(newSenderKey);

    return SenderKeyEncryptedMessage(
      groupId: groupId,
      senderId: userId,
      senderDeviceId: deviceId,
      keyId: senderKey.keyId,
      chainIndex: senderKey.chainIndex,
      ciphertext: base64Encode(ciphertext),
      createdAt: DateTime.now(),
    );
  }

  /// Déchiffre un message avec la Sender Key de l'expéditeur
  Future<String?> decryptWithSenderKey(
    String groupId,
    String senderId,
    int senderDeviceId,
    SenderKeyEncryptedMessage encryptedMessage,
  ) async {
    try {
      // Récupérer la Sender Key de l'expéditeur
      var senderKey = await _storage.getSenderKey(groupId, senderId, senderDeviceId);

      if (senderKey == null) {
        debugPrint('SenderKeyService: No sender key for $senderId in group $groupId');
        return null;
      }

      // Vérifier l'index de chaîne
      if (encryptedMessage.chainIndex < senderKey.chainIndex) {
        debugPrint('SenderKeyService: Message from past chain index, cannot decrypt');
        return null;
      }

      // Avancer la chaîne si nécessaire pour rattraper l'index du message
      var chainKey = senderKey.chainKey;
      var currentIndex = senderKey.chainIndex;

      while (currentIndex < encryptedMessage.chainIndex) {
        chainKey = await _ratchetChainKey(chainKey);
        currentIndex++;
      }

      // Dériver la clé de message
      final messageKey = await _deriveMessageKey(chainKey, encryptedMessage.chainIndex);

      // Décoder le ciphertext
      final ciphertextFull = base64Decode(encryptedMessage.ciphertext);

      // Extraire nonce (12 bytes), ciphertext, et MAC (16 bytes)
      final nonce = ciphertextFull.sublist(0, 12);
      final ciphertextWithMac = ciphertextFull.sublist(12);
      final ciphertext = ciphertextWithMac.sublist(0, ciphertextWithMac.length - 16);
      final mac = ciphertextWithMac.sublist(ciphertextWithMac.length - 16);

      // Déchiffrer avec AES-GCM
      final secretBox = SecretBox(
        ciphertext,
        nonce: nonce,
        mac: Mac(mac),
      );

      final plaintextBytes = await _aesGcm.decrypt(
        secretBox,
        secretKey: SecretKey(messageKey),
      );

      // Mettre à jour la Sender Key avec le nouvel index
      final newSenderKey = senderKey.copyWith(
        chainKey: await _ratchetChainKey(chainKey),
        chainIndex: encryptedMessage.chainIndex + 1,
      );
      await _storage.storeSenderKey(newSenderKey);

      return utf8.decode(plaintextBytes);
    } catch (e) {
      debugPrint('SenderKeyService: Error decrypting with sender key: $e');
      return null;
    }
  }

  /// Dérive une clé de message à partir de la chain key
  Future<Uint8List> _deriveMessageKey(Uint8List chainKey, int index) async {
    final messageKey = await _hkdf.deriveKey(
      secretKey: SecretKey(chainKey),
      nonce: Uint8List.fromList(utf8.encode('msg_$index')),
      info: _senderKeyInfo,
    );
    return Uint8List.fromList(await messageKey.extractBytes());
  }

  /// Avance la chain key (ratchet)
  Future<Uint8List> _ratchetChainKey(Uint8List chainKey) async {
    final hmac = Hmac.sha256();
    final mac = await hmac.calculateMac(
      utf8.encode('chain_ratchet'),
      secretKey: SecretKey(chainKey),
    );
    return Uint8List.fromList(mac.bytes);
  }

  // ============================================================
  // ROTATION DES SENDER KEYS
  // ============================================================

  /// Effectue la rotation de notre Sender Key (quand un membre quitte le groupe)
  Future<void> rotateSenderKey(String groupId, List<String> currentMemberIds) async {
    final userId = _e2eeService.currentUserId;
    if (userId == null) return;

    debugPrint('SenderKeyService: Rotating sender key for group $groupId');

    // Supprimer l'ancienne Sender Key
    final deviceIdStr = await _storage.getDeviceId(userId);
    final deviceId = int.tryParse(deviceIdStr ?? '1') ?? 1;
    await _storage.deleteSenderKey(groupId, userId, deviceId);

    // Créer une nouvelle Sender Key
    await createSenderKey(groupId);

    // Distribuer la nouvelle clé à tous les membres actuels
    await distributeSenderKeyToGroup(groupId, currentMemberIds);

    debugPrint('SenderKeyService: Sender key rotated and distributed');
  }

  /// Supprime toutes les Sender Keys d'un groupe (quand on quitte le groupe)
  Future<void> leaveGroup(String groupId) async {
    await _storage.deleteAllSenderKeysForGroup(groupId);
    debugPrint('SenderKeyService: Left group $groupId, cleared all sender keys');
  }

  // ============================================================
  // RÉCUPÉRATION DES SENDER KEYS MANQUANTES
  // ============================================================

  /// Récupère les distributions de Sender Keys depuis Supabase
  Future<void> fetchPendingDistributions(String groupId) async {
    final userId = _e2eeService.currentUserId;
    if (userId == null) return;

    try {
      final rows = await _supabase
          .from('e2ee_sender_key_distributions')
          .select()
          .eq('group_id', groupId)
          .eq('recipient_id', userId);

      for (final row in rows) {
        final encryptedDistribution = row['encrypted_distribution'] as String;
        final senderId = row['sender_id'] as String;
        final rowId = row['id'] as String;

        final encryptedMessage = E2EEEncryptedMessage.fromFirebaseString(encryptedDistribution);
        final decrypted = await _e2eeService.decryptMessage(senderId, encryptedMessage);

        if (decrypted != null) {
          final distribution = jsonDecode(decrypted) as Map<String, dynamic>;
          await processDistributionMessage(
            senderId,
            row['sender_device_id'] as int,
            distribution,
          );

          // Supprimer la distribution traitée
          await _supabase
              .from('e2ee_sender_key_distributions')
              .delete()
              .eq('id', rowId);
        }
      }
    } catch (e) {
      debugPrint('SenderKeyService: Error fetching distributions: $e');
    }
  }

  /// Vérifie si on a la Sender Key d'un expéditeur pour un groupe
  Future<bool> hasSenderKey(String groupId, String senderId, int senderDeviceId) async {
    final senderKey = await _storage.getSenderKey(groupId, senderId, senderDeviceId);
    return senderKey != null;
  }
}

/// Message chiffré avec Sender Key
class SenderKeyEncryptedMessage {
  final String groupId;
  final String senderId;
  final int senderDeviceId;
  final int keyId;
  final int chainIndex;
  final String ciphertext;
  final DateTime createdAt;

  const SenderKeyEncryptedMessage({
    required this.groupId,
    required this.senderId,
    required this.senderDeviceId,
    required this.keyId,
    required this.chainIndex,
    required this.ciphertext,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'groupId': groupId,
        'senderId': senderId,
        'senderDeviceId': senderDeviceId,
        'keyId': keyId,
        'chainIndex': chainIndex,
        'ciphertext': ciphertext,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };

  factory SenderKeyEncryptedMessage.fromJson(Map<String, dynamic> json) {
    return SenderKeyEncryptedMessage(
      groupId: json['groupId'] as String,
      senderId: json['senderId'] as String,
      senderDeviceId: json['senderDeviceId'] as int,
      keyId: json['keyId'] as int,
      chainIndex: json['chainIndex'] as int,
      ciphertext: json['ciphertext'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
    );
  }

  String toFirebaseString() => base64Encode(utf8.encode(jsonEncode(toJson())));

  static SenderKeyEncryptedMessage fromFirebaseString(String encoded) {
    final json = jsonDecode(utf8.decode(base64Decode(encoded)));
    return SenderKeyEncryptedMessage.fromJson(json as Map<String, dynamic>);
  }
}
