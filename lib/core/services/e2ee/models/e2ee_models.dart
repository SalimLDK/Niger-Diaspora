import 'dart:convert';
import 'dart:typed_data';

/// Types de messages chiffrés selon le Signal Protocol
enum E2EEMessageType {
  /// Premier message d'une session (contient les informations X3DH)
  preKeyMessage(1),

  /// Messages suivants (Double Ratchet)
  whisperMessage(2),

  /// Message de distribution de Sender Key (pour les groupes)
  senderKeyDistribution(3),

  /// Message chiffré avec Sender Key (groupes)
  senderKeyMessage(4);

  const E2EEMessageType(this.value);
  final int value;

  static E2EEMessageType fromValue(int value) {
    return E2EEMessageType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => E2EEMessageType.whisperMessage,
    );
  }
}

/// Message chiffré E2EE pour transmission
class E2EEEncryptedMessage {
  /// Type de message (preKey ou whisper)
  final E2EEMessageType messageType;

  /// ID de l'appareil expéditeur
  final int senderDeviceId;

  /// Registration ID de l'expéditeur
  final int senderRegistrationId;

  /// Clé publique d'identité de l'expéditeur (base64)
  final String senderIdentityKey;

  /// Contenu chiffré (base64)
  final String ciphertext;

  /// Clé éphémère publique de l'expéditeur (base64, uniquement pour preKeyMessage)
  final String? senderEphemeralKey;

  /// Version du protocole
  final int protocolVersion;

  /// Timestamp de création
  final DateTime createdAt;

  const E2EEEncryptedMessage({
    required this.messageType,
    required this.senderDeviceId,
    required this.senderRegistrationId,
    required this.senderIdentityKey,
    required this.ciphertext,
    this.senderEphemeralKey,
    this.protocolVersion = 1,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'messageType': messageType.value,
        'senderDeviceId': senderDeviceId,
        'senderRegistrationId': senderRegistrationId,
        'senderIdentityKey': senderIdentityKey,
        'ciphertext': ciphertext,
        if (senderEphemeralKey != null) 'senderEphemeralKey': senderEphemeralKey,
        'protocolVersion': protocolVersion,
        'createdAt': createdAt.toIso8601String(),
      };

  factory E2EEEncryptedMessage.fromJson(Map<String, dynamic> json) {
    return E2EEEncryptedMessage(
      messageType: E2EEMessageType.fromValue(json['messageType'] as int),
      senderDeviceId: json['senderDeviceId'] as int,
      senderRegistrationId: json['senderRegistrationId'] as int,
      senderIdentityKey: json['senderIdentityKey'] as String,
      ciphertext: json['ciphertext'] as String,
      senderEphemeralKey: json['senderEphemeralKey'] as String?,
      protocolVersion: json['protocolVersion'] as int? ?? 1,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  /// Encode le message pour stockage dans Firebase
  String toFirebaseString() => base64Encode(utf8.encode(jsonEncode(toJson())));

  /// Decode un message depuis Firebase
  static E2EEEncryptedMessage fromFirebaseString(String encoded) {
    final json = jsonDecode(utf8.decode(base64Decode(encoded)));
    return E2EEEncryptedMessage.fromJson(json as Map<String, dynamic>);
  }
}

/// Paire de clés d'identité (Identity Key Pair)
class E2EEIdentityKeyPair {
  /// Clé publique (32 bytes, Curve25519)
  final Uint8List publicKey;

  /// Clé privée (32 bytes, Curve25519)
  final Uint8List privateKey;

  const E2EEIdentityKeyPair({
    required this.publicKey,
    required this.privateKey,
  });

  String get publicKeyBase64 => base64Encode(publicKey);
  String get privateKeyBase64 => base64Encode(privateKey);

  Map<String, dynamic> toJson() => {
        'publicKey': publicKeyBase64,
        'privateKey': privateKeyBase64,
      };

  factory E2EEIdentityKeyPair.fromJson(Map<String, dynamic> json) {
    return E2EEIdentityKeyPair(
      publicKey: base64Decode(json['publicKey'] as String),
      privateKey: base64Decode(json['privateKey'] as String),
    );
  }
}

/// Signed Pre-Key (clé pré-signée)
class E2EESignedPreKey {
  /// ID unique de la clé
  final int keyId;

  /// Clé publique (32 bytes)
  final Uint8List publicKey;

  /// Clé privée (32 bytes)
  final Uint8List privateKey;

  /// Signature de la clé publique par l'Identity Key
  final Uint8List signature;

  /// Timestamp de création
  final DateTime createdAt;

  const E2EESignedPreKey({
    required this.keyId,
    required this.publicKey,
    required this.privateKey,
    required this.signature,
    required this.createdAt,
  });

  String get publicKeyBase64 => base64Encode(publicKey);
  String get privateKeyBase64 => base64Encode(privateKey);
  String get signatureBase64 => base64Encode(signature);

  Map<String, dynamic> toJson() => {
        'keyId': keyId,
        'publicKey': publicKeyBase64,
        'privateKey': privateKeyBase64,
        'signature': signatureBase64,
        'createdAt': createdAt.toIso8601String(),
      };

  factory E2EESignedPreKey.fromJson(Map<String, dynamic> json) {
    return E2EESignedPreKey(
      keyId: json['keyId'] as int,
      publicKey: base64Decode(json['publicKey'] as String),
      privateKey: base64Decode(json['privateKey'] as String),
      signature: base64Decode(json['signature'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  /// Version publique pour publication sur Firebase
  Map<String, dynamic> toPublicJson() => {
        'keyId': keyId,
        'publicKey': publicKeyBase64,
        'signature': signatureBase64,
        'createdAt': createdAt.toIso8601String(),
      };
}

/// One-Time Pre-Key (clé à usage unique)
class E2EEOneTimePreKey {
  /// ID unique de la clé
  final int keyId;

  /// Clé publique (32 bytes)
  final Uint8List publicKey;

  /// Clé privée (32 bytes)
  final Uint8List privateKey;

  const E2EEOneTimePreKey({
    required this.keyId,
    required this.publicKey,
    required this.privateKey,
  });

  String get publicKeyBase64 => base64Encode(publicKey);
  String get privateKeyBase64 => base64Encode(privateKey);

  Map<String, dynamic> toJson() => {
        'keyId': keyId,
        'publicKey': publicKeyBase64,
        'privateKey': privateKeyBase64,
      };

  factory E2EEOneTimePreKey.fromJson(Map<String, dynamic> json) {
    return E2EEOneTimePreKey(
      keyId: json['keyId'] as int,
      publicKey: base64Decode(json['publicKey'] as String),
      privateKey: base64Decode(json['privateKey'] as String),
    );
  }

  /// Version publique pour publication sur Firebase
  Map<String, dynamic> toPublicJson() => {
        'keyId': keyId,
        'publicKey': publicKeyBase64,
      };
}

/// Pre-Key Bundle pour établir une session (publié sur Firebase)
class E2EEPreKeyBundle {
  /// ID de l'utilisateur
  final String userId;

  /// ID de l'appareil
  final int deviceId;

  /// Registration ID
  final int registrationId;

  /// Identity Key publique
  final String identityKey;

  /// Signed Pre-Key
  final int signedPreKeyId;
  final String signedPreKeyPublic;
  final String signedPreKeySignature;

  /// One-Time Pre-Key (optionnel, peut être null si épuisées)
  final int? oneTimePreKeyId;
  final String? oneTimePreKeyPublic;

  const E2EEPreKeyBundle({
    required this.userId,
    required this.deviceId,
    required this.registrationId,
    required this.identityKey,
    required this.signedPreKeyId,
    required this.signedPreKeyPublic,
    required this.signedPreKeySignature,
    this.oneTimePreKeyId,
    this.oneTimePreKeyPublic,
  });

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'deviceId': deviceId,
        'registrationId': registrationId,
        'identityKey': identityKey,
        'signedPreKeyId': signedPreKeyId,
        'signedPreKeyPublic': signedPreKeyPublic,
        'signedPreKeySignature': signedPreKeySignature,
        if (oneTimePreKeyId != null) 'oneTimePreKeyId': oneTimePreKeyId,
        if (oneTimePreKeyPublic != null)
          'oneTimePreKeyPublic': oneTimePreKeyPublic,
      };

  factory E2EEPreKeyBundle.fromJson(Map<String, dynamic> json) {
    return E2EEPreKeyBundle(
      userId: json['userId'] as String,
      deviceId: json['deviceId'] as int,
      registrationId: json['registrationId'] as int,
      identityKey: json['identityKey'] as String,
      signedPreKeyId: json['signedPreKeyId'] as int,
      signedPreKeyPublic: json['signedPreKeyPublic'] as String,
      signedPreKeySignature: json['signedPreKeySignature'] as String,
      oneTimePreKeyId: json['oneTimePreKeyId'] as int?,
      oneTimePreKeyPublic: json['oneTimePreKeyPublic'] as String?,
    );
  }

  bool get hasOneTimePreKey =>
      oneTimePreKeyId != null && oneTimePreKeyPublic != null;
}

/// Informations sur un appareil
class E2EEDeviceInfo {
  final String deviceId;
  final String deviceName;
  final String platform;
  final String identityKeyPublic;
  final DateTime createdAt;
  final DateTime lastActive;

  const E2EEDeviceInfo({
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    required this.identityKeyPublic,
    required this.createdAt,
    required this.lastActive,
  });

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'deviceName': deviceName,
        'platform': platform,
        'identityKeyPublic': identityKeyPublic,
        'createdAt': createdAt.toIso8601String(),
        'lastActive': lastActive.toIso8601String(),
      };

  factory E2EEDeviceInfo.fromJson(Map<String, dynamic> json) {
    return E2EEDeviceInfo(
      deviceId: json['deviceId'] as String,
      deviceName: json['deviceName'] as String,
      platform: json['platform'] as String,
      identityKeyPublic: json['identityKeyPublic'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastActive: DateTime.parse(json['lastActive'] as String),
    );
  }
}

/// État d'une session E2EE avec un destinataire
class E2EESessionState {
  /// ID du destinataire
  final String recipientId;

  /// ID de l'appareil du destinataire
  final int recipientDeviceId;

  /// Chaîne racine (root key) - 32 bytes
  final Uint8List rootKey;

  /// Chaîne d'envoi (sending chain key) - 32 bytes
  final Uint8List? sendingChainKey;

  /// Chaîne de réception (receiving chain key) - 32 bytes
  final Uint8List? receivingChainKey;

  /// Index du message d'envoi
  final int sendingMessageIndex;

  /// Index du message de réception
  final int receivingMessageIndex;

  /// Clé publique de ratchet distante
  final Uint8List? remoteRatchetKey;

  /// Paire de clés de ratchet locale
  final Uint8List? localRatchetPublicKey;
  final Uint8List? localRatchetPrivateKey;

  /// Numéro du ratchet précédent (pour gérer les messages hors ordre)
  final int previousCounter;

  const E2EESessionState({
    required this.recipientId,
    required this.recipientDeviceId,
    required this.rootKey,
    this.sendingChainKey,
    this.receivingChainKey,
    this.sendingMessageIndex = 0,
    this.receivingMessageIndex = 0,
    this.remoteRatchetKey,
    this.localRatchetPublicKey,
    this.localRatchetPrivateKey,
    this.previousCounter = 0,
  });

  Map<String, dynamic> toJson() => {
        'recipientId': recipientId,
        'recipientDeviceId': recipientDeviceId,
        'rootKey': base64Encode(rootKey),
        if (sendingChainKey != null)
          'sendingChainKey': base64Encode(sendingChainKey!),
        if (receivingChainKey != null)
          'receivingChainKey': base64Encode(receivingChainKey!),
        'sendingMessageIndex': sendingMessageIndex,
        'receivingMessageIndex': receivingMessageIndex,
        if (remoteRatchetKey != null)
          'remoteRatchetKey': base64Encode(remoteRatchetKey!),
        if (localRatchetPublicKey != null)
          'localRatchetPublicKey': base64Encode(localRatchetPublicKey!),
        if (localRatchetPrivateKey != null)
          'localRatchetPrivateKey': base64Encode(localRatchetPrivateKey!),
        'previousCounter': previousCounter,
      };

  factory E2EESessionState.fromJson(Map<String, dynamic> json) {
    return E2EESessionState(
      recipientId: json['recipientId'] as String,
      recipientDeviceId: json['recipientDeviceId'] as int,
      rootKey: base64Decode(json['rootKey'] as String),
      sendingChainKey: json['sendingChainKey'] != null
          ? base64Decode(json['sendingChainKey'] as String)
          : null,
      receivingChainKey: json['receivingChainKey'] != null
          ? base64Decode(json['receivingChainKey'] as String)
          : null,
      sendingMessageIndex: json['sendingMessageIndex'] as int? ?? 0,
      receivingMessageIndex: json['receivingMessageIndex'] as int? ?? 0,
      remoteRatchetKey: json['remoteRatchetKey'] != null
          ? base64Decode(json['remoteRatchetKey'] as String)
          : null,
      localRatchetPublicKey: json['localRatchetPublicKey'] != null
          ? base64Decode(json['localRatchetPublicKey'] as String)
          : null,
      localRatchetPrivateKey: json['localRatchetPrivateKey'] != null
          ? base64Decode(json['localRatchetPrivateKey'] as String)
          : null,
      previousCounter: json['previousCounter'] as int? ?? 0,
    );
  }

  E2EESessionState copyWith({
    Uint8List? rootKey,
    Uint8List? sendingChainKey,
    Uint8List? receivingChainKey,
    int? sendingMessageIndex,
    int? receivingMessageIndex,
    Uint8List? remoteRatchetKey,
    Uint8List? localRatchetPublicKey,
    Uint8List? localRatchetPrivateKey,
    int? previousCounter,
  }) {
    return E2EESessionState(
      recipientId: recipientId,
      recipientDeviceId: recipientDeviceId,
      rootKey: rootKey ?? this.rootKey,
      sendingChainKey: sendingChainKey ?? this.sendingChainKey,
      receivingChainKey: receivingChainKey ?? this.receivingChainKey,
      sendingMessageIndex: sendingMessageIndex ?? this.sendingMessageIndex,
      receivingMessageIndex:
          receivingMessageIndex ?? this.receivingMessageIndex,
      remoteRatchetKey: remoteRatchetKey ?? this.remoteRatchetKey,
      localRatchetPublicKey:
          localRatchetPublicKey ?? this.localRatchetPublicKey,
      localRatchetPrivateKey:
          localRatchetPrivateKey ?? this.localRatchetPrivateKey,
      previousCounter: previousCounter ?? this.previousCounter,
    );
  }
}

/// Sender Key pour les groupes (Signal Sender Keys protocol)
class E2EESenderKey {
  /// ID du groupe
  final String groupId;

  /// ID de l'expéditeur (propriétaire de cette Sender Key)
  final String senderId;

  /// ID de l'appareil de l'expéditeur
  final int senderDeviceId;

  /// ID de la Sender Key
  final int keyId;

  /// Clé de chaîne (pour dériver les clés de message)
  final Uint8List chainKey;

  /// Clé publique de signature
  final Uint8List signatureKeyPublic;

  /// Clé privée de signature (seulement pour le propriétaire)
  final Uint8List? signatureKeyPrivate;

  /// Index de la chaîne (incrémenté à chaque message)
  final int chainIndex;

  const E2EESenderKey({
    required this.groupId,
    required this.senderId,
    required this.senderDeviceId,
    required this.keyId,
    required this.chainKey,
    required this.signatureKeyPublic,
    this.signatureKeyPrivate,
    this.chainIndex = 0,
  });

  Map<String, dynamic> toJson() => {
        'groupId': groupId,
        'senderId': senderId,
        'senderDeviceId': senderDeviceId,
        'keyId': keyId,
        'chainKey': base64Encode(chainKey),
        'signatureKeyPublic': base64Encode(signatureKeyPublic),
        if (signatureKeyPrivate != null)
          'signatureKeyPrivate': base64Encode(signatureKeyPrivate!),
        'chainIndex': chainIndex,
      };

  factory E2EESenderKey.fromJson(Map<String, dynamic> json) {
    return E2EESenderKey(
      groupId: json['groupId'] as String,
      senderId: json['senderId'] as String,
      senderDeviceId: json['senderDeviceId'] as int,
      keyId: json['keyId'] as int,
      chainKey: base64Decode(json['chainKey'] as String),
      signatureKeyPublic: base64Decode(json['signatureKeyPublic'] as String),
      signatureKeyPrivate: json['signatureKeyPrivate'] != null
          ? base64Decode(json['signatureKeyPrivate'] as String)
          : null,
      chainIndex: json['chainIndex'] as int? ?? 0,
    );
  }

  E2EESenderKey copyWith({
    Uint8List? chainKey,
    int? chainIndex,
  }) {
    return E2EESenderKey(
      groupId: groupId,
      senderId: senderId,
      senderDeviceId: senderDeviceId,
      keyId: keyId,
      chainKey: chainKey ?? this.chainKey,
      signatureKeyPublic: signatureKeyPublic,
      signatureKeyPrivate: signatureKeyPrivate,
      chainIndex: chainIndex ?? this.chainIndex,
    );
  }
}

/// Backup chiffré des clés
class E2EEEncryptedBackup {
  /// Version du format de backup
  final int version;

  /// Salt pour la dérivation de clé (32 bytes)
  final String saltBase64;

  /// IV pour le chiffrement (12 bytes pour AES-GCM)
  final String ivBase64;

  /// Données chiffrées
  final String ciphertextBase64;

  /// Tag d'authentification (16 bytes)
  final String authTagBase64;

  /// Informations sur l'appareil source
  final String deviceInfo;

  /// Timestamp de création
  final DateTime createdAt;

  const E2EEEncryptedBackup({
    required this.version,
    required this.saltBase64,
    required this.ivBase64,
    required this.ciphertextBase64,
    required this.authTagBase64,
    required this.deviceInfo,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'version': version,
        'salt': saltBase64,
        'iv': ivBase64,
        'ciphertext': ciphertextBase64,
        'authTag': authTagBase64,
        'deviceInfo': deviceInfo,
        'createdAt': createdAt.toIso8601String(),
      };

  factory E2EEEncryptedBackup.fromJson(Map<String, dynamic> json) {
    return E2EEEncryptedBackup(
      version: json['version'] as int,
      saltBase64: json['salt'] as String,
      ivBase64: json['iv'] as String,
      ciphertextBase64: json['ciphertext'] as String,
      authTagBase64: json['authTag'] as String,
      deviceInfo: json['deviceInfo'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
