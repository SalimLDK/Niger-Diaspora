import 'dart:io';

import 'package:flutter/material.dart';

import 'play_integrity_service.dart';

/// Niveaux de sécurité requis pour différentes opérations
enum SecurityLevel {
  /// Aucune vérification requise
  none,

  /// Appareil doit passer les vérifications de base (pas rooté/émulateur)
  basicDevice,

  /// App doit être installée depuis le Play Store + appareil sécurisé
  playStoreRequired,

  /// Niveau maximal: Play Store + intégrité forte + licence vérifiée
  highSecurity,
}

/// Résultat d'une vérification de sécurité
class SecurityCheckResult {
  final bool isAllowed;
  final String? denialReason;
  final SecurityLevel requiredLevel;
  final PlayIntegrityVerdict? verdict;

  const SecurityCheckResult({
    required this.isAllowed,
    this.denialReason,
    required this.requiredLevel,
    this.verdict,
  });

  factory SecurityCheckResult.allowed(PlayIntegrityVerdict? verdict) {
    return SecurityCheckResult(
      isAllowed: true,
      requiredLevel: SecurityLevel.none,
      verdict: verdict,
    );
  }

  factory SecurityCheckResult.denied({
    required String reason,
    required SecurityLevel requiredLevel,
    PlayIntegrityVerdict? verdict,
  }) {
    return SecurityCheckResult(
      isAllowed: false,
      denialReason: reason,
      requiredLevel: requiredLevel,
      verdict: verdict,
    );
  }
}

/// Service pour gérer les vérifications de sécurité avant les opérations sensibles
class SecurityGateService {
  static final SecurityGateService _instance = SecurityGateService._internal();
  factory SecurityGateService() => _instance;
  SecurityGateService._internal();

  final _integrityService = PlayIntegrityService();

  /// Cache du dernier verdict (valide pendant 5 minutes)
  PlayIntegrityVerdict? _cachedVerdict;
  DateTime? _cacheTime;
  static const _cacheDuration = Duration(minutes: 5);

  /// Vérifie si une opération est autorisée selon le niveau de sécurité requis
  Future<SecurityCheckResult> checkSecurity(SecurityLevel requiredLevel) async {
    // Niveau none = toujours autorisé
    if (requiredLevel == SecurityLevel.none) {
      return SecurityCheckResult.allowed(null);
    }

    // iOS n'a pas Play Integrity - autoriser par défaut
    if (!Platform.isAndroid) {
      return SecurityCheckResult.allowed(null);
    }

    // Utiliser le cache si valide
    final verdict = await _getVerdict();

    if (verdict.hasError) {
      // En cas d'erreur, autoriser les niveaux bas, bloquer les niveaux hauts
      if (requiredLevel == SecurityLevel.basicDevice) {
        return SecurityCheckResult.allowed(verdict);
      }
      return SecurityCheckResult.denied(
        reason: 'Impossible de vérifier la sécurité: ${verdict.error}',
        requiredLevel: requiredLevel,
        verdict: verdict,
      );
    }

    switch (requiredLevel) {
      case SecurityLevel.none:
        return SecurityCheckResult.allowed(verdict);

      case SecurityLevel.basicDevice:
        if (verdict.deviceIntegrity.meetsBasicIntegrity) {
          return SecurityCheckResult.allowed(verdict);
        }
        return SecurityCheckResult.denied(
          reason: 'Cet appareil ne répond pas aux exigences de sécurité de base.',
          requiredLevel: requiredLevel,
          verdict: verdict,
        );

      case SecurityLevel.playStoreRequired:
        if (!verdict.deviceIntegrity.meetsBasicIntegrity) {
          return SecurityCheckResult.denied(
            reason: 'Cet appareil ne répond pas aux exigences de sécurité.',
            requiredLevel: requiredLevel,
            verdict: verdict,
          );
        }
        if (!verdict.isPlayLicensed) {
          return SecurityCheckResult.denied(
            reason: 'Cette fonctionnalité nécessite l\'installation depuis Google Play Store.',
            requiredLevel: requiredLevel,
            verdict: verdict,
          );
        }
        return SecurityCheckResult.allowed(verdict);

      case SecurityLevel.highSecurity:
        if (!verdict.isSecure) {
          if (!verdict.isPlayLicensed) {
            return SecurityCheckResult.denied(
              reason: 'Cette fonctionnalité nécessite l\'installation depuis Google Play Store.',
              requiredLevel: requiredLevel,
              verdict: verdict,
            );
          }
          return SecurityCheckResult.denied(
            reason: 'Cet appareil ne répond pas aux exigences de sécurité élevées.',
            requiredLevel: requiredLevel,
            verdict: verdict,
          );
        }
        return SecurityCheckResult.allowed(verdict);
    }
  }

  /// Obtient le verdict (depuis le cache ou nouveau)
  Future<PlayIntegrityVerdict> _getVerdict() async {
    if (_cachedVerdict != null &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < _cacheDuration) {
      return _cachedVerdict!;
    }

    final verdict = await _integrityService.verifyWithCloudFunction();
    _cachedVerdict = verdict;
    _cacheTime = DateTime.now();
    return verdict;
  }

  /// Invalide le cache (appeler après une action importante)
  void invalidateCache() {
    _cachedVerdict = null;
    _cacheTime = null;
  }

  // ============================================================================
  // MÉTHODES PRATIQUES POUR CHAQUE TYPE D'OPÉRATION
  // ============================================================================

  /// Vérifie si les paiements sont autorisés
  Future<SecurityCheckResult> canMakePayment() async {
    return checkSecurity(SecurityLevel.playStoreRequired);
  }

  /// Vérifie si les transferts d'argent sont autorisés
  Future<SecurityCheckResult> canMakeTransfer() async {
    return checkSecurity(SecurityLevel.playStoreRequired);
  }

  /// Vérifie si l'utilisateur peut accéder au marketplace (achat/vente)
  Future<SecurityCheckResult> canUseMarketplace() async {
    return checkSecurity(SecurityLevel.playStoreRequired);
  }

  /// Vérifie les fonctions de base (messagerie, groupes, etc.)
  Future<SecurityCheckResult> canUseBasicFeatures() async {
    return checkSecurity(SecurityLevel.basicDevice);
  }

  // ============================================================================
  // HELPER POUR AFFICHER LES DIALOGUES
  // ============================================================================

  /// Affiche un dialogue si la sécurité n'est pas suffisante
  /// Retourne true si autorisé, false sinon
  Future<bool> checkAndShowDialog(
    BuildContext context, {
    required SecurityLevel level,
    String? customTitle,
    String? customMessage,
  }) async {
    final result = await checkSecurity(level);

    if (result.isAllowed) {
      return true;
    }

    if (!context.mounted) return false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(customTitle ?? 'Accès restreint'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(customMessage ?? result.denialReason ?? 'Accès non autorisé'),
            if (!result.verdict!.isPlayLicensed) ...[
              const SizedBox(height: 16),
              const Text(
                'Pour accéder à cette fonctionnalité, veuillez installer '
                'l\'application depuis Google Play Store.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Compris'),
          ),
          if (!result.verdict!.isPlayLicensed)
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _openPlayStore();
              },
              child: const Text('Ouvrir Play Store'),
            ),
        ],
      ),
    );

    return false;
  }

  void _openPlayStore() {
    // Utiliser url_launcher pour ouvrir le Play Store
    // launchUrl(Uri.parse('https://play.google.com/store/apps/details?id=com.diasponiger.diasponiger'));
  }
}
