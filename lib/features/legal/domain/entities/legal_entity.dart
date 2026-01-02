import 'package:freezed_annotation/freezed_annotation.dart';

part 'legal_entity.freezed.dart';

/// Entité représentant un contenu légal (CGU, Politique de confidentialité, etc.)
@freezed
class LegalContent with _$LegalContent {
  const LegalContent._();

  const factory LegalContent({
    required String id,
    required LegalContentType type,
    required String title,
    required String version,
    required List<LegalSection> sections,
    required DateTime updatedAt,
    String? summary,
  }) = _LegalContent;

  /// Vérifie si le contenu a été mis à jour récemment (30 jours)
  bool get isRecentlyUpdated {
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    return updatedAt.isAfter(thirtyDaysAgo);
  }

  /// Retourne le contenu complet formaté
  String get fullContent {
    return sections.map((s) => '${s.title}\n\n${s.content}').join('\n\n---\n\n');
  }
}

/// Types de contenu légal
enum LegalContentType {
  terms,
  privacy,
  conduct,
}

/// Extension pour convertir le type en string et vice versa
extension LegalContentTypeX on LegalContentType {
  String get value {
    switch (this) {
      case LegalContentType.terms:
        return 'terms';
      case LegalContentType.privacy:
        return 'privacy';
      case LegalContentType.conduct:
        return 'conduct';
    }
  }

  String get displayName {
    switch (this) {
      case LegalContentType.terms:
        return 'Conditions Générales d\'Utilisation';
      case LegalContentType.privacy:
        return 'Politique de Confidentialité';
      case LegalContentType.conduct:
        return 'Code de Conduite';
    }
  }

  static LegalContentType fromString(String value) {
    switch (value) {
      case 'terms':
        return LegalContentType.terms;
      case 'privacy':
        return LegalContentType.privacy;
      case 'conduct':
        return LegalContentType.conduct;
      default:
        return LegalContentType.terms;
    }
  }
}

/// Entité représentant une section de contenu légal
@freezed
class LegalSection with _$LegalSection {
  const factory LegalSection({
    required String title,
    required String content,
    @Default(0) int order,
  }) = _LegalSection;
}

/// Entité représentant l'acceptation des conditions par l'utilisateur
@freezed
class LegalAcceptance with _$LegalAcceptance {
  const LegalAcceptance._();

  const factory LegalAcceptance({
    required String termsVersion,
    required String privacyVersion,
    required DateTime acceptedAt,
    String? conductVersion,
  }) = _LegalAcceptance;

  /// Vérifie si l'acceptation est à jour par rapport aux versions fournies
  bool isUpToDate({
    required String currentTermsVersion,
    required String currentPrivacyVersion,
    String? currentConductVersion,
  }) {
    if (termsVersion != currentTermsVersion) return false;
    if (privacyVersion != currentPrivacyVersion) return false;
    if (currentConductVersion != null && conductVersion != currentConductVersion) {
      return false;
    }
    return true;
  }
}

/// État de l'acceptation légale
enum LegalAcceptanceStatus {
  /// Jamais accepté
  neverAccepted,

  /// Accepté mais mise à jour nécessaire
  needsUpdate,

  /// À jour
  upToDate,
}
