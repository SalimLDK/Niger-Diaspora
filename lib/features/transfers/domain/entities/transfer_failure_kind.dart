/// Ce qui est arrivé à l'argent quand un transfert n'aboutit pas.
///
/// C'est la seule information que l'utilisateur cherche vraiment, et les six
/// statuts génériques (`TransactionStatus`) ne la portent pas : « Échoué »
/// ne dit pas si le compte a été débité.
enum TransferDebitState {
  /// Rien n'a été prélevé.
  notCharged,

  /// Le montant est parti et n'est pas encore revenu (retenu, en litige).
  charged,

  /// L'issue n'est pas connue — typiquement une coupure au mauvais moment.
  /// Ne jamais proposer de réessayer dans ce cas : risque de double débit.
  uncertain,
}

/// Ce qu'on peut proposer de faire ensuite.
enum TransferFailureAction {
  /// Refaire le transfert à l'identique est sûr.
  retry,

  /// Le bénéficiaire est en cause : il faut le corriger avant de refaire.
  fixRecipient,

  /// Seul le support peut trancher.
  contactSupport,

  /// Rien à faire — l'échec est une protection qui a fonctionné.
  none,
}

/// Nature détaillée d'un échec de transfert (maquette 3a).
///
/// `TransactionStatus.failed` mélangeait des situations qui n'appellent pas du
/// tout la même réaction : un refus de carte (rien débité, on réessaie) et un
/// blocage opérateur (argent parti, surtout ne pas réessayer) affichaient le
/// même « Le transfert a échoué. Veuillez réessayer. »
///
/// ⚠ Aucun producteur ne remplit `failureReason` aujourd'hui : ni les
/// fonctions Cloud du dépôt, ni l'intégration MyNita (qui n'existe que comme
/// valeur d'enum côté client). Ces états sont donc inatteignables tant que
/// l'intégration du prestataire de paiement n'écrit pas de motif. La
/// classification retombe sur [unknown], qui reproduit exactement le
/// comportement précédent — rien ne régresse en attendant.
enum TransferFailureKind {
  /// L'opérateur de mobile money a refusé ou retenu le versement
  /// (plafond du portefeuille, KYC incomplet, compte gelé, panne opérateur).
  operatorBlocked(
    debitState: TransferDebitState.charged,
    action: TransferFailureAction.contactSupport,
  ),

  /// Un transfert identique était déjà en cours : le second a été bloqué
  /// avant tout prélèvement. C'est une protection, pas une panne.
  duplicatePrevented(
    debitState: TransferDebitState.notCharged,
    action: TransferFailureAction.none,
  ),

  /// Le numéro ou le portefeuille du bénéficiaire est invalide/inexistant.
  invalidRecipient(
    debitState: TransferDebitState.notCharged,
    action: TransferFailureAction.fixRecipient,
  ),

  /// La banque ou l'émetteur de la carte a refusé le paiement.
  paymentDeclined(
    debitState: TransferDebitState.notCharged,
    action: TransferFailureAction.retry,
  ),

  /// Provision insuffisante sur le moyen de paiement.
  insufficientFunds(
    debitState: TransferDebitState.notCharged,
    action: TransferFailureAction.retry,
  ),

  /// Coupure pendant le traitement : l'issue réelle n'est pas connue.
  networkTimeout(
    debitState: TransferDebitState.uncertain,
    action: TransferFailureAction.contactSupport,
  ),

  /// Motif absent ou non reconnu.
  unknown(
    debitState: TransferDebitState.uncertain,
    action: TransferFailureAction.retry,
  );

  final TransferDebitState debitState;
  final TransferFailureAction action;

  const TransferFailureKind({
    required this.debitState,
    required this.action,
  });

  /// Classe un motif brut (code prestataire ou phrase libre).
  ///
  /// Volontairement permissif : on cherche des sous-chaînes plutôt que des
  /// codes exacts, parce que le format réel dépendra du prestataire branché.
  /// Tout ce qui n'est pas reconnu reste [unknown] — on préfère un message
  /// générique à un message précis et faux.
  static TransferFailureKind fromReason(String? reason) {
    if (reason == null || reason.trim().isEmpty) return unknown;
    final r = reason.toLowerCase();

    bool has(List<String> needles) => needles.any(r.contains);

    if (has([
      'duplicate',
      'already_processed',
      'idempot',
      'double',
    ])) {
      return duplicatePrevented;
    }
    if (has([
      'insufficient_funds',
      'insufficient funds',
      'provision',
      'solde insuffisant',
    ])) {
      return insufficientFunds;
    }
    if (has([
      'invalid_recipient',
      'invalid_account',
      'unknown_account',
      'account_not_found',
      'invalid_phone',
      'beneficiaire',
      'bénéficiaire',
    ])) {
      return invalidRecipient;
    }
    if (has([
      'operator',
      'opérateur',
      'operateur',
      'wallet_limit',
      'kyc',
      'frozen',
      'blocked',
      'bloqu',
      'held',
    ])) {
      return operatorBlocked;
    }
    if (has([
      'timeout',
      'timed_out',
      'network',
      'unreachable',
      'gateway',
    ])) {
      return networkTimeout;
    }
    if (has([
      'card_declined',
      'declined',
      'do_not_honor',
      'refus',
      'payment_failed',
    ])) {
      return paymentDeclined;
    }
    return unknown;
  }
}
