import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import 'marker_painter.dart';

/// Génère le pin de localisation moderne (goutte colorée + icône blanche)
/// utilisé partout où l'app affiche une position sélectionnée/partagée sur
/// Google Maps, en remplacement du marqueur rouge par défaut.
class LocationPinGenerator {
  LocationPinGenerator._();

  static final Map<String, BitmapDescriptor> _cache = {};

  /// Retourne (et met en cache) le pin de localisation à la taille demandée.
  static Future<BitmapDescriptor> getPin({
    double size = 90.0,
    Color color = AppColors.primary,
  }) async {
    final cacheKey = '${color.toARGB32()}_${size.toInt()}';
    final cached = _cache[cacheKey];
    if (cached != null) return cached;

    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);

    final path = MarkerPainter.createDropPinPath(size);
    MarkerPainter.drawPinBackground(canvas, path, [
      color,
      Color.lerp(color, Colors.black, 0.25)!,
    ], size);

    final photoRect = MarkerPainter.getPhotoRect(size, MarkerType.business);
    _drawLocationIcon(canvas, photoRect);

    final picture = pictureRecorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final descriptor = BitmapDescriptor.bytes(byteData!.buffer.asUint8List());

    _cache[cacheKey] = descriptor;
    return descriptor;
  }

  /// Dessine un pictogramme de localisation blanc au centre du pin.
  static void _drawLocationIcon(Canvas canvas, Rect rect) {
    final center = rect.center;
    final ringRadius = rect.width * 0.32;
    final dotRadius = rect.width * 0.13;

    final ringPaint =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = rect.width * 0.11;
    canvas.drawCircle(center, ringRadius, ringPaint);

    final dotPaint = Paint()..color = Colors.white;
    canvas.drawCircle(center, dotRadius, dotPaint);
  }

  static void clearCache() => _cache.clear();
}
