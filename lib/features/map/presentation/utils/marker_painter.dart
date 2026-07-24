import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

/// Enumération des types de pins pour la carte
enum MarkerType {
  currentUser,
  friend,
  member,
  embassy,
  business,
}

/// Configuration pour le rendu d'un marqueur
class MarkerConfig {
  final MarkerType type;
  final String? photoUrl;
  final String? profession;
  final bool isOnline;
  final DateTime? lastLoginAt;
  final bool isSelected;
  final double size;
  final double scale;

  const MarkerConfig({
    required this.type,
    this.photoUrl,
    this.profession,
    this.isOnline = false,
    this.lastLoginAt,
    this.isSelected = false,
    this.size = 90.0,
    this.scale = 1.0,
  });

  /// Retourne la taille effective avec le scale appliqué
  double get effectiveSize => size * scale;

  /// Génère une clé de cache unique pour cette configuration
  String get cacheKey {
    return '${type.name}_${photoUrl ?? 'no_photo'}_${profession ?? 'no_prof'}_'
        '${isOnline}_${lastLoginAt?.millisecondsSinceEpoch ?? 0}_'
        '${isSelected}_${size.toInt()}_${(scale * 100).toInt()}';
  }
}

/// Utilitaires de dessin pour les marqueurs de carte
class MarkerPainter {
  MarkerPainter._();

  /// Couleurs par type de marqueur
  static List<Color> getColorsForType(MarkerType type) {
    switch (type) {
      case MarkerType.currentUser:
        return [AppColors.info, AppColors.infoDark];
      case MarkerType.friend:
        return [AppColors.secondary, AppColors.secondaryDark];
      case MarkerType.member:
        return [AppColors.primary, AppColors.primaryDark];
      case MarkerType.embassy:
        return [const Color(0xFF1976D2), const Color(0xFF0D47A1)];
      case MarkerType.business:
        return [const Color(0xFFFF9800), const Color(0xFFE65100)];
    }
  }

  /// Retourne l'opacité pour un type de marqueur
  static double getOpacityForType(MarkerType type) {
    switch (type) {
      case MarkerType.member:
        return 0.85; // Membres non-amis légèrement transparents
      default:
        return 1.0;
    }
  }

  /// Retourne le facteur de taille pour un type de marqueur
  static double getSizeFactorForType(MarkerType type) {
    switch (type) {
      case MarkerType.member:
        return 0.85; // Membres non-amis plus petits
      default:
        return 1.0;
    }
  }

  /// Dessine un chemin de pin en forme de goutte classique (style Google Maps)
  ///
  /// La forme consiste en :
  /// - Un cercle parfait en haut pour la photo
  /// - Une pointe fine et élégante en bas
  static Path createDropPinPath(double size) {
    final path = Path();
    final centerX = size / 2;

    // Proportions classiques style Google Maps
    final bulbRadius = size * 0.40; // Cercle principal
    final bulbCenterY = size * 0.40; // Centre du cercle
    final anchorY = size * 0.95; // Pointe

    // Commencer en bas à la pointe
    path.moveTo(centerX, anchorY);

    // Courbe gauche (pointe → cercle) - plus serrée
    path.quadraticBezierTo(
      centerX - bulbRadius * 0.5, // Point de contrôle X
      size * 0.68, // Point de contrôle Y
      centerX - bulbRadius, // Arrivée X
      bulbCenterY, // Arrivée Y
    );

    // Arc du cercle (partie supérieure)
    path.arcToPoint(
      Offset(centerX + bulbRadius, bulbCenterY),
      radius: Radius.circular(bulbRadius),
      clockwise: true,
      largeArc: true,
    );

    // Courbe droite (cercle → pointe)
    path.quadraticBezierTo(
      centerX + bulbRadius * 0.5, // Point de contrôle X
      size * 0.68, // Point de contrôle Y
      centerX, // Retour à la pointe
      anchorY,
    );

    path.close();
    return path;
  }

  /// Retourne la position Y de l'ancrage (pointe du pin)
  static double getAnchorY(double size) => size * 0.95;

  /// Dessine un chemin de forme shield/badge pour les ambassades
  static Path createShieldPath(double size) {
    final path = Path();
    final centerX = size / 2;
    final topY = size * 0.08;
    final bottomY = size * 0.92;
    final sideMargin = size * 0.12;
    final cornerRadius = size * 0.12;

    // Commencer en haut à gauche
    path.moveTo(sideMargin + cornerRadius, topY);

    // Ligne du haut
    path.lineTo(size - sideMargin - cornerRadius, topY);

    // Coin haut droit arrondi
    path.arcToPoint(
      Offset(size - sideMargin, topY + cornerRadius),
      radius: Radius.circular(cornerRadius),
      clockwise: true,
    );

    // Côté droit descendant
    path.lineTo(size - sideMargin, size * 0.55);

    // Courbe vers la pointe
    path.quadraticBezierTo(
      size - sideMargin, size * 0.75,
      centerX, bottomY,
    );

    // Courbe remontant côté gauche
    path.quadraticBezierTo(
      sideMargin, size * 0.75,
      sideMargin, size * 0.55,
    );

    // Côté gauche remontant
    path.lineTo(sideMargin, topY + cornerRadius);

    // Coin haut gauche arrondi
    path.arcToPoint(
      Offset(sideMargin + cornerRadius, topY),
      radius: Radius.circular(cornerRadius),
      clockwise: true,
    );

    path.close();
    return path;
  }

  /// Dessine le fond du pin avec dégradé simple et propre
  static void drawPinBackground(
    Canvas canvas,
    Path path,
    List<Color> colors,
    double size, {
    double opacity = 1.0,
  }) {
    // Ombre portée simple
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.25 * opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawPath(path.shift(const Offset(0, 2)), shadowPaint);

    // Fond avec couleur unie ou dégradé léger
    final gradient = ui.Gradient.linear(
      Offset(size / 2, 0),
      Offset(size / 2, size),
      colors.map((c) => c.withValues(alpha: opacity)).toList(),
      [0.0, 1.0],
    );

    final fillPaint = Paint()
      ..shader = gradient
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // Bordure blanche fine
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9 * opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawPath(path, borderPaint);
  }

  /// Dessine un effet de glow autour du pin (pour les amis)
  static void drawGlowEffect(
    Canvas canvas,
    Path path,
    Color color,
    double intensity,
  ) {
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.25 * intensity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawPath(path, glowPaint);
  }

  /// Dessine des cercles de pulse animés (pour la position actuelle)
  static void drawPulseRings(
    Canvas canvas,
    Offset center,
    double baseRadius,
    Color color,
    double phase, // 0.0 à 1.0
  ) {
    for (int i = 0; i < 3; i++) {
      final ringRadius = baseRadius + (i * 8) + (phase * 20);
      final ringOpacity = (0.4 - (i * 0.12) - (phase * 0.3)).clamp(0.0, 0.4);

      if (ringOpacity > 0) {
        final ringPaint = Paint()
          ..color = color.withValues(alpha: ringOpacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5;
        canvas.drawCircle(center, ringRadius, ringPaint);
      }
    }
  }

  /// Dessine la zone circulaire pour la photo dans le pin
  static Rect getPhotoRect(double size, MarkerType type) {
    if (type == MarkerType.embassy) {
      // Zone pour l'icône du shield
      final iconSize = size * 0.40;
      return Rect.fromCenter(
        center: Offset(size / 2, size * 0.40),
        width: iconSize,
        height: iconSize,
      );
    }

    // Zone circulaire dans le cercle du drop-pin
    // Le cercle a un rayon de 0.40 * size, centré à Y = 0.40 * size
    // La photo occupe 80% du diamètre pour laisser une bordure visible
    final bulbRadius = size * 0.40;
    final photoSize = bulbRadius * 1.6; // 64% de size
    return Rect.fromCenter(
      center: Offset(size / 2, size * 0.40),
      width: photoSize,
      height: photoSize,
    );
  }

  /// Dessine une icône de personne par défaut
  static void drawDefaultPersonIcon(
    Canvas canvas,
    Rect photoRect,
    Color iconColor,
  ) {
    final iconPaint = Paint()
      ..color = iconColor
      ..style = PaintingStyle.fill;

    final centerX = photoRect.center.dx;
    final centerY = photoRect.center.dy;
    final scale = photoRect.width / 50; // Normaliser par rapport à une taille de référence

    // Tête (cercle)
    canvas.drawCircle(
      Offset(centerX, centerY - 6 * scale),
      10 * scale,
      iconPaint,
    );

    // Corps (arc)
    final bodyPath = Path()
      ..moveTo(centerX - 16 * scale, centerY + 18 * scale)
      ..quadraticBezierTo(
        centerX,
        centerY + 2 * scale,
        centerX + 16 * scale,
        centerY + 18 * scale,
      )
      ..arcToPoint(
        Offset(centerX - 16 * scale, centerY + 18 * scale),
        radius: Radius.circular(18 * scale),
        clockwise: false,
      );
    canvas.drawPath(bodyPath, iconPaint);
  }

  /// Dessine une icône d'ambassade (bâtiment)
  static void drawEmbassyIcon(
    Canvas canvas,
    Rect iconRect,
    Color iconColor,
  ) {
    final iconPaint = Paint()
      ..color = iconColor
      ..style = PaintingStyle.fill;

    final centerX = iconRect.center.dx;
    final centerY = iconRect.center.dy;
    final scale = iconRect.width / 45;

    // Base du bâtiment
    final buildingRect = Rect.fromCenter(
      center: Offset(centerX, centerY + 4 * scale),
      width: 28 * scale,
      height: 22 * scale,
    );
    canvas.drawRect(buildingRect, iconPaint);

    // Colonnes
    final columnPaint = Paint()
      ..color = iconColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 3; i++) {
      final columnX = centerX - 10 * scale + (i * 10 * scale);
      final columnRect = Rect.fromLTWH(
        columnX,
        centerY - 4 * scale,
        3 * scale,
        14 * scale,
      );
      canvas.drawRect(columnRect, columnPaint);
    }

    // Toit triangulaire
    final roofPath = Path()
      ..moveTo(centerX - 16 * scale, centerY - 6 * scale)
      ..lineTo(centerX, centerY - 16 * scale)
      ..lineTo(centerX + 16 * scale, centerY - 6 * scale)
      ..close();
    canvas.drawPath(roofPath, iconPaint);
  }

  /// Dessine l'indicateur de statut en ligne (proportionnel à la taille du pin)
  static void drawOnlineStatus(
    Canvas canvas,
    double markerSize,
    bool isOnline,
    DateTime? lastLoginAt,
  ) {
    // Taille proportionnelle au pin (environ 18% de la taille)
    final double statusSize = markerSize * 0.18;
    final statusX = markerSize * 0.75;
    final statusY = markerSize * 0.15;

    // Déterminer la couleur du statut
    Color statusColor;
    if (isOnline) {
      statusColor = AppColors.success;
    } else if (lastLoginAt != null) {
      final diff = DateTime.now().difference(lastLoginAt);
      if (diff.inMinutes < 60) {
        statusColor = AppColors.warning; // Actif récemment
      } else {
        statusColor = Colors.grey; // Inactif
      }
    } else {
      statusColor = Colors.grey;
    }

    // Fond blanc
    final bgPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(statusX, statusY), statusSize / 2 + 1.5, bgPaint);

    // Cercle de statut
    final statusPaint = Paint()
      ..color = statusColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(statusX, statusY), statusSize / 2, statusPaint);
  }

  /// Dessine le label de profession sous le pin
  static void drawProfessionLabel(
    Canvas canvas,
    String profession,
    double markerSize,
    double markerHeight,
  ) {
    final abbreviatedText = _abbreviateProfession(profession);
    if (abbreviatedText.isEmpty) return;

    final textSpan = TextSpan(
      text: abbreviatedText,
      style: const TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w600,
        color: Colors.white,
        letterSpacing: 0.3,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 70);

    final labelWidth = textPainter.width + 10;
    final labelHeight = textPainter.height + 4;
    final labelX = (markerSize - labelWidth) / 2;
    final labelY = markerHeight + 2;

    // Fond du label avec coins arrondis
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(labelX, labelY, labelWidth, labelHeight),
      const Radius.circular(6),
    );

    final bgPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.75);
    canvas.drawRRect(bgRect, bgPaint);

    // Texte
    textPainter.paint(
      canvas,
      Offset(labelX + 5, labelY + 2),
    );
  }

  /// Abrège la profession pour l'affichage
  static String _abbreviateProfession(String profession) {
    final p = profession.toLowerCase().trim();
    if (p.isEmpty) return '';

    // Mapping des professions vers des labels courts
    if (p.contains('entrepreneur') || p.contains('business')) return 'Entrepreneur';
    if (p.contains('etudiant') || p.contains('student')) return 'Etudiant';
    if (p.contains('ingenieur') || p.contains('engineer')) return 'Ingenieur';
    if (p.contains('medecin') || p.contains('doctor')) return 'Medecin';
    if (p.contains('avocat') || p.contains('lawyer')) return 'Avocat';
    if (p.contains('enseignant') || p.contains('teacher')) return 'Enseignant';
    if (p.contains('artiste') || p.contains('artist')) return 'Artiste';
    if (p.contains('musicien')) return 'Musicien';
    if (p.contains('informaticien') || p.contains('developer')) return 'Dev';
    if (p.contains('comptable')) return 'Comptable';
    if (p.contains('consultant')) return 'Consultant';

    // Tronquer si trop long
    if (profession.length > 12) {
      return '${profession.substring(0, 10)}...';
    }
    return profession;
  }

  /// Calcule la taille totale du marqueur
  static Size calculateTotalSize(double pinSize, bool hasLabel) {
    // Label désactivé pour un affichage plus épuré
    return Size(pinSize, pinSize);
  }
}
