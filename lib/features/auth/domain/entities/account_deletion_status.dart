/// Où en est la suppression du compte connecté (`account_deletion_requests`).
///
/// `cancelled` et `completed` n'existent pas ici : une suppression annulée ne
/// gêne plus personne, et une suppression menée à terme n'a plus de compte
/// pour la lire.
enum AccountDeletionPhase {
  /// Délai de grâce : le compte est désactivé, l'annulation est possible.
  pending,

  /// Bloquée côté serveur (historique financier, compte plateforme). La
  /// personne peut l'annuler : elle n'a pas à porter un obstacle qu'elle ne
  /// voit pas.
  blocked,

  /// La purge est engagée : le compte Firebase est en cours de suppression,
  /// plus d'annulation possible.
  deleting;

  bool get cancellable => this != AccountDeletionPhase.deleting;

  /// `null` pour `cancelled`, `completed` et tout statut inconnu : aucun
  /// écran n'a rien à dire dans ces cas.
  static AccountDeletionPhase? fromDb(String? status) => switch (status) {
    'pending' => AccountDeletionPhase.pending,
    'blocked' => AccountDeletionPhase.blocked,
    'deleting' => AccountDeletionPhase.deleting,
    _ => null,
  };
}

class AccountDeletionStatus {
  const AccountDeletionStatus({required this.phase, required this.executeAt});

  final AccountDeletionPhase phase;

  /// Date de suppression définitive, en heure locale.
  final DateTime executeAt;

  bool get cancellable => phase.cancellable;

  @override
  bool operator ==(Object other) =>
      other is AccountDeletionStatus &&
      other.phase == phase &&
      other.executeAt == executeAt;

  @override
  int get hashCode => Object.hash(phase, executeAt);
}
