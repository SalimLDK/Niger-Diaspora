import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import 'package:diaspo_niger/l10n/app_localizations.dart';

/// Visionneuse plein écran des médias d'un post (zoom / pan / swipe).
///
/// Lecture seule (MVP) : pas de téléchargement/partage. Généralise le pattern
/// de `FullScreenImageViewer` (messages) au cas multi-images via
/// [PhotoViewGallery]. Les tags Hero doivent correspondre exactement à ceux de
/// la grille média de la carte : `'${heroTagPrefix}_$index'`.
class FeedImageViewer extends StatefulWidget {
  final List<String> mediaUrls;
  final int initialIndex;
  final String? heroTagPrefix;

  const FeedImageViewer({
    super.key,
    required this.mediaUrls,
    this.initialIndex = 0,
    this.heroTagPrefix,
  });

  static void show(
    BuildContext context, {
    required List<String> mediaUrls,
    int initialIndex = 0,
    String? heroTagPrefix,
  }) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (_, __, ___) => FeedImageViewer(
          mediaUrls: mediaUrls,
          initialIndex: initialIndex,
          heroTagPrefix: heroTagPrefix,
        ),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  State<FeedImageViewer> createState() => _FeedImageViewerState();
}

class _FeedImageViewerState extends State<FeedImageViewer> {
  late final PageController _pageController =
      PageController(initialPage: widget.initialIndex);
  late int _current = widget.initialIndex;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasMany = widget.mediaUrls.length > 1;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black54,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: hasMany
            ? Text(
                l10n.imageCounter(_current + 1, widget.mediaUrls.length),
                style: const TextStyle(color: Colors.white, fontSize: 16),
              )
            : null,
      ),
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: PhotoViewGallery.builder(
          pageController: _pageController,
          itemCount: widget.mediaUrls.length,
          scrollPhysics: const BouncingScrollPhysics(),
          onPageChanged: (i) => setState(() => _current = i),
          backgroundDecoration: const BoxDecoration(color: Colors.black),
          loadingBuilder: (_, __) => const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
          builder: (_, i) => PhotoViewGalleryPageOptions(
            imageProvider: CachedNetworkImageProvider(widget.mediaUrls[i]),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 4,
            heroAttributes: widget.heroTagPrefix != null
                ? PhotoViewHeroAttributes(tag: '${widget.heroTagPrefix}_$i')
                : null,
          ),
        ),
      ),
    );
  }
}
