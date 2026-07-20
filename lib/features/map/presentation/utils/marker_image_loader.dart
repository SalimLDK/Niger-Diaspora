import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Charge les images utilisées par les pins de la carte en passant par le
/// cache disque partagé (`flutter_cache_manager`) avec le reste de l'app,
/// au lieu de retélécharger la photo à chaque génération de marqueur.
class MarkerImageLoader {
  MarkerImageLoader._();

  static const Duration _timeout = Duration(seconds: 3);

  /// Retourne l'image décodée pour [url], ou `null` en cas d'échec/timeout
  /// (réseau, décodage) — l'appelant doit alors utiliser une icône par défaut.
  static Future<ui.Image?> load(String url, {int? targetWidth}) async {
    try {
      final file = await DefaultCacheManager().getSingleFile(url).timeout(
        _timeout,
      );
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: targetWidth,
      );
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (_) {
      return null;
    }
  }
}
