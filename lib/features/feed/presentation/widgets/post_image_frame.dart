import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Le cadre d'une image seule dans le fil prend la forme de la photo.
///
/// C'était jusqu'ici une bande de 205 px de haut en `BoxFit.cover` : une photo
/// portrait y perdait la moitié de sa hauteur — un visage sur deux coupé —
/// sans que rien ne le signale. Le cadre suit maintenant le ratio réel, borné
/// des deux côtés : au-delà, une image très haute mangerait l'écran entier, et
/// une très large se réduirait à un filet.
const double ratioMiniPortrait = 4 / 5; // 0,80
const double ratioMaxiPaysage = 1.91;

/// Tant que la photo n'est pas décodée, sa forme est inconnue.
const double ratioParDefaut = 4 / 3;

/// Ratio du cadre pour une photo de ratio [ratioSource] (largeur / hauteur).
///
/// Une valeur absurde (zéro, négative, NaN) retombe sur le défaut plutôt que
/// de produire une contrainte que la mise en page ne saurait pas résoudre.
double cadreRatio(double ratioSource) {
  if (!ratioSource.isFinite || ratioSource <= 0) return ratioParDefaut;
  return ratioSource.clamp(ratioMiniPortrait, ratioMaxiPaysage);
}

/// Donne à [child] la forme de la photo qui se trouve à [url].
class PostImageFrame extends StatefulWidget {
  const PostImageFrame({super.key, required this.url, required this.child});

  final String url;
  final Widget child;

  @override
  State<PostImageFrame> createState() => _PostImageFrameState();
}

class _PostImageFrameState extends State<PostImageFrame> {
  /// Une photo déjà vue garde sa forme : en remontant le fil, la mise en page
  /// ne saute pas une seconde fois. Borné — le fil peut défiler longtemps.
  static final Map<String, double> _connus = {};
  static const int _maxConnus = 300;

  double _ratio = ratioParDefaut;
  ImageStream? _flux;
  ImageStreamListener? _ecouteur;

  /// `resolve()` appelle son écouteur **immédiatement** quand l'image est déjà
  /// en cache : à ce moment-là, `initState` n'est pas fini et il n'y a rien à
  /// redessiner.
  bool _monte = false;

  @override
  void initState() {
    super.initState();
    _resoudre();
    _monte = true;
  }

  @override
  void didUpdateWidget(PostImageFrame ancien) {
    super.didUpdateWidget(ancien);
    if (ancien.url != widget.url) {
      _detacher();
      _ratio = ratioParDefaut;
      _resoudre();
    }
  }

  @override
  void dispose() {
    _detacher();
    super.dispose();
  }

  void _resoudre() {
    if (widget.url.isEmpty) return;

    final connu = _connus[widget.url];
    if (connu != null) {
      _ratio = connu;
      return;
    }

    final flux = CachedNetworkImageProvider(
      widget.url,
    ).resolve(const ImageConfiguration());
    final ecouteur = ImageStreamListener(
      (info, _) {
        final ratio = cadreRatio(info.image.width / info.image.height);
        info.dispose();
        _memoriser(widget.url, ratio);
        if (!_monte) {
          _ratio = ratio;
          return;
        }
        if (mounted && ratio != _ratio) setState(() => _ratio = ratio);
      },
      // Une photo illisible garde le cadre par défaut : l'erreur se voit déjà
      // dans l'image elle-même, pas la peine d'en faire une seconde.
      onError: (_, __) {},
    );

    _flux = flux;
    _ecouteur = ecouteur;
    flux.addListener(ecouteur);
  }

  void _detacher() {
    if (_flux != null && _ecouteur != null) _flux!.removeListener(_ecouteur!);
    _flux = null;
    _ecouteur = null;
  }

  static void _memoriser(String url, double ratio) {
    if (_connus.length >= _maxConnus && !_connus.containsKey(url)) {
      _connus.remove(_connus.keys.first);
    }
    _connus[url] = ratio;
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(aspectRatio: _ratio, child: widget.child);
  }
}
