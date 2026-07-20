import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Provider pour le service de chiffrement des médias
final mediaEncryptionServiceProvider = Provider<MediaEncryptionService>((ref) {
  return MediaEncryptionService();
});

/// Service de chiffrement des fichiers médias (images, audio, vidéo, documents)
///
/// Chaque fichier est chiffré avec une clé AES-256-GCM unique.
/// Cette clé est ensuite incluse dans le message E2EE (chiffrée avec
/// le protocole Signal pour chaque destinataire).
///
/// Flow:
/// 1. Générer une clé AES-256 aléatoire pour le fichier
/// 2. Chiffrer le fichier avec AES-256-GCM
/// 3. Uploader le fichier chiffré sur Firebase Storage
/// 4. Retourner la clé + metadata pour inclusion dans le message E2EE
///
/// Le serveur ne peut pas déchiffrer les fichiers car il n'a pas la clé.
class MediaEncryptionService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final _aesGcm = AesGcm.with256bits();
  final _random = Random.secure();

  // Taille du chunk pour le chiffrement par blocs (5 MB)
  static const int _chunkSize = 5 * 1024 * 1024;

  // ============================================================
  // CHIFFREMENT DE FICHIERS
  // ============================================================

  /// Chiffre un fichier et l'uploade sur Firebase Storage
  ///
  /// [file] - Le fichier à chiffrer
  /// [conversationId] - ID de la conversation (pour le path de stockage)
  /// [senderId] - ID de l'expéditeur
  /// [mediaType] - Type de média (image, audio, video, document)
  ///
  /// Returns: Les métadonnées du fichier chiffré (incluant la clé)
  Future<EncryptedMediaResult> encryptAndUploadFile({
    required File file,
    required String conversationId,
    required String senderId,
    required MediaType mediaType,
  }) async {
    // Générer une clé AES-256 aléatoire pour ce fichier
    final fileKey = await _generateFileKey();
    final fileKeyBytes = await fileKey.extractBytes();

    // Lire le fichier
    final fileBytes = await file.readAsBytes();
    final originalSize = fileBytes.length;

    // Générer un IV aléatoire
    final iv = _generateRandomBytes(12); // 96 bits pour GCM

    // Chiffrer le fichier
    Uint8List encryptedBytes;
    if (originalSize > _chunkSize) {
      // Fichier volumineux: chiffrer par chunks
      encryptedBytes = await _encryptLargeFile(fileBytes, fileKey, iv);
    } else {
      // Petit fichier: chiffrer en une fois
      final secretBox = await _aesGcm.encrypt(
        fileBytes,
        secretKey: fileKey,
        nonce: iv,
      );
      // Combiner ciphertext + authTag
      encryptedBytes = Uint8List.fromList([
        ...secretBox.cipherText,
        ...secretBox.mac.bytes,
      ]);
    }

    // Générer un nom de fichier unique (sans révéler le nom original)
    final encryptedFileName = _generateEncryptedFileName(mediaType);
    final storagePath = 'encrypted_media/$conversationId/$senderId/$encryptedFileName';

    // Uploader sur Firebase Storage
    final ref = _storage.ref(storagePath);
    final uploadTask = await ref.putData(
      encryptedBytes,
      SettableMetadata(
        contentType: 'application/octet-stream', // Masquer le vrai type
        customMetadata: {
          'encrypted': 'true',
          'version': '1',
        },
      ),
    );

    final downloadUrl = await uploadTask.ref.getDownloadURL();

    debugPrint('MediaEncryptionService: Uploaded encrypted file to $storagePath');

    return EncryptedMediaResult(
      encryptedUrl: downloadUrl,
      storagePath: storagePath,
      fileKeyBase64: base64Encode(fileKeyBytes),
      ivBase64: base64Encode(iv),
      originalFileName: path.basename(file.path),
      originalSize: originalSize,
      encryptedSize: encryptedBytes.length,
      mediaType: mediaType,
      mimeType: _getMimeType(file.path),
    );
  }

  /// Chiffre un fichier volumineux par chunks
  Future<Uint8List> _encryptLargeFile(
    Uint8List fileBytes,
    SecretKey fileKey,
    Uint8List iv,
  ) async {
    final chunks = <Uint8List>[];
    var offset = 0;
    var chunkIndex = 0;

    while (offset < fileBytes.length) {
      final end = (offset + _chunkSize).clamp(0, fileBytes.length);
      final chunk = fileBytes.sublist(offset, end);

      // IV unique par chunk: IV original + index du chunk
      final chunkIv = _deriveChunkIv(iv, chunkIndex);

      final secretBox = await _aesGcm.encrypt(
        chunk,
        secretKey: fileKey,
        nonce: chunkIv,
      );

      // Format: [4 bytes chunk size][ciphertext][16 bytes authTag]
      final chunkSize = secretBox.cipherText.length + 16;
      final chunkData = Uint8List(4 + chunkSize);
      // Écrire la taille du chunk (big-endian)
      chunkData[0] = (chunkSize >> 24) & 0xFF;
      chunkData[1] = (chunkSize >> 16) & 0xFF;
      chunkData[2] = (chunkSize >> 8) & 0xFF;
      chunkData[3] = chunkSize & 0xFF;
      // Écrire le ciphertext + authTag
      chunkData.setRange(4, 4 + secretBox.cipherText.length, secretBox.cipherText);
      chunkData.setRange(
        4 + secretBox.cipherText.length,
        4 + chunkSize,
        secretBox.mac.bytes,
      );

      chunks.add(chunkData);
      offset = end;
      chunkIndex++;
    }

    // Header: [1 byte version][4 bytes total chunks]
    final header = Uint8List(5);
    header[0] = 1; // Version
    header[1] = (chunkIndex >> 24) & 0xFF;
    header[2] = (chunkIndex >> 16) & 0xFF;
    header[3] = (chunkIndex >> 8) & 0xFF;
    header[4] = chunkIndex & 0xFF;

    // Combiner header + tous les chunks
    final totalSize = 5 + chunks.fold<int>(0, (sum, chunk) => sum + chunk.length);
    final result = Uint8List(totalSize);
    result.setRange(0, 5, header);

    var writeOffset = 5;
    for (final chunk in chunks) {
      result.setRange(writeOffset, writeOffset + chunk.length, chunk);
      writeOffset += chunk.length;
    }

    return result;
  }

  /// Dérive un IV unique pour chaque chunk
  Uint8List _deriveChunkIv(Uint8List baseIv, int chunkIndex) {
    final chunkIv = Uint8List.fromList(baseIv);
    // XOR les derniers 4 bytes avec l'index du chunk
    chunkIv[8] ^= (chunkIndex >> 24) & 0xFF;
    chunkIv[9] ^= (chunkIndex >> 16) & 0xFF;
    chunkIv[10] ^= (chunkIndex >> 8) & 0xFF;
    chunkIv[11] ^= chunkIndex & 0xFF;
    return chunkIv;
  }

  // ============================================================
  // DÉCHIFFREMENT DE FICHIERS
  // ============================================================

  /// Télécharge et déchiffre un fichier
  ///
  /// [mediaInfo] - Les métadonnées du fichier chiffré (reçues dans le message)
  ///
  /// Returns: Le fichier déchiffré (temporaire)
  Future<File> downloadAndDecryptFile(EncryptedMediaInfo mediaInfo) async {
    // Télécharger le fichier chiffré
    final ref = _storage.ref(mediaInfo.storagePath);
    final encryptedBytes = await ref.getData();

    if (encryptedBytes == null) {
      throw MediaDecryptionException('Failed to download encrypted file');
    }

    // Décoder la clé et l'IV
    final fileKeyBytes = base64Decode(mediaInfo.fileKeyBase64);
    final iv = base64Decode(mediaInfo.ivBase64);
    final fileKey = SecretKey(fileKeyBytes);

    // Déchiffrer
    Uint8List decryptedBytes;
    if (encryptedBytes[0] == 1 && encryptedBytes.length > 5) {
      // Format chunked (version 1)
      decryptedBytes = await _decryptLargeFile(encryptedBytes, fileKey, iv);
    } else {
      // Format simple
      final authTagStart = encryptedBytes.length - 16;
      final cipherText = encryptedBytes.sublist(0, authTagStart);
      final authTag = encryptedBytes.sublist(authTagStart);

      final secretBox = SecretBox(
        cipherText,
        nonce: iv,
        mac: Mac(authTag),
      );

      try {
        decryptedBytes = Uint8List.fromList(
          await _aesGcm.decrypt(secretBox, secretKey: fileKey),
        );
      } catch (e) {
        throw MediaDecryptionException('Failed to decrypt file: invalid key or corrupted data');
      }
    }

    // Sauvegarder dans un fichier temporaire
    final tempDir = await getTemporaryDirectory();
    final extension = _getExtensionFromMimeType(mediaInfo.mimeType);
    final tempFile = File('${tempDir.path}/decrypted_${DateTime.now().millisecondsSinceEpoch}$extension');
    await tempFile.writeAsBytes(decryptedBytes);

    debugPrint('MediaEncryptionService: Decrypted file to ${tempFile.path}');
    return tempFile;
  }

  /// Déchiffre un fichier volumineux par chunks
  Future<Uint8List> _decryptLargeFile(
    Uint8List encryptedBytes,
    SecretKey fileKey,
    Uint8List iv,
  ) async {
    // Lire le header
    final version = encryptedBytes[0];
    if (version != 1) {
      throw MediaDecryptionException('Unsupported encryption version: $version');
    }

    final totalChunks = (encryptedBytes[1] << 24) |
        (encryptedBytes[2] << 16) |
        (encryptedBytes[3] << 8) |
        encryptedBytes[4];

    final decryptedChunks = <Uint8List>[];
    var readOffset = 5;

    for (var chunkIndex = 0; chunkIndex < totalChunks; chunkIndex++) {
      // Lire la taille du chunk
      final chunkSize = (encryptedBytes[readOffset] << 24) |
          (encryptedBytes[readOffset + 1] << 16) |
          (encryptedBytes[readOffset + 2] << 8) |
          encryptedBytes[readOffset + 3];
      readOffset += 4;

      // Lire le chunk
      final chunkData = encryptedBytes.sublist(readOffset, readOffset + chunkSize);
      readOffset += chunkSize;

      // Séparer ciphertext et authTag
      final cipherText = chunkData.sublist(0, chunkData.length - 16);
      final authTag = chunkData.sublist(chunkData.length - 16);

      // IV unique pour ce chunk
      final chunkIv = _deriveChunkIv(iv, chunkIndex);

      final secretBox = SecretBox(
        cipherText,
        nonce: chunkIv,
        mac: Mac(authTag),
      );

      try {
        final decrypted = await _aesGcm.decrypt(secretBox, secretKey: fileKey);
        decryptedChunks.add(Uint8List.fromList(decrypted));
      } catch (e) {
        throw MediaDecryptionException('Failed to decrypt chunk $chunkIndex');
      }
    }

    // Combiner tous les chunks
    final totalSize = decryptedChunks.fold<int>(0, (sum, chunk) => sum + chunk.length);
    final result = Uint8List(totalSize);
    var writeOffset = 0;
    for (final chunk in decryptedChunks) {
      result.setRange(writeOffset, writeOffset + chunk.length, chunk);
      writeOffset += chunk.length;
    }

    return result;
  }

  // ============================================================
  // CHIFFREMENT EN MÉMOIRE (pour petits fichiers/thumbnails)
  // ============================================================

  /// Chiffre des bytes en mémoire (pour thumbnails, audio court, etc.)
  Future<EncryptedBytesResult> encryptBytes(Uint8List bytes) async {
    final fileKey = await _generateFileKey();
    final fileKeyBytes = await fileKey.extractBytes();
    final iv = _generateRandomBytes(12);

    final secretBox = await _aesGcm.encrypt(
      bytes,
      secretKey: fileKey,
      nonce: iv,
    );

    return EncryptedBytesResult(
      encryptedBytes: Uint8List.fromList([
        ...secretBox.cipherText,
        ...secretBox.mac.bytes,
      ]),
      keyBase64: base64Encode(fileKeyBytes),
      ivBase64: base64Encode(iv),
    );
  }

  /// Déchiffre des bytes en mémoire
  Future<Uint8List> decryptBytes(
    Uint8List encryptedBytes,
    String keyBase64,
    String ivBase64,
  ) async {
    final fileKey = SecretKey(base64Decode(keyBase64));
    final iv = base64Decode(ivBase64);

    final authTagStart = encryptedBytes.length - 16;
    final cipherText = encryptedBytes.sublist(0, authTagStart);
    final authTag = encryptedBytes.sublist(authTagStart);

    final secretBox = SecretBox(
      cipherText,
      nonce: iv,
      mac: Mac(authTag),
    );

    return Uint8List.fromList(
      await _aesGcm.decrypt(secretBox, secretKey: fileKey),
    );
  }

  // ============================================================
  // SUPPRESSION DE FICHIERS
  // ============================================================

  /// Supprime un fichier chiffré de Firebase Storage
  Future<void> deleteEncryptedFile(String storagePath) async {
    try {
      final ref = _storage.ref(storagePath);
      await ref.delete();
      debugPrint('MediaEncryptionService: Deleted $storagePath');
    } catch (e) {
      debugPrint('MediaEncryptionService: Error deleting file: $e');
    }
  }

  // ============================================================
  // UTILITAIRES
  // ============================================================

  /// Génère une clé AES-256 aléatoire
  Future<SecretKey> _generateFileKey() async {
    return _aesGcm.newSecretKey();
  }

  /// Génère des bytes aléatoires
  Uint8List _generateRandomBytes(int length) {
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return bytes;
  }

  /// Génère un nom de fichier chiffré unique
  String _generateEncryptedFileName(MediaType mediaType) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = _random.nextInt(999999).toString().padLeft(6, '0');
    return '${mediaType.name}_${timestamp}_$random.enc';
  }

  /// Récupère le type MIME d'un fichier
  String _getMimeType(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    switch (ext) {
      // Images
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      case '.heic':
        return 'image/heic';
      // Audio
      case '.mp3':
        return 'audio/mpeg';
      case '.m4a':
        return 'audio/mp4';
      case '.aac':
        return 'audio/aac';
      case '.ogg':
        return 'audio/ogg';
      case '.wav':
        return 'audio/wav';
      // Video
      case '.mp4':
        return 'video/mp4';
      case '.mov':
        return 'video/quicktime';
      case '.avi':
        return 'video/x-msvideo';
      case '.webm':
        return 'video/webm';
      // Documents
      case '.pdf':
        return 'application/pdf';
      case '.doc':
        return 'application/msword';
      case '.docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case '.xls':
        return 'application/vnd.ms-excel';
      case '.xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case '.ppt':
        return 'application/vnd.ms-powerpoint';
      case '.pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case '.txt':
        return 'text/plain';
      case '.zip':
        return 'application/zip';
      default:
        return 'application/octet-stream';
    }
  }

  /// Récupère l'extension depuis le type MIME
  String _getExtensionFromMimeType(String mimeType) {
    switch (mimeType) {
      case 'image/jpeg':
        return '.jpg';
      case 'image/png':
        return '.png';
      case 'image/gif':
        return '.gif';
      case 'image/webp':
        return '.webp';
      case 'image/heic':
        return '.heic';
      case 'audio/mpeg':
        return '.mp3';
      case 'audio/mp4':
        return '.m4a';
      case 'audio/aac':
        return '.aac';
      case 'audio/ogg':
        return '.ogg';
      case 'audio/wav':
        return '.wav';
      case 'video/mp4':
        return '.mp4';
      case 'video/quicktime':
        return '.mov';
      case 'video/x-msvideo':
        return '.avi';
      case 'video/webm':
        return '.webm';
      case 'application/pdf':
        return '.pdf';
      case 'text/plain':
        return '.txt';
      case 'application/zip':
        return '.zip';
      default:
        return '.bin';
    }
  }
}

/// Types de médias supportés
enum MediaType {
  image,
  audio,
  video,
  document,
  voiceNote,
}

/// Résultat du chiffrement et upload d'un fichier
class EncryptedMediaResult {
  /// URL de téléchargement du fichier chiffré
  final String encryptedUrl;

  /// Chemin dans Firebase Storage
  final String storagePath;

  /// Clé de chiffrement du fichier (base64)
  /// Cette clé sera incluse dans le message E2EE
  final String fileKeyBase64;

  /// IV utilisé pour le chiffrement (base64)
  final String ivBase64;

  /// Nom original du fichier
  final String originalFileName;

  /// Taille originale en bytes
  final int originalSize;

  /// Taille chiffrée en bytes
  final int encryptedSize;

  /// Type de média
  final MediaType mediaType;

  /// Type MIME original
  final String mimeType;

  const EncryptedMediaResult({
    required this.encryptedUrl,
    required this.storagePath,
    required this.fileKeyBase64,
    required this.ivBase64,
    required this.originalFileName,
    required this.originalSize,
    required this.encryptedSize,
    required this.mediaType,
    required this.mimeType,
  });

  /// Convertit en Map pour inclusion dans un message E2EE
  Map<String, dynamic> toMessagePayload() {
    return {
      'encryptedUrl': encryptedUrl,
      'storagePath': storagePath,
      'fileKey': fileKeyBase64,
      'iv': ivBase64,
      'fileName': originalFileName,
      'size': originalSize,
      'mediaType': mediaType.name,
      'mimeType': mimeType,
    };
  }
}

/// Informations d'un fichier chiffré (reçues dans un message)
class EncryptedMediaInfo {
  final String encryptedUrl;
  final String storagePath;
  final String fileKeyBase64;
  final String ivBase64;
  final String originalFileName;
  final int originalSize;
  final MediaType mediaType;
  final String mimeType;

  const EncryptedMediaInfo({
    required this.encryptedUrl,
    required this.storagePath,
    required this.fileKeyBase64,
    required this.ivBase64,
    required this.originalFileName,
    required this.originalSize,
    required this.mediaType,
    required this.mimeType,
  });

  factory EncryptedMediaInfo.fromMessagePayload(Map<String, dynamic> payload) {
    return EncryptedMediaInfo(
      encryptedUrl: payload['encryptedUrl'] as String,
      storagePath: payload['storagePath'] as String,
      fileKeyBase64: payload['fileKey'] as String,
      ivBase64: payload['iv'] as String,
      originalFileName: payload['fileName'] as String,
      originalSize: payload['size'] as int,
      mediaType: MediaType.values.firstWhere(
        (t) => t.name == payload['mediaType'],
        orElse: () => MediaType.document,
      ),
      mimeType: payload['mimeType'] as String,
    );
  }
}

/// Résultat du chiffrement en mémoire
class EncryptedBytesResult {
  final Uint8List encryptedBytes;
  final String keyBase64;
  final String ivBase64;

  const EncryptedBytesResult({
    required this.encryptedBytes,
    required this.keyBase64,
    required this.ivBase64,
  });
}

/// Exception pour les erreurs de déchiffrement de médias
class MediaDecryptionException implements Exception {
  final String message;
  MediaDecryptionException(this.message);

  @override
  String toString() => 'MediaDecryptionException: $message';
}
