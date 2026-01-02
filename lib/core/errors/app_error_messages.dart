import 'dart:ui';

/// Messages d'erreur localisés et user-friendly (FR/EN)
///
/// Ces messages sont conçus pour être compréhensibles par l'utilisateur
/// et ne pas exposer de détails techniques
class AppErrorMessages {
  AppErrorMessages._();

  /// Langue actuelle (par défaut: français)
  static Locale _currentLocale = const Locale('fr');

  /// Définit la langue actuelle
  static void setLocale(Locale locale) {
    _currentLocale = locale;
  }

  /// Retourne la langue actuelle
  static Locale get currentLocale => _currentLocale;

  /// Vérifie si la langue est l'anglais
  static bool get _isEnglish => _currentLocale.languageCode == 'en';

  // ==================== Erreurs Générales / General Errors ====================

  static String get unexpectedError => _isEnglish
      ? 'An unexpected error occurred. Please try again.'
      : 'Une erreur inattendue s\'est produite. Veuillez réessayer.';

  static String get serverError => _isEnglish
      ? 'The server is not responding. Please try again later.'
      : 'Le serveur ne répond pas. Veuillez réessayer plus tard.';

  static String get dataError => _isEnglish
      ? 'Unable to process data. Please try again.'
      : 'Impossible de traiter les données. Veuillez réessayer.';

  static String get formatError => _isEnglish
      ? 'Invalid data format. Please check your input.'
      : 'Format de données invalide. Veuillez vérifier votre saisie.';

  static String get errorShort => _isEnglish
      ? 'An error occurred'
      : 'Une erreur est survenue';

  // ==================== Erreurs Réseau / Network Errors ====================

  static String get networkError => _isEnglish
      ? 'No internet connection. Check your connection and try again.'
      : 'Pas de connexion internet. Vérifiez votre connexion et réessayez.';

  static String get networkErrorShort => _isEnglish
      ? 'No connection'
      : 'Pas de connexion';

  static String get timeout => _isEnglish
      ? 'The connection timed out. Please try again.'
      : 'La connexion a pris trop de temps. Veuillez réessayer.';

  static String get serviceUnavailable => _isEnglish
      ? 'The service is temporarily unavailable. Try again later.'
      : 'Le service est temporairement indisponible. Réessayez plus tard.';

  // ==================== Erreurs Cache / Cache Errors ====================

  static String get cacheError => _isEnglish
      ? 'Error accessing local data. Please restart the application.'
      : 'Erreur lors de l\'accès aux données locales. Veuillez redémarrer l\'application.';

  // ==================== Erreurs Auth / Auth Errors ====================

  static String get authError => _isEnglish
      ? 'Authentication error. Please try again.'
      : 'Erreur d\'authentification. Veuillez réessayer.';

  static String get authErrorShort => _isEnglish
      ? 'Login error'
      : 'Erreur de connexion';

  static String get userNotFound => _isEnglish
      ? 'No account found with this email address.'
      : 'Aucun compte associé à cette adresse email.';

  static String get wrongPassword => _isEnglish
      ? 'Incorrect password. Please try again.'
      : 'Mot de passe incorrect. Veuillez réessayer.';

  static String get invalidEmail => _isEnglish
      ? 'The email address is not valid.'
      : 'L\'adresse email n\'est pas valide.';

  static String get userDisabled => _isEnglish
      ? 'This account has been disabled. Contact support.'
      : 'Ce compte a été désactivé. Contactez le support.';

  static String get invalidCredential => _isEnglish
      ? 'Incorrect email or password.'
      : 'Email ou mot de passe incorrect.';

  static String get emailAlreadyInUse => _isEnglish
      ? 'This email address is already used by another account.'
      : 'Cette adresse email est déjà utilisée par un autre compte.';

  static String get weakPassword => _isEnglish
      ? 'Password is too weak. Use at least 8 characters with letters and numbers.'
      : 'Le mot de passe est trop faible. Utilisez au moins 8 caractères avec lettres et chiffres.';

  static String get operationNotAllowed => _isEnglish
      ? 'This operation is not allowed. Contact support.'
      : 'Cette opération n\'est pas autorisée. Contactez le support.';

  static String get tooManyRequests => _isEnglish
      ? 'Too many attempts. Please wait a few minutes before trying again.'
      : 'Trop de tentatives. Veuillez patienter quelques minutes avant de réessayer.';

  static String get expiredCode => _isEnglish
      ? 'The code has expired. Please request a new one.'
      : 'Le code a expiré. Veuillez en demander un nouveau.';

  static String get invalidCode => _isEnglish
      ? 'The code is invalid. Please verify or request a new one.'
      : 'Le code est invalide. Veuillez vérifier ou en demander un nouveau.';

  static String get accountExistsWithDifferentCredential => _isEnglish
      ? 'An account already exists with this email but with a different login method.'
      : 'Un compte existe déjà avec cette adresse email mais avec une autre méthode de connexion.';

  static String get authCancelled => _isEnglish
      ? 'Login was cancelled.'
      : 'La connexion a été annulée.';

  static String get requiresRecentLogin => _isEnglish
      ? 'This action requires a recent login. Please log out and log back in.'
      : 'Cette action nécessite une reconnexion récente. Veuillez vous déconnecter et vous reconnecter.';

  // ==================== Erreurs Firestore / Firestore Errors ====================

  static String get permissionDenied => _isEnglish
      ? 'You do not have permission to perform this action.'
      : 'Vous n\'avez pas la permission d\'effectuer cette action.';

  static String get notFound => _isEnglish
      ? 'The requested item does not exist or has been deleted.'
      : 'L\'élément demandé n\'existe pas ou a été supprimé.';

  static String get alreadyExists => _isEnglish
      ? 'This item already exists.'
      : 'Cet élément existe déjà.';

  // ==================== Erreurs Upload / Upload Errors ====================

  static String get uploadError => _isEnglish
      ? 'Error uploading file. Please try again.'
      : 'Erreur lors de l\'envoi du fichier. Veuillez réessayer.';

  static String get fileTooLarge => _isEnglish
      ? 'The file is too large. Maximum size: 10 MB.'
      : 'Le fichier est trop volumineux. Taille maximum : 10 MB.';

  static String get invalidFileType => _isEnglish
      ? 'Unsupported file type.'
      : 'Type de fichier non supporté.';

  // ==================== Erreurs Validation / Validation Errors ====================

  static String get requiredField => _isEnglish
      ? 'This field is required.'
      : 'Ce champ est obligatoire.';

  static String get invalidPhoneNumber => _isEnglish
      ? 'Invalid phone number.'
      : 'Numéro de téléphone invalide.';

  static String get invalidUrl => _isEnglish
      ? 'Invalid URL.'
      : 'URL invalide.';

  static String get minLengthTemplate => _isEnglish
      ? 'This field must contain at least {min} characters.'
      : 'Ce champ doit contenir au moins {min} caractères.';

  static String get maxLengthTemplate => _isEnglish
      ? 'This field cannot exceed {max} characters.'
      : 'Ce champ ne peut pas dépasser {max} caractères.';

  /// Retourne le message de longueur minimum avec la valeur
  static String minLength(int min) => format(minLengthTemplate, {'min': min.toString()});

  /// Retourne le message de longueur maximum avec la valeur
  static String maxLength(int max) => format(maxLengthTemplate, {'max': max.toString()});

  // ==================== Erreurs Messages / Message Errors ====================

  static String get messageNotSent => _isEnglish
      ? 'Unable to send message. Please try again.'
      : 'Impossible d\'envoyer le message. Veuillez réessayer.';

  static String get conversationNotFound => _isEnglish
      ? 'This conversation no longer exists.'
      : 'Cette conversation n\'existe plus.';

  // ==================== Erreurs Profil / Profile Errors ====================

  static String get profileNotFound => _isEnglish
      ? 'Profile not found.'
      : 'Profil introuvable.';

  static String get profileUpdateFailed => _isEnglish
      ? 'Unable to update profile. Please try again.'
      : 'Impossible de mettre à jour le profil. Veuillez réessayer.';

  // ==================== Erreurs Groupes / Group Errors ====================

  static String get groupNotFound => _isEnglish
      ? 'This group no longer exists or you no longer have access.'
      : 'Ce groupe n\'existe plus ou vous n\'y avez plus accès.';

  static String get notGroupMember => _isEnglish
      ? 'You are not a member of this group.'
      : 'Vous n\'êtes pas membre de ce groupe.';

  static String get cannotLeaveGroup => _isEnglish
      ? 'Cannot leave group. You are the only administrator.'
      : 'Impossible de quitter le groupe. Vous êtes le seul administrateur.';

  // ==================== Erreurs Événements / Event Errors ====================

  static String get eventNotFound => _isEnglish
      ? 'This event no longer exists.'
      : 'Cet événement n\'existe plus.';

  static String get eventFull => _isEnglish
      ? 'This event has reached maximum capacity.'
      : 'Cet événement a atteint sa capacité maximum.';

  static String get eventPast => _isEnglish
      ? 'This event has already passed.'
      : 'Cet événement est déjà passé.';

  // ==================== Erreurs Marketplace / Marketplace Errors ====================

  static String get productNotAvailable => _isEnglish
      ? 'This product is no longer available.'
      : 'Ce produit n\'est plus disponible.';

  static String get insufficientStock => _isEnglish
      ? 'Insufficient stock for this quantity.'
      : 'Stock insuffisant pour cette quantité.';

  static String get paymentFailed => _isEnglish
      ? 'Payment failed. Please verify your payment information.'
      : 'Le paiement a échoué. Veuillez vérifier vos informations de paiement.';

  // ==================== Erreurs Transferts / Transfer Errors ====================

  static String get transferFailed => _isEnglish
      ? 'Transfer failed. Please try again.'
      : 'Le transfert a échoué. Veuillez réessayer.';

  static String get invalidAmount => _isEnglish
      ? 'Invalid amount.'
      : 'Montant invalide.';

  static String get insufficientBalance => _isEnglish
      ? 'Insufficient balance to complete this transfer.'
      : 'Solde insuffisant pour effectuer ce transfert.';

  // ==================== Messages Offline / Offline Messages ====================

  static String get offlineMode => _isEnglish
      ? 'Offline mode activated. Changes will be synced when reconnected.'
      : 'Mode hors-ligne activé. Les modifications seront synchronisées à la reconnexion.';

  static String get syncInProgress => _isEnglish
      ? 'Synchronizing...'
      : 'Synchronisation en cours...';

  static String get syncComplete => _isEnglish
      ? 'Synchronization complete.'
      : 'Synchronisation terminée.';

  static String get syncFailed => _isEnglish
      ? 'Synchronization failed. Automatic retry scheduled.'
      : 'Échec de la synchronisation. Nouvelle tentative automatique.';

  static String get pendingChangesTemplate => _isEnglish
      ? '{count} change(s) pending synchronization.'
      : '{count} modification(s) en attente de synchronisation.';

  /// Retourne le message de changements en attente avec le nombre
  static String pendingChanges(int count) =>
      format(pendingChangesTemplate, {'count': count.toString()});

  // ==================== Messages Recherche / Search Messages ====================

  static String get searchError => _isEnglish
      ? 'Error during search. Please try again.'
      : 'Erreur lors de la recherche. Veuillez réessayer.';

  static String get noSearchResults => _isEnglish
      ? 'No results found.'
      : 'Aucun résultat trouvé.';

  static String get searchHint => _isEnglish
      ? 'Search members, groups, events...'
      : 'Rechercher membres, groupes, événements...';

  // ==================== Messages Amis / Friends Messages ====================

  static String get friendRequestSent => _isEnglish
      ? 'Friend request sent.'
      : 'Demande d\'ami envoyée.';

  static String get friendRequestAccepted => _isEnglish
      ? 'Friend request accepted.'
      : 'Demande d\'ami acceptée.';

  static String get friendRequestDeclined => _isEnglish
      ? 'Friend request declined.'
      : 'Demande d\'ami refusée.';

  static String get alreadyFriends => _isEnglish
      ? 'You are already friends.'
      : 'Vous êtes déjà amis.';

  static String get friendRemoved => _isEnglish
      ? 'Friend removed from your list.'
      : 'Ami supprimé de votre liste.';

  // ==================== Messages Succès / Success Messages ====================

  static String get saveSuccess => _isEnglish
      ? 'Saved successfully.'
      : 'Enregistré avec succès.';

  static String get updateSuccess => _isEnglish
      ? 'Updated successfully.'
      : 'Mis à jour avec succès.';

  static String get deleteSuccess => _isEnglish
      ? 'Deleted successfully.'
      : 'Supprimé avec succès.';

  static String get sendSuccess => _isEnglish
      ? 'Sent successfully.'
      : 'Envoyé avec succès.';

  // ==================== Messages Confirmation / Confirmation Messages ====================

  static String get confirmDelete => _isEnglish
      ? 'Are you sure you want to delete?'
      : 'Êtes-vous sûr de vouloir supprimer ?';

  static String get confirmLogout => _isEnglish
      ? 'Are you sure you want to log out?'
      : 'Êtes-vous sûr de vouloir vous déconnecter ?';

  static String get confirmCancel => _isEnglish
      ? 'Are you sure you want to cancel?'
      : 'Êtes-vous sûr de vouloir annuler ?';

  static String get confirmLeaveGroup => _isEnglish
      ? 'Are you sure you want to leave this group?'
      : 'Êtes-vous sûr de vouloir quitter ce groupe ?';

  // ==================== Boutons / Buttons ====================

  static String get retry => _isEnglish ? 'Retry' : 'Réessayer';
  static String get cancel => _isEnglish ? 'Cancel' : 'Annuler';
  static String get confirm => _isEnglish ? 'Confirm' : 'Confirmer';
  static String get ok => 'OK';
  static String get yes => _isEnglish ? 'Yes' : 'Oui';
  static String get no => _isEnglish ? 'No' : 'Non';
  static String get close => _isEnglish ? 'Close' : 'Fermer';
  static String get save => _isEnglish ? 'Save' : 'Enregistrer';
  static String get delete => _isEnglish ? 'Delete' : 'Supprimer';
  static String get edit => _isEnglish ? 'Edit' : 'Modifier';
  static String get send => _isEnglish ? 'Send' : 'Envoyer';
  static String get share => _isEnglish ? 'Share' : 'Partager';
  static String get loading => _isEnglish ? 'Loading...' : 'Chargement...';

  // ==================== Labels Communs / Common Labels ====================

  static String get email => _isEnglish ? 'Email' : 'Email';
  static String get password => _isEnglish ? 'Password' : 'Mot de passe';
  static String get confirmPassword => _isEnglish ? 'Confirm password' : 'Confirmer le mot de passe';
  static String get firstName => _isEnglish ? 'First name' : 'Prénom';
  static String get lastName => _isEnglish ? 'Last name' : 'Nom';
  static String get phoneNumber => _isEnglish ? 'Phone number' : 'Numéro de téléphone';
  static String get address => _isEnglish ? 'Address' : 'Adresse';
  static String get city => _isEnglish ? 'City' : 'Ville';
  static String get country => _isEnglish ? 'Country' : 'Pays';

  // ==================== Helpers ====================

  /// Remplace les placeholders dans un message
  static String format(String message, Map<String, String> params) {
    String result = message;
    params.forEach((key, value) {
      result = result.replaceAll('{$key}', value);
    });
    return result;
  }

  /// Retourne un message d'erreur basé sur le code
  static String fromCode(String code) {
    switch (code) {
      case 'user-not-found':
        return userNotFound;
      case 'wrong-password':
        return wrongPassword;
      case 'invalid-email':
        return invalidEmail;
      case 'user-disabled':
        return userDisabled;
      case 'invalid-credential':
        return invalidCredential;
      case 'email-already-in-use':
        return emailAlreadyInUse;
      case 'weak-password':
        return weakPassword;
      case 'operation-not-allowed':
        return operationNotAllowed;
      case 'too-many-requests':
        return tooManyRequests;
      case 'expired-action-code':
        return expiredCode;
      case 'invalid-action-code':
        return invalidCode;
      case 'permission-denied':
        return permissionDenied;
      case 'not-found':
        return notFound;
      case 'already-exists':
        return alreadyExists;
      case 'network-request-failed':
        return networkError;
      case 'requires-recent-login':
        return requiresRecentLogin;
      default:
        return unexpectedError;
    }
  }
}
