import 'package:flutter/material.dart';

/// Cadre en pointillés. Flutter n'a pas de `BorderStyle.dashed` : on trace le
/// rectangle arrondi (ou le cercle) et on n'en peint qu'un segment sur deux.
///
/// Utilisé par les zones « à remplir » des maquettes — affiche d'événement
/// (16e), avatar d'un profil incomplet (11f).
class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double strokeWidth;

  static const double _dash = 5;
  static const double _gap = 4;

  const DashedBorderPainter({
    required this.color,
    required this.radius,
    this.strokeWidth = 1,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth;
    final path =
        Path()..addRRect(
          RRect.fromRectAndRadius(
            // Le trait est centré sur le chemin : sans cette marge, la moitié
            // extérieure du trait est rognée par les bords du widget.
            Rect.fromLTWH(
              strokeWidth / 2,
              strokeWidth / 2,
              size.width - strokeWidth,
              size.height - strokeWidth,
            ),
            Radius.circular(radius),
          ),
        );

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + _dash;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.radius != radius ||
      oldDelegate.strokeWidth != strokeWidth;
}
