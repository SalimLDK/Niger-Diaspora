import '../../../../core/services/e2ee/undecryptable_placeholders.dart';
import '../../domain/entities/message_entity.dart';

/// Application d'une ligne reçue par le flux des mises à jour
/// (`getMessageUpdatesStream`) sur une discussion en clair : métadonnées,
/// **modification de texte**, **suppression pour tout le monde**.
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

/// Le message à afficher quand le flux des mises à jour livre [brut], la
/// ligne non déchiffrée d'un message déjà à l'écran sous la forme [affiche].
///
/// **Cas courant** (accusé, réaction, épingle, étoile) : les métadonnées
/// viennent de [brut], tout ce qui est chiffré au repos vient de [affiche].
/// Re-déchiffrer est impossible pour Signal (voir l'en-tête) ; et depuis que
/// les charges annexes et les médias sont chiffrés, la ligne brute n'en porte
/// que le blob — sans ce rappel, le premier accusé de lecture faisait
/// disparaître la carte partagée ou rendait la photo illisible.
///
/// La date de modification suit le TEXTE, pas la ligne : elle n'avance
/// qu'avec lui, par [appliquerModificationRelue]. L'adopter ici afficherait
/// « modifié » sur l'ancien texte, et une relecture échouée (hors ligne) ne
/// serait jamais retentée.
///
/// **Supprimé pour tout le monde** : [brut] est pris tel quel. Le serveur a
/// déjà vidé la ligne (`deleteMessageForEveryone` : contenu, fichier,
/// annexes, clé du média) — c'est exactement l'état voulu. Le rappel du cas
/// courant faisait l'inverse : la bulle montrait bien la pierre tombale,
/// mais le texte clair, la carte partagée et la clé du média restaient dans
/// l'état de l'écran, à portée de la copie, du transfert et du cache.
MessageEntity fusionnerLigneBrute({
  required MessageEntity affiche,
  required MessageEntity brut,
}) {
  if (brut.deletedForEveryone) return brut.videPourSuppression();
  return brut.copyWith(
    content: affiche.content,
    fileUrl: affiche.fileUrl,
    mediaChiffre: affiche.mediaChiffre,
    fileName: affiche.fileName,
    postData: affiche.postData,
    eventData: affiche.eventData,
    productData: affiche.productData,
    linkPreviewData: affiche.linkPreviewData,
    replyToMessageData: affiche.replyToMessageData,
    editedAt: affiche.editedAt,
    // Première modification d'un message qui ne l'avait jamais été : sans
    // ça, `editedAt: null` laissait passer la date de la ligne — le cas le
    // plus courant affichait « modifié » sur l'ancien texte.
    effacerDateDeModification: affiche.editedAt == null,
  );
}

/// [messages] où chaque message supprimé pour tout le monde est réduit à sa
/// coquille (`MessageEntity.videPourSuppression`). Rend la liste elle-même,
/// sans copie, quand aucun ne l'est.
///
/// Appliqué à chaque écriture de l'état de l'écran, pas dans un chemin
/// particulier : un message MLS supprimé arrive **déchiffré**, drapeau posé
/// mais texte intact (`MlsGateway._avecMetadonnees` ne fait que recoller
/// `deletedForEveryone`), et il arrive par le temps réel — qui relit le fil
/// entier et remplace par identifiant — comme par le cache ou la pagination.
///
/// Après `_reconcileEcho`, jamais avant : il garde le texte local quand
/// l'entrant est vide, et rendrait donc le clair à une coquille.
List<MessageEntity> sansContenuSupprime(List<MessageEntity> messages) {
  if (!messages.any((m) => m.deletedForEveryone)) return messages;
  return [
    for (final m in messages)
      m.deletedForEveryone ? m.videPourSuppression() : m,
  ];
}

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
/// - Message supprimé pour tout le monde, à l'écran ou dans la relecture :
///   rien ne change. Une relecture partie avant la suppression et revenue
///   après remettrait sinon le texte modifié sous la pierre tombale.
/// - Sinon : nouveau texte et nouvelle date.
MessageEntity appliquerModificationRelue({
  required MessageEntity affiche,
  required MessageEntity relu,
  required bool estAMoi,
}) {
  if (affiche.deletedForEveryone || relu.deletedForEveryone) return affiche;
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
