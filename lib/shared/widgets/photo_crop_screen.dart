import 'dart:async';

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:diaspo_niger/l10n/app_localizations.dart';

import 'app_icon.dart';

/// Rectangle de l'image source (en pixels) visible dans le cadre carré.
///
/// [transformation] est celle de l'`InteractiveViewer`, donc exprimée dans les
/// coordonnées de l'image **affichée** ; [taillePixels] ramène le résultat aux
/// pixels du fichier. Les deux échelles sont égales : le cadre est carré et la
/// transformation n'est qu'un déplacement et un zoom uniforme.
Rect rectRecadrage({
  required Matrix4 transformation,
  required double coteCadre,
  required Size tailleAffichee,
  required Size taillePixels,
}) {
  final visible = MatrixUtils.inverseTransformRect(
    transformation,
    Rect.fromLTWH(0, 0, coteCadre, coteCadre),
  );
  final echelle = taillePixels.width / tailleAffichee.width;
  // Les arrondis de la matrice débordent parfois d'une fraction de pixel :
  // `copyCrop` sortirait de l'image.
  final gauche = (visible.left * echelle).clamp(0.0, taillePixels.width);
  final haut = (visible.top * echelle).clamp(0.0, taillePixels.height);
  final droite = (visible.right * echelle).clamp(gauche, taillePixels.width);
  final bas = (visible.bottom * echelle).clamp(haut, taillePixels.height);
  return Rect.fromLTRB(gauche, haut, droite, bas);
}

/// Cadrer une photo avant de l'envoyer.
///
/// L'avatar est affiché dans un carré : sans cette étape, la photo était
/// rognée en son centre et personne ne décidait de ce qui restait — un
/// portrait y perdait le haut du crâne ou le menton.
class PhotoCropScreen extends StatefulWidget {
  const PhotoCropScreen({super.key, required this.source});

  final File source;

  /// Ouvre l'écran ; rend le fichier recadré, ou `null` si l'utilisateur
  /// renonce.
  static Future<File?> show(BuildContext context, File source) {
    return Navigator.of(context).push<File>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PhotoCropScreen(source: source),
      ),
    );
  }

  @override
  State<PhotoCropScreen> createState() => _PhotoCropScreenState();
}

class _PhotoCropScreenState extends State<PhotoCropScreen> {
  final TransformationController _controleur = TransformationController();

  Size? _taillePixels;
  bool _enEchec = false;
  bool _enTravail = false;

  /// Taille du carré et taille d'affichage de la photo dedans, retenues au
  /// moment du rendu : le calcul du recadrage en a besoin, et elles dépendent
  /// des contraintes de mise en page.
  double _coteCadre = 0;
  Size _tailleAffichee = Size.zero;
  bool _cadrageInitialPose = false;

  @override
  void initState() {
    super.initState();
    unawaited(_mesurer());
  }

  @override
  void dispose() {
    _controleur.dispose();
    super.dispose();
  }

  Future<void> _mesurer() async {
    try {
      final octets = await widget.source.readAsBytes();
      final decodee = await decodeImageFromList(octets);
      if (!mounted) return;
      setState(() {
        _taillePixels = Size(
          decodee.width.toDouble(),
          decodee.height.toDouble(),
        );
      });
      decodee.dispose();
    } catch (_) {
      if (mounted) setState(() => _enEchec = true);
    }
  }

  /// La photo remplit le carré au départ (l'équivalent d'un `BoxFit.cover`),
  /// centrée : le cadrage proposé est celui qu'on obtenait sans cet écran.
  void _poserCadrageInitial() {
    if (_cadrageInitialPose) return;
    _cadrageInitialPose = true;
    _controleur.value =
        Matrix4.identity()..translateByDouble(
          -(_tailleAffichee.width - _coteCadre) / 2,
          -(_tailleAffichee.height - _coteCadre) / 2,
          0,
          1,
        );
  }

  Future<void> _valider() async {
    final pixels = _taillePixels;
    if (pixels == null || _enTravail) return;
    setState(() => _enTravail = true);

    final rect = rectRecadrage(
      transformation: _controleur.value,
      coteCadre: _coteCadre,
      tailleAffichee: _tailleAffichee,
      taillePixels: pixels,
    );

    // Un carré : l'arrondi peut donner un pixel d'écart entre les deux côtés.
    final cote = math.min(rect.width, rect.height).floor();
    final x = rect.left.round().clamp(0, pixels.width.toInt() - cote);
    final y = rect.top.round().clamp(0, pixels.height.toInt() - cote);

    final dossier = await getTemporaryDirectory();
    final sortie = p.join(
      dossier.path,
      'recadre_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );

    final chemin = await compute(_recadrerFichier, <String, Object>{
      'source': widget.source.path,
      'sortie': sortie,
      'x': x,
      'y': y,
      'cote': cote,
    });

    if (!mounted) return;
    if (chemin == null) {
      // Ne pas renvoyer l'original en douce : ce ne serait pas le cadrage
      // demandé, et personne ne le saurait.
      setState(() => _enTravail = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.cropPhotoFailed)),
      );
      return;
    }
    Navigator.of(context).pop(File(chemin));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const AppIcon(AppIcon.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          l10n.cropPhotoTitle,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon:
                _enTravail
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                    : const AppIcon(AppIcon.check, color: Colors.white),
            tooltip: l10n.confirm,
            onPressed: _taillePixels == null || _enTravail ? null : _valider,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: Center(child: _corps())),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 16,
              ),
              child: Text(
                l10n.cropPhotoHint,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _corps() {
    if (_enEchec) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          AppLocalizations.of(context)!.cropPhotoFailed,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70),
        ),
      );
    }

    final pixels = _taillePixels;
    if (pixels == null) {
      return const CircularProgressIndicator(color: Colors.white);
    }

    return LayoutBuilder(
      builder: (context, contraintes) {
        final cote = math.min(contraintes.maxWidth, contraintes.maxHeight);
        // Au départ, la photo couvre le carré : son petit côté vaut le côté du
        // cadre. En dézoomant on ne pourrait que découvrir du vide.
        final echelle = math.max(cote / pixels.width, cote / pixels.height);
        _coteCadre = cote;
        _tailleAffichee = Size(pixels.width * echelle, pixels.height * echelle);
        _poserCadrageInitial();

        return SizedBox(
          width: cote,
          height: cote,
          child: ClipRect(
            child: InteractiveViewer(
              transformationController: _controleur,
              constrained: false,
              // Zéro : le cadre ne peut jamais sortir de la photo, donc le
              // recadrage ne contient jamais de vide.
              boundaryMargin: EdgeInsets.zero,
              // 1 et pas moins : le carré reste toujours plein. Un portrait
              // 9:16 ne tient donc pas entier — l'utilisateur choisit
              // seulement quelle part garder. Arbitré le 2026-09-14, comme le
              // font WhatsApp et Instagram pour une photo de profil ; l'autre
              // voie demandait de cuire un fond (flou ou aplat) dans le
              // fichier envoyé, définitivement.
              minScale: 1,
              maxScale: 6,
              child: SizedBox(
                width: _tailleAffichee.width,
                height: _tailleAffichee.height,
                child: Image.file(widget.source, fit: BoxFit.fill),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Tourne dans un isolate : décoder puis ré-encoder une photo de 2048 px
/// gèlerait l'interface une bonne seconde sur un téléphone d'entrée de gamme.
String? _recadrerFichier(Map<String, Object> consigne) {
  try {
    final octets = File(consigne['source'] as String).readAsBytesSync();
    final source = img.decodeImage(octets);
    if (source == null) return null;
    // `bakeOrientation` ne fait rien quand l'EXIF est déjà neutre — ce qui est
    // le cas des fichiers que rend le sélecteur, mais pas forcément d'ailleurs.
    final droite = img.bakeOrientation(source);
    final coupe = img.copyCrop(
      droite,
      x: consigne['x'] as int,
      y: consigne['y'] as int,
      width: consigne['cote'] as int,
      height: consigne['cote'] as int,
    );
    final sortie = consigne['sortie'] as String;
    File(sortie).writeAsBytesSync(img.encodeJpg(coupe, quality: 92));
    return sortie;
  } catch (_) {
    return null;
  }
}
