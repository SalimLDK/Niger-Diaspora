import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'profile_entity.dart';

/// Extension pour gérer l'affichage des profils null/supprimés
extension ProfileDisplayExtension on ProfileEntity? {
  /// Retourne true si le profil est supprimé (null)
  bool get isDeleted => this == null;

  /// Retourne le nom d'affichage ou "Utilisateur supprimé"
  String displayNameOrDeleted(AppLocalizations l10n) {
    if (this == null) return l10n.deletedUser;
    return this!.displayName?.isNotEmpty == true
        ? this!.displayName!
        : l10n.user;
  }

  /// Retourne l'URL de la photo ou null si profil supprimé
  String? photoUrlOrNull() {
    return this?.photoUrl;
  }

  /// Retourne la biographie ou un message si profil supprimé
  String bioOrDeleted(AppLocalizations l10n) {
    if (this == null) return l10n.accountNoLongerExists;
    return this!.bio ?? '';
  }
}
