/// Marqueurs ecrits par le backend lors de la suppression d'un compte.
///
/// `functions/index.js` anonymise les documents qui referencent l'utilisateur
/// supprime : il y pose `deleted_user` comme identifiant et « Utilisateur
/// supprime » comme nom. Ce nom est donc une **donnee**, figee en francais dans
/// la base, et non un libelle traduisible.
///
/// Le comparer a `l10n.deletedUser` ne fonctionnerait qu'en francais : en
/// anglais la cle vaut « Deleted user » et la condition ne serait jamais vraie.
/// Pour afficher, utiliser `l10n.deletedUser` ; pour reconnaitre, utiliser les
/// constantes ci-dessous.
class DeletedAccount {
  const DeletedAccount._();

  /// Identifiant substitue aux references de l'utilisateur supprime.
  static const String id = 'deleted_user';

  /// Nom stocke en base par l'anonymisation. Figé en francais, jamais traduit.
  static const String storedName = 'Utilisateur supprimé';
}
