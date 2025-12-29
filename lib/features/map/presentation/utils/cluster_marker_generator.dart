import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../profile/data/models/profile_model.dart';

/// Générateur de marqueurs de cluster améliorés avec mini-avatars
class ClusterMarkerGenerator {
  ClusterMarkerGenerator._();

  /// Cache des marqueurs de cluster générés
  static final Map<String, BitmapDescriptor> _clusterCache = {};

  /// Génère un marqueur de cluster avec mini-avatars superposés
  ///
  /// Affiche jusqu'à 3 photos de profil avec un badge de comptage
  static Future<BitmapDescriptor> createClusterMarker(
    List<ProfileModel> members, {
    double size = 90.0,
  }) async {
    // Clé de cache basée sur les IDs des membres et la taille
    final cacheKey = _generateCacheKey(members, size);
    if (_clusterCache.containsKey(cacheKey)) {
      return _clusterCache[cacheKey]!;
    }

    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);

    // Dimensions
    final badgeSize = 24.0;
    final avatarSize = 32.0;
    final totalWidth = size;
    final totalHeight = size;

    // Dessiner l'ombre de fond
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(
      Offset(totalWidth / 2, totalHeight / 2 + 2),
      totalWidth / 2 - 4,
      shadowPaint,
    );

    // Dessiner le cercle de fond principal
    final bgGradient = ui.Gradient.radial(
      Offset(totalWidth / 2, totalHeight / 2),
      totalWidth / 2,
      [AppColors.secondary, AppColors.secondaryDark],
      [0.0, 1.0],
    );
    final bgPaint = Paint()..shader = bgGradient;
    canvas.drawCircle(
      Offset(totalWidth / 2, totalHeight / 2),
      totalWidth / 2 - 4,
      bgPaint,
    );

    // Bordure blanche
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(
      Offset(totalWidth / 2, totalHeight / 2),
      totalWidth / 2 - 5,
      borderPaint,
    );

    // Dessiner les mini-avatars (jusqu'à 3)
    final avatarsToShow = members.take(3).toList();
    final avatarCenters = _calculateAvatarPositions(
      avatarsToShow.length,
      totalWidth,
      totalHeight,
      avatarSize,
    );

    for (int i = 0; i < avatarsToShow.length; i++) {
      await _drawMiniAvatar(
        canvas,
        avatarsToShow[i],
        avatarCenters[i],
        avatarSize,
        i, // Z-index pour l'ordre de superposition
      );
    }

    // Dessiner le badge de comptage si plus de 3 membres
    if (members.length > 3) {
      _drawCountBadge(
        canvas,
        members.length,
        Offset(totalWidth - badgeSize / 2 - 2, badgeSize / 2 + 2),
        badgeSize,
      );
    } else if (members.length > 1) {
      // Afficher le nombre total même si <= 3
      _drawCountBadge(
        canvas,
        members.length,
        Offset(totalWidth - badgeSize / 2 - 2, badgeSize / 2 + 2),
        badgeSize,
      );
    }

    // Convertir en BitmapDescriptor
    final picture = pictureRecorder.endRecording();
    final img = await picture.toImage(totalWidth.toInt(), totalHeight.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    final descriptor = BitmapDescriptor.bytes(bytes);
    _clusterCache[cacheKey] = descriptor;

    return descriptor;
  }

  /// Génère un marqueur de cluster simple (nombre seulement)
  static Future<BitmapDescriptor> createSimpleClusterMarker(
    int count, {
    double size = 80.0,
  }) async {
    final cacheKey = 'simple_${count}_$size';
    if (_clusterCache.containsKey(cacheKey)) {
      return _clusterCache[cacheKey]!;
    }

    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);

    // Ombre
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(
      Offset(size / 2, size / 2 + 2),
      size / 2 - 2,
      shadowPaint,
    );

    // Fond avec dégradé
    final gradient = ui.Gradient.radial(
      Offset(size / 2, size / 2),
      size / 2,
      [AppColors.secondary, AppColors.secondaryDark],
      [0.0, 1.0],
    );
    final paint = Paint()..shader = gradient;
    canvas.drawCircle(Offset(size / 2, size / 2), size / 2 - 2, paint);

    // Bordure
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(Offset(size / 2, size / 2), size / 2 - 4, borderPaint);

    // Texte du compteur
    final text = count > 99 ? '99+' : count.toString();
    final textSpan = TextSpan(
      text: text,
      style: const TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(
        size / 2 - textPainter.width / 2,
        size / 2 - textPainter.height / 2,
      ),
    );

    final picture = pictureRecorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    final descriptor = BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
    _clusterCache[cacheKey] = descriptor;

    return descriptor;
  }

  /// Calcule les positions des avatars pour un arrangement esthétique
  static List<Offset> _calculateAvatarPositions(
    int count,
    double containerWidth,
    double containerHeight,
    double avatarSize,
  ) {
    final centerX = containerWidth / 2;
    final centerY = containerHeight / 2;

    switch (count) {
      case 1:
        return [Offset(centerX, centerY)];
      case 2:
        return [
          Offset(centerX - 12, centerY),
          Offset(centerX + 12, centerY),
        ];
      case 3:
      default:
        return [
          Offset(centerX - 14, centerY + 6), // Gauche bas
          Offset(centerX + 14, centerY + 6), // Droite bas
          Offset(centerX, centerY - 10), // Centre haut
        ];
    }
  }

  /// Dessine un mini-avatar dans le cluster
  static Future<void> _drawMiniAvatar(
    Canvas canvas,
    ProfileModel member,
    Offset center,
    double size,
    int zIndex,
  ) async {
    // Bordure/ombre pour la profondeur
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawCircle(center + const Offset(0, 1), size / 2, shadowPaint);

    // Fond blanc
    final bgPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, size / 2, bgPaint);

    // Si photo disponible, essayer de la charger
    if (member.photoUrl != null && member.photoUrl!.isNotEmpty) {
      try {
        final image = await _loadNetworkImage(member.photoUrl!);
        if (image != null) {
          // Dessiner l'image dans un cercle
          canvas.save();
          final clipPath = Path()
            ..addOval(Rect.fromCircle(center: center, radius: size / 2 - 2));
          canvas.clipPath(clipPath);

          final srcRect = Rect.fromLTWH(
            0,
            0,
            image.width.toDouble(),
            image.height.toDouble(),
          );
          final dstRect = Rect.fromCircle(center: center, radius: size / 2 - 2);
          canvas.drawImageRect(image, srcRect, dstRect, Paint());

          canvas.restore();
          return;
        }
      } catch (_) {
        // Fallback vers l'icône par défaut
      }
    }

    // Icône par défaut si pas de photo
    _drawDefaultAvatar(canvas, center, size);
  }

  /// Dessine un avatar par défaut (icône de personne)
  static void _drawDefaultAvatar(Canvas canvas, Offset center, double size) {
    // Fond coloré
    final bgPaint = Paint()..color = AppColors.primaryLight;
    canvas.drawCircle(center, size / 2 - 2, bgPaint);

    // Icône de personne simplifiée
    final iconPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final scale = size / 32;

    // Tête
    canvas.drawCircle(
      Offset(center.dx, center.dy - 4 * scale),
      5 * scale,
      iconPaint,
    );

    // Corps
    final bodyPath = Path()
      ..moveTo(center.dx - 8 * scale, center.dy + 10 * scale)
      ..quadraticBezierTo(
        center.dx,
        center.dy + 2 * scale,
        center.dx + 8 * scale,
        center.dy + 10 * scale,
      )
      ..arcToPoint(
        Offset(center.dx - 8 * scale, center.dy + 10 * scale),
        radius: Radius.circular(10 * scale),
        clockwise: false,
      );
    canvas.drawPath(bodyPath, iconPaint);
  }

  /// Dessine le badge de comptage
  static void _drawCountBadge(
    Canvas canvas,
    int count,
    Offset center,
    double size,
  ) {
    // Fond du badge (rouge/orange)
    final badgePaint = Paint()..color = AppColors.primary;
    canvas.drawCircle(center, size / 2, badgePaint);

    // Bordure blanche
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, size / 2, borderPaint);

    // Texte
    final text = count > 99 ? '99+' : count.toString();
    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        fontSize: count > 99 ? 9 : 11,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );
  }

  /// Charge une image depuis le réseau
  static Future<ui.Image?> _loadNetworkImage(String url) async {
    try {
      final completer = Completer<ui.Image?>();
      final imageProvider = NetworkImage(url);
      final imageStream = imageProvider.resolve(const ImageConfiguration());

      late ImageStreamListener listener;
      listener = ImageStreamListener(
        (ImageInfo info, bool _) {
          if (!completer.isCompleted) {
            completer.complete(info.image);
          }
          imageStream.removeListener(listener);
        },
        onError: (exception, stackTrace) {
          if (!completer.isCompleted) {
            completer.complete(null);
          }
          imageStream.removeListener(listener);
        },
      );
      imageStream.addListener(listener);

      return await completer.future.timeout(
        const Duration(seconds: 3),
        onTimeout: () => null,
      );
    } catch (_) {
      return null;
    }
  }

  /// Génère une clé de cache unique pour un cluster
  static String _generateCacheKey(List<ProfileModel> members, double size) {
    final ids = members.take(3).map((m) => m.id).join('_');
    return 'cluster_${ids}_${members.length}_${size.toInt()}';
  }

  /// Nettoie le cache des clusters
  static void clearCache() {
    _clusterCache.clear();
  }
}
