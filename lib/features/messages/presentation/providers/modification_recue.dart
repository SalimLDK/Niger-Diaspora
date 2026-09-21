import '../../../../core/services/e2ee/undecryptable_placeholders.dart';
import '../../domain/entities/message_entity.dart';

/// Application d'une **modification de texte** reçue par le flux des mises à
/// jour (`getMessageUpdatesStream`) sur une discussion en clair.
///
/// Ce flux livre la ligne BRUTE : son contenu est le chiffré au repos, qu'on
/// ne peut pas afficher, et qu'on ne peut pas non plus re-déchiffrer à chaque
/// passage — pour Signal, un second déchiffrement du même message échoue, le
/// Double Ratchet ayant consommé la clé au premier. L'écran se contentait donc
/// d'en reprendre les métadonnées, et le nouveau texte d'un message modifié
/// n'apparaissait qu'à la réouverture de la discussion.
///
/// Une modification, elle, est **rechiffrée de neuf** par `editMessage` : la
/// nouvelle version se déchiffre une fois, comme un message neuf. La règle est
/// donc de la relire déchiffrée **une seule fois par version**, repérée par
/// son `editedAt`, et seulement quand elle est plus récente que celle affichée.

/// Vrai si [recue] annonce une version plus récente que [affichee].
bool modificationPlusRecente({
  required DateTime? affichee,
  required DateTime? recue,
}) {
  if (recue == null) return false;
  if (affichee == null) return true;
  return recue.isAfter(affichee);
}

/// Le message à afficher une fois la version modifiée relue déchiffrée.
///
/// - Relu pas plus récent que l'affiché (relecture tardive, écho de notre
///   propre modification déjà appliquée) : rien ne change.
/// - Relu illisible : on garde le texte affiché — jamais un placeholder
///   par-dessus du texte clair. Si le message est **le nôtre**, on adopte tout
///   de même la date : son auteur ne peut pas le déchiffrer (le ratchet ne
///   garde pas la clé d'un message émis) et son texte clair est déjà à
///   l'écran, posé par la modification optimiste. Sans ça, chaque accusé de
///   lecture relancerait une relecture vaine. Chez le destinataire, la date
///   n'est pas adoptée : une session rétablie plus tard permettra un nouvel
///   essai, au lieu d'afficher « modifié » sur l'ancien texte pour toujours.
/// - Sinon : nouveau texte et nouvelle date.
MessageEntity appliquerModificationRelue({
  required MessageEntity affiche,
  required MessageEntity relu,
  required bool estAMoi,
}) {
  if (!modificationPlusRecente(
    affichee: affiche.editedAt,
    recue: relu.editedAt,
  )) {
    return affiche;
  }
  if (isUndecryptableContent(relu.content)) {
    return estAMoi ? affiche.copyWith(editedAt: relu.editedAt) : affiche;
  }
  return affiche.copyWith(content: relu.content, editedAt: relu.editedAt);
}
