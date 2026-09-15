import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';

/// Vrai pour la forme `file://<chemin>` que produisent l'envoi en cours et
/// [MediaChiffreGate].
bool estUrlLocale(String url) => url.startsWith('file://');

/// Chemin de fichier derrière une URL `file://`.
///
/// Le reste de l'app construit ces URL par simple concaténation
/// (`'file://$localPath'`), sans encodage : on décode donc de la même façon,
/// en retirant le préfixe, plutôt que par `Uri.parse` qui casserait sur un
/// espace ou un accent dans le chemin.
String cheminDepuisUrlLocale(String url) => url.substring('file://'.length);

/// Enregistre dans la galerie une image déjà sur disque (média déchiffré).
/// Les permissions sont celles que l'appelant a déjà demandées pour la
/// variante réseau (`FileDownloadService.requestGalleryPermission`).
Future<bool> enregistrerImageLocaleDansGalerie(String chemin) async {
  try {
    await Gal.putImage(chemin, album: 'Diaspo Niger');
    return true;
  } catch (e) {
    debugPrint('enregistrerImageLocaleDansGalerie: $e');
    return false;
  }
}

/// Fournisseur d'image pour une URL réseau **ou** locale.
ImageProvider imageProviderPour(String url) => estUrlLocale(url)
    ? FileImage(File(cheminDepuisUrlLocale(url)))
    : CachedNetworkImageProvider(url);

/// `CachedNetworkImage` quand l'URL est distante, `Image.file` quand elle est
/// locale — même surface pour l'appelant, qui n'a pas à savoir si le média
/// était chiffré.
class ImageLocaleOuReseau extends StatelessWidget {
  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final int? memCacheWidth;
  final Widget Function(BuildContext context, String url)? placeholder;
  final Widget Function(BuildContext context, String url, Object error)?
  errorWidget;

  const ImageLocaleOuReseau({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.memCacheWidth,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (estUrlLocale(url)) {
      return Image.file(
        File(cheminDepuisUrlLocale(url)),
        fit: fit,
        width: width,
        height: height,
        cacheWidth: memCacheWidth,
        errorBuilder: (context, error, _) =>
            errorWidget?.call(context, url, error) ?? const SizedBox.shrink(),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      width: width,
      height: height,
      memCacheWidth: memCacheWidth,
      placeholder: placeholder,
      errorWidget: errorWidget,
    );
  }
}
