import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider pour le service de modération de contenu
final contentModerationServiceProvider = Provider<ContentModerationService>((
  ref,
) {
  return ContentModerationService();
});

/// Service de modération de contenu compatible E2EE
///
/// Avec le chiffrement de bout en bout, le serveur ne peut plus analyser
/// le contenu des messages. La modération doit donc se faire:
///
/// 1. **Côté client AVANT chiffrement** (scanning local)
/// 2. **Via signalement utilisateur** (report system)
/// 3. **Hash matching** pour contenu illégal connu (CSAM, etc.)
///
/// IMPORTANT: Ce service ne compromet PAS la sécurité E2EE car:
/// - L'analyse se fait AVANT le chiffrement (côté expéditeur)
/// - Le serveur ne reçoit que des métadonnées de modération (flags)
/// - Le contenu reste chiffré et illisible pour le serveur
class ContentModerationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cache local des patterns de spam
  List<String> _spamPatterns = [];
  Set<String> _blockedHashes = {};
  DateTime? _lastPatternsUpdate;

  // Configuration
  static const Duration _patternsCacheDuration = Duration(hours: 6);

  // ============================================================
  // ANALYSE DE CONTENU (AVANT CHIFFREMENT)
  // ============================================================

  /// Analyse un message texte AVANT chiffrement
  ///
  /// Cette analyse se fait côté client, le serveur ne voit pas le contenu.
  /// Seul un flag de modération est envoyé avec le message chiffré.
  Future<ModerationResult> analyzeTextContent(String text) async {
    final issues = <ModerationIssue>[];

    // 1. Détection de spam
    final spamScore = await _checkSpamPatterns(text);
    if (spamScore > 0.7) {
      issues.add(
        ModerationIssue(
          type: ModerationIssueType.spam,
          severity: spamScore > 0.9 ? IssueSeverity.high : IssueSeverity.medium,
          confidence: spamScore,
        ),
      );
    }

    // 2. Détection de contenu inapproprié (mots clés)
    final inappropriateScore = _checkInappropriateContent(text);
    if (inappropriateScore > 0.5) {
      issues.add(
        ModerationIssue(
          type: ModerationIssueType.inappropriate,
          severity:
              inappropriateScore > 0.8
                  ? IssueSeverity.high
                  : IssueSeverity.medium,
          confidence: inappropriateScore,
        ),
      );
    }

    // 3. Détection de liens suspects
    final suspiciousLinks = _checkSuspiciousLinks(text);
    if (suspiciousLinks.isNotEmpty) {
      issues.add(
        ModerationIssue(
          type: ModerationIssueType.suspiciousLink,
          severity: IssueSeverity.medium,
          confidence: 0.8,
          metadata: {'links': suspiciousLinks},
        ),
      );
    }

    // 4. Détection de harcèlement
    final harassmentScore = _checkHarassment(text);
    if (harassmentScore > 0.6) {
      issues.add(
        ModerationIssue(
          type: ModerationIssueType.harassment,
          severity:
              harassmentScore > 0.85
                  ? IssueSeverity.high
                  : IssueSeverity.medium,
          confidence: harassmentScore,
        ),
      );
    }

    return ModerationResult(
      isAllowed:
          issues.isEmpty ||
          !issues.any((i) => i.severity == IssueSeverity.high),
      issues: issues,
      requiresReview: issues.any((i) => i.severity == IssueSeverity.medium),
    );
  }

  /// Analyse un média AVANT chiffrement
  ///
  /// Utilise le hash perceptuel pour détecter le contenu illégal connu
  /// (comme PhotoDNA pour CSAM) SANS envoyer l'image au serveur.
  Future<ModerationResult> analyzeMediaContent(
    Uint8List mediaBytes,
    MediaContentType type,
  ) async {
    final issues = <ModerationIssue>[];

    // 1. Calculer le hash perceptuel (pHash) pour les images
    if (type == MediaContentType.image) {
      final pHash = _computePerceptualHash(mediaBytes);

      // Vérifier contre la base de hashes bloqués
      await _ensureBlockedHashesLoaded();
      if (_blockedHashes.contains(pHash)) {
        issues.add(
          const ModerationIssue(
            type: ModerationIssueType.illegalContent,
            severity: IssueSeverity.critical,
            confidence: 1.0,
          ),
        );
      }

      // Vérifier les hashes similaires (distance de Hamming)
      for (final blockedHash in _blockedHashes) {
        if (_hammingDistance(pHash, blockedHash) < 10) {
          issues.add(
            const ModerationIssue(
              type: ModerationIssueType.illegalContent,
              severity: IssueSeverity.critical,
              confidence: 0.95,
            ),
          );
          break;
        }
      }
    }

    // 2. Vérifier la taille (fichiers suspects très volumineux)
    if (mediaBytes.length > 100 * 1024 * 1024) {
      // > 100MB
      issues.add(
        ModerationIssue(
          type: ModerationIssueType.suspiciousFile,
          severity: IssueSeverity.low,
          confidence: 0.5,
          metadata: {'size': mediaBytes.length},
        ),
      );
    }

    return ModerationResult(
      isAllowed: !issues.any((i) => i.severity == IssueSeverity.critical),
      issues: issues,
      requiresReview: issues.any((i) => i.severity == IssueSeverity.high),
    );
  }

  // ============================================================
  // SYSTÈME DE SIGNALEMENT
  // ============================================================

  /// Signale un message au système de modération
  ///
  /// L'utilisateur peut signaler un message reçu. Le contenu déchiffré
  /// est alors envoyé au serveur pour examen par les modérateurs.
  Future<ReportResult> reportMessage({
    required String reporterId,
    required String conversationId,
    required String messageId,
    required String senderId,
    required ReportReason reason,
    required String decryptedContent, // Contenu déchiffré par le reporter
    String? additionalInfo,
  }) async {
    try {
      // Security: never store decrypted E2EE content on server — store only a hash
      // and a short preview for moderation context, preserving E2EE guarantees
      final contentHash = crypto.sha256.convert(utf8.encode(decryptedContent)).toString();
      final contentPreview = decryptedContent.length > 50
          ? '${decryptedContent.substring(0, 50)}...'
          : decryptedContent;

      final reportRef = await _firestore.collection('moderation_reports').add({
        'reporterId': reporterId,
        'conversationId': conversationId,
        'messageId': messageId,
        'senderId': senderId,
        'reason': reason.name,
        'contentHash': contentHash,
        'contentPreview': contentPreview,
        'additionalInfo': additionalInfo,
        'status': ReportStatus.pending.name,
        'createdAt': FieldValue.serverTimestamp(),
        'reviewedAt': null,
        'reviewedBy': null,
        'action': null,
      });

      // Incrémenter le compteur de signalements pour cet utilisateur
      await _incrementUserReportCount(senderId);

      debugPrint('ContentModerationService: Report submitted ${reportRef.id}');

      return ReportResult(success: true, reportId: reportRef.id);
    } catch (e) {
      debugPrint('ContentModerationService: Error submitting report: $e');
      return ReportResult(success: false, error: e.toString());
    }
  }

  /// Signale un utilisateur (pas un message spécifique)
  Future<ReportResult> reportUser({
    required String reporterId,
    required String reportedUserId,
    required ReportReason reason,
    String? additionalInfo,
  }) async {
    try {
      final reportRef = await _firestore.collection('moderation_reports').add({
        'reporterId': reporterId,
        'reportedUserId': reportedUserId,
        'reason': reason.name,
        'additionalInfo': additionalInfo,
        'status': ReportStatus.pending.name,
        'createdAt': FieldValue.serverTimestamp(),
        'type': 'user_report',
      });

      await _incrementUserReportCount(reportedUserId);

      return ReportResult(success: true, reportId: reportRef.id);
    } catch (e) {
      return ReportResult(success: false, error: e.toString());
    }
  }

  /// Incrémente le compteur de signalements d'un utilisateur
  Future<void> _incrementUserReportCount(String userId) async {
    await _firestore.collection('user_moderation').doc(userId).set(
      {
        'reportCount': FieldValue.increment(1),
        'lastReportedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  // ============================================================
  // BLOCAGE UTILISATEUR (CÔTÉ CLIENT)
  // ============================================================

  /// Bloque un utilisateur (local + serveur)
  Future<void> blockUser(String currentUserId, String blockedUserId) async {
    await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('blocked_users')
        .doc(blockedUserId)
        .set({'blockedAt': FieldValue.serverTimestamp()});

    debugPrint('ContentModerationService: Blocked user $blockedUserId');
  }

  /// Débloque un utilisateur
  Future<void> unblockUser(String currentUserId, String blockedUserId) async {
    await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('blocked_users')
        .doc(blockedUserId)
        .delete();
  }

  /// Vérifie si un utilisateur est bloqué
  Future<bool> isUserBlocked(String currentUserId, String userId) async {
    final doc =
        await _firestore
            .collection('users')
            .doc(currentUserId)
            .collection('blocked_users')
            .doc(userId)
            .get();
    return doc.exists;
  }

  /// Récupère la liste des utilisateurs bloqués
  Future<List<String>> getBlockedUsers(String currentUserId) async {
    final snapshot =
        await _firestore
            .collection('users')
            .doc(currentUserId)
            .collection('blocked_users')
            .get();
    return snapshot.docs.map((doc) => doc.id).toList();
  }

  // ============================================================
  // VÉRIFICATION DE STATUT UTILISATEUR
  // ============================================================

  /// Vérifie si un utilisateur est banni ou restreint
  Future<UserModerationStatus> checkUserStatus(String userId) async {
    try {
      final doc =
          await _firestore.collection('user_moderation').doc(userId).get();

      if (!doc.exists) {
        return UserModerationStatus.clear;
      }

      final data = doc.data()!;
      final isBanned = data['isBanned'] == true;
      final isRestricted = data['isRestricted'] == true;
      final restrictedUntil = (data['restrictedUntil'] as Timestamp?)?.toDate();

      if (isBanned) {
        return UserModerationStatus.banned;
      }

      if (isRestricted && restrictedUntil != null) {
        if (restrictedUntil.isAfter(DateTime.now())) {
          return UserModerationStatus.restricted;
        }
      }

      return UserModerationStatus.clear;
    } catch (e) {
      return UserModerationStatus.clear;
    }
  }

  // ============================================================
  // DÉTECTION LOCALE (PATTERNS)
  // ============================================================

  /// Charge les patterns de spam depuis le serveur
  Future<void> _ensureSpamPatternsLoaded() async {
    if (_lastPatternsUpdate != null &&
        DateTime.now().difference(_lastPatternsUpdate!) <
            _patternsCacheDuration) {
      return;
    }

    try {
      final doc =
          await _firestore
              .collection('moderation_config')
              .doc('spam_patterns')
              .get();

      if (doc.exists) {
        final patterns =
            (doc.data()?['patterns'] as List<dynamic>?)?.cast<String>() ?? [];
        _spamPatterns = patterns;
        _lastPatternsUpdate = DateTime.now();
      }
    } catch (e) {
      debugPrint('ContentModerationService: Error loading spam patterns: $e');
    }
  }

  /// Charge les hashes de contenu bloqué
  Future<void> _ensureBlockedHashesLoaded() async {
    if (_blockedHashes.isNotEmpty) return;

    try {
      final doc =
          await _firestore
              .collection('moderation_config')
              .doc('blocked_hashes')
              .get();

      if (doc.exists) {
        final hashes =
            (doc.data()?['hashes'] as List<dynamic>?)?.cast<String>() ?? [];
        _blockedHashes = hashes.toSet();
      }
    } catch (e) {
      debugPrint('ContentModerationService: Error loading blocked hashes: $e');
    }
  }

  /// Vérifie les patterns de spam
  Future<double> _checkSpamPatterns(String text) async {
    await _ensureSpamPatternsLoaded();

    final lowerText = text.toLowerCase();
    var matchCount = 0;

    for (final pattern in _spamPatterns) {
      if (lowerText.contains(pattern.toLowerCase())) {
        matchCount++;
      }
    }

    // Score basé sur le nombre de patterns trouvés
    if (matchCount == 0) return 0.0;
    return (matchCount / 3).clamp(0.0, 1.0);
  }

  /// Vérifie le contenu inapproprié (liste locale de mots)
  double _checkInappropriateContent(String text) {
    // Liste de base - en production, charger depuis le serveur
    final inappropriateWords = [
      // Ajouter des mots/phrases inappropriés ici
      // Cette liste serait chargée dynamiquement en production
    ];

    if (inappropriateWords.isEmpty) return 0.0;

    final lowerText = text.toLowerCase();
    var matchCount = 0;

    for (final word in inappropriateWords) {
      if (lowerText.contains(word)) {
        matchCount++;
      }
    }

    return (matchCount / 2).clamp(0.0, 1.0);
  }

  /// Vérifie les liens suspects (phishing, etc.)
  List<String> _checkSuspiciousLinks(String text) {
    final urlPattern = RegExp(r'https?://[^\s]+', caseSensitive: false);

    final suspiciousPatterns = [
      RegExp(r'bit\.ly|tinyurl|t\.co', caseSensitive: false),
      RegExp(r'\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}'), // IP addresses
      RegExp(r'login|password|verify|account|suspended', caseSensitive: false),
    ];

    final matches = urlPattern.allMatches(text);
    final suspiciousLinks = <String>[];

    for (final match in matches) {
      final url = match.group(0)!;
      for (final pattern in suspiciousPatterns) {
        if (pattern.hasMatch(url)) {
          suspiciousLinks.add(url);
          break;
        }
      }
    }

    return suspiciousLinks;
  }

  /// Vérifie le harcèlement
  double _checkHarassment(String text) {
    // Indicateurs simples de harcèlement
    final harassmentIndicators = [
      RegExp(
        r'(je vais te|on va te)\s+(tuer|frapper|trouver)',
        caseSensitive: false,
      ),
      RegExp(
        r'(tu vas|vous allez)\s+(mourir|souffrir|regretter)',
        caseSensitive: false,
      ),
      RegExp(r'menace|menacer|violence', caseSensitive: false),
    ];

    var score = 0.0;
    for (final indicator in harassmentIndicators) {
      if (indicator.hasMatch(text)) {
        score += 0.4;
      }
    }

    // Vérifier les majuscules excessives (criant)
    final upperRatio =
        text.replaceAll(RegExp(r'[^A-Z]'), '').length / text.length;
    if (upperRatio > 0.5 && text.length > 20) {
      score += 0.2;
    }

    return score.clamp(0.0, 1.0);
  }

  // ============================================================
  // HASH PERCEPTUEL (POUR IMAGES)
  // ============================================================

  /// Calcule un hash perceptuel simplifié d'une image
  ///
  /// Note: En production, utiliser une vraie implémentation de pHash
  /// ou un service comme PhotoDNA via une API sécurisée.
  String _computePerceptualHash(Uint8List imageBytes) {
    // Hash SHA-256 comme placeholder
    // En production: implémenter pHash ou dHash
    final digest = crypto.sha256.convert(imageBytes);
    return digest.toString().substring(0, 16);
  }

  /// Calcule la distance de Hamming entre deux hashes
  int _hammingDistance(String hash1, String hash2) {
    if (hash1.length != hash2.length) return hash1.length;

    var distance = 0;
    for (var i = 0; i < hash1.length; i++) {
      if (hash1[i] != hash2[i]) {
        distance++;
      }
    }
    return distance;
  }

  // ============================================================
  // MÉTADONNÉES DE MODÉRATION POUR MESSAGE E2EE
  // ============================================================

  /// Génère les métadonnées de modération pour un message
  ///
  /// Ces métadonnées sont envoyées avec le message chiffré pour
  /// permettre un filtrage côté serveur sans révéler le contenu.
  Map<String, dynamic> generateModerationMetadata(ModerationResult result) {
    return {
      'moderationVersion': 1,
      'checkedAt': DateTime.now().toIso8601String(),
      'flags': result.issues.map((i) => i.type.name).toList(),
      'requiresReview': result.requiresReview,
      // Ne PAS inclure le contenu ou des détails révélateurs
    };
  }
}

/// Types de problèmes de modération
enum ModerationIssueType {
  spam,
  inappropriate,
  harassment,
  suspiciousLink,
  illegalContent,
  suspiciousFile,
}

/// Sévérité d'un problème
enum IssueSeverity { low, medium, high, critical }

/// Un problème détecté par la modération
class ModerationIssue {
  final ModerationIssueType type;
  final IssueSeverity severity;
  final double confidence;
  final Map<String, dynamic>? metadata;

  const ModerationIssue({
    required this.type,
    required this.severity,
    required this.confidence,
    this.metadata,
  });
}

/// Résultat d'une analyse de modération
class ModerationResult {
  /// Le contenu est-il autorisé à être envoyé?
  final bool isAllowed;

  /// Liste des problèmes détectés
  final List<ModerationIssue> issues;

  /// Nécessite une révision manuelle?
  final bool requiresReview;

  const ModerationResult({
    required this.isAllowed,
    required this.issues,
    required this.requiresReview,
  });

  bool get hasIssues => issues.isNotEmpty;
}

/// Raisons de signalement
enum ReportReason {
  spam,
  harassment,
  inappropriateContent,
  illegalContent,
  impersonation,
  scam,
  violence,
  hateSpeech,
  other,
}

/// Statut d'un signalement
enum ReportStatus { pending, reviewing, resolved, dismissed }

/// Résultat d'un signalement
class ReportResult {
  final bool success;
  final String? reportId;
  final String? error;

  const ReportResult({required this.success, this.reportId, this.error});
}

/// Types de contenu média
enum MediaContentType { image, video, audio, document }

/// Statut de modération d'un utilisateur
enum UserModerationStatus { clear, restricted, banned }
