// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get callControlMic => 'Micro';

  @override
  String get callControlMicOff => 'Micro coupé';

  @override
  String get callControlSpeaker => 'Haut-parleur';

  @override
  String get callControlEarpiece => 'Écouteur';

  @override
  String get callControlCamera => 'Caméra';

  @override
  String get callControlVideo => 'Vidéo';

  @override
  String get callControlFlip => 'Retourner';

  @override
  String get callControlHold => 'Pause';

  @override
  String get callControlResume => 'Reprendre';

  @override
  String get hangUp => 'Raccrocher';

  @override
  String get supportPromptHeader => 'Par quoi commencer ?';

  @override
  String get supportPromptTransfer => 'Un transfert est bloqué';

  @override
  String get supportPromptAccount => 'Je n\'accède pas à mon compte';

  @override
  String get supportPromptBug => 'Un problème technique';

  @override
  String get supportAutoAttached => 'Joint automatiquement';

  @override
  String get appTitle => 'Diaspo Niger';

  @override
  String get you => 'Vous';

  @override
  String get welcomeTitle => 'Bienvenue';

  @override
  String get welcomeBackTitle => 'Bon retour';

  @override
  String get createMyAccount => 'Créer mon compte';

  @override
  String get passwordStrengthWeak => 'Faible';

  @override
  String get passwordStrengthOk => 'Correct';

  @override
  String get passwordStrengthStrong => 'Fort';

  @override
  String get loginSubtitle =>
      'Retrouvez la communauté nigérienne : messages chiffrés, entraide locale, transferts vers le pays.';

  @override
  String get emailAddressLabel => 'Adresse e-mail';

  @override
  String get forgotShort => 'Oublié ?';

  @override
  String get passwordMinHelper => 'Au moins 6 caractères';

  @override
  String get e2eeFooterNote => 'Vos messages sont chiffrés de bout en bout.';

  @override
  String get joinDiaspora => 'Rejoins la diaspora nigérienne';

  @override
  String get continueWithGoogle => 'Continuer avec Google';

  @override
  String get or => 'ou';

  @override
  String get password => 'Mot de passe';

  @override
  String get confirmPassword => 'Confirmer le mot de passe';

  @override
  String get signIn => 'Se connecter';

  @override
  String get signUp => 'S\'inscrire';

  @override
  String get noAccount => 'Pas encore de compte ?';

  @override
  String get alreadyHaveAccount => 'Déjà un compte ?';

  @override
  String get createAccount => 'Créer un compte';

  @override
  String get joinCommunity => 'Rejoins la communauté nigérienne';

  @override
  String get enterEmail => 'Veuillez entrer votre email';

  @override
  String get invalidEmail => 'Email invalide';

  @override
  String get emailMissingAt => 'Ajoutez le @, par exemple nom@exemple.com';

  @override
  String get emailMissingDomain =>
      'Il manque la fin de l\'adresse, par exemple .com';

  @override
  String get enterPassword => 'Veuillez entrer votre mot de passe';

  @override
  String get enterAPassword => 'Veuillez entrer un mot de passe';

  @override
  String get passwordTooShort =>
      'Le mot de passe doit contenir au moins 6 caractères';

  @override
  String get enterName => 'Veuillez entrer votre nom';

  @override
  String get nameTooShort => 'Le nom doit contenir au moins 2 caractères';

  @override
  String get confirmPasswordRequired => 'Veuillez confirmer le mot de passe';

  @override
  String get passwordsDoNotMatch => 'Les mots de passe ne correspondent pas';

  @override
  String get termsAgreement =>
      'En vous inscrivant, vous acceptez nos Conditions d\'utilisation et notre Politique de confidentialité.';

  @override
  String get settings => 'Réglages';

  @override
  String get account => 'Compte';

  @override
  String get editProfile => 'Modifier le profil';

  @override
  String get myProfile => 'Mon profil';

  @override
  String get email => 'Email';

  @override
  String get notDefined => 'Non défini';

  @override
  String get notifications => 'Notifications';

  @override
  String get pushNotifications => 'Notifications push';

  @override
  String get receiveNotifications => 'Recevoir des notifications';

  @override
  String get notificationPreferences => 'Préférences de notification';

  @override
  String get messages => 'Messages';

  @override
  String get newEvents => 'Nouveaux événements';

  @override
  String get groupActivity => 'Activité des groupes';

  @override
  String get eventReminders => 'Rappels d\'événements';

  @override
  String get privacy => 'Confidentialité';

  @override
  String get visibleProfile => 'Profil visible';

  @override
  String get appearInSearches => 'Apparaître dans les recherches';

  @override
  String get shareLocation => 'Partager ma position';

  @override
  String get appearOnMap => 'Apparaître sur la carte';

  @override
  String get blockedUsers => 'Utilisateurs bloqués';

  @override
  String get noBlockedUsers => 'Aucun utilisateur bloqué';

  @override
  String get blockedUsersConsequences =>
      'La personne bloquée ne peut plus vous envoyer de messages, ni voir votre position ou votre statut en ligne. Elle n\'est pas informée du blocage.';

  @override
  String get unblock => 'Débloquer';

  @override
  String get blockUser => 'Bloquer l\'utilisateur';

  @override
  String get userBlocked => 'Utilisateur bloqué';

  @override
  String get userUnblocked => 'Utilisateur débloqué';

  @override
  String blockedOn(String date) {
    return 'Bloqué le $date';
  }

  @override
  String get security => 'Sécurité';

  @override
  String get keyBackup => 'Sauvegarde des clés';

  @override
  String get keyBackupSubtitle => 'Protégez vos messages chiffrés';

  @override
  String get connectedDevices => 'Appareils connectés';

  @override
  String get connectedDevicesSubtitle => 'Gérez vos appareils (max 5)';

  @override
  String get endToEndEncryption => 'Chiffrement de bout en bout';

  @override
  String get e2eeDescription =>
      'Vos messages sont chiffrés de bout en bout. Seuls vous et vos correspondants pouvez les lire.';

  @override
  String get createBackup => 'Créer une sauvegarde';

  @override
  String get restoreBackup => 'Restaurer la sauvegarde';

  @override
  String get passphrase => 'Passphrase';

  @override
  String get passphraseHint => 'Minimum 8 caractères';

  @override
  String get confirmPassphrase => 'Confirmer la passphrase';

  @override
  String get generatePassphrase => 'Générer une passphrase sécurisée';

  @override
  String get passphraseStrength => 'Force';

  @override
  String get weak => 'Faible';

  @override
  String get medium => 'Moyen';

  @override
  String get strong => 'Fort';

  @override
  String get backupCreated => 'Sauvegarde créée avec succès';

  @override
  String get backupRestored => 'Clés restaurées avec succès';

  @override
  String get invalidPassphrase => 'Passphrase incorrecte';

  @override
  String get noBackupFound => 'Aucune sauvegarde trouvée';

  @override
  String get deleteBackup => 'Supprimer la sauvegarde';

  @override
  String get deleteBackupWarning =>
      'Cette action est irréversible. Si vous perdez vos clés et n\'avez plus de sauvegarde, vous ne pourrez plus lire vos anciens messages.';

  @override
  String get existingBackup => 'Sauvegarde existante';

  @override
  String get backupActive => 'Sauvegarde active';

  @override
  String get restoreOnDevice => 'Restaurer sur cet appareil';

  @override
  String get enterPassphrase =>
      'Entrez votre passphrase pour restaurer vos clés';

  @override
  String get passphraseWarning =>
      'N\'oubliez pas votre passphrase ! Sans elle, vos clés ne pourront pas être restaurées.';

  @override
  String get deviceManagement => 'Gestion des appareils';

  @override
  String get deviceManagementInfo =>
      'Vous pouvez avoir jusqu\'à 5 appareils connectés simultanément. Chaque appareil possède ses propres clés de chiffrement.';

  @override
  String get noDevices => 'Aucun appareil enregistré';

  @override
  String get noDevicesDescription =>
      'Les appareils utilisant le chiffrement de bout en bout apparaîtront ici.';

  @override
  String get thisDevice => 'Cet appareil';

  @override
  String get renameDevice => 'Renommer';

  @override
  String get revokeDevice => 'Révoquer';

  @override
  String get revokeDeviceTitle => 'Révoquer l\'appareil ?';

  @override
  String get revokeDeviceWarning =>
      'Cet appareil ne pourra plus envoyer ni recevoir de messages chiffrés. Les clés de cet appareil seront supprimées.';

  @override
  String get deviceRenamed => 'Appareil renommé';

  @override
  String get deviceRevoked => 'Appareil révoqué';

  @override
  String get deviceLimitReached => 'Limite atteinte';

  @override
  String get fingerprint => 'Empreinte';

  @override
  String get online => 'En ligne';

  @override
  String get application => 'Application';

  @override
  String get theme => 'Thème';

  @override
  String get light => 'Clair';

  @override
  String get dark => 'Sombre';

  @override
  String get system => 'Système';

  @override
  String get chooseTheme => 'Choisir le thème';

  @override
  String get language => 'Langue';

  @override
  String get french => 'Français';

  @override
  String get english => 'English';

  @override
  String get chooseLanguage => 'Choisir la langue';

  @override
  String get helpAndSupport => 'Aide & Support';

  @override
  String get contactUs => 'Nous contacter';

  @override
  String get reportBug => 'Signaler un bug';

  @override
  String get giveFeedback => 'Donner un avis';

  @override
  String get bugReportTitle => 'Signaler un bug';

  @override
  String get bugDescription => 'Description du bug';

  @override
  String get bugDescriptionHint => 'Décrivez le problème rencontré...';

  @override
  String get stepsToReproduce => 'Étapes pour reproduire (optionnel)';

  @override
  String get stepsHint => '1. Ouvrir l\'application\n2. ...';

  @override
  String get send => 'Envoyer';

  @override
  String get bugReportSent => 'Rapport de bug envoyé';

  @override
  String get feedbackSent => 'Merci pour votre avis !';

  @override
  String get about => 'À propos';

  @override
  String get version => 'Version';

  @override
  String get lastUpdate => 'Dernière mise à jour';

  @override
  String versionInfo(String version, String date) {
    return 'Version $version - Dernière mise à jour : $date';
  }

  @override
  String get appDescription =>
      'Plateforme de mise en relation de la diaspora nigérienne.';

  @override
  String get termsOfService => 'Conditions d\'utilisation';

  @override
  String get privacyPolicy => 'Politique de confidentialité';

  @override
  String get codeOfConduct => 'Code de conduite';

  @override
  String get legalDocumentsTitle => 'Documents légaux';

  @override
  String get legalEssentialsTitle => 'L\'essentiel';

  @override
  String legalReadingTime(int minutes) {
    return '≈ $minutes min de lecture';
  }

  @override
  String get legalUpdateTitle => 'Mise à jour des conditions';

  @override
  String get legalUpdateDescription =>
      'Nos conditions d\'utilisation et/ou notre politique de confidentialité ont été mises à jour. Veuillez les lire et les accepter pour continuer à utiliser l\'application.';

  @override
  String get summaryOfChanges => 'Résumé des changements :';

  @override
  String get iAcceptThe => 'J\'accepte les ';

  @override
  String get iAccept => 'J\'accepte la ';

  @override
  String get acceptAndContinue => 'Accepter et continuer';

  @override
  String get dangerZone => 'Actions du compte';

  @override
  String get logout => 'Déconnexion';

  @override
  String get deleteAccount => 'Supprimer mon compte';

  @override
  String get confirmLogout => 'Voulez-vous vraiment vous déconnecter ?';

  @override
  String get confirmDeleteAccount => 'Supprimer le compte';

  @override
  String get deleteAccountWarning =>
      'Cette action est irréversible. Toutes vos données seront supprimées définitivement.\n\nCela inclut :\n• Votre profil et vos informations personnelles\n• Vos conversations et messages\n• Vos événements créés\n• Votre participation aux groupes';

  @override
  String unreadConversations(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count non lus',
      one: '1 non lu',
      zero: 'Aucun non lu',
    );
    return '$_temp0';
  }

  @override
  String get exportMyData => 'Exporter mes données';

  @override
  String get exportMyDataSubtitle =>
      'Télécharger une copie de vos données (RGPD)';

  @override
  String get exportMyDataPreparing => 'Préparation de votre export…';

  @override
  String get exportMyDataFailed => 'L\'export a échoué';

  @override
  String get continueAction => 'Continuer';

  @override
  String get finalConfirmation => 'Confirmation finale';

  @override
  String get typeDeleteToConfirm =>
      'Pour confirmer la suppression, tapez \"SUPPRIMER\" ci-dessous :';

  @override
  String get deleteKeyword => 'SUPPRIMER';

  @override
  String get deletePermanently => 'Supprimer définitivement';

  @override
  String get deletingAccount => 'Suppression du compte en cours...';

  @override
  String get accountDeleted => 'Votre compte a été supprimé avec succès';

  @override
  String get deleteError =>
      'Erreur lors de la suppression. Veuillez vous reconnecter et réessayer.';

  @override
  String get cancel => 'Annuler';

  @override
  String get confirm => 'Confirmer';

  @override
  String get save => 'Enregistrer';

  @override
  String get close => 'Fermer';

  @override
  String get error => 'Erreur';

  @override
  String get success => 'Succès';

  @override
  String get history => 'Historique';

  @override
  String get loading => 'Chargement...';

  @override
  String get conversationOptions => 'Options de la conversation';

  @override
  String get mute => 'Mettre en sourdine';

  @override
  String get unmute => 'Réactiver les notifications';

  @override
  String get muteConversation => 'Conversation mise en sourdine';

  @override
  String get unmuteConversation => 'Notifications réactivées';

  @override
  String get archive => 'Archiver';

  @override
  String get unarchive => 'Désarchiver';

  @override
  String get archiveConversation => 'Conversation archivée';

  @override
  String get unarchiveConversation => 'Conversation désarchivée';

  @override
  String get deleteConversation => 'Supprimer la conversation';

  @override
  String get deleteConversations => 'Supprimer les conversations';

  @override
  String get confirmDeleteConversation =>
      'Voulez-vous vraiment supprimer cette conversation ? Cette action est irréversible.';

  @override
  String confirmDeleteMultipleConversations(int count) {
    return 'Voulez-vous vraiment supprimer $count conversations ? Cette action est irréversible.';
  }

  @override
  String selectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$count sélectionné$_temp0';
  }

  @override
  String conversationsDeleted(int count) {
    return '$count conversation(s) supprimée(s)';
  }

  @override
  String get select => 'Sélectionner';

  @override
  String get deleteForMe => 'Supprimer pour moi';

  @override
  String get deleteForEveryone => 'Supprimer pour tous';

  @override
  String get conversationDeleted => 'Conversation supprimée';

  @override
  String get changeWallpaper => 'Changer le fond d\'écran';

  @override
  String get blockUserTitle => 'Bloquer l\'utilisateur';

  @override
  String get unblockUserTitle => 'Débloquer l\'utilisateur';

  @override
  String confirmBlockUser(String userName) {
    return 'Voulez-vous vraiment bloquer $userName ? Vous ne recevrez plus de messages de sa part.';
  }

  @override
  String confirmUnblockUser(String userName) {
    return 'Voulez-vous vraiment débloquer $userName ?';
  }

  @override
  String get block => 'Bloquer';

  @override
  String get unblockUser => 'Débloquer l\'utilisateur';

  @override
  String get blockError => 'Erreur lors du blocage';

  @override
  String get unblockError => 'Erreur lors du déblocage';

  @override
  String get reportConversation => 'Signaler';

  @override
  String get reportReason => 'Motif du signalement';

  @override
  String get spam => 'Spam';

  @override
  String get harassment => 'Harcèlement';

  @override
  String get inappropriateContent => 'Contenu inapproprié';

  @override
  String get other => 'Autre';

  @override
  String get reportSent => 'Signalement envoyé';

  @override
  String get reportDescription => 'Description (optionnel)';

  @override
  String get messagesTitle => 'Messages';

  @override
  String get archives => 'Archives';

  @override
  String get searchPlaceholder => 'Rechercher...';

  @override
  String get noConversation => 'Aucune conversation';

  @override
  String get startChatting =>
      'Commencez à discuter avec les membres de la diaspora';

  @override
  String get newConversation => 'Nouvelle conversation';

  @override
  String noResults(String query) {
    return 'Aucun résultat pour \"$query\"';
  }

  @override
  String get noArchivedConversation => 'Aucune conversation archivée';

  @override
  String get noUnreadMessages => 'Aucun message non lu';

  @override
  String get noGroupConversations => 'Aucune conversation de groupe';

  @override
  String get showAllConversations => 'Afficher toutes les conversations';

  @override
  String get messageRequests => 'Demandes';

  @override
  String get wantsToMessageYou => 'souhaite vous envoyer un message';

  @override
  String get acceptRequest => 'Accepter';

  @override
  String get declineRequest => 'Refuser';

  @override
  String get requestPending => 'Demande en attente';

  @override
  String get requestAccepted => 'Demande acceptée';

  @override
  String get requestDeclined => 'Demande refusée';

  @override
  String get commonGroups => 'Groupes en commun';

  @override
  String get noCommonGroups => 'Aucun groupe en commun';

  @override
  String get unknownCaller => 'Appelant inconnu';

  @override
  String get callerNotInContacts => 'Cet appelant n\'est pas dans vos contacts';

  @override
  String get sendMessageRequest => 'Envoyer une demande de message ?';

  @override
  String get personNotInContacts =>
      'Cette personne n\'est pas dans vos contacts. Elle devra accepter votre demande pour voir vos messages.';

  @override
  String get noMessageRequests => 'Aucune demande de message';

  @override
  String get loadingError => 'Erreur de chargement';

  @override
  String get retry => 'Réessayer';

  @override
  String get messageNotSent => 'Non envoyé';

  @override
  String get noMessages => 'Aucun message';

  @override
  String get sendFirstMessage => 'Envoyez le premier message !';

  @override
  String get group => 'Groupe';

  @override
  String get conversation => 'Conversation';

  @override
  String get newConversationTitle => 'Nouvelle conversation';

  @override
  String get start => 'Commencer';

  @override
  String get searchMember => 'Rechercher un membre...';

  @override
  String createGroupWith(int count) {
    return 'Créer un groupe avec $count membres';
  }

  @override
  String get groupName => 'Nom du groupe';

  @override
  String get enterGroupName => 'Entrez le nom du groupe';

  @override
  String get create => 'Créer';

  @override
  String get searchAMember => 'Recherchez un membre';

  @override
  String get enterAtLeast2Chars => 'Entrez au moins 2 caractères';

  @override
  String get user => 'Utilisateur';

  @override
  String get eventsTitle => 'Événements';

  @override
  String get upcoming => 'À venir';

  @override
  String get past => 'Passés';

  @override
  String get noPastEvents => 'Aucun événement passé';

  @override
  String get all => 'Tous';

  @override
  String get noUpcomingEvents => 'Aucun événement à venir';

  @override
  String get eventsNearMe => 'Près de moi';

  @override
  String get eventsOnline => 'En ligne';

  @override
  String get eventsFree => 'Gratuits';

  @override
  String participants(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count participants',
      one: '1 participant',
      zero: 'Aucun participant',
    );
    return '$_temp0';
  }

  @override
  String get seeMore => 'Voir plus';

  @override
  String get createEvent => 'Créer un événement';

  @override
  String get eventDetails => 'Détails de l\'événement';

  @override
  String get join => 'Participer';

  @override
  String get leave => 'Quitter';

  @override
  String get joined => 'Inscrit';

  @override
  String get organizedBy => 'Organisé par';

  @override
  String get organizer => 'Organisateur';

  @override
  String get aboutEvent => 'À propos';

  @override
  String startingFrom(String time) {
    return 'À partir de $time';
  }

  @override
  String get noParticipantsYet => 'Aucun participant pour le moment';

  @override
  String othersMore(int count) {
    return '+$count autres';
  }

  @override
  String get delete => 'Supprimer';

  @override
  String get edit => 'Modifier';

  @override
  String get participate => 'Participer';

  @override
  String get full => 'Complet';

  @override
  String get eventFree => 'Gratuit';

  @override
  String get eventPaid => 'Payant';

  @override
  String get eventPriceOptional => 'Prix du billet (optionnel)';

  @override
  String get eventPriceHint => '0 = gratuit';

  @override
  String get eventPriceFreeHelper => 'Laissez à 0 pour un événement gratuit';

  @override
  String get registrationConfirmed => 'Inscription confirmée !';

  @override
  String get registered => 'Inscrit';

  @override
  String get cancelParticipation => 'Annuler la participation';

  @override
  String get cancelParticipationConfirm =>
      'Voulez-vous vraiment annuler votre participation ?';

  @override
  String get no => 'Non';

  @override
  String get yesCancel => 'Oui, annuler';

  @override
  String get participationCancelled => 'Participation annulée';

  @override
  String get deleteEvent => 'Supprimer l\'événement';

  @override
  String get deleteEventConfirm =>
      'Voulez-vous vraiment supprimer cet événement ? Cette action est irréversible.';

  @override
  String get eventDeleted => 'Événement supprimé';

  @override
  String get addedToCalendar => 'Événement ajouté au calendrier';

  @override
  String get cannotAddToCalendar => 'Impossible d\'ajouter au calendrier';

  @override
  String get calendar => 'Calendrier';

  @override
  String get eventCategoryCultural => 'Culturel';

  @override
  String get eventCategoryProfessional => 'Professionnel';

  @override
  String get eventCategorySocial => 'Social';

  @override
  String get eventCategorySport => 'Sport';

  @override
  String get eventCategoryOther => 'Autre';

  @override
  String get groupsTitle => 'Groupes';

  @override
  String get noGroups => 'Aucun groupe';

  @override
  String get myGroups => 'Mes groupes';

  @override
  String get searchGroup => 'Rechercher un groupe...';

  @override
  String get noJoinedGroups => 'Vous n\'avez rejoint aucun groupe';

  @override
  String get faqEncryptionQ => 'Mes messages sont-ils protégés ?';

  @override
  String get faqEncryptionA =>
      'Oui. Vos conversations sont chiffrées de bout en bout : seuls vous et vos correspondants peuvent les lire.';

  @override
  String get faqLocationQ => 'Qui voit ma position sur la carte ?';

  @override
  String get faqLocationA =>
      'Uniquement les membres dont vous voyez aussi la position (réciprocité). Vous pouvez la désactiver à tout moment, et les comptes bloqués ne vous voient jamais.';

  @override
  String get faqReportQ => 'Comment signaler un contenu ?';

  @override
  String get faqReportA =>
      'Ouvrez le menu d\'un message ou d\'une publication, puis « Signaler ». Votre signalement est anonyme.';

  @override
  String get faqTransferQ => 'Combien de temps prend un transfert ?';

  @override
  String get faqTransferA =>
      'Les transferts sont généralement disponibles sous 24 h. Les frais sont annoncés avant confirmation.';

  @override
  String get pinnedSection => 'Épinglées';

  @override
  String get otherConversations => 'Autres';

  @override
  String get emptyMessagesJoinGroup => 'Rejoindre un groupe de votre ville';

  @override
  String get emptyGroupsUsage =>
      'Les groupes réunissent la diaspora par ville, centre d\'intérêt ou projet. Rejoignez-en un ou créez le vôtre.';

  @override
  String get noGroupsToDiscover => 'Aucun nouveau groupe à découvrir';

  @override
  String get groupsNoneInYourAreaTitle =>
      'Rien dans votre région pour l\'instant';

  @override
  String get groupsNoneInYourAreaBody =>
      'Aucun groupe ne correspond encore à votre pays de résidence ni à votre région d\'origine. Tu peux ouvrir le premier, ou élargir votre recherche.';

  @override
  String get groupsBrowseAll => 'Voir tous les groupes';

  @override
  String searchNoResultsFor(String query) {
    return 'Aucun résultat pour « $query »';
  }

  @override
  String get searchTipsTitle => 'Quelques pistes';

  @override
  String get searchTipSpelling => 'Vérifiez l\'orthographe';

  @override
  String get searchTipFewerWords =>
      'Essayez avec moins de mots, ou un mot plus général';

  @override
  String get searchTipRemoveFilters =>
      'Retire les filtres actifs pour élargir la recherche';

  @override
  String get searchClearFilters => 'Effacer les filtres';

  @override
  String get marketplaceSellItem => 'Vendre un article';

  @override
  String get mapEmptyAreaTitle => 'Rien dans cette zone';

  @override
  String get mapEmptyAreaBody =>
      'Aucun membre, commerce ni ambassade à afficher ici. Élargis la vue ou active une autre couche.';

  @override
  String get mapZoomOut => 'Dézoomer';

  @override
  String get mapShowEmbassies => 'Voir les ambassades';

  @override
  String scheduleRoomOnDate(String date, String time) {
    return '📅 Programmer le $date à $time';
  }

  @override
  String get scheduleRoomTitleLabel => 'Titre du salon';

  @override
  String get scheduleRoomTitleHint => 'De quoi allez-vous parler ?';

  @override
  String get audioRoomTicketAction => 'Billet';

  @override
  String ghostModerationHeader(String duration) {
    return 'MODÉRATION · $duration';
  }

  @override
  String get ghostWarnHost => 'Avertir l\'hôte';

  @override
  String get audioRoomPrivateRoomHint =>
      'Seules les personnes invitées pourront entrer.';

  @override
  String get audioRoomVideoEnabledHint =>
      'Les intervenants pourront activer leur caméra.';

  @override
  String get audioRoomEnableRecordingHint =>
      'Le salon pourra être republié en podcast après coup.';

  @override
  String get audioRoomPaidRoomHint =>
      'L\'entrée demande l\'achat d\'un billet.';

  @override
  String get audioRoomEnableFundraisingHint =>
      'Une barre de collecte s\'affiche pendant le salon.';

  @override
  String get audioRoomHeritageContentHint =>
      'Le salon est archivé dans la bibliothèque du patrimoine.';

  @override
  String get audioRoomScheduleAction => 'Programmer';

  @override
  String get scheduleRoomIntro =>
      'Choisissez un créneau qui tombe bien pour tout le monde : l\'heure est convertie dans le fuseau de chaque membre.';

  @override
  String get scheduleMembersLocalTime => 'HEURE LOCALE DES MEMBRES';

  @override
  String get scheduleRemindMe => 'Me le rappeler';

  @override
  String get scheduleRemindMeHint => 'Notification 15 min avant le début.';

  @override
  String get scheduleSlotEvening => 'Bonne heure · soirée';

  @override
  String get scheduleSlotMidday => 'Midi · en journée';

  @override
  String get scheduleSlotMorning => 'Matin · au réveil';

  @override
  String get scheduleSlotNight => 'Tard · risque de nuit';

  @override
  String get audioRoomHeritageArchivedNote => 'ce salon sera archivé';

  @override
  String get audioRoomInviteCoHostTitle => 'Nommer un co-hôte';

  @override
  String audioRoomCoHostAdded(String name) {
    return '$name est désormais co-hôte';
  }

  @override
  String get audioRoomHandsRaisedLabel => 'Mains levées';

  @override
  String get audioRoomStatsLiveNote =>
      'Valeurs de l\'instant — aucun historique n\'est conservé.';

  @override
  String heritageRecordingsCount(int count) {
    return '$count ENREGISTREMENTS';
  }

  @override
  String get heritageDownloadHint =>
      'Téléchargez avant un trajet : les enregistrements restent écoutables sans connexion.';

  @override
  String get homeSeeOnlineEvents => 'Voir les événements en ligne';

  @override
  String get homeCreateEvent => 'Créer';

  @override
  String get podcastsSortRecent => 'Plus récents';

  @override
  String get podcastsSortOldest => 'Plus anciens';

  @override
  String get savePodcastHeritageNote =>
      'Un salon patrimoine reste aussi dans la bibliothèque du patrimoine, même publié en podcast.';

  @override
  String podcastsHomeSubtitle(int subscriptions, int inProgress) {
    return '$subscriptions abonnements · $inProgress en cours d\'écoute';
  }

  @override
  String get audioRoomSeeAllListeners => 'Voir tout';

  @override
  String audioRoomHandsRaisedCount(int count) {
    return '$count mains levées';
  }

  @override
  String audioRoomElapsedMinutes(int minutes) {
    return '$minutes MIN';
  }

  @override
  String audioRoomElapsedHours(int hours, int minutes) {
    return '$hours H $minutes MIN';
  }

  @override
  String podcastFrequencyAndPrice(String frequency, String price) {
    return '$frequency · $price/mois';
  }

  @override
  String get podcastViewSheet => 'Voir la fiche';

  @override
  String get podcastsDiasporaVoicesTitle => 'Des voix de la diaspora';

  @override
  String get podcastsPopularInDiaspora => 'POPULAIRES DANS LA DIASPORA';

  @override
  String get podcastsCreateMine => 'Créer mon podcast';

  @override
  String marketplaceSearchEverywhere(int count) {
    return 'Chercher partout · $count';
  }

  @override
  String get marketplaceAlertMe => 'M\'alerter si ça arrive';

  @override
  String marketplaceAlertSaved(String query) {
    return 'Alerte enregistrée pour « $query ». Tu recevras une notification dès qu\'un article correspond.';
  }

  @override
  String get marketplaceNoProductsTitle => 'Rien en vente pour l\'instant';

  @override
  String get marketplaceNoProductsHint =>
      'Sois le premier à proposer quelque chose à la diaspora.';

  @override
  String get myProductsEmptyHint => 'Choisissez une catégorie pour commencer :';

  @override
  String get ordersEmptyEscrowNote =>
      'Les paiements sont gardés en séquestre jusqu\'à confirmation de réception.';

  @override
  String groupsSeeSuggested(int count) {
    return 'Voir les $count groupes suggérés';
  }

  @override
  String searchCreateNamed(String query) {
    return 'Créer « $query »';
  }

  @override
  String get reconnectedTitle => 'Connexion revenue';

  @override
  String reconnectedAfter(String duration) {
    return 'Coupure de $duration';
  }

  @override
  String get reconnectedSentSection => 'Envoyé en priorité';

  @override
  String get reconnectedReceivedSection => 'Reçu pendant votre absence';

  @override
  String get reconnectedOutcomeSent => 'Envoyé';

  @override
  String get reconnectedOutcomeRetrying => 'Sera renvoyé';

  @override
  String get reconnectedOutcomeAbandoned => 'Abandonné après 3 tentatives';

  @override
  String reconnectedAbandonedWarning(int count) {
    return '$count élément(s) n\'ont pas pu être envoyés et ont été abandonnés. Il faut les refaire à la main.';
  }

  @override
  String reconnectedUnreadMessages(int count) {
    return '$count message(s) non lu(s)';
  }

  @override
  String reconnectedUnreadNotifications(int count) {
    return '$count notification(s)';
  }

  @override
  String get reconnectedNothingReceived => 'Rien de nouveau.';

  @override
  String get reconnectedActionCreate => 'Création';

  @override
  String get reconnectedActionUpdate => 'Modification';

  @override
  String get reconnectedActionDelete => 'Suppression';

  @override
  String get feedPostNotSent => 'Publication non envoyée';

  @override
  String get feedPostNotSentHint =>
      'Ton texte est gardé ici. Rien n\'est perdu.';

  @override
  String get feedPostDiscard => 'Abandonner';

  @override
  String get feedErrorNoConnectionTitle => 'Pas de connexion';

  @override
  String get feedErrorNoConnectionBody =>
      'Ton téléphone n\'est relié à aucun réseau. Le fil se rechargera dès que la connexion revient.';

  @override
  String get feedErrorServerTitle => 'Nos serveurs ne répondent pas';

  @override
  String get feedErrorServerBody =>
      'Ça vient de nous, pas de toi. Nouvelle tentative automatique.';

  @override
  String feedErrorServerCountdown(int seconds) {
    return 'Nouvelle tentative dans $seconds s';
  }

  @override
  String get feedErrorSlowTitle => 'Réseau trop lent';

  @override
  String get feedErrorSlowBody =>
      'La connexion n\'a pas tenu assez longtemps pour charger le fil. Réessaie, ou attends un meilleur réseau.';

  @override
  String get feedErrorUnknownTitle => 'Le fil n\'a pas pu se charger';

  @override
  String get feedErrorUnknownBody => 'Une erreur inattendue est survenue.';

  @override
  String feedCachedNotice(String when) {
    return 'Fil hors ligne · dernière mise à jour $when';
  }

  @override
  String get feedCachedNoticeUnknownTime =>
      'Fil hors ligne · publications déjà chargées';

  @override
  String audioRoomsLiveAndScheduled(int live, int scheduled) {
    return '$live en direct · $scheduled programmés';
  }

  @override
  String get audioRoomOpenRoom => 'Ouvrir un salon';

  @override
  String get audioRoomOpenRoomHint =>
      'Lance une discussion en direct, seul ou à plusieurs.';

  @override
  String get heritageOralTitle => 'Patrimoine oral';

  @override
  String get heritageOralHint =>
      'Contes, proverbes et mémoire, à écouter même hors ligne.';

  @override
  String get transferFailOperatorBlockedTitle => 'Bloqué par l\'opérateur';

  @override
  String get transferFailOperatorBlockedDesc =>
      'L\'opérateur du bénéficiaire a refusé de créditer le compte (plafond atteint, pièces d\'identité manquantes ou compte gelé).';

  @override
  String get transferFailDuplicateTitle => 'Doublon évité';

  @override
  String get transferFailDuplicateDesc =>
      'Un transfert identique était déjà en cours. Celui-ci a été arrêté avant tout prélèvement pour ne pas te débiter deux fois.';

  @override
  String get transferFailInvalidRecipientTitle => 'Bénéficiaire introuvable';

  @override
  String get transferFailInvalidRecipientDesc =>
      'Le numéro ou le portefeuille indiqué n\'existe pas chez l\'opérateur.';

  @override
  String get transferFailDeclinedTitle => 'Paiement refusé';

  @override
  String get transferFailDeclinedDesc =>
      'Ta banque a refusé le paiement. Ce refus vient de l\'émetteur de la carte, pas de l\'application.';

  @override
  String get transferFailInsufficientTitle => 'Provision insuffisante';

  @override
  String get transferFailInsufficientDesc =>
      'Le moyen de paiement n\'avait pas assez de fonds pour couvrir le montant et les frais.';

  @override
  String get transferFailTimeoutTitle => 'Traitement interrompu';

  @override
  String get transferFailTimeoutDesc =>
      'La connexion a été coupée pendant le traitement. L\'issue n\'est pas encore connue.';

  @override
  String get transferDebitNotCharged => 'Aucun montant n\'a été prélevé.';

  @override
  String get transferDebitCharged =>
      'Le montant a été prélevé et n\'a pas encore été rendu.';

  @override
  String get transferDebitUncertain =>
      'Nous ne savons pas encore si le montant a été prélevé — ne relance pas le transfert avant vérification.';

  @override
  String get transferActionFixRecipient => 'Corriger le bénéficiaire';

  @override
  String get audioRoomReconnecting => 'Reconnexion en cours…';

  @override
  String get audioRoomReconnectingHint =>
      'Le son est coupé le temps de retrouver le salon.';

  @override
  String get audioRoomAudioLost => 'Connexion audio perdue';

  @override
  String get audioRoomAudioLostHint =>
      'Vous êtes toujours dans le salon, mais vous n\'entendez plus personne.';

  @override
  String get podcastRecordMicTitle => 'Enregistrer au micro';

  @override
  String get podcastRecordMicHint =>
      'Ou enregistre directement depuis le téléphone.';

  @override
  String get podcastRecordStart => 'Enregistrer';

  @override
  String get podcastRecordStop => 'Terminer';

  @override
  String get podcastRecordPause => 'Pause';

  @override
  String get podcastRecordResume => 'Reprendre';

  @override
  String get podcastRecordDiscard => 'Annuler l\'enregistrement';

  @override
  String get podcastRecordPermissionDenied =>
      'Accès au micro refusé. Autorise le micro dans les réglages du téléphone.';

  @override
  String get podcastRecordFailed =>
      'L\'enregistrement n\'a pas pu être sauvegardé.';

  @override
  String get podcastRecordedFileName => 'Enregistrement micro';

  @override
  String get podcastStatsTitle => 'Statistiques';

  @override
  String get podcastStatsTotalPlays => 'Écoutes';

  @override
  String get podcastStatsSubscribers => 'Abonnés';

  @override
  String get podcastStatsEpisodes => 'Épisodes';

  @override
  String get podcastStatsTotalDuration => 'Durée publiée';

  @override
  String get podcastStatsEngagementTitle => 'Engagement';

  @override
  String get podcastStatsLikes => 'J\'aime';

  @override
  String get podcastStatsShares => 'Partages';

  @override
  String get podcastStatsDownloads => 'Téléchargements';

  @override
  String get podcastStatsAvgPlaysPerEpisode => 'Moyenne par épisode';

  @override
  String get podcastStatsTopEpisodesTitle => 'Épisodes les plus écoutés';

  @override
  String get podcastStatsRhythmTitle => 'Rythme de publication';

  @override
  String get podcastStatsLastEpisode => 'Dernier épisode';

  @override
  String get podcastStatsAvgInterval => 'Intervalle moyen';

  @override
  String podcastStatsIntervalDays(int days) {
    return '$days jours';
  }

  @override
  String get podcastStatsNoData =>
      'Pas encore d\'épisode publié — rien à mesurer.';

  @override
  String get podcastStatsNoHistoryNote =>
      'Ces chiffres sont des totaux cumulés. L\'application ne conserve pas d\'historique daté, donc aucune évolution dans le temps ne peut être affichée.';

  @override
  String podcastStatsPlaysCount(int count) {
    return '$count écoutes';
  }

  @override
  String get groupJoined => 'Vous avez rejoint le groupe';

  @override
  String get leaveGroupTitle => 'Quitter le groupe';

  @override
  String get leaveGroupConfirm => 'Voulez-vous vraiment quitter ce groupe ?';

  @override
  String get groupLeft => 'Vous avez quitté le groupe';

  @override
  String get member => 'Membre';

  @override
  String get joinGroup => 'Rejoindre';

  @override
  String get shareGroup => 'Partager le groupe';

  @override
  String get shareVia => 'Partager via';

  @override
  String get scanToJoin => 'Scannez pour rejoindre';

  @override
  String joinGroupInvite(String groupName, String link) {
    return 'Rejoignez le groupe \"$groupName\" sur Diaspo Niger : $link';
  }

  @override
  String get deletedUser => 'Utilisateur supprimé';

  @override
  String sharePostMessage(String authorName, String preview, String link) {
    return '$authorName sur Diaspo Niger :\n\n$preview\n\n$link';
  }

  @override
  String get leaveGroup => 'Quitter';

  @override
  String members(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count membres',
      one: '1 membre',
      zero: 'Aucun membre',
    );
    return '$_temp0';
  }

  @override
  String get createGroup => 'Créer un groupe';

  @override
  String get groupDetails => 'Détails du groupe';

  @override
  String get groupDescription => 'Description du groupe';

  @override
  String get admins => 'Admins';

  @override
  String get private => 'Privé';

  @override
  String get public => 'Public';

  @override
  String get access => 'Accès';

  @override
  String get aboutGroup => 'À propos';

  @override
  String createdBy(String name) {
    return 'Créé par $name';
  }

  @override
  String get creator => 'Créateur';

  @override
  String get noOtherMembers => 'Aucun autre membre pour le moment';

  @override
  String get discussion => 'Discussion';

  @override
  String get joinTheGroup => 'Rejoindre le groupe';

  @override
  String get errorOpeningDiscussion =>
      'Erreur lors de l\'ouverture de la discussion';

  @override
  String get friendsTitle => 'Amis';

  @override
  String get friends => 'Amis';

  @override
  String get received => 'Reçues';

  @override
  String get sent => 'Envoyées';

  @override
  String get noFriends => 'Aucun ami';

  @override
  String get noFriendsHint => 'Commencez à ajouter des amis pour les voir ici';

  @override
  String get noRequests => 'Aucune demande';

  @override
  String get receivedRequestsHint =>
      'Les demandes d\'amis reçues apparaîtront ici';

  @override
  String get sentRequestsHint =>
      'Les demandes d\'amis envoyées apparaîtront ici';

  @override
  String get sendMessage => 'Envoyer un message';

  @override
  String get cancelRequest => 'Annuler la demande';

  @override
  String get removeFriend => 'Retirer des amis';

  @override
  String get removeFriendConfirm =>
      'Voulez-vous vraiment retirer cette personne de vos amis ?';

  @override
  String get friendRemoved => 'Ami retiré';

  @override
  String get requestCancelled => 'Demande annulée';

  @override
  String get profileTitle => 'Profil';

  @override
  String get editProfileTitle => 'Modifier le profil';

  @override
  String get firstName => 'Prénom';

  @override
  String get lastName => 'Nom';

  @override
  String get bio => 'Bio';

  @override
  String get profession => 'Profession';

  @override
  String get city => 'Ville';

  @override
  String get country => 'Pays';

  @override
  String get phoneNumber => 'Numéro de téléphone';

  @override
  String get saveChanges => 'Enregistrer les modifications';

  @override
  String get profileUpdated => 'Profil mis à jour';

  @override
  String get profileUpdatedSuccess => 'Profil mis à jour avec succès';

  @override
  String get changePhoto => 'Changer la photo';

  @override
  String get basicInfo => 'Informations de base';

  @override
  String get fullName => 'Nom complet';

  @override
  String get enterYourName => 'Veuillez entrer votre nom';

  @override
  String get phone => 'Téléphone';

  @override
  String get location => 'Position';

  @override
  String get currentCity => 'Ville actuelle';

  @override
  String get originCity => 'Ville d\'origine au Niger';

  @override
  String get interests => 'Centres d\'intérêt';

  @override
  String get spokenLanguages => 'Langues parlées';

  @override
  String get otherMembersCanSee =>
      'Les autres membres peuvent voir votre profil';

  @override
  String get connections => 'Connexions';

  @override
  String get myLocation => 'Ma localisation';

  @override
  String get preferences => 'Préférences';

  @override
  String get darkTheme => 'Thème sombre';

  @override
  String get disabled => 'Désactivé';

  @override
  String get helpFaq => 'Aide & FAQ';

  @override
  String get homeTitle => 'Accueil';

  @override
  String get discover => 'Découvrir';

  @override
  String get welcome => 'Bienvenue';

  @override
  String get hello => 'Bonjour';

  @override
  String get membersLabel => 'Membres';

  @override
  String get membersNearby => 'Membres à proximité';

  @override
  String get aroundYou => 'Autour de vous';

  @override
  String get theMap => 'La carte';

  @override
  String get noMembersNearby => 'Aucun membre à proximité';

  @override
  String get enableNearbyMembers => 'Activer les membres à proximité';

  @override
  String get disableNearbyMembers => 'Désactiver les membres à proximité';

  @override
  String get nearbyMembersDisabled => 'Mode privé activé';

  @override
  String get nearbyMembersDisabledHint =>
      'Activez pour voir les membres à proximité et apparaître sur leur carte';

  @override
  String get searchMembersGroups => 'Rechercher un membre, un groupe…';

  @override
  String get createOrJoinEvents => 'Créez ou rejoignez des événements';

  @override
  String get upcomingEvents => 'Événements à venir';

  @override
  String get popularGroups => 'Groupes populaires';

  @override
  String get recentMembers => 'Membres récents';

  @override
  String get seeAll => 'Voir tout';

  @override
  String get mapTitle => 'Carte';

  @override
  String get searchTitle => 'Recherche';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get noNotifications => 'Aucune notification';

  @override
  String get noNotificationsHint =>
      'Vous serez notifié des nouvelles activités';

  @override
  String get markAllAsRead => 'Tout marquer comme lu';

  @override
  String get deleteAll => 'Tout supprimer';

  @override
  String get deleteAllNotifications => 'Supprimer toutes les notifications';

  @override
  String get deleteAllNotificationsConfirm =>
      'Voulez-vous vraiment supprimer toutes vos notifications ?';

  @override
  String get justNow => 'À l\'instant';

  @override
  String secondsAgo(int count) {
    return 'Il y a $count s';
  }

  @override
  String minutesAgo(int count) {
    return 'Il y a $count minute(s)';
  }

  @override
  String hoursAgo(int count) {
    return 'Il y a $count heure(s)';
  }

  @override
  String daysAgo(int count) {
    return 'Il y a $count jour(s)';
  }

  @override
  String weeksAgo(int count) {
    return 'Il y a $count sem';
  }

  @override
  String monthsAgo(int count) {
    return 'Il y a $count mois';
  }

  @override
  String yearsAgo(int count) {
    return 'Il y a $count an(s)';
  }

  @override
  String get participantsTitle => 'Participants';

  @override
  String get errorNetwork =>
      'Pas de connexion internet. Vérifiez votre connexion et réessayez.';

  @override
  String get errorServer => 'Erreur du serveur. Veuillez réessayer plus tard.';

  @override
  String get errorCache => 'Erreur de lecture des données locales.';

  @override
  String get errorAuth =>
      'Erreur d\'authentification. Veuillez vous reconnecter.';

  @override
  String get errorTimeout => 'La requête a expiré. Veuillez réessayer.';

  @override
  String get errorUnknown => 'Une erreur inattendue s\'est produite.';

  @override
  String get offlineMode => 'Mode hors ligne';

  @override
  String get offlineBannerMessage =>
      'Vous êtes hors ligne. Certaines fonctionnalités peuvent être limitées.';

  @override
  String get syncingLabel => 'Synchronisation…';

  @override
  String pendingSyncCount(int count) {
    return '$count en attente';
  }

  @override
  String retryIn(int seconds) {
    return 'Réessayer dans ${seconds}s';
  }

  @override
  String get connectionRestored => 'Connexion rétablie';

  @override
  String get eventTitle => 'Titre de l\'événement';

  @override
  String get eventTitleRequired => 'Titre de l\'événement *';

  @override
  String get eventTitleHint => 'Ex: Rencontre entrepreneurs Niger';

  @override
  String get eventTitleRequiredError => 'Le titre est requis';

  @override
  String get eventTitleTooShort =>
      'Le titre doit contenir au moins 5 caractères';

  @override
  String get description => 'Description';

  @override
  String get descriptionRequired => 'La description est requise';

  @override
  String get descriptionHint => 'Décrivez votre événement...';

  @override
  String get descriptionRequiredError => 'Entrez une description';

  @override
  String get descriptionTooShort =>
      'La description doit contenir au moins 20 caractères';

  @override
  String get category => 'Catégorie';

  @override
  String get startDateTime => 'Date et heure de début *';

  @override
  String get endDateTimeOptional => 'Date et heure de fin (optionnel)';

  @override
  String get endDate => 'Date de fin';

  @override
  String get endTime => 'Heure de fin';

  @override
  String get onlineEvent => 'Événement en ligne';

  @override
  String get onlineEventDescription =>
      'L\'événement se déroule en visioconférence';

  @override
  String get videoConferenceLink => 'Lien de la visioconférence';

  @override
  String get videoConferenceLinkHint => 'Ex: https://zoom.us/j/...';

  @override
  String get locationRequired => 'Localisation requise';

  @override
  String get locationHint => 'Ex: Paris, France';

  @override
  String get locationRequiredError => 'Le lieu est requis';

  @override
  String get addressOptional => 'Adresse (optionnel)';

  @override
  String get addressHint => 'Ex: 123 Rue de la Paix';

  @override
  String get maxAttendeesOptional => 'Nombre max de participants (optionnel)';

  @override
  String get maxAttendeesHint => 'Ex: 50';

  @override
  String get unlimitedAttendees => 'Laissez vide pour un nombre illimité';

  @override
  String get createEventButton => 'Créer l\'événement';

  @override
  String get editEvent => 'Modifier l\'événement';

  @override
  String get saveModifications => 'Enregistrer les modifications';

  @override
  String get eventCreatedSuccess => 'Événement créé avec succès';

  @override
  String get eventCreationError => 'Erreur lors de la création';

  @override
  String get eventUpdatedSuccess => 'Événement modifié avec succès';

  @override
  String get eventUpdateError => 'Erreur lors de la modification';

  @override
  String get youAreHere => 'Vous êtes ici';

  @override
  String get viewProfile => 'Voir le profil';

  @override
  String get message => 'Message';

  @override
  String get searchRadius => 'Rayon de recherche';

  @override
  String get searchRadiusDescription =>
      'Sélectionnez la distance maximale pour trouver des membres';

  @override
  String get wholeCountry => 'Pays entier';

  @override
  String get everywhere => 'Global';

  @override
  String get everywhereLabel => 'Global';

  @override
  String get countryLabel => 'Pays';

  @override
  String get filterAll => 'Tous';

  @override
  String get filterEntrepreneurs => 'Entrepreneurs';

  @override
  String get filterStudents => 'Étudiants';

  @override
  String get filterProfessionals => 'Professionnels';

  @override
  String get filterArtists => 'Artistes';

  @override
  String get enableLocationServices => 'Activez les services de localisation';

  @override
  String get locationPermissionDenied => 'Permission de localisation refusée';

  @override
  String get unableToGetLocation => 'Impossible d\'obtenir la position';

  @override
  String get settingsLabel => 'Réglages';

  @override
  String get modifyYourInfo => 'Modifier vos informations';

  @override
  String get myFriends => 'Mes amis';

  @override
  String get manageConnections => 'Gérer vos connexions';

  @override
  String get callHistoryTitle => 'Historique d\'appels';

  @override
  String get callHistorySubtitle => 'Vos appels passés et manqués';

  @override
  String get shareMyProfile => 'Partager mon profil';

  @override
  String get qrCodeAndShareLink => 'QR code et lien de partage';

  @override
  String get manageAlerts => 'Gérer les notifications';

  @override
  String get appearInSearchesDesc => 'Apparaître dans les recherches';

  @override
  String get appearOnMapDesc => 'Apparaître sur la carte';

  @override
  String get receiveNotificationsDesc => 'Recevoir des notifications';

  @override
  String get supportEmail => 'support@diasponiger.com';

  @override
  String get helpUsImprove => 'Aidez-nous à améliorer l\'app';

  @override
  String get rateUsOnStore => 'Notez-nous sur le store';

  @override
  String get deleteAccountTitle => 'Supprimer le compte';

  @override
  String get filterUnread => 'Non lus';

  @override
  String get filterFriends => 'Amis';

  @override
  String get notificationSettings => 'Paramètres de notifications';

  @override
  String get notificationsDisabled => 'Notifications désactivées';

  @override
  String get notificationsDisabledDesc =>
      'Activez les notifications pour recevoir les alertes de messages et d\'appels.';

  @override
  String get notificationContent => 'Contenu';

  @override
  String get notificationAlerts => 'Alertes';

  @override
  String get notificationAdvanced => 'Avancé';

  @override
  String get notifyMessages => 'Messages';

  @override
  String get notifyEvents => 'Événements';

  @override
  String get notifyFriendRequests => 'Demandes d\'amis';

  @override
  String get notifyGroups => 'Groupes';

  @override
  String get notifyEventReminders => 'Rappels d\'événements';

  @override
  String get notificationSound => 'Son';

  @override
  String get notificationVibration => 'Vibration';

  @override
  String get quietHours => 'Mode silencieux';

  @override
  String get quietHoursDesc => 'Ne pas déranger pendant ces heures';

  @override
  String get quietHoursStart => 'Début';

  @override
  String get quietHoursEnd => 'Fin';

  @override
  String get notificationDetail => 'Détail de la notification';

  @override
  String get open => 'Ouvrir';

  @override
  String get markAsRead => 'Marquer comme lu';

  @override
  String get accountDeletedSuccess => 'Votre compte a été supprimé avec succès';

  @override
  String get errorDeletingAccount => 'Erreur lors de la suppression';

  @override
  String get allRightsReserved => '© 2025 Diaspo Niger. Tous droits réservés.';

  @override
  String get mobileAppDescription =>
      'Plateforme mobile de mise en relation de la diaspora nigérienne.';

  @override
  String get currentCountry => 'Pays actuel';

  @override
  String get originRegion => 'Région d\'origine au Niger (optionnel)';

  @override
  String get skills => 'Compétences';

  @override
  String get languagesSpoken => 'Langues';

  @override
  String get profileNotFound =>
      'Profil introuvable. Veuillez redémarrer l\'application.';

  @override
  String get deletedProfile => 'Profil supprimé';

  @override
  String get accountNoLongerExists => 'Ce compte n\'existe plus';

  @override
  String livingIn(String city, String country) {
    return 'Vit à $city, $country';
  }

  @override
  String fromRegion(String region) {
    return 'Originaire de $region';
  }

  @override
  String fromCity(String city) {
    return 'Originaire de $city';
  }

  @override
  String get scanQRCode => 'Scanner un QR code';

  @override
  String get scanQRCodeTitle => 'Scanner un profil';

  @override
  String get scanQRCodeDescription =>
      'Placez le QR code dans le cadre pour scanner';

  @override
  String get qrCodeScanned => 'QR code scanné avec succès';

  @override
  String get invalidQRCode => 'QR code invalide';

  @override
  String get cameraPermissionDenied =>
      'L\'accès à la caméra a été refusé. Veuillez l\'activer dans les paramètres de l\'application.';

  @override
  String get enableFlash => 'Activer le flash';

  @override
  String get disableFlash => 'Désactiver le flash';

  @override
  String get switchCamera => 'Changer de caméra';

  @override
  String systemMessageUserJoined(String userName) {
    return '$userName a rejoint le groupe';
  }

  @override
  String systemMessageUserLeft(String userName) {
    return '$userName a quitté le groupe';
  }

  @override
  String systemMessageUserRemoved(String userName) {
    return '$userName a été retiré du groupe';
  }

  @override
  String systemMessageUserPromoted(String userName) {
    return '$userName est maintenant administrateur';
  }

  @override
  String systemMessageUserDemoted(String userName) {
    return '$userName n\'est plus administrateur';
  }

  @override
  String systemMessageGroupRenamed(String newName) {
    return 'Le groupe a été renommé en $newName';
  }

  @override
  String get audioRoomsTitle => 'Salons Audio';

  @override
  String get createAudioRoom => 'Créer un salon';

  @override
  String get scheduleAudioRoom => 'Programmer un salon';

  @override
  String get audioRoomTitle => 'Titre du salon *';

  @override
  String get audioRoomTitleHint => 'Ex: Discussion sur l\'entrepreneuriat';

  @override
  String get audioRoomTitleRequired => 'Veuillez entrer un titre';

  @override
  String get audioRoomDescription => 'Description';

  @override
  String get audioRoomDescriptionHint => 'De quoi allez-vous parler ?';

  @override
  String get audioRoomCategory => 'Catégorie';

  @override
  String get audioRoomMode => 'Mode du salon';

  @override
  String get audioRoomPrivate => 'Salon privé';

  @override
  String get audioRoomPrivateDesc =>
      'Seules les personnes invitées peuvent rejoindre';

  @override
  String get audioRoomRecording => 'Enregistrer le salon';

  @override
  String get audioRoomRecordingDesc =>
      'Permettre l\'enregistrement pour replay';

  @override
  String get audioRoomPaid => 'PAYANT';

  @override
  String get audioRoomPaidDesc => 'Les participants doivent acheter un ticket';

  @override
  String get audioRoomTags => 'Tags';

  @override
  String get audioRoomCreatedSuccess => 'Salon créé avec succès !';

  @override
  String get audioRoomCreationError => 'Erreur lors de la création';

  @override
  String audioRoomScheduledSuccess(String date) {
    return 'Salon programmé pour le $date';
  }

  @override
  String get audioRoomScheduleError => 'Erreur lors de la programmation';

  @override
  String get audioRoomDateMustBeFuture => 'La date doit être dans le futur';

  @override
  String get audioRoomOptions => 'Options du salon';

  @override
  String get audioRoomShare => 'Partager le salon';

  @override
  String get audioRoomCopyLink => 'Copier le lien';

  @override
  String get audioRoomLinkCopied => 'Lien copié dans le presse-papier';

  @override
  String get audioRoomManageRecording => 'Gérer l\'enregistrement';

  @override
  String get audioRoomSettings => 'Paramètres du salon';

  @override
  String get audioRoomEndRoom => 'Terminer le salon';

  @override
  String get audioRoomEndRoomConfirm => 'Terminer le salon ?';

  @override
  String get audioRoomEndRoomWarning =>
      'Cette action mettra fin au salon pour tous les participants. Cette action est irréversible.';

  @override
  String get audioRoomReport => 'Signaler le salon';

  @override
  String get audioRoomReportSent => 'Signalement bientôt disponible';

  @override
  String get audioRoomSettingsComingSoon => 'Paramètres bientôt disponibles';

  @override
  String get audioRoomRecordingComingSoon =>
      'Gestion d\'enregistrement bientôt disponible';

  @override
  String get audioRoomShareComingSoon =>
      'Fonctionnalité de partage bientôt disponible';

  @override
  String get audioRoomLive => 'EN DIRECT';

  @override
  String get audioRoomScheduled => 'Programmé';

  @override
  String get audioRoomEnded => 'Terminé';

  @override
  String audioRoomParticipants(int count) {
    return '$count participants';
  }

  @override
  String audioRoomHostedBy(String name) {
    return 'Animé par $name';
  }

  @override
  String get audioRoomJoinUs => 'Rejoignez-nous !';

  @override
  String get audioRoomCategoryGeneral => 'Général';

  @override
  String get audioRoomCategoryGriot => 'Griot / Contes';

  @override
  String get audioRoomCategorySpirituality => 'Spiritualité';

  @override
  String get audioRoomCategoryNews => 'Actualités';

  @override
  String get audioRoomCategoryBusiness => 'Business';

  @override
  String get audioRoomCategoryMentorship => 'Mentorat';

  @override
  String get audioRoomCategoryFamily => 'Famille';

  @override
  String get audioRoomCategoryOfficial => 'Officiel';

  @override
  String get audioRoomCategoryCulture => 'Culture';

  @override
  String get audioRoomCategoryEducation => 'Éducation';

  @override
  String get audioRoomModeNormal => 'Normal';

  @override
  String get audioRoomModeCeremony => 'Cérémonie';

  @override
  String get audioRoomModeRadio => 'Radio';

  @override
  String get audioRoomModeHeritage => 'Patrimoine';

  @override
  String get audioRoomCollection => 'Collecte';

  @override
  String get audioRoomCollectionNone => 'Pas de collecte';

  @override
  String get audioRoomCollectionFamilyEvent => 'Événement familial';

  @override
  String get audioRoomCollectionEmergency => 'Aide d\'urgence';

  @override
  String get audioRoomCollectionCommunityProject => 'Projet communautaire';

  @override
  String get audioRoomCollectionAssociationDues => 'Cotisation association';

  @override
  String get audioRoomCollectionCustom => 'Personnalisé';

  @override
  String get audioRoomCollectionGoal => 'Objectif de collecte';

  @override
  String get audioRoomCollectionDescription => 'Description de la collecte';

  @override
  String get audioRoomCollectionBeneficiary => 'Bénéficiaire';

  @override
  String get audioRoomHeritageContent => 'Contenu patrimoine';

  @override
  String get audioRoomHeritageContentDesc =>
      'Enregistrement pour la préservation culturelle';

  @override
  String get audioRoomHeritageLanguage => 'Langue du contenu';

  @override
  String get audioRoomHeritageRegion => 'Région d\'origine';

  @override
  String get audioRoomLinkedContent => 'Lier ce salon à :';

  @override
  String get audioRoomLinkedEvent => 'Événement';

  @override
  String get audioRoomLinkedEventNone => 'Aucun événement lié';

  @override
  String get audioRoomLinkedGroup => 'Groupe';

  @override
  String get audioRoomLinkedGroupNone => 'Aucun groupe lié';

  @override
  String get audioRoomLinkedEmbassy => 'Ambassade/Consulat';

  @override
  String get audioRoomLinkedEmbassyNone => 'Aucune ambassade liée';

  @override
  String get audioRoomSearchEvent => 'Rechercher un événement...';

  @override
  String get audioRoomSearchGroup => 'Rechercher un groupe...';

  @override
  String get audioRoomSearchEmbassy => 'Rechercher une ambassade...';

  @override
  String get audioRoomLinkEvent => 'Lier un événement';

  @override
  String get audioRoomLinkGroup => 'Lier un groupe';

  @override
  String get audioRoomLinkEmbassy => 'Lier une ambassade/consulat';

  @override
  String get audioRoomNoEventFound => 'Aucun événement trouvé';

  @override
  String get audioRoomNoGroupFound => 'Aucun groupe trouvé';

  @override
  String get audioRoomNoEmbassyFound => 'Aucune ambassade trouvée';

  @override
  String get audioRoomRemove => 'Retirer';

  @override
  String get audioRoomSpeakers => 'SPEAKERS';

  @override
  String get audioRoomListeners => 'LISTENERS';

  @override
  String get audioRoomHandsRaised => 'Mains levées';

  @override
  String get audioRoomRaiseHand => 'Lever la main';

  @override
  String get audioRoomLowerHand => 'Baisser la main';

  @override
  String get audioRoomLeave => 'Quitter';

  @override
  String get audioRoomMute => 'Muet';

  @override
  String get audioRoomUnmute => 'Activer le micro';

  @override
  String get audioRoomVerified => 'Vérifié';

  @override
  String get audioRoomNotVerified => 'Non vérifié';

  @override
  String get audioRoomEmbassy => 'Ambassade';

  @override
  String get audioRoomConsulate => 'Consulat';

  @override
  String get audioRoomHeritageLibrary => 'Bibliothèque du patrimoine';

  @override
  String get audioRoomHeritageDiscover => 'Découvrir';

  @override
  String get audioRoomHeritageCategories => 'Catégories';

  @override
  String get audioRoomHeritageSaved => 'Enregistrés';

  @override
  String get audioRoomBack => 'Retour';

  @override
  String get audioRoomAudioRoom => 'Salon Audio';

  @override
  String audioRoomPromoteUser(String userName) {
    return 'Promouvoir $userName';
  }

  @override
  String get audioRoomPromoteQuestion =>
      'Voulez-vous donner la parole à cet utilisateur ?';

  @override
  String get audioRoomPromote => 'Promouvoir';

  @override
  String get audioRoomEnd => 'Terminer';

  @override
  String get audioRoomCreateRoom => 'Créer un salon';

  @override
  String get audioRoomBasicInfo => 'Informations de base';

  @override
  String get audioRoomTitleLabel => 'Titre du salon *';

  @override
  String get audioRoomTitleHintExample => 'Ex: Discussion Tech Niger';

  @override
  String get audioRoomEnterTitle => 'Veuillez entrer un titre';

  @override
  String get audioRoomTitleMinLength =>
      'Le titre doit contenir au moins 3 caractères';

  @override
  String get audioRoomPleaseFixErrors =>
      'Veuillez corriger les erreurs avant de continuer';

  @override
  String get audioRoomDescriptionLabel => 'Description';

  @override
  String get audioRoomDescriptionHintWhat => 'De quoi allez-vous parler ?';

  @override
  String get audioRoomCategoryLabel => 'Catégorie';

  @override
  String get audioRoomModeLabel => 'Mode du salon';

  @override
  String get audioRoomTagsOptional => 'Tags (optionnel)';

  @override
  String get audioRoomMaxTags => 'Maximum 3 tags';

  @override
  String get audioRoomFundraising => 'Collecte de fonds';

  @override
  String get audioRoomCulturalHeritage => 'Patrimoine culturel';

  @override
  String get audioRoomLinks => 'Liens';

  @override
  String get audioRoomSettingsLabel => 'Réglages';

  @override
  String get audioRoomPrivateRoom => 'Salon privé';

  @override
  String get audioRoomPrivateRoomDesc =>
      'Seules les personnes invitées peuvent rejoindre';

  @override
  String get audioRoomEnableRecording => 'Activer l\'enregistrement';

  @override
  String get audioRoomEnableRecordingDesc =>
      'Le salon sera enregistré pour le replay';

  @override
  String get audioRoomPaidRoom => 'Salon payant';

  @override
  String get audioRoomPaidRoomDesc =>
      'Les participants doivent acheter un ticket';

  @override
  String get audioRoomCurrencyLabel => 'Devise';

  @override
  String get audioRoomTicketPriceLabel => 'Prix du ticket';

  @override
  String get audioRoomTicketPriceRequired =>
      'Veuillez entrer le prix du ticket';

  @override
  String get audioRoomTicketPriceInvalid =>
      'Le prix doit être un nombre valide';

  @override
  String get audioRoomMinPrice => 'Le prix minimum est';

  @override
  String get audioRoomMaxPrice => 'Le prix maximum est';

  @override
  String get audioRoomCommissionInfoTitle => 'Commission plateforme';

  @override
  String get audioRoomCommissionLabel => 'Commission';

  @override
  String get audioRoomYouReceive => 'Vous recevez';

  @override
  String get audioRoomEstimatedEarnings => 'Gains estimés';

  @override
  String get audioRoomCreating => 'Création...';

  @override
  String get audioRoomStartRoom => 'Démarrer le salon';

  @override
  String get audioRoomScheduleForLater => 'Programmer pour plus tard';

  @override
  String get audioRoomCreatedSuccessfully => 'Salon créé avec succès !';

  @override
  String get audioRoomCreationErrorGeneric => 'Erreur lors de la création';

  @override
  String get audioRoomCategoryDiscussion => 'Discussion';

  @override
  String get audioRoomCategoryGriotStory => 'Griot/Conte';

  @override
  String get audioRoomCategorySpiritualityLabel => 'Spiritualité';

  @override
  String get audioRoomCategoryNewsLabel => 'Actualités';

  @override
  String get audioRoomCategoryBusinessLabel => 'Business';

  @override
  String get audioRoomCategoryMentorshipLabel => 'Mentorat';

  @override
  String get audioRoomCategoryFamilyLabel => 'Famille';

  @override
  String get audioRoomCategoryOfficialLabel => 'Officiel';

  @override
  String get audioRoomCategoryCultureLabel => 'Culture';

  @override
  String get audioRoomCategoryEducationLabel => 'Éducation';

  @override
  String get audioRoomModeNormalLabel => 'Normal';

  @override
  String get audioRoomModeCeremonyLabel => 'Cérémonie';

  @override
  String get audioRoomModeRadioLabel => 'Radio';

  @override
  String get audioRoomModeHeritageLabel => 'Patrimoine';

  @override
  String get audioRoomCollectionTypeNone => 'Aucune';

  @override
  String get audioRoomCollectionFamilyEventLabel => 'Événement familial';

  @override
  String get audioRoomCollectionEmergencyAid => 'Aide d\'urgence';

  @override
  String get audioRoomCollectionCommunityProjectLabel => 'Projet communautaire';

  @override
  String get audioRoomCollectionDues => 'Cotisation';

  @override
  String get audioRoomCollectionCustomLabel => 'Personnalisé';

  @override
  String get audioRoomCollectionGoalLabel => 'Objectif (XOF)';

  @override
  String get audioRoomCollectionGoalHint => 'Ex: 100000';

  @override
  String get audioRoomCollectionEnterGoal => 'Veuillez entrer un objectif';

  @override
  String get audioRoomCollectionInvalidAmount => 'Montant invalide';

  @override
  String get audioRoomCollectionBeneficiaryLabel => 'Bénéficiaire';

  @override
  String get audioRoomCollectionBeneficiaryHint => 'Nom du bénéficiaire';

  @override
  String get audioRoomCollectionDescriptionLabel =>
      'Description de la collecte';

  @override
  String get audioRoomHeritageContentLabel => 'Contenu patrimonial';

  @override
  String get audioRoomHeritageLanguageLabel => 'Langue';

  @override
  String get audioRoomHeritageRegionLabel => 'Région d\'origine';

  @override
  String get audioRoomLinkTo => 'Lier ce salon à :';

  @override
  String get audioRoomEventLabel => 'Événement';

  @override
  String get audioRoomNoLinkedEvent => 'Aucun événement lié';

  @override
  String get audioRoomGroupLabel => 'Groupe';

  @override
  String get audioRoomNoLinkedGroup => 'Aucun groupe lié';

  @override
  String get audioRoomEmbassyConsulate => 'Ambassade/Consulat';

  @override
  String get audioRoomNoLinkedEmbassy => 'Aucune ambassade liée';

  @override
  String get audioRoomScheduleRoom => 'Programmer un salon';

  @override
  String get audioRoomTitleWeeklyExample => 'Ex: Discussion hebdomadaire Tech';

  @override
  String get audioRoomDateAndTime => 'Date et heure';

  @override
  String get audioRoomDate => 'Date';

  @override
  String get audioRoomTime => 'Heure';

  @override
  String get audioRoomSendReminders => 'Envoyer des rappels';

  @override
  String get audioRoomSendRemindersDesc =>
      'Notifier les participants 15 min avant';

  @override
  String get audioRoomScheduling => 'Programmation...';

  @override
  String get audioRoomScheduleTheRoom => 'Programmer le salon';

  @override
  String get audioRoomPreview => 'Aperçu';

  @override
  String get audioRoomDateMustBeFutureError =>
      'La date doit être dans le futur';

  @override
  String audioRoomScheduleSuccessDate(String date) {
    return 'Salon programmé pour le $date';
  }

  @override
  String get audioRoomScheduleErrorGeneric => 'Erreur lors de la programmation';

  @override
  String get audioRoomListTitle => 'Salons Audio';

  @override
  String get audioRoomCreateTooltip => 'Créer un salon';

  @override
  String get audioRoomLiveTab => 'En direct';

  @override
  String get audioRoomScheduledTab => 'Programmés';

  @override
  String get audioRoomStartARoom => 'Démarrer un salon';

  @override
  String get audioRoomNoLiveRooms => 'Aucun salon en direct';

  @override
  String get audioRoomBeFirstToStart =>
      'Soyez le premier à démarrer un salon !';

  @override
  String get audioRoomNoScheduledRooms => 'Aucun salon programmé';

  @override
  String get audioRoomScheduleRoomForLater =>
      'Programmez un salon pour plus tard';

  @override
  String get audioRoomLoadingError => 'Erreur de chargement';

  @override
  String get heritageLibraryTitle => 'Bibliothèque Culturelle';

  @override
  String get heritageLibraryNotAvailable =>
      'La bibliothèque culturelle n\'est pas disponible pour le moment.';

  @override
  String get heritageLibraryPreserve =>
      'Préservons notre patrimoine pour les générations futures';

  @override
  String get heritageLibrarySearch => 'Rechercher...';

  @override
  String get heritageLibraryLanguageFilter => 'Langue';

  @override
  String get heritageLibraryAllLanguages => 'Toutes les langues';

  @override
  String get heritageLibraryRegionFilter => 'Région';

  @override
  String get heritageLibraryAllRegions => 'Toutes les régions';

  @override
  String get heritageLibraryDiscoverTab => 'Découvrir';

  @override
  String get heritageLibraryCategoriesTab => 'Catégories';

  @override
  String get heritageLibrarySavedTab => 'Sauvegardés';

  @override
  String get heritageLibraryPopular => 'Populaires';

  @override
  String get heritageLibraryNoPopularRecordings =>
      'Aucun enregistrement populaire';

  @override
  String get heritageLibraryRecent => 'Récents';

  @override
  String get heritageLibraryNoRecordingsFound => 'Aucun enregistrement trouvé';

  @override
  String get heritageLibrarySeeAll => 'Voir tout';

  @override
  String get heritageLibraryNoCategoryRecordings =>
      'Aucun enregistrement dans cette catégorie';

  @override
  String get heritageLibraryNoSavedRecordings =>
      'Aucun enregistrement sauvegardé';

  @override
  String get heritageLibrarySaveHint =>
      'Appuyez sur l\'icône de signet pour sauvegarder';

  @override
  String get heritageContentTypeStories => 'Contes';

  @override
  String get heritageContentTypeProverbs => 'Proverbes';

  @override
  String get heritageContentTypeHistory => 'Histoire';

  @override
  String get heritageContentTypeCeremonies => 'Cérémonies';

  @override
  String get heritageContentTypeLanguage => 'Langue';

  @override
  String get heritageContentTypeCraft => 'Artisanat';

  @override
  String get heritageContentTypeRecipes => 'Recettes';

  @override
  String get heritageContentTypeMedicine => 'Médecine';

  @override
  String get heritageContentTypeOther => 'Autre';

  @override
  String get callTitle => 'Appel';

  @override
  String get callCalling => 'Appel en cours...';

  @override
  String get callConnecting => 'Connexion...';

  @override
  String get callUnableToStart => 'Impossible de démarrer l\'appel';

  @override
  String get callMute => 'Muet';

  @override
  String get callUnmute => 'Activer le micro';

  @override
  String get callSpeaker => 'Haut-parleur';

  @override
  String get callCamera => 'Caméra';

  @override
  String get callFlipCamera => 'Inverser';

  @override
  String get callHangUp => 'Raccrocher';

  @override
  String get callEnable => 'Activer';

  @override
  String get callEarpiece => 'Écouteur';

  @override
  String get incomingVideoCall => 'Appel vidéo entrant';

  @override
  String get incomingAudioCall => 'Appel audio entrant';

  @override
  String get incomingCallStatus => 'Appel entrant...';

  @override
  String get callDecline => 'Refuser';

  @override
  String get callAccept => 'Accepter';

  @override
  String get answerAudioOnly => 'Répondre en audio';

  @override
  String get callSwitchToVideo => 'Vidéo';

  @override
  String videoUpgradeRequest(String name) {
    return '$name souhaite passer en vidéo';
  }

  @override
  String get videoUpgradeWaiting =>
      'En attente de l\'acceptation de la vidéo...';

  @override
  String get videoUpgradeDeclined => 'Demande vidéo refusée';

  @override
  String get buyTicket => 'Acheter un ticket';

  @override
  String get buyTicketAcceptTerms => 'Veuillez accepter les conditions';

  @override
  String get buyTicketPurchaseSuccess => 'Ticket acheté avec succès !';

  @override
  String get buyTicketAcceptTermsCheckbox =>
      'J\'accepte les conditions d\'utilisation et la politique de remboursement';

  @override
  String buyTicketPay(String price) {
    return 'Payer $price';
  }

  @override
  String get buyTicketSecurePayment => 'Paiement sécurisé par Stripe';

  @override
  String get buyTicketTicketPrice => 'Prix du ticket';

  @override
  String get buyTicketTotal => 'Total à payer';

  @override
  String buyTicketHostedBy(String name) {
    return 'Animé par $name';
  }

  @override
  String get buyTicketFree => 'Gratuit';

  @override
  String get sendTip => 'Envoyer un pourboire';

  @override
  String get sendTipChooseAmount => 'Choisir un montant';

  @override
  String get sendTipCustomAmount => 'Montant personnalisé';

  @override
  String get sendTipMessageOptional => 'Message (optionnel)';

  @override
  String get sendTipMessageHint => 'Ajouter un message...';

  @override
  String sendTipSend(String amount) {
    return 'Envoyer $amount';
  }

  @override
  String get sendTipSelectAmount => 'Sélectionner un montant';

  @override
  String sendTipSuccess(String amount) {
    return 'Pourboire de $amount envoyé !';
  }

  @override
  String get sendTipOther => 'Autre';

  @override
  String get sendTipRoleHost => 'Hôte';

  @override
  String get sendTipRoleCoHost => 'Co-hôte';

  @override
  String get sendTipRoleSpeaker => 'Speaker';

  @override
  String get sendTipRoleListener => 'Auditeur';

  @override
  String get shareRoomLiveStatus => 'EN DIRECT';

  @override
  String get shareRoomScheduledStatus => 'Salon programmé';

  @override
  String get shareRoomOnDiaspoNiger => 'sur Diaspo Niger';

  @override
  String shareRoomHostedBy(String name) {
    return 'Animé par $name';
  }

  @override
  String shareRoomParticipantsCount(int count) {
    return '$count participants';
  }

  @override
  String get shareRoomJoinUs => 'Rejoignez-nous !';

  @override
  String get shareRoomLinkCopied => 'Lien copié dans le presse-papier';

  @override
  String get podcastsTitle => 'Podcasts';

  @override
  String get podcastsDiscover => 'Découvrir';

  @override
  String get podcastsCategories => 'Catégories';

  @override
  String get podcastsSubscriptions => 'Abonnements';

  @override
  String get podcastsTrending => 'Tendances';

  @override
  String get podcastsLatestEpisodes => 'Derniers épisodes';

  @override
  String get podcastsAllPodcasts => 'Tous les podcasts';

  @override
  String get podcastsSearch => 'Rechercher un podcast...';

  @override
  String get podcastsNoResults => 'Aucun podcast trouvé';

  @override
  String get podcastsNoSubscriptions => 'Aucun abonnement';

  @override
  String get podcastsNoSubscriptionsDesc =>
      'Abonnez-vous à des podcasts pour ne rien manquer';

  @override
  String get podcastsSubscribe => 'S\'abonner';

  @override
  String get podcastsSubscribed => 'Abonné';

  @override
  String get podcastsUnsubscribe => 'Se désabonner';

  @override
  String podcastsSubscribers(int count) {
    return '$count abonnés';
  }

  @override
  String podcastsEpisodes(int count) {
    return '$count épisodes';
  }

  @override
  String podcastsPlays(int count) {
    return '$count écoutes';
  }

  @override
  String get podcastsCreatePodcast => 'Créer un podcast';

  @override
  String get podcastsMyPodcasts => 'Mes podcasts';

  @override
  String get podcastsNoPodcasts => 'Vous n\'avez pas encore de podcast';

  @override
  String get podcastsNoPodcastsDesc =>
      'Créez votre premier podcast et partagez votre voix avec la communauté !';

  @override
  String get podcastsCreateFirst => 'Créer mon premier podcast';

  @override
  String get podcastsNewPodcast => 'Nouveau podcast';

  @override
  String get podcastsPodcastTitle => 'Titre du podcast *';

  @override
  String get podcastsPodcastTitleHint => 'Ex: Tech Niger';

  @override
  String get podcastsPodcastTitleRequired => 'Veuillez entrer un titre';

  @override
  String get podcastsPodcastDescription => 'Description';

  @override
  String get podcastsPodcastDescriptionHint => 'De quoi parle votre podcast ?';

  @override
  String get podcastsCoverImage => 'Image de couverture *';

  @override
  String get podcastsSelectCover => 'Sélectionner une image';

  @override
  String get podcastsChangeCover => 'Changer l\'image';

  @override
  String get podcastsCategory => 'Catégorie';

  @override
  String get podcastsLanguage => 'Langue principale';

  @override
  String get podcastsTags => 'Tags';

  @override
  String get podcastsTagsHint =>
      'Ajoutez des tags pour améliorer la découverte';

  @override
  String get podcastsExplicitContent => 'Contenu explicite';

  @override
  String get podcastsExplicitContentDesc =>
      'Ce podcast contient du contenu réservé aux adultes';

  @override
  String get podcastsEpisodeFrequency => 'Fréquence de publication';

  @override
  String get podcastsFrequencyWeekly => 'Hebdomadaire';

  @override
  String get podcastsFrequencyBiweekly => 'Bimensuel';

  @override
  String get podcastsFrequencyMonthly => 'Mensuel';

  @override
  String get podcastsFrequencyVariable => 'Variable';

  @override
  String get podcastsCreateButton => 'Créer le podcast';

  @override
  String get podcastsCreating => 'Création...';

  @override
  String get podcastsCreatedSuccess => 'Podcast créé avec succès !';

  @override
  String get podcastsCreationError => 'Erreur lors de la création';

  @override
  String get podcastsNewEpisode => 'Nouvel épisode';

  @override
  String get podcastsRecordEpisode => 'Enregistrer un épisode';

  @override
  String get podcastsUploadAudio => 'Uploader un fichier audio';

  @override
  String get podcastsSelectAudio => 'Sélectionner un fichier audio';

  @override
  String get podcastsAudioSelected => 'Fichier sélectionné';

  @override
  String podcastsEstimatedDuration(String duration) {
    return 'Durée estimée: $duration';
  }

  @override
  String get podcastsEpisodeTitle => 'Titre de l\'épisode *';

  @override
  String get podcastsEpisodeTitleRequired => 'Veuillez entrer un titre';

  @override
  String get podcastsEpisodeDescription => 'Description / Notes';

  @override
  String get podcastsChapters => 'Chapitres';

  @override
  String get podcastsAddChapter => 'Ajouter un chapitre';

  @override
  String get podcastsChapterTitle => 'Titre du chapitre';

  @override
  String get podcastsChapterTime => 'Temps de début';

  @override
  String get podcastsNoChapters => 'Aucun chapitre ajouté';

  @override
  String get podcastsPremiumEpisode => 'Épisode premium';

  @override
  String get podcastsPremiumEpisodeDesc => 'Réservé aux abonnés payants';

  @override
  String get podcastsPublishEpisode => 'Publier l\'épisode';

  @override
  String get podcastsPublishing => 'Publication...';

  @override
  String get podcastsPublishedSuccess => 'Épisode publié avec succès !';

  @override
  String get podcastsPublishError => 'Erreur lors de la publication';

  @override
  String get podcastsSelectAudioFirst =>
      'Veuillez sélectionner un fichier audio';

  @override
  String get podcastsEpisodeDetail => 'Détail de l\'épisode';

  @override
  String get podcastsPlay => 'Écouter';

  @override
  String get podcastsPause => 'Pause';

  @override
  String get podcastsDownload => 'Télécharger';

  @override
  String get podcastsDownloading => 'Téléchargement...';

  @override
  String get podcastsShare => 'Partager';

  @override
  String get podcastsLike => 'J\'aime';

  @override
  String get podcastsLiked => 'Aimé';

  @override
  String get podcastsSleepTimer => 'Minuterie de sommeil';

  @override
  String get podcastsSleepTimerOff => 'Désactivé';

  @override
  String podcastsSleepTimerMinutes(int minutes) {
    return '$minutes minutes';
  }

  @override
  String get podcastsSleepTimerEndOfEpisode => 'Fin de l\'épisode';

  @override
  String get podcastsPlaybackSpeed => 'Vitesse de lecture';

  @override
  String get podcastsFromLiveRoom =>
      'Cet épisode a été enregistré lors d\'un salon audio en direct';

  @override
  String get podcastsTranscription => 'Transcription';

  @override
  String get podcastsReport => 'Signaler';

  @override
  String get podcastsReportSent => 'Signalement envoyé';

  @override
  String get podcastsCategoryNews => 'Actualités';

  @override
  String get podcastsCategoryCulture => 'Culture';

  @override
  String get podcastsCategorySpirituality => 'Spiritualité';

  @override
  String get podcastsCategoryBusiness => 'Business';

  @override
  String get podcastsCategoryEntertainment => 'Divertissement';

  @override
  String get podcastsCategoryEducation => 'Éducation';

  @override
  String get podcastsCategoryStorytelling => 'Contes/Griot';

  @override
  String get podcastsCategorySports => 'Sports';

  @override
  String get podcastsCategoryPolitics => 'Politique';

  @override
  String get podcastsCategoryTechnology => 'Technologie';

  @override
  String get podcastsCategoryHealth => 'Santé';

  @override
  String get podcastsCategoryOther => 'Autre';

  @override
  String get podcastsStatusDraft => 'Brouillon';

  @override
  String get podcastsStatusPublished => 'Publié';

  @override
  String get podcastsStatusPaused => 'En pause';

  @override
  String get podcastsStatusArchived => 'Archivé';

  @override
  String get podcastsStatusScheduled => 'Programmé';

  @override
  String get podcastsDeletePodcast => 'Supprimer le podcast';

  @override
  String get podcastsDeletePodcastConfirm =>
      'Êtes-vous sûr de vouloir supprimer ce podcast et tous ses épisodes ?';

  @override
  String get podcastsDeletedSuccess => 'Podcast supprimé';

  @override
  String get podcastsEdit => 'Modifier';

  @override
  String get podcastsStats => 'Statistiques';

  @override
  String get podcastsViewAll => 'Voir tout';

  @override
  String get callHistory => 'Historique des appels';

  @override
  String get clearHistory => 'Effacer l\'historique';

  @override
  String get clearHistoryConfirmation =>
      'Êtes-vous sûr de vouloir effacer tout l\'historique des appels ?';

  @override
  String get clear => 'Effacer';

  @override
  String get noCallHistory => 'Aucun appel';

  @override
  String get noCallHistoryDescription =>
      'Vos appels audio et vidéo apparaîtront ici';

  @override
  String get noMissedCalls => 'Aucun appel manqué';

  @override
  String get noIncomingCalls => 'Aucun appel entrant';

  @override
  String get noOutgoingCalls => 'Aucun appel sortant';

  @override
  String get busyCall => 'Occupé';

  @override
  String today(String time) {
    return 'Aujourd\'hui';
  }

  @override
  String yesterday(String time) {
    return 'Hier';
  }

  @override
  String get missedCall => 'Appel manqué';

  @override
  String get declinedCall => 'Appel refusé';

  @override
  String get incomingCall => 'Appel entrant';

  @override
  String get outgoingCall => 'Appel sortant';

  @override
  String get audioCall => 'Appel audio';

  @override
  String get callConfirmMessage => 'Voulez-vous appeler';

  @override
  String get openLink => 'Ouvrir le lien';

  @override
  String get openLinkConfirmMessage => 'Voulez-vous ouvrir ce lien ?';

  @override
  String get videoCall => 'Appel vidéo';

  @override
  String get callEnded => 'Appel terminé';

  @override
  String callDuration(String duration) {
    return 'Durée: $duration';
  }

  @override
  String get noAnswer => 'Pas de réponse';

  @override
  String get callAgain => 'Rappeler';

  @override
  String get callInProgress => 'Appel en cours';

  @override
  String get returnToCall => 'Retour';

  @override
  String get callInfo => 'Infos de l\'appel';

  @override
  String get callType => 'Type';

  @override
  String get voiceCall => 'Appel vocal';

  @override
  String get callDirection => 'Direction';

  @override
  String get callStatus => 'Statut';

  @override
  String get callBack => 'Rappeler';

  @override
  String get deleteCall => 'Supprimer l\'appel';

  @override
  String get deleteCallConfirmation =>
      'Êtes-vous sûr de vouloir supprimer cet appel de votre historique ?';

  @override
  String get callDeleted => 'Appel supprimé';

  @override
  String get paymentAccounts => 'Moyens de paiement';

  @override
  String get paymentAccountsDesc =>
      'Gérer vos comptes pour recevoir de l\'argent';

  @override
  String get addPaymentAccount => 'Ajouter un compte';

  @override
  String get paymentAccountType => 'Type de compte';

  @override
  String get paymentAccountLabel => 'Libellé du compte';

  @override
  String get paymentAccountLabelRequired => 'Le libellé est obligatoire';

  @override
  String get stripeConnect => 'Stripe Connect';

  @override
  String get stripeConnectDesc =>
      'Connectez votre compte Stripe pour recevoir des paiements internationaux directement sur votre compte bancaire.';

  @override
  String get stripeConnectSetup => 'Configurer Stripe Connect';

  @override
  String get mobileMoney => 'Mobile Money';

  @override
  String get bankAccount => 'Compte bancaire';

  @override
  String get mobileProvider => 'Opérateur';

  @override
  String get mobileNumber => 'Numéro de téléphone';

  @override
  String get mobileNumberRequired => 'Le numéro est obligatoire';

  @override
  String get mobileNumberInvalid => 'Numéro invalide (min. 8 chiffres)';

  @override
  String get bankName => 'Nom de la banque';

  @override
  String get bankNameRequired => 'Le nom de la banque est obligatoire';

  @override
  String get accountHolder => 'Titulaire du compte';

  @override
  String get accountHolderRequired => 'Le titulaire est obligatoire';

  @override
  String get ibanLabel => 'IBAN / RIB';

  @override
  String get ibanRequired => 'L\'IBAN est obligatoire';

  @override
  String get bicLabel => 'BIC / SWIFT';

  @override
  String get optional => 'optionnel';

  @override
  String get defaultAccount => 'Compte par défaut';

  @override
  String get setAsDefault => 'Définir par défaut';

  @override
  String get setAsDefaultDesc =>
      'Utiliser ce compte comme moyen de paiement principal';

  @override
  String get deletePaymentAccount => 'Supprimer le compte';

  @override
  String get confirmDeletePaymentAccount =>
      'Êtes-vous sûr de vouloir supprimer ce compte de paiement ?';

  @override
  String get accountAdded => 'Compte ajouté avec succès';

  @override
  String get paymentAccountDeleted => 'Compte supprimé';

  @override
  String get setAsDefaultSuccess => 'Compte défini par défaut';

  @override
  String get noPaymentAccounts => 'Aucun moyen de paiement configuré';

  @override
  String get paymentAccountRequired =>
      'Ajoutez un moyen de paiement pour recevoir vos gains';

  @override
  String get saveAccount => 'Enregistrer le compte';

  @override
  String get saving => 'Enregistrement...';

  @override
  String get confirmPayment => 'Confirmer le paiement';

  @override
  String get paymentSummary => 'Récapitulatif';

  @override
  String get grossAmount => 'Montant brut';

  @override
  String get commission => 'Commission';

  @override
  String get netAmount => 'Montant net';

  @override
  String get destinationAccount => 'Compte destinataire';

  @override
  String get confirmAndPay => 'Confirmer et payer';

  @override
  String get confirmPaymentBiometrics => 'Confirmez pour valider le paiement';

  @override
  String get enterPin => 'Saisissez votre code PIN';

  @override
  String get useBiometrics => 'Utiliser la biométrie';

  @override
  String get enableBiometricsDesc =>
      'Utilisez votre empreinte digitale ou Face ID pour confirmer vos paiements plus rapidement.';

  @override
  String get notNow => 'Pas maintenant';

  @override
  String get enable => 'Activer';

  @override
  String get setupPin => 'Configurer votre code PIN';

  @override
  String get setupPinDesc =>
      'Ce code à 4 chiffres protège vos transactions financières.';

  @override
  String get confirmPin => 'Confirmer le code PIN';

  @override
  String get confirmPinDesc =>
      'Saisissez à nouveau votre code PIN pour confirmer.';

  @override
  String get pinMismatch => 'Les codes ne correspondent pas';

  @override
  String get incorrectPin => 'Code PIN incorrect';

  @override
  String get tooManyAttempts =>
      'Trop de tentatives. Veuillez réessayer plus tard.';

  @override
  String get attemptsRemaining => 'tentatives restantes';

  @override
  String get paymentHistory => 'Historique des paiements';

  @override
  String get paymentHistoryDesc => 'Consultez toutes vos transactions';

  @override
  String get allTransactions => 'Toutes';

  @override
  String get tickets => 'Tickets';

  @override
  String get tips => 'Tips';

  @override
  String get sales => 'Ventes';

  @override
  String get payouts => 'Versements';

  @override
  String get statusPending => 'En attente';

  @override
  String get statusProcessing => 'En cours';

  @override
  String get statusCompleted => 'Terminé';

  @override
  String get statusFailed => 'Échoué';

  @override
  String get statusCancelled => 'Annulé';

  @override
  String get statusRefunded => 'Remboursé';

  @override
  String get transactionDetail => 'Détail de la transaction';

  @override
  String get reportIssue => 'Signaler un problème';

  @override
  String get noTransactions => 'Aucune transaction';

  @override
  String get counterparty => 'Contrepartie';

  @override
  String get dateLabel => 'Date';

  @override
  String get completedOn => 'Complété le';

  @override
  String get referenceLabel => 'Référence';

  @override
  String get copied => 'Copié !';

  @override
  String get descriptionLabel => 'Description';

  @override
  String get paymentTypeTicket => 'Ticket';

  @override
  String get paymentTypeTip => 'Tip';

  @override
  String get paymentTypeSale => 'Vente';

  @override
  String get paymentTypePayout => 'Versement';

  @override
  String get paymentTypeTransfer => 'Transfert';

  @override
  String reportTransactionSubject(String id, String type) {
    return 'Problème transaction #$id - $type';
  }

  @override
  String get reportTransactionIntro =>
      'Bonjour,\n\nJe signale un problème avec la transaction suivante :\n';

  @override
  String get describeYourProblem => 'Décrivez votre problème :\n';

  @override
  String get supportTickets => 'Tickets de support';

  @override
  String get newSupportTicket => 'Nouveau ticket';

  @override
  String get supportTicketCreated => 'Ticket créé avec succès';

  @override
  String get supportTicketUpdated => 'Ticket mis à jour';

  @override
  String get supportReply => 'Réponse du support';

  @override
  String get ticketOpen => 'Ouvert';

  @override
  String get ticketInProgress => 'En cours';

  @override
  String get ticketResolved => 'Résolu';

  @override
  String get ticketClosed => 'Fermé';

  @override
  String get yourMessage => 'Votre message...';

  @override
  String get sendReply => 'Envoyer';

  @override
  String get supportTeam => 'Équipe Support';

  @override
  String get noSupportTickets => 'Aucun ticket de support';

  @override
  String get noSupportTicketsDesc =>
      'Vos demandes d\'assistance apparaîtront ici';

  @override
  String get ticketSubject => 'Sujet';

  @override
  String get ticketDescription => 'Description du problème';

  @override
  String get ticketDescriptionRequired => 'Veuillez décrire le problème';

  @override
  String get ticketCategory => 'Catégorie';

  @override
  String get ticketCategoryTransaction => 'Transaction';

  @override
  String get ticketCategoryAccount => 'Compte';

  @override
  String get ticketCategoryTechnical => 'Technique';

  @override
  String get ticketCategoryOther => 'Autre';

  @override
  String get supportNotificationTitle => 'Réponse du support';

  @override
  String supportNotificationBody(String subject) {
    return 'Votre ticket \"$subject\" a reçu une réponse';
  }

  @override
  String get forward => 'Transférer';

  @override
  String get forwarded => 'Transféré';

  @override
  String get forwardTo => 'Transférer à...';

  @override
  String get messageForwarded => 'Message transféré';

  @override
  String messagesForwarded(int count) {
    return '$count messages transférés';
  }

  @override
  String deleteSelectedMessages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return 'Supprimer $count message$_temp0 ?';
  }

  @override
  String get messagesDeletedForYou =>
      'Les messages seront supprimés pour vous uniquement.';

  @override
  String messagesDeletedSuccess(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$count message$_temp0 supprimé$_temp1';
  }

  @override
  String get searchConversation => 'Rechercher une conversation...';

  @override
  String get noConversationFound => 'Aucune conversation trouvée';

  @override
  String get messageCopied => 'Message copié';

  @override
  String get reply => 'Répondre';

  @override
  String get react => 'Réagir';

  @override
  String get copy => 'Copier';

  @override
  String get report => 'Signaler';

  @override
  String get transferSendMoney => 'Envoyer de l\'argent';

  @override
  String get transferReset => 'Réinitialiser';

  @override
  String get transferContinue => 'Continuer';

  @override
  String get transferBack => 'Retour';

  @override
  String get transferRecipient => 'Bénéficiaire';

  @override
  String get transferPaymentMethod => 'Mode de paiement';

  @override
  String get transferAmount => 'Montant';

  @override
  String get transferConfirmation => 'Confirmation';

  @override
  String get transferConfirmButton => 'Confirmer';

  @override
  String get transferAddRecipient => 'Ajouter un bénéficiaire';

  @override
  String get transferSelectExistingRecipient =>
      'Ou sélectionnez un bénéficiaire existant';

  @override
  String get transferNoRecipients => 'Aucun bénéficiaire enregistré';

  @override
  String get transferFavorites => 'Favoris';

  @override
  String get transferRecentlyUsed => 'Récemment utilisés';

  @override
  String get transferOtherRecipients => 'Autres bénéficiaires';

  @override
  String get transferSelectPaymentMethod => 'Sélectionnez un mode de paiement';

  @override
  String get transferDebitAccountInfo => 'Informations du compte à débiter';

  @override
  String get transferCountryCode => 'Indicatif';

  @override
  String get transferMynitaNumber => 'Numéro Mynita *';

  @override
  String get transferWaveNumber => 'Numéro Wave *';

  @override
  String get transferPhoneHint => 'XX XX XX XX';

  @override
  String get transferPhoneRequired => 'Le numéro est requis';

  @override
  String get transferPhoneInvalid => 'Numéro invalide';

  @override
  String get transferBankName => 'Nom de la banque *';

  @override
  String get transferBankNameRequired => 'Le nom de la banque est requis';

  @override
  String get transferAccountNumberIban => 'Numéro de compte / IBAN *';

  @override
  String get transferAccountNumberIbanHint => 'XXXX XXXX XXXX XXXX';

  @override
  String get transferAccountNumberRequired => 'Le numéro de compte est requis';

  @override
  String get transferCurrency => 'Devise';

  @override
  String get transferAmountToSend => 'Montant à envoyer';

  @override
  String transferMinimumAmount(String currency) {
    return 'Minimum 5 $currency';
  }

  @override
  String get transferEnterAmount => 'Entrez un montant';

  @override
  String get transferInvalidAmount => 'Montant invalide';

  @override
  String get transferMessageOptional => 'Message (optionnel)';

  @override
  String get transferMessageHint => 'Ex: Pour les courses';

  @override
  String get transferSummary => 'Récapitulatif';

  @override
  String get transferAmountSent => 'Montant :';

  @override
  String transferFees(String percent) {
    return 'Frais :';
  }

  @override
  String get transferTotalDebited => 'Total débité';

  @override
  String transferExchangeRate(String from, String rate) {
    return 'Taux de change';
  }

  @override
  String get transferRecipientWillReceive => 'Le bénéficiaire recevra';

  @override
  String get transferAmountToReceive => 'Montant à recevoir';

  @override
  String transferTotalDebitedAmount(String amount, String currency) {
    return 'Total débité: $amount $currency';
  }

  @override
  String transferPayVia(String method) {
    return 'Payer via $method';
  }

  @override
  String get transferTermsAndConditions =>
      'En confirmant, vous acceptez les conditions générales de transfert. Les fonds seront disponibles sous 24h.';

  @override
  String get transferSelectRecipientError => 'Sélectionnez un bénéficiaire';

  @override
  String get transferSelectPaymentMethodError =>
      'Sélectionnez un mode de paiement';

  @override
  String get transferFeeCalculationError => 'Erreur lors du calcul des frais';

  @override
  String get transferConfirmTitle => 'Confirmer le transfert';

  @override
  String get transferAboutToSend => 'Vous êtes sur le point d\'envoyer:';

  @override
  String get transferAmountLabel => 'Montant à envoyer';

  @override
  String get transferFeesLabel => 'Frais';

  @override
  String get transferTotalLabel => 'Total:';

  @override
  String transferFromLabel(String method, String account) {
    return 'De: $method ($account)';
  }

  @override
  String transferToLabel(String name) {
    return 'À: $name';
  }

  @override
  String get transferIrreversibleWarning =>
      'Cette action est irréversible. Voulez-vous continuer ?';

  @override
  String get transferInitiatedSuccess => 'Transfert initié avec succès';

  @override
  String get transferSecureTitle => 'Transfert sécurisé';

  @override
  String get transferSecureMessage =>
      'Les transferts d\'argent nécessitent l\'installation de l\'application depuis Google Play Store pour garantir la sécurité de vos transactions.';

  @override
  String get transferUserNotConnected => 'Utilisateur non connecté';

  @override
  String transferError(String error) {
    return 'Erreur: $error';
  }

  @override
  String get recipientEditTitle => 'Modifier le bénéficiaire';

  @override
  String get recipientNewTitle => 'Nouveau bénéficiaire';

  @override
  String get recipientPersonalInfo => 'Informations personnelles';

  @override
  String get recipientFullName => 'Nom complet *';

  @override
  String get recipientFullNameHint => 'Ex: Amadou Boubacar';

  @override
  String get recipientNameRequired => 'Le nom est requis';

  @override
  String get recipientNameTooShort =>
      'Le nom doit contenir au moins 3 caractères';

  @override
  String get recipientPhoneNumber => 'Numéro de téléphone *';

  @override
  String get recipientEmailOptional => 'Email (optionnel)';

  @override
  String get recipientEmailHint => 'exemple@email.com';

  @override
  String get recipientEmailInvalid => 'Email invalide';

  @override
  String get recipientReceptionMode => 'Mode de réception';

  @override
  String get recipientPaymentDetails => 'Détails de paiement';

  @override
  String recipientMobilePaymentInfo(String service) {
    return 'Le transfert sera effectué via $service sur le numéro de téléphone du bénéficiaire.';
  }

  @override
  String get recipientCashPickupInfo =>
      'Le bénéficiaire pourra retirer l\'argent dans un point de service NITA avec une pièce d\'identité.';

  @override
  String get recipientSelectBank => 'Sélectionnez une banque';

  @override
  String get recipientAccountNumber => 'Numéro de compte *';

  @override
  String get recipientAccountNumberHint => 'XXXX XXXX XXXX XXXX';

  @override
  String get recipientAccountNumberRequired => 'Le numéro de compte est requis';

  @override
  String get recipientAccountNumberInvalid => 'Numéro de compte invalide';

  @override
  String get recipientLocation => 'Localisation';

  @override
  String get recipientCountry => 'Pays';

  @override
  String get recipientCity => 'Ville';

  @override
  String get recipientAddressOptional => 'Adresse (optionnel)';

  @override
  String get recipientAddressHint => 'Quartier, rue...';

  @override
  String get recipientAddToFavorites => 'Ajouter aux favoris';

  @override
  String get recipientFavoritesQuickAccess =>
      'Accès rapide lors des prochains transferts';

  @override
  String get recipientSaveChanges => 'Enregistrer les modifications';

  @override
  String get recipientAddButton => 'Ajouter le bénéficiaire';

  @override
  String get recipientModifiedSuccess => 'Bénéficiaire modifié avec succès';

  @override
  String get recipientAddedSuccess => 'Bénéficiaire ajouté avec succès';

  @override
  String get recipientDeleteTitle => 'Supprimer le bénéficiaire ?';

  @override
  String recipientDeleteConfirm(String name) {
    return 'Voulez-vous vraiment supprimer $name de vos bénéficiaires ?';
  }

  @override
  String get recipientDeleted => 'Bénéficiaire supprimé';

  @override
  String get recipientTypeMynita => 'Mynita';

  @override
  String get recipientTypeWave => 'Wave';

  @override
  String get recipientTypeBankAccount => 'Compte bancaire';

  @override
  String get recipientTypeCashPickup => 'Retrait espèces';

  @override
  String get recipientTypeMynitaDesc => 'Transfert via Mynita';

  @override
  String get recipientTypeWaveDesc => 'Transfert via Wave';

  @override
  String get recipientTypeBankAccountDesc => 'Virement bancaire direct';

  @override
  String get recipientTypeCashPickupDesc => 'Retrait dans un point de service';

  @override
  String get senderPaymentMynita => 'Mynita';

  @override
  String get senderPaymentWave => 'Wave';

  @override
  String get senderPaymentBankAccount => 'Compte bancaire';

  @override
  String get senderPaymentMynitaDesc => 'Payer via Mynita';

  @override
  String get senderPaymentWaveDesc => 'Payer via Wave';

  @override
  String get senderPaymentBankAccountDesc => 'Payer par virement bancaire';

  @override
  String get starMessage => 'Ajouter aux favoris';

  @override
  String get unstarMessage => 'Retirer des favoris';

  @override
  String get starredMessages => 'Messages favoris';

  @override
  String get noStarredMessages => 'Aucun message favori';

  @override
  String get searchMessages => 'Rechercher dans la conversation...';

  @override
  String get noSearchResults => 'Aucun résultat';

  @override
  String get selectAll => 'Tout sélectionner';

  @override
  String get deselectAll => 'Tout désélectionner';

  @override
  String get callHold => 'Attente';

  @override
  String get callResume => 'Reprendre';

  @override
  String get callOnHold => 'En attente';

  @override
  String get callReconnecting => 'Reconnexion...';

  @override
  String get callError => 'Erreur lors de l\'appel';

  @override
  String get callQualityGood => 'Bonne qualité';

  @override
  String get callQualityFair => 'Qualité moyenne';

  @override
  String get callQualityPoor => 'Mauvaise qualité';

  @override
  String get groupCallTitle => 'Group Call';

  @override
  String get groupCallCreate => 'Démarrer appel de groupe';

  @override
  String get groupCallJoin => 'Join';

  @override
  String get groupCallLeave => 'Quitter l\'appel';

  @override
  String get groupCallEnd => 'Terminer l\'appel';

  @override
  String get groupCallInvite => 'Inviter des participants';

  @override
  String groupCallParticipants(int count) {
    return '$count participants';
  }

  @override
  String get groupCallWaiting => 'En attente des participants...';

  @override
  String get groupCallConnecting => 'Connexion en cours...';

  @override
  String get groupCallConnected => 'Connecté';

  @override
  String get groupCallDisconnected => 'Déconnecté';

  @override
  String get groupCallReconnecting => 'Reconnexion...';

  @override
  String get groupCallMeshMode => 'Connexion directe';

  @override
  String get groupCallSfuMode => 'Via serveur';

  @override
  String get groupCallE2eeEnabled => 'Chiffré de bout en bout';

  @override
  String get groupCallE2eeDisabled => 'Non chiffré';

  @override
  String get groupCallE2eeVerify => 'Vérifier le chiffrement';

  @override
  String groupCallE2eeVerificationCode(String code) {
    return 'Code de vérification : $code';
  }

  @override
  String get groupCallE2eeVerifyHint =>
      'Comparez ce code avec les autres participants pour vérifier le chiffrement';

  @override
  String get groupCallVideoQuality => 'Qualité vidéo';

  @override
  String get groupCallVideoQualityLow => 'Basse (180p)';

  @override
  String get groupCallVideoQualityMedium => 'Moyenne (360p)';

  @override
  String get groupCallVideoQualityHigh => 'Haute (720p)';

  @override
  String get groupCallVideoQualityAuto => 'Automatique';

  @override
  String get groupCallScreenShare => 'Partager l\'écran';

  @override
  String get groupCallStopScreenShare => 'Arrêter le partage';

  @override
  String get groupCallRaiseHand => 'Lever la main';

  @override
  String get groupCallLowerHand => 'Baisser la main';

  @override
  String groupCallHandRaised(String name) {
    return '$name a levé la main';
  }

  @override
  String get groupCallMuted => 'Micro coupé';

  @override
  String get groupCallUnmuted => 'Micro activé';

  @override
  String get groupCallCameraOff => 'Caméra désactivée';

  @override
  String get groupCallCameraOn => 'Caméra activée';

  @override
  String get groupCallSpeaking => 'Parle';

  @override
  String get groupCallNetworkPoor => 'Mauvaise connexion';

  @override
  String get groupCallNetworkGood => 'Bonne connexion';

  @override
  String groupCallParticipantJoined(String name) {
    return '$name a rejoint';
  }

  @override
  String groupCallParticipantLeft(String name) {
    return '$name a quitté';
  }

  @override
  String get groupCallSelectParticipants => 'Sélectionner les participants';

  @override
  String get groupCallMinParticipants => 'Sélectionnez au moins un participant';

  @override
  String groupCallMaxParticipants(int max) {
    return 'Maximum $max participants';
  }

  @override
  String get groupCallStartVideo => 'Appel vidéo';

  @override
  String get groupCallStartAudio => 'Appel audio';

  @override
  String get groupCallSimulcast => 'Qualité adaptative activée';

  @override
  String get groupCallSwitchingToSfu =>
      'Passage en mode serveur pour une meilleure qualité...';

  @override
  String get comingSoon => 'BIENTÔT DISPONIBLE';

  @override
  String get goBack => 'Retour';

  @override
  String get comingSoonCallsTitle => 'Appels Audio & Vidéo';

  @override
  String get comingSoonCallsDescription =>
      'Passez des appels audio et vidéo de haute qualité avec vos amis et votre famille. Cette fonctionnalité est en cours de développement et sera disponible très prochainement.';

  @override
  String get comingSoonAudioRoomsTitle => 'Salons Audio';

  @override
  String get comingSoonAudioRoomsDescription =>
      'Rejoignez des discussions audio en direct avec la communauté. Participez à des débats, des sessions de questions-réponses et bien plus. Cette fonctionnalité arrive bientôt.';

  @override
  String get comingSoonInDevelopment => 'En cours de développement';

  @override
  String get comingSoonPodcastsTitle => 'Podcasts';

  @override
  String get comingSoonPodcastsDescription =>
      'Écoutez et créez des podcasts sur la diaspora nigérienne. Partagez vos histoires, interviews et discussions. Cette fonctionnalité arrive bientôt.';

  @override
  String get temporarilyClosed => 'Temporairement fermé';

  @override
  String get services => 'Services';

  @override
  String get viewFullDetails => 'Voir les détails complets';

  @override
  String get showBusinessesOnMap => 'Afficher les commerces sur la carte';

  @override
  String get hideBusinessesOnMap => 'Masquer les commerces sur la carte';

  @override
  String get locationRequiredToSeeMembers =>
      'Localisation requise pour voir les membres';

  @override
  String get activate => 'Activer';

  @override
  String get reminderTitle => 'Rappels';

  @override
  String get reminderInfoText =>
      'Vous recevrez une notification push avant le début de l\'événement selon les rappels configurés.';

  @override
  String get reminderOneHour => '1 heure avant';

  @override
  String get reminderTwentyFourHours => '24 heures avant';

  @override
  String get reminderOneWeek => '1 semaine avant';

  @override
  String get reminderSet => 'Rappel programmé';

  @override
  String get reminderCancelled => 'Rappel supprimé';

  @override
  String get reminderPast => 'Passé';

  @override
  String get audioRoomReminderTitle => 'Salle audio à venir';

  @override
  String get podcastNewEpisodeTitle => 'Nouvel épisode';

  @override
  String get transferReminderTitle => 'Transfert à venir';

  @override
  String get serviceMoneyTransfer => 'transferts d\'argent';

  @override
  String get serviceMarketplace => 'Boutique';

  @override
  String get serviceBusinessDirectory => 'annuaire des entreprises';

  @override
  String get serviceEmbassies => 'Ambassades';

  @override
  String quickAccessToService(String service) {
    return 'Accès rapide au service : $service.';
  }

  @override
  String quickAccessToServices(String services, String lastService) {
    return 'Accès rapide aux services : $services et $lastService.';
  }

  @override
  String get searchableMembers => 'membres';

  @override
  String get searchableGroups => 'groupes';

  @override
  String get searchableEvents => 'événements';

  @override
  String findEasily(String item) {
    return 'Trouvez des $item facilement.';
  }

  @override
  String findMultipleEasily(String items, String lastItem) {
    return 'Trouvez des $items et des $lastItem facilement.';
  }

  @override
  String discoverCommunityStats(String stats) {
    return 'Découvrez la communauté : nombre de $stats. Appuyez pour explorer.';
  }

  @override
  String get searchProduct => 'Rechercher un produit...';

  @override
  String get searchEmbassy => 'Rechercher par nom, pays ou ville...';

  @override
  String get searchEmployee => 'Rechercher par nom, titre, rôle...';

  @override
  String get searchRecipient => 'Rechercher un bénéficiaire...';

  @override
  String get searchFriend => 'Rechercher un ami...';

  @override
  String get searchByRecipient => 'Rechercher par bénéficiaire...';

  @override
  String get searchBusiness => 'Rechercher une entreprise...';

  @override
  String get download => 'Télécharger';

  @override
  String get share => 'Partager';

  @override
  String get galleryPermissionDenied =>
      'Permission refusée pour accéder à la galerie';

  @override
  String get imageSavedToGallery => 'Image enregistrée dans la galerie';

  @override
  String get errorDownloading => 'Erreur lors du téléchargement';

  @override
  String get errorSharing => 'Erreur lors du partage';

  @override
  String get imageNotAvailable => 'Image non disponible';

  @override
  String imageCounter(int current, int total) {
    return '$current sur $total';
  }

  @override
  String todayAt(String time) {
    return 'Aujourd\'hui à $time';
  }

  @override
  String yesterdayAt(String time) {
    return 'Hier à $time';
  }

  @override
  String get deletePhoto => 'Supprimer la photo';

  @override
  String get confirmDeletePhoto => 'Voulez-vous vraiment supprimer la photo ?';

  @override
  String get confirmDeleteGroup =>
      'Voulez-vous vraiment supprimer ce groupe ? Cette action est irréversible.';

  @override
  String get deleteGroup => 'Supprimer le groupe';

  @override
  String get groupDeleted => 'Groupe supprimé';

  @override
  String get deletionError => 'Erreur lors de la suppression';

  @override
  String get editGroup => 'Modifier le groupe';

  @override
  String get promoteAdmin => 'Promouvoir Admin';

  @override
  String get demoteAdmin => 'Rétrograder administrateur';

  @override
  String get joinRequests => 'Demandes d\'adhésion';

  @override
  String get requestApproved => 'Demande approuvée';

  @override
  String get requestRejected => 'Demande rejetée';

  @override
  String get accessDenied => 'Accès Refusé';

  @override
  String errorWithDetails(String error) {
    return 'Erreur : $error';
  }

  @override
  String get deleteConversationWarning =>
      'Attention : L\'autre personne pourra toujours vous envoyer des messages. La conversation reapparaitra si vous recevez un nouveau message.';

  @override
  String get deleteAndBlock => 'Supprimer et bloquer';

  @override
  String get messageWillBeDeleted => 'Le message sera supprimé';

  @override
  String get undo => 'Annuler';

  @override
  String confirmDeleteMultipleMessages(int count) {
    return 'Supprimer $count messages ?';
  }

  @override
  String get deleteMessages => 'Supprimer les messages';

  @override
  String get hostCountry => 'Pays d\'accueil (optionnel)';

  @override
  String get creatorMustTransferOwnership =>
      'Le créateur doit transférer la propriété avant de quitter';

  @override
  String get transfers => 'Transferts';

  @override
  String get reset => 'Réinitialiser';

  @override
  String get back => 'Retour';

  @override
  String get skip => 'Passer';

  @override
  String get coachMarkProfile => 'Votre profil';

  @override
  String get coachMarkProfileDesc =>
      'Appuyez ici pour accéder à votre profil et le compléter avec vos informations.';

  @override
  String get coachMarkNotifications => 'Notifications';

  @override
  String get coachMarkNotificationsDesc =>
      'Restez informé des nouveaux messages et activités de la communauté.';

  @override
  String get coachMarkNearbyMembers => 'Membres proches';

  @override
  String get coachMarkNearbyMembersDesc =>
      'Découvrez les Nigériens dans votre région. Faites glisser pour voir plus de profils.';

  @override
  String get coachMarkUpcomingEvents => 'Événements à venir';

  @override
  String get coachMarkUpcomingEventsDesc =>
      'Participez aux rencontres et activités de la diaspora. Appuyez pour voir les détails.';

  @override
  String get locationRequiredForNearby =>
      'Pour voir les membres à proximité, vous devez activer votre localisation. C\'est donnant-donnant !';

  @override
  String get enableLocation => 'ACTIVER';

  @override
  String get serviceTransfer => 'Transfert';

  @override
  String get serviceDirectory => 'Annuaire';

  @override
  String get serviceAudioRooms => 'Salons Audio';

  @override
  String get servicePodcasts => 'Podcasts';

  @override
  String get allServices => 'Tous les services';

  @override
  String get friend => 'Ami';

  @override
  String get embassies => 'Ambassades';

  @override
  String get mapLegendSemantics =>
      'Légende : Vert pour les amis, Orange pour les membres, Bleu pour les ambassades';

  @override
  String get saveAsPodcast => 'Sauver comme Podcast';

  @override
  String get publishRecording => 'Publier cet enregistrement';

  @override
  String get closeRoom => 'Fermer le salon';

  @override
  String get closeRoomConfirm => 'Êtes-vous sûr de vouloir fermer ce salon ?';

  @override
  String get moderationMode => 'Mode modération (invisible)';

  @override
  String get userNotConnected => 'Utilisateur non connecté';

  @override
  String get paidRoomsNotAllowed => 'Les salons payants ne sont pas autorisés';

  @override
  String get paidRoomsDisabled => 'Les salons payants sont désactivés';

  @override
  String get cardSecurityInfo =>
      'Vos données de carte sont sécurisées par Stripe. Nous ne stockons jamais votre numéro de carte complet.';

  @override
  String get cardTransferInfo =>
      'Le transfert sera effectué directement sur la carte via Visa Direct ou Mastercard Send.';

  @override
  String get registeredCard => 'Carte enregistrée';

  @override
  String get changeCard => 'Changer';

  @override
  String get cardInfoRequired =>
      'Veuillez entrer les informations complètes de la carte';

  @override
  String cardVerificationError(String error) {
    return 'Erreur de vérification de la carte : $error';
  }

  @override
  String get closeRoomWarning =>
      'Cette action fermera le salon pour tous les participants.';

  @override
  String get closeReasonHint => 'Raison de la fermeture...';

  @override
  String get defaultCloseReason => 'Violation des règles de la communauté';

  @override
  String get collectionsNotAllowed => 'Les collectes ne sont pas autorisées';

  @override
  String get heritageContentNotAllowed =>
      'Le contenu patrimonial n\'est pas autorisé';

  @override
  String minTicketPrice(int price) {
    return 'Le prix minimum du ticket est $price XOF';
  }

  @override
  String maxTicketPrice(int price) {
    return 'Le prix maximum du ticket est $price XOF';
  }

  @override
  String get defaultUserName => 'Utilisateur';

  @override
  String errorCreating(String error) {
    return 'Erreur lors de la création: $error';
  }

  @override
  String get roomNotFound => 'Salon introuvable';

  @override
  String get blockedFromRoom => 'Vous êtes bloqué de ce salon';

  @override
  String get roomFull => 'Salon complet';

  @override
  String errorConnecting(String error) {
    return 'Erreur lors de la connexion: $error';
  }

  @override
  String get unauthorizedAccess => 'Accès non autorisé';

  @override
  String tomorrowAt(String time) {
    return 'Demain à $time';
  }

  @override
  String forBeneficiary(String beneficiary) {
    return 'Pour: $beneficiary';
  }

  @override
  String goalAmount(String amount) {
    return 'Objectif: $amount';
  }

  @override
  String get contribute => 'Contribuer';

  @override
  String get suggestedAmount => 'Montant suggéré';

  @override
  String get orEnterAmount => 'Ou saisissez un montant';

  @override
  String get amountInXof => 'Montant en XOF';

  @override
  String get messageOptional => 'Message (optionnel)';

  @override
  String get confirmContribution => 'Confirmer la contribution';

  @override
  String get collectionLabel => 'Collecte';

  @override
  String get emergencyLabel => 'Urgence';

  @override
  String get projectLabel => 'Projet';

  @override
  String get duesLabel => 'Cotisation';

  @override
  String get moderatorRole => 'Modérateur';

  @override
  String get warnHost => 'Avertir l\'hôte';

  @override
  String get warningSentToHost => 'Avertissement envoyé à l\'hôte';

  @override
  String get muteMicrophone => 'Couper le micro';

  @override
  String userMuted(String userName) {
    return '$userName a été mis en sourdine';
  }

  @override
  String get kickFromRoom => 'Expulser du salon';

  @override
  String userKicked(String userName) {
    return '$userName a été expulsé';
  }

  @override
  String get blockFromRoom => 'Bloquer de ce salon';

  @override
  String userBlockedFromRoom(String userName) {
    return '$userName a été bloqué';
  }

  @override
  String get videoEnabled => 'Vidéo activée';

  @override
  String get videoEnabledDesc =>
      'Permettre aux speakers de partager leur vidéo';

  @override
  String get remove => 'Retirer';

  @override
  String errorLabel(String error) {
    return 'Erreur: $error';
  }

  @override
  String get noEventFound => 'Aucun événement trouvé';

  @override
  String get noGroupFound => 'Aucun groupe trouvé';

  @override
  String get noEmbassyFound => 'Aucune ambassade trouvée';

  @override
  String get warningMessageHint => 'Message d\'avertissement...';

  @override
  String get searchEventHint => 'Rechercher un événement...';

  @override
  String get searchGroupHint => 'Rechercher un groupe...';

  @override
  String get searchEmbassyHint => 'Rechercher une ambassade...';

  @override
  String get pleaseAddCoverImage => 'Veuillez ajouter une image de couverture';

  @override
  String get podcastCreatedSuccess => 'Podcast créé avec succès !';

  @override
  String get createPodcast => 'Créer un podcast';

  @override
  String get languageFrench => 'Français';

  @override
  String get languageEnglish => 'Anglais';

  @override
  String get languageHausa => 'Haoussa';

  @override
  String get languageZarma => 'Zarma/Djerma';

  @override
  String get frequencyNotDefined => 'Non définie';

  @override
  String get frequencyDaily => 'Quotidien';

  @override
  String get frequencyWeekly => 'Hebdomadaire';

  @override
  String get frequencyBiweekly => 'Bimensuel';

  @override
  String get frequencyMonthly => 'Mensuel';

  @override
  String get explicitContent => 'Contenu explicite';

  @override
  String get explicitContentDesc =>
      'Ce podcast contient du contenu pour adultes';

  @override
  String get createThePodcast => 'Créer le podcast';

  @override
  String get episodeNotFound => 'Épisode non trouvé';

  @override
  String get downloadInProgress => 'Téléchargement en cours...';

  @override
  String get sleepTimerDisabled => 'Désactivé';

  @override
  String get sleepTimer15min => '15 minutes';

  @override
  String get sleepTimer30min => '30 minutes';

  @override
  String get sleepTimer45min => '45 minutes';

  @override
  String get sleepTimer1hour => '1 heure';

  @override
  String get sleepTimerEndOfEpisode => 'Fin de l\'épisode';

  @override
  String get sleepTimerEndActivated => 'Arrêt à la fin de l\'épisode activé';

  @override
  String get sleepTimerFinished => 'Minuterie de sommeil terminée';

  @override
  String sleepTimerMinutes(int minutes) {
    return 'Minuterie: $minutes minutes';
  }

  @override
  String get myPodcasts => 'Mes Podcasts';

  @override
  String get newPodcast => 'Nouveau podcast';

  @override
  String get createMyFirstPodcast => 'Créer mon premier podcast';

  @override
  String viewAllEpisodes(int count) {
    return 'Voir les $count épisodes';
  }

  @override
  String get newEpisode => 'Nouvel épisode';

  @override
  String get noPodcastsYet => 'Vous n\'avez pas encore de podcast';

  @override
  String get noPodcastsDescription =>
      'Créez votre premier podcast et partagez votre voix avec la communauté diaspora !';

  @override
  String get noEpisodesPublished => 'Aucun épisode publié';

  @override
  String episodeListenInfo(String duration, int count) {
    return '$duration • $count écoutes';
  }

  @override
  String get viewPodcast => 'Voir le podcast';

  @override
  String get statistics => 'Statistiques';

  @override
  String get pausePodcast => 'Mettre en pause';

  @override
  String get publishPodcast => 'Publier';

  @override
  String get podcastPaused => 'Podcast mis en pause';

  @override
  String get podcastPublished => 'Podcast publié';

  @override
  String get deletePodcastTitle => 'Supprimer le podcast ?';

  @override
  String deletePodcastWarning(String title) {
    return 'Êtes-vous sûr de vouloir supprimer \"$title\" et tous ses épisodes ? Cette action est irréversible.';
  }

  @override
  String get podcastDeleted => 'Podcast supprimé';

  @override
  String get episodeDownloaded => 'Épisode téléchargé';

  @override
  String get deleteDownload => 'Supprimer le téléchargement';

  @override
  String get downloadDeleted => 'Téléchargement supprimé';

  @override
  String get selectPodcastOrCreate =>
      'Sélectionnez un podcast ou créez-en un nouveau';

  @override
  String get recordingSoonAvailable =>
      'L\'enregistrement du salon sera bientôt disponible';

  @override
  String get audioFileNotFound => 'Fichier audio introuvable';

  @override
  String get episodePublishedSuccess => 'Épisode publié avec succès !';

  @override
  String get publicationError => 'Erreur lors de la publication';

  @override
  String get publish => 'Publier';

  @override
  String get createAPodcast => 'Créer un podcast';

  @override
  String get podcasts => 'Podcasts';

  @override
  String get noPodcastAvailable => 'Aucun podcast disponible';

  @override
  String get noRecentEpisode => 'Aucun épisode récent';

  @override
  String get endOfEpisode => 'Fin de l\'épisode';

  @override
  String get addChapter => 'Ajouter un chapitre';

  @override
  String get add => 'Ajouter';

  @override
  String get pleaseSelectAudioFile => 'Veuillez sélectionner un fichier audio';

  @override
  String get premiumEpisode => 'Épisode premium';

  @override
  String get subscribersOnly => 'Réservé aux abonnés payants';

  @override
  String get podcastNotFound => 'Podcast non trouvé';

  @override
  String get trending => 'Tendances';

  @override
  String get newEpisodes => 'Nouveaux épisodes';

  @override
  String get resumeListening => 'Reprendre';

  @override
  String get categories => 'Catégories';

  @override
  String get subscriptions => 'Abonnements';

  @override
  String get noResultsFound => 'Aucun résultat trouvé';

  @override
  String get noSubscription => 'Aucun abonnement';

  @override
  String get subscribeToFindHere =>
      'Abonnez-vous à des podcasts pour les retrouver ici';

  @override
  String get chapterTitle => 'Titre du chapitre';

  @override
  String get marketplace => 'Marketplace';

  @override
  String get sell => 'Vendre';

  @override
  String get allCountries => 'Tous les pays';

  @override
  String get myProducts => 'Mes produits';

  @override
  String get listForSale => 'Mettre en vente';

  @override
  String get addAtLeastOneImage => 'Ajoutez au moins une image';

  @override
  String get priceTTC => 'Prix TTC';

  @override
  String get subtotal => 'Sous-total';

  @override
  String taxRate(String rate) {
    return 'Taxe ($rate%)';
  }

  @override
  String get myOrders => 'Mes commandes';

  @override
  String get discoverProducts => 'Découvrir les produits';

  @override
  String get paymentSuccess => 'Paiement effectué avec succès !';

  @override
  String get orderUpdateError => 'Erreur lors de la mise à jour de la commande';

  @override
  String paymentError(String error) {
    return 'Erreur de paiement : $error';
  }

  @override
  String get deliveryConfirmed => 'Livraison confirmée';

  @override
  String get orderMarkedAsShipped => 'Commande marquée comme expédiée';

  @override
  String get trackingNumber => 'Numéro de suivi';

  @override
  String get cart => 'Panier';

  @override
  String cartWithCount(int count) {
    return 'Panier ($count)';
  }

  @override
  String get emptyCart => 'Vider';

  @override
  String get total => 'Total';

  @override
  String get ordersCreatedSuccess => 'Commande(s) créée(s) avec succès !';

  @override
  String get loadingText => 'Chargement...';

  @override
  String get deleteProduct => 'Supprimer le produit';

  @override
  String get addedToCart => 'Ajouté au panier';

  @override
  String get addToCart => 'Ajouter au panier';

  @override
  String get conversationCreationError =>
      'Erreur lors de la création de la conversation';

  @override
  String get noProductsYet => 'Vous n\'avez pas encore de produits';

  @override
  String get emptyCartMessage => 'Votre panier est vide';

  @override
  String get businessDirectory => 'Annuaire Business';

  @override
  String get boostYourBusiness => 'Booster votre entreprise';

  @override
  String get boostActivatedSuccess => 'Boost activé avec succès !';

  @override
  String get boostPurchaseError => 'Erreur lors de l\'achat du boost';

  @override
  String get newBusiness => 'Nouvelle entreprise';

  @override
  String get photos => 'Photos';

  @override
  String get contact => 'Contact';

  @override
  String get servicesOffered => 'Services proposés';

  @override
  String get createTheBusiness => 'Créer l\'entreprise';

  @override
  String get businessCreatedSuccess => 'Entreprise créée avec succès !';

  @override
  String get creationError => 'Erreur lors de la création';

  @override
  String get boost => 'Booster';

  @override
  String get writeReview => 'Écrire un avis';

  @override
  String get writeFirstReview => 'Écrire le premier avis';

  @override
  String viewAllReviews(int count) {
    return 'Voir les $count autres avis';
  }

  @override
  String get mustBeLoggedInToReview =>
      'Vous devez être connecté pour laisser un avis';

  @override
  String get pleaseGiveRating => 'Veuillez donner une note';

  @override
  String get pleaseWriteReview => 'Veuillez écrire un avis';

  @override
  String get submissionError => 'Erreur lors de la soumission';

  @override
  String get deleteReview => 'Supprimer l\'avis';

  @override
  String get deleteReviewConfirm =>
      'Voulez-vous vraiment supprimer cet avis ? Cette action est irréversible.';

  @override
  String get reviewDeleted => 'Avis supprimé';

  @override
  String get reportReview => 'Signaler cet avis';

  @override
  String get pleaseIndicateReason => 'Veuillez indiquer une raison';

  @override
  String get useMyLocation => 'Utiliser ma localisation';

  @override
  String get enterCity => 'Entrer la ville';

  @override
  String get apply => 'Appliquer';

  @override
  String get newPost => 'Nouvelle publication';

  @override
  String get type => 'Type :';

  @override
  String get duration => 'Durée :';

  @override
  String get embassiesAndConsulates => 'Ambassades & Consulats';

  @override
  String get contactEmbassy => 'Contacter l\'ambassade';

  @override
  String get messageSentSuccess => 'Message envoyé avec succès !';

  @override
  String get newRequest => 'Nouvelle demande';

  @override
  String get requestSubmittedSuccess => 'Demande soumise avec succès !';

  @override
  String get callAction => 'Appeler';

  @override
  String get groupModified => 'Groupe modifié avec succès';

  @override
  String get modificationError => 'Erreur lors de la modification';

  @override
  String get nameRequired => 'Le nom est requis';

  @override
  String get nameMinLength => 'Le nom doit contenir au moins 3 caractères';

  @override
  String get privateGroup => 'Groupe privé';

  @override
  String get groupCreated => 'Groupe créé avec succès';

  @override
  String get groupCreationError => 'Erreur lors de la création du groupe';

  @override
  String get promotionError => 'Erreur lors de la promotion';

  @override
  String get demotionError => 'Erreur lors de la rétrogradation';

  @override
  String get requestSent => 'Demande envoyée avec succès';

  @override
  String get groupCountryHint => 'Le pays où se trouve la communauté du groupe';

  @override
  String get memberRemoved => 'Membre retiré avec succès';

  @override
  String get memberRemovalError => 'Erreur lors de la suppression du membre';

  @override
  String get filterGroups => 'Groupes';

  @override
  String get muted => 'En sourdine';

  @override
  String get pin => 'Épingler';

  @override
  String get unpin => 'Désépingler';

  @override
  String get pinLimitReached =>
      'Vous ne pouvez pas épingler plus de 5 conversations';

  @override
  String get conversationPinned => 'Conversation épinglée';

  @override
  String get editMessage => 'Modifier le message';

  @override
  String get edited => 'modifié';

  @override
  String get editTimeExpired => 'Le délai de modification est expiré (25 min)';

  @override
  String get messageEdited => 'Message modifié';

  @override
  String get conversationUnpinned => 'Conversation désépinglée';

  @override
  String get disappearingMessages => 'Messages éphémères';

  @override
  String get disappearingMessagesDescription =>
      'Les nouveaux messages disparaîtront après le délai sélectionné';

  @override
  String get off => 'Désactivé';

  @override
  String get hours24 => '24 heures';

  @override
  String get days7 => '7 jours';

  @override
  String get days30 => '30 jours';

  @override
  String expiresIn(Object time) {
    return 'Expire dans $time';
  }

  @override
  String disappearingMessagesEnabled(Object duration) {
    return 'Messages éphémères activés ($duration)';
  }

  @override
  String get disappearingMessagesDisabled => 'Messages éphémères désactivés';

  @override
  String get muteNotifications => 'Mettre en sourdine';

  @override
  String get muteNotificationsDescription =>
      'Vous ne recevrez pas de notifications pour cette conversation pendant la durée sélectionnée';

  @override
  String get muteFor1Hour => '1 heure';

  @override
  String get muteFor8Hours => '8 heures';

  @override
  String get muteFor24Hours => '24 heures';

  @override
  String get muteFor1Week => '1 semaine';

  @override
  String get muteForever => 'Toujours';

  @override
  String get conversationMuted => 'Conversation mise en sourdine';

  @override
  String mutedUntil(Object time) {
    return 'En sourdine jusqu\'à $time';
  }

  @override
  String get emptyStateNoDataTitle => 'Aucune donnée';

  @override
  String get emptyStateNoDataMessage =>
      'Il n\'y a rien à afficher pour le moment.';

  @override
  String get emptyStateNoResultsTitle => 'Aucun résultat';

  @override
  String get emptyStateNoResultsMessage =>
      'Aucun résultat ne correspond à votre recherche.';

  @override
  String get emptyStateNoResultsAction => 'Effacer la recherche';

  @override
  String get emptyStateNoMessagesTitle => 'Pas de messages';

  @override
  String get emptyStateNoMessagesMessage =>
      'Vous n\'avez pas encore de conversations. Commencez à discuter avec la communauté !';

  @override
  String get emptyStateNoMessagesAction => 'Nouvelle conversation';

  @override
  String get emptyStateNoNotificationsTitle => 'Pas de notifications';

  @override
  String get emptyStateNoNotificationsMessage =>
      'Vous êtes à jour ! Aucune nouvelle notification.';

  @override
  String get emptyStateNoEventsTitle => 'Aucun événement';

  @override
  String get emptyStateNoEventsMessage =>
      'Il n\'y a pas d\'événements à venir pour le moment.';

  @override
  String get emptyStateNoEventsAction => 'Créer un événement';

  @override
  String get emptyStateNoGroupsTitle => 'Aucun groupe';

  @override
  String get emptyStateNoGroupsMessage =>
      'Vous n\'êtes membre d\'aucun groupe. Rejoignez ou créez un groupe !';

  @override
  String get emptyStateNoGroupsAction => 'Explorer les groupes';

  @override
  String get emptyStateNoFriendsTitle => 'Pas encore d\'amis';

  @override
  String get emptyStateNoFriendsMessage =>
      'Connectez-vous avec d\'autres membres de la communauté.';

  @override
  String get emptyStateNoFriendsAction => 'Trouver des amis';

  @override
  String get emptyStateNoProductsTitle => 'Aucun produit';

  @override
  String get emptyStateNoProductsMessage =>
      'Le marketplace est vide pour le moment.';

  @override
  String get emptyStateNoProductsAction => 'Publier un produit';

  @override
  String get emptyStateNoOrdersTitle => 'Aucune commande';

  @override
  String get emptyStateNoOrdersMessage =>
      'Vous n\'avez pas encore passé de commande.';

  @override
  String get emptyStateNoOrdersAction => 'Voir le marketplace';

  @override
  String get emptyStateNoTransactionsTitle => 'Aucune transaction';

  @override
  String get emptyStateNoTransactionsMessage =>
      'Vous n\'avez pas encore effectué de transfert.';

  @override
  String get emptyStateNoTransactionsAction => 'Envoyer de l\'argent';

  @override
  String get emptyStateOfflineTitle => 'Mode hors-ligne';

  @override
  String get emptyStateOfflineMessage =>
      'Vous êtes actuellement hors-ligne. Certaines fonctionnalités peuvent être limitées.';

  @override
  String get emptyStateOfflineAction => 'Réessayer';

  @override
  String get emptyStateErrorTitle => 'Une erreur est survenue';

  @override
  String get emptyStateErrorMessage =>
      'Impossible de charger les données. Veuillez réessayer.';

  @override
  String get emptyStateErrorAction => 'Réessayer';

  @override
  String get emptyStateMaintenanceTitle => 'Maintenance en cours';

  @override
  String get emptyStateMaintenanceMessage =>
      'L\'application est en maintenance. Veuillez revenir plus tard.';

  @override
  String get transferSelectRecipientFirst =>
      'Veuillez sélectionner un bénéficiaire';

  @override
  String get transferSelectPaymentMethodFirst =>
      'Veuillez sélectionner un mode de paiement';

  @override
  String get transferInitiated => 'Transfert initié avec succès';

  @override
  String get transferFailed => 'Échec du transfert';

  @override
  String get businessCreationError => 'Erreur lors de la création';

  @override
  String get reviewPleaseRate => 'Veuillez donner une note';

  @override
  String get reviewPleaseWrite => 'Veuillez écrire un avis';

  @override
  String get reviewSubmitted => 'Avis soumis avec succès';

  @override
  String get reviewSubmissionError => 'Erreur lors de la soumission';

  @override
  String get mustBeLoggedIn => 'Vous devez être connecté';

  @override
  String get groupRequestSent => 'Demande envoyée avec succès';

  @override
  String get groupRequestApproved => 'Demande approuvée';

  @override
  String get groupRequestDeclined => 'Demande refusée';

  @override
  String get messageSent => 'Message envoyé';

  @override
  String get cannotGetLocation => 'Impossible d\'obtenir la position';

  @override
  String get reminderScheduled => 'Rappel programmé';

  @override
  String get reminderRemoved => 'Rappel supprimé';

  @override
  String get reminderPassed => 'Passé';

  @override
  String get selectAudioFile => 'Veuillez sélectionner un fichier audio';

  @override
  String get episodePublished => 'Épisode publié avec succès';

  @override
  String get downloadRemoved => 'Téléchargement supprimé';

  @override
  String get transactionStatusPending => 'En attente';

  @override
  String get transactionStatusDebiting => 'Débit en cours';

  @override
  String get transactionStatusProcessing => 'Traitement';

  @override
  String get transactionStatusSending => 'Envoi en cours';

  @override
  String get transactionStatusCompleted => 'Terminé';

  @override
  String get transactionStatusFailed => 'Échoué';

  @override
  String get transactionStatusRefunding => 'Remboursement en cours';

  @override
  String get transactionStatusRefunded => 'Remboursé';

  @override
  String get transactionStatusCancelled => 'Annulé';

  @override
  String get businessCategoryRestaurant => 'Restaurant';

  @override
  String get businessCategoryGrocery => 'Épicerie';

  @override
  String get businessCategoryBeauty => 'Beauté';

  @override
  String get businessCategoryFashion => 'Mode';

  @override
  String get businessCategoryServices => 'Services';

  @override
  String get businessCategoryHealth => 'Santé';

  @override
  String get businessCategoryEducation => 'Éducation';

  @override
  String get businessCategoryTechnology => 'Technologie';

  @override
  String get businessCategoryTravel => 'Voyage';

  @override
  String get businessCategoryOther => 'Autre';

  @override
  String get callAudio => 'Appel audio';

  @override
  String get callVideo => 'Appel vidéo';

  @override
  String get callRinging => 'Sonnerie';

  @override
  String get callOngoing => 'En cours';

  @override
  String get callMissed => 'Manqué';

  @override
  String get callDeclined => 'Refusé';

  @override
  String get callFailed => 'Échoué';

  @override
  String errorWithMessage(String message) {
    return 'Erreur : $message';
  }

  @override
  String get consentWelcome => 'Bienvenue !';

  @override
  String get consentAcceptConditions =>
      'Avant de continuer, veuillez accepter nos conditions.';

  @override
  String get consentTermsAccept =>
      'J\'accepte les conditions générales d\'utilisation de l\'application Diaspo Niger.';

  @override
  String get consentPrivacyAccept =>
      'J\'accepte la politique de confidentialité et le traitement de mes données personnelles.';

  @override
  String get consentCodeOfConductAccept =>
      'Je m\'engage à respecter le code de conduite et les règles de la communauté.';

  @override
  String get consentDataProtection =>
      'Vos données sont protégées et ne seront jamais partagées sans votre consentement.';

  @override
  String get readDetails => 'Lire les détails →';

  @override
  String get forgotPasswordTitle => 'Mot de passe oublié ?';

  @override
  String get forgotPasswordDescription =>
      'Entrez votre adresse email pour recevoir un lien de réinitialisation.';

  @override
  String get sendLink => 'Envoyer le lien';

  @override
  String get backToLogin => 'Retour à la connexion';

  @override
  String get emailSentTitle => 'Email envoyé !';

  @override
  String resetLinkSentTo(String email) {
    return 'Nous avons envoyé un lien de réinitialisation à $email';
  }

  @override
  String get checkSpamFolder =>
      'Vérifiez également votre dossier spam si vous ne trouvez pas l\'email.';

  @override
  String get resendLink => 'Renvoyer le lien';

  @override
  String get enableNotifications => 'Activer les notifications';

  @override
  String get notificationsMasterOnDesc =>
      'Vous recevez les notifications de l\'application';

  @override
  String get notificationsMasterOffDesc =>
      'Toutes les notifications sont coupées';

  @override
  String get notificationPromptMessage =>
      'Recevez des alertes lorsque vous avez de nouveaux messages, appels entrants ou activités importantes.\n\nVous pouvez modifier ce paramètre à tout moment.';

  @override
  String get later => 'Plus tard';

  @override
  String get notificationsDisabledMessage =>
      'Les notifications sont désactivées. Vous ne recevrez pas d\'alertes pour les nouveaux messages et appels.\n\nPour les activer, allez dans les paramètres de l\'application.';

  @override
  String get openSettings => 'Ouvrir les paramètres';

  @override
  String get permissionBlocked => 'Permission bloquée';

  @override
  String get typeYourReply => 'Tapez votre réponse...';

  @override
  String get openPlayStore => 'Ouvrir Play Store';

  @override
  String get understood => 'Compris';

  @override
  String get connectedElsewhere => 'Connecté ailleurs';

  @override
  String get connectedElsewhereMessage =>
      'Votre compte a été connecté sur un autre appareil. Vous avez été déconnecté de cet appareil pour sécurité.';

  @override
  String get ok => 'OK';

  @override
  String get taxAutomatic => 'Automatique';

  @override
  String get taxExempt => 'Exonéré';

  @override
  String get taxStandard => 'TVA Standard (19%)';

  @override
  String get taxReduced => 'TVA Réduite (10%)';

  @override
  String get taxCustom => 'Personnalisé';

  @override
  String get views => 'vues';

  @override
  String get reviews => 'Avis';

  @override
  String get contactAction => 'Contacter';

  @override
  String get addAction => 'Ajouter';

  @override
  String get viewAll => 'Voir tout';

  @override
  String get modify => 'Modifier';

  @override
  String get retryAction => 'Réessayer';

  @override
  String get tooltipFavorites => 'Favoris';

  @override
  String get tooltipForward => 'Transférer';

  @override
  String get tooltipDelete => 'Supprimer';

  @override
  String get tooltipVoiceCall => 'Appel vocal';

  @override
  String get tooltipVideoCall => 'Appel vidéo';

  @override
  String get addCaption => 'Ajouter une légende...';

  @override
  String get photosLabel => 'Photos';

  @override
  String get videosLabel => 'Vidéos';

  @override
  String get audioLabel => 'Audio';

  @override
  String get documentsLabel => 'Documents';

  @override
  String get photoLabel => 'Photo';

  @override
  String get videoLabel => 'Vidéo';

  @override
  String get positionLabel => 'Position';

  @override
  String get microphonePermissionRequired => 'Permission du microphone requise';

  @override
  String get cannotDeleteAfter1Hour =>
      'Impossible de supprimer le message après 1h';

  @override
  String get sendAction => 'Envoyer';

  @override
  String get forwardError => 'Erreur lors du transfert';

  @override
  String get cannotStartCall => 'Impossible de démarrer l\'appel';

  @override
  String get remindMeLater => 'Me rappeler plus tard';

  @override
  String get in1Hour => 'Dans 1 heure';

  @override
  String get tomorrowMorning => 'Demain matin (9h)';

  @override
  String get flipCamera => 'Flip';

  @override
  String get permissionRequired => 'Permission requise';

  @override
  String get adminOverview => 'Aperçu';

  @override
  String get adminUsers => 'Utilisateurs';

  @override
  String get adminBusinesses => 'Commerces';

  @override
  String get adminContent => 'Contenu';

  @override
  String get adminReports => 'Signalements';

  @override
  String get adminSupport => 'Support';

  @override
  String get adminLiveRooms => 'Salons Live';

  @override
  String get adminMarketplace => 'Marketplace';

  @override
  String get adminTransfers => 'Transferts';

  @override
  String get adminEmbassies => 'Ambassades';

  @override
  String get adminAnalytics => 'Analytics';

  @override
  String get adminNotifications => 'Notifications';

  @override
  String get adminConfiguration => 'Configuration';

  @override
  String get adminFeatures => 'Features';

  @override
  String get adminAudit => 'Audit';

  @override
  String get adminRoles => 'Rôles Admin';

  @override
  String get adminRefresh => 'Actualiser';

  @override
  String get adminLogout => 'Déconnexion';

  @override
  String get adminCreateEmbassy => 'Créer une ambassade';

  @override
  String get adminModerate => 'Modérer';

  @override
  String get adminModerationMode => 'Mode Modération';

  @override
  String get adminGhostModeDescription =>
      'Vous allez rejoindre ce salon en mode invisible (ghost mode). Les participants ne pourront pas vous voir.\n\nVous pourrez:\n• Écouter les conversations\n• Voir les vidéos (si activées)\n• Avertir l\'hôte\n• Fermer le salon si nécessaire';

  @override
  String get adminJoin => 'Rejoindre';

  @override
  String get adminViewReports => 'Voir Signalements';

  @override
  String get adminManageUsers => 'Gérer Utilisateurs';

  @override
  String get adminSendNotification => 'Envoyer Notification';

  @override
  String get adminViewAnalytics => 'Voir Analytics';

  @override
  String get adminFeatureFlags => 'Feature Flags';

  @override
  String get adminAuditHistory => 'Historique Audit';

  @override
  String get adminNewAdmin => 'Nouvel Admin';

  @override
  String adminChangeRole(String role) {
    return 'Changer le rôle';
  }

  @override
  String get adminRevokeAccess => 'Révoquer l\'accès admin';

  @override
  String get adminAccessDenied => 'Accès refusé. Compte administrateur requis.';

  @override
  String get adminBack => 'Retour';

  @override
  String adminAllTab(int count) {
    return 'Tous ($count)';
  }

  @override
  String adminPendingTab(int count) {
    return 'En attente ($count)';
  }

  @override
  String adminBoostedTab(int count) {
    return 'Boostés ($count)';
  }

  @override
  String get adminVerify => 'Vérifier';

  @override
  String get adminRemoveVerification => 'Retirer vérification';

  @override
  String get adminBoost30Days => 'Booster (30 jours)';

  @override
  String get adminRemoveBoost => 'Retirer boost';

  @override
  String get adminConfirmDeletion => 'Confirmer la suppression';

  @override
  String get adminGroupPrivate => 'Groupe rendu privé';

  @override
  String get adminGroupPublic => 'Groupe rendu public';

  @override
  String get makePublic => 'Rendre public';

  @override
  String get makePrivate => 'Rendre privé';

  @override
  String get adminEmailLabel => 'Email';

  @override
  String get adminEmailHint => 'utilisateur@exemple.com';

  @override
  String get adminEmbassyCreated => 'Ambassade créée avec succès !';

  @override
  String get adminConnectionError => 'Erreur lors de la connexion au salon';

  @override
  String get adminSearchPlaceholder => 'Rechercher par nom, raison, ID...';

  @override
  String get adminAllActions => 'Toutes les actions';

  @override
  String get adminActionUsers => 'Utilisateurs';

  @override
  String get adminActionBusinesses => 'Commerces';

  @override
  String get adminActionContent => 'Contenu';

  @override
  String get adminActionReports => 'Signalements';

  @override
  String get adminActionTransactions => 'Transactions';

  @override
  String get adminActionSettings => 'Configuration';

  @override
  String get adminFeatureFlagsUpdated => 'Feature flags mis à jour';

  @override
  String get adminMaintenanceHint => 'Ex: Application en maintenance...';

  @override
  String get adminSignInWithGoogle => 'Se connecter avec Google';

  @override
  String get adminEmailField => 'Email';

  @override
  String get adminPasswordField => 'Password';

  @override
  String get adminLogin => 'Connexion';

  @override
  String adminProductsTab(int count) {
    return 'Produits ($count)';
  }

  @override
  String adminOrdersTab(int count) {
    return 'Commandes ($count)';
  }

  @override
  String adminDisputesTab(int count) {
    return 'Litiges ($count)';
  }

  @override
  String get adminBuyer => 'Acheteur';

  @override
  String get adminSeller => 'Vendeur';

  @override
  String get adminRefund => 'Rembourser';

  @override
  String adminGroupsTab(int count) {
    return 'Groupes ($count)';
  }

  @override
  String get adminSendTab => 'Envoyer';

  @override
  String get adminHistoryTab => 'Historique';

  @override
  String get adminTitleLabel => 'Titre';

  @override
  String get adminMessageLabel => 'Message';

  @override
  String get adminClearAction => 'Effacer';

  @override
  String get adminConfirmSend => 'Confirmer l\'envoi';

  @override
  String get adminSendingNotificationTo =>
      'Vous êtes sur le point d\'envoyer une notification à:';

  @override
  String adminMessagePreview(String message) {
    return 'Message: $message';
  }

  @override
  String get adminSearchReportsPlaceholder =>
      'Rechercher par nom, raison, ID...';

  @override
  String adminViewTarget(String type) {
    return 'Voir le $type';
  }

  @override
  String get adminReject => 'Rejeter';

  @override
  String get adminProcess => 'Traiter';

  @override
  String get adminDeleteContent => 'Supprimer contenu';

  @override
  String get adminClearFilters => 'Effacer les filtres';

  @override
  String get adminRejectReasonHint =>
      'Ex: Signalement non fondé, contenu conforme aux règles...';

  @override
  String get adminProcessNoteHint =>
      'Ex: Avertissement envoyé, contenu modifié...';

  @override
  String adminChangeToRole(String role) {
    return 'Changer en $role';
  }

  @override
  String get adminFeesTab => 'Frais';

  @override
  String get adminBoostsTab => 'Boosts';

  @override
  String get adminTaxesTab => 'Taxes';

  @override
  String get adminMediaTab => 'Médias';

  @override
  String get adminSystemTab => 'Système';

  @override
  String get adminAudioTab => 'Audio';

  @override
  String get adminFeesUpdated => 'Frais mis à jour';

  @override
  String get adminFeePercentage => 'Pourcentage des frais';

  @override
  String get adminMinFee => 'Frais minimum (XOF)';

  @override
  String get adminMaxFee => 'Frais maximum (XOF)';

  @override
  String get adminPlatformCommission => 'Commission plateforme';

  @override
  String get adminMinCommission => 'Commission min (XOF)';

  @override
  String get adminMaxCommission => 'Commission max (XOF)';

  @override
  String get adminBoostPricesUpdated => 'Tarifs boost mis à jour';

  @override
  String get adminVatRatesUpdated => 'Taux de TVA mis à jour';

  @override
  String get adminMediaLimitsUpdated => 'Limites médias mises à jour';

  @override
  String get adminMaxDimension => 'Dimension max (px)';

  @override
  String get adminCompressionQuality => 'Qualité compression (%)';

  @override
  String get adminMaxImagesUpload => 'Max images/upload';

  @override
  String get adminMaxImageSize => 'Taille max image (MB)';

  @override
  String get adminMaxVideoSize => 'Taille max vidéo (MB)';

  @override
  String get adminMaxMessageChars => 'Caractères max par message';

  @override
  String get adminUrlsUpdated => 'URLs mises à jour';

  @override
  String get adminIntervalsUpdated => 'Intervalles mis à jour';

  @override
  String get adminShareBaseUrl => 'URL de base pour partage';

  @override
  String get adminSupportEmail => 'Email support';

  @override
  String get adminPrivacyEmail => 'Email confidentialité (RGPD)';

  @override
  String get adminBugReportEmail => 'Email rapport de bugs';

  @override
  String get adminFeedbackEmail => 'Email feedback';

  @override
  String get adminModerationEmail => 'Email modération';

  @override
  String get adminLocationUpdateInterval => 'Mise à jour localisation (min)';

  @override
  String get adminOnlineHeartbeat => 'Heartbeat statut en ligne (min)';

  @override
  String get adminCacheDuration => 'Durée cache (min)';

  @override
  String get adminAudioSettingsUpdated => 'Paramètres audio mis à jour';

  @override
  String get adminTicketPrices => 'Prix tickets (XOF)';

  @override
  String get adminTipAmounts => 'Montant pourboires (XOF)';

  @override
  String get adminPriceHint => 'Ex: 1, 2, 5, 10, 20';

  @override
  String get adminComplete => 'Compléter';

  @override
  String get adminSearchUserPlaceholder => 'Rechercher un utilisateur...';

  @override
  String get adminLoadingText => 'Chargement...';

  @override
  String get adminNoUserFound => 'Aucun utilisateur trouvé';

  @override
  String adminUserActivity(String name) {
    return 'Activité de $name';
  }

  @override
  String get adminNoActivity => 'Aucune activité enregistrée';

  @override
  String get adminConfirmLogout => 'Confirmer la déconnexion';

  @override
  String get adminDisconnect => 'Déconnecter';

  @override
  String get adminReactivate => 'Réactiver';

  @override
  String get adminApprove => 'Approuver';

  @override
  String get adminSuspend => 'Suspendre';

  @override
  String adminEmbassyApproved(String name) {
    return 'Ambassade $name approuvée';
  }

  @override
  String adminEmbassyRejected(String name) {
    return 'Ambassade $name rejetée';
  }

  @override
  String adminEmbassySuspended(String name) {
    return 'Ambassade $name suspendue';
  }

  @override
  String adminEmbassyReactivated(String name) {
    return 'Ambassade $name réactivée';
  }

  @override
  String get adminRejectRequest => 'Rejeter la demande';

  @override
  String get adminRejectReason => 'Raison du rejet';

  @override
  String adminExportInProgress(String type) {
    return 'Export des $type en cours...';
  }

  @override
  String get audioRoomWarnHost => 'Avertir l\'hôte';

  @override
  String audioRoomTicketHelper(String min, String max, String currency) {
    return 'Min: $min $currency - Max: $max $currency';
  }

  @override
  String audioRoomGoalHelper(String min, String max) {
    return 'Min: $min XOF - Max: $max XOF';
  }

  @override
  String get heritageStories => 'Contes';

  @override
  String get heritageProverbs => 'Proverbes';

  @override
  String get heritageHistory => 'Histoire';

  @override
  String get heritageCeremonies => 'Cérémonies';

  @override
  String get heritageLanguage => 'Langue';

  @override
  String get heritageCraft => 'Artisanat';

  @override
  String get heritageRecipes => 'Recettes';

  @override
  String get heritageMedicine => 'Médecine';

  @override
  String get boostType => 'Type :';

  @override
  String get boostDuration => 'Durée :';

  @override
  String get boostTotal => 'Total :';

  @override
  String get businessViews => 'Vues';

  @override
  String get businessReviews => 'Avis';

  @override
  String get businessContact => 'Contacter';

  @override
  String get businessAdd => 'Ajouter';

  @override
  String get businessNewPost => 'Nouvelle publication';

  @override
  String get businessPostType => 'Type';

  @override
  String get businessPostTitle => 'Titre';

  @override
  String get businessPostTitleHint => 'Ex: Nouvelle collection disponible';

  @override
  String get businessPostContent => 'Contenu';

  @override
  String get businessPostContentHint => 'Décrivez votre actualité...';

  @override
  String get businessDeletePost => 'Supprimer';

  @override
  String businessSeeAllReviews(int count) {
    return 'Voir les $count autres avis';
  }

  @override
  String get reviewMustBeLoggedIn =>
      'Vous devez être connecté pour laisser un avis';

  @override
  String get reviewDeleteTitle => 'Supprimer l\'avis';

  @override
  String get reviewDeleteConfirm =>
      'Voulez-vous vraiment supprimer cet avis ? Cette action est irréversible.';

  @override
  String get reviewReportTitle => 'Signaler cet avis';

  @override
  String get reviewReportReason => 'Raison du signalement';

  @override
  String get reviewReportHint => 'Pourquoi signalez-vous cet avis ?';

  @override
  String get reviewReportNoReason => 'Veuillez indiquer une raison';

  @override
  String get reviewModify => 'Modifier';

  @override
  String get reviewReport => 'Signaler';

  @override
  String get reviewSubmitError => 'Erreur lors de la soumission';

  @override
  String get reviewTitleOptional => 'Titre (optionnel)';

  @override
  String get reviewTitleHint => 'Ex: Excellent service';

  @override
  String get reviewYourReview => 'Votre avis';

  @override
  String get reviewShareExperience => 'Partagez votre expérience...';

  @override
  String get businessSearchCountry => 'Rechercher un pays';

  @override
  String get businessCityHint => 'Ex: Paris, Niamey, New York...';

  @override
  String get businessNewTitle => 'Nouvelle entreprise';

  @override
  String get businessPhotosSection => 'Photos';

  @override
  String get businessCategorySection => 'Catégorie';

  @override
  String get businessNameLabel => 'Nom de l\'entreprise *';

  @override
  String get businessDescriptionLabel => 'Description *';

  @override
  String get businessContactSection => 'Contact';

  @override
  String get businessPhoneLabel => 'Téléphone';

  @override
  String get businessEmailLabel => 'Email';

  @override
  String get businessWebsiteLabel => 'Site web';

  @override
  String get businessLocationSection => 'Localisation';

  @override
  String get businessSearchCountryHint => 'Tapez le nom du pays';

  @override
  String get businessCountryLabel => 'Pays';

  @override
  String get businessCityLabel => 'Ville';

  @override
  String get businessAddressLabel => 'Adresse';

  @override
  String get businessServicesSection => 'Services proposés';

  @override
  String get businessAddServiceHint => 'Ajouter un service';

  @override
  String get businessCreateButton => 'Créer l\'entreprise';

  @override
  String get callPermissionTitle => 'Permission requise';

  @override
  String get callClose => 'Fermer';

  @override
  String get embassyRequestSubmitted => 'Demande soumise avec succès !';

  @override
  String get embassyNewRequest => 'Nouvelle demande';

  @override
  String embassyReopenDate(String date) {
    return 'Réouverture prévue: $date';
  }

  @override
  String get embassyContact => 'Contacter';

  @override
  String get embassyRequest => 'Demande';

  @override
  String get embassyStaff => 'Personnel';

  @override
  String get embassyCall => 'Appeler';

  @override
  String get embassyEmail => 'Email';

  @override
  String get embassyWebsite => 'Site Web';

  @override
  String get embassyDirections => 'Y aller';

  @override
  String get embassyMessageSent => 'Message envoyé avec succès !';

  @override
  String get embassyContactTitle => 'Contacter l\'ambassade';

  @override
  String get embassySubjectHint =>
      'Ex: Demande de renseignements sur le passeport';

  @override
  String get embassyMessageHint => 'Décrivez votre demande en détail...';

  @override
  String get embassyDepartment => 'Département';

  @override
  String get embassyCallAction => 'Appeler';

  @override
  String get embassyRoute => 'Itinéraire';

  @override
  String get embassyDetails => 'Détails';

  @override
  String eventImageSelectionError(String error) {
    return 'Erreur lors de la sélection des images: $error';
  }

  @override
  String get eventSelectImages => 'Sélectionner des images';

  @override
  String get eventPosterLimit => 'Limite de 5 affiches atteinte';

  @override
  String get eventShareRecap => 'Partager le récapitulatif';

  @override
  String get eventPhotoLimit => 'Limite de 10 photos atteinte';

  @override
  String get eventAddPhotoMin => 'Veuillez ajouter au moins une photo';

  @override
  String get eventSelectPhotos => 'Sélectionner des photos';

  @override
  String eventAddPhotos(int count) {
    return 'Ajouter des photos ($count/10)';
  }

  @override
  String get friendSendMessage => 'Envoyer un message';

  @override
  String get friendRemoveTitle => 'Retirer des amis';

  @override
  String get friendRemoveAction => 'Retirer';

  @override
  String get friendRequestDeclined => 'Demande refusée';

  @override
  String get friendDecline => 'Refuser';

  @override
  String get friendRequestAccepted => 'Demande acceptée';

  @override
  String get friendAccept => 'Accepter';

  @override
  String get friendRequestCancelled => 'Demande annulée';

  @override
  String get friendCancelRequest => 'Annuler la demande';

  @override
  String get groupCreateTitle => 'Créer un groupe';

  @override
  String get groupEditTitle => 'Modifier le groupe';

  @override
  String get groupPromoteAdmin => 'Promouvoir Admin';

  @override
  String get groupDemoteAdmin => 'Retirer Admin';

  @override
  String get groupConfirmAction => 'Confirmer';

  @override
  String get groupMembershipRequests => 'Demandes d\'adhésion';

  @override
  String get groupRejectTooltip => 'Refuser';

  @override
  String get groupApproveTooltip => 'Approuver';

  @override
  String get groupFilterAll => 'Tous';

  @override
  String get groupFilterAllFeminine => 'Toutes';

  @override
  String get shareWhatsApp => 'WhatsApp';

  @override
  String get shareFacebook => 'Facebook';

  @override
  String get shareX => 'X';

  @override
  String get shareMore => 'Plus';

  @override
  String get homeMessages => 'Messages';

  @override
  String get homeGroups => 'Groupes';

  @override
  String get homeMarketplace => 'Marketplace';

  @override
  String get homeTransfers => 'Transferts';

  @override
  String get homeDirectory => 'Annuaire';

  @override
  String get mapEnable => 'ACTIVER';

  @override
  String get mapTestTitle => 'Test Carte Simple';

  @override
  String get marketplaceAddImageMin => 'Ajoutez au moins une image';

  @override
  String get marketplaceCustomTaxRate => 'Taux personnalisé (%)';

  @override
  String get marketplaceCustomTaxHint => 'Ex: 15';

  @override
  String get marketplacePriceTTC => 'Prix TTC';

  @override
  String get marketplaceSubtotal => 'Sous-total';

  @override
  String marketplaceTaxRate(String rate) {
    return 'Taxe ($rate%)';
  }

  @override
  String get marketplaceTitleLabel => 'Titre';

  @override
  String get marketplaceTitleHint => 'Ex: iPhone 13 Pro Max';

  @override
  String get marketplaceDescriptionLabel => 'Description';

  @override
  String get marketplaceDescriptionHint => 'Décrivez votre produit...';

  @override
  String get marketplacePriceLabel => 'Prix';

  @override
  String get marketplaceQuantityLabel => 'Quantité';

  @override
  String get marketplaceCurrencyLabel => 'Devise';

  @override
  String get marketplaceCategoryLabel => 'Catégorie';

  @override
  String get marketplaceConditionLabel => 'État';

  @override
  String get marketplaceCountryLabel => 'Pays';

  @override
  String get marketplaceCityLabel => 'Ville/Adresse (optionnel)';

  @override
  String get marketplaceCityHint => 'Ex: Niamey';

  @override
  String get marketplaceAllCategory => 'Tout';

  @override
  String get marketplaceMyOrders => 'Mes commandes';

  @override
  String get marketplaceDiscoverProducts => 'Découvrir les produits';

  @override
  String get marketplacePaymentSuccess => 'Paiement effectué avec succès !';

  @override
  String get marketplaceOrderUpdateError =>
      'Erreur lors de la mise à jour de la commande';

  @override
  String marketplacePaymentError(String error) {
    return 'Erreur de paiement: $error';
  }

  @override
  String get marketplaceDeliveryConfirmed => 'Livraison confirmée';

  @override
  String get marketplaceMarkedAsShipped => 'Commande marquée comme expédiée';

  @override
  String get marketplaceTrackingNumber => 'Numéro de suivi';

  @override
  String get marketplaceTrackingHint => 'Entrez le numéro de suivi (optionnel)';

  @override
  String get marketplaceLoadingLabel => 'Chargement...';

  @override
  String get marketplaceViewsLabel => 'vues';

  @override
  String get marketplacePublishedLabel => 'publié';

  @override
  String get marketplaceAddedToCart => 'Ajouté au panier';

  @override
  String get marketplaceViewCart => 'Voir';

  @override
  String get marketplaceAddToCart => 'Ajouter au panier';

  @override
  String get marketplaceDeleteProduct => 'Supprimer le produit';

  @override
  String get marketplaceConversationError =>
      'Erreur lors de la création de la conversation';

  @override
  String get messageVideoPlayError => 'Erreur de lecture de la vidéo';

  @override
  String get messageVideoSaved => 'Vidéo enregistrée dans la galerie';

  @override
  String get messageVideoSaveError => 'Erreur lors de l\'enregistrement';

  @override
  String get messageInfo => 'Info';

  @override
  String messageBackgroundError(String error) {
    return 'Erreur lors de la sélection de l\'image: $error';
  }

  @override
  String messageBackgroundApplyError(String error) {
    return 'Erreur lors de l\'application: $error';
  }

  @override
  String messagePhotosCount(int count) {
    return 'Photos ($count)';
  }

  @override
  String messageFilesCount(int count) {
    return 'Fichiers ($count)';
  }

  @override
  String get messageLocationSearchHint => 'Rechercher un lieu...';

  @override
  String get messageLocationError => 'Impossible d\'obtenir la position';

  @override
  String get messageSendThisPosition => 'Envoyer cette position';

  @override
  String get fileLabel => 'Fichier';

  @override
  String get messageTypeAudio => '🎵 Audio';

  @override
  String get messageTypeVoiceNote => 'Note vocale';

  @override
  String get shareError => 'Impossible de partager ce contenu';

  @override
  String get shareDownloadingMedia => 'Préparation du média...';

  @override
  String get messageInfoTitle => 'Infos du message';

  @override
  String messageSentAt(String time) {
    return 'Envoyé · $time';
  }

  @override
  String tabReadBy(int n) {
    return 'Lu · $n';
  }

  @override
  String tabDeliveredTo(int n) {
    return 'Reçu · $n';
  }

  @override
  String tabReactions(int n) {
    return 'Réactions · $n';
  }

  @override
  String get allReactions => 'Tous';

  @override
  String get noReactionsYet => 'Aucune réaction pour l\'instant';

  @override
  String get notReadYet => 'Aucun membre n\'a encore lu ce message';

  @override
  String get notDeliveredYet => 'Pas encore reçu';

  @override
  String get documentPDF => 'PDF';

  @override
  String get documentDOC => 'DOC';

  @override
  String get documentXLS => 'XLS';

  @override
  String get documentPPT => 'PPT';

  @override
  String get documentZIP => 'ZIP';

  @override
  String get documentTXT => 'TXT';

  @override
  String get documentCSV => 'CSV';

  @override
  String get documentJSON => 'JSON';

  @override
  String get notificationIn1Hour => 'Dans 1 heure';

  @override
  String get notificationTomorrowMorning => 'Demain matin (9h)';

  @override
  String get notificationReminderScheduled => 'Rappel programmé';

  @override
  String get paymentBankHint => 'Ex: BCEAO, Ecobank...';

  @override
  String get paymentIbanHint => 'NEXX XXXX XXXX XXXX';

  @override
  String get podcastTitleLabel => 'Titre du podcast *';

  @override
  String get podcastDescriptionLabel => 'Description';

  @override
  String get podcastCategoryLabel => 'Catégorie *';

  @override
  String get podcastLanguageLabel => 'Langue *';

  @override
  String get podcastFrequencyLabel => 'Fréquence de publication';

  @override
  String get podcastTagsLabel => 'Tags';

  @override
  String get podcastTagsHint => 'Ajouter un tag';

  @override
  String get podcastLike => 'J\'aime';

  @override
  String get podcastSleepTimerDisabled => 'Désactivé';

  @override
  String get podcastEpisodeEnd => 'Fin de l\'épisode';

  @override
  String get podcastSleepTimerEnabled => 'Arrêt à la fin de l\'épisode activé';

  @override
  String get podcastSleepTimerEnded => 'Minuterie de sommeil terminée';

  @override
  String podcastTimerMinutes(int minutes) {
    return 'Minuterie: $minutes minutes';
  }

  @override
  String get podcastAddChapter => 'Ajouter un chapitre';

  @override
  String get podcastChapterTitle => 'Titre du chapitre';

  @override
  String get podcastMinutes => 'Minutes';

  @override
  String get podcastSeconds => 'Secondes';

  @override
  String get podcastSelectAudioFile => 'Veuillez sélectionner un fichier audio';

  @override
  String get podcastNewEpisode => 'Nouvel épisode';

  @override
  String get podcastEpisodeTitle => 'Titre de l\'épisode *';

  @override
  String get podcastEpisodeNotes => 'Description / Notes';

  @override
  String get podcastPremiumOnly => 'Réservé aux abonnés payants';

  @override
  String get podcastDownloaded => 'Téléchargé';

  @override
  String get podcastDownload => 'Télécharger';

  @override
  String get podcastDeleteDownload => 'Supprimer le téléchargement';

  @override
  String get podcastDownloadRemoved => 'Téléchargement supprimé';

  @override
  String get podcastSelectOrCreate =>
      'Sélectionnez un podcast ou créez-en un nouveau';

  @override
  String get podcastRecordingComingSoon =>
      'L\'enregistrement du salon sera bientôt disponible';

  @override
  String get podcastAudioNotFound => 'Fichier audio introuvable';

  @override
  String get podcastPublishError => 'Erreur lors de la publication';

  @override
  String get podcastEpisodeTitleHint => 'Titre de l\'épisode';

  @override
  String get podcastEpisodeDescriptionHint =>
      'Description de l\'épisode (optionnel)';

  @override
  String get podcastPublish => 'Publier';

  @override
  String get podcastCreateNew => 'Créer un podcast';

  @override
  String get profileSpecifyProfession => 'Précisez votre profession';

  @override
  String get profileSpecifyCountry => 'Ou saisissez votre pays';

  @override
  String get profileRegion => 'Région';

  @override
  String get profileOriginCity => 'Ville d\'origine';

  @override
  String get profileSpecifyOriginCity => 'Précisez votre ville d\'origine';

  @override
  String get profilePhoneVerified => 'Numéro vérifié avec succès !';

  @override
  String profileCodeSent(String phone) {
    return 'Code envoyé au $phone';
  }

  @override
  String get profileConfigTitle => 'Configuration du profil';

  @override
  String get profilePrevious => 'Précédent';

  @override
  String get profileFullNameLabel => 'Nom complet';

  @override
  String get profileFullNameHint => 'Ex: Jean Dupont';

  @override
  String get profileProfessionLabel => 'Profession';

  @override
  String get profileProfessionHint => 'Sélectionnez votre profession';

  @override
  String get profileCurrentCityLabel => 'Ville actuelle';

  @override
  String get profileCurrentCityHint => 'Ex: Paris, Niamey, New York...';

  @override
  String get profileOriginCityHint => 'Votre ville...';

  @override
  String get profileShareLocation => 'Partager ma localisation';

  @override
  String get profileEnableNotifications => 'Activer les notifications';

  @override
  String get profileReceiveAllNotifications =>
      'Recevoir toutes les notifications';

  @override
  String get profileNewEventsInCity => 'Nouveaux événements dans votre ville';

  @override
  String get profileMessagesNotifications => 'Messages';

  @override
  String get profileNewMessagesNotifications =>
      'Nouveaux messages et conversations';

  @override
  String get profileCurrentCountryLabel => 'Pays actuel';

  @override
  String get profileSelectCountry => 'Sélectionnez votre pays';

  @override
  String get profileOriginRegionLabel => 'Région d\'origine';

  @override
  String get profileSelectRegion => 'Sélectionnez votre région';

  @override
  String get profileOriginCityLabel => 'Ville d\'origine';

  @override
  String get profileSelectCity => 'Sélectionnez votre ville';

  @override
  String get profileLocationDenied => 'Permission de localisation refusée';

  @override
  String get profileCannotChatDeleted =>
      'Impossible de discuter avec un utilisateur supprimé';

  @override
  String get profileCannotCall => 'Impossible d\'appeler cet utilisateur';

  @override
  String get profileBlockUser => 'Bloquer l\'utilisateur';

  @override
  String get profileTravelMode => 'Mode Voyage';

  @override
  String get profileAudioCall => 'Audio';

  @override
  String get profileVideoCall => 'Vidéo';

  @override
  String get profileRequestCancelled => 'Demande d\'ami annulée';

  @override
  String get profileRequestNotExist => 'Cette demande n\'existe plus.';

  @override
  String get profileCancelRequestAction => 'Annuler la demande';

  @override
  String get profileRequestDeclined => 'Demande d\'ami refusée';

  @override
  String get profileDeclineAction => 'Refuser';

  @override
  String get profileRequestAccepted => 'Demande d\'ami acceptée';

  @override
  String get profileAcceptAction => 'Accepter';

  @override
  String get profileQRScanned => 'QR code scanné avec succès';

  @override
  String get reportMyReports => 'Mes signalements';

  @override
  String get reportDescribeIssue => 'Décrivez le problème...';

  @override
  String get reportSendReport => 'Envoyer le signalement';

  @override
  String get settingsRenameDevice => 'Renommer l\'appareil';

  @override
  String get settingsDeviceName => 'Nom de l\'appareil';

  @override
  String get settingsRenameAction => 'Renommer';

  @override
  String get settingsRevokeDevice => 'Révoquer l\'appareil ?';

  @override
  String get settingsRevokeAction => 'Révoquer';

  @override
  String get settingsConnectedDevices => 'Appareils connectés';

  @override
  String get settingsDeleteBackup => 'Supprimer la sauvegarde ?';

  @override
  String get settingsKeyBackup => 'Sauvegarde des clés';

  @override
  String get settingsPassphraseLabel => 'Passphrase';

  @override
  String get settingsRestoreKeys => 'Restaurer les clés';

  @override
  String get settingsGeneratePassphrase => 'Générer une passphrase sécurisée';

  @override
  String get settingsPassphraseHint => 'Minimum 8 caractères';

  @override
  String get settingsConfirmPassphrase => 'Confirmer la passphrase';

  @override
  String get settingsCreateBackup => 'Créer la sauvegarde';

  @override
  String get settingsTermsOfService => 'Conditions d\'utilisation';

  @override
  String get settingsBugDescriptionLabel => 'Description du bug';

  @override
  String get settingsBugDescriptionHint => 'Décrivez le problème rencontré...';

  @override
  String get settingsCurrencySearchHint => 'Rechercher une devise...';

  @override
  String get transferFullNameLabel => 'Nom complet *';

  @override
  String get transferFullNameHint => 'Ex: Amadou Boubacar';

  @override
  String get transferPhoneLabel => 'Numéro de téléphone *';

  @override
  String get transferEmailOptional => 'Email (optionnel)';

  @override
  String get transferEmailHint => 'exemple@email.com';

  @override
  String get transferCardNameLabel => 'Nom sur la carte *';

  @override
  String get transferCardNameHint => 'JEAN DUPONT';

  @override
  String get transferChangeCard => 'Changer';

  @override
  String get transferCardInfoLabel => 'Informations de carte *';

  @override
  String get transferCountryLabel => 'Pays';

  @override
  String get transferCityLabel => 'Ville';

  @override
  String get transferAddressOptional => 'Adresse (optionnel)';

  @override
  String get transferAddressHint => 'Quartier, rue...';

  @override
  String get transferAddToFavorites => 'Ajouter aux favoris';

  @override
  String get transferFavoritesSubtitle =>
      'Accès rapide lors des prochains transferts';

  @override
  String get transferEnterCardInfo =>
      'Veuillez saisir les informations de carte complètes';

  @override
  String get transferDeleteRecipient => 'Supprimer le bénéficiaire ?';

  @override
  String get transferRecipientDeleted => 'Bénéficiaire supprimé';

  @override
  String get transferNewRecipient => 'Nouveau';

  @override
  String get transferAddManually => 'Ajouter manuellement';

  @override
  String get transferChooseRecipient => 'Choisir un bénéficiaire';

  @override
  String get transferAddRecipientTooltip => 'Ajouter un bénéficiaire';

  @override
  String get transferEditRecipient => 'Modifier';

  @override
  String transferDeleteConfirm(String name) {
    return 'Supprimer $name ?';
  }

  @override
  String get transferAccountNumber => 'Numéro de compte / IBAN *';

  @override
  String get transferAccountHint => 'XXXX XXXX XXXX XXXX';

  @override
  String get transferCurrencyLabel => 'Devise';

  @override
  String get transferMessageTitle => 'Message';

  @override
  String get transferSelectRecipient => 'Sélectionnez un bénéficiaire';

  @override
  String get transferTotal => 'Total :';

  @override
  String transferDebitInProgress(String provider) {
    return 'Débit $provider en cours...';
  }

  @override
  String get transferDetails => 'Détails du transfert';

  @override
  String get transferAmountSentLabel => 'Montant envoyé';

  @override
  String get transferCopied => 'Copié dans le presse-papiers';

  @override
  String get transferRetry => 'Réessayer le transfert';

  @override
  String get transferContactSupport => 'Contacter le support';

  @override
  String get transferHistory => 'Historique des transferts';

  @override
  String get transferSendAction => 'Envoyer';

  @override
  String get transferActiveFilters => 'Filtres actifs: ';

  @override
  String get transferClearAll => 'Effacer tout';

  @override
  String get transferSendMoney2 => 'Envoyer de l\'argent';

  @override
  String get transferChoosePeriod => 'Choisir une période';

  @override
  String get transferApplyFilters => 'Appliquer les filtres';

  @override
  String get transferTitle => 'Transferts';

  @override
  String get transferRecipientsTooltip => 'Bénéficiaires';

  @override
  String get transferHistoryTooltip => 'Historique';

  @override
  String get transferSendMoneyDescription =>
      'Transférez de l\'argent vers le Niger en quelques clics';

  @override
  String get transferRecentTransactions => 'Transactions récentes';

  @override
  String get transferNoTransactions => 'Aucune transaction';

  @override
  String get transferTransactionsWillAppear =>
      'Vos transferts apparaîtront ici';

  @override
  String get transferSend => 'Envoyer';

  @override
  String get personalInfo => 'Informations personnelles';

  @override
  String get recipientTypeTitle => 'Mode de réception';

  @override
  String get paymentDetailsTitle => 'Détails de paiement';

  @override
  String get locationTitle => 'Localisation';

  @override
  String mobileTransferInfo(String service) {
    return 'Le transfert sera effectué via $service sur le numéro de téléphone du bénéficiaire.';
  }

  @override
  String get cashPickupInfo =>
      'Le bénéficiaire pourra retirer l\'argent dans un point de service NITA avec une pièce d\'identité.';

  @override
  String get addRecipientButton => 'Ajouter le bénéficiaire';

  @override
  String get recipientModified => 'Bénéficiaire modifié avec succès';

  @override
  String get recipientAdded => 'Bénéficiaire ajouté avec succès';

  @override
  String get supportEmailTitle => 'Email';

  @override
  String get supportLiveChat => 'Chat en direct';

  @override
  String get supportAvailable247 => 'Disponible 24/7';

  @override
  String get supportChatUnavailable => 'Chat non disponible pour le moment';

  @override
  String get supportPhone => 'Téléphone';

  @override
  String get imagePickerCamera => 'Caméra';

  @override
  String get imagePickerGallery => 'Galerie';

  @override
  String get notificationEnableDescription =>
      'Recevez des alertes lorsque vous avez de nouveaux messages, appels entrants ou activités importantes.\n\nVous pouvez modifier ce paramètre à tout moment.';

  @override
  String get notificationDisabledDescription =>
      'Les notifications sont désactivées. Vous ne recevrez pas d\'alertes pour les nouveaux messages et appels.\n\nPour les activer, allez dans les paramètres de l\'application.';

  @override
  String get notificationBlockedDescription =>
      'Vous avez bloqué les notifications pour cette application.\n\nPour recevoir des notifications de nouveaux messages et appels, vous devez les activer manuellement dans les paramètres système.';

  @override
  String get installFromPlayStore =>
      'Pour accéder à cette fonctionnalité, veuillez installer l\'application depuis Google Play Store.';

  @override
  String get accessRestricted => 'Accès restreint';

  @override
  String securityCheckFailed(String error) {
    return 'Impossible de vérifier la sécurité: $error';
  }

  @override
  String get deviceBasicSecurityFailed =>
      'Cet appareil ne répond pas aux exigences de sécurité de base.';

  @override
  String get deviceSecurityFailed =>
      'Cet appareil ne répond pas aux exigences de sécurité.';

  @override
  String get playStoreRequired =>
      'Cette fonctionnalité nécessite l\'installation depuis Google Play Store.';

  @override
  String get highSecurityFailed =>
      'Cet appareil ne répond pas aux exigences de sécurité élevées.';

  @override
  String get signedInElsewhere => 'Connecté ailleurs';

  @override
  String get signedInElsewhereDescription =>
      'Votre compte a été connecté sur un autre appareil. Vous avez été déconnecté de cet appareil pour sécurité.';

  @override
  String get cameraPermissionRestricted =>
      'L\'accès à la caméra est restreint sur cet appareil.';

  @override
  String get cameraPermissionRequired =>
      'L\'accès à la caméra est nécessaire pour prendre des photos.';

  @override
  String get photoLibraryPermissionDenied =>
      'L\'accès aux photos a été refusé. Veuillez l\'activer dans les paramètres de l\'application.';

  @override
  String get photoLibraryPermissionRestricted =>
      'L\'accès aux photos est restreint sur cet appareil.';

  @override
  String get photoLibraryPermissionRequired =>
      'L\'accès aux photos est nécessaire pour sélectionner des images.';

  @override
  String get selectAnElement => 'Sélectionnez un élément';

  @override
  String get cameraPermissionRequiredTitle => 'Permission caméra requise';

  @override
  String get specifyYourProfession => 'Précisez votre profession';

  @override
  String get orEnterYourCountry => 'Ou saisissez votre pays';

  @override
  String get profileConfiguration => 'Configuration du profil';

  @override
  String get locationPermissionDeniedForever =>
      'Permission de localisation refusée définitivement';

  @override
  String get travelModeEnabled =>
      'Mode Voyage activé (Localisation en arrière-plan)';

  @override
  String get travelModeDisabled => 'Mode Voyage désactivé';

  @override
  String get cannotChatWithDeletedUser =>
      'Impossible de discuter avec un utilisateur supprimé';

  @override
  String get qrCodeScannedSuccess => 'QR code scanné avec succès';

  @override
  String get whatsApp => 'WhatsApp';

  @override
  String get facebook => 'Facebook';

  @override
  String get sendAMessage => 'Envoyer un message';

  @override
  String get removeFromFriends => 'Retirer des amis';

  @override
  String get requestDeclinedMessage => 'Demande refusée';

  @override
  String get decline => 'Refuser';

  @override
  String get requestSentSuccess => 'Demande envoyée avec succès';

  @override
  String get removeAdmin => 'Retirer Admin';

  @override
  String get membershipRequests => 'Demandes d\'adhésion';

  @override
  String errorPrefix(String error) {
    return 'Erreur: $error';
  }

  @override
  String get favorites => 'Favoris';

  @override
  String photosCount(int count) {
    return 'Photos ($count)';
  }

  @override
  String filesCount(int count) {
    return 'Fichiers ($count)';
  }

  @override
  String get videoPlaybackError => 'Erreur de lecture de la vidéo';

  @override
  String get videoSavedToGallery => 'Vidéo enregistrée dans la galerie';

  @override
  String get info => 'Info';

  @override
  String imageSelectionError(String error) {
    return 'Erreur lors de la sélection de l\'image: $error';
  }

  @override
  String get cannotDeleteMessageAfter1h =>
      'Impossible de supprimer le message après 1h';

  @override
  String get pdf => 'PDF';

  @override
  String get doc => 'DOC';

  @override
  String get joinCall => 'Join';

  @override
  String get groupCall => 'Appel de groupe';

  @override
  String get cannotGetPosition => 'Impossible d\'obtenir la position';

  @override
  String get searchPlace => 'Rechercher un lieu...';

  @override
  String get modifyGroup => 'Modifier le groupe';

  @override
  String get themeMode => 'Mode';

  @override
  String get themeAppearance => 'Apparence';

  @override
  String get themeGreenDefault => 'Vert (Défaut)';

  @override
  String get themeOrangeClassic => 'Orange (Classique)';

  @override
  String get scanProfile => 'Scanner un profil';

  @override
  String get placeQrCodeInFrame =>
      'Placez le QR code dans le cadre pour scanner';

  @override
  String get flashActive => 'Flash actif';

  @override
  String get flash => 'Flash';

  @override
  String cameraErrorCode(String errorCode) {
    return 'Erreur caméra: $errorCode';
  }

  @override
  String get invalidQrCode => 'QR code invalide';

  @override
  String get linkExpiredOrNotFound => 'Lien expiré ou introuvable';

  @override
  String get connectionError => 'Erreur de connexion';

  @override
  String get invalidQrCodeFormat => 'QR code invalide ou format non reconnu';

  @override
  String get shareMyProfileTitle => 'Partager mon profil';

  @override
  String get generatingLink => 'Génération du lien...';

  @override
  String get unableToGenerateShareLink =>
      'Impossible de générer le lien de partage';

  @override
  String get oops => 'Oups !';

  @override
  String get errorOccurred => 'Une erreur est survenue';

  @override
  String get scanToFindMe => 'Scannez pour me retrouver';

  @override
  String get scanQrCode => 'Scanner un QR code';

  @override
  String discoverMyProfile(String url) {
    return 'Découvrez mon profil sur Diaspo Niger: $url';
  }

  @override
  String get myProfileOnDiaspoNiger => 'Mon profil Diaspo Niger';

  @override
  String atTime(String time) {
    return 'à $time';
  }

  @override
  String get saveVideoError => 'Erreur lors de l\'enregistrement';

  @override
  String get fileNotAvailable => 'Fichier non disponible';

  @override
  String get fileCouldNotLoad => 'Le fichier n\'a pas pu être chargé';

  @override
  String get host => 'Hôte';

  @override
  String get live => 'En direct';

  @override
  String get waiting => 'En attente';

  @override
  String get endToEndEncrypted => 'Chiffré de bout en bout';

  @override
  String get noPhotos => 'Aucune photo';

  @override
  String get noFiles => 'Aucun fichier';

  @override
  String get loadingVideo => 'Chargement de la vidéo...';

  @override
  String get playbackError => 'Erreur de lecture';

  @override
  String get deleteMessage => 'Supprimer le message';

  @override
  String get selectAction => 'Sélectionner';

  @override
  String sendToConversations(int count) {
    return 'Envoyer à $count conversation(s)';
  }

  @override
  String get cannotResendMessage =>
      'Impossible de renvoyer ce type de message. Veuillez le renvoyer manuellement.';

  @override
  String get searchError => 'Erreur de recherche';

  @override
  String applyError(String error) {
    return 'Erreur lors de l\'application: $error';
  }

  @override
  String get deleteForMeSubtitle =>
      'Le message sera supprimé uniquement de votre vue';

  @override
  String get deleteForEveryoneSubtitle =>
      'Le message sera supprimé pour tous les participants';

  @override
  String get audioNotAvailable => 'Audio non disponible';

  @override
  String get invalidAudioUrl => 'URL audio invalide';

  @override
  String get audioPlaybackError => 'Erreur de lecture';

  @override
  String get audioNotFound => 'Audio introuvable';

  @override
  String get insufficientPermissionMessage =>
      'Vous n\'avez pas la permission d\'accéder à cette page.';

  @override
  String get shareALocation => 'Partager une position';

  @override
  String get searchLocation => 'Rechercher un lieu...';

  @override
  String get selectedPosition => 'Position sélectionnée';

  @override
  String get gettingLocation => 'Obtention de la position...';

  @override
  String get myCurrentLocation => 'Ma position actuelle';

  @override
  String get orSelectOnMap => 'ou sélectionnez sur la carte';

  @override
  String get loadingMap => 'Chargement de la carte...';

  @override
  String get sendThisLocation => 'Envoyer cette position';

  @override
  String get thisGroupWasDeleted => 'Ce groupe a été supprimé';

  @override
  String get thisUserWasDeleted => 'Cet utilisateur a été supprimé';

  @override
  String get youBlockedThisUser => 'Vous avez bloqué cet utilisateur';

  @override
  String get messageResendFailed => 'Échec du renvoi du message';

  @override
  String get unableToStartCall => 'Impossible de démarrer l\'appel';

  @override
  String get encrypted => 'Chiffré';

  @override
  String get typeYourMessageBelow => 'Tapez votre message ci-dessous';

  @override
  String get sendFirstMessageGroup =>
      'Soyez le premier à envoyer un message dans ce groupe !';

  @override
  String get accept => 'Accepter';

  @override
  String confirmRemoveFriend(String name) {
    return 'Voulez-vous vraiment retirer $name de vos amis ?';
  }

  @override
  String get groupCreatedSuccess => 'Groupe créé avec succès';

  @override
  String get groupUpdatedSuccess => 'Groupe modifié avec succès';

  @override
  String get groupUpdateError => 'Erreur lors de la modification du groupe';

  @override
  String get addPhoto => 'Ajouter une photo';

  @override
  String get groupNamePlaceholder => 'Ex: Entrepreneurs Niger';

  @override
  String get describeYourGroup => 'Décrivez votre groupe...';

  @override
  String get descriptionMinLength =>
      'La description doit contenir au moins 10 caractères';

  @override
  String get selectCountry => 'Sélectionner un pays';

  @override
  String get hostCountryHelp => 'Le pays où se trouve la communauté du groupe';

  @override
  String get selectRegion => 'Sélectionner une région';

  @override
  String get originRegionHelp =>
      'Pour regrouper les membres par région d\'origine';

  @override
  String get detailedLocation => 'Localisation détaillée (optionnel)';

  @override
  String get tagsHint => 'Séparez les tags par des virgules';

  @override
  String get membersNeedApproval => 'Les membres doivent être approuvés';

  @override
  String get createTheGroup => 'Créer le groupe';

  @override
  String get sendFileTitle => 'Envoyer un fichier';

  @override
  String get cameraSection => 'Caméra';

  @override
  String get locationSection => 'Localisation';

  @override
  String get originAtNiger => 'Origine au Niger';

  @override
  String get next => 'Suivant';

  @override
  String get finish => 'Terminer';

  @override
  String get connectionErrorRetry => 'Erreur de connexion. Veuillez réessayer.';

  @override
  String errorGeneric(String error) {
    return 'Erreur: $error';
  }

  @override
  String blockUserConfirmMessage(String name) {
    return 'Voulez-vous vraiment bloquer $name ? Vous ne recevrez plus de messages de sa part.';
  }

  @override
  String get blockingError => 'Erreur lors du blocage';

  @override
  String get infoLabel => 'Info';

  @override
  String get viewCart => 'Voir';

  @override
  String get selectImages => 'Sélectionner des images';

  @override
  String get selectPhotos => 'Sélectionner des photos';

  @override
  String addPhotosCount(int count) {
    return 'Ajouter des photos ($count/10)';
  }

  @override
  String photosLimitReached(int count) {
    return 'Limite de $count photos atteinte';
  }

  @override
  String selectionError(String error) {
    return 'Erreur lors de la sélection: $error';
  }

  @override
  String get addAtLeastOnePhoto => 'Veuillez ajouter au moins une photo';

  @override
  String get shareRecap => 'Partager le récapitulatif';

  @override
  String get okButton => 'OK';

  @override
  String get profilePhotoTitle => 'Photo de profil';

  @override
  String get profilePhotoOptional => 'Optionnel';

  @override
  String get yourLocation => 'Votre localisation';

  @override
  String get locationConnectHelp =>
      'Cela nous aide à vous connecter avec des membres proches de chez vous.';

  @override
  String get interestsTitle => 'Vos centres d\'intérêt';

  @override
  String get interestsHelp =>
      'Sélectionnez vos domaines d\'intérêt pour personnaliser votre expérience.';

  @override
  String get themeAppTitle => 'Thème de l\'application';

  @override
  String get themeCustomizeHelp =>
      'Personnalisez l\'apparence de l\'application selon vos préférences.';

  @override
  String get displayMode => 'Mode d\'affichage';

  @override
  String get lightMode => 'Clair';

  @override
  String get lightModeSubtitle => 'Thème lumineux';

  @override
  String get darkMode => 'Sombre';

  @override
  String get darkModeSubtitle => 'Thème sombre';

  @override
  String get autoMode => 'Automatique';

  @override
  String get autoModeSubtitle => 'Suit les paramètres du système';

  @override
  String get themeColorTitle => 'Couleur du thème';

  @override
  String get greenColor => 'Vert';

  @override
  String get orangeColor => 'Orange';

  @override
  String get takePhotoTitle => 'Prendre une photo';

  @override
  String get takePhotoSubtitle => 'Utiliser l\'appareil photo';

  @override
  String get galleryTitle => 'Choisir dans la galerie';

  @override
  String get gallerySubtitle => 'Sélectionner une image existante';

  @override
  String get deletePhotoTitle => 'Supprimer la photo';

  @override
  String get deletePhotoSubtitle => 'Utiliser les initiales par défaut';

  @override
  String get adminHistoryAudit => 'Historique Audit';

  @override
  String get adminGoBack => 'Retour';

  @override
  String get adminAll => 'Tous';

  @override
  String get adminPending => 'En attente';

  @override
  String get adminBoosted => 'Boostés';

  @override
  String get adminConfirmDelete => 'Confirmer la suppression';

  @override
  String get adminRevoke => 'Révoquer';

  @override
  String get adminTaxFees => 'Frais';

  @override
  String get adminTaxBoosts => 'Boosts';

  @override
  String get adminTaxes => 'Taxes';

  @override
  String get adminMedias => 'Medias';

  @override
  String get adminSystem => 'Système';

  @override
  String get adminAudio => 'Audio';

  @override
  String get adminFeeMinimum => 'Frais minimum (XOF)';

  @override
  String get adminFeeMaximum => 'Frais maximum (XOF)';

  @override
  String get adminCommissionMin => 'Commission min (XOF)';

  @override
  String get adminCommissionMax => 'Commission max (XOF)';

  @override
  String get adminVatRateUpdated => 'Taux de TVA mis à jour';

  @override
  String get adminBaseShareUrl => 'URL de base pour partage';

  @override
  String get adminAudioUpdated => 'Paramètres audio mis à jour';

  @override
  String get adminClear => 'Effacer';

  @override
  String get adminAboutToSend =>
      'Vous êtes sur le point d\'envoyer une notification à:';

  @override
  String get adminLoginWithGoogle => 'Sign in with Google';

  @override
  String get adminPasswordLabel => 'Mot de passe';

  @override
  String get adminLoginButton => 'Login';

  @override
  String adminProductsCount(int count) {
    return 'Produits ($count)';
  }

  @override
  String adminOrdersCount(int count) {
    return 'Commandes ($count)';
  }

  @override
  String adminDisputesCount(int count) {
    return 'Litiges ($count)';
  }

  @override
  String get adminDelete => 'Supprimer';

  @override
  String adminGroupsCount(int count) {
    return 'Groupes ($count)';
  }

  @override
  String get adminSearchUser => 'Rechercher un utilisateur...';

  @override
  String get adminLoading => 'Chargement...';

  @override
  String get adminNoUsersFound => 'Aucun utilisateur trouvé';

  @override
  String adminActivityOf(String name) {
    return 'Activité de $name';
  }

  @override
  String get adminSearchReports => 'Rechercher par nom, raison, ID...';

  @override
  String adminViewType(String type) {
    return 'Voir le $type';
  }

  @override
  String get adminRejectionHint =>
      'Ex: Signalement non fondé, contenu conforme aux règles...';

  @override
  String get adminResolutionHint =>
      'Ex: Avertissement envoyé, contenu modifié...';

  @override
  String get adminDeleteContentTitle => 'Supprimer le contenu';

  @override
  String get adminCreateEmbassyTitle => 'Créer une ambassade';

  @override
  String get adminWarnHost => 'Avertir l\'hôte';

  @override
  String adminGoalHint(String min, String max) {
    return 'Min: $min XOF - Max: $max XOF';
  }

  @override
  String get interestCulture => 'Culture';

  @override
  String get interestSport => 'Sport';

  @override
  String get interestBusiness => 'Business';

  @override
  String get interestEducation => 'Éducation';

  @override
  String get interestTechnology => 'Technologie';

  @override
  String get interestArts => 'Arts';

  @override
  String get interestHealth => 'Santé';

  @override
  String get interestPolitics => 'Politique';

  @override
  String get noBusinessFound => 'Aucune entreprise trouvée';

  @override
  String get beFirstToAddBusiness =>
      'Soyez le premier à ajouter votre entreprise !';

  @override
  String get filterByLocation => 'Filtrer par localisation';

  @override
  String get searchCountryLabel => 'Rechercher un pays';

  @override
  String get countryPlaceholder => 'Pays';

  @override
  String get cityPlaceholder => 'Ville';

  @override
  String get cityHintExample => 'Ex: Paris, Niamey, New York...';

  @override
  String get verifiedBadge => 'Vérifié';

  @override
  String get premiumBadge => 'Premium';

  @override
  String reviewsCountLabel(String rating, int count) {
    return '$rating ($count avis)';
  }

  @override
  String get contactSectionTitle => 'Contact';

  @override
  String get servicesSectionTitle => 'Services';

  @override
  String get viewsStatLabel => 'Vues';

  @override
  String get reviewsStatLabel => 'Avis';

  @override
  String get openingHoursTitle => 'Horaires d\'ouverture';

  @override
  String get dayMondayLabel => 'Lundi';

  @override
  String get dayTuesdayLabel => 'Mardi';

  @override
  String get dayWednesdayLabel => 'Mercredi';

  @override
  String get dayThursdayLabel => 'Jeudi';

  @override
  String get dayFridayLabel => 'Vendredi';

  @override
  String get daySaturdayLabel => 'Samedi';

  @override
  String get daySundayLabel => 'Dimanche';

  @override
  String get closedStatus => 'Fermé';

  @override
  String get currentOffersTitle => 'Offres en cours';

  @override
  String get noCurrentOffersMessage => 'Aucune offre en cours';

  @override
  String validUntilLabel(String date) {
    return 'Valable jusqu\'au $date';
  }

  @override
  String get newsSectionTitle => 'Actualités';

  @override
  String get addActionButton => 'Ajouter';

  @override
  String get noNewsMessage => 'Aucune actualité';

  @override
  String get newPostDialogTitle => 'Nouvelle publication';

  @override
  String get typeFieldLabel => 'Type';

  @override
  String get titleFieldPost => 'Titre';

  @override
  String get titleHintPost => 'Ex: Nouvelle collection disponible';

  @override
  String get contentFieldPost => 'Contenu';

  @override
  String get contentHintDescribe => 'Décrivez votre actualité...';

  @override
  String get publishAction => 'Publier';

  @override
  String get deleteDialogTitle => 'Supprimer';

  @override
  String get confirmDeletePostMessage =>
      'Voulez-vous vraiment supprimer cette publication ?';

  @override
  String get customerReviewsTitle => 'Avis clients';

  @override
  String get viewAllAction => 'Voir tout';

  @override
  String get noReviewsYetMessage => 'Aucun avis pour le moment';

  @override
  String get writeFirstReviewAction => 'Écrire le premier avis';

  @override
  String get writeReviewAction => 'Écrire un avis';

  @override
  String seeOtherReviewsLabel(int count) {
    return 'Voir les $count autres avis';
  }

  @override
  String get loginRequiredForReview =>
      'Vous devez être connecté pour laisser un avis';

  @override
  String get editAction => 'Modifier';

  @override
  String get boostAction => 'Booster';

  @override
  String get alreadyLeftReviewMessage => 'Vous avez déjà laissé un avis';

  @override
  String get reviewDeletedMessage => 'Avis supprimé';

  @override
  String get reportReviewTitle => 'Signaler cet avis';

  @override
  String get reportReasonField => 'Raison du signalement';

  @override
  String get reportReasonHintText => 'Pourquoi signalez-vous cet avis ?';

  @override
  String get reviewReportedMessage => 'Avis signalé';

  @override
  String get reportErrorOccurred => 'Erreur lors du signalement';

  @override
  String get deleteReviewDialogTitle => 'Supprimer l\'avis';

  @override
  String get confirmDeleteReviewMessage =>
      'Voulez-vous vraiment supprimer cet avis ? Cette action est irréversible.';

  @override
  String get reviewsScreenLabel => 'Avis';

  @override
  String get beFirstToShareExperience =>
      'Soyez le premier à partager votre expérience !';

  @override
  String get loadingErrorMessage => 'Erreur de chargement';

  @override
  String get retryButtonLabel => 'Réessayer';

  @override
  String nReviewsLabel(int count) {
    return '$count avis';
  }

  @override
  String get allCountriesOption => 'Tous les pays';

  @override
  String get chooseCountryDialogTitle => 'Choisir un pays';

  @override
  String get noProductAvailableMessage => 'Aucun produit disponible';

  @override
  String get beFirstToSellMessage => 'Soyez le premier à vendre !';

  @override
  String noSearchResultsForQuery(String query) {
    return 'Aucun résultat pour \"$query\"';
  }

  @override
  String get myOrdersScreenTitle => 'Mes commandes';

  @override
  String get myPurchasesTabLabel => 'Mes achats';

  @override
  String get mySalesTabLabel => 'Mes ventes';

  @override
  String get noOrdersYetMessage => 'Vous n\'avez pas encore passé de commande';

  @override
  String get noOrdersReceivedMessage =>
      'Vous n\'avez pas encore reçu de commande';

  @override
  String sellerWithNameLabel(String name) {
    return 'Vendeur: $name';
  }

  @override
  String buyerWithNameLabel(String name) {
    return 'Acheteur: $name';
  }

  @override
  String articlesCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$count article$_temp0';
  }

  @override
  String quantityShortLabel(int qty) {
    return 'Qté: $qty';
  }

  @override
  String payAmountLabel(String amount) {
    return 'Payer $amount';
  }

  @override
  String get confirmReceiptAction => 'Confirmer la réception';

  @override
  String get markAsShippedAction => 'Marquer comme expédié';

  @override
  String get trackingNumberDialogTitle => 'Numéro de suivi';

  @override
  String get trackingNumberHintOptional =>
      'Entrez le numéro de suivi (optionnel)';

  @override
  String get confirmAction => 'Confirmer';

  @override
  String get paymentSuccessfulMessage => 'Paiement effectué avec succès !';

  @override
  String get orderUpdateErrorOccurred =>
      'Erreur lors de la mise à jour de la commande';

  @override
  String paymentErrorWithDetails(String error) {
    return 'Erreur de paiement: $error';
  }

  @override
  String get deliveryConfirmedSuccess => 'Livraison confirmée';

  @override
  String availableQuantityInfo(int qty) {
    return '$qty disponible(s)';
  }

  @override
  String get descriptionSectionTitle => 'Description';

  @override
  String get sellerSectionTitle => 'Vendeur';

  @override
  String get loadingLabel => 'Chargement...';

  @override
  String get viewProfileAction => 'Voir le profil';

  @override
  String get contactSellerAction => 'Contacter le vendeur';

  @override
  String get connectingLabel => 'Connexion...';

  @override
  String get conversationCreationErrorMessage =>
      'Erreur lors de la création de la conversation';

  @override
  String get interestedInProductText =>
      'Bonjour, je suis intéressé par ce produit :';

  @override
  String get addToCartAction => 'Ajouter au panier';

  @override
  String get addedToCartSuccess => 'Ajouté au panier';

  @override
  String get viewAction => 'Voir';

  @override
  String get deleteProductDialogTitle => 'Supprimer le produit';

  @override
  String get confirmDeleteProductMessage =>
      'Êtes-vous sûr de vouloir supprimer ce produit ?';

  @override
  String get sellProductScreenTitle => 'Vendre un produit';

  @override
  String get editProductScreenTitle => 'Modifier le produit';

  @override
  String get addImageAction => 'Ajouter';

  @override
  String get photosSectionTitle => 'Photos';

  @override
  String get titleFieldProduct => 'Titre';

  @override
  String get titleHintProduct => 'Ex: iPhone 13 Pro Max';

  @override
  String get titleRequiredError => 'Entrez un titre';

  @override
  String get descriptionFieldProduct => 'Description';

  @override
  String get descriptionHintProduct => 'Décrivez votre produit...';

  @override
  String get priceFieldProduct => 'Prix';

  @override
  String get priceRequiredError => 'Entrez un prix';

  @override
  String get priceInvalidError => 'Prix invalide';

  @override
  String get quantityFieldProduct => 'Quantité';

  @override
  String get quantityRequiredError => 'Requis';

  @override
  String get quantityInvalidError => 'Invalide';

  @override
  String get currencyFieldProduct => 'Devise';

  @override
  String get categoryFieldProduct => 'Catégorie';

  @override
  String get conditionFieldProduct => 'État';

  @override
  String get countryFieldProduct => 'Pays';

  @override
  String get countryRequiredError => 'Sélectionnez un pays';

  @override
  String get cityAddressOptionalField => 'Ville/Adresse (optionnel)';

  @override
  String get cityAddressHintProduct => 'Ex: Niamey';

  @override
  String get taxSettingsSectionTitle => 'Paramètres de taxe';

  @override
  String get taxExemptCategoryMessage =>
      'Cette catégorie est exonérée de taxe par défaut';

  @override
  String defaultTaxForCategoryInfo(String rate) {
    return 'Taxe par défaut pour cette catégorie: $rate%';
  }

  @override
  String get customRateField => 'Taux personnalisé (%)';

  @override
  String get customRateHintExample => 'Ex: 15';

  @override
  String get priceTtcToggle => 'Prix TTC';

  @override
  String get priceTtcEnabledInfo => 'Le prix affiché inclut déjà la taxe';

  @override
  String get priceTtcDisabledInfo => 'La taxe sera ajoutée au prix affiché';

  @override
  String get previewSectionTitle => 'Aperçu';

  @override
  String get subtotalLine => 'Sous-total';

  @override
  String taxRateLine(String rate) {
    return 'Taxe ($rate%)';
  }

  @override
  String get totalLine => 'Total';

  @override
  String get publishProductAction => 'Publier';

  @override
  String get saveProductAction => 'Enregistrer';

  @override
  String get addImageRequiredError => 'Ajoutez au moins une image';

  @override
  String get userNotConnectedMessage => 'Utilisateur non connecté';

  @override
  String get productModifiedMessage => 'Produit modifié';

  @override
  String get productPublishedMessage => 'Produit publié';

  @override
  String get orderAction => 'Commander';

  @override
  String get convertedNote => '(converti)';

  @override
  String get securePurchaseDialogTitle => 'Achat sécurisé';

  @override
  String get purchaseSecurityNote =>
      'Les achats sur le marketplace nécessitent l\'installation de l\'application depuis Google Play Store.';

  @override
  String get publishedDateLabel => 'publié';

  @override
  String get unknownUserLabel => 'Inconnu';

  @override
  String get allCategoryFilter => 'Tout';

  @override
  String get replyAction => 'Répondre';

  @override
  String get readAction => 'Lu';

  @override
  String get taxAutomaticDesc => 'Taxe calculée selon la catégorie du produit';

  @override
  String get taxExemptDesc => 'Pas de taxe sur ce produit';

  @override
  String get taxStandardDesc => 'Taux standard de TVA';

  @override
  String get taxReducedDesc => 'Taux réduit pour produits essentiels';

  @override
  String get taxCustomDesc => 'Définir un taux personnalisé';

  @override
  String get adminSearchByAdminOrAction => 'Rechercher par admin ou action...';

  @override
  String get adminTransactions => 'Transactions';

  @override
  String adminAllCount(int count) {
    return 'Tous ($count)';
  }

  @override
  String adminPendingCount(int count) {
    return '$count en attente';
  }

  @override
  String adminBoostedCount(int count) {
    return 'Boostés ($count)';
  }

  @override
  String adminGroupType(String type) {
    return 'Groupe • $type';
  }

  @override
  String get adminEmailAddress => 'Adresse email';

  @override
  String get adminRoomConnectionError => 'Erreur lors de la connexion au salon';

  @override
  String get adminSend => 'Envoyer';

  @override
  String get adminHistory => 'Historique';

  @override
  String get adminTitle => 'Titre';

  @override
  String get adminMessage => 'Message';

  @override
  String get adminRejectHint =>
      'Ex: Signalement non fondé, contenu conforme aux règles...';

  @override
  String get adminProcessHint => 'Ex: Avertissement envoyé, contenu modifié...';

  @override
  String get adminChangeRoleTitle => 'Changer le rôle';

  @override
  String get adminRevokeAction => 'Révoquer';

  @override
  String get adminFees => 'Frais';

  @override
  String get adminBoosts => 'Boosts';

  @override
  String get adminMedia => 'Médias';

  @override
  String get adminMaxImagesPerUpload => 'Max images/upload';

  @override
  String get adminMaxCharsPerMessage => 'Caractères max par message';

  @override
  String get adminCustomAmountsHint => 'Ex: 1, 2, 5, 10, 20';

  @override
  String get adminNoActivityRecorded => 'Aucune activité enregistrée';

  @override
  String audioRoomCollectionHelper(int min, int max) {
    return 'Min: $min XOF - Max: $max XOF';
  }

  @override
  String get audioRoomStoriesLabel => 'Contes';

  @override
  String get audioRoomProverbsLabel => 'Proverbes';

  @override
  String get audioRoomHistoryLabel => 'Histoire';

  @override
  String get audioRoomCeremoniesLabel => 'Cérémonies';

  @override
  String get audioRoomLanguageLabelNav => 'Langue';

  @override
  String get audioRoomCraftLabel => 'Artisanat';

  @override
  String get audioRoomRecipesLabel => 'Recettes';

  @override
  String get audioRoomMedicineLabel => 'Médecine';

  @override
  String get businessBoostActivated => 'Boost activé avec succès !';

  @override
  String get businessBoostError => 'Erreur lors de l\'achat du boost';

  @override
  String get businessBoostTitle => 'Booster votre entreprise';

  @override
  String get businessTypeLabel => 'Type:';

  @override
  String get businessDurationLabel => 'Durée:';

  @override
  String get businessTotalLabel => 'Total:';

  @override
  String get businessPhotosLabel => 'Photos';

  @override
  String get businessCategoryLabel => 'Catégorie';

  @override
  String get businessNameRequired => 'Nom de l\'entreprise *';

  @override
  String get businessDescriptionRequired => 'Description *';

  @override
  String get businessContactLabel => 'Contact';

  @override
  String get businessLocationLabel => 'Localisation';

  @override
  String get businessCountryHint => 'Tapez le nom du pays';

  @override
  String get businessServicesOffered => 'Services proposés';

  @override
  String get businessAddService => 'Ajouter un service';

  @override
  String get businessCreateAction => 'Créer l\'entreprise';

  @override
  String get businessEditReview => 'Modifier';

  @override
  String get businessReportReview => 'Signaler';

  @override
  String get businessGiveRating => 'Veuillez donner une note';

  @override
  String get businessWriteReview => 'Veuillez écrire un avis';

  @override
  String get businessSubmissionError => 'Erreur lors de la soumission';

  @override
  String get businessTitleOptional => 'Titre (optionnel)';

  @override
  String get businessTitleHint => 'Ex: Excellent service';

  @override
  String get businessYourReview => 'Votre avis';

  @override
  String get businessShareExperience => 'Partagez votre expérience...';

  @override
  String get businessAddReview => 'Ajouter';

  @override
  String get callPermissionRequired => 'Permission requise';

  @override
  String get callSettings => 'Réglages';

  @override
  String get callEnd => 'Terminer';

  @override
  String eventImageSelectionErrorMsg(String error) {
    return 'Erreur lors de la sélection des images: $error';
  }

  @override
  String get eventPosterLimitReached => 'Limite de 5 affiches atteinte';

  @override
  String eventSelectionError(String error) {
    return 'Erreur lors de la sélection: $error';
  }

  @override
  String get eventPhotoLimitReached => 'Limite de 10 photos atteinte';

  @override
  String get eventAddAtLeastOnePhoto => 'Veuillez ajouter au moins une photo';

  @override
  String get eventRecapShareTooltip => 'Partager le récapitulatif';

  @override
  String eventPhotosAddCount(int count) {
    return 'Ajouter des photos ($count/10)';
  }

  @override
  String get groupRequestSentSuccess => 'Demande envoyée avec succès';

  @override
  String get groupPromoteAdminTitle => 'Promouvoir Admin';

  @override
  String get groupDemoteAdminTitle => 'Retirer Admin';

  @override
  String get groupConfirmTitle => 'Confirmer';

  @override
  String get groupMembershipRequestsTitle => 'Demandes d\'adhésion';

  @override
  String get groupApprovedRequest => 'Demande approuvée';

  @override
  String get groupDeclinedRequest => 'Demande refusée';

  @override
  String get groupRejectAction => 'Refuser';

  @override
  String get groupApproveAction => 'Approuver';

  @override
  String get groupAllFilter => 'Tous';

  @override
  String mediaGalleryPhotos(int count) {
    return 'Photos ($count)';
  }

  @override
  String mediaGalleryFiles(int count) {
    return 'Fichiers ($count)';
  }

  @override
  String get mediaCaptionHint => 'Ajouter une légende...';

  @override
  String messageConversationError(String error) {
    return 'Erreur: $error';
  }

  @override
  String get messageInfoLabel => 'Info';

  @override
  String get notificationRemindLater => 'Me rappeler plus tard';

  @override
  String get notificationIn1HourOption => 'Dans 1 heure';

  @override
  String get notificationScheduled => 'Rappel programmé';

  @override
  String get notificationTomorrowOption => 'Demain matin (9h)';

  @override
  String get podcastDisabledOption => 'Désactivé';

  @override
  String get podcastEndOfEpisodeOption => 'Fin de l\'épisode';

  @override
  String get podcastSleepEndActivated => 'Arrêt à la fin de l\'épisode activé';

  @override
  String get podcastSleepEnded => 'Minuterie de sommeil terminée';

  @override
  String podcastTimerSet(int minutes) {
    return 'Minuterie: $minutes minutes';
  }

  @override
  String get podcastNotFoundError => 'Podcast non trouvé';

  @override
  String get podcastAddEpisode => 'Ajouter';

  @override
  String podcastErrorPrefix(String error) {
    return 'Erreur: $error';
  }

  @override
  String get podcastAddChapterTitle => 'Ajouter un chapitre';

  @override
  String get podcastChapterTitleLabel => 'Titre du chapitre';

  @override
  String get podcastMinutesLabel => 'Minutes';

  @override
  String get podcastSecondsLabel => 'Secondes';

  @override
  String get podcastSelectAudio => 'Veuillez sélectionner un fichier audio';

  @override
  String podcastEpisodeError(String error) {
    return 'Erreur: $error';
  }

  @override
  String get podcastEpisodeTitleRequired => 'Titre de l\'épisode *';

  @override
  String get podcastDescriptionNotes => 'Description / Notes';

  @override
  String get podcastSubscribersOnlyLabel => 'Réservé aux abonnés payants';

  @override
  String get podcastDownloadedTooltip => 'Téléchargé';

  @override
  String get podcastDownloadTooltip => 'Télécharger';

  @override
  String get podcastDeleteDownloadTitle => 'Supprimer le téléchargement';

  @override
  String get podcastDownloadDeleted => 'Téléchargement supprimé';

  @override
  String get podcastSelectOrCreateNew =>
      'Sélectionnez un podcast ou créez-en un nouveau';

  @override
  String get podcastRecordingSoon =>
      'L\'enregistrement du salon sera bientôt disponible';

  @override
  String get podcastAudioMissing => 'Fichier audio introuvable';

  @override
  String get podcastPublishingError => 'Erreur lors de la publication';

  @override
  String get podcastEpisodeTitleInput => 'Titre de l\'épisode';

  @override
  String get podcastEpisodeDescInput => 'Description de l\'épisode (optionnel)';

  @override
  String get podcastPublishAction => 'Publier';

  @override
  String get podcastCreateAction => 'Créer un podcast';

  @override
  String profileCodeSentTo(String phone) {
    return 'Code envoyé au $phone';
  }

  @override
  String get profileTravelModeTitle => 'Mode Voyage';

  @override
  String get reportMyReportsTitle => 'Mes signalements';

  @override
  String get reportDescribeProblem => 'Décrivez le problème...';

  @override
  String get reportSendAction => 'Envoyer le signalement';

  @override
  String get settingsRenameDeviceTitle => 'Renommer l\'appareil';

  @override
  String get settingsDeviceNameLabel => 'Nom de l\'appareil';

  @override
  String get settingsRename => 'Renommer';

  @override
  String get settingsRevokeDeviceTitle => 'Révoquer l\'appareil ?';

  @override
  String get settingsRevokeConfirm => 'Révoquer';

  @override
  String get settingsConnectedDevicesTitle => 'Appareils connectés';

  @override
  String get settingsDeleteBackupTitle => 'Supprimer la sauvegarde ?';

  @override
  String get settingsKeyBackupTitle => 'Sauvegarde des clés';

  @override
  String get settingsPassphrase => 'Passphrase';

  @override
  String get settingsRestoreKeysAction => 'Restaurer les clés';

  @override
  String get settingsGenerateSecurePassphrase =>
      'Générer une passphrase sécurisée';

  @override
  String get settingsPassphraseMinChars => 'Minimum 8 caractères';

  @override
  String get settingsConfirmPassphraseLabel => 'Confirmer la passphrase';

  @override
  String get settingsCreateBackupAction => 'Créer la sauvegarde';

  @override
  String get settingsTermsTitle => 'Conditions d\'utilisation';

  @override
  String get settingsBugDescLabel => 'Description du bug';

  @override
  String get settingsBugDescHint => 'Décrivez le problème rencontré...';

  @override
  String get settingsCurrencySearch => 'Rechercher une devise...';

  @override
  String get settingsOk => 'OK';

  @override
  String get transferAddRecipientTitle => 'Ajouter un bénéficiaire';

  @override
  String transferErrorPrefix(String error) {
    return 'Erreur: $error';
  }

  @override
  String get transferNewAction => 'Nouveau';

  @override
  String get transferAddManuallyAction => 'Ajouter manuellement';

  @override
  String get transferChooseRecipientTitle => 'Choisir un bénéficiaire';

  @override
  String get transferAddRecipientHint => 'Ajouter un bénéficiaire';

  @override
  String get transferSendMoneyAction => 'Envoyer de l\'argent';

  @override
  String get transferEditAction => 'Modifier';

  @override
  String get transferDeleteTitle => 'Supprimer ?';

  @override
  String transferDeleteMsg(String name) {
    return 'Supprimer $name ?';
  }

  @override
  String get transferDetailsTitle => 'Détails du transfert';

  @override
  String get transferAmountSentLine => 'Montant envoyé';

  @override
  String get transferFeesLine => 'Frais';

  @override
  String get transferExchangeRateLine => 'Taux de change';

  @override
  String get transferCopiedToClipboard => 'Copié dans le presse-papiers';

  @override
  String get transferRetryAction => 'Réessayer le transfert';

  @override
  String get transferContactSupportAction => 'Contacter le support';

  @override
  String get transferStatusPending => 'En attente';

  @override
  String get transferStatusDebiting => 'Débit en cours';

  @override
  String get transferStatusProcessing => 'En cours';

  @override
  String get transferStatusSending => 'Envoi en cours';

  @override
  String get transferStatusCompleted => 'Terminé';

  @override
  String get transferStatusFailed => 'Échoué';

  @override
  String get transferStatusRefunding => 'Remboursement en cours';

  @override
  String get transferStatusRefunded => 'Remboursé';

  @override
  String get transferStatusCancelled => 'Annulé';

  @override
  String get transferStatusPendingDesc =>
      'Votre transfert est en attente de traitement.';

  @override
  String get transferStatusDebitingDesc =>
      'Le prélèvement est en cours sur votre compte.';

  @override
  String get transferStatusProcessingDesc =>
      'Votre transfert est en cours de traitement.';

  @override
  String get transferStatusSendingDesc =>
      'L\'argent est en cours d\'envoi au bénéficiaire.';

  @override
  String get transferStatusCompletedDesc =>
      'Votre transfert a été effectué avec succès !';

  @override
  String get transferStatusFailedDesc =>
      'Le transfert a échoué. Veuillez réessayer.';

  @override
  String get transferStatusRefundingDesc =>
      'Le remboursement est en cours de traitement.';

  @override
  String get transferStatusRefundedDesc =>
      'Le montant a été remboursé sur votre compte.';

  @override
  String get transferStatusCancelledDesc => 'Ce transfert a été annulé.';

  @override
  String get transferEmailOption => 'Email';

  @override
  String get transferLiveChat => 'Chat en direct';

  @override
  String get transferAvailable247 => 'Disponible 24/7';

  @override
  String get transferChatUnavailable => 'Chat non disponible pour le moment';

  @override
  String get transferPhoneOption => 'Téléphone';

  @override
  String get transferHistoryTitle => 'Historique des transferts';

  @override
  String get transferSendActionLabel => 'Envoyer';

  @override
  String get transferActiveFiltersLabel => 'Filtres actifs: ';

  @override
  String get transferClearAllAction => 'Effacer tout';

  @override
  String get transferChoosePeriodAction => 'Choisir une période';

  @override
  String get transferApplyFiltersAction => 'Appliquer les filtres';

  @override
  String get widgetRetryAction => 'Réessayer';

  @override
  String get widgetCameraOption => 'Caméra';

  @override
  String get widgetGalleryOption => 'Galerie';

  @override
  String get adminDashboardTitle => 'Tableau de Bord';

  @override
  String get adminDashboardWelcome =>
      'Bienvenue dans le panneau d\'administration DiaspoNiger';

  @override
  String get adminGeneralStats => 'Statistiques Générales';

  @override
  String get adminActiveSessions => 'Sessions Actives';

  @override
  String get adminCommerceMarketplace => 'Commerce & Marketplace';

  @override
  String get adminProducts => 'Produits';

  @override
  String get adminQuickActions => 'Actions Rapides';

  @override
  String get adminNoLiveRooms => 'Aucun salon en direct';

  @override
  String get adminNoLiveRoomsDesc =>
      'Il n\'y a actuellement aucun salon audio en cours.';

  @override
  String get adminLiveAudioRooms => 'Salons Audio Live';

  @override
  String get adminLiveAudioRoomsDesc =>
      'Surveillez et modérez les salons audio en direct';

  @override
  String get adminEmbassyManagement => 'Gestion des Ambassades';

  @override
  String get adminEmbassyManagementDesc =>
      'Créez et gérez les comptes ambassades';

  @override
  String get adminLoadingData => 'Chargement des données...';

  @override
  String get adminErrorOccurred => 'Une erreur est survenue';

  @override
  String get adminActive => 'actif';

  @override
  String get adminPaid => 'Payant';

  @override
  String get adminVideo => 'Vidéo';

  @override
  String get adminHost => 'Hôte';

  @override
  String get adminModerationDialogContent =>
      'Vous allez rejoindre ce salon en mode invisible (ghost mode). Les participants ne pourront pas vous voir.\n\nVous pourrez:\n- Écouter les conversations\n- Voir les vidéos (si activées)\n- Avertir l\'hôte\n- Fermer le salon si nécessaire';

  @override
  String get eventPostersOptional => 'Affiches de l\'événement (optionnel)';

  @override
  String get eventPostersLabel => 'Affiches de l\'événement';

  @override
  String get eventPostersUpTo5 =>
      'Ajoutez jusqu\'à 5 affiches pour votre événement';

  @override
  String eventManagePosters(int count) {
    return 'Gérer les affiches ($count/5)';
  }

  @override
  String get eventCurrentPosters => 'Affiches actuelles';

  @override
  String get eventNewPosters => 'Nouvelles affiches';

  @override
  String get eventAddImages => 'Ajouter des images';

  @override
  String eventAddPosterCount(int count) {
    return 'Ajouter ($count/5)';
  }

  @override
  String get eventRecapTitle => 'Récapitulatif';

  @override
  String get eventCreateRecap => 'Créer un récapitulatif';

  @override
  String get eventEditRecap => 'Modifier le récapitulatif';

  @override
  String get eventRecapInfo =>
      'Partagez les meilleurs moments de votre événement avec des photos et une description.';

  @override
  String get eventRecapPhotosLabel => 'Photos du récapitulatif';

  @override
  String eventRecapUpTo10Photos(int count) {
    return 'Ajoutez jusqu\'à 10 photos ($count/10)';
  }

  @override
  String get eventExistingPhotos => 'Photos existantes';

  @override
  String get eventNewPhotos => 'Nouvelles photos';

  @override
  String get eventRecapDescriptionHint =>
      'Racontez comment s\'est passé l\'événement...';

  @override
  String get eventRecapDescriptionRequired =>
      'Veuillez ajouter une description';

  @override
  String get eventRecapDescriptionTooShort =>
      'La description doit faire au moins 20 caractères';

  @override
  String get eventRecapUpdateButton => 'Mettre à jour';

  @override
  String get eventRecapCreateButton => 'Créer le récapitulatif';

  @override
  String get eventRecapUpdatedSuccess => 'Récapitulatif mis à jour avec succès';

  @override
  String get eventRecapCreatedSuccess => 'Récapitulatif créé avec succès';

  @override
  String eventRecapError(String error) {
    return 'Erreur: $error';
  }

  @override
  String get noConnection => 'Pas de connexion';

  @override
  String get weakConnection => 'Connexion faible';

  @override
  String get unstableConnection => 'Connexion instable';

  @override
  String get goodConnection => 'Bonne connexion';

  @override
  String get noInternetConnection => 'Pas de connexion internet';

  @override
  String get poorConnectionLimitedFunctions =>
      'Connexion faible - certaines fonctions peuvent être limitées';

  @override
  String get chooseAnImage => 'Choisir une image';

  @override
  String get chooseImages => 'Choisir des images';

  @override
  String get permissionDeniedGeneric => 'Permission refusée';

  @override
  String maximumImages(int count) {
    return 'Maximum $count images';
  }

  @override
  String get callPermissionMicrophone => 'microphone';

  @override
  String get callPermissionCamera => 'caméra';

  @override
  String callPermissionDenied(String permissions) {
    return 'L\'accès au $permissions est nécessaire pour passer des appels. Veuillez l\'autoriser dans les paramètres.';
  }

  @override
  String get callEndConfirmMessage =>
      'Voulez-vous vraiment terminer cet appel ?';

  @override
  String get callEndButton => 'Terminer';

  @override
  String get callDeclinedStatus => 'Appel refusé';

  @override
  String get callNoAnswer => 'Pas de réponse';

  @override
  String get callEndedStatus => 'Appel terminé';

  @override
  String get callCameraInitializing => 'Initialisation de la caméra...';

  @override
  String get callCameraDisabled => 'Caméra désactivée';

  @override
  String get callReconnectingStatus => 'Reconnexion en cours...';

  @override
  String get callPleaseWait => 'Veuillez patienter';

  @override
  String get callReenableButton => 'Réactiver';

  @override
  String get callConnectionQuality => 'Qualité de connexion';

  @override
  String get callLatency => 'Latence';

  @override
  String get callPacketLoss => 'Perte de paquets';

  @override
  String get callJitter => 'Gigue';

  @override
  String get callBandwidth => 'Bande passante';

  @override
  String get callAudioCodec => 'Codec audio';

  @override
  String get callVideoCodec => 'Codec vidéo';

  @override
  String get callVideoLabel => 'Vidéo';

  @override
  String get callCloseButton => 'Fermer';

  @override
  String get callPermissionAnd => 'et';

  @override
  String get businessBoostVisibilityTitle => 'Augmentez votre visibilité';

  @override
  String get businessBoostVisibilityDesc =>
      'Apparaissez en premier dans les résultats de recherche et attirez plus de clients.';

  @override
  String get businessBoostTypeLabel => 'Type de boost';

  @override
  String get businessBoostRecommended => 'Recommandé';

  @override
  String get marketplaceTaxSettings => 'Paramètres de taxe';

  @override
  String get marketplacePreview => 'Aperçu';

  @override
  String get marketplaceChooseCountry => 'Choisir un pays';

  @override
  String get marketplacePhotos => 'Photos';

  @override
  String get marketplaceAddPhoto => 'Ajouter';

  @override
  String get marketplaceTitleRequired => 'Entrez un titre';

  @override
  String get marketplaceDescriptionRequired => 'Entrez une description';

  @override
  String get marketplaceSelectCountry => 'Sélectionnez un pays';

  @override
  String get marketplaceTaxIncluded => 'Le prix affiché inclut déjà la taxe';

  @override
  String get marketplaceTaxAdded => 'La taxe sera ajoutée au prix affiché';

  @override
  String marketplaceErrorWithMessage(String error) {
    return 'Erreur: $error';
  }

  @override
  String marketplaceNoResultFor(String query) {
    return 'Aucun résultat pour \"$query\"';
  }

  @override
  String get marketplaceNoProductAvailable => 'Aucun produit disponible';

  @override
  String get marketplaceBeFirstToSell => 'Soyez le premier à vendre !';

  @override
  String get marketplaceTodayLabel => 'Aujourd\'hui';

  @override
  String get marketplaceYesterdayLabel => 'Hier';

  @override
  String marketplaceDaysAgoLabel(int days) {
    return 'Il y a $days jours';
  }

  @override
  String marketplaceWeeksAgoLabel(int weeks) {
    return 'Il y a $weeks semaine(s)';
  }

  @override
  String marketplaceMonthsAgoLabel(int months) {
    return 'Il y a $months mois';
  }

  @override
  String get marketplaceUserNotConnected => 'Utilisateur non connecté';

  @override
  String get marketplaceAllCountries => 'Tous les pays';

  @override
  String get mapSimpleTestTitle => 'Test Carte Simple';

  @override
  String get businessBoostStartingFrom => 'À partir de';

  @override
  String get businessBoostDurationLabel => 'Durée';

  @override
  String get businessBoostSavings25 => '~25% économisé';

  @override
  String get businessBoostSavings42 => '~42% économisé';

  @override
  String get businessBoostBuyFor => 'Acheter pour';

  @override
  String get businessBoostNote =>
      'Note: Le boost sera actif immédiatement après le paiement.';

  @override
  String get businessNameRequiredError => 'Le nom est requis';

  @override
  String get businessDescriptionRequiredError => 'La description est requise';

  @override
  String get businessSelectCountry => 'Sélectionner un pays';

  @override
  String get businessSearchCountryPlaceholder => 'Rechercher un pays';

  @override
  String get businessTypeCountryName => 'Tapez le nom du pays';

  @override
  String get reviewHelpful => 'Utile';

  @override
  String reviewHelpfulCount(int count) {
    return 'Utile ($count)';
  }

  @override
  String get reviewPleaseWriteReview => 'Veuillez écrire un avis';

  @override
  String get reviewModifiedSuccess => 'Avis modifié avec succès';

  @override
  String get reviewPublishedSuccess => 'Avis publié avec succès';

  @override
  String get reviewWriteTitle => 'Écrire un avis';

  @override
  String get reviewModifyTitle => 'Modifier votre avis';

  @override
  String get reviewYourRating => 'Votre note';

  @override
  String get reviewPublish => 'Publier';

  @override
  String reviewPhotosCount(int current, int max) {
    return 'Photos ($current/$max)';
  }

  @override
  String get activateCamera => 'Activer';

  @override
  String get deactivateCamera => 'Désactiver';

  @override
  String get minAmountIs => 'Le montant minimum est';

  @override
  String get maxAmountIs => 'Le montant maximum est';

  @override
  String get heritageLanguageType => 'Langue';

  @override
  String get groupNameExample => 'Ex: Entrepreneurs Niger';

  @override
  String get groupNameIsRequired => 'Le nom est requis';

  @override
  String get groupNameMinLength => 'Le nom doit contenir au moins 3 caractères';

  @override
  String get descriptionIsRequired => 'La description est requise';

  @override
  String get hostCountryHint => 'Le pays où se trouve la communauté du groupe';

  @override
  String get none => 'Aucun';

  @override
  String get regionOriginHint =>
      'Pour regrouper les membres par région d\'origine';

  @override
  String get detailedLocationExample => 'Ex: Paris 18e, Île-de-France';

  @override
  String get tagsExample => 'Ex: business, networking, tech';

  @override
  String get tagsSeparatedByCommas => 'Séparez les tags par des virgules';

  @override
  String get privateGroupLabel => 'Groupe privé';

  @override
  String get membersMustBeApproved => 'Les membres doivent être approuvés';

  @override
  String get modifyTheGroup => 'Modifier le groupe';

  @override
  String get noPendingRequests => 'Aucune demande en attente';

  @override
  String get membershipRequestsTitle => 'Demandes d\'adhésion';

  @override
  String get requestApprovedSuccess => 'Demande approuvée';

  @override
  String get requestRejectedSuccess => 'Demande refusée';

  @override
  String get rejectAction => 'Refuser';

  @override
  String get approveAction => 'Approuver';

  @override
  String get promoteToAdmin => 'Promouvoir Admin';

  @override
  String get removeFromGroup => 'Retirer du groupe';

  @override
  String get confirmRemoveMember =>
      'Voulez-vous vraiment retirer ce membre du groupe ?';

  @override
  String get memberPromotedAdmin => 'Membre promu admin';

  @override
  String get promoteError => 'Erreur lors de la promotion';

  @override
  String get memberDemotedAdmin => 'Admin rétrogradé';

  @override
  String get demoteError => 'Erreur lors de la rétrogradation';

  @override
  String get memberRemovedFromGroup => 'Membre retiré du groupe';

  @override
  String get removalError => 'Erreur lors de la suppression';

  @override
  String get confirmTitle => 'Confirmer';

  @override
  String viewAllMembers(int count) {
    return 'Voir tous les $count membres';
  }

  @override
  String get allFeminine => 'Toutes';

  @override
  String get originRegionLabel => 'Région d\'origine';

  @override
  String get toutes => 'Toutes';

  @override
  String get groupCreationSuccess => 'Groupe créé avec succès';

  @override
  String get requester => 'Demandeur';

  @override
  String get podcastsAddCover => 'Ajouter une couverture';

  @override
  String get podcastsCategoryRequired => 'Catégorie *';

  @override
  String get podcastsLanguageRequired => 'Langue *';

  @override
  String get podcastsPublicationFrequency => 'Fréquence de publication';

  @override
  String get podcastsAddTag => 'Ajouter un tag';

  @override
  String get podcastsNewEpisodeTitle => 'Nouvel épisode';

  @override
  String get podcastsAddChapterDialog => 'Ajouter un chapitre';

  @override
  String get podcastsChapterTitleLabel => 'Titre du chapitre';

  @override
  String get podcastsMinutes => 'Minutes';

  @override
  String get podcastsSeconds => 'Secondes';

  @override
  String get podcastsAdd => 'Ajouter';

  @override
  String get podcastsSelectAudioFile =>
      'Veuillez sélectionner un fichier audio';

  @override
  String get podcastsEpisodePublished => 'Épisode publié avec succès !';

  @override
  String get podcastsAudioFileTitle => 'Sélectionner un fichier audio';

  @override
  String get podcastsFileSelected => 'Fichier sélectionné';

  @override
  String get podcastsNoChaptersAdded => 'Aucun chapitre ajouté';

  @override
  String podcastsErrorNotFound(String error) {
    return 'Erreur: $error';
  }

  @override
  String get podcastsNotFound => 'Podcast non trouvé';

  @override
  String get podcastsEpisodeNotFound => 'Épisode non trouvé';

  @override
  String podcastsBy(String name) {
    return 'Par $name';
  }

  @override
  String get podcastsAbout => 'À propos';

  @override
  String get podcastsNoEpisodes => 'Aucun épisode disponible';

  @override
  String get podcastsDescriptionNotes => 'Description / Notes';

  @override
  String get podcastsLikeAction => 'J\'aime';

  @override
  String get podcastsDownloadInProgress => 'Téléchargement en cours';

  @override
  String get podcastsSleepTimerTitle => 'Minuterie de sommeil';

  @override
  String get podcastsSleepTimerDisabled => 'Désactivé';

  @override
  String get podcastsSleepTimer15 => '15 minutes';

  @override
  String get podcastsSleepTimer30 => '30 minutes';

  @override
  String get podcastsSleepTimer45 => '45 minutes';

  @override
  String get podcastsSleepTimer60 => '1 heure';

  @override
  String get podcastsSleepTimerEnd => 'Fin de l\'épisode';

  @override
  String get podcastsSleepTimerActivated =>
      'Arrêt à la fin de l\'épisode activé';

  @override
  String get podcastsSleepTimerFinished => 'Minuterie de sommeil terminée';

  @override
  String podcastsSleepTimerSet(int minutes) {
    return 'Minuterie: $minutes minutes';
  }

  @override
  String podcastsEpisodeNumber(int number) {
    return 'Épisode $number';
  }

  @override
  String get podcastsLiveLabel => 'Live';

  @override
  String get podcastsDownloaded => 'Téléchargé';

  @override
  String get podcastsAvailableOffline => 'Disponible hors-ligne';

  @override
  String get podcastsDeleteDownload => 'Supprimer le téléchargement';

  @override
  String get podcastsDownloadDeleted => 'Téléchargement supprimé';

  @override
  String get podcastsSaveAsPodcast => 'Sauver comme Podcast';

  @override
  String get podcastsSaveAsPodcastDesc =>
      'Publiez l\'enregistrement de ce salon comme épisode de podcast';

  @override
  String get podcastsSelectPodcast => 'Sélectionner un podcast';

  @override
  String get podcastsSelectOrCreate =>
      'Sélectionnez un podcast ou créez-en un nouveau';

  @override
  String get podcastsRecordingSoon =>
      'L\'enregistrement du salon sera bientôt disponible';

  @override
  String get podcastsAudioFileNotFound => 'Fichier audio introuvable';

  @override
  String get podcastsEpisodeTitleInput => 'Titre de l\'épisode';

  @override
  String get podcastsEpisodeDescriptionInput =>
      'Description de l\'épisode (optionnel)';

  @override
  String get podcastsSourceRoom => 'Salon source';

  @override
  String get podcastsPublish => 'Publier';

  @override
  String get podcastsNoPodcastsYet => 'Vous n\'avez pas encore de podcast';

  @override
  String get podcastsCreateFirstPodcast =>
      'Créez votre premier podcast pour pouvoir y ajouter des épisodes';

  @override
  String get podcastsCreateNewPodcast => 'Créer un nouveau podcast';

  @override
  String get podcastsStartSeries => 'Commencez votre série de podcasts';

  @override
  String get notificationReplySent => 'Message envoyé';

  @override
  String get notificationReplyConfirmation => 'Votre réponse a été envoyée';

  @override
  String get notificationPendingMessage => 'Message en attente';

  @override
  String get notificationPendingReply =>
      'Votre réponse sera envoyée dès que possible';

  @override
  String get notificationIncomingVideoCall => 'Appel vidéo entrant...';

  @override
  String get notificationIncomingAudioCall => 'Appel vocal entrant...';

  @override
  String get notificationAnswerAction => 'Répondre';

  @override
  String get notificationDeclineAction => 'Refuser';

  @override
  String get notificationReplyAction => 'Répondre';

  @override
  String get notificationMarkReadAction => 'Marquer comme lu';

  @override
  String get notificationSendButton => 'Envoyer';

  @override
  String get notificationTypePlaceholder => 'Tapez votre réponse...';

  @override
  String get notificationCallsChannel => 'Appels';

  @override
  String get notificationCallsDescription =>
      'Notifications pour les appels entrants';

  @override
  String get notificationUnknownCaller => 'Inconnu';

  @override
  String get taxExemptBySeller => 'Exonéré par le vendeur';

  @override
  String get sharedMedia => 'Médias partagés';

  @override
  String get thisWeek => 'Cette semaine';

  @override
  String get lastWeek => 'La semaine dernière';

  @override
  String get thisMonth => 'Ce mois-ci';

  @override
  String get sharedPhotosWillAppear => 'Les photos partagées apparaîtront ici';

  @override
  String get sharedFilesWillAppear => 'Les fichiers partagés apparaîtront ici';

  @override
  String get otherMembers => 'Autres membres';

  @override
  String get imagePreview => 'Aperçu de l\'image';

  @override
  String get videoPreview => 'Aperçu de la vidéo';

  @override
  String get documentPreview => 'Aperçu du document';

  @override
  String get conversationBackground => 'Fond de conversation';

  @override
  String get defaultBackground => 'Fond par défaut';

  @override
  String get colors => 'Couleurs';

  @override
  String get defaultTheme => 'Thème par défaut';

  @override
  String get imageSelected => 'Image sélectionnée';

  @override
  String get chooseImage => 'Choisir une image';

  @override
  String errorImageSelection(String error) {
    return 'Erreur lors de la sélection de l\'image: $error';
  }

  @override
  String errorApplication(String error) {
    return 'Erreur lors de l\'application: $error';
  }

  @override
  String get receivedMessage => 'Message reçu';

  @override
  String get sentMessage => 'Message envoyé';

  @override
  String get messageDeleted => 'Message supprimé';

  @override
  String get photo => 'Photo';

  @override
  String get video => 'Vidéo';

  @override
  String get audio => 'Audio';

  @override
  String get document => 'Document';

  @override
  String get systemMessage => 'Message système';

  @override
  String get call => 'Appel';

  @override
  String get pending => 'En attente';

  @override
  String get sharedLocation => 'Localisation partagée';

  @override
  String get embassyTemporarilyClosed => 'Temporairement fermé';

  @override
  String get embassyOfficialVerified => 'Compte Officiel Vérifié';

  @override
  String get embassyComingSoon => 'Bientôt disponible';

  @override
  String get embassyConsularServices => 'Services Consulaires';

  @override
  String get embassyOpeningHours => 'Horaires d\'ouverture';

  @override
  String get embassyJurisdiction => 'Juridiction';

  @override
  String get embassyJurisdictionDescription =>
      'Cette ambassade dessert les ressortissants se trouvant dans: ';

  @override
  String get embassyNoActivities => 'Aucune activité prévue pour le moment.';

  @override
  String get embassyNoNews => 'Aucune actualité disponible.';

  @override
  String get embassyInfoTab => 'Infos';

  @override
  String get embassyActivitiesTab => 'Activités';

  @override
  String get embassyNewsTab => 'Actualités';

  @override
  String get embassyFormPrefilledNotice =>
      'Formulaire pré-rempli à partir de votre profil. Veuillez vérifier et compléter les informations.';

  @override
  String get embassyRequestType => 'Type de demande *';

  @override
  String get embassyPersonalInfo => 'Informations personnelles';

  @override
  String get embassyFullName => 'Nom complet *';

  @override
  String get embassyDateOfBirth => 'Date de naissance *';

  @override
  String get embassyDateFormat => 'JJ/MM/AAAA';

  @override
  String get embassyPlaceOfBirth => 'Lieu de naissance';

  @override
  String get embassyNationality => 'Nationalité';

  @override
  String get embassyNigerien => 'Nigérienne';

  @override
  String get embassyCurrentAddress => 'Adresse actuelle *';

  @override
  String get embassyContactSection => 'Contact';

  @override
  String get embassyPhone => 'Téléphone *';

  @override
  String get embassyEmailField => 'Email';

  @override
  String get embassyPassportInfo => 'Informations du passeport';

  @override
  String get embassyPassportNumber => 'N° de passeport';

  @override
  String get embassyPassportExpiry => 'Date d\'expiration';

  @override
  String get embassyNotesSection => 'Remarques / Informations complémentaires';

  @override
  String get embassyNotesPlaceholder =>
      'Ajoutez des détails supplémentaires si nécessaire...';

  @override
  String embassyCharacterCount(int count) {
    return '$count caractères';
  }

  @override
  String get embassyWarningMessage =>
      'Vous devrez peut-être vous rendre à l\'ambassade avec les documents originaux. Conservez votre numéro de suivi.';

  @override
  String get embassySending => 'Envoi...';

  @override
  String get embassySubmitRequest => 'Soumettre la demande';

  @override
  String get embassyFieldRequired => 'Champ obligatoire';

  @override
  String get embassyFieldRequiredShort => 'Obligatoire';

  @override
  String get embassyUserNotConnected => 'Utilisateur non connecté';

  @override
  String embassyErrorPrefix(String error) {
    return 'Erreur: $error';
  }

  @override
  String get embassyPassportRenewal => 'Renouvellement de passeport';

  @override
  String get embassyPassportNewRequest => 'Nouvelle demande de passeport';

  @override
  String get embassyVisaApplication => 'Demande de visa';

  @override
  String get embassyBirthCertificate => 'Acte de naissance';

  @override
  String get embassyMarriageCertificate => 'Acte de mariage';

  @override
  String get embassyDeathCertificate => 'Acte de décès';

  @override
  String get embassyConsularId => 'Carte consulaire';

  @override
  String get embassyLegalDocument => 'Document légal';

  @override
  String get embassyLaissezPasser => 'Laissez-passer';

  @override
  String get embassyPowerOfAttorney => 'Procuration';

  @override
  String get embassyInscription => 'Inscription consulaire';

  @override
  String get embassyOtherRequest => 'Autre demande';

  @override
  String get embassyPassportRenewalDesc =>
      'Renouvellement d\'un passeport existant arrivant à expiration.';

  @override
  String get embassyPassportNewRequestDesc =>
      'Première demande de passeport ou remplacement d\'un passeport perdu/volé.';

  @override
  String get embassyVisaApplicationDesc =>
      'Demande de visa pour les ressortissants étrangers.';

  @override
  String get embassyBirthCertificateDesc =>
      'Copie ou extrait d\'acte de naissance.';

  @override
  String get embassyMarriageCertificateDesc =>
      'Copie ou extrait d\'acte de mariage.';

  @override
  String get embassyDeathCertificateDesc =>
      'Copie ou extrait d\'acte de décès.';

  @override
  String get embassyConsularIdDesc =>
      'Carte d\'immatriculation consulaire pour les ressortissants nigériens.';

  @override
  String get embassyLegalDocumentDesc =>
      'Légalisation ou certification de documents officiels.';

  @override
  String get embassyLaissezPasserDesc =>
      'Document de voyage temporaire en cas de perte de passeport.';

  @override
  String get embassyPowerOfAttorneyDesc =>
      'Procuration pour représentation légale.';

  @override
  String get embassyInscriptionDesc =>
      'Inscription au registre des Nigériens à l\'étranger.';

  @override
  String get embassyOtherRequestDesc => 'Autre type de demande administrative.';

  @override
  String get embassyMessageType => 'Type de message';

  @override
  String get embassySubject => 'Objet *';

  @override
  String get embassyMessage => 'Message *';

  @override
  String get embassyMessageNote =>
      'Votre message sera transmis à l\'ambassade. Vous recevrez une notification lors de la réponse.';

  @override
  String get embassySendMessage => 'Envoyer le message';

  @override
  String get embassySubjectRequired => 'L\'objet est obligatoire';

  @override
  String get embassySubjectMinLength =>
      'L\'objet doit contenir au moins 5 caractères';

  @override
  String get embassyMessageRequired => 'Le message est obligatoire';

  @override
  String get embassyMessageMinLength =>
      'Le message doit contenir au moins 20 caractères';

  @override
  String embassyMessageCharacterCount(int count) {
    return '$count/1000 caractères';
  }

  @override
  String get embassyMessageGeneral => 'Question générale';

  @override
  String get embassyMessageRequest => 'Demande de service';

  @override
  String get embassyMessageComplaint => 'Réclamation';

  @override
  String get embassyMessageInquiry => 'Renseignement';

  @override
  String get embassyMessageFollowUp => 'Suivi de dossier';

  @override
  String get embassySearchTitle => 'Rechercher un employé';

  @override
  String embassyStaffTitle(String name) {
    return 'Personnel - $name';
  }

  @override
  String get embassyAllDepartments => 'Tous les départements';

  @override
  String get embassyDepartmentDirection => 'Direction';

  @override
  String get embassyDepartmentConsular => 'Services consulaires';

  @override
  String get embassyDepartmentVisa => 'Section des visas';

  @override
  String get embassyDepartmentCivilStatus => 'État civil';

  @override
  String get embassyDepartmentSocial => 'Affaires sociales';

  @override
  String get embassyDepartmentChancellery => 'Chancellerie';

  @override
  String get embassyDepartmentCommunication => 'Communication';

  @override
  String get embassyDepartmentAdministration => 'Administration';

  @override
  String get embassyLoadingError => 'Erreur de chargement';

  @override
  String get embassyRetry => 'Réessayer';

  @override
  String get embassyNoEmployeeFound => 'Aucun employé trouvé';

  @override
  String get embassyModifySearch =>
      'Essayez de modifier vos critères de recherche';

  @override
  String get adminAnalyticsAndReports => 'Analytique & Rapports';

  @override
  String get adminAnalyticsSubtitle =>
      'Statistiques et métriques de l\'application';

  @override
  String get adminLoadingError => 'Erreur de chargement';

  @override
  String get adminUserGrowth => 'Croissance Utilisateurs';

  @override
  String get adminToday => 'Aujourd\'hui';

  @override
  String get adminThisWeek => 'Cette semaine';

  @override
  String get adminThisMonth => 'Ce mois';

  @override
  String get adminMonthlyEvolution => 'Évolution Mensuelle (6 derniers mois)';

  @override
  String get adminNoDataAvailable => 'Aucune donnée disponible';

  @override
  String get adminEventsByCategory => 'Événements par Catégorie';

  @override
  String get adminBusinessesByCategory => 'Commerces par Catégorie';

  @override
  String get adminNoData => 'Aucune donnée';

  @override
  String get adminDataExport => 'Export de Données';

  @override
  String get adminExportUsers => 'Exporter Utilisateurs';

  @override
  String get adminExportEvents => 'Exporter Événements';

  @override
  String get adminExportBusinesses => 'Exporter Commerces';

  @override
  String get adminExportTransactions => 'Exporter Transactions';

  @override
  String get adminPanelTitle => 'Admin Panel';

  @override
  String get adminDiaspoNigerMonitoring => 'DiaspoNiger Monitoring';

  @override
  String get adminOrText => 'OR';

  @override
  String get adminGoogleError => 'Erreur de connexion Google';

  @override
  String get adminAccessDeniedMessage =>
      'Accès refusé. Compte administrateur requis.';

  @override
  String get adminContentModeration => 'Modération de Contenu';

  @override
  String get adminContentSubtitle =>
      'Gérez les événements et groupes de la communauté';

  @override
  String adminEventsTabCount(int count) {
    return 'Événements ($count)';
  }

  @override
  String adminGroupsTabCount(int count) {
    return 'Groupes ($count)';
  }

  @override
  String get adminLoadingContent => 'Chargement du contenu...';

  @override
  String get adminOrganizerLabel => 'Organisateur';

  @override
  String get adminMembersCount => 'membres';

  @override
  String get adminCategoryLabel => 'Catégorie';

  @override
  String get adminCancelAction => 'Annuler';

  @override
  String get adminDeleteAction => 'Supprimer';

  @override
  String get adminConfirmAction => 'Confirmer';

  @override
  String get adminCancelEventTitle => 'Annuler l\'événement';

  @override
  String get adminCancelEventMsg =>
      'Êtes-vous sûr de vouloir annuler cet événement ?';

  @override
  String get adminDeleteEventTitle => 'Supprimer l\'événement';

  @override
  String get adminDeleteEventMsg =>
      'Êtes-vous sûr de vouloir supprimer cet événement ? Cette action est irréversible.';

  @override
  String get adminMakePublicAction => 'Rendre public';

  @override
  String get adminMakePrivateAction => 'Rendre privé';

  @override
  String get adminEventCancelled => 'Événement annulé';

  @override
  String get adminEventDeleted => 'Événement supprimé';

  @override
  String get adminGroupMadePublic => 'Groupe rendu public';

  @override
  String get adminGroupMadePrivate => 'Groupe rendu privé';

  @override
  String get adminGroupDeleted => 'Groupe supprimé';

  @override
  String get adminNoEventsFound => 'Aucun événement trouvé';

  @override
  String get adminNoGroupsFound => 'Aucun groupe trouvé';

  @override
  String get adminErrorNotConnected => 'Erreur: Admin non connecté';

  @override
  String get adminReportsManagement => 'Gestion des Signalements';

  @override
  String get adminReportsSubtitle =>
      'Traitez les signalements de contenu inapproprié';

  @override
  String get adminPendingLabel => 'En attente';

  @override
  String get adminResolvedLabel => 'Résolu';

  @override
  String get adminDismissedLabel => 'Rejeté';

  @override
  String get adminTotalLabel => 'Total';

  @override
  String adminProcessedTabCount(int count) {
    return 'Traités ($count)';
  }

  @override
  String get adminTypeFilterLabel => 'Type:';

  @override
  String get adminAllTypesOption => 'Tous';

  @override
  String get adminReportedOnLabel => 'Signalé le:';

  @override
  String get adminTargetNameLabel => 'Nom';

  @override
  String get adminCapturedContentLabel => 'Contenu capturé (préservé)';

  @override
  String get adminHostLabel => 'Hôte';

  @override
  String get adminDescriptionLabel => 'Description';

  @override
  String get adminAdminNoteLabel => 'Note admin';

  @override
  String get adminReportDismissed => 'Signalement rejeté';

  @override
  String get adminReportProcessed => 'Signalement traité';

  @override
  String get adminReportProcessedNotified =>
      'Signalement traité (utilisateur notifié)';

  @override
  String get adminContentDeleted => 'Contenu supprimé';

  @override
  String get adminContentDeletedNotified =>
      'Contenu supprimé (utilisateur notifié)';

  @override
  String get adminDismissReportTitle => 'Rejeter le signalement';

  @override
  String get adminDismissReportPrompt => 'Raison du rejet:';

  @override
  String get adminProcessReportTitle => 'Traiter le signalement';

  @override
  String get adminProcessReportPrompt => 'Note de résolution:';

  @override
  String get adminDeleteContentMsg =>
      'Êtes-vous sûr de vouloir supprimer ce contenu ?';

  @override
  String adminDeleteIrreversibleMsg(String type) {
    return 'Cette action est irréversible et supprimera définitivement le $type.';
  }

  @override
  String get adminNoResultsSearch => 'Aucun résultat pour cette recherche';

  @override
  String get adminNoReportsAvailable => 'Aucun signalement';

  @override
  String get adminTargetIdLabel => 'ID cible';

  @override
  String get adminReportedByLabel => 'Signalé par';

  @override
  String get adminReportedUserLabel => 'Utilisateur signalé';

  @override
  String get adminLoadingReports => 'Chargement des signalements...';

  @override
  String get adminRejectAction => 'Rejeter';

  @override
  String get adminProcessAction => 'Traiter';

  @override
  String get adminDeleteContentAction => 'Supprimer contenu';

  @override
  String get adminClearFiltersAction => 'Effacer les filtres';

  @override
  String get adminViewTheLabel => 'Voir le';

  @override
  String get adminGeneralStatsTitle => 'Statistiques Générales';

  @override
  String get adminActiveSessionsLabel => 'Sessions Actives';

  @override
  String get adminEventsLabel => 'Événements';

  @override
  String get adminGroupsLabel => 'Groupes';

  @override
  String get adminCommerceTitle => 'Commerce & Marketplace';

  @override
  String get adminBusinessesLabel => 'Commerces';

  @override
  String get adminProductsLabel => 'Produits';

  @override
  String get adminTransactionsLabel => 'Transactions';

  @override
  String get adminReportsLabel => 'Signalements';

  @override
  String get adminQuickActionsTitle => 'Actions Rapides';

  @override
  String get adminActiveStatus => 'actif';

  @override
  String get adminManageEmbassiesTitle => 'Gestion des Ambassades';

  @override
  String get adminManageEmbassiesDesc =>
      'Créez et gérez les comptes ambassades';

  @override
  String get adminLiveAudioRoomsTitle => 'Salons Audio Live';

  @override
  String get adminNoLiveRoomsTitle => 'Aucun salon en direct';

  @override
  String get adminNoLiveRoomsMsg =>
      'Il n\'y a actuellement aucun salon audio en cours.';

  @override
  String get adminLiveLabel => 'LIVE';

  @override
  String get adminPaidTag => 'Payant';

  @override
  String get adminVideoTag => 'Vidéo';

  @override
  String get adminModeratorModeTitle => 'Mode Modération';

  @override
  String get adminModeratorModeMsg =>
      'Vous allez rejoindre ce salon en mode invisible (ghost mode). Les participants ne pourront pas vous voir.\n\nVous pourrez:\n• Écouter les conversations\n• Voir les vidéos (si activées)\n• Avertir l\'hôte\n• Fermer le salon si nécessaire';

  @override
  String get adminJoinAction => 'Rejoindre';

  @override
  String get adminTransferFeesTitle => 'Frais de Transfert';

  @override
  String get adminTransferFeesDesc =>
      'Configuration des frais sur les envois d\'argent';

  @override
  String get adminMarketplaceFeesTitle => 'Frais Marketplace';

  @override
  String get adminMarketplaceFeesDesc =>
      'Commission sur les ventes de produits';

  @override
  String get adminSaveChanges => 'Enregistrer les modifications';

  @override
  String get adminFieldRequired => 'Requis';

  @override
  String get adminValueBetweenError => 'Valeur entre 0 et 100';

  @override
  String get adminInvalidNumberError => 'Nombre invalide';

  @override
  String get adminBasePricesTitle => 'Prix de base (7 jours)';

  @override
  String get adminStandardTier => 'Standard';

  @override
  String get adminStandardTierDesc => 'Visibilité améliorée';

  @override
  String get adminFeaturedTier => 'Featured';

  @override
  String get adminFeaturedTierDesc => 'Badge + meilleure position';

  @override
  String get adminPremiumTier => 'Premium';

  @override
  String get adminPremiumTierDesc => 'Top position + section dédiée';

  @override
  String get adminDurationMultipliersTitle => 'Multiplicateurs de durée';

  @override
  String get adminDays7Label => '7 jours';

  @override
  String get adminDays30Label => '30 jours';

  @override
  String get adminDays90Label => '90 jours';

  @override
  String get adminPricePreviewTitle => 'Aperçu des prix (Standard)';

  @override
  String get adminPercentageHint => 'Ex: 2.5 pour 2.5%';

  @override
  String get adminFeesUpdatedSuccess => 'Frais mis à jour';

  @override
  String get adminBoostPricesUpdatedSuccess => 'Tarifs boost mis à jour';

  @override
  String get adminConfigurationAppTitle => 'Configuration App';

  @override
  String get podcastsSubscribersLabel => 'abonnés';

  @override
  String get podcastsEpisodesLabel => 'épisodes';

  @override
  String get podcastsPlaysLabel => 'écoutes';

  @override
  String get securityDeleteBackupTitle => 'Supprimer la sauvegarde ?';

  @override
  String get securityDeleteBackupContent =>
      'Cette action est irréversible. Si vous perdez vos clés et n\'avez plus de sauvegarde, vous ne pourrez plus lire vos anciens messages.';

  @override
  String get securityBackupDeleted => 'Sauvegarde supprimée';

  @override
  String get securityBackupTitle => 'Sauvegarde des clés';

  @override
  String get e2eeBackupNudgeMessage =>
      'Sauvegardez vos clés de chiffrement pour ne pas perdre l\'accès à vos messages si vous changez d\'appareil.';

  @override
  String get e2eeBackupNudgeAction => 'Sauvegarder';

  @override
  String get e2eeRestoreNudgeMessage =>
      'Restaurez vos clés de chiffrement pour lire vos messages chiffrés sur cet appareil.';

  @override
  String get e2eeRestoreNudgeAction => 'Restaurer';

  @override
  String get securityRestoreKeys => 'Restaurer les clés';

  @override
  String get securityGeneratePassphrase => 'Générer une passphrase sécurisée';

  @override
  String get securityCreateBackup => 'Créer la sauvegarde';

  @override
  String get securityPassphrase => 'Passphrase';

  @override
  String get securityPassphraseMin => 'Minimum 8 caractères';

  @override
  String get securityConfirmPassphrase => 'Confirmer la passphrase';

  @override
  String securityDeletionError(String error) {
    return 'Erreur lors de la suppression: $error';
  }

  @override
  String get bugReportDescription => 'Description du bug';

  @override
  String get bugReportDescriptionHint => 'Décrivez le problème rencontré...';

  @override
  String get bugReportDescriptionRequired => 'Veuillez décrire le bug';

  @override
  String get bugReportStepsOptional => 'Étapes pour reproduire (optionnel)';

  @override
  String get bugReportStepsHint => '1. Ouvrir l\'application\n2. ...';

  @override
  String get bugReportEmailOpened => 'Application de messagerie ouverte';

  @override
  String get bugReportEmailFailed =>
      'Impossible d\'ouvrir l\'application de messagerie';

  @override
  String get reminder => 'Rappel';

  @override
  String get confirmSend => 'Confirmer l\'envoi';

  @override
  String get titleLabel => 'Titre';

  @override
  String get adminGlobalNotifications => 'Notifications Globales';

  @override
  String get adminGlobalNotificationsDesc =>
      'Envoyez des notifications à tous les utilisateurs';

  @override
  String get adminNewNotification => 'Nouvelle Notification';

  @override
  String get adminNotifTitleHint => 'Ex: Mise à jour importante';

  @override
  String get adminNotifMessageHint => 'Contenu de la notification...';

  @override
  String get adminRecipients => 'Destinataires';

  @override
  String get adminAllUsers => 'Tous les utilisateurs';

  @override
  String get adminAdministrators => 'Administrateurs';

  @override
  String get adminVerifiedProfiles => 'Profils vérifiés';

  @override
  String get adminBusinessOwners => 'Propriétaires de commerces';

  @override
  String get adminSending => 'Envoi en cours...';

  @override
  String get adminNoTitle => 'Sans titre';

  @override
  String get adminStatusSent => 'Envoyé';

  @override
  String get adminStatusPending => 'En attente';

  @override
  String get adminStatusFailed => 'Échoué';

  @override
  String get adminTargetAll => 'Tous';

  @override
  String get adminTargetAdmins => 'Admins';

  @override
  String get adminTargetVerified => 'Vérifiés';

  @override
  String get adminTargetBusinesses => 'Commerces';

  @override
  String get adminNoNotificationsSent => 'Aucune notification envoyée';

  @override
  String get adminFillTitleAndMessage =>
      'Veuillez remplir le titre et le message';

  @override
  String get adminNotConnected => 'Erreur: Admin non connecté';

  @override
  String get typeLabel => 'Type:';

  @override
  String get contentDeleted => 'Contenu supprimé';

  @override
  String get contentDeletedUserNotified =>
      'Contenu supprimé (utilisateur notifié)';

  @override
  String get adminRejectionReason => 'Raison du rejet';

  @override
  String get adminMaintenanceMessageHint => 'Ex: Application en maintenance...';

  @override
  String get adminReportRejected => 'Signalement rejeté';

  @override
  String get adminReportProcessedUserNotified =>
      'Signalement traité (utilisateur notifié)';

  @override
  String get adminReportsManagementDesc =>
      'Traitez les signalements de contenu inapproprié';

  @override
  String get adminRejectReport => 'Rejeter le signalement';

  @override
  String get adminRejectionReasonLabel => 'Raison du rejet:';

  @override
  String get adminProcessReport => 'Traiter le signalement';

  @override
  String get adminResolutionNoteLabel => 'Note de résolution:';

  @override
  String get adminMinimumFee => 'Frais minimum (XOF)';

  @override
  String get adminMaximumFee => 'Frais maximum (XOF)';

  @override
  String get adminBoostRatesUpdated => 'Tarifs boost mis à jour';

  @override
  String get adminLocationUpdateMin => 'Mise à jour localisation (min)';

  @override
  String get adminOnlineHeartbeatMin => 'Heartbeat statut en ligne (min)';

  @override
  String get adminCacheDurationMin => 'Durée cache (min)';

  @override
  String get adminExampleValues => 'Ex: 1, 2, 5, 10, 20';

  @override
  String get adminSearchUserHint => 'Rechercher un utilisateur...';

  @override
  String adminUserActivityTitle(String name) {
    return 'Activité de $name';
  }

  @override
  String adminChangeTo(String role) {
    return 'Changer en $role';
  }

  @override
  String get revoke => 'Révoquer';

  @override
  String get refresh => 'Actualiser';

  @override
  String get adminRoleManagementTitle => 'Gestion des Rôles Admin';

  @override
  String get adminRoleManagementSubtitle =>
      'Attribuez et gérez les rôles des administrateurs';

  @override
  String get adminNoAdminsConfigured => 'Aucun administrateur configuré';

  @override
  String get noName => 'Sans nom';

  @override
  String lastLoginAt(String lastLogin) {
    return 'Dernière connexion: $lastLogin';
  }

  @override
  String adminChangeRoleConfirm(String name, String oldRole, String newRole) {
    return 'Voulez-vous changer le rôle de $name de $oldRole à $newRole?';
  }

  @override
  String adminRevokeAccessConfirm(String name) {
    return 'Voulez-vous vraiment révoquer l\'accès admin de $name? Cette personne ne pourra plus accéder au panneau d\'administration.';
  }

  @override
  String groupsCount(int count) {
    return 'Groupes ($count)';
  }

  @override
  String get groupLabel => 'Groupe';

  @override
  String get refund => 'Rembourser';

  @override
  String get adminFeesPercentageLabel => 'Pourcentage des frais';

  @override
  String get adminMinFeesLabel => 'Frais minimum (XOF)';

  @override
  String get adminMaxFeesLabel => 'Frais maximum (XOF)';

  @override
  String get adminPlatformCommissionLabel => 'Commission plateforme';

  @override
  String get adminMinCommissionLabel => 'Commission min (XOF)';

  @override
  String get adminMaxCommissionLabel => 'Commission max (XOF)';

  @override
  String get adminMaxDimensionLabel => 'Dimension max (px)';

  @override
  String adminUserActivityTitleParam(String name) {
    return 'Activité de $name';
  }

  @override
  String get myReports => 'Mes signalements';

  @override
  String get myReportsSubtitle => 'Voir l\'historique de vos signalements';

  @override
  String get calls => 'Appels';

  @override
  String get noiseSuppression => 'Suppression du bruit';

  @override
  String get noiseSuppressionSubtitle =>
      'Réduit les bruits de fond pendant les appels';

  @override
  String get soundAndVibration => 'Son et Vibration';

  @override
  String get sound => 'Son';

  @override
  String get vibration => 'Vibration';

  @override
  String get chooseCurrency => 'Choisir la devise';

  @override
  String get pricesDisplayedIn => 'Les prix seront affichés dans cette devise';

  @override
  String get noCurrencyFound => 'Aucune devise trouvée';

  @override
  String get chatBackground => 'Fond d\'écran des conversations';

  @override
  String get customColor => 'Couleur personnalisée';

  @override
  String get customImage => 'Image personnalisée';

  @override
  String get greenDefault => 'Vert (Défaut)';

  @override
  String get orangeClassic => 'Orange (Classique)';

  @override
  String get chooseColor => 'Choisir la couleur';

  @override
  String get mainCurrencies => 'Devises principales';

  @override
  String get africa => 'Afrique';

  @override
  String get asia => 'Asie';

  @override
  String get europe => 'Europe';

  @override
  String get americas => 'Amériques';

  @override
  String get oceaniaMiddleEast => 'Océanie & Moyen-Orient';

  @override
  String get describeTheProblem => 'Décrivez le problème...';

  @override
  String get sendReport => 'Envoyer le signalement';

  @override
  String get deviceNameLabel => 'Nom de l\'appareil';

  @override
  String get renameDeviceTitle => 'Renommer l\'appareil';

  @override
  String get searchCurrency => 'Rechercher une devise...';

  @override
  String get restoreKeys => 'Restaurer les clés';

  @override
  String get tags => 'Tags';

  @override
  String get requestToJoin => 'Demander à rejoindre';

  @override
  String get podcastsCancel => 'Annuler';

  @override
  String get addFriendsAsRecipients => 'Ajoutez vos amis comme bénéficiaires';

  @override
  String get noFriendMatchesSearch =>
      'Aucun ami ne correspond à votre recherche';

  @override
  String get addManually => 'Ajouter manuellement';

  @override
  String get chooseRecipient => 'Choisir un bénéficiaire';

  @override
  String get cardLabel => 'Carte';

  @override
  String get cashLabel => 'Espèces';

  @override
  String get noRecipientFound => 'Aucun bénéficiaire trouvé';

  @override
  String get noRecipientRegistered => 'Aucun bénéficiaire enregistré';

  @override
  String get tryModifyingFilters => 'Essayez de modifier les filtres';

  @override
  String get addFirstRecipient => 'Ajoutez votre premier bénéficiaire';

  @override
  String confirmDeleteRecipient(String name) {
    return 'Êtes-vous sûr de vouloir supprimer $name?';
  }

  @override
  String recipientDeletedSuccess(String name) {
    return '$name a été supprimé';
  }

  @override
  String get removeFromFavorites => 'Retirer des favoris';

  @override
  String get confirmDeleteTitle => 'Confirmer la suppression';

  @override
  String get amountSent => 'Montant envoyé';

  @override
  String get fees => 'Frais';

  @override
  String get totalDebited => 'Total débité';

  @override
  String get exchangeRate => 'Taux de change';

  @override
  String get amountReceived => 'Montant reçu';

  @override
  String get recipient => 'Bénéficiaire';

  @override
  String get unknown => 'Inconnu';

  @override
  String get information => 'Information';

  @override
  String get reference => 'Référence';

  @override
  String get paymentMode => 'Mode de paiement';

  @override
  String get stripeId => 'ID Stripe';

  @override
  String get mynitaRef => 'Réf Mynita';

  @override
  String get date => 'Date';

  @override
  String get notAvailable => 'N/D';

  @override
  String get completionDate => 'Date de complétion';

  @override
  String get failureReason => 'Raison de l\'échec';

  @override
  String get copiedToClipboard => 'Copié dans le presse-papiers';

  @override
  String get notes => 'Notes';

  @override
  String get activeFilters => 'Filtres actifs';

  @override
  String get clearAll => 'Tout effacer';

  @override
  String get unknownDate => 'Date inconnue';

  @override
  String reviewedOn(String date) {
    return 'Traité le $date';
  }

  @override
  String get unknownRecipient => 'Bénéficiaire inconnu';

  @override
  String get noTransferFound => 'Aucun transfert trouvé';

  @override
  String get noTransferCompleted => 'Aucun transfert effectué';

  @override
  String get sendMoneyToLovedOnes => 'Envoyez de l\'argent à vos proches';

  @override
  String get filterTransfers => 'Filtrer les transferts';

  @override
  String get status => 'Statut';

  @override
  String get period => 'Période';

  @override
  String get allPeriods => 'Toutes';

  @override
  String get last7Days => '7 derniers jours';

  @override
  String get last30Days => '30 derniers jours';

  @override
  String get last3Months => '3 derniers mois';

  @override
  String get choosePeriod => 'Choisir la période';

  @override
  String get applyFilters => 'Appliquer les filtres';

  @override
  String get statusDebiting => 'Débit en cours';

  @override
  String get statusSending => 'Envoi en cours';

  @override
  String get statusRefunding => 'Remboursement';

  @override
  String get noDeviceRegistered => 'Aucun appareil enregistré';

  @override
  String get devicesE2eeWillAppear =>
      'Les appareils utilisant le chiffrement de bout en bout apparaîtront ici.';

  @override
  String get rename => 'Renommer';

  @override
  String get revokeDeviceQuestion => 'Révoquer l\'appareil ?';

  @override
  String revokeDeviceConfirmMessage(String deviceName) {
    return 'Voulez-vous vraiment révoquer l\'accès de \"$deviceName\" ?';
  }

  @override
  String get deviceRenameSuccess => 'Appareil renommé';

  @override
  String get deviceRenameError => 'Erreur lors du renommage';

  @override
  String get restoreOnThisDevice => 'Restaurer sur cet appareil';

  @override
  String get enterPassphraseToRestore =>
      'Entrez votre passphrase pour restaurer vos clés:';

  @override
  String get createABackup => 'Créer une sauvegarde';

  @override
  String get createBackupButton => 'Créer une sauvegarde';

  @override
  String get confirmPassphraseLabel => 'Confirmer la passphrase';

  @override
  String get passphraseCopied => 'Passphrase copiée';

  @override
  String get xTwitter => 'X';

  @override
  String get more => 'Plus';

  @override
  String get travelMode => 'Mode Voyage';

  @override
  String codeSentTo(String phoneNumber) {
    return 'Code envoyé au $phoneNumber';
  }

  @override
  String get addParticipant => 'Ajouter un participant';

  @override
  String get addToCall => 'Ajouter à l\'appel';

  @override
  String get convertingToGroupCall => 'Conversion en appel de groupe...';

  @override
  String get selectParticipantToAdd => 'Sélectionner un participant';

  @override
  String get noEligibleParticipants => 'Aucun participant disponible';

  @override
  String get noEligibleParticipantsHint =>
      'Ajoutez des amis ou démarrez une conversation pour pouvoir les ajouter à un appel';

  @override
  String get recentConversations => 'Conversations récentes';

  @override
  String get callConvertedToGroup => 'Converti en appel de groupe';

  @override
  String participantBusy(String name) {
    return '$name est en appel';
  }

  @override
  String get conversionFailed => 'Échec de l\'ajout du participant';

  @override
  String get slideToCancel => 'Annuler';

  @override
  String get releaseToCancel => 'Annuler';

  @override
  String get recordingLocked => 'Enregistrement verrouillé';

  @override
  String get releaseToLock => 'Relâchez pour verrouiller';

  @override
  String get slideUpToLock => 'Glissez vers le haut';

  @override
  String timeRemaining(String time) {
    return 'Temps restant: $time';
  }

  @override
  String get lock => 'Verrouiller';

  @override
  String get localEvents => 'Événements locaux';

  @override
  String get localEventsSubtitle =>
      'Recevoir des notifications pour les nouveaux événements dans ma ville';

  @override
  String get systemMessages => 'Messages système';

  @override
  String get systemMessagesSubtitle =>
      'Recevoir des notifications pour les évènements système (ex: nouveau membre)';

  @override
  String get confidentiality => 'Confidentialité';

  @override
  String get messagePreview => 'Aperçu des messages';

  @override
  String get messagePreviewSubtitle =>
      'Afficher le contenu des messages dans les notifications';

  @override
  String get onlineStatus => 'En ligne';

  @override
  String seenAgo(String ago) {
    return 'Vu $ago';
  }

  @override
  String get offline => 'Hors ligne';

  @override
  String discoverProfile(String link) {
    return 'Découvrez mon profil sur Diaspo Niger: $link';
  }

  @override
  String profileOf(String name) {
    return 'Profil de $name';
  }

  @override
  String get unableToGenerateLink => 'Impossible de générer le lien de partage';

  @override
  String get profileSendFriendRequest => 'Envoyer une demande d\'ami';

  @override
  String get profileFriendRequestSent => 'Demande d\'ami envoyée';

  @override
  String get profileFriendRequestFailed => 'Échec de l\'envoi';

  @override
  String get profileNewMember => 'Nouvel utilisateur';

  @override
  String get profileNoBio => 'Aucune biographie';

  @override
  String get profileNoSkillsAdded => 'Aucune compétence ajoutée';

  @override
  String get profileNoInterestsAdded => 'Aucun intérêt ajouté';

  @override
  String get profileShowOnlineStatus => 'Afficher mon statut en ligne';

  @override
  String get profileReport => 'Signaler';

  @override
  String get profileSettings => 'Réglages';

  @override
  String get profileSendingRequest => 'Envoi en cours...';

  @override
  String get profileTravelModeSubtitle =>
      'Permettre la localisation même quand l\'application est fermée (Mise à jour toutes les 5 min)';

  @override
  String get profileShowOnlineStatusSubtitle =>
      'Permet de voir et d\'être vu en ligne. Si désactivé, vous ne verrez pas le statut des autres.';

  @override
  String get whoSeesYou => 'Qui vous voit';

  @override
  String get dataSaverMode => 'Mode données réduites';

  @override
  String get dataSaverModeSubtitle =>
      'Médias non téléchargés automatiquement en discussion';

  @override
  String get displayCurrency => 'Devise';

  @override
  String get displayCurrencySubtitle =>
      'Les prix seront affichés dans cette devise';

  @override
  String profileUpdateError(String error) {
    return 'Erreur lors de la mise à jour: $error';
  }

  @override
  String get profileLoadingText => 'Chargement...';

  @override
  String get profileLoadError => 'Erreur de chargement';

  @override
  String conversationYouPrefix(String message) {
    return 'Vous: $message';
  }

  @override
  String get emojis => 'Emojis';

  @override
  String get gifs => 'GIFs';

  @override
  String get searchGifs => 'Rechercher des GIFs';

  @override
  String get gifNoResults => 'Aucun résultat.';

  @override
  String get gifLoadError => 'Impossible de charger les GIFs.';

  @override
  String get gifProviderNotConfigured =>
      'Les GIFs ne sont pas encore configurés.';

  @override
  String get gifDataSaverNote => 'Téléchargés une fois, envoyés sans données';

  @override
  String get showKeyboard => 'Afficher le clavier';

  @override
  String get stickers => 'Stickers';

  @override
  String get stickerPacks => 'Packs de stickers';

  @override
  String get recentStickers => 'Récents';

  @override
  String get favoriteStickers => 'Favoris';

  @override
  String get addStickerPack => 'Ajouter un pack';

  @override
  String get removeStickerPack => 'Supprimer le pack';

  @override
  String get stickerPackAdded => 'Pack de stickers ajouté';

  @override
  String get stickerPackRemoved => 'Pack de stickers supprimé';

  @override
  String get noStickersYet => 'Pas encore de stickers';

  @override
  String get browseStickers => 'Parcourir les packs';

  @override
  String get stickerLabel => 'Sticker';

  @override
  String get myStickerPacks => 'Mes packs de stickers';

  @override
  String get createStickerPack => 'Créer un pack';

  @override
  String get stickerPackName => 'Nom du pack';

  @override
  String get stickerPackDescription => 'Description (optionnel)';

  @override
  String get stickerPackThumbnail => 'Miniature';

  @override
  String get addStickers => 'Ajouter des stickers';

  @override
  String get stickerPackCreated => 'Pack de stickers créé';

  @override
  String get stickerPackPending => 'En attente de modération';

  @override
  String get stickerPackApproved => 'Approuvé';

  @override
  String get stickerPackRejected => 'Rejeté';

  @override
  String get deleteStickerPack => 'Supprimer le pack';

  @override
  String get confirmDeleteStickerPack =>
      'Voulez-vous vraiment supprimer ce pack de stickers ?';

  @override
  String get noStickerPacks => 'Aucun pack de stickers';

  @override
  String get officialPacks => 'Packs officiels';

  @override
  String get communityPacks => 'Packs de la communauté';

  @override
  String get serviceFeed => 'Fil d\'actualité';

  @override
  String get feedTitle => 'Fil d\'actualité';

  @override
  String get storyTakePhoto => 'Prendre une photo';

  @override
  String get storyChooseFromGallery => 'Choisir depuis la galerie';

  @override
  String storiesTodayCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count récits aujourd\'hui',
      one: '1 récit aujourd\'hui',
      zero: 'Aucun récit aujourd’hui',
    );
    return '$_temp0';
  }

  @override
  String get storiesShow => 'Afficher';

  @override
  String get storyChooseVideo => 'Choisir une vidéo';

  @override
  String get storyVideoMaxDuration => '30 secondes maximum';

  @override
  String storyViewersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vues',
      one: '1 vue',
      zero: 'Aucune vue',
    );
    return '$_temp0';
  }

  @override
  String get storyNoViewersYet => 'Personne n\'a encore vu cette story';

  @override
  String get feedEmpty =>
      'Aucune publication pour le moment.\nSoyez le premier à partager !';

  @override
  String feedNewPostsPill(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nouvelles publications',
      one: '1 nouvelle publication',
      zero: 'Aucune nouvelle publication',
    );
    return '$_temp0';
  }

  @override
  String get createPost => 'Créer une publication';

  @override
  String get postPlaceholder => 'Quoi de neuf ?';

  @override
  String get publishPost => 'Publier';

  @override
  String get likePost => 'J\'aime';

  @override
  String get commentPost => 'Commenter';

  @override
  String get sharePost => 'Partager';

  @override
  String get deletePost => 'Supprimer la publication';

  @override
  String get confirmDeletePost =>
      'Voulez-vous vraiment supprimer cette publication ?';

  @override
  String get followUser => 'Suivre';

  @override
  String get unfollowUser => 'Ne plus suivre';

  @override
  String get followTitle => 'Abonnés et abonnements';

  @override
  String get followersTitle => 'Abonnés';

  @override
  String get followingTitle => 'Abonnements';

  @override
  String get noFollowersYet => 'Aucun abonné pour le moment.';

  @override
  String get noFollowingYet => 'Vous ne suivez encore personne.';

  @override
  String get myFollowsTitle => 'Abonnés et abonnements';

  @override
  String get myFollowsSubtitle => 'Voyez qui vous suit et qui vous suivez';

  @override
  String get errorLoadingData => 'Échec du chargement. Réessayez.';

  @override
  String get commentPlaceholder => 'Ajouter un commentaire…';

  @override
  String get addComment => 'Publier';

  @override
  String get postDeleted => 'Publication supprimée';

  @override
  String get postShared => 'Publication partagée';

  @override
  String get noComments => 'Aucun commentaire pour le moment';

  @override
  String get deleteComment => 'Supprimer le commentaire';

  @override
  String get confirmDeleteComment =>
      'Voulez-vous vraiment supprimer ce commentaire ?';

  @override
  String get commentDeleted => 'Commentaire supprimé';

  @override
  String get editPost => 'Modifier la publication';

  @override
  String get editPostTitle => 'Modifier la publication';

  @override
  String get likeComment => 'J\'aime';

  @override
  String replyingTo(String name) {
    return 'Réponse à $name';
  }

  @override
  String viewReplies(int count) {
    return 'Voir $count réponses';
  }

  @override
  String get hideReplies => 'Masquer les réponses';

  @override
  String get loadingMore => 'Chargement…';

  @override
  String get feedError => 'Impossible de charger le fil d\'actualité';

  @override
  String get postError => 'Impossible de charger la publication';

  @override
  String get addMedia => 'Ajouter des médias';

  @override
  String get addVideo => 'Ajouter une vidéo';

  @override
  String get publishing => 'Publication en cours…';

  @override
  String get publishSuccess => 'Publication créée avec succès';

  @override
  String get publishError => 'Erreur lors de la publication';

  @override
  String followers(int count) {
    return '$count abonnés';
  }

  @override
  String following(int count) {
    return '$count abonnements';
  }

  @override
  String postLikes(int count) {
    return '$count j\'aime';
  }

  @override
  String postComments(int count) {
    return '$count commentaire(s)';
  }

  @override
  String get mentionSuggestionHint => 'Mentionner un membre';

  @override
  String get mentionNotificationTitle => 'Vous avez été mentionné';

  @override
  String mentionNotificationBody(String senderName, String groupName) {
    return '$senderName vous a mentionné dans $groupName';
  }

  @override
  String mentionedBy(String name) {
    return 'Mentionné par $name';
  }

  @override
  String get loadingEllipsis => 'Chargement...';

  @override
  String get rejected => 'Rejeté';

  @override
  String get suspended => 'Suspendu';

  @override
  String get reactivate => 'Réactiver';

  @override
  String get reject => 'Rejeter';

  @override
  String get approve => 'Approuver';

  @override
  String get suspend => 'Suspendre';

  @override
  String get rejectionReason => 'Raison du rejet';

  @override
  String get complete => 'Complet';

  @override
  String get buyer => 'Acheteur';

  @override
  String get seller => 'Vendeur';

  @override
  String get deleteContent => 'Supprimer le contenu';

  @override
  String get process => 'Traiter';

  @override
  String get clearFilters => 'Effacer les filtres';

  @override
  String get newAdmin => 'Nouvel administrateur';

  @override
  String get changeRole => 'Changer le rôle';

  @override
  String get revokeAccess => 'Révoquer l\'accès';

  @override
  String exportInProgress(String type) {
    return 'Export de $type en cours...';
  }

  @override
  String get embassyCreated => 'Ambassade créée avec succès !';

  @override
  String get createEmbassy => 'Créer une ambassade';

  @override
  String get joinAction => 'Rejoindre';

  @override
  String get viewReports => 'Voir les rapports';

  @override
  String get manageUsers => 'Gérer les utilisateurs';

  @override
  String get sendNotification => 'Envoyer une notification';

  @override
  String get viewAnalytics => 'Voir les analyses';

  @override
  String get configuration => 'Configuration';

  @override
  String get featureFlags => 'Drapeaux de fonctionnalités';

  @override
  String get auditHistory => 'Historique d\'audit';

  @override
  String get emailAction => 'Email';

  @override
  String get website => 'Site web';

  @override
  String get getDirections => 'Obtenir l\'itinéraire';

  @override
  String get department => 'Département';

  @override
  String get messageTitle => 'Titre';

  @override
  String get messageBody => 'Message';

  @override
  String get confirmSending => 'Confirmer l\'envoi';

  @override
  String get aboutToSend =>
      'Vous êtes sur le point d\'envoyer une notification à :';

  @override
  String messageLabel(String message) {
    return 'Message : $message';
  }

  @override
  String get searchBy => 'Rechercher par nom, raison, ID...';

  @override
  String viewTheItem(String item) {
    return 'Voir le $item';
  }

  @override
  String changeToRole(String role) {
    return 'Passer à $role';
  }

  @override
  String get revokeAdminAccess => 'Révoquer l\'accès administrateur';

  @override
  String get revokeAction => 'Révoquer';

  @override
  String get feesUpdated => 'Frais mis à jour';

  @override
  String get feePercentage => 'Pourcentage de frais';

  @override
  String get minimumFee => 'Frais minimum (XOF)';

  @override
  String get maximumFee => 'Frais maximum (XOF)';

  @override
  String get platformCommission => 'Commission plateforme';

  @override
  String get minimumCommission => 'Commission minimum (XOF)';

  @override
  String get maximumCommission => 'Commission maximum (XOF)';

  @override
  String get boostRatesUpdated => 'Taux de boost mis à jour';

  @override
  String get vatRateUpdated => 'Taux de TVA mis à jour';

  @override
  String get mediaLimitsUpdated => 'Limites médias mises à jour';

  @override
  String get maxDimension => 'Dimension max (px)';

  @override
  String get compressionQuality => 'Qualité de compression (%)';

  @override
  String get maxImagesPerUpload => 'Max images/upload';

  @override
  String get maxImageSize => 'Taille max image (MB)';

  @override
  String get maxVideoSize => 'Taille max vidéo (MB)';

  @override
  String get maxCharsPerMessage => 'Max caractères par message';

  @override
  String get urlsUpdated => 'URLs mises à jour';

  @override
  String get intervalsUpdated => 'Intervalles mis à jour';

  @override
  String get baseShareUrl => 'URL de base pour le partage';

  @override
  String get privacyEmail => 'Email confidentialité (RGPD)';

  @override
  String get bugReportEmail => 'Email de signalement de bug';

  @override
  String get feedbackEmail => 'Email de retour';

  @override
  String get moderationEmail => 'Email de modération';

  @override
  String get locationUpdateInterval => 'Mise à jour localisation (min)';

  @override
  String get onlineStatusHeartbeat => 'Battement statut en ligne (min)';

  @override
  String get cacheDuration => 'Durée du cache (min)';

  @override
  String get audioSettingsUpdated => 'Paramètres audio mis à jour';

  @override
  String get exampleValues => 'Ex : 1, 2, 5, 10, 20';

  @override
  String get searchUser => 'Rechercher un utilisateur...';

  @override
  String get noUserFound => 'Aucun utilisateur trouvé';

  @override
  String get noActivityRecorded => 'Aucune activité enregistrée';

  @override
  String activityOf(String name) {
    return 'Activité de $name';
  }

  @override
  String get confirmLogoutTitle => 'Confirmer la déconnexion';

  @override
  String get disconnect => 'Déconnecter';

  @override
  String get publicGroup => 'Public';

  @override
  String embassyApproved(String name) {
    return 'Ambassade $name approuvée';
  }

  @override
  String embassyRejected(String name) {
    return 'Ambassade $name rejetée';
  }

  @override
  String embassySuspended(String name) {
    return 'Ambassade $name suspendue';
  }

  @override
  String embassyReactivated(String name) {
    return 'Ambassade $name réactivée';
  }

  @override
  String get rejectRequest => 'Rejeter la demande';

  @override
  String get featureFlagsUpdated => 'Drapeaux de fonctionnalités mis à jour';

  @override
  String get maintenanceMessage => 'Ex : Application en maintenance...';

  @override
  String get signInWithGoogle => 'Se connecter avec Google';

  @override
  String get loginButton => 'Connexion';

  @override
  String products(int count) {
    return 'Produits ($count)';
  }

  @override
  String orders(int count) {
    return 'Commandes ($count)';
  }

  @override
  String disputes(int count) {
    return 'Litiges ($count)';
  }

  @override
  String get sendButton => 'Envoyer';

  @override
  String get emailAddress => 'Adresse email';

  @override
  String get emailPlaceholder => 'utilisateur@example.com';

  @override
  String get passwordLabel => 'Mot de passe';

  @override
  String get businessCreated => 'Entreprise créée avec succès !';

  @override
  String get businessName => 'Nom de l\'entreprise *';

  @override
  String get telephone => 'Téléphone';

  @override
  String get address => 'Adresse';

  @override
  String get offeredServices => 'Services proposés';

  @override
  String get addService => 'Ajouter un service';

  @override
  String get createBusiness => 'Créer l\'entreprise';

  @override
  String get typeColon => 'Type :';

  @override
  String get durationColon => 'Durée :';

  @override
  String get totalColon => 'Total :';

  @override
  String get modifyReview => 'Modifier';

  @override
  String get pleaseRate => 'Veuillez noter';

  @override
  String get titleOptional => 'Titre (optionnel)';

  @override
  String get titleExample => 'Ex : Excellent service';

  @override
  String get yourReview => 'Votre avis';

  @override
  String get shareExperience => 'Partagez votre expérience...';

  @override
  String get addButton => 'Ajouter';

  @override
  String get imageLimitReached => 'Limite de 5 affiches atteinte';

  @override
  String get photoLimitReached => 'Limite de 10 photos atteinte';

  @override
  String addPhotos(int current, int max) {
    return 'Ajouter des photos ($current/$max)';
  }

  @override
  String get requestSubmitted => 'Demande soumise avec succès !';

  @override
  String get exampleRequest => 'Ex : Demande concernant le passeport';

  @override
  String get describeRequest => 'Décrivez votre demande en détail...';

  @override
  String get searchCountry => 'Rechercher un pays';

  @override
  String get typeCountryName => 'Tapez le nom du pays';

  @override
  String get itinerary => 'Itinéraire';

  @override
  String get promoteAdminTitle => 'Promouvoir en administrateur';

  @override
  String get removeAdminTitle => 'Retirer le rôle d\'administrateur';

  @override
  String get requestRefused => 'Demande refusée';

  @override
  String get refuse => 'Refuser';

  @override
  String get allLabel => 'Tous';

  @override
  String get allCategories => 'Tous';

  @override
  String get messagesLabel => 'Messages';

  @override
  String get groupsLabel => 'Groupes';

  @override
  String get directory => 'Annuaire';

  @override
  String get activateButton => 'ACTIVER';

  @override
  String get simpleMapTest => 'Test de carte simple';

  @override
  String get addImage => 'Ajoutez au moins une image';

  @override
  String get customRate => 'Taux personnalisé (%)';

  @override
  String get rateExample => 'Ex : 15';

  @override
  String tax(String rate) {
    return 'TVA ($rate%)';
  }

  @override
  String get titlePlaceholder => 'Ex : iPhone 13 Pro Max';

  @override
  String get descriptionPlaceholder => 'Décrivez votre produit...';

  @override
  String get quantity => 'Quantité';

  @override
  String get categoryLabel => 'Catégorie';

  @override
  String get condition => 'État';

  @override
  String get cityAddress => 'Ville/Adresse (optionnel)';

  @override
  String get cityExample => 'Ex : Niamey';

  @override
  String get everything => 'Tout';

  @override
  String get published => 'publié';

  @override
  String get pdfLabel => 'PDF';

  @override
  String get docLabel => 'DOC';

  @override
  String get xlsLabel => 'XLS';

  @override
  String get pptLabel => 'PPT';

  @override
  String get zipLabel => 'ZIP';

  @override
  String get txtLabel => 'TXT';

  @override
  String get csvLabel => 'CSV';

  @override
  String get jsonLabel => 'JSON';

  @override
  String get joinLabel => 'Rejoindre';

  @override
  String get remindLater => 'Me rappeler plus tard';

  @override
  String get audioRoomsReminderSet => 'Rappel activé — vous serez prévenu';

  @override
  String get audioRoomsStartingSoon => 'Le salon va commencer';

  @override
  String get inOneHour => 'Dans 1 heure';

  @override
  String get exampleBank => 'Ex : BCEAO, Ecobank...';

  @override
  String get ibanExample => 'NEXX XXXX XXXX XXXX';

  @override
  String get categoryRequired => 'Catégorie *';

  @override
  String get languageRequired => 'Langue *';

  @override
  String get publicationFrequency => 'Fréquence de publication';

  @override
  String get addTag => 'Ajouter un tag';

  @override
  String get likes => 'J\'aime';

  @override
  String get sleepTimerEnded => 'Minuteur de sommeil terminé';

  @override
  String timerMinutes(int minutes) {
    return 'Minuteur : $minutes minutes';
  }

  @override
  String get episodeTitle => 'Titre de l\'épisode *';

  @override
  String get episodeDescription => 'Description / Notes';

  @override
  String get reservedForSubscribers => 'Réservé aux abonnés payants';

  @override
  String get downloaded => 'Téléchargé';

  @override
  String get selectPodcast => 'Sélectionnez un podcast ou créez-en un nouveau';

  @override
  String get recordingAvailableSoon =>
      'L\'enregistrement sera disponible bientôt';

  @override
  String get episodeTitlePlaceholder => 'Titre de l\'épisode';

  @override
  String get episodeDescriptionPlaceholder =>
      'Description de l\'épisode (optionnel)';

  @override
  String codeSent(String phone) {
    return 'Code envoyé à $phone';
  }

  @override
  String get describeIssue => 'Décrivez le problème...';

  @override
  String get connectedDevicesTitle => 'Appareils connectés';

  @override
  String get backupKeys => 'Sauvegarde des clés';

  @override
  String get deleteBackupQuestion => 'Supprimer la sauvegarde ?';

  @override
  String get generateSecurePassphrase => 'Générer une phrase secrète sécurisée';

  @override
  String get minimumChars => 'Minimum 8 caractères';

  @override
  String get termsOfUse => 'Conditions d\'utilisation';

  @override
  String get bugDescriptionLabel => 'Description du bug';

  @override
  String get bugDescriptionPlaceholder => 'Décrivez le problème rencontré...';

  @override
  String get addRecipient => 'Ajouter un destinataire';

  @override
  String get newRecipient => 'Nouveau';

  @override
  String get deleteRecipientQuestion => 'Supprimer le destinataire ?';

  @override
  String deleteRecipientConfirm(String name) {
    return 'Voulez-vous supprimer $name ?';
  }

  @override
  String get deleteQuestion => 'Supprimer ?';

  @override
  String get sendMoney => 'Envoyer de l\'argent';

  @override
  String deleteConfirm(String name) {
    return 'Supprimer $name ?';
  }

  @override
  String get retryTransfer => 'Réessayer le transfert';

  @override
  String get contactSupport => 'Contacter le support';

  @override
  String get debitInProgress => 'Débit en cours';

  @override
  String get inProgress => 'En cours';

  @override
  String get sendingInProgress => 'Envoi en cours';

  @override
  String get completed => 'Terminé';

  @override
  String get failed => 'Échoué';

  @override
  String get refundInProgress => 'Remboursement en cours';

  @override
  String get refunded => 'Remboursé';

  @override
  String get cancelled => 'Annulé';

  @override
  String get liveChat => 'Chat en direct';

  @override
  String get liveChatAvailable => 'Disponible 24h/24 7j/7';

  @override
  String get chatNotAvailable => 'Chat non disponible pour le moment';

  @override
  String get sendMoneyButton => 'Envoyer de l\'argent';

  @override
  String applicationError(String error) {
    return 'Erreur lors de l\'application : $error';
  }

  @override
  String helperText(String min, String max) {
    return 'Min : $min XOF - Max : $max XOF';
  }

  @override
  String get tales => 'Contes';

  @override
  String get proverbs => 'Proverbes';

  @override
  String get ceremonies => 'Cérémonies';

  @override
  String get craft => 'Artisanat';

  @override
  String get recipes => 'Recettes';

  @override
  String get medicine => 'Médecine';

  @override
  String get automatic => 'Automatique';

  @override
  String get exempt => 'Exempté';

  @override
  String get standardVAT => 'TVA standard (19%)';

  @override
  String get reducedVAT => 'TVA réduite (10%)';

  @override
  String get custom => 'Personnalisé';

  @override
  String get typeYourResponse => 'Tapez votre réponse...';

  @override
  String get forYouTab => 'Pour toi';

  @override
  String get followingTab => 'Suivis';

  @override
  String get recentTab => 'Récent';

  @override
  String audioRoomsAvailableCount(int count) {
    return '$count salons disponibles';
  }

  @override
  String audioRoomsLiveTabLabel(int count) {
    return 'Live ($count)';
  }

  @override
  String audioRoomsScheduledTabLabel(int count) {
    return 'Programmés ($count)';
  }

  @override
  String get audioRoomsNoLiveRooms => 'Aucun salon live';

  @override
  String get audioRoomsNoLiveSubtitle => 'Soyez le premier à démarrer';

  @override
  String get audioRoomsNoScheduledRooms => 'Aucun salon programmé';

  @override
  String get audioRoomsNoScheduledSubtitle => 'Planifiez une session';

  @override
  String audioRoomsLiveListeners(int count) {
    return 'LIVE · $count auditeurs';
  }

  @override
  String audioRoomsRegisteredCount(int count) {
    return '$count inscrits';
  }

  @override
  String get audioRoomsScheduleButton => 'Programmer';

  @override
  String get audioRoomConnecting => 'Connexion en cours…';

  @override
  String get audioRoomDefaultTitle => 'Salon audio';

  @override
  String audioRoomParticipantsOnStage(int count, int max) {
    return 'Sur scène · $count/$max';
  }

  @override
  String audioRoomListenersCount(int count) {
    return 'Auditeurs · $count';
  }

  @override
  String audioRoomHandsRaisedSection(int count) {
    return 'Mains levées · $count';
  }

  @override
  String get audioRoomEndConfirmTitle => 'Terminer le salon ?';

  @override
  String get audioRoomEndConfirmMessage =>
      'Tous les participants seront déconnectés.';

  @override
  String get audioRoomGhostMode => 'Mode fantôme · admin invisible';

  @override
  String get audioRoomSuperAdmin => 'SuperAdmin';

  @override
  String get audioRoomModerators => 'Modérateurs';

  @override
  String get audioRoomMuteLabel => 'Muet';

  @override
  String get audioRoomActiveLabel => 'Activé';

  @override
  String get audioRoomStatsLabel => 'Stats';

  @override
  String get audioRoomCameraLabel => 'Caméra';

  @override
  String get audioRoomHandLabel => 'Main';

  @override
  String get audioRoomGoDownLabel => 'Descendre';

  @override
  String get audioRoomTipLabel => 'Pourboire';

  @override
  String get audioRoomShareLabel => 'Partager';

  @override
  String get audioRoomLeaveLabel => 'Quitter';

  @override
  String get audioRoomEndLabel => 'Terminer';

  @override
  String get audioRoomInviteLabel => 'Inviter';

  @override
  String get audioRoomCoHostLabel => 'Co-hôte';

  @override
  String get audioRoomMuteAction => 'Muet';

  @override
  String get audioRoomKickLabel => 'Exclure';

  @override
  String get audioRoomBlockLabel => 'Bloquer';

  @override
  String get audioRoomWarnLabel => 'Avertir';

  @override
  String get cannotLaunchPhoneDialer => 'Impossible de lancer le téléphone';

  @override
  String get cannotLaunchEmailClient => 'Impossible de lancer le client email';

  @override
  String get cannotOpenWebsite => 'Impossible d\'ouvrir le site web';

  @override
  String get cannotOpenMaps => 'Impossible d\'ouvrir les cartes';

  @override
  String get liveMicLabel => 'Micro';

  @override
  String get liveMicMuted => 'Micro coupé';

  @override
  String get liveCameraLabel => 'Caméra';

  @override
  String get liveCameraOff => 'Caméra off';

  @override
  String get liveEndLabel => 'Terminer';

  @override
  String get liveStartBroadcast => 'Démarrer le direct';

  @override
  String get liveConnecting => 'Connexion…';

  @override
  String get searchForGroupLabel => 'Rechercher un groupe';

  @override
  String get searchForDiscussionLabel => 'Rechercher une discussion';

  @override
  String get searchForFriendLabel => 'Rechercher un ami';

  @override
  String get searchForMemberLabel => 'Rechercher un membre';

  @override
  String get searchLabel => 'Recherche';

  @override
  String get searchDiscussionHint => 'Rechercher une discussion...';

  @override
  String get searchFriendHint => 'Rechercher un ami...';

  @override
  String get searchMembersOrGroupsHint =>
      'Rechercher des membres ou groupes...';

  @override
  String get searchMembersOrGroupsPrompt => 'Recherchez des membres ou groupes';

  @override
  String get membersSection => 'Membres';

  @override
  String get groupsSection => 'Groupes';

  @override
  String get conversationsSection => 'Discussions';

  @override
  String get memberDefault => 'Membre';

  @override
  String get friendLabel => 'Ami';

  @override
  String get conversationDefault => 'Conversation';

  @override
  String get adminConfirmDisconnect => 'Confirmer la déconnexion';

  @override
  String adminDisconnectDevicesConfirm(String userName) {
    return 'Voulez-vous vraiment déconnecter $userName de tous ses appareils ?';
  }

  @override
  String get adminNotConnectedError => 'Erreur: Admin non connecté';

  @override
  String get adminUsersTitle => 'Gestion des Utilisateurs';

  @override
  String get adminUsersDesc => 'Gérez les comptes utilisateurs et les sessions';

  @override
  String get neverConnected => 'Jamais';

  @override
  String get noEmail => 'Pas d\'email';

  @override
  String get adminRoleLabel => 'Admin';

  @override
  String get bannedLabel => 'Banni';

  @override
  String get userDefault => 'Utilisateur';

  @override
  String get adminForceDisconnect => 'Déconnecter de force';

  @override
  String get loadingUsers => 'Chargement des utilisateurs...';

  @override
  String get noUsersFound => 'Aucun utilisateur trouvé';

  @override
  String get adminTaxRatesTitle => 'Taux de TVA par catégorie';

  @override
  String get adminTaxRatesDesc =>
      'Définissez les taux applicables à chaque catégorie';

  @override
  String get adminImagesTitle => 'Images';

  @override
  String get adminImagesDesc => 'Configuration des images uploadées';

  @override
  String get adminImagesDimensionHint => 'Largeur et hauteur max';

  @override
  String get adminVideosTitle => 'Vidéos';

  @override
  String get adminVideosDesc => 'Limites pour les vidéos';

  @override
  String get adminMessagesTitle => 'Messages';

  @override
  String get adminMessagesDesc => 'Configuration des messages';

  @override
  String adminMaxValueConstraint(int max) {
    return 'Max: $max';
  }

  @override
  String get adminUrlsAndContactTitle => 'URLs & Contact';

  @override
  String get adminUrlsAndContactDesc => 'Configuration des liens et emails';

  @override
  String get adminIntervalsTitle => 'Intervalles système';

  @override
  String get adminIntervalsDesc => 'Fréquences de mise à jour';

  @override
  String get audioRoomForceCloseTitle => 'Forcer la fermeture ?';

  @override
  String get audioRoomForceButton => 'Forcer';

  @override
  String get scheduleRoomTitle => 'Programmer';

  @override
  String get scheduleRoomMultiTimezone => 'multi-fuseaux horaires';

  @override
  String get scheduleNewRoomLabel => 'Nouveau salon';

  @override
  String get errorLoadingStickers => 'Erreur lors du chargement des stickers';

  @override
  String get noRecentStickers => 'Aucun sticker récent';

  @override
  String get errorLoadingRecentStickers =>
      'Erreur lors du chargement des stickers récents';

  @override
  String get noFavoriteStickers => 'Aucun sticker favori';

  @override
  String get addToFavoritesHint => 'Appui long pour ajouter aux favoris';

  @override
  String get errorLoadingFavorites => 'Erreur lors du chargement des favoris';

  @override
  String get noStickersInPack => 'Aucun sticker dans ce pack';

  @override
  String get addToFavorites => 'Ajouter aux favoris';

  @override
  String get audioRoomForceCloseLabel => 'Forcer la fermeture';

  @override
  String get audioRoomForceCloseDesc =>
      'Le salon sera immédiatement fermé et l\'action sera auditée.';

  @override
  String get audioRoomForceCloseAuditNote => 'Action irréversible · log audit';

  @override
  String get ghostListeners => 'auditeurs visibles';

  @override
  String get ghostSpeakers => 'intervenants visibles';

  @override
  String get ghostReports => 'Signalements';

  @override
  String get ghostDuration => 'Durée';

  @override
  String get creatorEarningsTitle => 'Mes Gains';

  @override
  String get withdrawalRequestTitle => 'Demande de retrait';

  @override
  String get withdrawalAmountLabel => 'Montant à retirer';

  @override
  String get tipEarningsLabel => 'Pourboires';

  @override
  String get ticketEarningsLabel => 'Billets de salle';

  @override
  String get subscriptionEarningsLabel => 'Abonnements';

  @override
  String get replayEarningsLabel => 'Replays';

  @override
  String get totalLabel => 'Total';

  @override
  String get stripeDashboardButton => 'Tableau de bord Stripe';

  @override
  String get audioRoomVideoEnabled => 'Vidéo activée';

  @override
  String get audioRoomTicketPriceField => 'Prix du billet (€)';

  @override
  String get audioRoomEnableFundraising => 'Activer une collecte';

  @override
  String get audioRoomFundraisingGoal => 'Objectif (€)';

  @override
  String get audioRoomBeneficiary => 'Bénéficiaire';

  @override
  String get audioRoomLinkedTo => 'Lié à';

  @override
  String get audioRoomEmbassyLink => 'Ambassade';

  @override
  String get selectVideoFirst => 'Veuillez sélectionner une vidéo';

  @override
  String get subscribeButton => 'S\'abonner';

  @override
  String get previewTooltip => 'Prévisualiser';

  @override
  String get subscriptionActivated => 'Abonnement activé !';

  @override
  String get liveBadge => 'DIRECT';

  @override
  String get chaptersPill => 'Chapitres';

  @override
  String get replayBadge => 'REPLAY';

  @override
  String get sleepTimer => 'Minuteur';

  @override
  String get sleepTimerOff => 'Désactivé';

  @override
  String get saveAsPodcastTitle => 'Sauvegarder comme podcast';

  @override
  String get saveAsPodcastSubtitle => 'post-production';

  @override
  String get postPublicationTips => 'Pourboires post-publication';

  @override
  String get keepPrivate => 'Garder privé';

  @override
  String get paidRoomBadge => 'SALON PAYANT';

  @override
  String get verifiedHostBadge => 'hôte vérifié';

  @override
  String get hostShareLabel => 'Reversé à l\'hôte';

  @override
  String get paymentMethodLabel => 'MÉTHODE DE PAIEMENT';

  @override
  String get optionalMessageHint => 'Message (optionnel)…';

  @override
  String get creditCardMethod => 'Carte bancaire (Stripe)';

  @override
  String get creditCardBrands => 'Visa, Mastercard, Apple Pay, Google Pay';

  @override
  String get mobileMoneyMethod => 'Mobile Money';

  @override
  String get mobileMoneyBrands => 'Mynita, Wave (bientot)';

  @override
  String get ceremonyRoomLabel => 'Cérémonie · Diffusion famille élargie';

  @override
  String get moderatorInitialLabel => 'M';

  @override
  String get timezonesLabel => 'FUSEAUX HORAIRES';

  @override
  String get niamieyTimezoneLabel => 'GMT+1 · Niamey';

  @override
  String get kenteMotifAuto => 'Motif kente auto-généré';

  @override
  String get autoLabel => 'AUTO';

  @override
  String get laterButton => 'Plus tard';

  @override
  String get bankNameHint => 'Ex: BCEAO, Ecobank...';

  @override
  String get ibanHint => 'NEXX XXXX XXXX XXXX';

  @override
  String get adTransferTitle => 'Envoyez de l\'argent au Niger';

  @override
  String get adTransferSubtitle =>
      'Transferts rapides et sécurisés vers vos proches';

  @override
  String get adTransferCta => 'Envoyer maintenant';

  @override
  String get adGroupTitle => 'Rejoignez un groupe diaspora';

  @override
  String get adGroupSubtitle =>
      'Connectez-vous avec des Nigériens près de chez vous';

  @override
  String get adGroupCta => 'Découvrir les groupes';

  @override
  String get adMarketplaceTitle => 'Marketplace Diaspo Niger';

  @override
  String get adMarketplaceSubtitle =>
      'Achetez et vendez au sein de la communauté';

  @override
  String get adMarketplaceCta => 'Explorer le marché';

  @override
  String get adAudioRoomsTitle => 'Salons audio en direct';

  @override
  String get adAudioRoomsSubtitle => 'Rejoignez des discussions en temps réel';

  @override
  String get adAudioRoomsCta => 'Voir les salons';

  @override
  String get notifGroupOrders => 'Commandes';

  @override
  String get notifGroupProximity => 'Alertes proximité';

  @override
  String get notifGroupCalls => 'Appels';

  @override
  String get notifGroupAudioRooms => 'Salons Audio';

  @override
  String get notifGroupPodcasts => 'Podcasts';

  @override
  String get notifGroupTransfers => 'Transferts';

  @override
  String get notifGroupAll => 'Notifications';

  @override
  String notifNewMessagesCount(int count) {
    return '$count nouveaux messages';
  }

  @override
  String notifMessagesFrom(int count, int conversations) {
    return '$count messages de $conversations conversations';
  }

  @override
  String notifFriendRequestsCount(int count) {
    return '$count demandes d\'ami';
  }

  @override
  String get notifNow => 'maintenant';

  @override
  String get imageSaved => 'Image enregistrée';

  @override
  String get saveFailed => 'Échec de l\'enregistrement';

  @override
  String get videoSaved => 'Vidéo enregistrée';

  @override
  String embassiesFoundCount(int count) {
    return '$count ambassade(s) trouvée(s)';
  }

  @override
  String get embassiesHelperText =>
      'Les ambassades et consulats disponibles apparaîtront ici.';

  @override
  String get startNowLabel => 'Démarrer maintenant';

  @override
  String recipientReceives(String name) {
    return '$name reçoit';
  }

  @override
  String get sendTipYouSend => 'Vous envoyez';

  @override
  String get sendTipShownInRoomNote =>
      'Le don s\'affiche dans le salon avec votre nom.';

  @override
  String get ticketPaymentMethodCard => 'Carte bancaire';

  @override
  String get ticketPinRequired => 'Code PIN demandé pour confirmer';

  @override
  String get ticketReplayAccessNote =>
      'Le billet donne accès au salon et à son replay.';

  @override
  String ticketBuyAndJoin(String amount) {
    return 'Payer $amount et rejoindre';
  }

  @override
  String get configCompleteLabel => 'configuration complète';

  @override
  String get familyEventLabel => 'Événement familial';

  @override
  String get eventLabel => 'Événement';

  @override
  String get sessionRecorded => 'Session enregistrée';

  @override
  String get incompleteStripeConfig =>
      'Configuration incomplète. Complétez votre profil Stripe.';

  @override
  String get userNotLoggedIn => 'Utilisateur non connecté';

  @override
  String get adminBanUserTitle => 'Bannir l\'utilisateur';

  @override
  String get adminBanReasonLabel => 'Raison du bannissement:';

  @override
  String get adminUserBanned => 'Utilisateur banni';

  @override
  String get adminUnbanUserTitle => 'Débannir l\'utilisateur';

  @override
  String get adminUnbanConfirm =>
      'Êtes-vous sûr de vouloir débannir cet utilisateur ?';

  @override
  String get adminUserUnbanned => 'Utilisateur débanni';

  @override
  String get adminPromoteToAdminTitle => 'Promouvoir en admin';

  @override
  String get adminPromoteConfirm =>
      'Êtes-vous sûr de vouloir promouvoir cet utilisateur en administrateur ?';

  @override
  String get adminUserPromoted => 'Utilisateur promu admin';

  @override
  String get adminRevokeAdminTitle => 'Retirer les droits admin';

  @override
  String get adminRevokeAdminConfirm =>
      'Êtes-vous sûr de vouloir retirer les droits administrateur ?';

  @override
  String get adminAdminRightsRevoked => 'Droits admin retirés';

  @override
  String get adminCertifyUserTitle => 'Certifier l\'utilisateur';

  @override
  String adminCertifyConfirm(String name) {
    return 'Accorder la certification à $name ?';
  }

  @override
  String get adminUserCertified => 'Utilisateur certifié';

  @override
  String get adminRevokeCertTitle => 'Révoquer la certification';

  @override
  String adminRevokeCertConfirm(String name) {
    return 'Retirer la certification de $name ?';
  }

  @override
  String get adminCertRevoked => 'Certification révoquée';

  @override
  String get adminForceDisconnectConfirm =>
      'Cela déconnectera l\'utilisateur de tous ses appareils.';

  @override
  String get adminUserDisconnected => 'Utilisateur déconnecté';

  @override
  String adminDisconnectedSuccess(String name) {
    return '$name a été déconnecté.';
  }

  @override
  String get adminBusinessVerified => 'Commerce vérifié';

  @override
  String get adminVerificationRemoved => 'Vérification retirée';

  @override
  String get adminBusinessBoosted => 'Commerce boosté pour 30 jours';

  @override
  String get adminBoostRemoved => 'Boost retiré';

  @override
  String get adminDeleteBusinessTitle => 'Supprimer le commerce';

  @override
  String get adminDeleteBusinessConfirm =>
      'Êtes-vous sûr de vouloir supprimer ce commerce ? Cette action est irréversible.';

  @override
  String get adminBusinessDeleted => 'Commerce supprimé';

  @override
  String get adminProductActivated => 'Produit activé';

  @override
  String get adminProductDeactivated => 'Produit désactivé';

  @override
  String get adminDeleteProductTitle => 'Supprimer le produit';

  @override
  String get adminDeleteProductConfirm =>
      'Êtes-vous sûr de vouloir supprimer ce produit ?';

  @override
  String get adminProductDeleted => 'Produit supprimé';

  @override
  String get adminResolveDisputeTitle => 'Résoudre le litige';

  @override
  String get adminDisputeResolved => 'Litige résolu';

  @override
  String get adminCancelEventConfirm =>
      'Êtes-vous sûr de vouloir annuler cet événement ?';

  @override
  String get adminDeleteEventConfirm =>
      'Êtes-vous sûr de vouloir supprimer cet événement ? Cette action est irréversible.';

  @override
  String get adminDeleteGroupTitle => 'Supprimer le groupe';

  @override
  String get adminDeleteGroupConfirm =>
      'Êtes-vous sûr de vouloir supprimer ce groupe ? Cette action est irréversible.';

  @override
  String get adminTransactionFailReasonLabel => 'Raison de l\'échec:';

  @override
  String get adminTransactionFailed => 'Transaction marquée comme échouée';

  @override
  String get adminMarkCompleteTitle => 'Marquer comme complétée';

  @override
  String get adminMarkCompleteConfirm =>
      'Êtes-vous sûr de vouloir marquer cette transaction comme complétée ?';

  @override
  String get adminTransactionCompleted => 'Transaction complétée';

  @override
  String get adminRefundReasonLabel => 'Raison du remboursement:';

  @override
  String get adminTransactionRefunded => 'Transaction remboursée';

  @override
  String get adminUnknownAdmin => 'Admin inconnu';

  @override
  String get adminUnknownDate => 'Date inconnue';

  @override
  String adminEventByOrganizer(String id) {
    return 'Événement par $id';
  }

  @override
  String adminEventsTab(int count) {
    return 'Événements ($count)';
  }

  @override
  String get adminAvailable => 'Disponible';

  @override
  String get adminUnavailable => 'Indisponible';

  @override
  String get adminNoOrders => 'Aucune commande trouvée';

  @override
  String get adminNoDisputes => 'Aucun litige en cours';

  @override
  String adminDisputeId(String id) {
    return 'Litige #$id';
  }

  @override
  String adminDisputeReasonLabel(String reason) {
    return 'Raison: $reason';
  }

  @override
  String get adminReasonUnspecified => 'Non spécifiée';

  @override
  String get adminAmountHeader => 'Montant';

  @override
  String get adminAmountXofHeader => 'Montant en XOF';

  @override
  String get adminFailReasonHeader => 'Raison échec';

  @override
  String get adminTipAmountXof => 'Montant pourboires (XOF)';

  @override
  String get adminRoomLimitsTitle => 'Limites des salons';

  @override
  String get adminRoomLimitsSubtitle => 'Capacite et duree maximales';

  @override
  String get adminMaxDurationLabel => 'Duree max (minutes)';

  @override
  String get adminPredefinedTipsTitle => 'Montants de tips predefinis';

  @override
  String get adminPredefinedTipsSubtitle =>
      'Separes par virgule (en unites, pas en centimes)';

  @override
  String get wifiAndMobileData => 'WiFi et données mobiles';

  @override
  String get wifiOnly => 'WiFi uniquement';

  @override
  String get autoDownloads => 'Téléchargements automatiques';

  @override
  String get passphraseMinLength =>
      'La passphrase doit contenir au moins 8 caractères';

  @override
  String get backupCreatedSuccess => 'Sauvegarde créée avec succès';

  @override
  String backupCreateError(String error) {
    return 'Erreur lors de la création de la sauvegarde: $error';
  }

  @override
  String get keysRestoredSuccess => 'Clés restaurées avec succès';

  @override
  String backupCreatedOn(String date) {
    return 'Créée le: $date';
  }

  @override
  String get passphraseRequiredNote =>
      'Sans elle, vos clés ne pourront pas être restaurées.';

  @override
  String minTipAmountError(int amount, String currency) {
    return 'Montant minimum: $amount $currency';
  }

  @override
  String maxTipAmountError(int amount, String currency) {
    return 'Montant maximum: $amount $currency';
  }

  @override
  String get ghostSuperAdminBadge => 'GHOST · SuperAdmin';

  @override
  String get ghostInvisibleNotice =>
      'Vous êtes invisible : ni l\'hôte ni les participants ne voient votre présence. Toutes vos actions sont journalisées.';

  @override
  String get ghostActionsTitle => 'ACTIONS GHOST';

  @override
  String get ghostMuteSilent => 'Muet silencieux';

  @override
  String get ghostExclude => 'Exclure';

  @override
  String get ghostBlockGlobal => 'Bloquer global';

  @override
  String get ghostPickParticipantTitle => 'Choisir un participant';

  @override
  String get ghostNoParticipants => 'Aucun participant à modérer';

  @override
  String ghostActionMuted(String name) {
    return '$name est désormais muet';
  }

  @override
  String ghostActionKicked(String name) {
    return '$name a été exclu du salon';
  }

  @override
  String ghostActionBlocked(String name) {
    return '$name a été bloqué';
  }

  @override
  String get audioRoomCapacityNote => '10 intervenants · 1 000 auditeurs';

  @override
  String get audioRoomAdminLockNote =>
      '🔒 Fonctionnalités soumises aux règles administrateur.';

  @override
  String get payoutHistoryTitle => 'Historique des retraits';

  @override
  String get noWithdrawalsYet => 'Aucun retrait effectué';

  @override
  String get availableBalance => 'Solde disponible';

  @override
  String get processingEllipsis => 'Traitement…';

  @override
  String get withdrawEarnings => 'Retirer les gains';

  @override
  String get stripeConnectRequired =>
      'Configurez Stripe Connect pour activer les retraits.';

  @override
  String get earningsBreakdown => 'Répartition des gains';

  @override
  String get stripeConnectAccount => 'Compte Stripe Connect';

  @override
  String get stripeAccountActive =>
      'Votre compte est actif. Les retraits sont disponibles.';

  @override
  String get createStripePrompt =>
      'Créez un compte Stripe Connect pour recevoir vos paiements.';

  @override
  String get continueSetupButton => 'Continuer la configuration';

  @override
  String get createStripeButton => 'Créer un compte Stripe';

  @override
  String get podcastCoverLabel => 'Couverture';

  @override
  String get podcastVisibilityLabel => 'Visibilité';

  @override
  String get podcastFollowersVisibility => 'Abonnés';

  @override
  String get podcastPrivateVisibility => 'Privé';

  @override
  String get podcastVideoEpisodeLabel => 'Épisode vidéo';

  @override
  String get podcastVideoProcessing => 'Traitement vidéo en cours…';

  @override
  String get podcastEpisodeTitleLabel => 'Titre de l\'épisode';

  @override
  String get podcastAiChaptersLabel => 'Chapitres détectés par IA';

  @override
  String get scheduleRoomCaveat =>
      'Affiché à chaque membre dans son fuseau local lors du rappel.';

  @override
  String get filesLabel => 'Fichiers';

  @override
  String get embassyFormIntro =>
      'Remplissez ce formulaire pour créer une nouvelle ambassade. La demande sera vérifiée avant publication.';

  @override
  String get embassyBasicInfoSection => 'Informations de base';

  @override
  String get embassySelectType => 'Sélectionnez le type d\'établissement';

  @override
  String get embassyTypeEmbassy => 'Ambassade';

  @override
  String get embassyTypeConsulate => 'Consulat';

  @override
  String get embassyTypeMission => 'Mission diplomatique';

  @override
  String get embassyTypeDelegation => 'Délégation';

  @override
  String get embassyNameField => 'Nom *';

  @override
  String get embassyCountryField => 'Pays d\'implantation *';

  @override
  String get embassyCityField => 'Ville *';

  @override
  String get embassyAddressField => 'Adresse complète *';

  @override
  String get embassyNameRequired => 'Le nom est obligatoire';

  @override
  String get embassyCountryRequired => 'Le pays est obligatoire';

  @override
  String get embassyCityRequired => 'La ville est obligatoire';

  @override
  String get embassyAddressRequired => 'L\'adresse est obligatoire';

  @override
  String get embassyLocationSection => 'Localisation GPS (optionnel)';

  @override
  String get embassyServicesSection => 'Services proposés';

  @override
  String get embassyJurisdictionSection => 'Pays sous juridiction';

  @override
  String get embassyJurisdictionDesc =>
      'Indiquez les pays dont les ressortissants peuvent contacter cette ambassade.';

  @override
  String get embassyAddCountry => 'Ajouter un pays';

  @override
  String get embassyHoursSection => 'Horaires d\'ouverture';

  @override
  String get embassyHoursHint => 'Ex: 09:00 - 17:00 ou Fermé';

  @override
  String get embassyCreateButton => 'Créer l\'ambassade';

  @override
  String get emailInvalidError => 'Email invalide';

  @override
  String get adminDemoted => 'Rétrogradé';

  @override
  String get adminPrivacyChanged => 'Confidentialité modifiée';

  @override
  String get adminReportResolved => 'Signalement résolu';

  @override
  String get adminAvailabilityChanged => 'Disponibilité modifiée';

  @override
  String get adminConfigUpdated => 'Configuration mise à jour';

  @override
  String get adminFeatureChanged => 'Feature modifiée';

  @override
  String get adminNotificationSent => 'Notification envoyée';

  @override
  String get adminForceLogoutAction => 'Déconnexion forcée';

  @override
  String get adminAuditEmptyState =>
      'Les actions des administrateurs apparaîtront ici';

  @override
  String get adminDetailsLabel => 'Détails:';

  @override
  String get adminTransferMonitoringTitle => 'Monitoring Transferts';

  @override
  String get adminTransferMonitoringSubtitle =>
      'Suivi des transactions et volumes en temps réel';

  @override
  String get adminTransferVolume => 'Volume des Transferts';

  @override
  String get adminByCurrency => 'Détails par Devise';

  @override
  String get adminTotalVolumeUSD => 'Volume Total (USD)';

  @override
  String get adminFeesCollectedUSD => 'Frais Collectés (USD)';

  @override
  String adminFailedTab(int count) {
    return 'Échouées ($count)';
  }

  @override
  String adminCompletedTab(int count) {
    return 'Complétées ($count)';
  }

  @override
  String adminProcessedTab(int count) {
    return 'Traités ($count)';
  }

  @override
  String adminAdminsTab(int count) {
    return 'Admins ($count)';
  }

  @override
  String adminBannedTab(int count) {
    return 'Bannis ($count)';
  }

  @override
  String adminActiveTab(int count) {
    return 'Actives ($count)';
  }

  @override
  String adminSuspendedTab(int count) {
    return 'Suspendues ($count)';
  }

  @override
  String get adminMarkFailedAction => 'Échouer';

  @override
  String get adminMarkAsFailedTitle => 'Marquer comme échouée';

  @override
  String get adminTransactionDebiting => 'Débit en cours';

  @override
  String get adminTransactionInProgress => 'En cours';

  @override
  String get adminTransactionSending => 'Envoi en cours';

  @override
  String get adminTransactionCompletedLabel => 'Complétée';

  @override
  String get adminTransactionRefunding => 'Remboursement';

  @override
  String get adminActiveLabel => 'Actives';

  @override
  String get adminSuspendedLabel => 'Suspendues';

  @override
  String get adminSuspendedStatus => 'Suspendue';

  @override
  String get adminVerifiedStatus => 'Vérifiée';

  @override
  String get adminNoEmbassyPending =>
      'Aucune ambassade en attente de vérification';

  @override
  String get adminNoEmbassyActive => 'Aucune ambassade active';

  @override
  String get adminNoEmbassySuspended => 'Aucune ambassade suspendue';

  @override
  String get adminNoEmbassy => 'Aucune ambassade';

  @override
  String get adminLoadingEmbassies => 'Chargement des ambassades...';

  @override
  String get adminLoadError => 'Erreur de chargement';

  @override
  String get adminUsersManagementTitle => 'Gestion des Utilisateurs';

  @override
  String get adminUsersManagementSubtitle =>
      'Gérez les comptes, permissions et bannissements';

  @override
  String get adminNoName => 'Sans nom';

  @override
  String get adminNoEmail => 'Pas d\'email';

  @override
  String adminLastLogin(String date) {
    return 'Dernière connexion : $date';
  }

  @override
  String adminBanReason(String reason) {
    return 'Raison : $reason';
  }

  @override
  String get adminCertifiedBadge => 'CERTIFIÉ';

  @override
  String get adminAdminBadge => 'ADMIN';

  @override
  String get adminBannedBadge => 'BANNI';

  @override
  String get adminFeaturesToggleSubtitle => 'Activer/désactiver les options';

  @override
  String get adminActiveRoomsFeature => 'Salons audio actifs';

  @override
  String get adminPaidRoomsFeature => 'Salons payants';

  @override
  String get adminTipsFeature => 'Pourboires';

  @override
  String get adminPaidReplaysFeature => 'Replays payants';

  @override
  String get adminCreatorSubscriptionsFeature => 'Abonnements créateurs';

  @override
  String get adminRecordingFeature => 'Enregistrement';

  @override
  String get adminCommissionsTitle => 'Commissions';

  @override
  String get adminCommissionsSubtitle =>
      'Pourcentage prélevé par la plateforme';

  @override
  String get adminTicketsLabel => 'Tickets';

  @override
  String get adminTipsLabel => 'Pourboires';

  @override
  String get adminReplaysLabel => 'Replays';

  @override
  String get adminSubscriptionsLabel => 'Abonnements';

  @override
  String get adminPriceLimitsTitle => 'Limites de prix';

  @override
  String get adminPriceLimitsSubtitle => 'Min/Max pour les transactions';

  @override
  String get adminMinLabel => 'Min';

  @override
  String get adminMaxLabel => 'Max';

  @override
  String get adminMaxSpeakersLabel => 'Max speakers';

  @override
  String get adminMaxListenersLabel => 'Max listeners';

  @override
  String get stickerLoadError => 'Erreur de chargement des stickers';

  @override
  String get stickerNoRecent => 'Aucun sticker récent';

  @override
  String get stickerRecentLoadError =>
      'Erreur de chargement des stickers récents';

  @override
  String get stickerNoFavorites => 'Aucun sticker favori';

  @override
  String get stickerAddFavoritesHint => 'Appui long pour ajouter aux favoris';

  @override
  String get stickerFavoritesLoadError => 'Erreur de chargement des favoris';

  @override
  String get stickerPackEmpty => 'Aucun sticker dans ce pack';

  @override
  String priceConvertedFrom(String currency) {
    return 'Converti depuis $currency';
  }

  @override
  String get onboardingWelcomeTitle => 'Bienvenue sur\nDiaspo Niger';

  @override
  String get onboardingWelcomeDesc =>
      'Connectez-vous avec la diaspora nigérienne partout dans le monde. Retrouvez vos compatriotes et partagez ensemble.';

  @override
  String get onboardingDiscoverTitle => 'Découvrez les membres';

  @override
  String get onboardingDiscoverDesc =>
      'Trouvez des Nigériens près de chez vous grâce à notre carte interactive. Voyez qui habite dans votre région.';

  @override
  String get onboardingGroupsTitle => 'Rejoignez des groupes';

  @override
  String get onboardingGroupsDesc =>
      'Participez à des communautés thématiques : professionnels, étudiants, entrepreneurs... Échangez et entraidez-vous.';

  @override
  String get onboardingEventsTitle => 'Participez aux événements';

  @override
  String get onboardingEventsDesc =>
      'Organisez ou participez à des rencontres, conférences et activités culturelles de la diaspora.';

  @override
  String get onboardingConnectedTitle => 'Restez connectés';

  @override
  String get onboardingConnectedDesc =>
      'Discutez en privé avec les membres de la communauté. Créez des liens durables avec la diaspora.';

  @override
  String get adminAudioLiveSection => 'Salons Audio Live';

  @override
  String get adminAudioLiveSectionDesc =>
      'Surveillez et modérez les salons audio en direct';

  @override
  String get adminMustBeConnected =>
      'Vous devez être connecté pour sauvegarder';

  @override
  String get adminMaintenanceMode => 'Mode Maintenance';

  @override
  String get adminMaintenanceActive => 'Application en maintenance';

  @override
  String get adminMaintenanceInactive => 'Application active';

  @override
  String get adminMaintenanceWarning =>
      'L\'application sera inaccessible pour tous les utilisateurs non-admin !';

  @override
  String get adminFeaturesSubtitle => 'Activez ou désactivez les modules';

  @override
  String get featureMoneyTransfer => 'Transfert d\'argent';

  @override
  String get featureMoneyTransferDesc => 'Envoi d\'argent vers le Niger';

  @override
  String get featureMarketplaceDesc => 'Achat et vente de produits';

  @override
  String get featureBusinessDirectory => 'Annuaire Entreprises';

  @override
  String get featureBusinessDirectoryDesc =>
      'Répertoire des entreprises nigériennes';

  @override
  String get featureEventsDesc => 'Création et participation aux événements';

  @override
  String get featureGroupsDesc => 'Création et gestion des groupes';

  @override
  String get featureEmbassiesDesc => 'Services consulaires et ambassades';

  @override
  String get featureAudioRoomsDesc => 'Salons vocaux en direct et replays';

  @override
  String get featurePodcasts => 'Podcasts';

  @override
  String get featurePodcastsDesc => 'Écoute et création de podcasts';

  @override
  String get settingsImagesLabel => 'Images';

  @override
  String get manualDownload => 'Manuel (demander)';

  @override
  String get reportMessageTitle => 'Signaler le message';

  @override
  String get reportMessageSubtitle => 'Signaler ce message aux administrateurs';

  @override
  String get reportMotifLabel => 'Motif du signalement :';

  @override
  String get violenceThreats => 'Violence ou menaces';

  @override
  String get disable => 'Désactiver';

  @override
  String get noProductFound => 'Aucun produit trouvé';

  @override
  String get comingSoonShort => 'Bientôt disponible';

  @override
  String get loadingReports => 'Chargement des signalements...';

  @override
  String get noReports => 'Aucun signalement';

  @override
  String get noSearchResultsForFilter => 'Aucun résultat pour cette recherche';

  @override
  String get notVerifiedLabel => 'Non vérifié';

  @override
  String get deleteContentConfirmTitle =>
      'Êtes-vous sûr de vouloir supprimer ce contenu ?';

  @override
  String deleteContentIrreversibleDesc(String type) {
    return 'Cette action est irréversible et supprimera définitivement le $type.';
  }

  @override
  String get reportTypeConversation => 'Conversation';

  @override
  String get reportTypeEvent => 'Événement';

  @override
  String get reportTypeGroup => 'Groupe';

  @override
  String get reportTypeBusiness => 'Commerce';

  @override
  String get reportTypeProduct => 'Produit';

  @override
  String get categoryFood => 'Alimentation';

  @override
  String get categoryCrafts => 'Artisanat';

  @override
  String get categoryElectronics => 'Électronique';

  @override
  String get categoryClothing => 'Vêtements';

  @override
  String get categoryRealEstate => 'Immobilier';

  @override
  String get categoryOther => 'Standard (autres)';

  @override
  String get callDeleteError => 'Erreur lors de la suppression';

  @override
  String typingOneName(String name) {
    return '$name écrit...';
  }

  @override
  String typingTwoNames(String name1, String name2) {
    return '$name1 et $name2 écrivent...';
  }

  @override
  String typingManyNames(String name, int count) {
    return '$name et $count autres écrivent...';
  }

  @override
  String get typingSomeone => 'Quelqu\'un écrit...';

  @override
  String typingManyPeople(int count) {
    return '$count personnes écrivent...';
  }

  @override
  String get messageTypePhoto => '📷 Photo';

  @override
  String get messageTypeVideo => '🎥 Vidéo';

  @override
  String get messageTypeFile => '📄 Document';

  @override
  String get messageTypeCall => '📞 Appel';

  @override
  String get messageTypeLocation => '📍 Position';

  @override
  String get messageTypeSticker => '🎭 Sticker';

  @override
  String reportContentTitle(String target) {
    return 'Signaler $target';
  }

  @override
  String get reportTargetUser => 'cet utilisateur';

  @override
  String get reportTargetMessage => 'ce message';

  @override
  String get reportTargetConversation => 'cette conversation';

  @override
  String get reportTargetGroup => 'ce groupe';

  @override
  String get reportTargetEvent => 'cet événement';

  @override
  String get reportTargetBusiness => 'ce commerce';

  @override
  String get reportTargetProduct => 'ce produit';

  @override
  String get reportSentThanks => 'Signalement envoyé. Merci pour votre aide.';

  @override
  String get reportSendFailed => 'Erreur lors de l\'envoi du signalement';

  @override
  String get reportAlreadyReportedInfo =>
      'Vous avez déjà signalé ce contenu. Notre équipe examine votre signalement.';

  @override
  String get reportWhyQuestion => 'Pourquoi signalez-vous ce contenu ?';

  @override
  String get reportExtraDetails => 'Détails supplémentaires (optionnel)';

  @override
  String get reportedContentLabel => 'Contenu signalé';

  @override
  String get reportInfoText =>
      'Les signalements sont examinés par notre équipe de modération. Les faux signalements répétés peuvent entraîner des sanctions.';

  @override
  String get reportReasonSpam => 'Spam';

  @override
  String get reportReasonHarassment => 'Harcèlement';

  @override
  String get reportReasonInappropriate => 'Contenu inapproprié';

  @override
  String get reportReasonViolence => 'Violence';

  @override
  String get reportReasonHateSpeech => 'Discours haineux';

  @override
  String get reportReasonScam => 'Arnaque';

  @override
  String get reportReasonImpersonation => 'Usurpation d\'identité';

  @override
  String get reportReasonOther => 'Autre';

  @override
  String get maintenanceInProgress => 'Maintenance en cours';

  @override
  String get maintenanceDefaultMessage =>
      'L\'application est temporairement indisponible pour maintenance. Veuillez réessayer plus tard.';

  @override
  String get maintenanceImprovingExperience =>
      'Nous travaillons pour améliorer votre expérience.';

  @override
  String get phoneVerifTitle => 'Vérification du numéro';

  @override
  String phoneVerifEnterCodeHint(String phone) {
    return 'Entrez le code envoyé au\n$phone';
  }

  @override
  String phoneVerifSendCodeHint(String phone) {
    return 'Nous allons envoyer un code de vérification au\n$phone';
  }

  @override
  String get sendCode => 'Envoyer le code';

  @override
  String get verify => 'Vérifier';

  @override
  String get resendCode => 'Renvoyer le code';

  @override
  String resendCodeIn(int seconds) {
    return 'Renvoyer dans ${seconds}s';
  }

  @override
  String get phoneVerifSendError => 'Erreur lors de l\'envoi du code';

  @override
  String get phoneVerifEnterComplete => 'Veuillez entrer le code complet';

  @override
  String get phoneVerifResendRequired =>
      'Erreur de vérification. Veuillez renvoyer le code.';

  @override
  String get phoneVerifUserNotLoggedIn => 'Erreur : utilisateur non connecté';

  @override
  String get phoneVerifInvalidCode => 'Code invalide';

  @override
  String get phoneVerifError => 'Erreur de vérification';

  @override
  String get phoneVerifInvalidNumber => 'Numéro de téléphone invalide';

  @override
  String get phoneVerifTooManyAttempts =>
      'Trop de tentatives. Réessayez plus tard';

  @override
  String get phoneVerifQuotaExceeded => 'Quota dépassé. Réessayez plus tard';

  @override
  String get phoneVerifNetworkError =>
      'Erreur réseau. Vérifiez votre connexion';

  @override
  String get searchUsers => 'Rechercher des utilisateurs';

  @override
  String get inviteMember => 'Inviter un membre';

  @override
  String get inviteSent => 'Invitation envoyée !';

  @override
  String get inviteAlreadySent => 'Déjà invité';

  @override
  String get inviteError => 'Erreur lors de l\'invitation';

  @override
  String get receivedGroupInvitations => 'Invitations reçues';

  @override
  String invitedByName(String name) {
    return 'Invité par $name';
  }

  @override
  String get noInvitationsReceived => 'Aucune invitation en attente';

  @override
  String get myQrCode => 'Mon QR Code';

  @override
  String get scanMode => 'Scanner';

  @override
  String get shareMyQr => 'Partager mon QR';

  @override
  String get myPostsTitle => 'Mes publications';

  @override
  String get myPostsEmpty => 'Vous n\'avez pas encore publié';

  @override
  String get savedPostsTitle => 'Posts sauvegardés';

  @override
  String get savedPostsEmpty => 'Vous n\'avez pas encore sauvegardé de post';

  @override
  String get savedPostsCountLabel => 'enregistrés';

  @override
  String get exploreFeed => 'Explorer le feed';

  @override
  String get videos => 'Vidéos';

  @override
  String get texts => 'Textes';

  @override
  String get myPostsEmptyTitle => 'Votre première\npublication vous attend';

  @override
  String get myPostsEmptyBody =>
      'Partagez une nouvelle, une photo ou une question avec la diaspora.';

  @override
  String get savedPostsEmptyTitle => 'Rien d\'enregistré\npour l\'instant';

  @override
  String get savedPostsEmptyBody =>
      'Touchez le signet d\'une publication pour la garder ici.';

  @override
  String get savedPostsNote =>
      'Vos enregistrements ne sont visibles que par vous.';

  @override
  String get repostsTitle => 'Mes repartages';

  @override
  String get repostsError => 'Impossible de charger vos repartages.';

  @override
  String get repostsEmptyTitle => 'Aucun repartage';

  @override
  String get repostsEmptyBody =>
      'Repartagez une publication pour la faire découvrir à vos abonnés.';

  @override
  String get followersEmptyTitle => 'Pas encore\nd\'abonnés';

  @override
  String get followersEmptyBody =>
      'Publiez et participez pour vous faire connaître de la diaspora.';

  @override
  String get followingEmptyTitle => 'Vous ne suivez\npersonne';

  @override
  String get followingEmptyBody =>
      'Suivez des membres pour voir leurs publications dans votre fil.';

  @override
  String get searchPeopleHint => 'Rechercher une personne';

  @override
  String get suggestionsTitle => 'Suggestions';

  @override
  String get older => 'Plus ancien';

  @override
  String get trendingHashtags => 'Hashtags du moment';

  @override
  String get noPostsForFilter => 'Aucune publication chargée pour ce filtre.';

  @override
  String get todayTitle => 'Aujourd\'hui';

  @override
  String get messagesUnreadTitle => 'Messages non lus';

  @override
  String get mentions => 'Mentions';

  @override
  String get groupActive => 'Actif';

  @override
  String get groupCalm => 'Calme';

  @override
  String get settingsPrivacySecurity => 'Confidentialité et sécurité';

  @override
  String get settingsAppearanceLanguage => 'Apparence et langue';

  @override
  String get settingsHelpAbout => 'Aide et à propos';

  @override
  String get locationReciprocity =>
      'C\'est donnant-donnant : partagez votre position approximative pour voir les membres proches de vous.';

  @override
  String get locationGuarantee1 =>
      'Position approximative, jamais votre adresse exacte';

  @override
  String get locationGuarantee2 => 'Désactivable à tout moment';

  @override
  String get locationGuarantee3 =>
      'Invisible pour les comptes que vous bloquez';

  @override
  String get exploreOtherwise => 'Explorer autrement';

  @override
  String get embassyOpen => 'Ouvert';

  @override
  String get reopenExpected => 'Réouverture prévue';

  @override
  String get posts => 'posts';

  @override
  String get postSingle => 'post';

  @override
  String get shareToConversation => 'Envoyer à...';

  @override
  String get sharedFromAnotherApp => 'Partagé depuis une autre app';

  @override
  String get sharedContentSent => 'Contenu partagé avec succès';

  @override
  String get someSharedContentNotSent =>
      'Certains éléments n\'ont pas pu être partagés';

  @override
  String sharedFileCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '+$count fichier$_temp0';
  }

  @override
  String get sharedTextCount => '1 texte';

  @override
  String get exportConversation => 'Exporter la conversation';

  @override
  String get exportFormatTxt => 'Texte (.txt)';

  @override
  String get exportFormatJson => 'JSON (.json)';

  @override
  String get exportFormatHtml => 'HTML (.html)';

  @override
  String get noMessagesToExport => 'Aucun message à exporter';

  @override
  String get exportError => 'Erreur lors de l\'export';

  @override
  String get onbCitiesEyebrow => 'Niamey · Paris · Montréal · Abidjan';

  @override
  String get onbWelcomeTitle => 'Bienvenue sur\nDiaspo Niger';

  @override
  String get onbWelcomeBody =>
      'La communauté nigérienne, où qu\'elle soit : retrouvez vos proches, entraidez-vous, restez au pays même de loin.';

  @override
  String get onbWelcomeIllustration => 'illustration — la diaspora';

  @override
  String get onbMembersTitle => 'Découvrez\nles membres';

  @override
  String get onbMembersBody =>
      'Voyez qui vit près de chez vous : métier, ville d\'origine, langues parlées — de quoi trouver la bonne personne au bon moment.';

  @override
  String get onbMembersIllustration => 'illustration — carte des membres';

  @override
  String get onbMembersBullet1 =>
      'Position approximative, jamais l\'adresse exacte';

  @override
  String get onbMembersBullet2 =>
      'Vous voyez ceux qui partagent, et réciproquement';

  @override
  String get onbGroupsTitle => 'Rejoignez\ndes groupes';

  @override
  String get onbGroupsBody =>
      'Entraide de quartier, associations, promos d\'étudiants : trouvez les vôtres près de chez vous ou au pays.';

  @override
  String get onbGroupsIllustration => 'illustration — rejoindre un groupe';

  @override
  String get onbGroupsBullet1 => 'Groupes publics ou privés, à vous de choisir';

  @override
  String get onbGroupsBullet2 => 'Discussions chiffrées de bout en bout';

  @override
  String get onbEventsTitle => 'Participez aux\névénements';

  @override
  String get onbEventsBody =>
      'Fêtes, permanences administratives, rencontres sportives : inscrivez-vous en un geste et ajoutez la date à votre agenda.';

  @override
  String get onbEventsIllustration => 'illustration — fête de la République';

  @override
  String get onbEventsBullet1 => 'En présentiel ou en ligne';

  @override
  String get onbEventsBullet2 => 'Rappel avant le jour J';

  @override
  String get onbConnectedTitle => 'Restez\nconnectés';

  @override
  String get onbConnectedBody =>
      'Deux autorisations et vous êtes prêt. Vous pourrez les changer à tout moment dans Réglages.';

  @override
  String get onbConnectedIllustration => 'illustration — rester connectés';

  @override
  String get onbNotificationsSubtitle =>
      'Messages, invitations, rappels d\'événement';

  @override
  String get onbLocationSubtitle =>
      'Réciproque : vous voyez ceux qui partagent';

  @override
  String get onbLaterWithoutPermissions => 'Plus tard, sans autorisations';

  @override
  String get setupIdentityTitle => 'Faisons connaissance';

  @override
  String get setupIdentityBody =>
      'Votre nom et votre métier aident les membres à savoir qui vous êtes — et à vous solliciter au bon moment.';

  @override
  String get setupFullNameHint => 'Moussa Adamou';

  @override
  String get setupProfessionHint => 'Choisissez dans la liste';

  @override
  String get setupProfessionHelper =>
      'Choisie dans la liste : Entrepreneur, Ingénieur, Médecin, Étudiant…';

  @override
  String get setupAddPhoto => 'Ajouter une photo';

  @override
  String get setupPhotoHint => 'Optionnel · vos initiales sinon';

  @override
  String get setupYourPhoto => 'Votre photo';

  @override
  String get setupLocationBody =>
      'C\'est ce qui vous place sur la carte des membres et fait remonter les groupes et événements de votre ville.';

  @override
  String get setupCityHint => 'Paris, Niamey, New York…';

  @override
  String get setupOriginCityHint => 'Précisez votre ville d\'origine';

  @override
  String get setupShareLocationSubtitle =>
      'Réciproque : vous voyez les membres proches, ils vous voient';

  @override
  String get setupLocationPrivacyNote =>
      'Position approximative uniquement · modifiable dans Réglages';

  @override
  String get setupInterestsBody =>
      'Ils personnalisent le fil et les suggestions de groupes. Choisissez-en au moins deux.';

  @override
  String get setupNoneSelected => 'Aucun sélectionné';

  @override
  String setupSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sélectionnés',
      one: '1 sélectionné',
      zero: 'Aucun sélectionné',
    );
    return '$_temp0';
  }

  @override
  String get setupWhatYouGet => 'Ce que vous recevrez';

  @override
  String get setupThemeBody =>
      'Le mode sombre économise la batterie sur écran OLED. Modifiable à tout moment dans Réglages.';

  @override
  String get setupAccentColor => 'Couleur d\'accent';

  @override
  String get setupAllSet => 'Tout est prêt';

  @override
  String setupAllSetNamed(String name) {
    return 'Tout est prêt, $name';
  }

  @override
  String setupCompletionSummary(int percent) {
    return 'Profil complété à $percent % : vous êtes visible sur la carte des membres et dans la recherche.';
  }

  @override
  String setupCompletionSummaryCity(int percent, String city) {
    return 'Profil complété à $percent % : vous êtes visible sur la carte des membres de $city et dans la recherche.';
  }

  @override
  String get setupHandleInvalid => 'Choisissez un nom d\'utilisateur libre';

  @override
  String get setupErrorConnection =>
      'Erreur de connexion. Vérifiez votre connexion internet.';

  @override
  String get setupErrorNotSignedIn =>
      'Utilisateur non connecté. Veuillez vous reconnecter.';

  @override
  String get setupErrorProfileMissing =>
      'Profil introuvable. Veuillez redémarrer l\'application.';

  @override
  String setupErrorGeneric(String details) {
    return 'Erreur : $details';
  }

  @override
  String get handleLabel => 'Nom d\'utilisateur';

  @override
  String get handleExample => 'moussa';

  @override
  String get handleHint =>
      'Sert à vous retrouver et à vous mentionner · optionnel';

  @override
  String get handleAvailableHint =>
      'Disponible · sert à vous retrouver et à vous mentionner';

  @override
  String get handleTaken => 'Ce nom d\'utilisateur est déjà pris';

  @override
  String get handleFormat => '3 à 20 caractères : lettres, chiffres, _';

  @override
  String messagesActiveGroups(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count groupes actifs',
      one: '1 groupe actif',
      zero: 'Aucun groupe actif',
    );
    return '$_temp0';
  }

  @override
  String groupsJoinedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rejoints',
      one: '1 rejoint',
      zero: '0 rejoint',
    );
    return '$_temp0';
  }

  @override
  String groupsPendingInvites(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count invitations',
      one: '1 invitation',
      zero: 'Aucune invitation',
    );
    return '$_temp0';
  }

  @override
  String notificationsUnreadCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count non lues',
      one: '1 non lue',
      zero: 'Aucune non lue',
    );
    return '$_temp0';
  }

  @override
  String get homeServiceFeed => 'Le fil';

  @override
  String homeNobodyWithin(int km) {
    return 'Personne à moins de $km km';
  }

  @override
  String get homeLocationActiveNote =>
      'Votre position est active : vous apparaîtrez dès qu\'un membre partagera la sienne.';

  @override
  String get homeWidenRadius => 'Élargir à 200 km';

  @override
  String get homeInviteRelative => 'Inviter un proche';

  @override
  String get homeNotOnMapTitle => 'Vous n\'apparaissez pas sur la carte';

  @override
  String get homeNotOnMapBody =>
      'Le partage est réciproque : sans votre position, vous ne voyez pas non plus les autres.';

  @override
  String get homeEnableLocation => 'Activer ma position';

  @override
  String get homeOfflineTitle => 'Vous êtes hors ligne';

  @override
  String get homeOfflineBody =>
      'Contenu affiché depuis le cache. Mise à jour automatique au retour du réseau.';

  @override
  String get homeCompleteProfile => 'Complétez votre profil';

  @override
  String homeGroupsToDiscover(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count groupes à découvrir',
      one: '1 groupe à découvrir',
    );
    return '$_temp0';
  }

  @override
  String get homeFindYourCommunity => 'Trouvez votre communauté';

  @override
  String get homeGettingStarted => 'POUR COMMENCER';

  @override
  String get homeFindRelatives => 'Retrouver vos proches';

  @override
  String get homeFindRelativesSub => 'Par QR code, sans échanger de numéro';

  @override
  String get homeJoinGroup => 'Rejoindre un groupe';

  @override
  String get homeEnableMemberMap => 'Activer la carte des membres';

  @override
  String get homeEnableMemberMapSub => 'Réciproque · désactivable';

  @override
  String homeFirstMeetupCity(String city) {
    return 'Un thé, un match, une aide aux papiers : soyez le premier à réunir la communauté de $city.';
  }

  @override
  String get homeFirstMeetup =>
      'Un thé, un match, une aide aux papiers : soyez le premier à réunir la communauté.';

  @override
  String get homeStartFirstMeetup => 'Lancez la première rencontre';

  @override
  String get homeEventChipPaperwork => 'Démarches';

  @override
  String homeNoEventInCity(String city) {
    return 'Aucun événement à $city';
  }

  @override
  String get homeNoInPersonEvent => 'Aucun événement en présentiel';

  @override
  String get homeOnlineWorkshopNote =>
      'Un atelier en ligne est accessible depuis chez vous.';

  @override
  String get homeNothingPlanned => 'Rien de prévu pour le moment';

  @override
  String homeLastEventGathered(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Le dernier a réuni $count personnes.',
      one: 'Le dernier a réuni 1 personne.',
    );
    return '$_temp0';
  }

  @override
  String get homeReviveCommunity =>
      'Relancez la communauté avec un nouvel événement.';

  @override
  String get homeNotifyNext => 'M\'avertir du prochain';

  @override
  String get homeAddCity => 'Ajouter ma ville';

  @override
  String get homeAddCountry => 'Ajouter mon pays';

  @override
  String get homeAddProfession => 'Ajouter mon métier';

  @override
  String get homeFieldProfession => 'métier';

  @override
  String get homeCompleteBio => 'Compléter ma bio';

  @override
  String get homeShareInvite =>
      'Rejoins-moi sur Diaspo Niger, la communauté nigérienne à travers le monde.';

  @override
  String get groupsSuggestedForYou => 'Suggéré pour toi';

  @override
  String get groupsActionUnavailable =>
      'Action impossible pour le moment, réessayez.';

  @override
  String get groupsDetailsUnavailable => 'Détails indisponibles.';

  @override
  String groupSeeAllMembers(int count) {
    return 'Voir tous les $count membres';
  }

  @override
  String get groupRoleModerator => 'Modé';

  @override
  String get messagesMyNotes => 'Mes notes';

  @override
  String get messagesMyNotesSubtitle => 'Notes, brouillons et sondages';

  @override
  String get callStatusMissed => 'manqué';

  @override
  String get callStatusDeclined => 'refusé';

  @override
  String get callKindVideo => 'vidéo';

  @override
  String notificationsGroupedMessages(int count, int conversations) {
    return '$count messages de $conversations conversations';
  }

  @override
  String get profileCompletionPhotoBenefit =>
      'Vous serez plus facilement reconnu';

  @override
  String get profileCompletionCityBenefit =>
      'Vous apparaîtrez auprès des membres proches';

  @override
  String get profileFieldOccupation => 'Métier';

  @override
  String get profileCompletionJobBenefit => 'Utile pour les mises en relation';

  @override
  String get profileCompletionBioBenefit => 'Présentez-vous à la communauté';

  @override
  String get profileCompleteYours => 'Complétez votre profil';

  @override
  String get profileCompleteMine => 'Compléter mon profil';

  @override
  String profileBlockConfirm(String name) {
    return 'Voulez-vous vraiment bloquer $name ? Vous ne recevrez plus de messages de sa part.';
  }

  @override
  String profileCommonGroups(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count groupes en commun',
      one: '1 groupe en commun',
    );
    return '$_temp0';
  }

  @override
  String profileAcceptError(String details) {
    return 'Erreur lors de l\'acceptation : $details';
  }

  @override
  String get profileRequestGoneDetail =>
      'Cette demande n\'existe plus. Elle a peut-être déjà été acceptée ou annulée.';

  @override
  String get searchRecent => 'Recherches récentes';

  @override
  String get searchAnything => 'Rechercher...';

  @override
  String get homeServiceTransfers => 'transferts d\'argent';

  @override
  String get homeServiceShop => 'boutique';

  @override
  String get homeServiceEmbassies => 'ambassades';

  @override
  String homeA11yServices(String list) {
    return 'Accès rapide aux services : $list.';
  }

  @override
  String get homeSearchableMembers => 'membres';

  @override
  String get homeSearchableGroups => 'groupes';

  @override
  String get homeSearchableEvents => 'événements';

  @override
  String homeA11ySearch(String list) {
    return 'Trouvez des $list facilement.';
  }

  @override
  String homeA11yStats(String list) {
    return 'Découvrez la communauté : nombre de $list. Appuyez pour explorer.';
  }

  @override
  String get listSeparatorAnd => ' et ';

  @override
  String profileCompletionMessage(int count, String fields, String place) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$fields vous rendent visible auprès de la communauté$place.',
      one: '$fields vous rend visible auprès de la communauté$place.',
    );
    return '$_temp0';
  }

  @override
  String profileCompletionField(String field) {
    return 'votre $field';
  }

  @override
  String profileCompletionPlace(String city) {
    return ' de $city';
  }

  @override
  String get homeFieldPhoto => 'photo';

  @override
  String get homeFieldCity => 'ville';

  @override
  String get homeFieldCountry => 'pays';

  @override
  String get homeFieldBio => 'bio';

  @override
  String get recordingGestureHints =>
      'Glisser ‹ pour annuler · ↑ pour verrouiller';

  @override
  String get releaseToCancelNow => 'Relâcher pour annuler';

  @override
  String get recordingWillBeDeleted => 'L\'enregistrement sera supprimé';

  @override
  String get recordingLockedBadge => 'Verrouillé';

  @override
  String get recordingHandsFree => 'Mains libres — vous pouvez lâcher l’écran';

  @override
  String get pollLabel => 'Sondage';

  @override
  String get mediaBlurredPreview => 'aperçu flouté';

  @override
  String mediaBlurredPreviewSize(String size) {
    return 'aperçu flouté · $size';
  }

  @override
  String get moreActions => 'Autres actions';

  @override
  String get ghostMuteSilentNote =>
      '« Muet en silence » ne prévient pas la personne : son micro cesse d’être diffusé, sans message d’erreur.';

  @override
  String get podcastsEpisodeSavedDraft => 'Épisode enregistré en brouillon';

  @override
  String get profileStatPosts => 'Publications';

  @override
  String get filterUnreadFeminine => 'Non lues';

  @override
  String get whoCanSeeMyNumber => 'Qui peut voir mon numéro ?';

  @override
  String get changePhotoAction => 'Modifier la photo';
}
