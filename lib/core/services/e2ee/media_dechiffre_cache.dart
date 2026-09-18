import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../features/messages/domain/entities/media_chiffre.dart';
import 'media_encryption_service.dart';

final mediaDechiffreCacheProvider = Provider<MediaDechiffreCache>((ref) {
  return MediaDechiffreCache(ref.watch(mediaEncryptionServiceProvider));
});

/// Télécharge et déchiffre un média **une seule fois**, puis le sert depuis
/// le répertoire de support de l'application.
///
/// Pourquoi un cache à part : les bulles, la galerie et le plein écran
/// demandent le même fichier, parfois dans la même seconde. Sans ça, chaque
/// widget retéléchargerait le blob et le déchiffrerait de son côté.
///
/// Le fichier déchiffré est écrit **en clair** sur l'appareil, comme les
/// pièces jointes téléchargées aujourd'hui (`FileDownloadService`) et comme
/// le cache Hive des messages : c'est le compromis assumé par le plan MLS
/// (§ 7.4). Il est effacé par [vider], à appeler à la déconnexion.
class MediaDechiffreCache {
  MediaDechiffreCache(this._chiffrement, {Future<Directory> Function()? racine})
    : _racine = racine ?? _racineParDefaut;

  final MediaEncryptionService _chiffrement;
  final Future<Directory> Function() _racine;

  /// Un seul déchiffrement en vol par message, même si trois widgets le
  /// demandent en même temps.
  final Map<String, Future<String>> _enVol = {};

  static const _dossier = 'medias_dechiffres';

  static Future<Directory> _racineParDefaut() async {
    final support = await getApplicationSupportDirectory();
    return Directory('${support.path}/$_dossier');
  }

  /// Nom de fichier déterministe : l'id du message et l'extension déduite du
  /// type MIME. Pur, testable, et sans le nom d'origine (qui pourrait
  /// contenir n'importe quoi).
  @visibleForTesting
  static String nomDeFichier(String messageId, String mimeType) {
    final sur = messageId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return '$sur${extensionPour(mimeType)}';
  }

  @visibleForTesting
  static String extensionPour(String mimeType) {
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
      case 'audio/m4a':
      case 'audio/x-m4a':
        return '.m4a';
      case 'audio/aac':
        return '.aac';
      case 'audio/ogg':
        return '.ogg';
      case 'audio/wav':
      case 'audio/x-wav':
        return '.wav';
      case 'application/pdf':
        return '.pdf';
      case 'video/mp4':
        return '.mp4';
      default:
        return '.bin';
    }
  }

  /// Chemin local du média en clair, téléchargé et déchiffré si nécessaire.
  Future<String> cheminLocal(String messageId, MediaChiffre media) {
    return _enVol.putIfAbsent(messageId, () async {
      try {
        return await _resoudre(messageId, media);
      } finally {
        unawaited(_enVol.remove(messageId));
      }
    });
  }

  Future<String> _resoudre(String messageId, MediaChiffre media) async {
    if (!media.estComplet) {
      throw MediaDecryptionException('métadonnées de déchiffrement incomplètes');
    }
    final dossier = await _racine();
    if (!await dossier.exists()) {
      await dossier.create(recursive: true);
    }
    final cible = File('${dossier.path}/${nomDeFichier(messageId, media.mimeType)}');
    if (await cible.exists() && await cible.length() > 0) {
      return cible.path;
    }

    final temporaire = await _chiffrement.downloadAndDecryptFile(
      EncryptedMediaInfo(
        encryptedUrl: media.encryptedUrl,
        storagePath: media.storagePath,
        fileKeyBase64: media.fileKeyBase64,
        ivBase64: media.ivBase64,
        originalFileName: media.fileName,
        originalSize: media.size,
        mediaType: _typePour(media.mimeType),
        mimeType: media.mimeType,
      ),
    );
    // `rename` échoue d'un volume à l'autre ; copier puis supprimer est sûr.
    await temporaire.copy(cible.path);
    try {
      await temporaire.delete();
    } catch (_) {
      // Un temporaire qui traîne n'est pas une erreur.
    }
    return cible.path;
  }

  static MediaType _typePour(String mimeType) {
    if (mimeType.startsWith('image/')) return MediaType.image;
    if (mimeType.startsWith('audio/')) return MediaType.audio;
    if (mimeType.startsWith('video/')) return MediaType.video;
    return MediaType.document;
  }

  /// Supprime tout le cache déchiffré. À la déconnexion et à la suppression
  /// de compte, pour la même raison que `FileDownloadService.clearDownloadedFiles`.
  Future<int> vider() async {
    try {
      final dossier = await _racine();
      if (!await dossier.exists()) return 0;
      var n = 0;
      await for (final entree in dossier.list()) {
        if (entree is File) {
          await entree.delete();
          n++;
        }
      }
      return n;
    } catch (e) {
      debugPrint('MediaDechiffreCache: vidage impossible ($e)');
      return 0;
    }
  }
}
