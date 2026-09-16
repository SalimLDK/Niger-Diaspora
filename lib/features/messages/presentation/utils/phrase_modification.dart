import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/message_entity.dart';

/// La phrase qui dit pourquoi « Modifier » est refusé.
///
/// Une seule table de correspondance, partagée par les deux endroits qui
/// doivent le dire : le sous-titre de l'entrée de menu désactivée, et le
/// message qui suit une tentative refusée. Les avoir séparés, c'était
/// l'occasion d'en oublier un — l'écran annonçait déjà « délai de modification
/// expiré » pour une coupure réseau, faute de savoir distinguer les causes.
String phraseModificationImpossible(
  AppLocalizations l10n,
  MotifModificationImpossible motif,
) {
  return switch (motif) {
    MotifModificationImpossible.pasLauteur => l10n.editImpossibleNotAuthor,
    MotifModificationImpossible.pasDuTexte => l10n.editImpossibleNotText,
    MotifModificationImpossible.supprime => l10n.editImpossibleDeleted,
    MotifModificationImpossible.pasEncoreEnvoye => l10n.editImpossibleNotSent,
    MotifModificationImpossible.delaiExpire => l10n.editTimeExpired,
  };
}
