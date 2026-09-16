import 'dart:async';
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
  /// **Paresseux, et c'est voulu.** En champ immédiat, construire le service
  /// exigeait un Firebase initialisé — ce qui rendait la classe entière
  /// intestable hors appareil, y compris ses parties purement
  /// cryptographiques, qui n'ont rien à voir avec le stockage. Le résultat est
  /// identique à l'exécution : la première lecture a lieu au premier
  /// téléversement ou téléchargement, quand Firebase est là depuis longtemps.
  FirebaseStorage? _storageOptionnel;
  FirebaseStorage get _storage =>
      _storageOptionnel ??= FirebaseStorage.instance;
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
  ///
  /// [onProgress] reçoit la progression du téléversement (0..1) ;
  /// [checkCancelled] est consulté pendant le téléversement, qui est annulé
  /// s'il rend vrai.
  ///
  /// **Le chiffrement ne passe plus par la mémoire** : il va d'un fichier vers
  /// un autre, un morceau à la fois, et c'est ce fichier qui est téléversé.
  /// Le pic mémoire ne dépend donc plus de la taille du média — ce qui lève
  /// la raison pour laquelle la vidéo en était écartée.
  Future<EncryptedMediaResult> encryptAndUploadFile({
    required File file,
    required String conversationId,
    required String senderId,
    required MediaType mediaType,
    void Function(double progress)? onProgress,
    bool Function()? checkCancelled,
  }) async {
    // Générer une clé AES-256 aléatoire pour ce fichier
    final fileKey = await _generateFileKey();
    final fileKeyBytes = await fileKey.extractBytes();

    final originalSize = await file.length();
    final iv = _generateRandomBytes(12); // 96 bits pour GCM

    // **Chiffrer d'un fichier vers un autre, un morceau à la fois.**
    //
    // L'ancien chemin lisait le fichier entier (`readAsBytes`), assemblait le
    // chiffré entier, puis le téléversait en tampon (`putData`) : trois fois
    // la taille du fichier en mémoire au pic. C'est ce qui interdisait la
    // vidéo, et ce qui faisait tuer l'application par le système sur un gros
    // document. Ici le pic ne dépend plus que de la taille d'un morceau.
    //
    // Le conteneur versionné sert désormais **pour toute taille**, y compris
    // les petits fichiers qui prenaient le format simple. Un chemin de moins,
    // et le lecteur accepte les deux de toute façon.
    final tempDir = await getTemporaryDirectory();
    final chiffre = File(
        '${tempDir.path}/enc_up_${DateTime.now().millisecondsSinceEpoch}.bin');
    final int encryptedSize;
    try {
      encryptedSize = await chiffrerFichierVersFichier(file, chiffre, fileKey, iv);
    } catch (e) {
      await _effacerSansBruit(chiffre);
      rethrow;
    }

    // Générer un nom de fichier unique (sans révéler le nom original)
    final encryptedFileName = _generateEncryptedFileName(mediaType);
    final storagePath = 'encrypted_media/$conversationId/$senderId/$encryptedFileName';

    // Uploader sur Firebase Storage
    final ref = _storage.ref(storagePath);
    final task = ref.putFile(
      chiffre,
      SettableMetadata(
        contentType: 'application/octet-stream', // Masquer le vrai type
        customMetadata: {
          'encrypted': 'true',
          'version': '1',
        },
      ),
    );
    StreamSubscription<TaskSnapshot>? suivi;
    if (onProgress != null || checkCancelled != null) {
      suivi = task.snapshotEvents.listen((event) {
        if (checkCancelled?.call() == true) {
          task.cancel();
          return;
        }
        if (onProgress != null && event.totalBytes > 0) {
          onProgress(event.bytesTransferred / event.totalBytes);
        }
      }, onError: (_) {});
    }
    final TaskSnapshot uploadTask;
    try {
      uploadTask = await task;
    } finally {
      await suivi?.cancel();
      // Le temporaire chiffré ne sert qu'au téléversement — y compris quand
      // celui-ci échoue ou qu'on l'annule. Le laisser traîner remplirait le
      // cache de l'appareil de fichiers que plus rien ne réclame.
      await _effacerSansBruit(chiffre);
    }

    final downloadUrl = await uploadTask.ref.getDownloadURL();

    debugPrint('MediaEncryptionService: Uploaded encrypted file to $storagePath');

    return EncryptedMediaResult(
      encryptedUrl: downloadUrl,
      storagePath: storagePath,
      fileKeyBase64: base64Encode(fileKeyBytes),
      ivBase64: base64Encode(iv),
      originalFileName: path.basename(file.path),
      originalSize: originalSize,
      encryptedSize: encryptedSize,
      mediaType: mediaType,
      mimeType: _getMimeType(file.path),
    );
  }

  /// Chiffre d'un fichier vers un autre, un morceau à la fois.
  ///
  /// Rend la taille du fichier produit. Format inchangé : en-tête
  /// `[version][nombre de morceaux]`, puis pour chaque morceau
  /// `[taille sur 4 octets][ciphertext][étiquette sur 16 octets]`.
  ///
  /// Le nombre de morceaux ne se connaît qu'à la fin, mais il doit figurer en
  /// tête : on réserve les cinq octets, on écrit les morceaux, puis on revient
  /// remplir l'en-tête. C'est pour ça que l'écriture passe par un
  /// `RandomAccessFile` et non par un simple flux.
  @visibleForTesting
  Future<int> chiffrerFichierVersFichier(
    File source,
    File destination,
    SecretKey fileKey,
    Uint8List iv,
  ) async {
    final entree = await source.open();
    final sortie = await destination.open(mode: FileMode.write);
    try {
      await sortie.writeFrom(Uint8List(5)); // en-tête réservé
      var index = 0;
      while (true) {
        final morceau = await entree.read(_chunkSize);
        if (morceau.isEmpty) break;
        final boite = await _aesGcm.encrypt(
          morceau,
          secretKey: fileKey,
          nonce: deriveChunkIv(iv, index),
        );
        final n = boite.cipherText.length + 16;
        await sortie.writeFrom(Uint8List.fromList([
          (n >> 24) & 0xFF,
          (n >> 16) & 0xFF,
          (n >> 8) & 0xFF,
          n & 0xFF,
        ]));
        await sortie.writeFrom(Uint8List.fromList(boite.cipherText));
        await sortie.writeFrom(Uint8List.fromList(boite.mac.bytes));
        index++;
        if (morceau.length < _chunkSize) break;
      }

      final taille = await sortie.position();
      await sortie.setPosition(0);
      await sortie.writeFrom(Uint8List.fromList([
        1,
        (index >> 24) & 0xFF,
        (index >> 16) & 0xFF,
        (index >> 8) & 0xFF,
        index & 0xFF,
      ]));
      await sortie.flush();
      return taille;
    } finally {
      await entree.close();
      await sortie.close();
    }
  }

  /// Dérive un IV unique pour chaque chunk.
  ///
  /// Exposé pour les tests : c'est la moitié du format, et un test qui la
  /// réécrirait de son côté ne verrait pas une dérivation qui change.
  @visibleForTesting
  Uint8List deriveChunkIv(Uint8List baseIv, int chunkIndex) {
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
  /// Télécharge et déchiffre **sans jamais tenir le fichier entier en
  /// mémoire**, et sans plafond de taille.
  ///
  /// Les deux limites qu'on lève ici, mesurées le 2026-09-16 :
  ///
  /// 1. `ref.getData()` sans argument plafonne à **10 Mo** — c'est le défaut
  ///    de `firebase_storage`, pas un choix de ce code. Au-delà, le
  ///    téléchargement échouait, donc tout média chiffré d'une photo un peu
  ///    lourde, d'un document ou d'un audio long était **illisible**. Le
  ///    drapeau étant fermé, personne ne l'avait encore rencontré.
  /// 2. Tout passait par la mémoire : octets chiffrés entiers, puis la liste
  ///    des morceaux déchiffrés, puis leur concaténation. Soit près de trois
  ///    fois la taille du fichier au pic. C'est la raison pour laquelle la
  ///    vidéo était écartée du chiffrement.
  ///
  /// `writeToFile` écrit directement sur le disque, et le déchiffrement va
  /// d'un fichier à l'autre, un morceau à la fois : le pic mémoire ne dépend
  /// plus de la taille du fichier, mais de celle d'un morceau.
  Future<File> downloadAndDecryptFile(EncryptedMediaInfo mediaInfo) async {
    final tempDir = await getTemporaryDirectory();
    final horodatage = DateTime.now().millisecondsSinceEpoch;
    final chiffre = File('${tempDir.path}/enc_$horodatage.bin');

    try {
      await _storage.ref(mediaInfo.storagePath).writeToFile(chiffre);
    } catch (e) {
      await _effacerSansBruit(chiffre);
      throw MediaDecryptionException('Failed to download encrypted file: $e');
    }
    if (!await chiffre.exists() || await chiffre.length() == 0) {
      await _effacerSansBruit(chiffre);
      throw MediaDecryptionException('Failed to download encrypted file');
    }

    final fileKey = SecretKey(base64Decode(mediaInfo.fileKeyBase64));
    final iv = base64Decode(mediaInfo.ivBase64);

    final extension = _getExtensionFromMimeType(mediaInfo.mimeType);
    final clair = File('${tempDir.path}/decrypted_$horodatage$extension');

    try {
      await dechiffrerFichierVersFichier(chiffre, clair, fileKey, iv);
    } catch (e) {
      await _effacerSansBruit(clair);
      rethrow;
    } finally {
      await _effacerSansBruit(chiffre);
    }

    debugPrint('MediaEncryptionService: Decrypted file to ${clair.path}');
    return clair;
  }

  Future<void> _effacerSansBruit(File f) async {
    try {
      if (await f.exists()) await f.delete();
    } catch (_) {
      // Un temporaire qui survit n'est pas une raison d'échouer.
    }
  }

  /// Déchiffre d'un fichier vers un autre, un morceau à la fois.
  ///
  /// Reconnaît les deux formats. Le format simple — un seul bloc GCM, sans
  /// en-tête — n'a jamais servi qu'à de petits fichiers (au-delà de la taille
  /// d'un morceau, l'envoi passait déjà par le format versionné) : le lire
  /// entier ne coûte donc rien. Il reste accepté pour ne pas rendre illisible
  /// ce qu'une version précédente aurait écrit.
  @visibleForTesting
  Future<void> dechiffrerFichierVersFichier(
    File source,
    File destination,
    SecretKey fileKey,
    Uint8List iv,
  ) async {
    final entree = await source.open();
    IOSink? sortie;
    try {
      final entete = await entree.read(5);
      final versionne = entete.isNotEmpty && entete[0] == 1 && entete.length == 5;

      if (!versionne) {
        // Format simple : tout le fichier, d'un bloc.
        await entree.setPosition(0);
        final tout = await entree.read(await source.length());
        if (tout.length < 16) {
          throw MediaDecryptionException('Encrypted file too short');
        }
        final coupe = tout.length - 16;
        try {
          final clair = await _aesGcm.decrypt(
            SecretBox(tout.sublist(0, coupe),
                nonce: iv, mac: Mac(tout.sublist(coupe))),
            secretKey: fileKey,
          );
          await destination.writeAsBytes(clair);
        } catch (e) {
          throw MediaDecryptionException(
              'Failed to decrypt file: invalid key or corrupted data');
        }
        return;
      }

      final total =
          (entete[1] << 24) | (entete[2] << 16) | (entete[3] << 8) | entete[4];
      sortie = destination.openWrite();

      for (var index = 0; index < total; index++) {
        final taille = await entree.read(4);
        if (taille.length < 4) {
          throw MediaDecryptionException('Truncated chunk header at $index');
        }
        final n = (taille[0] << 24) | (taille[1] << 16) | (taille[2] << 8) | taille[3];
        final morceau = await entree.read(n);
        if (morceau.length < n || n < 16) {
          throw MediaDecryptionException('Truncated chunk $index');
        }
        final coupe = morceau.length - 16;
        try {
          final clair = await _aesGcm.decrypt(
            SecretBox(morceau.sublist(0, coupe),
                nonce: deriveChunkIv(iv, index), mac: Mac(morceau.sublist(coupe))),
            secretKey: fileKey,
          );
          sortie.add(clair);
        } catch (e) {
          throw MediaDecryptionException('Failed to decrypt chunk $index');
        }
      }
    } finally {
      await entree.close();
      if (sortie != null) {
        await sortie.flush();
        await sortie.close();
      }
    }
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
