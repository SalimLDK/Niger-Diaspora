import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Fonds d'écran nommés (§21c) rendus **procéduralement** via [CustomPainter] —
/// aucun asset image n'est requis. Chaque motif décline une variante claire et
/// sombre.
class ChatWallpaper {
  final String id;
  final String label;

  const ChatWallpaper._(this.id, this.label);

  static const sahel = ChatWallpaper._('sahel', 'Sahel');
  static const tissage = ChatWallpaper._('tissage', 'Tissage');
  static const nuit = ChatWallpaper._('nuit', 'Nuit');

  static const all = <ChatWallpaper>[sahel, tissage, nuit];

  static ChatWallpaper? byId(String? id) {
    if (id == null) return null;
    for (final w in all) {
      if (w.id == id) return w;
    }
    return null;
  }

  CustomPainter painter(bool isDark) =>
      ChatWallpaperPainter(id: id, isDark: isDark);

  /// Rendu plein cadre (à placer dans un [Stack]).
  Widget fill(bool isDark) => Positioned.fill(
        child: CustomPaint(painter: painter(isDark)),
      );

  /// Vignette carrée (grille du sélecteur / aperçu).
  Widget thumbnail(bool isDark, {double size = 60, double radius = 12}) =>
      ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: CustomPaint(
          painter: painter(isDark),
          size: Size.square(size),
        ),
      );
}

class ChatWallpaperPainter extends CustomPainter {
  final String id;
  final bool isDark;

  const ChatWallpaperPainter({required this.id, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    switch (id) {
      case 'sahel':
        _paintSahel(canvas, size);
        break;
      case 'tissage':
        _paintTissage(canvas, size);
        break;
      case 'nuit':
        _paintNuit(canvas, size);
        break;
    }
  }

  // ---- Sahel : dunes de sable, dégradé chaud ----
  void _paintSahel(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final top = isDark ? const Color(0xFF2A2418) : const Color(0xFFF5E6C8);
    final bottom = isDark ? const Color(0xFF15120C) : const Color(0xFFE4C596);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, bottom],
        ).createShader(rect),
    );

    final duneColor = (isDark ? const Color(0xFFD9A441) : const Color(0xFFC89B5A))
        .withValues(alpha: isDark ? 0.10 : 0.18);
    final dunePaint = Paint()
      ..color = duneColor
      ..style = PaintingStyle.fill;

    // Quelques courbes de dune régulières.
    for (var i = 0; i < 4; i++) {
      final y = size.height * (0.30 + i * 0.20);
      final amp = size.height * 0.05;
      final path = Path()..moveTo(0, y);
      final steps = 6;
      for (var s = 0; s <= steps; s++) {
        final x = size.width * s / steps;
        final dy = y + math.sin((s / steps) * math.pi * 2 + i) * amp;
        path.lineTo(x, dy);
      }
      path
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(path, dunePaint);
    }
  }

  // ---- Tissage : motif de vannerie entrelacé ----
  void _paintTissage(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final base = isDark ? const Color(0xFF221E17) : const Color(0xFFE8DCC4);
    canvas.drawRect(rect, Paint()..color = base);

    final warm = (isDark ? const Color(0xFFC85A3A) : const Color(0xFFC85A3A))
        .withValues(alpha: isDark ? 0.16 : 0.22);
    final ochre = (isDark ? const Color(0xFFD9A441) : const Color(0xFFB88A3A))
        .withValues(alpha: isDark ? 0.14 : 0.20);

    // Cellule de tissage : deux brins qui alternent dessus/dessous.
    final cell = size.width / 6;
    final strand = cell * 0.42;
    for (var row = 0; row * cell < size.height + cell; row++) {
      for (var col = 0; col * cell < size.width + cell; col++) {
        final cx = col * cell;
        final cy = row * cell;
        final over = (row + col).isEven;
        final r = Radius.circular(strand * 0.5);
        // Brin horizontal
        final h = RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - cell * 0.5, cy - strand * 0.5, cell, strand),
          r,
        );
        // Brin vertical
        final v = RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - strand * 0.5, cy - cell * 0.5, strand, cell),
          r,
        );
        if (over) {
          canvas.drawRRect(v, Paint()..color = ochre);
          canvas.drawRRect(h, Paint()..color = warm);
        } else {
          canvas.drawRRect(h, Paint()..color = warm);
          canvas.drawRRect(v, Paint()..color = ochre);
        }
      }
    }
  }

  // ---- Nuit : ciel étoilé indigo ----
  void _paintNuit(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0.2, -0.6),
          radius: 1.2,
          colors: [Color(0xFF232645), Color(0xFF0C0D16)],
        ).createShader(rect),
    );

    // Étoiles déterministes (seed fixe → pas de scintillement au repaint).
    final rnd = math.Random(42);
    final star = Paint()..color = Colors.white;
    final count = ((size.width * size.height) / 2600).clamp(12, 90).toInt();
    for (var i = 0; i < count; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      final radius = rnd.nextDouble() * 1.1 + 0.4;
      star.color = Colors.white.withValues(alpha: rnd.nextDouble() * 0.5 + 0.2);
      canvas.drawCircle(Offset(x, y), radius, star);
    }

    // Croissant de lune discret : disque clair puis découpe avec la couleur du
    // ciel (évite BlendMode.clear qui nécessiterait un saveLayer).
    final moonCenter = Offset(size.width * 0.80, size.height * 0.18);
    final moonR = size.shortestSide * 0.09;
    canvas.drawCircle(
      moonCenter,
      moonR,
      Paint()..color = const Color(0xFFE9E4CF).withValues(alpha: 0.85),
    );
    canvas.drawCircle(
      moonCenter.translate(moonR * 0.55, -moonR * 0.28),
      moonR,
      Paint()..color = const Color(0xFF191B30),
    );
  }

  @override
  bool shouldRepaint(covariant ChatWallpaperPainter oldDelegate) =>
      oldDelegate.id != id || oldDelegate.isDark != isDark;
}
