import 'package:flutter/material.dart';

/// Back-office admin palette — « grille d'outil ».
///
/// Écrans d'administration (tableau de bord, gestion des utilisateurs, audit,
/// rôles). Registre volontairement plus froid et plus dense que le reste de
/// l'app grand public : c'est une interface de travail, pas une surface
/// éditoriale.
///
/// Règle transversale du design system : l'accent orange
/// (`AppColors.primaryDark` en clair) est réservé à l'app grand public — le
/// back-office utilise le **bleu d'action** [actionBlue] pour l'action
/// principale et l'état actif, jamais l'orange.
///
/// Usage : `AdminColors.actionBlue` etc.
class AdminColors {
  AdminColors._();

  // ============================================
  // FONDS & SURFACES
  // ============================================

  /// Fond de page.
  static const bg = Color(0xFFF4F5F7);

  /// Surface (cartes, panneaux, tableaux).
  static const surface = Color(0xFFFFFFFF);

  /// Surface alternée (lignes zébrées, en-têtes de tableau).
  static const surfaceAlt = Color(0xFFFAFBFC);

  // ============================================
  // RAIL LATÉRAL (navigation sombre)
  // ============================================

  /// Fond du rail latéral.
  static const rail = Color(0xFF16181D);

  /// Texte actif / titre sur le rail.
  static const railText = Color(0xFFF4F5F7);

  /// Texte secondaire sur le rail.
  static const railText2 = Color(0xFFC6CBD4);

  /// Texte tertiaire / désactivé sur le rail.
  static const railText3 = Color(0xFF8A919E);

  // ============================================
  // TEXTE (échelle claire → dense)
  // ============================================

  /// Texte principal.
  static const text = Color(0xFF16181D);

  /// Texte secondaire.
  static const text2 = Color(0xFF3F444D);

  /// Texte tertiaire.
  static const text3 = Color(0xFF6C727C);

  // ============================================
  // BORDURES
  // ============================================

  /// Bordure standard.
  static const border = Color(0xFFE3E5E9);

  /// Bordure subtile (séparateurs internes).
  static const borderSubtle = Color(0xFFEDEFF2);

  // ============================================
  // BLEU D'ACTION (action principale, état actif)
  // ============================================

  /// Action principale, état actif.
  static const actionBlue = Color(0xFF2C6BED);

  /// Variante claire (survol, icônes).
  static const actionBlueLight = Color(0xFF3B82F6);

  /// Fond bleu léger (lignes/puces d'information).
  static const actionBlueBg = Color(0xFFEFF6FF);

  // ============================================
  // STATUTS — texte foncé / texte accentué / fond
  // ============================================

  // Rouge — erreur, danger.
  static const statusRed = Color(0xFFDC2626);
  static const statusRedStrong = Color(0xFFB91C1C);
  static const statusRedBg = Color(0xFFFEF2F2);

  // Ambre — avertissement, en attente.
  static const statusAmber = Color(0xFFB45309);
  static const statusAmberStrong = Color(0xFF92400E);
  static const statusAmberBg = Color(0xFFFEF3C7);

  // Vert — succès, actif, validé.
  static const statusGreen = Color(0xFF15803D);
  static const statusGreenStrong = Color(0xFF047857);
  static const statusGreenBg = Color(0xFFECFDF5);

  // Violet — rôle, catégorie particulière.
  static const statusPurple = Color(0xFF6D28D9);
  static const statusPurpleBg = Color(0xFFF5F3FF);

  // Gris — neutre, archivé.
  static const statusGray = Color(0xFF475569);
  static const statusGrayBg = Color(0xFFF1F5F9);

  // ============================================
  // LIGNES D'ALERTE (fonds de rangée très pâles)
  // ============================================

  /// Fond de rangée d'alerte rouge.
  static const alertRowRed = Color(0xFFFFFBFB);

  /// Fond de rangée d'alerte ambre.
  static const alertRowAmber = Color(0xFFFFFBF5);

  /// Fond de rangée d'information bleue.
  static const alertRowBlue = Color(0xFFFAFBFF);

  /// Bordure d'alerte danger.
  static const alertBorderRed = Color(0xFFFCA5A5);

  /// Bordure d'alerte ambre.
  static const alertBorderAmber = Color(0xFFFDE68A);
}
