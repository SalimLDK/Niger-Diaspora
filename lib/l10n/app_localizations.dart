import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr')
  ];

  /// No description provided for @appTitle.
  ///
  /// In fr, this message translates to:
  /// **'Niger Diaspora'**
  String get appTitle;

  /// No description provided for @welcomeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Bienvenue'**
  String get welcomeTitle;

  /// No description provided for @joinDiaspora.
  ///
  /// In fr, this message translates to:
  /// **'Rejoins la diaspora nigérienne'**
  String get joinDiaspora;

  /// No description provided for @continueWithGoogle.
  ///
  /// In fr, this message translates to:
  /// **'Continuer avec Google'**
  String get continueWithGoogle;

  /// No description provided for @or.
  ///
  /// In fr, this message translates to:
  /// **'ou'**
  String get or;

  /// No description provided for @password.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe'**
  String get password;

  /// No description provided for @confirmPassword.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer le mot de passe'**
  String get confirmPassword;

  /// No description provided for @signIn.
  ///
  /// In fr, this message translates to:
  /// **'Se connecter'**
  String get signIn;

  /// No description provided for @signUp.
  ///
  /// In fr, this message translates to:
  /// **'S\'inscrire'**
  String get signUp;

  /// No description provided for @noAccount.
  ///
  /// In fr, this message translates to:
  /// **'Pas encore de compte ?'**
  String get noAccount;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In fr, this message translates to:
  /// **'Déjà un compte ?'**
  String get alreadyHaveAccount;

  /// No description provided for @createAccount.
  ///
  /// In fr, this message translates to:
  /// **'Créer un compte'**
  String get createAccount;

  /// No description provided for @joinCommunity.
  ///
  /// In fr, this message translates to:
  /// **'Rejoins la communauté nigérienne'**
  String get joinCommunity;

  /// No description provided for @enterEmail.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez entrer votre email'**
  String get enterEmail;

  /// No description provided for @invalidEmail.
  ///
  /// In fr, this message translates to:
  /// **'Email invalide'**
  String get invalidEmail;

  /// No description provided for @enterPassword.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez entrer votre mot de passe'**
  String get enterPassword;

  /// No description provided for @enterAPassword.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez entrer un mot de passe'**
  String get enterAPassword;

  /// No description provided for @passwordTooShort.
  ///
  /// In fr, this message translates to:
  /// **'Le mot de passe doit contenir au moins 6 caractères'**
  String get passwordTooShort;

  /// No description provided for @enterName.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez entrer votre nom'**
  String get enterName;

  /// No description provided for @nameTooShort.
  ///
  /// In fr, this message translates to:
  /// **'Le nom doit contenir au moins 2 caractères'**
  String get nameTooShort;

  /// No description provided for @confirmPasswordRequired.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez confirmer le mot de passe'**
  String get confirmPasswordRequired;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In fr, this message translates to:
  /// **'Les mots de passe ne correspondent pas'**
  String get passwordsDoNotMatch;

  /// No description provided for @termsAgreement.
  ///
  /// In fr, this message translates to:
  /// **'En vous inscrivant, vous acceptez nos Conditions d\'utilisation et notre Politique de confidentialité.'**
  String get termsAgreement;

  /// No description provided for @settings.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres'**
  String get settings;

  /// No description provided for @account.
  ///
  /// In fr, this message translates to:
  /// **'Compte'**
  String get account;

  /// No description provided for @editProfile.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le profil'**
  String get editProfile;

  /// No description provided for @myProfile.
  ///
  /// In fr, this message translates to:
  /// **'Mon profil'**
  String get myProfile;

  /// No description provided for @email.
  ///
  /// In fr, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @notDefined.
  ///
  /// In fr, this message translates to:
  /// **'Non défini'**
  String get notDefined;

  /// No description provided for @notifications.
  ///
  /// In fr, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @pushNotifications.
  ///
  /// In fr, this message translates to:
  /// **'Notifications push'**
  String get pushNotifications;

  /// No description provided for @receiveNotifications.
  ///
  /// In fr, this message translates to:
  /// **'Recevoir des notifications'**
  String get receiveNotifications;

  /// No description provided for @notificationPreferences.
  ///
  /// In fr, this message translates to:
  /// **'Préférences de notification'**
  String get notificationPreferences;

  /// No description provided for @messages.
  ///
  /// In fr, this message translates to:
  /// **'Messages'**
  String get messages;

  /// No description provided for @newEvents.
  ///
  /// In fr, this message translates to:
  /// **'Nouveaux événements'**
  String get newEvents;

  /// No description provided for @groupActivity.
  ///
  /// In fr, this message translates to:
  /// **'Activité des groupes'**
  String get groupActivity;

  /// No description provided for @eventReminders.
  ///
  /// In fr, this message translates to:
  /// **'Rappels d\'événements'**
  String get eventReminders;

  /// No description provided for @privacy.
  ///
  /// In fr, this message translates to:
  /// **'Confidentialité'**
  String get privacy;

  /// No description provided for @visibleProfile.
  ///
  /// In fr, this message translates to:
  /// **'Profil visible'**
  String get visibleProfile;

  /// No description provided for @appearInSearches.
  ///
  /// In fr, this message translates to:
  /// **'Apparaître dans les recherches'**
  String get appearInSearches;

  /// No description provided for @shareLocation.
  ///
  /// In fr, this message translates to:
  /// **'Partager ma position'**
  String get shareLocation;

  /// No description provided for @appearOnMap.
  ///
  /// In fr, this message translates to:
  /// **'Apparaître sur la carte'**
  String get appearOnMap;

  /// No description provided for @blockedUsers.
  ///
  /// In fr, this message translates to:
  /// **'Utilisateurs bloqués'**
  String get blockedUsers;

  /// No description provided for @noBlockedUsers.
  ///
  /// In fr, this message translates to:
  /// **'Aucun utilisateur bloqué'**
  String get noBlockedUsers;

  /// No description provided for @unblock.
  ///
  /// In fr, this message translates to:
  /// **'Débloquer'**
  String get unblock;

  /// No description provided for @blockUser.
  ///
  /// In fr, this message translates to:
  /// **'Bloquer l\'utilisateur'**
  String get blockUser;

  /// No description provided for @userBlocked.
  ///
  /// In fr, this message translates to:
  /// **'Utilisateur bloqué'**
  String get userBlocked;

  /// No description provided for @userUnblocked.
  ///
  /// In fr, this message translates to:
  /// **'Utilisateur débloqué'**
  String get userUnblocked;

  /// No description provided for @blockedOn.
  ///
  /// In fr, this message translates to:
  /// **'Bloqué le {date}'**
  String blockedOn(String date);

  /// No description provided for @application.
  ///
  /// In fr, this message translates to:
  /// **'Application'**
  String get application;

  /// No description provided for @theme.
  ///
  /// In fr, this message translates to:
  /// **'Thème'**
  String get theme;

  /// No description provided for @light.
  ///
  /// In fr, this message translates to:
  /// **'Clair'**
  String get light;

  /// No description provided for @dark.
  ///
  /// In fr, this message translates to:
  /// **'Sombre'**
  String get dark;

  /// No description provided for @system.
  ///
  /// In fr, this message translates to:
  /// **'Système'**
  String get system;

  /// No description provided for @chooseTheme.
  ///
  /// In fr, this message translates to:
  /// **'Choisir le thème'**
  String get chooseTheme;

  /// No description provided for @language.
  ///
  /// In fr, this message translates to:
  /// **'Langue'**
  String get language;

  /// No description provided for @french.
  ///
  /// In fr, this message translates to:
  /// **'Français'**
  String get french;

  /// No description provided for @english.
  ///
  /// In fr, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @chooseLanguage.
  ///
  /// In fr, this message translates to:
  /// **'Choisir la langue'**
  String get chooseLanguage;

  /// No description provided for @helpAndSupport.
  ///
  /// In fr, this message translates to:
  /// **'Aide & Support'**
  String get helpAndSupport;

  /// No description provided for @contactUs.
  ///
  /// In fr, this message translates to:
  /// **'Nous contacter'**
  String get contactUs;

  /// No description provided for @reportBug.
  ///
  /// In fr, this message translates to:
  /// **'Signaler un bug'**
  String get reportBug;

  /// No description provided for @giveFeedback.
  ///
  /// In fr, this message translates to:
  /// **'Donner un avis'**
  String get giveFeedback;

  /// No description provided for @bugReportTitle.
  ///
  /// In fr, this message translates to:
  /// **'Signaler un bug'**
  String get bugReportTitle;

  /// No description provided for @bugDescription.
  ///
  /// In fr, this message translates to:
  /// **'Description du bug'**
  String get bugDescription;

  /// No description provided for @bugDescriptionHint.
  ///
  /// In fr, this message translates to:
  /// **'Décrivez le problème rencontré...'**
  String get bugDescriptionHint;

  /// No description provided for @stepsToReproduce.
  ///
  /// In fr, this message translates to:
  /// **'Étapes pour reproduire (optionnel)'**
  String get stepsToReproduce;

  /// No description provided for @stepsHint.
  ///
  /// In fr, this message translates to:
  /// **'1. Ouvrir l\'application\n2. ...'**
  String get stepsHint;

  /// No description provided for @send.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer'**
  String get send;

  /// No description provided for @bugReportSent.
  ///
  /// In fr, this message translates to:
  /// **'Rapport de bug envoyé'**
  String get bugReportSent;

  /// No description provided for @feedbackSent.
  ///
  /// In fr, this message translates to:
  /// **'Merci pour votre avis !'**
  String get feedbackSent;

  /// No description provided for @about.
  ///
  /// In fr, this message translates to:
  /// **'À propos'**
  String get about;

  /// No description provided for @version.
  ///
  /// In fr, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @lastUpdate.
  ///
  /// In fr, this message translates to:
  /// **'Dernière mise à jour'**
  String get lastUpdate;

  /// No description provided for @versionInfo.
  ///
  /// In fr, this message translates to:
  /// **'Version {version} - Dernière mise à jour : {date}'**
  String versionInfo(String version, String date);

  /// No description provided for @appDescription.
  ///
  /// In fr, this message translates to:
  /// **'Plateforme de mise en relation de la diaspora nigérienne.'**
  String get appDescription;

  /// No description provided for @termsOfService.
  ///
  /// In fr, this message translates to:
  /// **'Conditions d\'utilisation'**
  String get termsOfService;

  /// No description provided for @privacyPolicy.
  ///
  /// In fr, this message translates to:
  /// **'Politique de confidentialité'**
  String get privacyPolicy;

  /// No description provided for @legalUpdateTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mise à jour des conditions'**
  String get legalUpdateTitle;

  /// No description provided for @legalUpdateDescription.
  ///
  /// In fr, this message translates to:
  /// **'Nos conditions d\'utilisation et/ou notre politique de confidentialité ont été mises à jour. Veuillez les lire et les accepter pour continuer à utiliser l\'application.'**
  String get legalUpdateDescription;

  /// No description provided for @summaryOfChanges.
  ///
  /// In fr, this message translates to:
  /// **'Résumé des changements :'**
  String get summaryOfChanges;

  /// No description provided for @iAcceptThe.
  ///
  /// In fr, this message translates to:
  /// **'J\'accepte les '**
  String get iAcceptThe;

  /// No description provided for @iAccept.
  ///
  /// In fr, this message translates to:
  /// **'J\'accepte la '**
  String get iAccept;

  /// No description provided for @acceptAndContinue.
  ///
  /// In fr, this message translates to:
  /// **'Accepter et continuer'**
  String get acceptAndContinue;

  /// No description provided for @dangerZone.
  ///
  /// In fr, this message translates to:
  /// **'Zone de danger'**
  String get dangerZone;

  /// No description provided for @logout.
  ///
  /// In fr, this message translates to:
  /// **'Déconnexion'**
  String get logout;

  /// No description provided for @deleteAccount.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer mon compte'**
  String get deleteAccount;

  /// No description provided for @confirmLogout.
  ///
  /// In fr, this message translates to:
  /// **'Voulez-vous vraiment vous déconnecter ?'**
  String get confirmLogout;

  /// No description provided for @confirmDeleteAccount.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le compte'**
  String get confirmDeleteAccount;

  /// No description provided for @deleteAccountWarning.
  ///
  /// In fr, this message translates to:
  /// **'Cette action est irréversible. Toutes vos données seront supprimées définitivement.\n\nCela inclut :\n• Votre profil et vos informations personnelles\n• Vos conversations et messages\n• Vos événements créés\n• Votre participation aux groupes'**
  String get deleteAccountWarning;

  /// No description provided for @continueAction.
  ///
  /// In fr, this message translates to:
  /// **'Continuer'**
  String get continueAction;

  /// No description provided for @finalConfirmation.
  ///
  /// In fr, this message translates to:
  /// **'Confirmation finale'**
  String get finalConfirmation;

  /// No description provided for @typeDeleteToConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Pour confirmer la suppression, tapez \"SUPPRIMER\" ci-dessous :'**
  String get typeDeleteToConfirm;

  /// No description provided for @deleteKeyword.
  ///
  /// In fr, this message translates to:
  /// **'SUPPRIMER'**
  String get deleteKeyword;

  /// No description provided for @deletePermanently.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer définitivement'**
  String get deletePermanently;

  /// No description provided for @deletingAccount.
  ///
  /// In fr, this message translates to:
  /// **'Suppression du compte en cours...'**
  String get deletingAccount;

  /// No description provided for @accountDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Votre compte a été supprimé avec succès'**
  String get accountDeleted;

  /// No description provided for @deleteError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la suppression. Veuillez vous reconnecter et réessayer.'**
  String get deleteError;

  /// No description provided for @cancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer'**
  String get confirm;

  /// No description provided for @save.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get save;

  /// No description provided for @close.
  ///
  /// In fr, this message translates to:
  /// **'Fermer'**
  String get close;

  /// No description provided for @error.
  ///
  /// In fr, this message translates to:
  /// **'Erreur'**
  String get error;

  /// No description provided for @success.
  ///
  /// In fr, this message translates to:
  /// **'Succès'**
  String get success;

  /// No description provided for @loading.
  ///
  /// In fr, this message translates to:
  /// **'Chargement...'**
  String get loading;

  /// No description provided for @conversationOptions.
  ///
  /// In fr, this message translates to:
  /// **'Options de la conversation'**
  String get conversationOptions;

  /// No description provided for @mute.
  ///
  /// In fr, this message translates to:
  /// **'Mettre en sourdine'**
  String get mute;

  /// No description provided for @unmute.
  ///
  /// In fr, this message translates to:
  /// **'Réactiver les notifications'**
  String get unmute;

  /// No description provided for @muteConversation.
  ///
  /// In fr, this message translates to:
  /// **'Conversation mise en sourdine'**
  String get muteConversation;

  /// No description provided for @unmuteConversation.
  ///
  /// In fr, this message translates to:
  /// **'Notifications réactivées'**
  String get unmuteConversation;

  /// No description provided for @archive.
  ///
  /// In fr, this message translates to:
  /// **'Archiver'**
  String get archive;

  /// No description provided for @unarchive.
  ///
  /// In fr, this message translates to:
  /// **'Désarchiver'**
  String get unarchive;

  /// No description provided for @archiveConversation.
  ///
  /// In fr, this message translates to:
  /// **'Conversation archivée'**
  String get archiveConversation;

  /// No description provided for @unarchiveConversation.
  ///
  /// In fr, this message translates to:
  /// **'Conversation désarchivée'**
  String get unarchiveConversation;

  /// No description provided for @deleteConversation.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer la conversation'**
  String get deleteConversation;

  /// No description provided for @confirmDeleteConversation.
  ///
  /// In fr, this message translates to:
  /// **'Voulez-vous vraiment supprimer cette conversation ? Cette action est irréversible.'**
  String get confirmDeleteConversation;

  /// No description provided for @conversationDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Conversation supprimée'**
  String get conversationDeleted;

  /// No description provided for @reportConversation.
  ///
  /// In fr, this message translates to:
  /// **'Signaler'**
  String get reportConversation;

  /// No description provided for @reportReason.
  ///
  /// In fr, this message translates to:
  /// **'Motif du signalement'**
  String get reportReason;

  /// No description provided for @spam.
  ///
  /// In fr, this message translates to:
  /// **'Spam'**
  String get spam;

  /// No description provided for @harassment.
  ///
  /// In fr, this message translates to:
  /// **'Harcèlement'**
  String get harassment;

  /// No description provided for @inappropriateContent.
  ///
  /// In fr, this message translates to:
  /// **'Contenu inapproprié'**
  String get inappropriateContent;

  /// No description provided for @other.
  ///
  /// In fr, this message translates to:
  /// **'Autre'**
  String get other;

  /// No description provided for @reportSent.
  ///
  /// In fr, this message translates to:
  /// **'Signalement envoyé'**
  String get reportSent;

  /// No description provided for @reportDescription.
  ///
  /// In fr, this message translates to:
  /// **'Description (optionnel)'**
  String get reportDescription;

  /// No description provided for @messagesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Messages'**
  String get messagesTitle;

  /// No description provided for @archives.
  ///
  /// In fr, this message translates to:
  /// **'Archives'**
  String get archives;

  /// No description provided for @searchPlaceholder.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher...'**
  String get searchPlaceholder;

  /// No description provided for @noConversation.
  ///
  /// In fr, this message translates to:
  /// **'Aucune conversation'**
  String get noConversation;

  /// No description provided for @startChatting.
  ///
  /// In fr, this message translates to:
  /// **'Commencez à discuter avec les membres de la diaspora'**
  String get startChatting;

  /// No description provided for @newConversation.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle conversation'**
  String get newConversation;

  /// No description provided for @noResults.
  ///
  /// In fr, this message translates to:
  /// **'Aucun résultat pour \"{query}\"'**
  String noResults(String query);

  /// No description provided for @noArchivedConversation.
  ///
  /// In fr, this message translates to:
  /// **'Aucune conversation archivée'**
  String get noArchivedConversation;

  /// No description provided for @loadingError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur de chargement'**
  String get loadingError;

  /// No description provided for @retry.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get retry;

  /// No description provided for @noMessages.
  ///
  /// In fr, this message translates to:
  /// **'Aucun message'**
  String get noMessages;

  /// No description provided for @sendFirstMessage.
  ///
  /// In fr, this message translates to:
  /// **'Envoyez le premier message !'**
  String get sendFirstMessage;

  /// No description provided for @group.
  ///
  /// In fr, this message translates to:
  /// **'Groupe'**
  String get group;

  /// No description provided for @conversation.
  ///
  /// In fr, this message translates to:
  /// **'Conversation'**
  String get conversation;

  /// No description provided for @newConversationTitle.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle conversation'**
  String get newConversationTitle;

  /// No description provided for @start.
  ///
  /// In fr, this message translates to:
  /// **'Démarrer'**
  String get start;

  /// No description provided for @searchMember.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un membre...'**
  String get searchMember;

  /// No description provided for @createGroupWith.
  ///
  /// In fr, this message translates to:
  /// **'Créer un groupe avec {count} membres'**
  String createGroupWith(int count);

  /// No description provided for @groupName.
  ///
  /// In fr, this message translates to:
  /// **'Nom du groupe'**
  String get groupName;

  /// No description provided for @enterGroupName.
  ///
  /// In fr, this message translates to:
  /// **'Entrez le nom du groupe'**
  String get enterGroupName;

  /// No description provided for @create.
  ///
  /// In fr, this message translates to:
  /// **'Créer'**
  String get create;

  /// No description provided for @searchAMember.
  ///
  /// In fr, this message translates to:
  /// **'Recherchez un membre'**
  String get searchAMember;

  /// No description provided for @enterAtLeast2Chars.
  ///
  /// In fr, this message translates to:
  /// **'Entrez au moins 2 caractères'**
  String get enterAtLeast2Chars;

  /// No description provided for @user.
  ///
  /// In fr, this message translates to:
  /// **'Utilisateur'**
  String get user;

  /// No description provided for @eventsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Événements'**
  String get eventsTitle;

  /// No description provided for @all.
  ///
  /// In fr, this message translates to:
  /// **'Tous'**
  String get all;

  /// No description provided for @noUpcomingEvents.
  ///
  /// In fr, this message translates to:
  /// **'Aucun événement à venir'**
  String get noUpcomingEvents;

  /// No description provided for @online.
  ///
  /// In fr, this message translates to:
  /// **'En ligne'**
  String get online;

  /// No description provided for @participants.
  ///
  /// In fr, this message translates to:
  /// **'{count} participants'**
  String participants(int count);

  /// No description provided for @seeMore.
  ///
  /// In fr, this message translates to:
  /// **'Voir plus'**
  String get seeMore;

  /// No description provided for @createEvent.
  ///
  /// In fr, this message translates to:
  /// **'Créer un événement'**
  String get createEvent;

  /// No description provided for @eventDetails.
  ///
  /// In fr, this message translates to:
  /// **'Détails de l\'événement'**
  String get eventDetails;

  /// No description provided for @join.
  ///
  /// In fr, this message translates to:
  /// **'Participer'**
  String get join;

  /// No description provided for @leave.
  ///
  /// In fr, this message translates to:
  /// **'Quitter'**
  String get leave;

  /// No description provided for @joined.
  ///
  /// In fr, this message translates to:
  /// **'Inscrit'**
  String get joined;

  /// No description provided for @organizedBy.
  ///
  /// In fr, this message translates to:
  /// **'Organisé par'**
  String get organizedBy;

  /// No description provided for @organizer.
  ///
  /// In fr, this message translates to:
  /// **'Organisateur'**
  String get organizer;

  /// No description provided for @aboutEvent.
  ///
  /// In fr, this message translates to:
  /// **'À propos'**
  String get aboutEvent;

  /// No description provided for @startingFrom.
  ///
  /// In fr, this message translates to:
  /// **'À partir de {time}'**
  String startingFrom(String time);

  /// No description provided for @noParticipantsYet.
  ///
  /// In fr, this message translates to:
  /// **'Aucun participant pour le moment'**
  String get noParticipantsYet;

  /// No description provided for @othersMore.
  ///
  /// In fr, this message translates to:
  /// **'+{count} autres'**
  String othersMore(int count);

  /// No description provided for @delete.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In fr, this message translates to:
  /// **'Modifier'**
  String get edit;

  /// No description provided for @participate.
  ///
  /// In fr, this message translates to:
  /// **'Participer'**
  String get participate;

  /// No description provided for @full.
  ///
  /// In fr, this message translates to:
  /// **'Complet'**
  String get full;

  /// No description provided for @registrationConfirmed.
  ///
  /// In fr, this message translates to:
  /// **'Inscription confirmée !'**
  String get registrationConfirmed;

  /// No description provided for @cancelParticipation.
  ///
  /// In fr, this message translates to:
  /// **'Annuler la participation'**
  String get cancelParticipation;

  /// No description provided for @cancelParticipationConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Voulez-vous vraiment annuler votre participation ?'**
  String get cancelParticipationConfirm;

  /// No description provided for @no.
  ///
  /// In fr, this message translates to:
  /// **'Non'**
  String get no;

  /// No description provided for @yesCancel.
  ///
  /// In fr, this message translates to:
  /// **'Oui, annuler'**
  String get yesCancel;

  /// No description provided for @participationCancelled.
  ///
  /// In fr, this message translates to:
  /// **'Participation annulée'**
  String get participationCancelled;

  /// No description provided for @deleteEvent.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer l\'événement'**
  String get deleteEvent;

  /// No description provided for @deleteEventConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Voulez-vous vraiment supprimer cet événement ? Cette action est irréversible.'**
  String get deleteEventConfirm;

  /// No description provided for @eventDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Événement supprimé'**
  String get eventDeleted;

  /// No description provided for @addedToCalendar.
  ///
  /// In fr, this message translates to:
  /// **'Événement ajouté au calendrier'**
  String get addedToCalendar;

  /// No description provided for @cannotAddToCalendar.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'ajouter au calendrier'**
  String get cannotAddToCalendar;

  /// No description provided for @calendar.
  ///
  /// In fr, this message translates to:
  /// **'Calendrier'**
  String get calendar;

  /// No description provided for @eventCategoryCultural.
  ///
  /// In fr, this message translates to:
  /// **'Culturel'**
  String get eventCategoryCultural;

  /// No description provided for @eventCategoryProfessional.
  ///
  /// In fr, this message translates to:
  /// **'Professionnel'**
  String get eventCategoryProfessional;

  /// No description provided for @eventCategorySocial.
  ///
  /// In fr, this message translates to:
  /// **'Social'**
  String get eventCategorySocial;

  /// No description provided for @eventCategorySport.
  ///
  /// In fr, this message translates to:
  /// **'Sport'**
  String get eventCategorySport;

  /// No description provided for @eventCategoryOther.
  ///
  /// In fr, this message translates to:
  /// **'Autre'**
  String get eventCategoryOther;

  /// No description provided for @groupsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Groupes'**
  String get groupsTitle;

  /// No description provided for @noGroups.
  ///
  /// In fr, this message translates to:
  /// **'Aucun groupe'**
  String get noGroups;

  /// No description provided for @myGroups.
  ///
  /// In fr, this message translates to:
  /// **'Mes groupes'**
  String get myGroups;

  /// No description provided for @searchGroup.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un groupe...'**
  String get searchGroup;

  /// No description provided for @noJoinedGroups.
  ///
  /// In fr, this message translates to:
  /// **'Vous n\'avez rejoint aucun groupe'**
  String get noJoinedGroups;

  /// No description provided for @noGroupsToDiscover.
  ///
  /// In fr, this message translates to:
  /// **'Aucun nouveau groupe à découvrir'**
  String get noGroupsToDiscover;

  /// No description provided for @groupJoined.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez rejoint le groupe'**
  String get groupJoined;

  /// No description provided for @leaveGroupTitle.
  ///
  /// In fr, this message translates to:
  /// **'Quitter le groupe'**
  String get leaveGroupTitle;

  /// No description provided for @leaveGroupConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Voulez-vous vraiment quitter ce groupe ?'**
  String get leaveGroupConfirm;

  /// No description provided for @groupLeft.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez quitté le groupe'**
  String get groupLeft;

  /// No description provided for @member.
  ///
  /// In fr, this message translates to:
  /// **'Membre'**
  String get member;

  /// No description provided for @joinGroup.
  ///
  /// In fr, this message translates to:
  /// **'Rejoindre'**
  String get joinGroup;

  /// No description provided for @leaveGroup.
  ///
  /// In fr, this message translates to:
  /// **'Quitter'**
  String get leaveGroup;

  /// No description provided for @members.
  ///
  /// In fr, this message translates to:
  /// **'{count} membres'**
  String members(int count);

  /// No description provided for @createGroup.
  ///
  /// In fr, this message translates to:
  /// **'Créer un groupe'**
  String get createGroup;

  /// No description provided for @groupDetails.
  ///
  /// In fr, this message translates to:
  /// **'Détails du groupe'**
  String get groupDetails;

  /// No description provided for @groupDescription.
  ///
  /// In fr, this message translates to:
  /// **'Description du groupe'**
  String get groupDescription;

  /// No description provided for @admins.
  ///
  /// In fr, this message translates to:
  /// **'Admins'**
  String get admins;

  /// No description provided for @private.
  ///
  /// In fr, this message translates to:
  /// **'Privé'**
  String get private;

  /// No description provided for @public.
  ///
  /// In fr, this message translates to:
  /// **'Public'**
  String get public;

  /// No description provided for @access.
  ///
  /// In fr, this message translates to:
  /// **'Accès'**
  String get access;

  /// No description provided for @aboutGroup.
  ///
  /// In fr, this message translates to:
  /// **'À propos'**
  String get aboutGroup;

  /// No description provided for @createdBy.
  ///
  /// In fr, this message translates to:
  /// **'Créé par {name}'**
  String createdBy(String name);

  /// No description provided for @creator.
  ///
  /// In fr, this message translates to:
  /// **'Créateur'**
  String get creator;

  /// No description provided for @discussion.
  ///
  /// In fr, this message translates to:
  /// **'Discussion'**
  String get discussion;

  /// No description provided for @joinTheGroup.
  ///
  /// In fr, this message translates to:
  /// **'Rejoindre le groupe'**
  String get joinTheGroup;

  /// No description provided for @errorOpeningDiscussion.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de l\'ouverture de la discussion'**
  String get errorOpeningDiscussion;

  /// No description provided for @friendsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Amis'**
  String get friendsTitle;

  /// No description provided for @friends.
  ///
  /// In fr, this message translates to:
  /// **'Amis'**
  String get friends;

  /// No description provided for @received.
  ///
  /// In fr, this message translates to:
  /// **'Reçues'**
  String get received;

  /// No description provided for @sent.
  ///
  /// In fr, this message translates to:
  /// **'Envoyées'**
  String get sent;

  /// No description provided for @noFriends.
  ///
  /// In fr, this message translates to:
  /// **'Aucun ami'**
  String get noFriends;

  /// No description provided for @noFriendsHint.
  ///
  /// In fr, this message translates to:
  /// **'Commencez à ajouter des amis pour les voir ici'**
  String get noFriendsHint;

  /// No description provided for @noRequests.
  ///
  /// In fr, this message translates to:
  /// **'Aucune demande'**
  String get noRequests;

  /// No description provided for @receivedRequestsHint.
  ///
  /// In fr, this message translates to:
  /// **'Les demandes d\'amis reçues apparaîtront ici'**
  String get receivedRequestsHint;

  /// No description provided for @sentRequestsHint.
  ///
  /// In fr, this message translates to:
  /// **'Les demandes d\'amis envoyées apparaîtront ici'**
  String get sentRequestsHint;

  /// No description provided for @sendMessage.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer un message'**
  String get sendMessage;

  /// No description provided for @cancelRequest.
  ///
  /// In fr, this message translates to:
  /// **'Annuler la demande'**
  String get cancelRequest;

  /// No description provided for @acceptRequest.
  ///
  /// In fr, this message translates to:
  /// **'Accepter'**
  String get acceptRequest;

  /// No description provided for @declineRequest.
  ///
  /// In fr, this message translates to:
  /// **'Refuser'**
  String get declineRequest;

  /// No description provided for @removeFriend.
  ///
  /// In fr, this message translates to:
  /// **'Retirer des amis'**
  String get removeFriend;

  /// No description provided for @removeFriendConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Voulez-vous vraiment retirer cette personne de vos amis ?'**
  String get removeFriendConfirm;

  /// No description provided for @friendRemoved.
  ///
  /// In fr, this message translates to:
  /// **'Ami retiré'**
  String get friendRemoved;

  /// No description provided for @requestCancelled.
  ///
  /// In fr, this message translates to:
  /// **'Demande annulée'**
  String get requestCancelled;

  /// No description provided for @requestAccepted.
  ///
  /// In fr, this message translates to:
  /// **'Demande acceptée'**
  String get requestAccepted;

  /// No description provided for @requestDeclined.
  ///
  /// In fr, this message translates to:
  /// **'Demande refusée'**
  String get requestDeclined;

  /// No description provided for @profileTitle.
  ///
  /// In fr, this message translates to:
  /// **'Profil'**
  String get profileTitle;

  /// No description provided for @editProfileTitle.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le profil'**
  String get editProfileTitle;

  /// No description provided for @firstName.
  ///
  /// In fr, this message translates to:
  /// **'Prénom'**
  String get firstName;

  /// No description provided for @lastName.
  ///
  /// In fr, this message translates to:
  /// **'Nom'**
  String get lastName;

  /// No description provided for @bio.
  ///
  /// In fr, this message translates to:
  /// **'Bio'**
  String get bio;

  /// No description provided for @profession.
  ///
  /// In fr, this message translates to:
  /// **'Profession'**
  String get profession;

  /// No description provided for @city.
  ///
  /// In fr, this message translates to:
  /// **'Ville'**
  String get city;

  /// No description provided for @country.
  ///
  /// In fr, this message translates to:
  /// **'Pays'**
  String get country;

  /// No description provided for @phoneNumber.
  ///
  /// In fr, this message translates to:
  /// **'Numéro de téléphone'**
  String get phoneNumber;

  /// No description provided for @saveChanges.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer les modifications'**
  String get saveChanges;

  /// No description provided for @profileUpdated.
  ///
  /// In fr, this message translates to:
  /// **'Profil mis à jour'**
  String get profileUpdated;

  /// No description provided for @profileUpdatedSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Profil mis à jour avec succès'**
  String get profileUpdatedSuccess;

  /// No description provided for @changePhoto.
  ///
  /// In fr, this message translates to:
  /// **'Changer la photo'**
  String get changePhoto;

  /// No description provided for @basicInfo.
  ///
  /// In fr, this message translates to:
  /// **'Informations de base'**
  String get basicInfo;

  /// No description provided for @fullName.
  ///
  /// In fr, this message translates to:
  /// **'Nom complet'**
  String get fullName;

  /// No description provided for @enterYourName.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez entrer votre nom'**
  String get enterYourName;

  /// No description provided for @phone.
  ///
  /// In fr, this message translates to:
  /// **'Téléphone'**
  String get phone;

  /// No description provided for @location.
  ///
  /// In fr, this message translates to:
  /// **'Localisation'**
  String get location;

  /// No description provided for @currentCity.
  ///
  /// In fr, this message translates to:
  /// **'Ville actuelle'**
  String get currentCity;

  /// No description provided for @originCity.
  ///
  /// In fr, this message translates to:
  /// **'Ville d\'origine au Niger'**
  String get originCity;

  /// No description provided for @interests.
  ///
  /// In fr, this message translates to:
  /// **'Centres d\'intérêt'**
  String get interests;

  /// No description provided for @spokenLanguages.
  ///
  /// In fr, this message translates to:
  /// **'Langues parlées'**
  String get spokenLanguages;

  /// No description provided for @otherMembersCanSee.
  ///
  /// In fr, this message translates to:
  /// **'Les autres membres peuvent voir votre profil'**
  String get otherMembersCanSee;

  /// No description provided for @connections.
  ///
  /// In fr, this message translates to:
  /// **'Connexions'**
  String get connections;

  /// No description provided for @myLocation.
  ///
  /// In fr, this message translates to:
  /// **'Ma localisation'**
  String get myLocation;

  /// No description provided for @preferences.
  ///
  /// In fr, this message translates to:
  /// **'Préférences'**
  String get preferences;

  /// No description provided for @darkTheme.
  ///
  /// In fr, this message translates to:
  /// **'Thème sombre'**
  String get darkTheme;

  /// No description provided for @disabled.
  ///
  /// In fr, this message translates to:
  /// **'Désactivé'**
  String get disabled;

  /// No description provided for @helpFaq.
  ///
  /// In fr, this message translates to:
  /// **'Aide & FAQ'**
  String get helpFaq;

  /// No description provided for @homeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Accueil'**
  String get homeTitle;

  /// No description provided for @discover.
  ///
  /// In fr, this message translates to:
  /// **'Découvrir'**
  String get discover;

  /// No description provided for @welcome.
  ///
  /// In fr, this message translates to:
  /// **'Bienvenue'**
  String get welcome;

  /// No description provided for @hello.
  ///
  /// In fr, this message translates to:
  /// **'Bonjour'**
  String get hello;

  /// No description provided for @membersLabel.
  ///
  /// In fr, this message translates to:
  /// **'Membres'**
  String get membersLabel;

  /// No description provided for @membersNearby.
  ///
  /// In fr, this message translates to:
  /// **'Membres à proximité'**
  String get membersNearby;

  /// No description provided for @noMembersNearby.
  ///
  /// In fr, this message translates to:
  /// **'Aucun membre à proximité'**
  String get noMembersNearby;

  /// No description provided for @searchMembersGroups.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher des membres, groupes...'**
  String get searchMembersGroups;

  /// No description provided for @createOrJoinEvents.
  ///
  /// In fr, this message translates to:
  /// **'Créez ou rejoignez des événements'**
  String get createOrJoinEvents;

  /// No description provided for @upcomingEvents.
  ///
  /// In fr, this message translates to:
  /// **'Événements à venir'**
  String get upcomingEvents;

  /// No description provided for @popularGroups.
  ///
  /// In fr, this message translates to:
  /// **'Groupes populaires'**
  String get popularGroups;

  /// No description provided for @recentMembers.
  ///
  /// In fr, this message translates to:
  /// **'Membres récents'**
  String get recentMembers;

  /// No description provided for @seeAll.
  ///
  /// In fr, this message translates to:
  /// **'Voir tout'**
  String get seeAll;

  /// No description provided for @mapTitle.
  ///
  /// In fr, this message translates to:
  /// **'Carte'**
  String get mapTitle;

  /// No description provided for @searchTitle.
  ///
  /// In fr, this message translates to:
  /// **'Recherche'**
  String get searchTitle;

  /// No description provided for @notificationsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// No description provided for @noNotifications.
  ///
  /// In fr, this message translates to:
  /// **'Aucune notification'**
  String get noNotifications;

  /// No description provided for @noNotificationsHint.
  ///
  /// In fr, this message translates to:
  /// **'Vous serez notifié des nouvelles activités'**
  String get noNotificationsHint;

  /// No description provided for @markAllAsRead.
  ///
  /// In fr, this message translates to:
  /// **'Tout marquer comme lu'**
  String get markAllAsRead;

  /// No description provided for @deleteAll.
  ///
  /// In fr, this message translates to:
  /// **'Tout supprimer'**
  String get deleteAll;

  /// No description provided for @deleteAllNotifications.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer toutes les notifications'**
  String get deleteAllNotifications;

  /// No description provided for @deleteAllNotificationsConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Voulez-vous vraiment supprimer toutes vos notifications ?'**
  String get deleteAllNotificationsConfirm;

  /// No description provided for @justNow.
  ///
  /// In fr, this message translates to:
  /// **'À l\'instant'**
  String get justNow;

  /// No description provided for @minutesAgo.
  ///
  /// In fr, this message translates to:
  /// **'Il y a {count} min'**
  String minutesAgo(int count);

  /// No description provided for @hoursAgo.
  ///
  /// In fr, this message translates to:
  /// **'Il y a {count} h'**
  String hoursAgo(int count);

  /// No description provided for @daysAgo.
  ///
  /// In fr, this message translates to:
  /// **'Il y a {count} j'**
  String daysAgo(int count);

  /// No description provided for @participantsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Participants'**
  String get participantsTitle;

  /// No description provided for @errorNetwork.
  ///
  /// In fr, this message translates to:
  /// **'Pas de connexion internet. Vérifiez votre connexion et réessayez.'**
  String get errorNetwork;

  /// No description provided for @errorServer.
  ///
  /// In fr, this message translates to:
  /// **'Erreur du serveur. Veuillez réessayer plus tard.'**
  String get errorServer;

  /// No description provided for @errorCache.
  ///
  /// In fr, this message translates to:
  /// **'Erreur de lecture des données locales.'**
  String get errorCache;

  /// No description provided for @errorAuth.
  ///
  /// In fr, this message translates to:
  /// **'Erreur d\'authentification. Veuillez vous reconnecter.'**
  String get errorAuth;

  /// No description provided for @errorTimeout.
  ///
  /// In fr, this message translates to:
  /// **'La requête a expiré. Veuillez réessayer.'**
  String get errorTimeout;

  /// No description provided for @errorUnknown.
  ///
  /// In fr, this message translates to:
  /// **'Une erreur inattendue s\'est produite.'**
  String get errorUnknown;

  /// No description provided for @offlineMode.
  ///
  /// In fr, this message translates to:
  /// **'Mode hors ligne'**
  String get offlineMode;

  /// No description provided for @offlineBannerMessage.
  ///
  /// In fr, this message translates to:
  /// **'Vous êtes hors ligne. Certaines fonctionnalités peuvent être limitées.'**
  String get offlineBannerMessage;

  /// No description provided for @retryIn.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer dans {seconds}s'**
  String retryIn(int seconds);

  /// No description provided for @connectionRestored.
  ///
  /// In fr, this message translates to:
  /// **'Connexion rétablie'**
  String get connectionRestored;

  /// No description provided for @eventTitle.
  ///
  /// In fr, this message translates to:
  /// **'Titre de l\'événement'**
  String get eventTitle;

  /// No description provided for @eventTitleRequired.
  ///
  /// In fr, this message translates to:
  /// **'Titre de l\'événement *'**
  String get eventTitleRequired;

  /// No description provided for @eventTitleHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex: Rencontre entrepreneurs Niger'**
  String get eventTitleHint;

  /// No description provided for @eventTitleRequiredError.
  ///
  /// In fr, this message translates to:
  /// **'Le titre est requis'**
  String get eventTitleRequiredError;

  /// No description provided for @eventTitleTooShort.
  ///
  /// In fr, this message translates to:
  /// **'Le titre doit contenir au moins 5 caractères'**
  String get eventTitleTooShort;

  /// No description provided for @description.
  ///
  /// In fr, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @descriptionRequired.
  ///
  /// In fr, this message translates to:
  /// **'Description *'**
  String get descriptionRequired;

  /// No description provided for @descriptionHint.
  ///
  /// In fr, this message translates to:
  /// **'Décrivez votre événement...'**
  String get descriptionHint;

  /// No description provided for @descriptionRequiredError.
  ///
  /// In fr, this message translates to:
  /// **'La description est requise'**
  String get descriptionRequiredError;

  /// No description provided for @descriptionTooShort.
  ///
  /// In fr, this message translates to:
  /// **'La description doit contenir au moins 20 caractères'**
  String get descriptionTooShort;

  /// No description provided for @category.
  ///
  /// In fr, this message translates to:
  /// **'Catégorie'**
  String get category;

  /// No description provided for @startDateTime.
  ///
  /// In fr, this message translates to:
  /// **'Date et heure de début *'**
  String get startDateTime;

  /// No description provided for @endDateTimeOptional.
  ///
  /// In fr, this message translates to:
  /// **'Date et heure de fin (optionnel)'**
  String get endDateTimeOptional;

  /// No description provided for @endDate.
  ///
  /// In fr, this message translates to:
  /// **'Date de fin'**
  String get endDate;

  /// No description provided for @endTime.
  ///
  /// In fr, this message translates to:
  /// **'Heure de fin'**
  String get endTime;

  /// No description provided for @onlineEvent.
  ///
  /// In fr, this message translates to:
  /// **'Événement en ligne'**
  String get onlineEvent;

  /// No description provided for @onlineEventDescription.
  ///
  /// In fr, this message translates to:
  /// **'L\'événement se déroule en visioconférence'**
  String get onlineEventDescription;

  /// No description provided for @videoConferenceLink.
  ///
  /// In fr, this message translates to:
  /// **'Lien de la visioconférence'**
  String get videoConferenceLink;

  /// No description provided for @videoConferenceLinkHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex: https://zoom.us/j/...'**
  String get videoConferenceLinkHint;

  /// No description provided for @locationRequired.
  ///
  /// In fr, this message translates to:
  /// **'Lieu *'**
  String get locationRequired;

  /// No description provided for @locationHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex: Paris, France'**
  String get locationHint;

  /// No description provided for @locationRequiredError.
  ///
  /// In fr, this message translates to:
  /// **'Le lieu est requis'**
  String get locationRequiredError;

  /// No description provided for @addressOptional.
  ///
  /// In fr, this message translates to:
  /// **'Adresse (optionnel)'**
  String get addressOptional;

  /// No description provided for @addressHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex: 123 Rue de la Paix'**
  String get addressHint;

  /// No description provided for @maxAttendeesOptional.
  ///
  /// In fr, this message translates to:
  /// **'Nombre max de participants (optionnel)'**
  String get maxAttendeesOptional;

  /// No description provided for @maxAttendeesHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex: 50'**
  String get maxAttendeesHint;

  /// No description provided for @unlimitedAttendees.
  ///
  /// In fr, this message translates to:
  /// **'Laissez vide pour un nombre illimité'**
  String get unlimitedAttendees;

  /// No description provided for @createEventButton.
  ///
  /// In fr, this message translates to:
  /// **'Créer l\'événement'**
  String get createEventButton;

  /// No description provided for @editEvent.
  ///
  /// In fr, this message translates to:
  /// **'Modifier l\'événement'**
  String get editEvent;

  /// No description provided for @saveModifications.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer les modifications'**
  String get saveModifications;

  /// No description provided for @eventCreatedSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Événement créé avec succès'**
  String get eventCreatedSuccess;

  /// No description provided for @eventCreationError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la création'**
  String get eventCreationError;

  /// No description provided for @eventUpdatedSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Événement modifié avec succès'**
  String get eventUpdatedSuccess;

  /// No description provided for @eventUpdateError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la modification'**
  String get eventUpdateError;

  /// No description provided for @youAreHere.
  ///
  /// In fr, this message translates to:
  /// **'Vous êtes ici'**
  String get youAreHere;

  /// No description provided for @viewProfile.
  ///
  /// In fr, this message translates to:
  /// **'Voir le profil'**
  String get viewProfile;

  /// No description provided for @message.
  ///
  /// In fr, this message translates to:
  /// **'Message'**
  String get message;

  /// No description provided for @searchRadius.
  ///
  /// In fr, this message translates to:
  /// **'Rayon de recherche'**
  String get searchRadius;

  /// No description provided for @searchRadiusDescription.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionnez la distance maximale pour trouver des membres'**
  String get searchRadiusDescription;

  /// No description provided for @wholeCountry.
  ///
  /// In fr, this message translates to:
  /// **'Pays entier'**
  String get wholeCountry;

  /// No description provided for @countryLabel.
  ///
  /// In fr, this message translates to:
  /// **'Pays'**
  String get countryLabel;

  /// No description provided for @filterAll.
  ///
  /// In fr, this message translates to:
  /// **'Tous'**
  String get filterAll;

  /// No description provided for @filterEntrepreneurs.
  ///
  /// In fr, this message translates to:
  /// **'Entrepreneurs'**
  String get filterEntrepreneurs;

  /// No description provided for @filterStudents.
  ///
  /// In fr, this message translates to:
  /// **'Étudiants'**
  String get filterStudents;

  /// No description provided for @filterProfessionals.
  ///
  /// In fr, this message translates to:
  /// **'Professionnels'**
  String get filterProfessionals;

  /// No description provided for @filterArtists.
  ///
  /// In fr, this message translates to:
  /// **'Artistes'**
  String get filterArtists;

  /// No description provided for @enableLocationServices.
  ///
  /// In fr, this message translates to:
  /// **'Activez les services de localisation'**
  String get enableLocationServices;

  /// No description provided for @locationPermissionDenied.
  ///
  /// In fr, this message translates to:
  /// **'Permission de localisation refusée'**
  String get locationPermissionDenied;

  /// No description provided for @unableToGetLocation.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'obtenir la position'**
  String get unableToGetLocation;

  /// No description provided for @settingsLabel.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres'**
  String get settingsLabel;

  /// No description provided for @modifyYourInfo.
  ///
  /// In fr, this message translates to:
  /// **'Modifier vos informations'**
  String get modifyYourInfo;

  /// No description provided for @myFriends.
  ///
  /// In fr, this message translates to:
  /// **'Mes amis'**
  String get myFriends;

  /// No description provided for @manageConnections.
  ///
  /// In fr, this message translates to:
  /// **'Gérer vos connexions'**
  String get manageConnections;

  /// No description provided for @shareMyProfile.
  ///
  /// In fr, this message translates to:
  /// **'Partager mon profil'**
  String get shareMyProfile;

  /// No description provided for @qrCodeAndShareLink.
  ///
  /// In fr, this message translates to:
  /// **'QR code et lien de partage'**
  String get qrCodeAndShareLink;

  /// No description provided for @manageAlerts.
  ///
  /// In fr, this message translates to:
  /// **'Gérer vos alertes'**
  String get manageAlerts;

  /// No description provided for @appearInSearchesDesc.
  ///
  /// In fr, this message translates to:
  /// **'Apparaître dans les recherches'**
  String get appearInSearchesDesc;

  /// No description provided for @appearOnMapDesc.
  ///
  /// In fr, this message translates to:
  /// **'Apparaître sur la carte'**
  String get appearOnMapDesc;

  /// No description provided for @receiveNotificationsDesc.
  ///
  /// In fr, this message translates to:
  /// **'Recevoir des notifications'**
  String get receiveNotificationsDesc;

  /// No description provided for @supportEmail.
  ///
  /// In fr, this message translates to:
  /// **'support@diasponiger.com'**
  String get supportEmail;

  /// No description provided for @helpUsImprove.
  ///
  /// In fr, this message translates to:
  /// **'Aidez-nous à améliorer l\'app'**
  String get helpUsImprove;

  /// No description provided for @rateUsOnStore.
  ///
  /// In fr, this message translates to:
  /// **'Notez-nous sur le store'**
  String get rateUsOnStore;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le compte'**
  String get deleteAccountTitle;

  /// No description provided for @accountDeletedSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Votre compte a été supprimé avec succès'**
  String get accountDeletedSuccess;

  /// No description provided for @errorDeletingAccount.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la suppression'**
  String get errorDeletingAccount;

  /// No description provided for @allRightsReserved.
  ///
  /// In fr, this message translates to:
  /// **'© 2024 Niger Diaspora. Tous droits réservés.'**
  String get allRightsReserved;

  /// No description provided for @mobileAppDescription.
  ///
  /// In fr, this message translates to:
  /// **'Plateforme mobile de mise en relation de la diaspora nigérienne.'**
  String get mobileAppDescription;

  /// No description provided for @currentCountry.
  ///
  /// In fr, this message translates to:
  /// **'Pays actuel'**
  String get currentCountry;

  /// No description provided for @originRegion.
  ///
  /// In fr, this message translates to:
  /// **'Région d\'origine'**
  String get originRegion;

  /// No description provided for @skills.
  ///
  /// In fr, this message translates to:
  /// **'Compétences'**
  String get skills;

  /// No description provided for @languagesSpoken.
  ///
  /// In fr, this message translates to:
  /// **'Langues'**
  String get languagesSpoken;

  /// No description provided for @profileNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Profil non trouvé'**
  String get profileNotFound;

  /// No description provided for @livingIn.
  ///
  /// In fr, this message translates to:
  /// **'Vit à {city}, {country}'**
  String livingIn(String city, String country);

  /// No description provided for @fromRegion.
  ///
  /// In fr, this message translates to:
  /// **'Originaire de {region}'**
  String fromRegion(String region);

  /// No description provided for @fromCity.
  ///
  /// In fr, this message translates to:
  /// **'Originaire de {city}'**
  String fromCity(String city);

  /// No description provided for @scanQRCode.
  ///
  /// In fr, this message translates to:
  /// **'Scanner un QR code'**
  String get scanQRCode;

  /// No description provided for @scanQRCodeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Scanner un profil'**
  String get scanQRCodeTitle;

  /// No description provided for @scanQRCodeDescription.
  ///
  /// In fr, this message translates to:
  /// **'Placez le QR code dans le cadre pour scanner'**
  String get scanQRCodeDescription;

  /// No description provided for @qrCodeScanned.
  ///
  /// In fr, this message translates to:
  /// **'QR code scanné avec succès'**
  String get qrCodeScanned;

  /// No description provided for @invalidQRCode.
  ///
  /// In fr, this message translates to:
  /// **'QR code invalide'**
  String get invalidQRCode;

  /// No description provided for @cameraPermissionDenied.
  ///
  /// In fr, this message translates to:
  /// **'Permission caméra refusée'**
  String get cameraPermissionDenied;

  /// No description provided for @enableFlash.
  ///
  /// In fr, this message translates to:
  /// **'Activer le flash'**
  String get enableFlash;

  /// No description provided for @disableFlash.
  ///
  /// In fr, this message translates to:
  /// **'Désactiver le flash'**
  String get disableFlash;

  /// No description provided for @switchCamera.
  ///
  /// In fr, this message translates to:
  /// **'Changer de caméra'**
  String get switchCamera;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'fr': return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
