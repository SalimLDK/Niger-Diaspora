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
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
  ];

  /// No description provided for @callControlMic.
  ///
  /// In fr, this message translates to:
  /// **'Micro'**
  String get callControlMic;

  /// No description provided for @callControlMicOff.
  ///
  /// In fr, this message translates to:
  /// **'Micro coupé'**
  String get callControlMicOff;

  /// No description provided for @callControlSpeaker.
  ///
  /// In fr, this message translates to:
  /// **'Haut-parleur'**
  String get callControlSpeaker;

  /// No description provided for @callControlEarpiece.
  ///
  /// In fr, this message translates to:
  /// **'Écouteur'**
  String get callControlEarpiece;

  /// No description provided for @callControlCamera.
  ///
  /// In fr, this message translates to:
  /// **'Caméra'**
  String get callControlCamera;

  /// No description provided for @callControlVideo.
  ///
  /// In fr, this message translates to:
  /// **'Vidéo'**
  String get callControlVideo;

  /// No description provided for @callControlFlip.
  ///
  /// In fr, this message translates to:
  /// **'Retourner'**
  String get callControlFlip;

  /// No description provided for @callControlHold.
  ///
  /// In fr, this message translates to:
  /// **'Pause'**
  String get callControlHold;

  /// No description provided for @callControlResume.
  ///
  /// In fr, this message translates to:
  /// **'Reprendre'**
  String get callControlResume;

  /// No description provided for @hangUp.
  ///
  /// In fr, this message translates to:
  /// **'Raccrocher'**
  String get hangUp;

  /// No description provided for @supportPromptHeader.
  ///
  /// In fr, this message translates to:
  /// **'Par quoi commencer ?'**
  String get supportPromptHeader;

  /// No description provided for @supportPromptTransfer.
  ///
  /// In fr, this message translates to:
  /// **'Un transfert est bloqué'**
  String get supportPromptTransfer;

  /// No description provided for @supportPromptAccount.
  ///
  /// In fr, this message translates to:
  /// **'Je n\'accède pas à mon compte'**
  String get supportPromptAccount;

  /// No description provided for @supportPromptBug.
  ///
  /// In fr, this message translates to:
  /// **'Un problème technique'**
  String get supportPromptBug;

  /// No description provided for @supportAutoAttached.
  ///
  /// In fr, this message translates to:
  /// **'Joint automatiquement'**
  String get supportAutoAttached;

  /// No description provided for @appTitle.
  ///
  /// In fr, this message translates to:
  /// **'Diaspo Niger'**
  String get appTitle;

  /// No description provided for @you.
  ///
  /// In fr, this message translates to:
  /// **'Vous'**
  String get you;

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

  /// No description provided for @emailMissingAt.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez le @, par exemple nom@exemple.com'**
  String get emailMissingAt;

  /// No description provided for @emailMissingDomain.
  ///
  /// In fr, this message translates to:
  /// **'Il manque la fin de l\'adresse, par exemple .com'**
  String get emailMissingDomain;

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

  /// No description provided for @blockedUsersConsequences.
  ///
  /// In fr, this message translates to:
  /// **'La personne bloquée ne peut plus vous envoyer de messages, ni voir votre position ou votre statut en ligne. Elle n\'est pas informée du blocage.'**
  String get blockedUsersConsequences;

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

  /// No description provided for @security.
  ///
  /// In fr, this message translates to:
  /// **'Sécurité'**
  String get security;

  /// No description provided for @keyBackup.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarde des clés'**
  String get keyBackup;

  /// No description provided for @keyBackupSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Protégez vos messages chiffrés'**
  String get keyBackupSubtitle;

  /// No description provided for @connectedDevices.
  ///
  /// In fr, this message translates to:
  /// **'Appareils connectés'**
  String get connectedDevices;

  /// No description provided for @connectedDevicesSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Gérez vos appareils (max 5)'**
  String get connectedDevicesSubtitle;

  /// No description provided for @endToEndEncryption.
  ///
  /// In fr, this message translates to:
  /// **'Chiffrement de bout en bout'**
  String get endToEndEncryption;

  /// No description provided for @e2eeDescription.
  ///
  /// In fr, this message translates to:
  /// **'Vos messages sont chiffrés de bout en bout. Seuls vous et vos correspondants pouvez les lire.'**
  String get e2eeDescription;

  /// No description provided for @createBackup.
  ///
  /// In fr, this message translates to:
  /// **'Créer une sauvegarde'**
  String get createBackup;

  /// No description provided for @restoreBackup.
  ///
  /// In fr, this message translates to:
  /// **'Restaurer la sauvegarde'**
  String get restoreBackup;

  /// No description provided for @passphrase.
  ///
  /// In fr, this message translates to:
  /// **'Passphrase'**
  String get passphrase;

  /// No description provided for @passphraseHint.
  ///
  /// In fr, this message translates to:
  /// **'Minimum 8 caractères'**
  String get passphraseHint;

  /// No description provided for @confirmPassphrase.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer la passphrase'**
  String get confirmPassphrase;

  /// No description provided for @generatePassphrase.
  ///
  /// In fr, this message translates to:
  /// **'Générer une passphrase sécurisée'**
  String get generatePassphrase;

  /// No description provided for @passphraseStrength.
  ///
  /// In fr, this message translates to:
  /// **'Force'**
  String get passphraseStrength;

  /// No description provided for @weak.
  ///
  /// In fr, this message translates to:
  /// **'Faible'**
  String get weak;

  /// No description provided for @medium.
  ///
  /// In fr, this message translates to:
  /// **'Moyen'**
  String get medium;

  /// No description provided for @strong.
  ///
  /// In fr, this message translates to:
  /// **'Fort'**
  String get strong;

  /// No description provided for @backupCreated.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarde créée avec succès'**
  String get backupCreated;

  /// No description provided for @backupRestored.
  ///
  /// In fr, this message translates to:
  /// **'Clés restaurées avec succès'**
  String get backupRestored;

  /// No description provided for @invalidPassphrase.
  ///
  /// In fr, this message translates to:
  /// **'Passphrase incorrecte'**
  String get invalidPassphrase;

  /// No description provided for @noBackupFound.
  ///
  /// In fr, this message translates to:
  /// **'Aucune sauvegarde trouvée'**
  String get noBackupFound;

  /// No description provided for @deleteBackup.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer la sauvegarde'**
  String get deleteBackup;

  /// No description provided for @deleteBackupWarning.
  ///
  /// In fr, this message translates to:
  /// **'Cette action est irréversible. Si vous perdez vos clés et n\'avez plus de sauvegarde, vous ne pourrez plus lire vos anciens messages.'**
  String get deleteBackupWarning;

  /// No description provided for @existingBackup.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarde existante'**
  String get existingBackup;

  /// No description provided for @backupActive.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarde active'**
  String get backupActive;

  /// No description provided for @restoreOnDevice.
  ///
  /// In fr, this message translates to:
  /// **'Restaurer sur cet appareil'**
  String get restoreOnDevice;

  /// No description provided for @enterPassphrase.
  ///
  /// In fr, this message translates to:
  /// **'Entrez votre passphrase pour restaurer vos clés'**
  String get enterPassphrase;

  /// No description provided for @passphraseWarning.
  ///
  /// In fr, this message translates to:
  /// **'N\'oubliez pas votre passphrase ! Sans elle, vos clés ne pourront pas être restaurées.'**
  String get passphraseWarning;

  /// No description provided for @deviceManagement.
  ///
  /// In fr, this message translates to:
  /// **'Gestion des appareils'**
  String get deviceManagement;

  /// No description provided for @deviceManagementInfo.
  ///
  /// In fr, this message translates to:
  /// **'Vous pouvez avoir jusqu\'à 5 appareils connectés simultanément. Chaque appareil possède ses propres clés de chiffrement.'**
  String get deviceManagementInfo;

  /// No description provided for @noDevices.
  ///
  /// In fr, this message translates to:
  /// **'Aucun appareil enregistré'**
  String get noDevices;

  /// No description provided for @noDevicesDescription.
  ///
  /// In fr, this message translates to:
  /// **'Les appareils utilisant le chiffrement de bout en bout apparaîtront ici.'**
  String get noDevicesDescription;

  /// No description provided for @thisDevice.
  ///
  /// In fr, this message translates to:
  /// **'Cet appareil'**
  String get thisDevice;

  /// No description provided for @renameDevice.
  ///
  /// In fr, this message translates to:
  /// **'Renommer'**
  String get renameDevice;

  /// No description provided for @revokeDevice.
  ///
  /// In fr, this message translates to:
  /// **'Révoquer'**
  String get revokeDevice;

  /// No description provided for @revokeDeviceTitle.
  ///
  /// In fr, this message translates to:
  /// **'Révoquer l\'appareil ?'**
  String get revokeDeviceTitle;

  /// No description provided for @revokeDeviceWarning.
  ///
  /// In fr, this message translates to:
  /// **'Cet appareil ne pourra plus envoyer ni recevoir de messages chiffrés. Les clés de cet appareil seront supprimées.'**
  String get revokeDeviceWarning;

  /// No description provided for @deviceRenamed.
  ///
  /// In fr, this message translates to:
  /// **'Appareil renommé'**
  String get deviceRenamed;

  /// No description provided for @deviceRevoked.
  ///
  /// In fr, this message translates to:
  /// **'Appareil révoqué'**
  String get deviceRevoked;

  /// No description provided for @deviceLimitReached.
  ///
  /// In fr, this message translates to:
  /// **'Limite atteinte'**
  String get deviceLimitReached;

  /// No description provided for @fingerprint.
  ///
  /// In fr, this message translates to:
  /// **'Empreinte'**
  String get fingerprint;

  /// No description provided for @online.
  ///
  /// In fr, this message translates to:
  /// **'En ligne'**
  String get online;

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

  /// No description provided for @codeOfConduct.
  ///
  /// In fr, this message translates to:
  /// **'Code de conduite'**
  String get codeOfConduct;

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
  /// **'Actions du compte'**
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

  /// Compteur de conversations non lues sous le titre de l'écran Messages
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucun non lu} =1{1 non lu} other{{count} non lus}}'**
  String unreadConversations(int count);

  /// No description provided for @exportMyData.
  ///
  /// In fr, this message translates to:
  /// **'Exporter mes données'**
  String get exportMyData;

  /// No description provided for @exportMyDataSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Télécharger une copie de vos données (RGPD)'**
  String get exportMyDataSubtitle;

  /// No description provided for @exportMyDataPreparing.
  ///
  /// In fr, this message translates to:
  /// **'Préparation de votre export…'**
  String get exportMyDataPreparing;

  /// No description provided for @exportMyDataFailed.
  ///
  /// In fr, this message translates to:
  /// **'L\'export a échoué'**
  String get exportMyDataFailed;

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

  /// No description provided for @history.
  ///
  /// In fr, this message translates to:
  /// **'Historique'**
  String get history;

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

  /// No description provided for @deleteConversations.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer les conversations'**
  String get deleteConversations;

  /// No description provided for @confirmDeleteConversation.
  ///
  /// In fr, this message translates to:
  /// **'Voulez-vous vraiment supprimer cette conversation ? Cette action est irréversible.'**
  String get confirmDeleteConversation;

  /// No description provided for @confirmDeleteMultipleConversations.
  ///
  /// In fr, this message translates to:
  /// **'Voulez-vous vraiment supprimer {count} conversations ? Cette action est irréversible.'**
  String confirmDeleteMultipleConversations(int count);

  /// No description provided for @selectedCount.
  ///
  /// In fr, this message translates to:
  /// **'{count} sélectionné{count, plural, =1{} other{s}}'**
  String selectedCount(int count);

  /// No description provided for @conversationsDeleted.
  ///
  /// In fr, this message translates to:
  /// **'{count} conversation(s) supprimée(s)'**
  String conversationsDeleted(int count);

  /// No description provided for @select.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionner'**
  String get select;

  /// No description provided for @deleteForMe.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer pour moi'**
  String get deleteForMe;

  /// No description provided for @deleteForEveryone.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer pour tous'**
  String get deleteForEveryone;

  /// No description provided for @conversationDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Conversation supprimée'**
  String get conversationDeleted;

  /// No description provided for @changeWallpaper.
  ///
  /// In fr, this message translates to:
  /// **'Changer le fond d\'écran'**
  String get changeWallpaper;

  /// No description provided for @blockUserTitle.
  ///
  /// In fr, this message translates to:
  /// **'Bloquer l\'utilisateur'**
  String get blockUserTitle;

  /// No description provided for @unblockUserTitle.
  ///
  /// In fr, this message translates to:
  /// **'Débloquer l\'utilisateur'**
  String get unblockUserTitle;

  /// No description provided for @confirmBlockUser.
  ///
  /// In fr, this message translates to:
  /// **'Voulez-vous vraiment bloquer {userName} ? Vous ne recevrez plus de messages de sa part.'**
  String confirmBlockUser(String userName);

  /// No description provided for @confirmUnblockUser.
  ///
  /// In fr, this message translates to:
  /// **'Voulez-vous vraiment débloquer {userName} ?'**
  String confirmUnblockUser(String userName);

  /// No description provided for @block.
  ///
  /// In fr, this message translates to:
  /// **'Bloquer'**
  String get block;

  /// No description provided for @unblockUser.
  ///
  /// In fr, this message translates to:
  /// **'Débloquer l\'utilisateur'**
  String get unblockUser;

  /// No description provided for @blockError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors du blocage'**
  String get blockError;

  /// No description provided for @unblockError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors du déblocage'**
  String get unblockError;

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

  /// No description provided for @noUnreadMessages.
  ///
  /// In fr, this message translates to:
  /// **'Aucun message non lu'**
  String get noUnreadMessages;

  /// No description provided for @noGroupConversations.
  ///
  /// In fr, this message translates to:
  /// **'Aucune conversation de groupe'**
  String get noGroupConversations;

  /// No description provided for @showAllConversations.
  ///
  /// In fr, this message translates to:
  /// **'Afficher toutes les conversations'**
  String get showAllConversations;

  /// No description provided for @messageRequests.
  ///
  /// In fr, this message translates to:
  /// **'Demandes'**
  String get messageRequests;

  /// No description provided for @wantsToMessageYou.
  ///
  /// In fr, this message translates to:
  /// **'souhaite vous envoyer un message'**
  String get wantsToMessageYou;

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

  /// No description provided for @requestPending.
  ///
  /// In fr, this message translates to:
  /// **'Demande en attente'**
  String get requestPending;

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

  /// No description provided for @commonGroups.
  ///
  /// In fr, this message translates to:
  /// **'Groupes en commun'**
  String get commonGroups;

  /// No description provided for @noCommonGroups.
  ///
  /// In fr, this message translates to:
  /// **'Aucun groupe en commun'**
  String get noCommonGroups;

  /// No description provided for @unknownCaller.
  ///
  /// In fr, this message translates to:
  /// **'Appelant inconnu'**
  String get unknownCaller;

  /// No description provided for @callerNotInContacts.
  ///
  /// In fr, this message translates to:
  /// **'Cet appelant n\'est pas dans vos contacts'**
  String get callerNotInContacts;

  /// No description provided for @sendMessageRequest.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer une demande de message ?'**
  String get sendMessageRequest;

  /// No description provided for @personNotInContacts.
  ///
  /// In fr, this message translates to:
  /// **'Cette personne n\'est pas dans vos contacts. Elle devra accepter votre demande pour voir vos messages.'**
  String get personNotInContacts;

  /// No description provided for @noMessageRequests.
  ///
  /// In fr, this message translates to:
  /// **'Aucune demande de message'**
  String get noMessageRequests;

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

  /// No description provided for @messageNotSent.
  ///
  /// In fr, this message translates to:
  /// **'Non envoyé'**
  String get messageNotSent;

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
  /// **'Commencer'**
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

  /// No description provided for @upcoming.
  ///
  /// In fr, this message translates to:
  /// **'À venir'**
  String get upcoming;

  /// No description provided for @past.
  ///
  /// In fr, this message translates to:
  /// **'Passés'**
  String get past;

  /// No description provided for @noPastEvents.
  ///
  /// In fr, this message translates to:
  /// **'Aucun événement passé'**
  String get noPastEvents;

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

  /// No description provided for @participants.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucun participant} =1{1 participant} other{{count} participants}}'**
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

  /// No description provided for @eventFree.
  ///
  /// In fr, this message translates to:
  /// **'Gratuit'**
  String get eventFree;

  /// No description provided for @eventPaid.
  ///
  /// In fr, this message translates to:
  /// **'Payant'**
  String get eventPaid;

  /// No description provided for @eventPriceOptional.
  ///
  /// In fr, this message translates to:
  /// **'Prix du billet (optionnel)'**
  String get eventPriceOptional;

  /// No description provided for @eventPriceHint.
  ///
  /// In fr, this message translates to:
  /// **'0 = gratuit'**
  String get eventPriceHint;

  /// No description provided for @eventPriceFreeHelper.
  ///
  /// In fr, this message translates to:
  /// **'Laissez à 0 pour un événement gratuit'**
  String get eventPriceFreeHelper;

  /// No description provided for @registrationConfirmed.
  ///
  /// In fr, this message translates to:
  /// **'Inscription confirmée !'**
  String get registrationConfirmed;

  /// No description provided for @registered.
  ///
  /// In fr, this message translates to:
  /// **'Inscrit'**
  String get registered;

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

  /// No description provided for @faqEncryptionQ.
  ///
  /// In fr, this message translates to:
  /// **'Mes messages sont-ils protégés ?'**
  String get faqEncryptionQ;

  /// No description provided for @faqEncryptionA.
  ///
  /// In fr, this message translates to:
  /// **'Oui. Vos conversations sont chiffrées de bout en bout : seuls vous et vos correspondants peuvent les lire.'**
  String get faqEncryptionA;

  /// No description provided for @faqLocationQ.
  ///
  /// In fr, this message translates to:
  /// **'Qui voit ma position sur la carte ?'**
  String get faqLocationQ;

  /// No description provided for @faqLocationA.
  ///
  /// In fr, this message translates to:
  /// **'Uniquement les membres dont vous voyez aussi la position (réciprocité). Vous pouvez la désactiver à tout moment, et les comptes bloqués ne vous voient jamais.'**
  String get faqLocationA;

  /// No description provided for @faqReportQ.
  ///
  /// In fr, this message translates to:
  /// **'Comment signaler un contenu ?'**
  String get faqReportQ;

  /// No description provided for @faqReportA.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrez le menu d\'un message ou d\'une publication, puis « Signaler ». Votre signalement est anonyme.'**
  String get faqReportA;

  /// No description provided for @faqTransferQ.
  ///
  /// In fr, this message translates to:
  /// **'Combien de temps prend un transfert ?'**
  String get faqTransferQ;

  /// No description provided for @faqTransferA.
  ///
  /// In fr, this message translates to:
  /// **'Les transferts sont généralement disponibles sous 24 h. Les frais sont annoncés avant confirmation.'**
  String get faqTransferA;

  /// No description provided for @pinnedSection.
  ///
  /// In fr, this message translates to:
  /// **'Épinglées'**
  String get pinnedSection;

  /// No description provided for @otherConversations.
  ///
  /// In fr, this message translates to:
  /// **'Autres'**
  String get otherConversations;

  /// No description provided for @emptyMessagesJoinGroup.
  ///
  /// In fr, this message translates to:
  /// **'Rejoindre un groupe de votre ville'**
  String get emptyMessagesJoinGroup;

  /// No description provided for @emptyGroupsUsage.
  ///
  /// In fr, this message translates to:
  /// **'Les groupes réunissent la diaspora par ville, centre d\'intérêt ou projet. Rejoignez-en un ou créez le vôtre.'**
  String get emptyGroupsUsage;

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

  /// No description provided for @shareGroup.
  ///
  /// In fr, this message translates to:
  /// **'Partager le groupe'**
  String get shareGroup;

  /// No description provided for @shareVia.
  ///
  /// In fr, this message translates to:
  /// **'Partager via'**
  String get shareVia;

  /// No description provided for @scanToJoin.
  ///
  /// In fr, this message translates to:
  /// **'Scannez pour rejoindre'**
  String get scanToJoin;

  /// No description provided for @joinGroupInvite.
  ///
  /// In fr, this message translates to:
  /// **'Rejoignez le groupe \"{groupName}\" sur Diaspo Niger : {link}'**
  String joinGroupInvite(String groupName, String link);

  /// No description provided for @deletedUser.
  ///
  /// In fr, this message translates to:
  /// **'Utilisateur supprimé'**
  String get deletedUser;

  /// No description provided for @sharePostMessage.
  ///
  /// In fr, this message translates to:
  /// **'{authorName} sur Diaspo Niger :\n\n{preview}\n\n{link}'**
  String sharePostMessage(String authorName, String preview, String link);

  /// No description provided for @leaveGroup.
  ///
  /// In fr, this message translates to:
  /// **'Quitter'**
  String get leaveGroup;

  /// No description provided for @members.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucun membre} =1{1 membre} other{{count} membres}}'**
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

  /// No description provided for @noOtherMembers.
  ///
  /// In fr, this message translates to:
  /// **'Aucun autre membre pour le moment'**
  String get noOtherMembers;

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
  /// **'Position'**
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

  /// No description provided for @aroundYou.
  ///
  /// In fr, this message translates to:
  /// **'Autour de vous'**
  String get aroundYou;

  /// No description provided for @theMap.
  ///
  /// In fr, this message translates to:
  /// **'La carte'**
  String get theMap;

  /// No description provided for @noMembersNearby.
  ///
  /// In fr, this message translates to:
  /// **'Aucun membre à proximité'**
  String get noMembersNearby;

  /// No description provided for @enableNearbyMembers.
  ///
  /// In fr, this message translates to:
  /// **'Activer les membres à proximité'**
  String get enableNearbyMembers;

  /// No description provided for @disableNearbyMembers.
  ///
  /// In fr, this message translates to:
  /// **'Désactiver les membres à proximité'**
  String get disableNearbyMembers;

  /// No description provided for @nearbyMembersDisabled.
  ///
  /// In fr, this message translates to:
  /// **'Mode privé activé'**
  String get nearbyMembersDisabled;

  /// No description provided for @nearbyMembersDisabledHint.
  ///
  /// In fr, this message translates to:
  /// **'Activez pour voir les membres à proximité et apparaître sur leur carte'**
  String get nearbyMembersDisabledHint;

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

  /// No description provided for @secondsAgo.
  ///
  /// In fr, this message translates to:
  /// **'Il y a {count} s'**
  String secondsAgo(int count);

  /// No description provided for @minutesAgo.
  ///
  /// In fr, this message translates to:
  /// **'Il y a {count} minute(s)'**
  String minutesAgo(int count);

  /// No description provided for @hoursAgo.
  ///
  /// In fr, this message translates to:
  /// **'Il y a {count} heure(s)'**
  String hoursAgo(int count);

  /// No description provided for @daysAgo.
  ///
  /// In fr, this message translates to:
  /// **'Il y a {count} jour(s)'**
  String daysAgo(int count);

  /// No description provided for @weeksAgo.
  ///
  /// In fr, this message translates to:
  /// **'Il y a {count} sem'**
  String weeksAgo(int count);

  /// No description provided for @monthsAgo.
  ///
  /// In fr, this message translates to:
  /// **'Il y a {count} mois'**
  String monthsAgo(int count);

  /// No description provided for @yearsAgo.
  ///
  /// In fr, this message translates to:
  /// **'Il y a {count} an(s)'**
  String yearsAgo(int count);

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
  /// **'La description est requise'**
  String get descriptionRequired;

  /// No description provided for @descriptionHint.
  ///
  /// In fr, this message translates to:
  /// **'Décrivez votre événement...'**
  String get descriptionHint;

  /// No description provided for @descriptionRequiredError.
  ///
  /// In fr, this message translates to:
  /// **'Entrez une description'**
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
  /// **'Localisation requise'**
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

  /// No description provided for @everywhere.
  ///
  /// In fr, this message translates to:
  /// **'Global'**
  String get everywhere;

  /// No description provided for @everywhereLabel.
  ///
  /// In fr, this message translates to:
  /// **'Global'**
  String get everywhereLabel;

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
  /// **'Gérer les notifications'**
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

  /// No description provided for @filterUnread.
  ///
  /// In fr, this message translates to:
  /// **'Non lus'**
  String get filterUnread;

  /// No description provided for @filterFriends.
  ///
  /// In fr, this message translates to:
  /// **'Amis'**
  String get filterFriends;

  /// No description provided for @notificationSettings.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres de notifications'**
  String get notificationSettings;

  /// No description provided for @notificationsDisabled.
  ///
  /// In fr, this message translates to:
  /// **'Notifications désactivées'**
  String get notificationsDisabled;

  /// No description provided for @notificationsDisabledDesc.
  ///
  /// In fr, this message translates to:
  /// **'Activez les notifications pour recevoir les alertes de messages et d\'appels.'**
  String get notificationsDisabledDesc;

  /// No description provided for @notificationContent.
  ///
  /// In fr, this message translates to:
  /// **'Contenu'**
  String get notificationContent;

  /// No description provided for @notificationAlerts.
  ///
  /// In fr, this message translates to:
  /// **'Alertes'**
  String get notificationAlerts;

  /// No description provided for @notificationAdvanced.
  ///
  /// In fr, this message translates to:
  /// **'Avancé'**
  String get notificationAdvanced;

  /// No description provided for @notifyMessages.
  ///
  /// In fr, this message translates to:
  /// **'Messages'**
  String get notifyMessages;

  /// No description provided for @notifyEvents.
  ///
  /// In fr, this message translates to:
  /// **'Événements'**
  String get notifyEvents;

  /// No description provided for @notifyFriendRequests.
  ///
  /// In fr, this message translates to:
  /// **'Demandes d\'amis'**
  String get notifyFriendRequests;

  /// No description provided for @notifyGroups.
  ///
  /// In fr, this message translates to:
  /// **'Groupes'**
  String get notifyGroups;

  /// No description provided for @notifyEventReminders.
  ///
  /// In fr, this message translates to:
  /// **'Rappels d\'événements'**
  String get notifyEventReminders;

  /// No description provided for @notificationSound.
  ///
  /// In fr, this message translates to:
  /// **'Son'**
  String get notificationSound;

  /// No description provided for @notificationVibration.
  ///
  /// In fr, this message translates to:
  /// **'Vibration'**
  String get notificationVibration;

  /// No description provided for @quietHours.
  ///
  /// In fr, this message translates to:
  /// **'Mode silencieux'**
  String get quietHours;

  /// No description provided for @quietHoursDesc.
  ///
  /// In fr, this message translates to:
  /// **'Ne pas déranger pendant ces heures'**
  String get quietHoursDesc;

  /// No description provided for @quietHoursStart.
  ///
  /// In fr, this message translates to:
  /// **'Début'**
  String get quietHoursStart;

  /// No description provided for @quietHoursEnd.
  ///
  /// In fr, this message translates to:
  /// **'Fin'**
  String get quietHoursEnd;

  /// No description provided for @notificationDetail.
  ///
  /// In fr, this message translates to:
  /// **'Détail de la notification'**
  String get notificationDetail;

  /// No description provided for @open.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir'**
  String get open;

  /// No description provided for @markAsRead.
  ///
  /// In fr, this message translates to:
  /// **'Marquer comme lu'**
  String get markAsRead;

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
  /// **'© 2025 Diaspo Niger. Tous droits réservés.'**
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
  /// **'Région d\'origine au Niger (optionnel)'**
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
  /// **'Profil introuvable. Veuillez redémarrer l\'application.'**
  String get profileNotFound;

  /// No description provided for @deletedProfile.
  ///
  /// In fr, this message translates to:
  /// **'Profil supprimé'**
  String get deletedProfile;

  /// No description provided for @accountNoLongerExists.
  ///
  /// In fr, this message translates to:
  /// **'Ce compte n\'existe plus'**
  String get accountNoLongerExists;

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
  /// **'L\'accès à la caméra a été refusé. Veuillez l\'activer dans les paramètres de l\'application.'**
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

  /// No description provided for @systemMessageUserJoined.
  ///
  /// In fr, this message translates to:
  /// **'{userName} a rejoint le groupe'**
  String systemMessageUserJoined(String userName);

  /// No description provided for @systemMessageUserLeft.
  ///
  /// In fr, this message translates to:
  /// **'{userName} a quitté le groupe'**
  String systemMessageUserLeft(String userName);

  /// No description provided for @systemMessageUserRemoved.
  ///
  /// In fr, this message translates to:
  /// **'{userName} a été retiré du groupe'**
  String systemMessageUserRemoved(String userName);

  /// No description provided for @systemMessageUserPromoted.
  ///
  /// In fr, this message translates to:
  /// **'{userName} est maintenant administrateur'**
  String systemMessageUserPromoted(String userName);

  /// No description provided for @systemMessageUserDemoted.
  ///
  /// In fr, this message translates to:
  /// **'{userName} n\'est plus administrateur'**
  String systemMessageUserDemoted(String userName);

  /// No description provided for @systemMessageGroupRenamed.
  ///
  /// In fr, this message translates to:
  /// **'Le groupe a été renommé en {newName}'**
  String systemMessageGroupRenamed(String newName);

  /// No description provided for @audioRoomsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Salons Audio'**
  String get audioRoomsTitle;

  /// No description provided for @createAudioRoom.
  ///
  /// In fr, this message translates to:
  /// **'Créer un salon'**
  String get createAudioRoom;

  /// No description provided for @scheduleAudioRoom.
  ///
  /// In fr, this message translates to:
  /// **'Programmer un salon'**
  String get scheduleAudioRoom;

  /// No description provided for @audioRoomTitle.
  ///
  /// In fr, this message translates to:
  /// **'Titre du salon *'**
  String get audioRoomTitle;

  /// No description provided for @audioRoomTitleHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex: Discussion sur l\'entrepreneuriat'**
  String get audioRoomTitleHint;

  /// No description provided for @audioRoomTitleRequired.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez entrer un titre'**
  String get audioRoomTitleRequired;

  /// No description provided for @audioRoomDescription.
  ///
  /// In fr, this message translates to:
  /// **'Description'**
  String get audioRoomDescription;

  /// No description provided for @audioRoomDescriptionHint.
  ///
  /// In fr, this message translates to:
  /// **'De quoi allez-vous parler ?'**
  String get audioRoomDescriptionHint;

  /// No description provided for @audioRoomCategory.
  ///
  /// In fr, this message translates to:
  /// **'Catégorie'**
  String get audioRoomCategory;

  /// No description provided for @audioRoomMode.
  ///
  /// In fr, this message translates to:
  /// **'Mode du salon'**
  String get audioRoomMode;

  /// No description provided for @audioRoomPrivate.
  ///
  /// In fr, this message translates to:
  /// **'Salon privé'**
  String get audioRoomPrivate;

  /// No description provided for @audioRoomPrivateDesc.
  ///
  /// In fr, this message translates to:
  /// **'Seules les personnes invitées peuvent rejoindre'**
  String get audioRoomPrivateDesc;

  /// No description provided for @audioRoomRecording.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer le salon'**
  String get audioRoomRecording;

  /// No description provided for @audioRoomRecordingDesc.
  ///
  /// In fr, this message translates to:
  /// **'Permettre l\'enregistrement pour replay'**
  String get audioRoomRecordingDesc;

  /// No description provided for @audioRoomPaid.
  ///
  /// In fr, this message translates to:
  /// **'PAYANT'**
  String get audioRoomPaid;

  /// No description provided for @audioRoomPaidDesc.
  ///
  /// In fr, this message translates to:
  /// **'Les participants doivent acheter un ticket'**
  String get audioRoomPaidDesc;

  /// No description provided for @audioRoomTags.
  ///
  /// In fr, this message translates to:
  /// **'Tags'**
  String get audioRoomTags;

  /// No description provided for @audioRoomCreatedSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Salon créé avec succès !'**
  String get audioRoomCreatedSuccess;

  /// No description provided for @audioRoomCreationError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la création'**
  String get audioRoomCreationError;

  /// No description provided for @audioRoomScheduledSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Salon programmé pour le {date}'**
  String audioRoomScheduledSuccess(String date);

  /// No description provided for @audioRoomScheduleError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la programmation'**
  String get audioRoomScheduleError;

  /// No description provided for @audioRoomDateMustBeFuture.
  ///
  /// In fr, this message translates to:
  /// **'La date doit être dans le futur'**
  String get audioRoomDateMustBeFuture;

  /// No description provided for @audioRoomOptions.
  ///
  /// In fr, this message translates to:
  /// **'Options du salon'**
  String get audioRoomOptions;

  /// No description provided for @audioRoomShare.
  ///
  /// In fr, this message translates to:
  /// **'Partager le salon'**
  String get audioRoomShare;

  /// No description provided for @audioRoomCopyLink.
  ///
  /// In fr, this message translates to:
  /// **'Copier le lien'**
  String get audioRoomCopyLink;

  /// No description provided for @audioRoomLinkCopied.
  ///
  /// In fr, this message translates to:
  /// **'Lien copié dans le presse-papier'**
  String get audioRoomLinkCopied;

  /// No description provided for @audioRoomManageRecording.
  ///
  /// In fr, this message translates to:
  /// **'Gérer l\'enregistrement'**
  String get audioRoomManageRecording;

  /// No description provided for @audioRoomSettings.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres du salon'**
  String get audioRoomSettings;

  /// No description provided for @audioRoomEndRoom.
  ///
  /// In fr, this message translates to:
  /// **'Terminer le salon'**
  String get audioRoomEndRoom;

  /// No description provided for @audioRoomEndRoomConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Terminer le salon ?'**
  String get audioRoomEndRoomConfirm;

  /// No description provided for @audioRoomEndRoomWarning.
  ///
  /// In fr, this message translates to:
  /// **'Cette action mettra fin au salon pour tous les participants. Cette action est irréversible.'**
  String get audioRoomEndRoomWarning;

  /// No description provided for @audioRoomReport.
  ///
  /// In fr, this message translates to:
  /// **'Signaler le salon'**
  String get audioRoomReport;

  /// No description provided for @audioRoomReportSent.
  ///
  /// In fr, this message translates to:
  /// **'Signalement bientôt disponible'**
  String get audioRoomReportSent;

  /// No description provided for @audioRoomSettingsComingSoon.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres bientôt disponibles'**
  String get audioRoomSettingsComingSoon;

  /// No description provided for @audioRoomRecordingComingSoon.
  ///
  /// In fr, this message translates to:
  /// **'Gestion d\'enregistrement bientôt disponible'**
  String get audioRoomRecordingComingSoon;

  /// No description provided for @audioRoomShareComingSoon.
  ///
  /// In fr, this message translates to:
  /// **'Fonctionnalité de partage bientôt disponible'**
  String get audioRoomShareComingSoon;

  /// No description provided for @audioRoomLive.
  ///
  /// In fr, this message translates to:
  /// **'EN DIRECT'**
  String get audioRoomLive;

  /// No description provided for @audioRoomScheduled.
  ///
  /// In fr, this message translates to:
  /// **'Programmé'**
  String get audioRoomScheduled;

  /// No description provided for @audioRoomEnded.
  ///
  /// In fr, this message translates to:
  /// **'Terminé'**
  String get audioRoomEnded;

  /// No description provided for @audioRoomParticipants.
  ///
  /// In fr, this message translates to:
  /// **'{count} participants'**
  String audioRoomParticipants(int count);

  /// No description provided for @audioRoomHostedBy.
  ///
  /// In fr, this message translates to:
  /// **'Animé par {name}'**
  String audioRoomHostedBy(String name);

  /// No description provided for @audioRoomJoinUs.
  ///
  /// In fr, this message translates to:
  /// **'Rejoignez-nous !'**
  String get audioRoomJoinUs;

  /// No description provided for @audioRoomCategoryGeneral.
  ///
  /// In fr, this message translates to:
  /// **'Général'**
  String get audioRoomCategoryGeneral;

  /// No description provided for @audioRoomCategoryGriot.
  ///
  /// In fr, this message translates to:
  /// **'Griot / Contes'**
  String get audioRoomCategoryGriot;

  /// No description provided for @audioRoomCategorySpirituality.
  ///
  /// In fr, this message translates to:
  /// **'Spiritualité'**
  String get audioRoomCategorySpirituality;

  /// No description provided for @audioRoomCategoryNews.
  ///
  /// In fr, this message translates to:
  /// **'Actualités'**
  String get audioRoomCategoryNews;

  /// No description provided for @audioRoomCategoryBusiness.
  ///
  /// In fr, this message translates to:
  /// **'Business'**
  String get audioRoomCategoryBusiness;

  /// No description provided for @audioRoomCategoryMentorship.
  ///
  /// In fr, this message translates to:
  /// **'Mentorat'**
  String get audioRoomCategoryMentorship;

  /// No description provided for @audioRoomCategoryFamily.
  ///
  /// In fr, this message translates to:
  /// **'Famille'**
  String get audioRoomCategoryFamily;

  /// No description provided for @audioRoomCategoryOfficial.
  ///
  /// In fr, this message translates to:
  /// **'Officiel'**
  String get audioRoomCategoryOfficial;

  /// No description provided for @audioRoomCategoryCulture.
  ///
  /// In fr, this message translates to:
  /// **'Culture'**
  String get audioRoomCategoryCulture;

  /// No description provided for @audioRoomCategoryEducation.
  ///
  /// In fr, this message translates to:
  /// **'Éducation'**
  String get audioRoomCategoryEducation;

  /// No description provided for @audioRoomModeNormal.
  ///
  /// In fr, this message translates to:
  /// **'Normal'**
  String get audioRoomModeNormal;

  /// No description provided for @audioRoomModeCeremony.
  ///
  /// In fr, this message translates to:
  /// **'Cérémonie'**
  String get audioRoomModeCeremony;

  /// No description provided for @audioRoomModeRadio.
  ///
  /// In fr, this message translates to:
  /// **'Radio'**
  String get audioRoomModeRadio;

  /// No description provided for @audioRoomModeHeritage.
  ///
  /// In fr, this message translates to:
  /// **'Patrimoine'**
  String get audioRoomModeHeritage;

  /// No description provided for @audioRoomCollection.
  ///
  /// In fr, this message translates to:
  /// **'Collecte'**
  String get audioRoomCollection;

  /// No description provided for @audioRoomCollectionNone.
  ///
  /// In fr, this message translates to:
  /// **'Pas de collecte'**
  String get audioRoomCollectionNone;

  /// No description provided for @audioRoomCollectionFamilyEvent.
  ///
  /// In fr, this message translates to:
  /// **'Événement familial'**
  String get audioRoomCollectionFamilyEvent;

  /// No description provided for @audioRoomCollectionEmergency.
  ///
  /// In fr, this message translates to:
  /// **'Aide d\'urgence'**
  String get audioRoomCollectionEmergency;

  /// No description provided for @audioRoomCollectionCommunityProject.
  ///
  /// In fr, this message translates to:
  /// **'Projet communautaire'**
  String get audioRoomCollectionCommunityProject;

  /// No description provided for @audioRoomCollectionAssociationDues.
  ///
  /// In fr, this message translates to:
  /// **'Cotisation association'**
  String get audioRoomCollectionAssociationDues;

  /// No description provided for @audioRoomCollectionCustom.
  ///
  /// In fr, this message translates to:
  /// **'Personnalisé'**
  String get audioRoomCollectionCustom;

  /// No description provided for @audioRoomCollectionGoal.
  ///
  /// In fr, this message translates to:
  /// **'Objectif de collecte'**
  String get audioRoomCollectionGoal;

  /// No description provided for @audioRoomCollectionDescription.
  ///
  /// In fr, this message translates to:
  /// **'Description de la collecte'**
  String get audioRoomCollectionDescription;

  /// No description provided for @audioRoomCollectionBeneficiary.
  ///
  /// In fr, this message translates to:
  /// **'Bénéficiaire'**
  String get audioRoomCollectionBeneficiary;

  /// No description provided for @audioRoomHeritageContent.
  ///
  /// In fr, this message translates to:
  /// **'Contenu patrimoine'**
  String get audioRoomHeritageContent;

  /// No description provided for @audioRoomHeritageContentDesc.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrement pour la préservation culturelle'**
  String get audioRoomHeritageContentDesc;

  /// No description provided for @audioRoomHeritageLanguage.
  ///
  /// In fr, this message translates to:
  /// **'Langue du contenu'**
  String get audioRoomHeritageLanguage;

  /// No description provided for @audioRoomHeritageRegion.
  ///
  /// In fr, this message translates to:
  /// **'Région d\'origine'**
  String get audioRoomHeritageRegion;

  /// No description provided for @audioRoomLinkedContent.
  ///
  /// In fr, this message translates to:
  /// **'Lier ce salon à :'**
  String get audioRoomLinkedContent;

  /// No description provided for @audioRoomLinkedEvent.
  ///
  /// In fr, this message translates to:
  /// **'Événement'**
  String get audioRoomLinkedEvent;

  /// No description provided for @audioRoomLinkedEventNone.
  ///
  /// In fr, this message translates to:
  /// **'Aucun événement lié'**
  String get audioRoomLinkedEventNone;

  /// No description provided for @audioRoomLinkedGroup.
  ///
  /// In fr, this message translates to:
  /// **'Groupe'**
  String get audioRoomLinkedGroup;

  /// No description provided for @audioRoomLinkedGroupNone.
  ///
  /// In fr, this message translates to:
  /// **'Aucun groupe lié'**
  String get audioRoomLinkedGroupNone;

  /// No description provided for @audioRoomLinkedEmbassy.
  ///
  /// In fr, this message translates to:
  /// **'Ambassade/Consulat'**
  String get audioRoomLinkedEmbassy;

  /// No description provided for @audioRoomLinkedEmbassyNone.
  ///
  /// In fr, this message translates to:
  /// **'Aucune ambassade liée'**
  String get audioRoomLinkedEmbassyNone;

  /// No description provided for @audioRoomSearchEvent.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un événement...'**
  String get audioRoomSearchEvent;

  /// No description provided for @audioRoomSearchGroup.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un groupe...'**
  String get audioRoomSearchGroup;

  /// No description provided for @audioRoomSearchEmbassy.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher une ambassade...'**
  String get audioRoomSearchEmbassy;

  /// No description provided for @audioRoomLinkEvent.
  ///
  /// In fr, this message translates to:
  /// **'Lier un événement'**
  String get audioRoomLinkEvent;

  /// No description provided for @audioRoomLinkGroup.
  ///
  /// In fr, this message translates to:
  /// **'Lier un groupe'**
  String get audioRoomLinkGroup;

  /// No description provided for @audioRoomLinkEmbassy.
  ///
  /// In fr, this message translates to:
  /// **'Lier une ambassade/consulat'**
  String get audioRoomLinkEmbassy;

  /// No description provided for @audioRoomNoEventFound.
  ///
  /// In fr, this message translates to:
  /// **'Aucun événement trouvé'**
  String get audioRoomNoEventFound;

  /// No description provided for @audioRoomNoGroupFound.
  ///
  /// In fr, this message translates to:
  /// **'Aucun groupe trouvé'**
  String get audioRoomNoGroupFound;

  /// No description provided for @audioRoomNoEmbassyFound.
  ///
  /// In fr, this message translates to:
  /// **'Aucune ambassade trouvée'**
  String get audioRoomNoEmbassyFound;

  /// No description provided for @audioRoomRemove.
  ///
  /// In fr, this message translates to:
  /// **'Retirer'**
  String get audioRoomRemove;

  /// No description provided for @audioRoomSpeakers.
  ///
  /// In fr, this message translates to:
  /// **'SPEAKERS'**
  String get audioRoomSpeakers;

  /// No description provided for @audioRoomListeners.
  ///
  /// In fr, this message translates to:
  /// **'LISTENERS'**
  String get audioRoomListeners;

  /// No description provided for @audioRoomHandsRaised.
  ///
  /// In fr, this message translates to:
  /// **'Mains levées'**
  String get audioRoomHandsRaised;

  /// No description provided for @audioRoomRaiseHand.
  ///
  /// In fr, this message translates to:
  /// **'Lever la main'**
  String get audioRoomRaiseHand;

  /// No description provided for @audioRoomLowerHand.
  ///
  /// In fr, this message translates to:
  /// **'Baisser la main'**
  String get audioRoomLowerHand;

  /// No description provided for @audioRoomLeave.
  ///
  /// In fr, this message translates to:
  /// **'Quitter'**
  String get audioRoomLeave;

  /// No description provided for @audioRoomMute.
  ///
  /// In fr, this message translates to:
  /// **'Muet'**
  String get audioRoomMute;

  /// No description provided for @audioRoomUnmute.
  ///
  /// In fr, this message translates to:
  /// **'Activer le micro'**
  String get audioRoomUnmute;

  /// No description provided for @audioRoomVerified.
  ///
  /// In fr, this message translates to:
  /// **'Vérifié'**
  String get audioRoomVerified;

  /// No description provided for @audioRoomNotVerified.
  ///
  /// In fr, this message translates to:
  /// **'Non vérifié'**
  String get audioRoomNotVerified;

  /// No description provided for @audioRoomEmbassy.
  ///
  /// In fr, this message translates to:
  /// **'Ambassade'**
  String get audioRoomEmbassy;

  /// No description provided for @audioRoomConsulate.
  ///
  /// In fr, this message translates to:
  /// **'Consulat'**
  String get audioRoomConsulate;

  /// No description provided for @audioRoomHeritageLibrary.
  ///
  /// In fr, this message translates to:
  /// **'Bibliothèque du patrimoine'**
  String get audioRoomHeritageLibrary;

  /// No description provided for @audioRoomHeritageDiscover.
  ///
  /// In fr, this message translates to:
  /// **'Découvrir'**
  String get audioRoomHeritageDiscover;

  /// No description provided for @audioRoomHeritageCategories.
  ///
  /// In fr, this message translates to:
  /// **'Catégories'**
  String get audioRoomHeritageCategories;

  /// No description provided for @audioRoomHeritageSaved.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrés'**
  String get audioRoomHeritageSaved;

  /// No description provided for @audioRoomBack.
  ///
  /// In fr, this message translates to:
  /// **'Retour'**
  String get audioRoomBack;

  /// No description provided for @audioRoomAudioRoom.
  ///
  /// In fr, this message translates to:
  /// **'Salon Audio'**
  String get audioRoomAudioRoom;

  /// No description provided for @audioRoomPromoteUser.
  ///
  /// In fr, this message translates to:
  /// **'Promouvoir {userName}'**
  String audioRoomPromoteUser(String userName);

  /// No description provided for @audioRoomPromoteQuestion.
  ///
  /// In fr, this message translates to:
  /// **'Voulez-vous donner la parole à cet utilisateur ?'**
  String get audioRoomPromoteQuestion;

  /// No description provided for @audioRoomPromote.
  ///
  /// In fr, this message translates to:
  /// **'Promouvoir'**
  String get audioRoomPromote;

  /// No description provided for @audioRoomEnd.
  ///
  /// In fr, this message translates to:
  /// **'Terminer'**
  String get audioRoomEnd;

  /// No description provided for @audioRoomCreateRoom.
  ///
  /// In fr, this message translates to:
  /// **'Créer un salon'**
  String get audioRoomCreateRoom;

  /// No description provided for @audioRoomBasicInfo.
  ///
  /// In fr, this message translates to:
  /// **'Informations de base'**
  String get audioRoomBasicInfo;

  /// No description provided for @audioRoomTitleLabel.
  ///
  /// In fr, this message translates to:
  /// **'Titre du salon *'**
  String get audioRoomTitleLabel;

  /// No description provided for @audioRoomTitleHintExample.
  ///
  /// In fr, this message translates to:
  /// **'Ex: Discussion Tech Niger'**
  String get audioRoomTitleHintExample;

  /// No description provided for @audioRoomEnterTitle.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez entrer un titre'**
  String get audioRoomEnterTitle;

  /// No description provided for @audioRoomTitleMinLength.
  ///
  /// In fr, this message translates to:
  /// **'Le titre doit contenir au moins 3 caractères'**
  String get audioRoomTitleMinLength;

  /// No description provided for @audioRoomPleaseFixErrors.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez corriger les erreurs avant de continuer'**
  String get audioRoomPleaseFixErrors;

  /// No description provided for @audioRoomDescriptionLabel.
  ///
  /// In fr, this message translates to:
  /// **'Description'**
  String get audioRoomDescriptionLabel;

  /// No description provided for @audioRoomDescriptionHintWhat.
  ///
  /// In fr, this message translates to:
  /// **'De quoi allez-vous parler ?'**
  String get audioRoomDescriptionHintWhat;

  /// No description provided for @audioRoomCategoryLabel.
  ///
  /// In fr, this message translates to:
  /// **'Catégorie'**
  String get audioRoomCategoryLabel;

  /// No description provided for @audioRoomModeLabel.
  ///
  /// In fr, this message translates to:
  /// **'Mode du salon'**
  String get audioRoomModeLabel;

  /// No description provided for @audioRoomTagsOptional.
  ///
  /// In fr, this message translates to:
  /// **'Tags (optionnel)'**
  String get audioRoomTagsOptional;

  /// No description provided for @audioRoomMaxTags.
  ///
  /// In fr, this message translates to:
  /// **'Maximum 3 tags'**
  String get audioRoomMaxTags;

  /// No description provided for @audioRoomFundraising.
  ///
  /// In fr, this message translates to:
  /// **'Collecte de fonds'**
  String get audioRoomFundraising;

  /// No description provided for @audioRoomCulturalHeritage.
  ///
  /// In fr, this message translates to:
  /// **'Patrimoine culturel'**
  String get audioRoomCulturalHeritage;

  /// No description provided for @audioRoomLinks.
  ///
  /// In fr, this message translates to:
  /// **'Liens'**
  String get audioRoomLinks;

  /// No description provided for @audioRoomSettingsLabel.
  ///
  /// In fr, this message translates to:
  /// **'Réglages'**
  String get audioRoomSettingsLabel;

  /// No description provided for @audioRoomPrivateRoom.
  ///
  /// In fr, this message translates to:
  /// **'Salon privé'**
  String get audioRoomPrivateRoom;

  /// No description provided for @audioRoomPrivateRoomDesc.
  ///
  /// In fr, this message translates to:
  /// **'Seules les personnes invitées peuvent rejoindre'**
  String get audioRoomPrivateRoomDesc;

  /// No description provided for @audioRoomEnableRecording.
  ///
  /// In fr, this message translates to:
  /// **'Activer l\'enregistrement'**
  String get audioRoomEnableRecording;

  /// No description provided for @audioRoomEnableRecordingDesc.
  ///
  /// In fr, this message translates to:
  /// **'Le salon sera enregistré pour le replay'**
  String get audioRoomEnableRecordingDesc;

  /// No description provided for @audioRoomPaidRoom.
  ///
  /// In fr, this message translates to:
  /// **'Salon payant'**
  String get audioRoomPaidRoom;

  /// No description provided for @audioRoomPaidRoomDesc.
  ///
  /// In fr, this message translates to:
  /// **'Les participants doivent acheter un ticket'**
  String get audioRoomPaidRoomDesc;

  /// No description provided for @audioRoomCurrencyLabel.
  ///
  /// In fr, this message translates to:
  /// **'Devise'**
  String get audioRoomCurrencyLabel;

  /// No description provided for @audioRoomTicketPriceLabel.
  ///
  /// In fr, this message translates to:
  /// **'Prix du ticket'**
  String get audioRoomTicketPriceLabel;

  /// No description provided for @audioRoomTicketPriceRequired.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez entrer le prix du ticket'**
  String get audioRoomTicketPriceRequired;

  /// No description provided for @audioRoomTicketPriceInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Le prix doit être un nombre valide'**
  String get audioRoomTicketPriceInvalid;

  /// No description provided for @audioRoomMinPrice.
  ///
  /// In fr, this message translates to:
  /// **'Le prix minimum est'**
  String get audioRoomMinPrice;

  /// No description provided for @audioRoomMaxPrice.
  ///
  /// In fr, this message translates to:
  /// **'Le prix maximum est'**
  String get audioRoomMaxPrice;

  /// No description provided for @audioRoomCommissionInfoTitle.
  ///
  /// In fr, this message translates to:
  /// **'Commission plateforme'**
  String get audioRoomCommissionInfoTitle;

  /// No description provided for @audioRoomCommissionLabel.
  ///
  /// In fr, this message translates to:
  /// **'Commission'**
  String get audioRoomCommissionLabel;

  /// No description provided for @audioRoomYouReceive.
  ///
  /// In fr, this message translates to:
  /// **'Vous recevez'**
  String get audioRoomYouReceive;

  /// No description provided for @audioRoomEstimatedEarnings.
  ///
  /// In fr, this message translates to:
  /// **'Gains estimés'**
  String get audioRoomEstimatedEarnings;

  /// No description provided for @audioRoomCreating.
  ///
  /// In fr, this message translates to:
  /// **'Création...'**
  String get audioRoomCreating;

  /// No description provided for @audioRoomStartRoom.
  ///
  /// In fr, this message translates to:
  /// **'Démarrer le salon'**
  String get audioRoomStartRoom;

  /// No description provided for @audioRoomScheduleForLater.
  ///
  /// In fr, this message translates to:
  /// **'Programmer pour plus tard'**
  String get audioRoomScheduleForLater;

  /// No description provided for @audioRoomCreatedSuccessfully.
  ///
  /// In fr, this message translates to:
  /// **'Salon créé avec succès !'**
  String get audioRoomCreatedSuccessfully;

  /// No description provided for @audioRoomCreationErrorGeneric.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la création'**
  String get audioRoomCreationErrorGeneric;

  /// No description provided for @audioRoomCategoryDiscussion.
  ///
  /// In fr, this message translates to:
  /// **'Discussion'**
  String get audioRoomCategoryDiscussion;

  /// No description provided for @audioRoomCategoryGriotStory.
  ///
  /// In fr, this message translates to:
  /// **'Griot/Conte'**
  String get audioRoomCategoryGriotStory;

  /// No description provided for @audioRoomCategorySpiritualityLabel.
  ///
  /// In fr, this message translates to:
  /// **'Spiritualité'**
  String get audioRoomCategorySpiritualityLabel;

  /// No description provided for @audioRoomCategoryNewsLabel.
  ///
  /// In fr, this message translates to:
  /// **'Actualités'**
  String get audioRoomCategoryNewsLabel;

  /// No description provided for @audioRoomCategoryBusinessLabel.
  ///
  /// In fr, this message translates to:
  /// **'Business'**
  String get audioRoomCategoryBusinessLabel;

  /// No description provided for @audioRoomCategoryMentorshipLabel.
  ///
  /// In fr, this message translates to:
  /// **'Mentorat'**
  String get audioRoomCategoryMentorshipLabel;

  /// No description provided for @audioRoomCategoryFamilyLabel.
  ///
  /// In fr, this message translates to:
  /// **'Famille'**
  String get audioRoomCategoryFamilyLabel;

  /// No description provided for @audioRoomCategoryOfficialLabel.
  ///
  /// In fr, this message translates to:
  /// **'Officiel'**
  String get audioRoomCategoryOfficialLabel;

  /// No description provided for @audioRoomCategoryCultureLabel.
  ///
  /// In fr, this message translates to:
  /// **'Culture'**
  String get audioRoomCategoryCultureLabel;

  /// No description provided for @audioRoomCategoryEducationLabel.
  ///
  /// In fr, this message translates to:
  /// **'Éducation'**
  String get audioRoomCategoryEducationLabel;

  /// No description provided for @audioRoomModeNormalLabel.
  ///
  /// In fr, this message translates to:
  /// **'Normal'**
  String get audioRoomModeNormalLabel;

  /// No description provided for @audioRoomModeCeremonyLabel.
  ///
  /// In fr, this message translates to:
  /// **'Cérémonie'**
  String get audioRoomModeCeremonyLabel;

  /// No description provided for @audioRoomModeRadioLabel.
  ///
  /// In fr, this message translates to:
  /// **'Radio'**
  String get audioRoomModeRadioLabel;

  /// No description provided for @audioRoomModeHeritageLabel.
  ///
  /// In fr, this message translates to:
  /// **'Patrimoine'**
  String get audioRoomModeHeritageLabel;

  /// No description provided for @audioRoomCollectionTypeNone.
  ///
  /// In fr, this message translates to:
  /// **'Aucune'**
  String get audioRoomCollectionTypeNone;

  /// No description provided for @audioRoomCollectionFamilyEventLabel.
  ///
  /// In fr, this message translates to:
  /// **'Événement familial'**
  String get audioRoomCollectionFamilyEventLabel;

  /// No description provided for @audioRoomCollectionEmergencyAid.
  ///
  /// In fr, this message translates to:
  /// **'Aide d\'urgence'**
  String get audioRoomCollectionEmergencyAid;

  /// No description provided for @audioRoomCollectionCommunityProjectLabel.
  ///
  /// In fr, this message translates to:
  /// **'Projet communautaire'**
  String get audioRoomCollectionCommunityProjectLabel;

  /// No description provided for @audioRoomCollectionDues.
  ///
  /// In fr, this message translates to:
  /// **'Cotisation'**
  String get audioRoomCollectionDues;

  /// No description provided for @audioRoomCollectionCustomLabel.
  ///
  /// In fr, this message translates to:
  /// **'Personnalisé'**
  String get audioRoomCollectionCustomLabel;

  /// No description provided for @audioRoomCollectionGoalLabel.
  ///
  /// In fr, this message translates to:
  /// **'Objectif (XOF)'**
  String get audioRoomCollectionGoalLabel;

  /// No description provided for @audioRoomCollectionGoalHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex: 100000'**
  String get audioRoomCollectionGoalHint;

  /// No description provided for @audioRoomCollectionEnterGoal.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez entrer un objectif'**
  String get audioRoomCollectionEnterGoal;

  /// No description provided for @audioRoomCollectionInvalidAmount.
  ///
  /// In fr, this message translates to:
  /// **'Montant invalide'**
  String get audioRoomCollectionInvalidAmount;

  /// No description provided for @audioRoomCollectionBeneficiaryLabel.
  ///
  /// In fr, this message translates to:
  /// **'Bénéficiaire'**
  String get audioRoomCollectionBeneficiaryLabel;

  /// No description provided for @audioRoomCollectionBeneficiaryHint.
  ///
  /// In fr, this message translates to:
  /// **'Nom du bénéficiaire'**
  String get audioRoomCollectionBeneficiaryHint;

  /// No description provided for @audioRoomCollectionDescriptionLabel.
  ///
  /// In fr, this message translates to:
  /// **'Description de la collecte'**
  String get audioRoomCollectionDescriptionLabel;

  /// No description provided for @audioRoomHeritageContentLabel.
  ///
  /// In fr, this message translates to:
  /// **'Contenu patrimonial'**
  String get audioRoomHeritageContentLabel;

  /// No description provided for @audioRoomHeritageLanguageLabel.
  ///
  /// In fr, this message translates to:
  /// **'Langue'**
  String get audioRoomHeritageLanguageLabel;

  /// No description provided for @audioRoomHeritageRegionLabel.
  ///
  /// In fr, this message translates to:
  /// **'Région d\'origine'**
  String get audioRoomHeritageRegionLabel;

  /// No description provided for @audioRoomLinkTo.
  ///
  /// In fr, this message translates to:
  /// **'Lier ce salon à :'**
  String get audioRoomLinkTo;

  /// No description provided for @audioRoomEventLabel.
  ///
  /// In fr, this message translates to:
  /// **'Événement'**
  String get audioRoomEventLabel;

  /// No description provided for @audioRoomNoLinkedEvent.
  ///
  /// In fr, this message translates to:
  /// **'Aucun événement lié'**
  String get audioRoomNoLinkedEvent;

  /// No description provided for @audioRoomGroupLabel.
  ///
  /// In fr, this message translates to:
  /// **'Groupe'**
  String get audioRoomGroupLabel;

  /// No description provided for @audioRoomNoLinkedGroup.
  ///
  /// In fr, this message translates to:
  /// **'Aucun groupe lié'**
  String get audioRoomNoLinkedGroup;

  /// No description provided for @audioRoomEmbassyConsulate.
  ///
  /// In fr, this message translates to:
  /// **'Ambassade/Consulat'**
  String get audioRoomEmbassyConsulate;

  /// No description provided for @audioRoomNoLinkedEmbassy.
  ///
  /// In fr, this message translates to:
  /// **'Aucune ambassade liée'**
  String get audioRoomNoLinkedEmbassy;

  /// No description provided for @audioRoomScheduleRoom.
  ///
  /// In fr, this message translates to:
  /// **'Programmer un salon'**
  String get audioRoomScheduleRoom;

  /// No description provided for @audioRoomTitleWeeklyExample.
  ///
  /// In fr, this message translates to:
  /// **'Ex: Discussion hebdomadaire Tech'**
  String get audioRoomTitleWeeklyExample;

  /// No description provided for @audioRoomDateAndTime.
  ///
  /// In fr, this message translates to:
  /// **'Date et heure'**
  String get audioRoomDateAndTime;

  /// No description provided for @audioRoomDate.
  ///
  /// In fr, this message translates to:
  /// **'Date'**
  String get audioRoomDate;

  /// No description provided for @audioRoomTime.
  ///
  /// In fr, this message translates to:
  /// **'Heure'**
  String get audioRoomTime;

  /// No description provided for @audioRoomSendReminders.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer des rappels'**
  String get audioRoomSendReminders;

  /// No description provided for @audioRoomSendRemindersDesc.
  ///
  /// In fr, this message translates to:
  /// **'Notifier les participants 15 min avant'**
  String get audioRoomSendRemindersDesc;

  /// No description provided for @audioRoomScheduling.
  ///
  /// In fr, this message translates to:
  /// **'Programmation...'**
  String get audioRoomScheduling;

  /// No description provided for @audioRoomScheduleTheRoom.
  ///
  /// In fr, this message translates to:
  /// **'Programmer le salon'**
  String get audioRoomScheduleTheRoom;

  /// No description provided for @audioRoomPreview.
  ///
  /// In fr, this message translates to:
  /// **'Aperçu'**
  String get audioRoomPreview;

  /// No description provided for @audioRoomDateMustBeFutureError.
  ///
  /// In fr, this message translates to:
  /// **'La date doit être dans le futur'**
  String get audioRoomDateMustBeFutureError;

  /// No description provided for @audioRoomScheduleSuccessDate.
  ///
  /// In fr, this message translates to:
  /// **'Salon programmé pour le {date}'**
  String audioRoomScheduleSuccessDate(String date);

  /// No description provided for @audioRoomScheduleErrorGeneric.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la programmation'**
  String get audioRoomScheduleErrorGeneric;

  /// No description provided for @audioRoomListTitle.
  ///
  /// In fr, this message translates to:
  /// **'Salons Audio'**
  String get audioRoomListTitle;

  /// No description provided for @audioRoomCreateTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Créer un salon'**
  String get audioRoomCreateTooltip;

  /// No description provided for @audioRoomLiveTab.
  ///
  /// In fr, this message translates to:
  /// **'En direct'**
  String get audioRoomLiveTab;

  /// No description provided for @audioRoomScheduledTab.
  ///
  /// In fr, this message translates to:
  /// **'Programmés'**
  String get audioRoomScheduledTab;

  /// No description provided for @audioRoomStartARoom.
  ///
  /// In fr, this message translates to:
  /// **'Démarrer un salon'**
  String get audioRoomStartARoom;

  /// No description provided for @audioRoomNoLiveRooms.
  ///
  /// In fr, this message translates to:
  /// **'Aucun salon en direct'**
  String get audioRoomNoLiveRooms;

  /// No description provided for @audioRoomBeFirstToStart.
  ///
  /// In fr, this message translates to:
  /// **'Soyez le premier à démarrer un salon !'**
  String get audioRoomBeFirstToStart;

  /// No description provided for @audioRoomNoScheduledRooms.
  ///
  /// In fr, this message translates to:
  /// **'Aucun salon programmé'**
  String get audioRoomNoScheduledRooms;

  /// No description provided for @audioRoomScheduleRoomForLater.
  ///
  /// In fr, this message translates to:
  /// **'Programmez un salon pour plus tard'**
  String get audioRoomScheduleRoomForLater;

  /// No description provided for @audioRoomLoadingError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur de chargement'**
  String get audioRoomLoadingError;

  /// No description provided for @heritageLibraryTitle.
  ///
  /// In fr, this message translates to:
  /// **'Bibliothèque Culturelle'**
  String get heritageLibraryTitle;

  /// No description provided for @heritageLibraryNotAvailable.
  ///
  /// In fr, this message translates to:
  /// **'La bibliothèque culturelle n\'est pas disponible pour le moment.'**
  String get heritageLibraryNotAvailable;

  /// No description provided for @heritageLibraryPreserve.
  ///
  /// In fr, this message translates to:
  /// **'Préservons notre patrimoine pour les générations futures'**
  String get heritageLibraryPreserve;

  /// No description provided for @heritageLibrarySearch.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher...'**
  String get heritageLibrarySearch;

  /// No description provided for @heritageLibraryLanguageFilter.
  ///
  /// In fr, this message translates to:
  /// **'Langue'**
  String get heritageLibraryLanguageFilter;

  /// No description provided for @heritageLibraryAllLanguages.
  ///
  /// In fr, this message translates to:
  /// **'Toutes les langues'**
  String get heritageLibraryAllLanguages;

  /// No description provided for @heritageLibraryRegionFilter.
  ///
  /// In fr, this message translates to:
  /// **'Région'**
  String get heritageLibraryRegionFilter;

  /// No description provided for @heritageLibraryAllRegions.
  ///
  /// In fr, this message translates to:
  /// **'Toutes les régions'**
  String get heritageLibraryAllRegions;

  /// No description provided for @heritageLibraryDiscoverTab.
  ///
  /// In fr, this message translates to:
  /// **'Découvrir'**
  String get heritageLibraryDiscoverTab;

  /// No description provided for @heritageLibraryCategoriesTab.
  ///
  /// In fr, this message translates to:
  /// **'Catégories'**
  String get heritageLibraryCategoriesTab;

  /// No description provided for @heritageLibrarySavedTab.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegardés'**
  String get heritageLibrarySavedTab;

  /// No description provided for @heritageLibraryPopular.
  ///
  /// In fr, this message translates to:
  /// **'Populaires'**
  String get heritageLibraryPopular;

  /// No description provided for @heritageLibraryNoPopularRecordings.
  ///
  /// In fr, this message translates to:
  /// **'Aucun enregistrement populaire'**
  String get heritageLibraryNoPopularRecordings;

  /// No description provided for @heritageLibraryRecent.
  ///
  /// In fr, this message translates to:
  /// **'Récents'**
  String get heritageLibraryRecent;

  /// No description provided for @heritageLibraryNoRecordingsFound.
  ///
  /// In fr, this message translates to:
  /// **'Aucun enregistrement trouvé'**
  String get heritageLibraryNoRecordingsFound;

  /// No description provided for @heritageLibrarySeeAll.
  ///
  /// In fr, this message translates to:
  /// **'Voir tout'**
  String get heritageLibrarySeeAll;

  /// No description provided for @heritageLibraryNoCategoryRecordings.
  ///
  /// In fr, this message translates to:
  /// **'Aucun enregistrement dans cette catégorie'**
  String get heritageLibraryNoCategoryRecordings;

  /// No description provided for @heritageLibraryNoSavedRecordings.
  ///
  /// In fr, this message translates to:
  /// **'Aucun enregistrement sauvegardé'**
  String get heritageLibraryNoSavedRecordings;

  /// No description provided for @heritageLibrarySaveHint.
  ///
  /// In fr, this message translates to:
  /// **'Appuyez sur l\'icône de signet pour sauvegarder'**
  String get heritageLibrarySaveHint;

  /// No description provided for @heritageContentTypeStories.
  ///
  /// In fr, this message translates to:
  /// **'Contes'**
  String get heritageContentTypeStories;

  /// No description provided for @heritageContentTypeProverbs.
  ///
  /// In fr, this message translates to:
  /// **'Proverbes'**
  String get heritageContentTypeProverbs;

  /// No description provided for @heritageContentTypeHistory.
  ///
  /// In fr, this message translates to:
  /// **'Histoire'**
  String get heritageContentTypeHistory;

  /// No description provided for @heritageContentTypeCeremonies.
  ///
  /// In fr, this message translates to:
  /// **'Cérémonies'**
  String get heritageContentTypeCeremonies;

  /// No description provided for @heritageContentTypeLanguage.
  ///
  /// In fr, this message translates to:
  /// **'Langue'**
  String get heritageContentTypeLanguage;

  /// No description provided for @heritageContentTypeCraft.
  ///
  /// In fr, this message translates to:
  /// **'Artisanat'**
  String get heritageContentTypeCraft;

  /// No description provided for @heritageContentTypeRecipes.
  ///
  /// In fr, this message translates to:
  /// **'Recettes'**
  String get heritageContentTypeRecipes;

  /// No description provided for @heritageContentTypeMedicine.
  ///
  /// In fr, this message translates to:
  /// **'Médecine'**
  String get heritageContentTypeMedicine;

  /// No description provided for @heritageContentTypeOther.
  ///
  /// In fr, this message translates to:
  /// **'Autre'**
  String get heritageContentTypeOther;

  /// No description provided for @callTitle.
  ///
  /// In fr, this message translates to:
  /// **'Appel'**
  String get callTitle;

  /// No description provided for @callCalling.
  ///
  /// In fr, this message translates to:
  /// **'Appel en cours...'**
  String get callCalling;

  /// No description provided for @callConnecting.
  ///
  /// In fr, this message translates to:
  /// **'Connexion...'**
  String get callConnecting;

  /// No description provided for @callUnableToStart.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de démarrer l\'appel'**
  String get callUnableToStart;

  /// No description provided for @callMute.
  ///
  /// In fr, this message translates to:
  /// **'Muet'**
  String get callMute;

  /// No description provided for @callUnmute.
  ///
  /// In fr, this message translates to:
  /// **'Activer le micro'**
  String get callUnmute;

  /// No description provided for @callSpeaker.
  ///
  /// In fr, this message translates to:
  /// **'Haut-parleur'**
  String get callSpeaker;

  /// No description provided for @callCamera.
  ///
  /// In fr, this message translates to:
  /// **'Caméra'**
  String get callCamera;

  /// No description provided for @callFlipCamera.
  ///
  /// In fr, this message translates to:
  /// **'Inverser'**
  String get callFlipCamera;

  /// No description provided for @callHangUp.
  ///
  /// In fr, this message translates to:
  /// **'Raccrocher'**
  String get callHangUp;

  /// No description provided for @callEnable.
  ///
  /// In fr, this message translates to:
  /// **'Activer'**
  String get callEnable;

  /// No description provided for @callEarpiece.
  ///
  /// In fr, this message translates to:
  /// **'Écouteur'**
  String get callEarpiece;

  /// No description provided for @incomingVideoCall.
  ///
  /// In fr, this message translates to:
  /// **'Appel vidéo entrant'**
  String get incomingVideoCall;

  /// No description provided for @incomingAudioCall.
  ///
  /// In fr, this message translates to:
  /// **'Appel audio entrant'**
  String get incomingAudioCall;

  /// No description provided for @incomingCallStatus.
  ///
  /// In fr, this message translates to:
  /// **'Appel entrant...'**
  String get incomingCallStatus;

  /// No description provided for @callDecline.
  ///
  /// In fr, this message translates to:
  /// **'Refuser'**
  String get callDecline;

  /// No description provided for @callAccept.
  ///
  /// In fr, this message translates to:
  /// **'Accepter'**
  String get callAccept;

  /// No description provided for @answerAudioOnly.
  ///
  /// In fr, this message translates to:
  /// **'Répondre en audio'**
  String get answerAudioOnly;

  /// No description provided for @callSwitchToVideo.
  ///
  /// In fr, this message translates to:
  /// **'Vidéo'**
  String get callSwitchToVideo;

  /// No description provided for @videoUpgradeRequest.
  ///
  /// In fr, this message translates to:
  /// **'{name} souhaite passer en vidéo'**
  String videoUpgradeRequest(String name);

  /// No description provided for @videoUpgradeWaiting.
  ///
  /// In fr, this message translates to:
  /// **'En attente de l\'acceptation de la vidéo...'**
  String get videoUpgradeWaiting;

  /// No description provided for @videoUpgradeDeclined.
  ///
  /// In fr, this message translates to:
  /// **'Demande vidéo refusée'**
  String get videoUpgradeDeclined;

  /// No description provided for @buyTicket.
  ///
  /// In fr, this message translates to:
  /// **'Acheter un ticket'**
  String get buyTicket;

  /// No description provided for @buyTicketAcceptTerms.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez accepter les conditions'**
  String get buyTicketAcceptTerms;

  /// No description provided for @buyTicketPurchaseSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Ticket acheté avec succès !'**
  String get buyTicketPurchaseSuccess;

  /// No description provided for @buyTicketAcceptTermsCheckbox.
  ///
  /// In fr, this message translates to:
  /// **'J\'accepte les conditions d\'utilisation et la politique de remboursement'**
  String get buyTicketAcceptTermsCheckbox;

  /// No description provided for @buyTicketPay.
  ///
  /// In fr, this message translates to:
  /// **'Payer {price}'**
  String buyTicketPay(String price);

  /// No description provided for @buyTicketSecurePayment.
  ///
  /// In fr, this message translates to:
  /// **'Paiement sécurisé par Stripe'**
  String get buyTicketSecurePayment;

  /// No description provided for @buyTicketTicketPrice.
  ///
  /// In fr, this message translates to:
  /// **'Prix du ticket'**
  String get buyTicketTicketPrice;

  /// No description provided for @buyTicketTotal.
  ///
  /// In fr, this message translates to:
  /// **'Total à payer'**
  String get buyTicketTotal;

  /// No description provided for @buyTicketHostedBy.
  ///
  /// In fr, this message translates to:
  /// **'Animé par {name}'**
  String buyTicketHostedBy(String name);

  /// No description provided for @buyTicketFree.
  ///
  /// In fr, this message translates to:
  /// **'Gratuit'**
  String get buyTicketFree;

  /// No description provided for @sendTip.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer un pourboire'**
  String get sendTip;

  /// No description provided for @sendTipChooseAmount.
  ///
  /// In fr, this message translates to:
  /// **'Choisir un montant'**
  String get sendTipChooseAmount;

  /// No description provided for @sendTipCustomAmount.
  ///
  /// In fr, this message translates to:
  /// **'Montant personnalisé'**
  String get sendTipCustomAmount;

  /// No description provided for @sendTipMessageOptional.
  ///
  /// In fr, this message translates to:
  /// **'Message (optionnel)'**
  String get sendTipMessageOptional;

  /// No description provided for @sendTipMessageHint.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un message...'**
  String get sendTipMessageHint;

  /// No description provided for @sendTipSend.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer {amount}'**
  String sendTipSend(String amount);

  /// No description provided for @sendTipSelectAmount.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionner un montant'**
  String get sendTipSelectAmount;

  /// No description provided for @sendTipSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Pourboire de {amount} envoyé !'**
  String sendTipSuccess(String amount);

  /// No description provided for @sendTipOther.
  ///
  /// In fr, this message translates to:
  /// **'Autre'**
  String get sendTipOther;

  /// No description provided for @sendTipRoleHost.
  ///
  /// In fr, this message translates to:
  /// **'Hôte'**
  String get sendTipRoleHost;

  /// No description provided for @sendTipRoleCoHost.
  ///
  /// In fr, this message translates to:
  /// **'Co-hôte'**
  String get sendTipRoleCoHost;

  /// No description provided for @sendTipRoleSpeaker.
  ///
  /// In fr, this message translates to:
  /// **'Speaker'**
  String get sendTipRoleSpeaker;

  /// No description provided for @sendTipRoleListener.
  ///
  /// In fr, this message translates to:
  /// **'Auditeur'**
  String get sendTipRoleListener;

  /// No description provided for @shareRoomLiveStatus.
  ///
  /// In fr, this message translates to:
  /// **'EN DIRECT'**
  String get shareRoomLiveStatus;

  /// No description provided for @shareRoomScheduledStatus.
  ///
  /// In fr, this message translates to:
  /// **'Salon programmé'**
  String get shareRoomScheduledStatus;

  /// No description provided for @shareRoomOnDiaspoNiger.
  ///
  /// In fr, this message translates to:
  /// **'sur Diaspo Niger'**
  String get shareRoomOnDiaspoNiger;

  /// No description provided for @shareRoomHostedBy.
  ///
  /// In fr, this message translates to:
  /// **'Animé par {name}'**
  String shareRoomHostedBy(String name);

  /// No description provided for @shareRoomParticipantsCount.
  ///
  /// In fr, this message translates to:
  /// **'{count} participants'**
  String shareRoomParticipantsCount(int count);

  /// No description provided for @shareRoomJoinUs.
  ///
  /// In fr, this message translates to:
  /// **'Rejoignez-nous !'**
  String get shareRoomJoinUs;

  /// No description provided for @shareRoomLinkCopied.
  ///
  /// In fr, this message translates to:
  /// **'Lien copié dans le presse-papier'**
  String get shareRoomLinkCopied;

  /// No description provided for @podcastsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Podcasts'**
  String get podcastsTitle;

  /// No description provided for @podcastsDiscover.
  ///
  /// In fr, this message translates to:
  /// **'Découvrir'**
  String get podcastsDiscover;

  /// No description provided for @podcastsCategories.
  ///
  /// In fr, this message translates to:
  /// **'Catégories'**
  String get podcastsCategories;

  /// No description provided for @podcastsSubscriptions.
  ///
  /// In fr, this message translates to:
  /// **'Abonnements'**
  String get podcastsSubscriptions;

  /// No description provided for @podcastsTrending.
  ///
  /// In fr, this message translates to:
  /// **'Tendances'**
  String get podcastsTrending;

  /// No description provided for @podcastsLatestEpisodes.
  ///
  /// In fr, this message translates to:
  /// **'Derniers épisodes'**
  String get podcastsLatestEpisodes;

  /// No description provided for @podcastsAllPodcasts.
  ///
  /// In fr, this message translates to:
  /// **'Tous les podcasts'**
  String get podcastsAllPodcasts;

  /// No description provided for @podcastsSearch.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un podcast...'**
  String get podcastsSearch;

  /// No description provided for @podcastsNoResults.
  ///
  /// In fr, this message translates to:
  /// **'Aucun podcast trouvé'**
  String get podcastsNoResults;

  /// No description provided for @podcastsNoSubscriptions.
  ///
  /// In fr, this message translates to:
  /// **'Aucun abonnement'**
  String get podcastsNoSubscriptions;

  /// No description provided for @podcastsNoSubscriptionsDesc.
  ///
  /// In fr, this message translates to:
  /// **'Abonnez-vous à des podcasts pour ne rien manquer'**
  String get podcastsNoSubscriptionsDesc;

  /// No description provided for @podcastsSubscribe.
  ///
  /// In fr, this message translates to:
  /// **'S\'abonner'**
  String get podcastsSubscribe;

  /// No description provided for @podcastsSubscribed.
  ///
  /// In fr, this message translates to:
  /// **'Abonné'**
  String get podcastsSubscribed;

  /// No description provided for @podcastsUnsubscribe.
  ///
  /// In fr, this message translates to:
  /// **'Se désabonner'**
  String get podcastsUnsubscribe;

  /// No description provided for @podcastsSubscribers.
  ///
  /// In fr, this message translates to:
  /// **'{count} abonnés'**
  String podcastsSubscribers(int count);

  /// No description provided for @podcastsEpisodes.
  ///
  /// In fr, this message translates to:
  /// **'{count} épisodes'**
  String podcastsEpisodes(int count);

  /// No description provided for @podcastsPlays.
  ///
  /// In fr, this message translates to:
  /// **'{count} écoutes'**
  String podcastsPlays(int count);

  /// No description provided for @podcastsCreatePodcast.
  ///
  /// In fr, this message translates to:
  /// **'Créer un podcast'**
  String get podcastsCreatePodcast;

  /// No description provided for @podcastsMyPodcasts.
  ///
  /// In fr, this message translates to:
  /// **'Mes podcasts'**
  String get podcastsMyPodcasts;

  /// No description provided for @podcastsNoPodcasts.
  ///
  /// In fr, this message translates to:
  /// **'Vous n\'avez pas encore de podcast'**
  String get podcastsNoPodcasts;

  /// No description provided for @podcastsNoPodcastsDesc.
  ///
  /// In fr, this message translates to:
  /// **'Créez votre premier podcast et partagez votre voix avec la communauté !'**
  String get podcastsNoPodcastsDesc;

  /// No description provided for @podcastsCreateFirst.
  ///
  /// In fr, this message translates to:
  /// **'Créer mon premier podcast'**
  String get podcastsCreateFirst;

  /// No description provided for @podcastsNewPodcast.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau podcast'**
  String get podcastsNewPodcast;

  /// No description provided for @podcastsPodcastTitle.
  ///
  /// In fr, this message translates to:
  /// **'Titre du podcast *'**
  String get podcastsPodcastTitle;

  /// No description provided for @podcastsPodcastTitleHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex: Tech Niger'**
  String get podcastsPodcastTitleHint;

  /// No description provided for @podcastsPodcastTitleRequired.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez entrer un titre'**
  String get podcastsPodcastTitleRequired;

  /// No description provided for @podcastsPodcastDescription.
  ///
  /// In fr, this message translates to:
  /// **'Description'**
  String get podcastsPodcastDescription;

  /// No description provided for @podcastsPodcastDescriptionHint.
  ///
  /// In fr, this message translates to:
  /// **'De quoi parle votre podcast ?'**
  String get podcastsPodcastDescriptionHint;

  /// No description provided for @podcastsCoverImage.
  ///
  /// In fr, this message translates to:
  /// **'Image de couverture *'**
  String get podcastsCoverImage;

  /// No description provided for @podcastsSelectCover.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionner une image'**
  String get podcastsSelectCover;

  /// No description provided for @podcastsChangeCover.
  ///
  /// In fr, this message translates to:
  /// **'Changer l\'image'**
  String get podcastsChangeCover;

  /// No description provided for @podcastsCategory.
  ///
  /// In fr, this message translates to:
  /// **'Catégorie'**
  String get podcastsCategory;

  /// No description provided for @podcastsLanguage.
  ///
  /// In fr, this message translates to:
  /// **'Langue principale'**
  String get podcastsLanguage;

  /// No description provided for @podcastsTags.
  ///
  /// In fr, this message translates to:
  /// **'Tags'**
  String get podcastsTags;

  /// No description provided for @podcastsTagsHint.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez des tags pour améliorer la découverte'**
  String get podcastsTagsHint;

  /// No description provided for @podcastsExplicitContent.
  ///
  /// In fr, this message translates to:
  /// **'Contenu explicite'**
  String get podcastsExplicitContent;

  /// No description provided for @podcastsExplicitContentDesc.
  ///
  /// In fr, this message translates to:
  /// **'Ce podcast contient du contenu réservé aux adultes'**
  String get podcastsExplicitContentDesc;

  /// No description provided for @podcastsEpisodeFrequency.
  ///
  /// In fr, this message translates to:
  /// **'Fréquence de publication'**
  String get podcastsEpisodeFrequency;

  /// No description provided for @podcastsFrequencyWeekly.
  ///
  /// In fr, this message translates to:
  /// **'Hebdomadaire'**
  String get podcastsFrequencyWeekly;

  /// No description provided for @podcastsFrequencyBiweekly.
  ///
  /// In fr, this message translates to:
  /// **'Bimensuel'**
  String get podcastsFrequencyBiweekly;

  /// No description provided for @podcastsFrequencyMonthly.
  ///
  /// In fr, this message translates to:
  /// **'Mensuel'**
  String get podcastsFrequencyMonthly;

  /// No description provided for @podcastsFrequencyVariable.
  ///
  /// In fr, this message translates to:
  /// **'Variable'**
  String get podcastsFrequencyVariable;

  /// No description provided for @podcastsCreateButton.
  ///
  /// In fr, this message translates to:
  /// **'Créer le podcast'**
  String get podcastsCreateButton;

  /// No description provided for @podcastsCreating.
  ///
  /// In fr, this message translates to:
  /// **'Création...'**
  String get podcastsCreating;

  /// No description provided for @podcastsCreatedSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Podcast créé avec succès !'**
  String get podcastsCreatedSuccess;

  /// No description provided for @podcastsCreationError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la création'**
  String get podcastsCreationError;

  /// No description provided for @podcastsNewEpisode.
  ///
  /// In fr, this message translates to:
  /// **'Nouvel épisode'**
  String get podcastsNewEpisode;

  /// No description provided for @podcastsRecordEpisode.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer un épisode'**
  String get podcastsRecordEpisode;

  /// No description provided for @podcastsUploadAudio.
  ///
  /// In fr, this message translates to:
  /// **'Uploader un fichier audio'**
  String get podcastsUploadAudio;

  /// No description provided for @podcastsSelectAudio.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionner un fichier audio'**
  String get podcastsSelectAudio;

  /// No description provided for @podcastsAudioSelected.
  ///
  /// In fr, this message translates to:
  /// **'Fichier sélectionné'**
  String get podcastsAudioSelected;

  /// No description provided for @podcastsEstimatedDuration.
  ///
  /// In fr, this message translates to:
  /// **'Durée estimée: {duration}'**
  String podcastsEstimatedDuration(String duration);

  /// No description provided for @podcastsEpisodeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Titre de l\'épisode *'**
  String get podcastsEpisodeTitle;

  /// No description provided for @podcastsEpisodeTitleRequired.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez entrer un titre'**
  String get podcastsEpisodeTitleRequired;

  /// No description provided for @podcastsEpisodeDescription.
  ///
  /// In fr, this message translates to:
  /// **'Description / Notes'**
  String get podcastsEpisodeDescription;

  /// No description provided for @podcastsChapters.
  ///
  /// In fr, this message translates to:
  /// **'Chapitres'**
  String get podcastsChapters;

  /// No description provided for @podcastsAddChapter.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un chapitre'**
  String get podcastsAddChapter;

  /// No description provided for @podcastsChapterTitle.
  ///
  /// In fr, this message translates to:
  /// **'Titre du chapitre'**
  String get podcastsChapterTitle;

  /// No description provided for @podcastsChapterTime.
  ///
  /// In fr, this message translates to:
  /// **'Temps de début'**
  String get podcastsChapterTime;

  /// No description provided for @podcastsNoChapters.
  ///
  /// In fr, this message translates to:
  /// **'Aucun chapitre ajouté'**
  String get podcastsNoChapters;

  /// No description provided for @podcastsPremiumEpisode.
  ///
  /// In fr, this message translates to:
  /// **'Épisode premium'**
  String get podcastsPremiumEpisode;

  /// No description provided for @podcastsPremiumEpisodeDesc.
  ///
  /// In fr, this message translates to:
  /// **'Réservé aux abonnés payants'**
  String get podcastsPremiumEpisodeDesc;

  /// No description provided for @podcastsPublishEpisode.
  ///
  /// In fr, this message translates to:
  /// **'Publier l\'épisode'**
  String get podcastsPublishEpisode;

  /// No description provided for @podcastsPublishing.
  ///
  /// In fr, this message translates to:
  /// **'Publication...'**
  String get podcastsPublishing;

  /// No description provided for @podcastsPublishedSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Épisode publié avec succès !'**
  String get podcastsPublishedSuccess;

  /// No description provided for @podcastsPublishError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la publication'**
  String get podcastsPublishError;

  /// No description provided for @podcastsSelectAudioFirst.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez sélectionner un fichier audio'**
  String get podcastsSelectAudioFirst;

  /// No description provided for @podcastsEpisodeDetail.
  ///
  /// In fr, this message translates to:
  /// **'Détail de l\'épisode'**
  String get podcastsEpisodeDetail;

  /// No description provided for @podcastsPlay.
  ///
  /// In fr, this message translates to:
  /// **'Écouter'**
  String get podcastsPlay;

  /// No description provided for @podcastsPause.
  ///
  /// In fr, this message translates to:
  /// **'Pause'**
  String get podcastsPause;

  /// No description provided for @podcastsDownload.
  ///
  /// In fr, this message translates to:
  /// **'Télécharger'**
  String get podcastsDownload;

  /// No description provided for @podcastsDownloading.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargement...'**
  String get podcastsDownloading;

  /// No description provided for @podcastsShare.
  ///
  /// In fr, this message translates to:
  /// **'Partager'**
  String get podcastsShare;

  /// No description provided for @podcastsLike.
  ///
  /// In fr, this message translates to:
  /// **'J\'aime'**
  String get podcastsLike;

  /// No description provided for @podcastsLiked.
  ///
  /// In fr, this message translates to:
  /// **'Aimé'**
  String get podcastsLiked;

  /// No description provided for @podcastsSleepTimer.
  ///
  /// In fr, this message translates to:
  /// **'Minuterie de sommeil'**
  String get podcastsSleepTimer;

  /// No description provided for @podcastsSleepTimerOff.
  ///
  /// In fr, this message translates to:
  /// **'Désactivé'**
  String get podcastsSleepTimerOff;

  /// No description provided for @podcastsSleepTimerMinutes.
  ///
  /// In fr, this message translates to:
  /// **'{minutes} minutes'**
  String podcastsSleepTimerMinutes(int minutes);

  /// No description provided for @podcastsSleepTimerEndOfEpisode.
  ///
  /// In fr, this message translates to:
  /// **'Fin de l\'épisode'**
  String get podcastsSleepTimerEndOfEpisode;

  /// No description provided for @podcastsPlaybackSpeed.
  ///
  /// In fr, this message translates to:
  /// **'Vitesse de lecture'**
  String get podcastsPlaybackSpeed;

  /// No description provided for @podcastsFromLiveRoom.
  ///
  /// In fr, this message translates to:
  /// **'Cet épisode a été enregistré lors d\'un salon audio en direct'**
  String get podcastsFromLiveRoom;

  /// No description provided for @podcastsTranscription.
  ///
  /// In fr, this message translates to:
  /// **'Transcription'**
  String get podcastsTranscription;

  /// No description provided for @podcastsReport.
  ///
  /// In fr, this message translates to:
  /// **'Signaler'**
  String get podcastsReport;

  /// No description provided for @podcastsReportSent.
  ///
  /// In fr, this message translates to:
  /// **'Signalement envoyé'**
  String get podcastsReportSent;

  /// No description provided for @podcastsCategoryNews.
  ///
  /// In fr, this message translates to:
  /// **'Actualités'**
  String get podcastsCategoryNews;

  /// No description provided for @podcastsCategoryCulture.
  ///
  /// In fr, this message translates to:
  /// **'Culture'**
  String get podcastsCategoryCulture;

  /// No description provided for @podcastsCategorySpirituality.
  ///
  /// In fr, this message translates to:
  /// **'Spiritualité'**
  String get podcastsCategorySpirituality;

  /// No description provided for @podcastsCategoryBusiness.
  ///
  /// In fr, this message translates to:
  /// **'Business'**
  String get podcastsCategoryBusiness;

  /// No description provided for @podcastsCategoryEntertainment.
  ///
  /// In fr, this message translates to:
  /// **'Divertissement'**
  String get podcastsCategoryEntertainment;

  /// No description provided for @podcastsCategoryEducation.
  ///
  /// In fr, this message translates to:
  /// **'Éducation'**
  String get podcastsCategoryEducation;

  /// No description provided for @podcastsCategoryStorytelling.
  ///
  /// In fr, this message translates to:
  /// **'Contes/Griot'**
  String get podcastsCategoryStorytelling;

  /// No description provided for @podcastsCategorySports.
  ///
  /// In fr, this message translates to:
  /// **'Sports'**
  String get podcastsCategorySports;

  /// No description provided for @podcastsCategoryPolitics.
  ///
  /// In fr, this message translates to:
  /// **'Politique'**
  String get podcastsCategoryPolitics;

  /// No description provided for @podcastsCategoryTechnology.
  ///
  /// In fr, this message translates to:
  /// **'Technologie'**
  String get podcastsCategoryTechnology;

  /// No description provided for @podcastsCategoryHealth.
  ///
  /// In fr, this message translates to:
  /// **'Santé'**
  String get podcastsCategoryHealth;

  /// No description provided for @podcastsCategoryOther.
  ///
  /// In fr, this message translates to:
  /// **'Autre'**
  String get podcastsCategoryOther;

  /// No description provided for @podcastsStatusDraft.
  ///
  /// In fr, this message translates to:
  /// **'Brouillon'**
  String get podcastsStatusDraft;

  /// No description provided for @podcastsStatusPublished.
  ///
  /// In fr, this message translates to:
  /// **'Publié'**
  String get podcastsStatusPublished;

  /// No description provided for @podcastsStatusPaused.
  ///
  /// In fr, this message translates to:
  /// **'En pause'**
  String get podcastsStatusPaused;

  /// No description provided for @podcastsStatusArchived.
  ///
  /// In fr, this message translates to:
  /// **'Archivé'**
  String get podcastsStatusArchived;

  /// No description provided for @podcastsStatusScheduled.
  ///
  /// In fr, this message translates to:
  /// **'Programmé'**
  String get podcastsStatusScheduled;

  /// No description provided for @podcastsDeletePodcast.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le podcast'**
  String get podcastsDeletePodcast;

  /// No description provided for @podcastsDeletePodcastConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Êtes-vous sûr de vouloir supprimer ce podcast et tous ses épisodes ?'**
  String get podcastsDeletePodcastConfirm;

  /// No description provided for @podcastsDeletedSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Podcast supprimé'**
  String get podcastsDeletedSuccess;

  /// No description provided for @podcastsEdit.
  ///
  /// In fr, this message translates to:
  /// **'Modifier'**
  String get podcastsEdit;

  /// No description provided for @podcastsStats.
  ///
  /// In fr, this message translates to:
  /// **'Statistiques'**
  String get podcastsStats;

  /// No description provided for @podcastsViewAll.
  ///
  /// In fr, this message translates to:
  /// **'Voir tout'**
  String get podcastsViewAll;

  /// No description provided for @callHistory.
  ///
  /// In fr, this message translates to:
  /// **'Historique des appels'**
  String get callHistory;

  /// No description provided for @clearHistory.
  ///
  /// In fr, this message translates to:
  /// **'Effacer l\'historique'**
  String get clearHistory;

  /// No description provided for @clearHistoryConfirmation.
  ///
  /// In fr, this message translates to:
  /// **'Êtes-vous sûr de vouloir effacer tout l\'historique des appels ?'**
  String get clearHistoryConfirmation;

  /// No description provided for @clear.
  ///
  /// In fr, this message translates to:
  /// **'Effacer'**
  String get clear;

  /// No description provided for @noCallHistory.
  ///
  /// In fr, this message translates to:
  /// **'Aucun appel'**
  String get noCallHistory;

  /// No description provided for @noCallHistoryDescription.
  ///
  /// In fr, this message translates to:
  /// **'Vos appels audio et vidéo apparaîtront ici'**
  String get noCallHistoryDescription;

  /// No description provided for @noMissedCalls.
  ///
  /// In fr, this message translates to:
  /// **'Aucun appel manqué'**
  String get noMissedCalls;

  /// No description provided for @noIncomingCalls.
  ///
  /// In fr, this message translates to:
  /// **'Aucun appel entrant'**
  String get noIncomingCalls;

  /// No description provided for @noOutgoingCalls.
  ///
  /// In fr, this message translates to:
  /// **'Aucun appel sortant'**
  String get noOutgoingCalls;

  /// No description provided for @busyCall.
  ///
  /// In fr, this message translates to:
  /// **'Occupé'**
  String get busyCall;

  /// No description provided for @today.
  ///
  /// In fr, this message translates to:
  /// **'Aujourd\'hui'**
  String today(String time);

  /// No description provided for @yesterday.
  ///
  /// In fr, this message translates to:
  /// **'Hier'**
  String yesterday(String time);

  /// No description provided for @missedCall.
  ///
  /// In fr, this message translates to:
  /// **'Appel manqué'**
  String get missedCall;

  /// No description provided for @declinedCall.
  ///
  /// In fr, this message translates to:
  /// **'Appel refusé'**
  String get declinedCall;

  /// No description provided for @incomingCall.
  ///
  /// In fr, this message translates to:
  /// **'Appel entrant'**
  String get incomingCall;

  /// No description provided for @outgoingCall.
  ///
  /// In fr, this message translates to:
  /// **'Appel sortant'**
  String get outgoingCall;

  /// No description provided for @audioCall.
  ///
  /// In fr, this message translates to:
  /// **'Appel audio'**
  String get audioCall;

  /// No description provided for @callConfirmMessage.
  ///
  /// In fr, this message translates to:
  /// **'Voulez-vous appeler'**
  String get callConfirmMessage;

  /// No description provided for @openLink.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir le lien'**
  String get openLink;

  /// No description provided for @openLinkConfirmMessage.
  ///
  /// In fr, this message translates to:
  /// **'Voulez-vous ouvrir ce lien ?'**
  String get openLinkConfirmMessage;

  /// No description provided for @videoCall.
  ///
  /// In fr, this message translates to:
  /// **'Appel vidéo'**
  String get videoCall;

  /// No description provided for @callEnded.
  ///
  /// In fr, this message translates to:
  /// **'Appel terminé'**
  String get callEnded;

  /// No description provided for @callDuration.
  ///
  /// In fr, this message translates to:
  /// **'Durée: {duration}'**
  String callDuration(String duration);

  /// No description provided for @noAnswer.
  ///
  /// In fr, this message translates to:
  /// **'Pas de réponse'**
  String get noAnswer;

  /// No description provided for @callAgain.
  ///
  /// In fr, this message translates to:
  /// **'Rappeler'**
  String get callAgain;

  /// No description provided for @callInProgress.
  ///
  /// In fr, this message translates to:
  /// **'Appel en cours'**
  String get callInProgress;

  /// No description provided for @returnToCall.
  ///
  /// In fr, this message translates to:
  /// **'Retour'**
  String get returnToCall;

  /// No description provided for @callInfo.
  ///
  /// In fr, this message translates to:
  /// **'Infos de l\'appel'**
  String get callInfo;

  /// No description provided for @callType.
  ///
  /// In fr, this message translates to:
  /// **'Type'**
  String get callType;

  /// No description provided for @voiceCall.
  ///
  /// In fr, this message translates to:
  /// **'Appel vocal'**
  String get voiceCall;

  /// No description provided for @callDirection.
  ///
  /// In fr, this message translates to:
  /// **'Direction'**
  String get callDirection;

  /// No description provided for @callStatus.
  ///
  /// In fr, this message translates to:
  /// **'Statut'**
  String get callStatus;

  /// No description provided for @callBack.
  ///
  /// In fr, this message translates to:
  /// **'Rappeler'**
  String get callBack;

  /// No description provided for @deleteCall.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer l\'appel'**
  String get deleteCall;

  /// No description provided for @deleteCallConfirmation.
  ///
  /// In fr, this message translates to:
  /// **'Êtes-vous sûr de vouloir supprimer cet appel de votre historique ?'**
  String get deleteCallConfirmation;

  /// No description provided for @callDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Appel supprimé'**
  String get callDeleted;

  /// No description provided for @paymentAccounts.
  ///
  /// In fr, this message translates to:
  /// **'Moyens de paiement'**
  String get paymentAccounts;

  /// No description provided for @paymentAccountsDesc.
  ///
  /// In fr, this message translates to:
  /// **'Gérer vos comptes pour recevoir de l\'argent'**
  String get paymentAccountsDesc;

  /// No description provided for @addPaymentAccount.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un compte'**
  String get addPaymentAccount;

  /// No description provided for @paymentAccountType.
  ///
  /// In fr, this message translates to:
  /// **'Type de compte'**
  String get paymentAccountType;

  /// No description provided for @paymentAccountLabel.
  ///
  /// In fr, this message translates to:
  /// **'Libellé du compte'**
  String get paymentAccountLabel;

  /// No description provided for @paymentAccountLabelRequired.
  ///
  /// In fr, this message translates to:
  /// **'Le libellé est obligatoire'**
  String get paymentAccountLabelRequired;

  /// No description provided for @stripeConnect.
  ///
  /// In fr, this message translates to:
  /// **'Stripe Connect'**
  String get stripeConnect;

  /// No description provided for @stripeConnectDesc.
  ///
  /// In fr, this message translates to:
  /// **'Connectez votre compte Stripe pour recevoir des paiements internationaux directement sur votre compte bancaire.'**
  String get stripeConnectDesc;

  /// No description provided for @stripeConnectSetup.
  ///
  /// In fr, this message translates to:
  /// **'Configurer Stripe Connect'**
  String get stripeConnectSetup;

  /// No description provided for @mobileMoney.
  ///
  /// In fr, this message translates to:
  /// **'Mobile Money'**
  String get mobileMoney;

  /// No description provided for @bankAccount.
  ///
  /// In fr, this message translates to:
  /// **'Compte bancaire'**
  String get bankAccount;

  /// No description provided for @mobileProvider.
  ///
  /// In fr, this message translates to:
  /// **'Opérateur'**
  String get mobileProvider;

  /// No description provided for @mobileNumber.
  ///
  /// In fr, this message translates to:
  /// **'Numéro de téléphone'**
  String get mobileNumber;

  /// No description provided for @mobileNumberRequired.
  ///
  /// In fr, this message translates to:
  /// **'Le numéro est obligatoire'**
  String get mobileNumberRequired;

  /// No description provided for @mobileNumberInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Numéro invalide (min. 8 chiffres)'**
  String get mobileNumberInvalid;

  /// No description provided for @bankName.
  ///
  /// In fr, this message translates to:
  /// **'Nom de la banque'**
  String get bankName;

  /// No description provided for @bankNameRequired.
  ///
  /// In fr, this message translates to:
  /// **'Le nom de la banque est obligatoire'**
  String get bankNameRequired;

  /// No description provided for @accountHolder.
  ///
  /// In fr, this message translates to:
  /// **'Titulaire du compte'**
  String get accountHolder;

  /// No description provided for @accountHolderRequired.
  ///
  /// In fr, this message translates to:
  /// **'Le titulaire est obligatoire'**
  String get accountHolderRequired;

  /// No description provided for @ibanLabel.
  ///
  /// In fr, this message translates to:
  /// **'IBAN / RIB'**
  String get ibanLabel;

  /// No description provided for @ibanRequired.
  ///
  /// In fr, this message translates to:
  /// **'L\'IBAN est obligatoire'**
  String get ibanRequired;

  /// No description provided for @bicLabel.
  ///
  /// In fr, this message translates to:
  /// **'BIC / SWIFT'**
  String get bicLabel;

  /// No description provided for @optional.
  ///
  /// In fr, this message translates to:
  /// **'optionnel'**
  String get optional;

  /// No description provided for @defaultAccount.
  ///
  /// In fr, this message translates to:
  /// **'Compte par défaut'**
  String get defaultAccount;

  /// No description provided for @setAsDefault.
  ///
  /// In fr, this message translates to:
  /// **'Définir par défaut'**
  String get setAsDefault;

  /// No description provided for @setAsDefaultDesc.
  ///
  /// In fr, this message translates to:
  /// **'Utiliser ce compte comme moyen de paiement principal'**
  String get setAsDefaultDesc;

  /// No description provided for @deletePaymentAccount.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le compte'**
  String get deletePaymentAccount;

  /// No description provided for @confirmDeletePaymentAccount.
  ///
  /// In fr, this message translates to:
  /// **'Êtes-vous sûr de vouloir supprimer ce compte de paiement ?'**
  String get confirmDeletePaymentAccount;

  /// No description provided for @accountAdded.
  ///
  /// In fr, this message translates to:
  /// **'Compte ajouté avec succès'**
  String get accountAdded;

  /// No description provided for @paymentAccountDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Compte supprimé'**
  String get paymentAccountDeleted;

  /// No description provided for @setAsDefaultSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Compte défini par défaut'**
  String get setAsDefaultSuccess;

  /// No description provided for @noPaymentAccounts.
  ///
  /// In fr, this message translates to:
  /// **'Aucun moyen de paiement configuré'**
  String get noPaymentAccounts;

  /// No description provided for @paymentAccountRequired.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez un moyen de paiement pour recevoir vos gains'**
  String get paymentAccountRequired;

  /// No description provided for @saveAccount.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer le compte'**
  String get saveAccount;

  /// No description provided for @saving.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrement...'**
  String get saving;

  /// No description provided for @confirmPayment.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer le paiement'**
  String get confirmPayment;

  /// No description provided for @paymentSummary.
  ///
  /// In fr, this message translates to:
  /// **'Récapitulatif'**
  String get paymentSummary;

  /// No description provided for @grossAmount.
  ///
  /// In fr, this message translates to:
  /// **'Montant brut'**
  String get grossAmount;

  /// No description provided for @commission.
  ///
  /// In fr, this message translates to:
  /// **'Commission'**
  String get commission;

  /// No description provided for @netAmount.
  ///
  /// In fr, this message translates to:
  /// **'Montant net'**
  String get netAmount;

  /// No description provided for @destinationAccount.
  ///
  /// In fr, this message translates to:
  /// **'Compte destinataire'**
  String get destinationAccount;

  /// No description provided for @confirmAndPay.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer et payer'**
  String get confirmAndPay;

  /// No description provided for @confirmPaymentBiometrics.
  ///
  /// In fr, this message translates to:
  /// **'Confirmez pour valider le paiement'**
  String get confirmPaymentBiometrics;

  /// No description provided for @enterPin.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez votre code PIN'**
  String get enterPin;

  /// No description provided for @useBiometrics.
  ///
  /// In fr, this message translates to:
  /// **'Utiliser la biométrie'**
  String get useBiometrics;

  /// No description provided for @enableBiometricsDesc.
  ///
  /// In fr, this message translates to:
  /// **'Utilisez votre empreinte digitale ou Face ID pour confirmer vos paiements plus rapidement.'**
  String get enableBiometricsDesc;

  /// No description provided for @notNow.
  ///
  /// In fr, this message translates to:
  /// **'Pas maintenant'**
  String get notNow;

  /// No description provided for @enable.
  ///
  /// In fr, this message translates to:
  /// **'Activer'**
  String get enable;

  /// No description provided for @setupPin.
  ///
  /// In fr, this message translates to:
  /// **'Configurer votre code PIN'**
  String get setupPin;

  /// No description provided for @setupPinDesc.
  ///
  /// In fr, this message translates to:
  /// **'Ce code à 4 chiffres protège vos transactions financières.'**
  String get setupPinDesc;

  /// No description provided for @confirmPin.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer le code PIN'**
  String get confirmPin;

  /// No description provided for @confirmPinDesc.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez à nouveau votre code PIN pour confirmer.'**
  String get confirmPinDesc;

  /// No description provided for @pinMismatch.
  ///
  /// In fr, this message translates to:
  /// **'Les codes ne correspondent pas'**
  String get pinMismatch;

  /// No description provided for @incorrectPin.
  ///
  /// In fr, this message translates to:
  /// **'Code PIN incorrect'**
  String get incorrectPin;

  /// No description provided for @tooManyAttempts.
  ///
  /// In fr, this message translates to:
  /// **'Trop de tentatives. Veuillez réessayer plus tard.'**
  String get tooManyAttempts;

  /// No description provided for @attemptsRemaining.
  ///
  /// In fr, this message translates to:
  /// **'tentatives restantes'**
  String get attemptsRemaining;

  /// No description provided for @paymentHistory.
  ///
  /// In fr, this message translates to:
  /// **'Historique des paiements'**
  String get paymentHistory;

  /// No description provided for @paymentHistoryDesc.
  ///
  /// In fr, this message translates to:
  /// **'Consultez toutes vos transactions'**
  String get paymentHistoryDesc;

  /// No description provided for @allTransactions.
  ///
  /// In fr, this message translates to:
  /// **'Toutes'**
  String get allTransactions;

  /// No description provided for @tickets.
  ///
  /// In fr, this message translates to:
  /// **'Tickets'**
  String get tickets;

  /// No description provided for @tips.
  ///
  /// In fr, this message translates to:
  /// **'Tips'**
  String get tips;

  /// No description provided for @sales.
  ///
  /// In fr, this message translates to:
  /// **'Ventes'**
  String get sales;

  /// No description provided for @payouts.
  ///
  /// In fr, this message translates to:
  /// **'Versements'**
  String get payouts;

  /// No description provided for @statusPending.
  ///
  /// In fr, this message translates to:
  /// **'En attente'**
  String get statusPending;

  /// No description provided for @statusProcessing.
  ///
  /// In fr, this message translates to:
  /// **'En cours'**
  String get statusProcessing;

  /// No description provided for @statusCompleted.
  ///
  /// In fr, this message translates to:
  /// **'Terminé'**
  String get statusCompleted;

  /// No description provided for @statusFailed.
  ///
  /// In fr, this message translates to:
  /// **'Échoué'**
  String get statusFailed;

  /// No description provided for @statusCancelled.
  ///
  /// In fr, this message translates to:
  /// **'Annulé'**
  String get statusCancelled;

  /// No description provided for @statusRefunded.
  ///
  /// In fr, this message translates to:
  /// **'Remboursé'**
  String get statusRefunded;

  /// No description provided for @transactionDetail.
  ///
  /// In fr, this message translates to:
  /// **'Détail de la transaction'**
  String get transactionDetail;

  /// No description provided for @reportIssue.
  ///
  /// In fr, this message translates to:
  /// **'Signaler un problème'**
  String get reportIssue;

  /// No description provided for @noTransactions.
  ///
  /// In fr, this message translates to:
  /// **'Aucune transaction'**
  String get noTransactions;

  /// No description provided for @counterparty.
  ///
  /// In fr, this message translates to:
  /// **'Contrepartie'**
  String get counterparty;

  /// No description provided for @dateLabel.
  ///
  /// In fr, this message translates to:
  /// **'Date'**
  String get dateLabel;

  /// No description provided for @completedOn.
  ///
  /// In fr, this message translates to:
  /// **'Complété le'**
  String get completedOn;

  /// No description provided for @referenceLabel.
  ///
  /// In fr, this message translates to:
  /// **'Référence'**
  String get referenceLabel;

  /// No description provided for @copied.
  ///
  /// In fr, this message translates to:
  /// **'Copié!'**
  String get copied;

  /// No description provided for @descriptionLabel.
  ///
  /// In fr, this message translates to:
  /// **'Description'**
  String get descriptionLabel;

  /// No description provided for @paymentTypeTicket.
  ///
  /// In fr, this message translates to:
  /// **'Ticket'**
  String get paymentTypeTicket;

  /// No description provided for @paymentTypeTip.
  ///
  /// In fr, this message translates to:
  /// **'Tip'**
  String get paymentTypeTip;

  /// No description provided for @paymentTypeSale.
  ///
  /// In fr, this message translates to:
  /// **'Vente'**
  String get paymentTypeSale;

  /// No description provided for @paymentTypePayout.
  ///
  /// In fr, this message translates to:
  /// **'Versement'**
  String get paymentTypePayout;

  /// No description provided for @paymentTypeTransfer.
  ///
  /// In fr, this message translates to:
  /// **'Transfert'**
  String get paymentTypeTransfer;

  /// No description provided for @reportTransactionSubject.
  ///
  /// In fr, this message translates to:
  /// **'Problème transaction #{id} - {type}'**
  String reportTransactionSubject(String id, String type);

  /// No description provided for @reportTransactionIntro.
  ///
  /// In fr, this message translates to:
  /// **'Bonjour,\n\nJe signale un problème avec la transaction suivante :\n'**
  String get reportTransactionIntro;

  /// No description provided for @describeYourProblem.
  ///
  /// In fr, this message translates to:
  /// **'Décrivez votre problème :\n'**
  String get describeYourProblem;

  /// No description provided for @supportTickets.
  ///
  /// In fr, this message translates to:
  /// **'Tickets de support'**
  String get supportTickets;

  /// No description provided for @newSupportTicket.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau ticket'**
  String get newSupportTicket;

  /// No description provided for @supportTicketCreated.
  ///
  /// In fr, this message translates to:
  /// **'Ticket créé avec succès'**
  String get supportTicketCreated;

  /// No description provided for @supportTicketUpdated.
  ///
  /// In fr, this message translates to:
  /// **'Ticket mis à jour'**
  String get supportTicketUpdated;

  /// No description provided for @supportReply.
  ///
  /// In fr, this message translates to:
  /// **'Réponse du support'**
  String get supportReply;

  /// No description provided for @ticketOpen.
  ///
  /// In fr, this message translates to:
  /// **'Ouvert'**
  String get ticketOpen;

  /// No description provided for @ticketInProgress.
  ///
  /// In fr, this message translates to:
  /// **'En cours'**
  String get ticketInProgress;

  /// No description provided for @ticketResolved.
  ///
  /// In fr, this message translates to:
  /// **'Résolu'**
  String get ticketResolved;

  /// No description provided for @ticketClosed.
  ///
  /// In fr, this message translates to:
  /// **'Fermé'**
  String get ticketClosed;

  /// No description provided for @yourMessage.
  ///
  /// In fr, this message translates to:
  /// **'Votre message...'**
  String get yourMessage;

  /// No description provided for @sendReply.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer'**
  String get sendReply;

  /// No description provided for @supportTeam.
  ///
  /// In fr, this message translates to:
  /// **'Équipe Support'**
  String get supportTeam;

  /// No description provided for @noSupportTickets.
  ///
  /// In fr, this message translates to:
  /// **'Aucun ticket de support'**
  String get noSupportTickets;

  /// No description provided for @noSupportTicketsDesc.
  ///
  /// In fr, this message translates to:
  /// **'Vos demandes d\'assistance apparaîtront ici'**
  String get noSupportTicketsDesc;

  /// No description provided for @ticketSubject.
  ///
  /// In fr, this message translates to:
  /// **'Sujet'**
  String get ticketSubject;

  /// No description provided for @ticketDescription.
  ///
  /// In fr, this message translates to:
  /// **'Description du problème'**
  String get ticketDescription;

  /// No description provided for @ticketDescriptionRequired.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez décrire le problème'**
  String get ticketDescriptionRequired;

  /// No description provided for @ticketCategory.
  ///
  /// In fr, this message translates to:
  /// **'Catégorie'**
  String get ticketCategory;

  /// No description provided for @ticketCategoryTransaction.
  ///
  /// In fr, this message translates to:
  /// **'Transaction'**
  String get ticketCategoryTransaction;

  /// No description provided for @ticketCategoryAccount.
  ///
  /// In fr, this message translates to:
  /// **'Compte'**
  String get ticketCategoryAccount;

  /// No description provided for @ticketCategoryTechnical.
  ///
  /// In fr, this message translates to:
  /// **'Technique'**
  String get ticketCategoryTechnical;

  /// No description provided for @ticketCategoryOther.
  ///
  /// In fr, this message translates to:
  /// **'Autre'**
  String get ticketCategoryOther;

  /// No description provided for @supportNotificationTitle.
  ///
  /// In fr, this message translates to:
  /// **'Réponse du support'**
  String get supportNotificationTitle;

  /// No description provided for @supportNotificationBody.
  ///
  /// In fr, this message translates to:
  /// **'Votre ticket \"{subject}\" a reçu une réponse'**
  String supportNotificationBody(String subject);

  /// No description provided for @forward.
  ///
  /// In fr, this message translates to:
  /// **'Transférer'**
  String get forward;

  /// No description provided for @forwarded.
  ///
  /// In fr, this message translates to:
  /// **'Transféré'**
  String get forwarded;

  /// No description provided for @forwardTo.
  ///
  /// In fr, this message translates to:
  /// **'Transférer à...'**
  String get forwardTo;

  /// No description provided for @messageForwarded.
  ///
  /// In fr, this message translates to:
  /// **'Message transféré'**
  String get messageForwarded;

  /// No description provided for @messagesForwarded.
  ///
  /// In fr, this message translates to:
  /// **'{count} messages transférés'**
  String messagesForwarded(int count);

  /// No description provided for @deleteSelectedMessages.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer {count} message{count, plural, =1{} other{s}} ?'**
  String deleteSelectedMessages(int count);

  /// No description provided for @messagesDeletedForYou.
  ///
  /// In fr, this message translates to:
  /// **'Les messages seront supprimés pour vous uniquement.'**
  String get messagesDeletedForYou;

  /// No description provided for @messagesDeletedSuccess.
  ///
  /// In fr, this message translates to:
  /// **'{count} message{count, plural, =1{} other{s}} supprimé{count, plural, =1{} other{s}}'**
  String messagesDeletedSuccess(int count);

  /// No description provided for @searchConversation.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher une conversation...'**
  String get searchConversation;

  /// No description provided for @noConversationFound.
  ///
  /// In fr, this message translates to:
  /// **'Aucune conversation trouvée'**
  String get noConversationFound;

  /// No description provided for @messageCopied.
  ///
  /// In fr, this message translates to:
  /// **'Message copié'**
  String get messageCopied;

  /// No description provided for @reply.
  ///
  /// In fr, this message translates to:
  /// **'Répondre'**
  String get reply;

  /// No description provided for @react.
  ///
  /// In fr, this message translates to:
  /// **'Réagir'**
  String get react;

  /// No description provided for @copy.
  ///
  /// In fr, this message translates to:
  /// **'Copier'**
  String get copy;

  /// No description provided for @report.
  ///
  /// In fr, this message translates to:
  /// **'Signaler'**
  String get report;

  /// No description provided for @transferSendMoney.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer de l\'argent'**
  String get transferSendMoney;

  /// No description provided for @transferReset.
  ///
  /// In fr, this message translates to:
  /// **'Réinitialiser'**
  String get transferReset;

  /// No description provided for @transferContinue.
  ///
  /// In fr, this message translates to:
  /// **'Continuer'**
  String get transferContinue;

  /// No description provided for @transferBack.
  ///
  /// In fr, this message translates to:
  /// **'Retour'**
  String get transferBack;

  /// No description provided for @transferRecipient.
  ///
  /// In fr, this message translates to:
  /// **'Bénéficiaire'**
  String get transferRecipient;

  /// No description provided for @transferPaymentMethod.
  ///
  /// In fr, this message translates to:
  /// **'Mode de paiement'**
  String get transferPaymentMethod;

  /// No description provided for @transferAmount.
  ///
  /// In fr, this message translates to:
  /// **'Montant'**
  String get transferAmount;

  /// No description provided for @transferConfirmation.
  ///
  /// In fr, this message translates to:
  /// **'Confirmation'**
  String get transferConfirmation;

  /// No description provided for @transferConfirmButton.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer'**
  String get transferConfirmButton;

  /// No description provided for @transferAddRecipient.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un bénéficiaire'**
  String get transferAddRecipient;

  /// No description provided for @transferSelectExistingRecipient.
  ///
  /// In fr, this message translates to:
  /// **'Ou sélectionnez un bénéficiaire existant'**
  String get transferSelectExistingRecipient;

  /// No description provided for @transferNoRecipients.
  ///
  /// In fr, this message translates to:
  /// **'Aucun bénéficiaire enregistré'**
  String get transferNoRecipients;

  /// No description provided for @transferFavorites.
  ///
  /// In fr, this message translates to:
  /// **'Favoris'**
  String get transferFavorites;

  /// No description provided for @transferRecentlyUsed.
  ///
  /// In fr, this message translates to:
  /// **'Récemment utilisés'**
  String get transferRecentlyUsed;

  /// No description provided for @transferOtherRecipients.
  ///
  /// In fr, this message translates to:
  /// **'Autres bénéficiaires'**
  String get transferOtherRecipients;

  /// No description provided for @transferSelectPaymentMethod.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionnez un mode de paiement'**
  String get transferSelectPaymentMethod;

  /// No description provided for @transferDebitAccountInfo.
  ///
  /// In fr, this message translates to:
  /// **'Informations du compte à débiter'**
  String get transferDebitAccountInfo;

  /// No description provided for @transferCountryCode.
  ///
  /// In fr, this message translates to:
  /// **'Indicatif'**
  String get transferCountryCode;

  /// No description provided for @transferMynitaNumber.
  ///
  /// In fr, this message translates to:
  /// **'Numéro Mynita *'**
  String get transferMynitaNumber;

  /// No description provided for @transferWaveNumber.
  ///
  /// In fr, this message translates to:
  /// **'Numéro Wave *'**
  String get transferWaveNumber;

  /// No description provided for @transferPhoneHint.
  ///
  /// In fr, this message translates to:
  /// **'XX XX XX XX'**
  String get transferPhoneHint;

  /// No description provided for @transferPhoneRequired.
  ///
  /// In fr, this message translates to:
  /// **'Le numéro est requis'**
  String get transferPhoneRequired;

  /// No description provided for @transferPhoneInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Numéro invalide'**
  String get transferPhoneInvalid;

  /// No description provided for @transferBankName.
  ///
  /// In fr, this message translates to:
  /// **'Nom de la banque *'**
  String get transferBankName;

  /// No description provided for @transferBankNameRequired.
  ///
  /// In fr, this message translates to:
  /// **'Le nom de la banque est requis'**
  String get transferBankNameRequired;

  /// No description provided for @transferAccountNumberIban.
  ///
  /// In fr, this message translates to:
  /// **'Numéro de compte / IBAN *'**
  String get transferAccountNumberIban;

  /// No description provided for @transferAccountNumberIbanHint.
  ///
  /// In fr, this message translates to:
  /// **'XXXX XXXX XXXX XXXX'**
  String get transferAccountNumberIbanHint;

  /// No description provided for @transferAccountNumberRequired.
  ///
  /// In fr, this message translates to:
  /// **'Le numéro de compte est requis'**
  String get transferAccountNumberRequired;

  /// No description provided for @transferCurrency.
  ///
  /// In fr, this message translates to:
  /// **'Devise'**
  String get transferCurrency;

  /// No description provided for @transferAmountToSend.
  ///
  /// In fr, this message translates to:
  /// **'Montant à envoyer'**
  String get transferAmountToSend;

  /// No description provided for @transferMinimumAmount.
  ///
  /// In fr, this message translates to:
  /// **'Minimum 5 {currency}'**
  String transferMinimumAmount(String currency);

  /// No description provided for @transferEnterAmount.
  ///
  /// In fr, this message translates to:
  /// **'Entrez un montant'**
  String get transferEnterAmount;

  /// No description provided for @transferInvalidAmount.
  ///
  /// In fr, this message translates to:
  /// **'Montant invalide'**
  String get transferInvalidAmount;

  /// No description provided for @transferMessageOptional.
  ///
  /// In fr, this message translates to:
  /// **'Message (optionnel)'**
  String get transferMessageOptional;

  /// No description provided for @transferMessageHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex: Pour les courses'**
  String get transferMessageHint;

  /// No description provided for @transferSummary.
  ///
  /// In fr, this message translates to:
  /// **'Récapitulatif'**
  String get transferSummary;

  /// No description provided for @transferAmountSent.
  ///
  /// In fr, this message translates to:
  /// **'Montant :'**
  String get transferAmountSent;

  /// No description provided for @transferFees.
  ///
  /// In fr, this message translates to:
  /// **'Frais :'**
  String transferFees(String percent);

  /// No description provided for @transferTotalDebited.
  ///
  /// In fr, this message translates to:
  /// **'Total débité'**
  String get transferTotalDebited;

  /// No description provided for @transferExchangeRate.
  ///
  /// In fr, this message translates to:
  /// **'Taux de change'**
  String transferExchangeRate(String from, String rate);

  /// No description provided for @transferRecipientWillReceive.
  ///
  /// In fr, this message translates to:
  /// **'Le bénéficiaire recevra'**
  String get transferRecipientWillReceive;

  /// No description provided for @transferAmountToReceive.
  ///
  /// In fr, this message translates to:
  /// **'Montant à recevoir'**
  String get transferAmountToReceive;

  /// No description provided for @transferTotalDebitedAmount.
  ///
  /// In fr, this message translates to:
  /// **'Total débité: {amount} {currency}'**
  String transferTotalDebitedAmount(String amount, String currency);

  /// No description provided for @transferPayVia.
  ///
  /// In fr, this message translates to:
  /// **'Payer via {method}'**
  String transferPayVia(String method);

  /// No description provided for @transferTermsAndConditions.
  ///
  /// In fr, this message translates to:
  /// **'En confirmant, vous acceptez les conditions générales de transfert. Les fonds seront disponibles sous 24h.'**
  String get transferTermsAndConditions;

  /// No description provided for @transferSelectRecipientError.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionnez un bénéficiaire'**
  String get transferSelectRecipientError;

  /// No description provided for @transferSelectPaymentMethodError.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionnez un mode de paiement'**
  String get transferSelectPaymentMethodError;

  /// No description provided for @transferFeeCalculationError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors du calcul des frais'**
  String get transferFeeCalculationError;

  /// No description provided for @transferConfirmTitle.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer le transfert'**
  String get transferConfirmTitle;

  /// No description provided for @transferAboutToSend.
  ///
  /// In fr, this message translates to:
  /// **'Vous êtes sur le point d\'envoyer:'**
  String get transferAboutToSend;

  /// No description provided for @transferAmountLabel.
  ///
  /// In fr, this message translates to:
  /// **'Montant à envoyer'**
  String get transferAmountLabel;

  /// No description provided for @transferFeesLabel.
  ///
  /// In fr, this message translates to:
  /// **'Frais'**
  String get transferFeesLabel;

  /// No description provided for @transferTotalLabel.
  ///
  /// In fr, this message translates to:
  /// **'Total:'**
  String get transferTotalLabel;

  /// No description provided for @transferFromLabel.
  ///
  /// In fr, this message translates to:
  /// **'De: {method} ({account})'**
  String transferFromLabel(String method, String account);

  /// No description provided for @transferToLabel.
  ///
  /// In fr, this message translates to:
  /// **'À: {name}'**
  String transferToLabel(String name);

  /// No description provided for @transferIrreversibleWarning.
  ///
  /// In fr, this message translates to:
  /// **'Cette action est irréversible. Voulez-vous continuer?'**
  String get transferIrreversibleWarning;

  /// No description provided for @transferInitiatedSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Transfert initié avec succès'**
  String get transferInitiatedSuccess;

  /// No description provided for @transferSecureTitle.
  ///
  /// In fr, this message translates to:
  /// **'Transfert sécurisé'**
  String get transferSecureTitle;

  /// No description provided for @transferSecureMessage.
  ///
  /// In fr, this message translates to:
  /// **'Les transferts d\'argent nécessitent l\'installation de l\'application depuis Google Play Store pour garantir la sécurité de vos transactions.'**
  String get transferSecureMessage;

  /// No description provided for @transferUserNotConnected.
  ///
  /// In fr, this message translates to:
  /// **'Utilisateur non connecté'**
  String get transferUserNotConnected;

  /// No description provided for @transferError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur: {error}'**
  String transferError(String error);

  /// No description provided for @recipientEditTitle.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le bénéficiaire'**
  String get recipientEditTitle;

  /// No description provided for @recipientNewTitle.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau bénéficiaire'**
  String get recipientNewTitle;

  /// No description provided for @recipientPersonalInfo.
  ///
  /// In fr, this message translates to:
  /// **'Informations personnelles'**
  String get recipientPersonalInfo;

  /// No description provided for @recipientFullName.
  ///
  /// In fr, this message translates to:
  /// **'Nom complet *'**
  String get recipientFullName;

  /// No description provided for @recipientFullNameHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex: Amadou Boubacar'**
  String get recipientFullNameHint;

  /// No description provided for @recipientNameRequired.
  ///
  /// In fr, this message translates to:
  /// **'Le nom est requis'**
  String get recipientNameRequired;

  /// No description provided for @recipientNameTooShort.
  ///
  /// In fr, this message translates to:
  /// **'Le nom doit contenir au moins 3 caractères'**
  String get recipientNameTooShort;

  /// No description provided for @recipientPhoneNumber.
  ///
  /// In fr, this message translates to:
  /// **'Numéro de téléphone *'**
  String get recipientPhoneNumber;

  /// No description provided for @recipientEmailOptional.
  ///
  /// In fr, this message translates to:
  /// **'Email (optionnel)'**
  String get recipientEmailOptional;

  /// No description provided for @recipientEmailHint.
  ///
  /// In fr, this message translates to:
  /// **'exemple@email.com'**
  String get recipientEmailHint;

  /// No description provided for @recipientEmailInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Email invalide'**
  String get recipientEmailInvalid;

  /// No description provided for @recipientReceptionMode.
  ///
  /// In fr, this message translates to:
  /// **'Mode de réception'**
  String get recipientReceptionMode;

  /// No description provided for @recipientPaymentDetails.
  ///
  /// In fr, this message translates to:
  /// **'Détails de paiement'**
  String get recipientPaymentDetails;

  /// No description provided for @recipientMobilePaymentInfo.
  ///
  /// In fr, this message translates to:
  /// **'Le transfert sera effectué via {service} sur le numéro de téléphone du bénéficiaire.'**
  String recipientMobilePaymentInfo(String service);

  /// No description provided for @recipientCashPickupInfo.
  ///
  /// In fr, this message translates to:
  /// **'Le bénéficiaire pourra retirer l\'argent dans un point de service NITA avec une pièce d\'identité.'**
  String get recipientCashPickupInfo;

  /// No description provided for @recipientSelectBank.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionnez une banque'**
  String get recipientSelectBank;

  /// No description provided for @recipientAccountNumber.
  ///
  /// In fr, this message translates to:
  /// **'Numéro de compte *'**
  String get recipientAccountNumber;

  /// No description provided for @recipientAccountNumberHint.
  ///
  /// In fr, this message translates to:
  /// **'XXXX XXXX XXXX XXXX'**
  String get recipientAccountNumberHint;

  /// No description provided for @recipientAccountNumberRequired.
  ///
  /// In fr, this message translates to:
  /// **'Le numéro de compte est requis'**
  String get recipientAccountNumberRequired;

  /// No description provided for @recipientAccountNumberInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Numéro de compte invalide'**
  String get recipientAccountNumberInvalid;

  /// No description provided for @recipientLocation.
  ///
  /// In fr, this message translates to:
  /// **'Localisation'**
  String get recipientLocation;

  /// No description provided for @recipientCountry.
  ///
  /// In fr, this message translates to:
  /// **'Pays'**
  String get recipientCountry;

  /// No description provided for @recipientCity.
  ///
  /// In fr, this message translates to:
  /// **'Ville'**
  String get recipientCity;

  /// No description provided for @recipientAddressOptional.
  ///
  /// In fr, this message translates to:
  /// **'Adresse (optionnel)'**
  String get recipientAddressOptional;

  /// No description provided for @recipientAddressHint.
  ///
  /// In fr, this message translates to:
  /// **'Quartier, rue...'**
  String get recipientAddressHint;

  /// No description provided for @recipientAddToFavorites.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter aux favoris'**
  String get recipientAddToFavorites;

  /// No description provided for @recipientFavoritesQuickAccess.
  ///
  /// In fr, this message translates to:
  /// **'Accès rapide lors des prochains transferts'**
  String get recipientFavoritesQuickAccess;

  /// No description provided for @recipientSaveChanges.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer les modifications'**
  String get recipientSaveChanges;

  /// No description provided for @recipientAddButton.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter le bénéficiaire'**
  String get recipientAddButton;

  /// No description provided for @recipientModifiedSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Bénéficiaire modifié avec succès'**
  String get recipientModifiedSuccess;

  /// No description provided for @recipientAddedSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Bénéficiaire ajouté avec succès'**
  String get recipientAddedSuccess;

  /// No description provided for @recipientDeleteTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le bénéficiaire ?'**
  String get recipientDeleteTitle;

  /// No description provided for @recipientDeleteConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Voulez-vous vraiment supprimer {name} de vos bénéficiaires ?'**
  String recipientDeleteConfirm(String name);

  /// No description provided for @recipientDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Bénéficiaire supprimé'**
  String get recipientDeleted;

  /// No description provided for @recipientTypeMynita.
  ///
  /// In fr, this message translates to:
  /// **'Mynita'**
  String get recipientTypeMynita;

  /// No description provided for @recipientTypeWave.
  ///
  /// In fr, this message translates to:
  /// **'Wave'**
  String get recipientTypeWave;

  /// No description provided for @recipientTypeBankAccount.
  ///
  /// In fr, this message translates to:
  /// **'Compte bancaire'**
  String get recipientTypeBankAccount;

  /// No description provided for @recipientTypeCashPickup.
  ///
  /// In fr, this message translates to:
  /// **'Retrait espèces'**
  String get recipientTypeCashPickup;

  /// No description provided for @recipientTypeMynitaDesc.
  ///
  /// In fr, this message translates to:
  /// **'Transfert via Mynita'**
  String get recipientTypeMynitaDesc;

  /// No description provided for @recipientTypeWaveDesc.
  ///
  /// In fr, this message translates to:
  /// **'Transfert via Wave'**
  String get recipientTypeWaveDesc;

  /// No description provided for @recipientTypeBankAccountDesc.
  ///
  /// In fr, this message translates to:
  /// **'Virement bancaire direct'**
  String get recipientTypeBankAccountDesc;

  /// No description provided for @recipientTypeCashPickupDesc.
  ///
  /// In fr, this message translates to:
  /// **'Retrait dans un point de service'**
  String get recipientTypeCashPickupDesc;

  /// No description provided for @senderPaymentMynita.
  ///
  /// In fr, this message translates to:
  /// **'Mynita'**
  String get senderPaymentMynita;

  /// No description provided for @senderPaymentWave.
  ///
  /// In fr, this message translates to:
  /// **'Wave'**
  String get senderPaymentWave;

  /// No description provided for @senderPaymentBankAccount.
  ///
  /// In fr, this message translates to:
  /// **'Compte bancaire'**
  String get senderPaymentBankAccount;

  /// No description provided for @senderPaymentMynitaDesc.
  ///
  /// In fr, this message translates to:
  /// **'Payer via Mynita'**
  String get senderPaymentMynitaDesc;

  /// No description provided for @senderPaymentWaveDesc.
  ///
  /// In fr, this message translates to:
  /// **'Payer via Wave'**
  String get senderPaymentWaveDesc;

  /// No description provided for @senderPaymentBankAccountDesc.
  ///
  /// In fr, this message translates to:
  /// **'Payer par virement bancaire'**
  String get senderPaymentBankAccountDesc;

  /// No description provided for @starMessage.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter aux favoris'**
  String get starMessage;

  /// No description provided for @unstarMessage.
  ///
  /// In fr, this message translates to:
  /// **'Retirer des favoris'**
  String get unstarMessage;

  /// No description provided for @starredMessages.
  ///
  /// In fr, this message translates to:
  /// **'Messages favoris'**
  String get starredMessages;

  /// No description provided for @noStarredMessages.
  ///
  /// In fr, this message translates to:
  /// **'Aucun message favori'**
  String get noStarredMessages;

  /// No description provided for @searchMessages.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher dans la conversation...'**
  String get searchMessages;

  /// No description provided for @noSearchResults.
  ///
  /// In fr, this message translates to:
  /// **'Aucun résultat'**
  String get noSearchResults;

  /// No description provided for @selectAll.
  ///
  /// In fr, this message translates to:
  /// **'Tout sélectionner'**
  String get selectAll;

  /// No description provided for @deselectAll.
  ///
  /// In fr, this message translates to:
  /// **'Tout désélectionner'**
  String get deselectAll;

  /// No description provided for @callHold.
  ///
  /// In fr, this message translates to:
  /// **'Attente'**
  String get callHold;

  /// No description provided for @callResume.
  ///
  /// In fr, this message translates to:
  /// **'Reprendre'**
  String get callResume;

  /// No description provided for @callOnHold.
  ///
  /// In fr, this message translates to:
  /// **'En attente'**
  String get callOnHold;

  /// No description provided for @callReconnecting.
  ///
  /// In fr, this message translates to:
  /// **'Reconnexion...'**
  String get callReconnecting;

  /// No description provided for @callError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de l\'appel'**
  String get callError;

  /// No description provided for @callQualityGood.
  ///
  /// In fr, this message translates to:
  /// **'Bonne qualité'**
  String get callQualityGood;

  /// No description provided for @callQualityFair.
  ///
  /// In fr, this message translates to:
  /// **'Qualité moyenne'**
  String get callQualityFair;

  /// No description provided for @callQualityPoor.
  ///
  /// In fr, this message translates to:
  /// **'Mauvaise qualité'**
  String get callQualityPoor;

  /// No description provided for @groupCallTitle.
  ///
  /// In fr, this message translates to:
  /// **'Group Call'**
  String get groupCallTitle;

  /// No description provided for @groupCallCreate.
  ///
  /// In fr, this message translates to:
  /// **'Démarrer appel de groupe'**
  String get groupCallCreate;

  /// No description provided for @groupCallJoin.
  ///
  /// In fr, this message translates to:
  /// **'Join'**
  String get groupCallJoin;

  /// No description provided for @groupCallLeave.
  ///
  /// In fr, this message translates to:
  /// **'Quitter l\'appel'**
  String get groupCallLeave;

  /// No description provided for @groupCallEnd.
  ///
  /// In fr, this message translates to:
  /// **'Terminer l\'appel'**
  String get groupCallEnd;

  /// No description provided for @groupCallInvite.
  ///
  /// In fr, this message translates to:
  /// **'Inviter des participants'**
  String get groupCallInvite;

  /// No description provided for @groupCallParticipants.
  ///
  /// In fr, this message translates to:
  /// **'{count} participants'**
  String groupCallParticipants(int count);

  /// No description provided for @groupCallWaiting.
  ///
  /// In fr, this message translates to:
  /// **'En attente des participants...'**
  String get groupCallWaiting;

  /// No description provided for @groupCallConnecting.
  ///
  /// In fr, this message translates to:
  /// **'Connexion en cours...'**
  String get groupCallConnecting;

  /// No description provided for @groupCallConnected.
  ///
  /// In fr, this message translates to:
  /// **'Connecté'**
  String get groupCallConnected;

  /// No description provided for @groupCallDisconnected.
  ///
  /// In fr, this message translates to:
  /// **'Déconnecté'**
  String get groupCallDisconnected;

  /// No description provided for @groupCallReconnecting.
  ///
  /// In fr, this message translates to:
  /// **'Reconnexion...'**
  String get groupCallReconnecting;

  /// No description provided for @groupCallMeshMode.
  ///
  /// In fr, this message translates to:
  /// **'Connexion directe'**
  String get groupCallMeshMode;

  /// No description provided for @groupCallSfuMode.
  ///
  /// In fr, this message translates to:
  /// **'Via serveur'**
  String get groupCallSfuMode;

  /// No description provided for @groupCallE2eeEnabled.
  ///
  /// In fr, this message translates to:
  /// **'Chiffré de bout en bout'**
  String get groupCallE2eeEnabled;

  /// No description provided for @groupCallE2eeDisabled.
  ///
  /// In fr, this message translates to:
  /// **'Non chiffré'**
  String get groupCallE2eeDisabled;

  /// No description provided for @groupCallE2eeVerify.
  ///
  /// In fr, this message translates to:
  /// **'Vérifier le chiffrement'**
  String get groupCallE2eeVerify;

  /// No description provided for @groupCallE2eeVerificationCode.
  ///
  /// In fr, this message translates to:
  /// **'Code de vérification : {code}'**
  String groupCallE2eeVerificationCode(String code);

  /// No description provided for @groupCallE2eeVerifyHint.
  ///
  /// In fr, this message translates to:
  /// **'Comparez ce code avec les autres participants pour vérifier le chiffrement'**
  String get groupCallE2eeVerifyHint;

  /// No description provided for @groupCallVideoQuality.
  ///
  /// In fr, this message translates to:
  /// **'Qualité vidéo'**
  String get groupCallVideoQuality;

  /// No description provided for @groupCallVideoQualityLow.
  ///
  /// In fr, this message translates to:
  /// **'Basse (180p)'**
  String get groupCallVideoQualityLow;

  /// No description provided for @groupCallVideoQualityMedium.
  ///
  /// In fr, this message translates to:
  /// **'Moyenne (360p)'**
  String get groupCallVideoQualityMedium;

  /// No description provided for @groupCallVideoQualityHigh.
  ///
  /// In fr, this message translates to:
  /// **'Haute (720p)'**
  String get groupCallVideoQualityHigh;

  /// No description provided for @groupCallVideoQualityAuto.
  ///
  /// In fr, this message translates to:
  /// **'Automatique'**
  String get groupCallVideoQualityAuto;

  /// No description provided for @groupCallScreenShare.
  ///
  /// In fr, this message translates to:
  /// **'Partager l\'écran'**
  String get groupCallScreenShare;

  /// No description provided for @groupCallStopScreenShare.
  ///
  /// In fr, this message translates to:
  /// **'Arrêter le partage'**
  String get groupCallStopScreenShare;

  /// No description provided for @groupCallRaiseHand.
  ///
  /// In fr, this message translates to:
  /// **'Lever la main'**
  String get groupCallRaiseHand;

  /// No description provided for @groupCallLowerHand.
  ///
  /// In fr, this message translates to:
  /// **'Baisser la main'**
  String get groupCallLowerHand;

  /// No description provided for @groupCallHandRaised.
  ///
  /// In fr, this message translates to:
  /// **'{name} a levé la main'**
  String groupCallHandRaised(String name);

  /// No description provided for @groupCallMuted.
  ///
  /// In fr, this message translates to:
  /// **'Micro coupé'**
  String get groupCallMuted;

  /// No description provided for @groupCallUnmuted.
  ///
  /// In fr, this message translates to:
  /// **'Micro activé'**
  String get groupCallUnmuted;

  /// No description provided for @groupCallCameraOff.
  ///
  /// In fr, this message translates to:
  /// **'Caméra désactivée'**
  String get groupCallCameraOff;

  /// No description provided for @groupCallCameraOn.
  ///
  /// In fr, this message translates to:
  /// **'Caméra activée'**
  String get groupCallCameraOn;

  /// No description provided for @groupCallSpeaking.
  ///
  /// In fr, this message translates to:
  /// **'Parle'**
  String get groupCallSpeaking;

  /// No description provided for @groupCallNetworkPoor.
  ///
  /// In fr, this message translates to:
  /// **'Mauvaise connexion'**
  String get groupCallNetworkPoor;

  /// No description provided for @groupCallNetworkGood.
  ///
  /// In fr, this message translates to:
  /// **'Bonne connexion'**
  String get groupCallNetworkGood;

  /// No description provided for @groupCallParticipantJoined.
  ///
  /// In fr, this message translates to:
  /// **'{name} a rejoint'**
  String groupCallParticipantJoined(String name);

  /// No description provided for @groupCallParticipantLeft.
  ///
  /// In fr, this message translates to:
  /// **'{name} a quitté'**
  String groupCallParticipantLeft(String name);

  /// No description provided for @groupCallSelectParticipants.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionner les participants'**
  String get groupCallSelectParticipants;

  /// No description provided for @groupCallMinParticipants.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionnez au moins un participant'**
  String get groupCallMinParticipants;

  /// No description provided for @groupCallMaxParticipants.
  ///
  /// In fr, this message translates to:
  /// **'Maximum {max} participants'**
  String groupCallMaxParticipants(int max);

  /// No description provided for @groupCallStartVideo.
  ///
  /// In fr, this message translates to:
  /// **'Appel vidéo'**
  String get groupCallStartVideo;

  /// No description provided for @groupCallStartAudio.
  ///
  /// In fr, this message translates to:
  /// **'Appel audio'**
  String get groupCallStartAudio;

  /// No description provided for @groupCallSimulcast.
  ///
  /// In fr, this message translates to:
  /// **'Qualité adaptative activée'**
  String get groupCallSimulcast;

  /// No description provided for @groupCallSwitchingToSfu.
  ///
  /// In fr, this message translates to:
  /// **'Passage en mode serveur pour une meilleure qualité...'**
  String get groupCallSwitchingToSfu;

  /// No description provided for @comingSoon.
  ///
  /// In fr, this message translates to:
  /// **'BIENTÔT DISPONIBLE'**
  String get comingSoon;

  /// No description provided for @goBack.
  ///
  /// In fr, this message translates to:
  /// **'Retour'**
  String get goBack;

  /// No description provided for @comingSoonCallsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Appels Audio & Vidéo'**
  String get comingSoonCallsTitle;

  /// No description provided for @comingSoonCallsDescription.
  ///
  /// In fr, this message translates to:
  /// **'Passez des appels audio et vidéo de haute qualité avec vos amis et votre famille. Cette fonctionnalité est en cours de développement et sera disponible très prochainement.'**
  String get comingSoonCallsDescription;

  /// No description provided for @comingSoonAudioRoomsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Salons Audio'**
  String get comingSoonAudioRoomsTitle;

  /// No description provided for @comingSoonAudioRoomsDescription.
  ///
  /// In fr, this message translates to:
  /// **'Rejoignez des discussions audio en direct avec la communauté. Participez à des débats, des sessions de questions-réponses et bien plus. Cette fonctionnalité arrive bientôt.'**
  String get comingSoonAudioRoomsDescription;

  /// No description provided for @comingSoonInDevelopment.
  ///
  /// In fr, this message translates to:
  /// **'En cours de développement'**
  String get comingSoonInDevelopment;

  /// No description provided for @comingSoonPodcastsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Podcasts'**
  String get comingSoonPodcastsTitle;

  /// No description provided for @comingSoonPodcastsDescription.
  ///
  /// In fr, this message translates to:
  /// **'Écoutez et créez des podcasts sur la diaspora nigérienne. Partagez vos histoires, interviews et discussions. Cette fonctionnalité arrive bientôt.'**
  String get comingSoonPodcastsDescription;

  /// No description provided for @temporarilyClosed.
  ///
  /// In fr, this message translates to:
  /// **'Temporairement fermé'**
  String get temporarilyClosed;

  /// No description provided for @services.
  ///
  /// In fr, this message translates to:
  /// **'Services'**
  String get services;

  /// No description provided for @viewFullDetails.
  ///
  /// In fr, this message translates to:
  /// **'Voir les détails complets'**
  String get viewFullDetails;

  /// No description provided for @showBusinessesOnMap.
  ///
  /// In fr, this message translates to:
  /// **'Afficher les commerces sur la carte'**
  String get showBusinessesOnMap;

  /// No description provided for @hideBusinessesOnMap.
  ///
  /// In fr, this message translates to:
  /// **'Masquer les commerces sur la carte'**
  String get hideBusinessesOnMap;

  /// No description provided for @locationRequiredToSeeMembers.
  ///
  /// In fr, this message translates to:
  /// **'Localisation requise pour voir les membres'**
  String get locationRequiredToSeeMembers;

  /// No description provided for @activate.
  ///
  /// In fr, this message translates to:
  /// **'Activer'**
  String get activate;

  /// No description provided for @reminderTitle.
  ///
  /// In fr, this message translates to:
  /// **'Rappels'**
  String get reminderTitle;

  /// No description provided for @reminderInfoText.
  ///
  /// In fr, this message translates to:
  /// **'Vous recevrez une notification push avant le début de l\'événement selon les rappels configurés.'**
  String get reminderInfoText;

  /// No description provided for @reminderOneHour.
  ///
  /// In fr, this message translates to:
  /// **'1 heure avant'**
  String get reminderOneHour;

  /// No description provided for @reminderTwentyFourHours.
  ///
  /// In fr, this message translates to:
  /// **'24 heures avant'**
  String get reminderTwentyFourHours;

  /// No description provided for @reminderOneWeek.
  ///
  /// In fr, this message translates to:
  /// **'1 semaine avant'**
  String get reminderOneWeek;

  /// No description provided for @reminderSet.
  ///
  /// In fr, this message translates to:
  /// **'Rappel programmé'**
  String get reminderSet;

  /// No description provided for @reminderCancelled.
  ///
  /// In fr, this message translates to:
  /// **'Rappel supprimé'**
  String get reminderCancelled;

  /// No description provided for @reminderPast.
  ///
  /// In fr, this message translates to:
  /// **'Passé'**
  String get reminderPast;

  /// No description provided for @audioRoomReminderTitle.
  ///
  /// In fr, this message translates to:
  /// **'Salle audio à venir'**
  String get audioRoomReminderTitle;

  /// No description provided for @podcastNewEpisodeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Nouvel épisode'**
  String get podcastNewEpisodeTitle;

  /// No description provided for @transferReminderTitle.
  ///
  /// In fr, this message translates to:
  /// **'Transfert à venir'**
  String get transferReminderTitle;

  /// No description provided for @serviceMoneyTransfer.
  ///
  /// In fr, this message translates to:
  /// **'transferts d\'argent'**
  String get serviceMoneyTransfer;

  /// No description provided for @serviceMarketplace.
  ///
  /// In fr, this message translates to:
  /// **'Boutique'**
  String get serviceMarketplace;

  /// No description provided for @serviceBusinessDirectory.
  ///
  /// In fr, this message translates to:
  /// **'annuaire des entreprises'**
  String get serviceBusinessDirectory;

  /// No description provided for @serviceEmbassies.
  ///
  /// In fr, this message translates to:
  /// **'Ambassades'**
  String get serviceEmbassies;

  /// No description provided for @quickAccessToService.
  ///
  /// In fr, this message translates to:
  /// **'Accès rapide au service : {service}.'**
  String quickAccessToService(String service);

  /// No description provided for @quickAccessToServices.
  ///
  /// In fr, this message translates to:
  /// **'Accès rapide aux services : {services} et {lastService}.'**
  String quickAccessToServices(String services, String lastService);

  /// No description provided for @searchableMembers.
  ///
  /// In fr, this message translates to:
  /// **'membres'**
  String get searchableMembers;

  /// No description provided for @searchableGroups.
  ///
  /// In fr, this message translates to:
  /// **'groupes'**
  String get searchableGroups;

  /// No description provided for @searchableEvents.
  ///
  /// In fr, this message translates to:
  /// **'événements'**
  String get searchableEvents;

  /// No description provided for @findEasily.
  ///
  /// In fr, this message translates to:
  /// **'Trouvez des {item} facilement.'**
  String findEasily(String item);

  /// No description provided for @findMultipleEasily.
  ///
  /// In fr, this message translates to:
  /// **'Trouvez des {items} et des {lastItem} facilement.'**
  String findMultipleEasily(String items, String lastItem);

  /// No description provided for @discoverCommunityStats.
  ///
  /// In fr, this message translates to:
  /// **'Découvrez la communauté : nombre de {stats}. Appuyez pour explorer.'**
  String discoverCommunityStats(String stats);

  /// No description provided for @searchProduct.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un produit...'**
  String get searchProduct;

  /// No description provided for @searchEmbassy.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher par nom, pays ou ville...'**
  String get searchEmbassy;

  /// No description provided for @searchEmployee.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher par nom, titre, rôle...'**
  String get searchEmployee;

  /// No description provided for @searchRecipient.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un bénéficiaire...'**
  String get searchRecipient;

  /// No description provided for @searchFriend.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un ami...'**
  String get searchFriend;

  /// No description provided for @searchByRecipient.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher par bénéficiaire...'**
  String get searchByRecipient;

  /// No description provided for @searchBusiness.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher une entreprise...'**
  String get searchBusiness;

  /// No description provided for @download.
  ///
  /// In fr, this message translates to:
  /// **'Télécharger'**
  String get download;

  /// No description provided for @share.
  ///
  /// In fr, this message translates to:
  /// **'Partager'**
  String get share;

  /// No description provided for @galleryPermissionDenied.
  ///
  /// In fr, this message translates to:
  /// **'Permission refusée pour accéder à la galerie'**
  String get galleryPermissionDenied;

  /// No description provided for @imageSavedToGallery.
  ///
  /// In fr, this message translates to:
  /// **'Image enregistrée dans la galerie'**
  String get imageSavedToGallery;

  /// No description provided for @errorDownloading.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors du téléchargement'**
  String get errorDownloading;

  /// No description provided for @errorSharing.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors du partage'**
  String get errorSharing;

  /// No description provided for @imageNotAvailable.
  ///
  /// In fr, this message translates to:
  /// **'Image non disponible'**
  String get imageNotAvailable;

  /// No description provided for @imageCounter.
  ///
  /// In fr, this message translates to:
  /// **'{current} sur {total}'**
  String imageCounter(int current, int total);

  /// No description provided for @todayAt.
  ///
  /// In fr, this message translates to:
  /// **'Aujourd\'hui à {time}'**
  String todayAt(String time);

  /// No description provided for @yesterdayAt.
  ///
  /// In fr, this message translates to:
  /// **'Hier à {time}'**
  String yesterdayAt(String time);

  /// No description provided for @deletePhoto.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer la photo'**
  String get deletePhoto;

  /// No description provided for @confirmDeletePhoto.
  ///
  /// In fr, this message translates to:
  /// **'Voulez-vous vraiment supprimer la photo ?'**
  String get confirmDeletePhoto;

  /// No description provided for @confirmDeleteGroup.
  ///
  /// In fr, this message translates to:
  /// **'Voulez-vous vraiment supprimer ce groupe ? Cette action est irréversible.'**
  String get confirmDeleteGroup;

  /// No description provided for @deleteGroup.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le groupe'**
  String get deleteGroup;

  /// No description provided for @groupDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Groupe supprimé'**
  String get groupDeleted;

  /// No description provided for @deletionError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la suppression'**
  String get deletionError;

  /// No description provided for @editGroup.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le groupe'**
  String get editGroup;

  /// No description provided for @promoteAdmin.
  ///
  /// In fr, this message translates to:
  /// **'Promouvoir Admin'**
  String get promoteAdmin;

  /// No description provided for @demoteAdmin.
  ///
  /// In fr, this message translates to:
  /// **'Rétrograder administrateur'**
  String get demoteAdmin;

  /// No description provided for @joinRequests.
  ///
  /// In fr, this message translates to:
  /// **'Demandes d\'adhésion'**
  String get joinRequests;

  /// No description provided for @requestApproved.
  ///
  /// In fr, this message translates to:
  /// **'Demande approuvée'**
  String get requestApproved;

  /// No description provided for @requestRejected.
  ///
  /// In fr, this message translates to:
  /// **'Demande rejetée'**
  String get requestRejected;

  /// No description provided for @accessDenied.
  ///
  /// In fr, this message translates to:
  /// **'Accès Refusé'**
  String get accessDenied;

  /// No description provided for @errorWithDetails.
  ///
  /// In fr, this message translates to:
  /// **'Erreur : {error}'**
  String errorWithDetails(String error);

  /// No description provided for @deleteConversationWarning.
  ///
  /// In fr, this message translates to:
  /// **'Attention : L\'autre personne pourra toujours vous envoyer des messages. La conversation reapparaitra si vous recevez un nouveau message.'**
  String get deleteConversationWarning;

  /// No description provided for @deleteAndBlock.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer et bloquer'**
  String get deleteAndBlock;

  /// No description provided for @messageWillBeDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Le message sera supprimé'**
  String get messageWillBeDeleted;

  /// No description provided for @undo.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get undo;

  /// No description provided for @confirmDeleteMultipleMessages.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer {count} messages ?'**
  String confirmDeleteMultipleMessages(int count);

  /// No description provided for @deleteMessages.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer les messages'**
  String get deleteMessages;

  /// No description provided for @hostCountry.
  ///
  /// In fr, this message translates to:
  /// **'Pays d\'accueil (optionnel)'**
  String get hostCountry;

  /// No description provided for @creatorMustTransferOwnership.
  ///
  /// In fr, this message translates to:
  /// **'Le créateur doit transférer la propriété avant de quitter'**
  String get creatorMustTransferOwnership;

  /// No description provided for @transfers.
  ///
  /// In fr, this message translates to:
  /// **'Transferts'**
  String get transfers;

  /// No description provided for @reset.
  ///
  /// In fr, this message translates to:
  /// **'Réinitialiser'**
  String get reset;

  /// No description provided for @back.
  ///
  /// In fr, this message translates to:
  /// **'Retour'**
  String get back;

  /// No description provided for @skip.
  ///
  /// In fr, this message translates to:
  /// **'Passer'**
  String get skip;

  /// No description provided for @coachMarkProfile.
  ///
  /// In fr, this message translates to:
  /// **'Votre profil'**
  String get coachMarkProfile;

  /// No description provided for @coachMarkProfileDesc.
  ///
  /// In fr, this message translates to:
  /// **'Appuyez ici pour accéder à votre profil et le compléter avec vos informations.'**
  String get coachMarkProfileDesc;

  /// No description provided for @coachMarkNotifications.
  ///
  /// In fr, this message translates to:
  /// **'Notifications'**
  String get coachMarkNotifications;

  /// No description provided for @coachMarkNotificationsDesc.
  ///
  /// In fr, this message translates to:
  /// **'Restez informé des nouveaux messages et activités de la communauté.'**
  String get coachMarkNotificationsDesc;

  /// No description provided for @coachMarkNearbyMembers.
  ///
  /// In fr, this message translates to:
  /// **'Membres proches'**
  String get coachMarkNearbyMembers;

  /// No description provided for @coachMarkNearbyMembersDesc.
  ///
  /// In fr, this message translates to:
  /// **'Découvrez les Nigériens dans votre région. Faites glisser pour voir plus de profils.'**
  String get coachMarkNearbyMembersDesc;

  /// No description provided for @coachMarkUpcomingEvents.
  ///
  /// In fr, this message translates to:
  /// **'Événements à venir'**
  String get coachMarkUpcomingEvents;

  /// No description provided for @coachMarkUpcomingEventsDesc.
  ///
  /// In fr, this message translates to:
  /// **'Participez aux rencontres et activités de la diaspora. Appuyez pour voir les détails.'**
  String get coachMarkUpcomingEventsDesc;

  /// No description provided for @locationRequiredForNearby.
  ///
  /// In fr, this message translates to:
  /// **'Pour voir les membres à proximité, vous devez activer votre localisation. C\'est donnant-donnant !'**
  String get locationRequiredForNearby;

  /// No description provided for @enableLocation.
  ///
  /// In fr, this message translates to:
  /// **'ACTIVER'**
  String get enableLocation;

  /// No description provided for @serviceTransfer.
  ///
  /// In fr, this message translates to:
  /// **'Transfert'**
  String get serviceTransfer;

  /// No description provided for @serviceDirectory.
  ///
  /// In fr, this message translates to:
  /// **'Annuaire'**
  String get serviceDirectory;

  /// No description provided for @serviceAudioRooms.
  ///
  /// In fr, this message translates to:
  /// **'Salons Audio'**
  String get serviceAudioRooms;

  /// No description provided for @servicePodcasts.
  ///
  /// In fr, this message translates to:
  /// **'Podcasts'**
  String get servicePodcasts;

  /// No description provided for @allServices.
  ///
  /// In fr, this message translates to:
  /// **'Tous les services'**
  String get allServices;

  /// No description provided for @friend.
  ///
  /// In fr, this message translates to:
  /// **'Ami'**
  String get friend;

  /// No description provided for @embassies.
  ///
  /// In fr, this message translates to:
  /// **'Ambassades'**
  String get embassies;

  /// No description provided for @mapLegendSemantics.
  ///
  /// In fr, this message translates to:
  /// **'Légende : Vert pour les amis, Orange pour les membres, Bleu pour les ambassades'**
  String get mapLegendSemantics;

  /// No description provided for @saveAsPodcast.
  ///
  /// In fr, this message translates to:
  /// **'Sauver comme Podcast'**
  String get saveAsPodcast;

  /// No description provided for @publishRecording.
  ///
  /// In fr, this message translates to:
  /// **'Publier cet enregistrement'**
  String get publishRecording;

  /// No description provided for @closeRoom.
  ///
  /// In fr, this message translates to:
  /// **'Fermer le salon'**
  String get closeRoom;

  /// No description provided for @closeRoomConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Êtes-vous sûr de vouloir fermer ce salon ?'**
  String get closeRoomConfirm;

  /// No description provided for @moderationMode.
  ///
  /// In fr, this message translates to:
  /// **'Mode modération (invisible)'**
  String get moderationMode;

  /// No description provided for @userNotConnected.
  ///
  /// In fr, this message translates to:
  /// **'Utilisateur non connecté'**
  String get userNotConnected;

  /// No description provided for @paidRoomsNotAllowed.
  ///
  /// In fr, this message translates to:
  /// **'Les salons payants ne sont pas autorisés'**
  String get paidRoomsNotAllowed;

  /// No description provided for @paidRoomsDisabled.
  ///
  /// In fr, this message translates to:
  /// **'Les salons payants sont désactivés'**
  String get paidRoomsDisabled;

  /// No description provided for @cardSecurityInfo.
  ///
  /// In fr, this message translates to:
  /// **'Vos données de carte sont sécurisées par Stripe. Nous ne stockons jamais votre numéro de carte complet.'**
  String get cardSecurityInfo;

  /// No description provided for @cardTransferInfo.
  ///
  /// In fr, this message translates to:
  /// **'Le transfert sera effectué directement sur la carte via Visa Direct ou Mastercard Send.'**
  String get cardTransferInfo;

  /// No description provided for @registeredCard.
  ///
  /// In fr, this message translates to:
  /// **'Carte enregistrée'**
  String get registeredCard;

  /// No description provided for @changeCard.
  ///
  /// In fr, this message translates to:
  /// **'Changer'**
  String get changeCard;

  /// No description provided for @cardInfoRequired.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez entrer les informations complètes de la carte'**
  String get cardInfoRequired;

  /// No description provided for @cardVerificationError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur de vérification de la carte : {error}'**
  String cardVerificationError(String error);

  /// No description provided for @closeRoomWarning.
  ///
  /// In fr, this message translates to:
  /// **'Cette action fermera le salon pour tous les participants.'**
  String get closeRoomWarning;

  /// No description provided for @closeReasonHint.
  ///
  /// In fr, this message translates to:
  /// **'Raison de la fermeture...'**
  String get closeReasonHint;

  /// No description provided for @defaultCloseReason.
  ///
  /// In fr, this message translates to:
  /// **'Violation des règles de la communauté'**
  String get defaultCloseReason;

  /// No description provided for @collectionsNotAllowed.
  ///
  /// In fr, this message translates to:
  /// **'Les collectes ne sont pas autorisées'**
  String get collectionsNotAllowed;

  /// No description provided for @heritageContentNotAllowed.
  ///
  /// In fr, this message translates to:
  /// **'Le contenu patrimonial n\'est pas autorisé'**
  String get heritageContentNotAllowed;

  /// No description provided for @minTicketPrice.
  ///
  /// In fr, this message translates to:
  /// **'Le prix minimum du ticket est {price} XOF'**
  String minTicketPrice(int price);

  /// No description provided for @maxTicketPrice.
  ///
  /// In fr, this message translates to:
  /// **'Le prix maximum du ticket est {price} XOF'**
  String maxTicketPrice(int price);

  /// No description provided for @defaultUserName.
  ///
  /// In fr, this message translates to:
  /// **'Utilisateur'**
  String get defaultUserName;

  /// No description provided for @errorCreating.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la création: {error}'**
  String errorCreating(String error);

  /// No description provided for @roomNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Salon introuvable'**
  String get roomNotFound;

  /// No description provided for @blockedFromRoom.
  ///
  /// In fr, this message translates to:
  /// **'Vous êtes bloqué de ce salon'**
  String get blockedFromRoom;

  /// No description provided for @roomFull.
  ///
  /// In fr, this message translates to:
  /// **'Salon complet'**
  String get roomFull;

  /// No description provided for @errorConnecting.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la connexion: {error}'**
  String errorConnecting(String error);

  /// No description provided for @unauthorizedAccess.
  ///
  /// In fr, this message translates to:
  /// **'Accès non autorisé'**
  String get unauthorizedAccess;

  /// No description provided for @tomorrowAt.
  ///
  /// In fr, this message translates to:
  /// **'Demain à {time}'**
  String tomorrowAt(String time);

  /// No description provided for @forBeneficiary.
  ///
  /// In fr, this message translates to:
  /// **'Pour: {beneficiary}'**
  String forBeneficiary(String beneficiary);

  /// No description provided for @goalAmount.
  ///
  /// In fr, this message translates to:
  /// **'Objectif: {amount}'**
  String goalAmount(String amount);

  /// No description provided for @contribute.
  ///
  /// In fr, this message translates to:
  /// **'Contribuer'**
  String get contribute;

  /// No description provided for @suggestedAmount.
  ///
  /// In fr, this message translates to:
  /// **'Montant suggéré'**
  String get suggestedAmount;

  /// No description provided for @orEnterAmount.
  ///
  /// In fr, this message translates to:
  /// **'Ou saisissez un montant'**
  String get orEnterAmount;

  /// No description provided for @amountInXof.
  ///
  /// In fr, this message translates to:
  /// **'Montant en XOF'**
  String get amountInXof;

  /// No description provided for @messageOptional.
  ///
  /// In fr, this message translates to:
  /// **'Message (optionnel)'**
  String get messageOptional;

  /// No description provided for @confirmContribution.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer la contribution'**
  String get confirmContribution;

  /// No description provided for @collectionLabel.
  ///
  /// In fr, this message translates to:
  /// **'Collecte'**
  String get collectionLabel;

  /// No description provided for @emergencyLabel.
  ///
  /// In fr, this message translates to:
  /// **'Urgence'**
  String get emergencyLabel;

  /// No description provided for @projectLabel.
  ///
  /// In fr, this message translates to:
  /// **'Projet'**
  String get projectLabel;

  /// No description provided for @duesLabel.
  ///
  /// In fr, this message translates to:
  /// **'Cotisation'**
  String get duesLabel;

  /// No description provided for @moderatorRole.
  ///
  /// In fr, this message translates to:
  /// **'Modérateur'**
  String get moderatorRole;

  /// No description provided for @warnHost.
  ///
  /// In fr, this message translates to:
  /// **'Avertir l\'hôte'**
  String get warnHost;

  /// No description provided for @warningSentToHost.
  ///
  /// In fr, this message translates to:
  /// **'Avertissement envoyé à l\'hôte'**
  String get warningSentToHost;

  /// No description provided for @muteMicrophone.
  ///
  /// In fr, this message translates to:
  /// **'Couper le micro'**
  String get muteMicrophone;

  /// No description provided for @userMuted.
  ///
  /// In fr, this message translates to:
  /// **'{userName} a été mis en sourdine'**
  String userMuted(String userName);

  /// No description provided for @kickFromRoom.
  ///
  /// In fr, this message translates to:
  /// **'Expulser du salon'**
  String get kickFromRoom;

  /// No description provided for @userKicked.
  ///
  /// In fr, this message translates to:
  /// **'{userName} a été expulsé'**
  String userKicked(String userName);

  /// No description provided for @blockFromRoom.
  ///
  /// In fr, this message translates to:
  /// **'Bloquer de ce salon'**
  String get blockFromRoom;

  /// No description provided for @userBlockedFromRoom.
  ///
  /// In fr, this message translates to:
  /// **'{userName} a été bloqué'**
  String userBlockedFromRoom(String userName);

  /// No description provided for @videoEnabled.
  ///
  /// In fr, this message translates to:
  /// **'Vidéo activée'**
  String get videoEnabled;

  /// No description provided for @videoEnabledDesc.
  ///
  /// In fr, this message translates to:
  /// **'Permettre aux speakers de partager leur vidéo'**
  String get videoEnabledDesc;

  /// No description provided for @remove.
  ///
  /// In fr, this message translates to:
  /// **'Retirer'**
  String get remove;

  /// No description provided for @errorLabel.
  ///
  /// In fr, this message translates to:
  /// **'Erreur: {error}'**
  String errorLabel(String error);

  /// No description provided for @noEventFound.
  ///
  /// In fr, this message translates to:
  /// **'Aucun événement trouvé'**
  String get noEventFound;

  /// No description provided for @noGroupFound.
  ///
  /// In fr, this message translates to:
  /// **'Aucun groupe trouvé'**
  String get noGroupFound;

  /// No description provided for @noEmbassyFound.
  ///
  /// In fr, this message translates to:
  /// **'Aucune ambassade trouvée'**
  String get noEmbassyFound;

  /// No description provided for @warningMessageHint.
  ///
  /// In fr, this message translates to:
  /// **'Message d\'avertissement...'**
  String get warningMessageHint;

  /// No description provided for @searchEventHint.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un événement...'**
  String get searchEventHint;

  /// No description provided for @searchGroupHint.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un groupe...'**
  String get searchGroupHint;

  /// No description provided for @searchEmbassyHint.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher une ambassade...'**
  String get searchEmbassyHint;

  /// No description provided for @pleaseAddCoverImage.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez ajouter une image de couverture'**
  String get pleaseAddCoverImage;

  /// No description provided for @podcastCreatedSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Podcast créé avec succès!'**
  String get podcastCreatedSuccess;

  /// No description provided for @createPodcast.
  ///
  /// In fr, this message translates to:
  /// **'Créer un podcast'**
  String get createPodcast;

  /// No description provided for @languageFrench.
  ///
  /// In fr, this message translates to:
  /// **'Français'**
  String get languageFrench;

  /// No description provided for @languageEnglish.
  ///
  /// In fr, this message translates to:
  /// **'Anglais'**
  String get languageEnglish;

  /// No description provided for @languageHausa.
  ///
  /// In fr, this message translates to:
  /// **'Haoussa'**
  String get languageHausa;

  /// No description provided for @languageZarma.
  ///
  /// In fr, this message translates to:
  /// **'Zarma/Djerma'**
  String get languageZarma;

  /// No description provided for @frequencyNotDefined.
  ///
  /// In fr, this message translates to:
  /// **'Non définie'**
  String get frequencyNotDefined;

  /// No description provided for @frequencyDaily.
  ///
  /// In fr, this message translates to:
  /// **'Quotidien'**
  String get frequencyDaily;

  /// No description provided for @frequencyWeekly.
  ///
  /// In fr, this message translates to:
  /// **'Hebdomadaire'**
  String get frequencyWeekly;

  /// No description provided for @frequencyBiweekly.
  ///
  /// In fr, this message translates to:
  /// **'Bimensuel'**
  String get frequencyBiweekly;

  /// No description provided for @frequencyMonthly.
  ///
  /// In fr, this message translates to:
  /// **'Mensuel'**
  String get frequencyMonthly;

  /// No description provided for @explicitContent.
  ///
  /// In fr, this message translates to:
  /// **'Contenu explicite'**
  String get explicitContent;

  /// No description provided for @explicitContentDesc.
  ///
  /// In fr, this message translates to:
  /// **'Ce podcast contient du contenu pour adultes'**
  String get explicitContentDesc;

  /// No description provided for @createThePodcast.
  ///
  /// In fr, this message translates to:
  /// **'Créer le podcast'**
  String get createThePodcast;

  /// No description provided for @episodeNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Épisode non trouvé'**
  String get episodeNotFound;

  /// No description provided for @downloadInProgress.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargement en cours...'**
  String get downloadInProgress;

  /// No description provided for @sleepTimerDisabled.
  ///
  /// In fr, this message translates to:
  /// **'Désactivé'**
  String get sleepTimerDisabled;

  /// No description provided for @sleepTimer15min.
  ///
  /// In fr, this message translates to:
  /// **'15 minutes'**
  String get sleepTimer15min;

  /// No description provided for @sleepTimer30min.
  ///
  /// In fr, this message translates to:
  /// **'30 minutes'**
  String get sleepTimer30min;

  /// No description provided for @sleepTimer45min.
  ///
  /// In fr, this message translates to:
  /// **'45 minutes'**
  String get sleepTimer45min;

  /// No description provided for @sleepTimer1hour.
  ///
  /// In fr, this message translates to:
  /// **'1 heure'**
  String get sleepTimer1hour;

  /// No description provided for @sleepTimerEndOfEpisode.
  ///
  /// In fr, this message translates to:
  /// **'Fin de l\'épisode'**
  String get sleepTimerEndOfEpisode;

  /// No description provided for @sleepTimerEndActivated.
  ///
  /// In fr, this message translates to:
  /// **'Arrêt à la fin de l\'épisode activé'**
  String get sleepTimerEndActivated;

  /// No description provided for @sleepTimerFinished.
  ///
  /// In fr, this message translates to:
  /// **'Minuterie de sommeil terminée'**
  String get sleepTimerFinished;

  /// No description provided for @sleepTimerMinutes.
  ///
  /// In fr, this message translates to:
  /// **'Minuterie: {minutes} minutes'**
  String sleepTimerMinutes(int minutes);

  /// No description provided for @myPodcasts.
  ///
  /// In fr, this message translates to:
  /// **'Mes Podcasts'**
  String get myPodcasts;

  /// No description provided for @newPodcast.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau podcast'**
  String get newPodcast;

  /// No description provided for @createMyFirstPodcast.
  ///
  /// In fr, this message translates to:
  /// **'Créer mon premier podcast'**
  String get createMyFirstPodcast;

  /// No description provided for @viewAllEpisodes.
  ///
  /// In fr, this message translates to:
  /// **'Voir les {count} épisodes'**
  String viewAllEpisodes(int count);

  /// No description provided for @newEpisode.
  ///
  /// In fr, this message translates to:
  /// **'Nouvel épisode'**
  String get newEpisode;

  /// No description provided for @noPodcastsYet.
  ///
  /// In fr, this message translates to:
  /// **'Vous n\'avez pas encore de podcast'**
  String get noPodcastsYet;

  /// No description provided for @noPodcastsDescription.
  ///
  /// In fr, this message translates to:
  /// **'Créez votre premier podcast et partagez votre voix avec la communauté diaspora !'**
  String get noPodcastsDescription;

  /// No description provided for @noEpisodesPublished.
  ///
  /// In fr, this message translates to:
  /// **'Aucun épisode publié'**
  String get noEpisodesPublished;

  /// No description provided for @episodeListenInfo.
  ///
  /// In fr, this message translates to:
  /// **'{duration} • {count} écoutes'**
  String episodeListenInfo(String duration, int count);

  /// No description provided for @viewPodcast.
  ///
  /// In fr, this message translates to:
  /// **'Voir le podcast'**
  String get viewPodcast;

  /// No description provided for @statistics.
  ///
  /// In fr, this message translates to:
  /// **'Statistiques'**
  String get statistics;

  /// No description provided for @pausePodcast.
  ///
  /// In fr, this message translates to:
  /// **'Mettre en pause'**
  String get pausePodcast;

  /// No description provided for @publishPodcast.
  ///
  /// In fr, this message translates to:
  /// **'Publier'**
  String get publishPodcast;

  /// No description provided for @podcastPaused.
  ///
  /// In fr, this message translates to:
  /// **'Podcast mis en pause'**
  String get podcastPaused;

  /// No description provided for @podcastPublished.
  ///
  /// In fr, this message translates to:
  /// **'Podcast publié'**
  String get podcastPublished;

  /// No description provided for @deletePodcastTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le podcast ?'**
  String get deletePodcastTitle;

  /// No description provided for @deletePodcastWarning.
  ///
  /// In fr, this message translates to:
  /// **'Êtes-vous sûr de vouloir supprimer \"{title}\" et tous ses épisodes ? Cette action est irréversible.'**
  String deletePodcastWarning(String title);

  /// No description provided for @podcastDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Podcast supprimé'**
  String get podcastDeleted;

  /// No description provided for @episodeDownloaded.
  ///
  /// In fr, this message translates to:
  /// **'Épisode téléchargé'**
  String get episodeDownloaded;

  /// No description provided for @deleteDownload.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le téléchargement'**
  String get deleteDownload;

  /// No description provided for @downloadDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargement supprimé'**
  String get downloadDeleted;

  /// No description provided for @selectPodcastOrCreate.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionnez un podcast ou créez-en un nouveau'**
  String get selectPodcastOrCreate;

  /// No description provided for @recordingSoonAvailable.
  ///
  /// In fr, this message translates to:
  /// **'L\'enregistrement du salon sera bientôt disponible'**
  String get recordingSoonAvailable;

  /// No description provided for @audioFileNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Fichier audio introuvable'**
  String get audioFileNotFound;

  /// No description provided for @episodePublishedSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Épisode publié avec succès !'**
  String get episodePublishedSuccess;

  /// No description provided for @publicationError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la publication'**
  String get publicationError;

  /// No description provided for @publish.
  ///
  /// In fr, this message translates to:
  /// **'Publier'**
  String get publish;

  /// No description provided for @createAPodcast.
  ///
  /// In fr, this message translates to:
  /// **'Créer un podcast'**
  String get createAPodcast;

  /// No description provided for @podcasts.
  ///
  /// In fr, this message translates to:
  /// **'Podcasts'**
  String get podcasts;

  /// No description provided for @noPodcastAvailable.
  ///
  /// In fr, this message translates to:
  /// **'Aucun podcast disponible'**
  String get noPodcastAvailable;

  /// No description provided for @noRecentEpisode.
  ///
  /// In fr, this message translates to:
  /// **'Aucun épisode récent'**
  String get noRecentEpisode;

  /// No description provided for @endOfEpisode.
  ///
  /// In fr, this message translates to:
  /// **'Fin de l\'épisode'**
  String get endOfEpisode;

  /// No description provided for @addChapter.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un chapitre'**
  String get addChapter;

  /// No description provided for @add.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter'**
  String get add;

  /// No description provided for @pleaseSelectAudioFile.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez sélectionner un fichier audio'**
  String get pleaseSelectAudioFile;

  /// No description provided for @premiumEpisode.
  ///
  /// In fr, this message translates to:
  /// **'Épisode premium'**
  String get premiumEpisode;

  /// No description provided for @subscribersOnly.
  ///
  /// In fr, this message translates to:
  /// **'Réservé aux abonnés payants'**
  String get subscribersOnly;

  /// No description provided for @podcastNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Podcast non trouvé'**
  String get podcastNotFound;

  /// No description provided for @trending.
  ///
  /// In fr, this message translates to:
  /// **'Tendances'**
  String get trending;

  /// No description provided for @newEpisodes.
  ///
  /// In fr, this message translates to:
  /// **'Nouveaux épisodes'**
  String get newEpisodes;

  /// No description provided for @resumeListening.
  ///
  /// In fr, this message translates to:
  /// **'Reprendre'**
  String get resumeListening;

  /// No description provided for @categories.
  ///
  /// In fr, this message translates to:
  /// **'Catégories'**
  String get categories;

  /// No description provided for @subscriptions.
  ///
  /// In fr, this message translates to:
  /// **'Abonnements'**
  String get subscriptions;

  /// No description provided for @noResultsFound.
  ///
  /// In fr, this message translates to:
  /// **'Aucun résultat trouvé'**
  String get noResultsFound;

  /// No description provided for @noSubscription.
  ///
  /// In fr, this message translates to:
  /// **'Aucun abonnement'**
  String get noSubscription;

  /// No description provided for @subscribeToFindHere.
  ///
  /// In fr, this message translates to:
  /// **'Abonnez-vous à des podcasts pour les retrouver ici'**
  String get subscribeToFindHere;

  /// No description provided for @chapterTitle.
  ///
  /// In fr, this message translates to:
  /// **'Titre du chapitre'**
  String get chapterTitle;

  /// No description provided for @marketplace.
  ///
  /// In fr, this message translates to:
  /// **'Marketplace'**
  String get marketplace;

  /// No description provided for @sell.
  ///
  /// In fr, this message translates to:
  /// **'Vendre'**
  String get sell;

  /// No description provided for @allCountries.
  ///
  /// In fr, this message translates to:
  /// **'Tous les pays'**
  String get allCountries;

  /// No description provided for @myProducts.
  ///
  /// In fr, this message translates to:
  /// **'Mes produits'**
  String get myProducts;

  /// No description provided for @listForSale.
  ///
  /// In fr, this message translates to:
  /// **'Mettre en vente'**
  String get listForSale;

  /// No description provided for @addAtLeastOneImage.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez au moins une image'**
  String get addAtLeastOneImage;

  /// No description provided for @priceTTC.
  ///
  /// In fr, this message translates to:
  /// **'Prix TTC'**
  String get priceTTC;

  /// No description provided for @subtotal.
  ///
  /// In fr, this message translates to:
  /// **'Sous-total'**
  String get subtotal;

  /// No description provided for @taxRate.
  ///
  /// In fr, this message translates to:
  /// **'Taxe ({rate}%)'**
  String taxRate(String rate);

  /// No description provided for @myOrders.
  ///
  /// In fr, this message translates to:
  /// **'Mes commandes'**
  String get myOrders;

  /// No description provided for @discoverProducts.
  ///
  /// In fr, this message translates to:
  /// **'Découvrir les produits'**
  String get discoverProducts;

  /// No description provided for @paymentSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Paiement effectué avec succès !'**
  String get paymentSuccess;

  /// No description provided for @orderUpdateError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la mise à jour de la commande'**
  String get orderUpdateError;

  /// No description provided for @paymentError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur de paiement : {error}'**
  String paymentError(String error);

  /// No description provided for @deliveryConfirmed.
  ///
  /// In fr, this message translates to:
  /// **'Livraison confirmée'**
  String get deliveryConfirmed;

  /// No description provided for @orderMarkedAsShipped.
  ///
  /// In fr, this message translates to:
  /// **'Commande marquée comme expédiée'**
  String get orderMarkedAsShipped;

  /// No description provided for @trackingNumber.
  ///
  /// In fr, this message translates to:
  /// **'Numéro de suivi'**
  String get trackingNumber;

  /// No description provided for @cart.
  ///
  /// In fr, this message translates to:
  /// **'Panier'**
  String get cart;

  /// No description provided for @cartWithCount.
  ///
  /// In fr, this message translates to:
  /// **'Panier ({count})'**
  String cartWithCount(int count);

  /// No description provided for @emptyCart.
  ///
  /// In fr, this message translates to:
  /// **'Vider'**
  String get emptyCart;

  /// No description provided for @total.
  ///
  /// In fr, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @ordersCreatedSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Commande(s) créée(s) avec succès !'**
  String get ordersCreatedSuccess;

  /// No description provided for @loadingText.
  ///
  /// In fr, this message translates to:
  /// **'Chargement...'**
  String get loadingText;

  /// No description provided for @deleteProduct.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le produit'**
  String get deleteProduct;

  /// No description provided for @addedToCart.
  ///
  /// In fr, this message translates to:
  /// **'Ajouté au panier'**
  String get addedToCart;

  /// No description provided for @addToCart.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter au panier'**
  String get addToCart;

  /// No description provided for @conversationCreationError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la création de la conversation'**
  String get conversationCreationError;

  /// No description provided for @noProductsYet.
  ///
  /// In fr, this message translates to:
  /// **'Vous n\'avez pas encore de produits'**
  String get noProductsYet;

  /// No description provided for @emptyCartMessage.
  ///
  /// In fr, this message translates to:
  /// **'Votre panier est vide'**
  String get emptyCartMessage;

  /// No description provided for @businessDirectory.
  ///
  /// In fr, this message translates to:
  /// **'Annuaire Business'**
  String get businessDirectory;

  /// No description provided for @boostYourBusiness.
  ///
  /// In fr, this message translates to:
  /// **'Booster votre entreprise'**
  String get boostYourBusiness;

  /// No description provided for @boostActivatedSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Boost activé avec succès !'**
  String get boostActivatedSuccess;

  /// No description provided for @boostPurchaseError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de l\'achat du boost'**
  String get boostPurchaseError;

  /// No description provided for @newBusiness.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle entreprise'**
  String get newBusiness;

  /// No description provided for @photos.
  ///
  /// In fr, this message translates to:
  /// **'Photos'**
  String get photos;

  /// No description provided for @contact.
  ///
  /// In fr, this message translates to:
  /// **'Contact'**
  String get contact;

  /// No description provided for @servicesOffered.
  ///
  /// In fr, this message translates to:
  /// **'Services proposés'**
  String get servicesOffered;

  /// No description provided for @createTheBusiness.
  ///
  /// In fr, this message translates to:
  /// **'Créer l\'entreprise'**
  String get createTheBusiness;

  /// No description provided for @businessCreatedSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Entreprise créée avec succès!'**
  String get businessCreatedSuccess;

  /// No description provided for @creationError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la création'**
  String get creationError;

  /// No description provided for @boost.
  ///
  /// In fr, this message translates to:
  /// **'Booster'**
  String get boost;

  /// No description provided for @writeReview.
  ///
  /// In fr, this message translates to:
  /// **'Écrire un avis'**
  String get writeReview;

  /// No description provided for @writeFirstReview.
  ///
  /// In fr, this message translates to:
  /// **'Écrire le premier avis'**
  String get writeFirstReview;

  /// No description provided for @viewAllReviews.
  ///
  /// In fr, this message translates to:
  /// **'Voir les {count} autres avis'**
  String viewAllReviews(int count);

  /// No description provided for @mustBeLoggedInToReview.
  ///
  /// In fr, this message translates to:
  /// **'Vous devez être connecté pour laisser un avis'**
  String get mustBeLoggedInToReview;

  /// No description provided for @pleaseGiveRating.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez donner une note'**
  String get pleaseGiveRating;

  /// No description provided for @pleaseWriteReview.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez écrire un avis'**
  String get pleaseWriteReview;

  /// No description provided for @submissionError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la soumission'**
  String get submissionError;

  /// No description provided for @deleteReview.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer l\'avis'**
  String get deleteReview;

  /// No description provided for @deleteReviewConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Voulez-vous vraiment supprimer cet avis ? Cette action est irréversible.'**
  String get deleteReviewConfirm;

  /// No description provided for @reviewDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Avis supprimé'**
  String get reviewDeleted;

  /// No description provided for @reportReview.
  ///
  /// In fr, this message translates to:
  /// **'Signaler cet avis'**
  String get reportReview;

  /// No description provided for @pleaseIndicateReason.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez indiquer une raison'**
  String get pleaseIndicateReason;

  /// No description provided for @useMyLocation.
  ///
  /// In fr, this message translates to:
  /// **'Utiliser ma localisation'**
  String get useMyLocation;

  /// No description provided for @enterCity.
  ///
  /// In fr, this message translates to:
  /// **'Entrer la ville'**
  String get enterCity;

  /// No description provided for @apply.
  ///
  /// In fr, this message translates to:
  /// **'Appliquer'**
  String get apply;

  /// No description provided for @newPost.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle publication'**
  String get newPost;

  /// No description provided for @type.
  ///
  /// In fr, this message translates to:
  /// **'Type :'**
  String get type;

  /// No description provided for @duration.
  ///
  /// In fr, this message translates to:
  /// **'Durée :'**
  String get duration;

  /// No description provided for @embassiesAndConsulates.
  ///
  /// In fr, this message translates to:
  /// **'Ambassades & Consulats'**
  String get embassiesAndConsulates;

  /// No description provided for @contactEmbassy.
  ///
  /// In fr, this message translates to:
  /// **'Contacter l\'ambassade'**
  String get contactEmbassy;

  /// No description provided for @messageSentSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Message envoyé avec succès !'**
  String get messageSentSuccess;

  /// No description provided for @newRequest.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle demande'**
  String get newRequest;

  /// No description provided for @requestSubmittedSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Demande soumise avec succès !'**
  String get requestSubmittedSuccess;

  /// No description provided for @callAction.
  ///
  /// In fr, this message translates to:
  /// **'Appeler'**
  String get callAction;

  /// No description provided for @groupModified.
  ///
  /// In fr, this message translates to:
  /// **'Groupe modifié avec succès'**
  String get groupModified;

  /// No description provided for @modificationError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la modification'**
  String get modificationError;

  /// No description provided for @nameRequired.
  ///
  /// In fr, this message translates to:
  /// **'Le nom est requis'**
  String get nameRequired;

  /// No description provided for @nameMinLength.
  ///
  /// In fr, this message translates to:
  /// **'Le nom doit contenir au moins 3 caractères'**
  String get nameMinLength;

  /// No description provided for @privateGroup.
  ///
  /// In fr, this message translates to:
  /// **'Groupe privé'**
  String get privateGroup;

  /// No description provided for @groupCreated.
  ///
  /// In fr, this message translates to:
  /// **'Groupe créé avec succès'**
  String get groupCreated;

  /// No description provided for @groupCreationError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la création du groupe'**
  String get groupCreationError;

  /// No description provided for @promotionError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la promotion'**
  String get promotionError;

  /// No description provided for @demotionError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la rétrogradation'**
  String get demotionError;

  /// No description provided for @requestSent.
  ///
  /// In fr, this message translates to:
  /// **'Demande envoyée avec succès'**
  String get requestSent;

  /// No description provided for @groupCountryHint.
  ///
  /// In fr, this message translates to:
  /// **'Le pays où se trouve la communauté du groupe'**
  String get groupCountryHint;

  /// No description provided for @memberRemoved.
  ///
  /// In fr, this message translates to:
  /// **'Membre retiré avec succès'**
  String get memberRemoved;

  /// No description provided for @memberRemovalError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la suppression du membre'**
  String get memberRemovalError;

  /// No description provided for @filterGroups.
  ///
  /// In fr, this message translates to:
  /// **'Groupes'**
  String get filterGroups;

  /// No description provided for @muted.
  ///
  /// In fr, this message translates to:
  /// **'En sourdine'**
  String get muted;

  /// No description provided for @pin.
  ///
  /// In fr, this message translates to:
  /// **'Épingler'**
  String get pin;

  /// No description provided for @unpin.
  ///
  /// In fr, this message translates to:
  /// **'Désépingler'**
  String get unpin;

  /// No description provided for @pinLimitReached.
  ///
  /// In fr, this message translates to:
  /// **'Vous ne pouvez pas épingler plus de 5 conversations'**
  String get pinLimitReached;

  /// No description provided for @conversationPinned.
  ///
  /// In fr, this message translates to:
  /// **'Conversation épinglée'**
  String get conversationPinned;

  /// No description provided for @editMessage.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le message'**
  String get editMessage;

  /// No description provided for @edited.
  ///
  /// In fr, this message translates to:
  /// **'modifié'**
  String get edited;

  /// No description provided for @editTimeExpired.
  ///
  /// In fr, this message translates to:
  /// **'Le délai de modification est expiré (25 min)'**
  String get editTimeExpired;

  /// No description provided for @messageEdited.
  ///
  /// In fr, this message translates to:
  /// **'Message modifié'**
  String get messageEdited;

  /// No description provided for @conversationUnpinned.
  ///
  /// In fr, this message translates to:
  /// **'Conversation désépinglée'**
  String get conversationUnpinned;

  /// No description provided for @disappearingMessages.
  ///
  /// In fr, this message translates to:
  /// **'Messages éphémères'**
  String get disappearingMessages;

  /// No description provided for @disappearingMessagesDescription.
  ///
  /// In fr, this message translates to:
  /// **'Les nouveaux messages disparaîtront après le délai sélectionné'**
  String get disappearingMessagesDescription;

  /// No description provided for @off.
  ///
  /// In fr, this message translates to:
  /// **'Désactivé'**
  String get off;

  /// No description provided for @hours24.
  ///
  /// In fr, this message translates to:
  /// **'24 heures'**
  String get hours24;

  /// No description provided for @days7.
  ///
  /// In fr, this message translates to:
  /// **'7 jours'**
  String get days7;

  /// No description provided for @days30.
  ///
  /// In fr, this message translates to:
  /// **'30 jours'**
  String get days30;

  /// No description provided for @expiresIn.
  ///
  /// In fr, this message translates to:
  /// **'Expire dans {time}'**
  String expiresIn(Object time);

  /// No description provided for @disappearingMessagesEnabled.
  ///
  /// In fr, this message translates to:
  /// **'Messages éphémères activés ({duration})'**
  String disappearingMessagesEnabled(Object duration);

  /// No description provided for @disappearingMessagesDisabled.
  ///
  /// In fr, this message translates to:
  /// **'Messages éphémères désactivés'**
  String get disappearingMessagesDisabled;

  /// No description provided for @muteNotifications.
  ///
  /// In fr, this message translates to:
  /// **'Mettre en sourdine'**
  String get muteNotifications;

  /// No description provided for @muteNotificationsDescription.
  ///
  /// In fr, this message translates to:
  /// **'Vous ne recevrez pas de notifications pour cette conversation pendant la durée sélectionnée'**
  String get muteNotificationsDescription;

  /// No description provided for @muteFor1Hour.
  ///
  /// In fr, this message translates to:
  /// **'1 heure'**
  String get muteFor1Hour;

  /// No description provided for @muteFor8Hours.
  ///
  /// In fr, this message translates to:
  /// **'8 heures'**
  String get muteFor8Hours;

  /// No description provided for @muteFor24Hours.
  ///
  /// In fr, this message translates to:
  /// **'24 heures'**
  String get muteFor24Hours;

  /// No description provided for @muteFor1Week.
  ///
  /// In fr, this message translates to:
  /// **'1 semaine'**
  String get muteFor1Week;

  /// No description provided for @muteForever.
  ///
  /// In fr, this message translates to:
  /// **'Toujours'**
  String get muteForever;

  /// No description provided for @conversationMuted.
  ///
  /// In fr, this message translates to:
  /// **'Conversation mise en sourdine'**
  String get conversationMuted;

  /// No description provided for @mutedUntil.
  ///
  /// In fr, this message translates to:
  /// **'En sourdine jusqu\'à {time}'**
  String mutedUntil(Object time);

  /// No description provided for @emptyStateNoDataTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aucune donnée'**
  String get emptyStateNoDataTitle;

  /// No description provided for @emptyStateNoDataMessage.
  ///
  /// In fr, this message translates to:
  /// **'Il n\'y a rien à afficher pour le moment.'**
  String get emptyStateNoDataMessage;

  /// No description provided for @emptyStateNoResultsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aucun résultat'**
  String get emptyStateNoResultsTitle;

  /// No description provided for @emptyStateNoResultsMessage.
  ///
  /// In fr, this message translates to:
  /// **'Aucun résultat ne correspond à votre recherche.'**
  String get emptyStateNoResultsMessage;

  /// No description provided for @emptyStateNoResultsAction.
  ///
  /// In fr, this message translates to:
  /// **'Effacer la recherche'**
  String get emptyStateNoResultsAction;

  /// No description provided for @emptyStateNoMessagesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Pas de messages'**
  String get emptyStateNoMessagesTitle;

  /// No description provided for @emptyStateNoMessagesMessage.
  ///
  /// In fr, this message translates to:
  /// **'Vous n\'avez pas encore de conversations. Commencez à discuter avec la communauté !'**
  String get emptyStateNoMessagesMessage;

  /// No description provided for @emptyStateNoMessagesAction.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle conversation'**
  String get emptyStateNoMessagesAction;

  /// No description provided for @emptyStateNoNotificationsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Pas de notifications'**
  String get emptyStateNoNotificationsTitle;

  /// No description provided for @emptyStateNoNotificationsMessage.
  ///
  /// In fr, this message translates to:
  /// **'Vous êtes à jour ! Aucune nouvelle notification.'**
  String get emptyStateNoNotificationsMessage;

  /// No description provided for @emptyStateNoEventsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aucun événement'**
  String get emptyStateNoEventsTitle;

  /// No description provided for @emptyStateNoEventsMessage.
  ///
  /// In fr, this message translates to:
  /// **'Il n\'y a pas d\'événements à venir pour le moment.'**
  String get emptyStateNoEventsMessage;

  /// No description provided for @emptyStateNoEventsAction.
  ///
  /// In fr, this message translates to:
  /// **'Créer un événement'**
  String get emptyStateNoEventsAction;

  /// No description provided for @emptyStateNoGroupsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aucun groupe'**
  String get emptyStateNoGroupsTitle;

  /// No description provided for @emptyStateNoGroupsMessage.
  ///
  /// In fr, this message translates to:
  /// **'Vous n\'êtes membre d\'aucun groupe. Rejoignez ou créez un groupe !'**
  String get emptyStateNoGroupsMessage;

  /// No description provided for @emptyStateNoGroupsAction.
  ///
  /// In fr, this message translates to:
  /// **'Explorer les groupes'**
  String get emptyStateNoGroupsAction;

  /// No description provided for @emptyStateNoFriendsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Pas encore d\'amis'**
  String get emptyStateNoFriendsTitle;

  /// No description provided for @emptyStateNoFriendsMessage.
  ///
  /// In fr, this message translates to:
  /// **'Connectez-vous avec d\'autres membres de la communauté.'**
  String get emptyStateNoFriendsMessage;

  /// No description provided for @emptyStateNoFriendsAction.
  ///
  /// In fr, this message translates to:
  /// **'Trouver des amis'**
  String get emptyStateNoFriendsAction;

  /// No description provided for @emptyStateNoProductsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aucun produit'**
  String get emptyStateNoProductsTitle;

  /// No description provided for @emptyStateNoProductsMessage.
  ///
  /// In fr, this message translates to:
  /// **'Le marketplace est vide pour le moment.'**
  String get emptyStateNoProductsMessage;

  /// No description provided for @emptyStateNoProductsAction.
  ///
  /// In fr, this message translates to:
  /// **'Publier un produit'**
  String get emptyStateNoProductsAction;

  /// No description provided for @emptyStateNoOrdersTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aucune commande'**
  String get emptyStateNoOrdersTitle;

  /// No description provided for @emptyStateNoOrdersMessage.
  ///
  /// In fr, this message translates to:
  /// **'Vous n\'avez pas encore passé de commande.'**
  String get emptyStateNoOrdersMessage;

  /// No description provided for @emptyStateNoOrdersAction.
  ///
  /// In fr, this message translates to:
  /// **'Voir le marketplace'**
  String get emptyStateNoOrdersAction;

  /// No description provided for @emptyStateNoTransactionsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aucune transaction'**
  String get emptyStateNoTransactionsTitle;

  /// No description provided for @emptyStateNoTransactionsMessage.
  ///
  /// In fr, this message translates to:
  /// **'Vous n\'avez pas encore effectué de transfert.'**
  String get emptyStateNoTransactionsMessage;

  /// No description provided for @emptyStateNoTransactionsAction.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer de l\'argent'**
  String get emptyStateNoTransactionsAction;

  /// No description provided for @emptyStateOfflineTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mode hors-ligne'**
  String get emptyStateOfflineTitle;

  /// No description provided for @emptyStateOfflineMessage.
  ///
  /// In fr, this message translates to:
  /// **'Vous êtes actuellement hors-ligne. Certaines fonctionnalités peuvent être limitées.'**
  String get emptyStateOfflineMessage;

  /// No description provided for @emptyStateOfflineAction.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get emptyStateOfflineAction;

  /// No description provided for @emptyStateErrorTitle.
  ///
  /// In fr, this message translates to:
  /// **'Une erreur est survenue'**
  String get emptyStateErrorTitle;

  /// No description provided for @emptyStateErrorMessage.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger les données. Veuillez réessayer.'**
  String get emptyStateErrorMessage;

  /// No description provided for @emptyStateErrorAction.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get emptyStateErrorAction;

  /// No description provided for @emptyStateMaintenanceTitle.
  ///
  /// In fr, this message translates to:
  /// **'Maintenance en cours'**
  String get emptyStateMaintenanceTitle;

  /// No description provided for @emptyStateMaintenanceMessage.
  ///
  /// In fr, this message translates to:
  /// **'L\'application est en maintenance. Veuillez revenir plus tard.'**
  String get emptyStateMaintenanceMessage;

  /// No description provided for @transferSelectRecipientFirst.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez sélectionner un bénéficiaire'**
  String get transferSelectRecipientFirst;

  /// No description provided for @transferSelectPaymentMethodFirst.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez sélectionner un mode de paiement'**
  String get transferSelectPaymentMethodFirst;

  /// No description provided for @transferInitiated.
  ///
  /// In fr, this message translates to:
  /// **'Transfert initié avec succès'**
  String get transferInitiated;

  /// No description provided for @transferFailed.
  ///
  /// In fr, this message translates to:
  /// **'Échec du transfert'**
  String get transferFailed;

  /// No description provided for @businessCreationError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la création'**
  String get businessCreationError;

  /// No description provided for @reviewPleaseRate.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez donner une note'**
  String get reviewPleaseRate;

  /// No description provided for @reviewPleaseWrite.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez écrire un avis'**
  String get reviewPleaseWrite;

  /// No description provided for @reviewSubmitted.
  ///
  /// In fr, this message translates to:
  /// **'Avis soumis avec succès'**
  String get reviewSubmitted;

  /// No description provided for @reviewSubmissionError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la soumission'**
  String get reviewSubmissionError;

  /// No description provided for @mustBeLoggedIn.
  ///
  /// In fr, this message translates to:
  /// **'Vous devez être connecté'**
  String get mustBeLoggedIn;

  /// No description provided for @groupRequestSent.
  ///
  /// In fr, this message translates to:
  /// **'Demande envoyée avec succès'**
  String get groupRequestSent;

  /// No description provided for @groupRequestApproved.
  ///
  /// In fr, this message translates to:
  /// **'Demande approuvée'**
  String get groupRequestApproved;

  /// No description provided for @groupRequestDeclined.
  ///
  /// In fr, this message translates to:
  /// **'Demande refusée'**
  String get groupRequestDeclined;

  /// No description provided for @messageSent.
  ///
  /// In fr, this message translates to:
  /// **'Message envoyé'**
  String get messageSent;

  /// No description provided for @cannotGetLocation.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'obtenir la position'**
  String get cannotGetLocation;

  /// No description provided for @reminderScheduled.
  ///
  /// In fr, this message translates to:
  /// **'Rappel programmé'**
  String get reminderScheduled;

  /// No description provided for @reminderRemoved.
  ///
  /// In fr, this message translates to:
  /// **'Rappel supprimé'**
  String get reminderRemoved;

  /// No description provided for @reminderPassed.
  ///
  /// In fr, this message translates to:
  /// **'Passé'**
  String get reminderPassed;

  /// No description provided for @selectAudioFile.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez sélectionner un fichier audio'**
  String get selectAudioFile;

  /// No description provided for @episodePublished.
  ///
  /// In fr, this message translates to:
  /// **'Épisode publié avec succès'**
  String get episodePublished;

  /// No description provided for @downloadRemoved.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargement supprimé'**
  String get downloadRemoved;

  /// No description provided for @transactionStatusPending.
  ///
  /// In fr, this message translates to:
  /// **'En attente'**
  String get transactionStatusPending;

  /// No description provided for @transactionStatusDebiting.
  ///
  /// In fr, this message translates to:
  /// **'Débit en cours'**
  String get transactionStatusDebiting;

  /// No description provided for @transactionStatusProcessing.
  ///
  /// In fr, this message translates to:
  /// **'Traitement'**
  String get transactionStatusProcessing;

  /// No description provided for @transactionStatusSending.
  ///
  /// In fr, this message translates to:
  /// **'Envoi en cours'**
  String get transactionStatusSending;

  /// No description provided for @transactionStatusCompleted.
  ///
  /// In fr, this message translates to:
  /// **'Terminé'**
  String get transactionStatusCompleted;

  /// No description provided for @transactionStatusFailed.
  ///
  /// In fr, this message translates to:
  /// **'Échoué'**
  String get transactionStatusFailed;

  /// No description provided for @transactionStatusRefunding.
  ///
  /// In fr, this message translates to:
  /// **'Remboursement en cours'**
  String get transactionStatusRefunding;

  /// No description provided for @transactionStatusRefunded.
  ///
  /// In fr, this message translates to:
  /// **'Remboursé'**
  String get transactionStatusRefunded;

  /// No description provided for @transactionStatusCancelled.
  ///
  /// In fr, this message translates to:
  /// **'Annulé'**
  String get transactionStatusCancelled;

  /// No description provided for @businessCategoryRestaurant.
  ///
  /// In fr, this message translates to:
  /// **'Restaurant'**
  String get businessCategoryRestaurant;

  /// No description provided for @businessCategoryGrocery.
  ///
  /// In fr, this message translates to:
  /// **'Épicerie'**
  String get businessCategoryGrocery;

  /// No description provided for @businessCategoryBeauty.
  ///
  /// In fr, this message translates to:
  /// **'Beauté'**
  String get businessCategoryBeauty;

  /// No description provided for @businessCategoryFashion.
  ///
  /// In fr, this message translates to:
  /// **'Mode'**
  String get businessCategoryFashion;

  /// No description provided for @businessCategoryServices.
  ///
  /// In fr, this message translates to:
  /// **'Services'**
  String get businessCategoryServices;

  /// No description provided for @businessCategoryHealth.
  ///
  /// In fr, this message translates to:
  /// **'Santé'**
  String get businessCategoryHealth;

  /// No description provided for @businessCategoryEducation.
  ///
  /// In fr, this message translates to:
  /// **'Éducation'**
  String get businessCategoryEducation;

  /// No description provided for @businessCategoryTechnology.
  ///
  /// In fr, this message translates to:
  /// **'Technologie'**
  String get businessCategoryTechnology;

  /// No description provided for @businessCategoryTravel.
  ///
  /// In fr, this message translates to:
  /// **'Voyage'**
  String get businessCategoryTravel;

  /// No description provided for @businessCategoryOther.
  ///
  /// In fr, this message translates to:
  /// **'Autre'**
  String get businessCategoryOther;

  /// No description provided for @callAudio.
  ///
  /// In fr, this message translates to:
  /// **'Appel audio'**
  String get callAudio;

  /// No description provided for @callVideo.
  ///
  /// In fr, this message translates to:
  /// **'Appel vidéo'**
  String get callVideo;

  /// No description provided for @callRinging.
  ///
  /// In fr, this message translates to:
  /// **'Sonnerie'**
  String get callRinging;

  /// No description provided for @callOngoing.
  ///
  /// In fr, this message translates to:
  /// **'En cours'**
  String get callOngoing;

  /// No description provided for @callMissed.
  ///
  /// In fr, this message translates to:
  /// **'Manqué'**
  String get callMissed;

  /// No description provided for @callDeclined.
  ///
  /// In fr, this message translates to:
  /// **'Refusé'**
  String get callDeclined;

  /// No description provided for @callFailed.
  ///
  /// In fr, this message translates to:
  /// **'Échoué'**
  String get callFailed;

  /// No description provided for @errorWithMessage.
  ///
  /// In fr, this message translates to:
  /// **'Erreur : {message}'**
  String errorWithMessage(String message);

  /// No description provided for @consentWelcome.
  ///
  /// In fr, this message translates to:
  /// **'Bienvenue !'**
  String get consentWelcome;

  /// No description provided for @consentAcceptConditions.
  ///
  /// In fr, this message translates to:
  /// **'Avant de continuer, veuillez accepter nos conditions.'**
  String get consentAcceptConditions;

  /// No description provided for @consentTermsAccept.
  ///
  /// In fr, this message translates to:
  /// **'J\'accepte les conditions générales d\'utilisation de l\'application Diaspo Niger.'**
  String get consentTermsAccept;

  /// No description provided for @consentPrivacyAccept.
  ///
  /// In fr, this message translates to:
  /// **'J\'accepte la politique de confidentialité et le traitement de mes données personnelles.'**
  String get consentPrivacyAccept;

  /// No description provided for @consentCodeOfConductAccept.
  ///
  /// In fr, this message translates to:
  /// **'Je m\'engage à respecter le code de conduite et les règles de la communauté.'**
  String get consentCodeOfConductAccept;

  /// No description provided for @consentDataProtection.
  ///
  /// In fr, this message translates to:
  /// **'Vos données sont protégées et ne seront jamais partagées sans votre consentement.'**
  String get consentDataProtection;

  /// No description provided for @readDetails.
  ///
  /// In fr, this message translates to:
  /// **'Lire les détails →'**
  String get readDetails;

  /// No description provided for @forgotPasswordTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe oublié ?'**
  String get forgotPasswordTitle;

  /// No description provided for @forgotPasswordDescription.
  ///
  /// In fr, this message translates to:
  /// **'Entrez votre adresse email pour recevoir un lien de réinitialisation.'**
  String get forgotPasswordDescription;

  /// No description provided for @sendLink.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer le lien'**
  String get sendLink;

  /// No description provided for @backToLogin.
  ///
  /// In fr, this message translates to:
  /// **'Retour à la connexion'**
  String get backToLogin;

  /// No description provided for @emailSentTitle.
  ///
  /// In fr, this message translates to:
  /// **'Email envoyé !'**
  String get emailSentTitle;

  /// No description provided for @resetLinkSentTo.
  ///
  /// In fr, this message translates to:
  /// **'Nous avons envoyé un lien de réinitialisation à {email}'**
  String resetLinkSentTo(String email);

  /// No description provided for @checkSpamFolder.
  ///
  /// In fr, this message translates to:
  /// **'Vérifiez également votre dossier spam si vous ne trouvez pas l\'email.'**
  String get checkSpamFolder;

  /// No description provided for @resendLink.
  ///
  /// In fr, this message translates to:
  /// **'Renvoyer le lien'**
  String get resendLink;

  /// No description provided for @enableNotifications.
  ///
  /// In fr, this message translates to:
  /// **'Activer les notifications'**
  String get enableNotifications;

  /// No description provided for @notificationsMasterOnDesc.
  ///
  /// In fr, this message translates to:
  /// **'Vous recevez les notifications de l\'application'**
  String get notificationsMasterOnDesc;

  /// No description provided for @notificationsMasterOffDesc.
  ///
  /// In fr, this message translates to:
  /// **'Toutes les notifications sont coupées'**
  String get notificationsMasterOffDesc;

  /// No description provided for @notificationPromptMessage.
  ///
  /// In fr, this message translates to:
  /// **'Recevez des alertes lorsque vous avez de nouveaux messages, appels entrants ou activités importantes.\n\nVous pouvez modifier ce paramètre à tout moment.'**
  String get notificationPromptMessage;

  /// No description provided for @later.
  ///
  /// In fr, this message translates to:
  /// **'Plus tard'**
  String get later;

  /// No description provided for @notificationsDisabledMessage.
  ///
  /// In fr, this message translates to:
  /// **'Les notifications sont désactivées. Vous ne recevrez pas d\'alertes pour les nouveaux messages et appels.\n\nPour les activer, allez dans les paramètres de l\'application.'**
  String get notificationsDisabledMessage;

  /// No description provided for @openSettings.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir les paramètres'**
  String get openSettings;

  /// No description provided for @permissionBlocked.
  ///
  /// In fr, this message translates to:
  /// **'Permission bloquée'**
  String get permissionBlocked;

  /// No description provided for @typeYourReply.
  ///
  /// In fr, this message translates to:
  /// **'Tapez votre réponse...'**
  String get typeYourReply;

  /// No description provided for @openPlayStore.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir Play Store'**
  String get openPlayStore;

  /// No description provided for @understood.
  ///
  /// In fr, this message translates to:
  /// **'Compris'**
  String get understood;

  /// No description provided for @connectedElsewhere.
  ///
  /// In fr, this message translates to:
  /// **'Connecté ailleurs'**
  String get connectedElsewhere;

  /// No description provided for @connectedElsewhereMessage.
  ///
  /// In fr, this message translates to:
  /// **'Votre compte a été connecté sur un autre appareil. Vous avez été déconnecté de cet appareil pour sécurité.'**
  String get connectedElsewhereMessage;

  /// No description provided for @ok.
  ///
  /// In fr, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @taxAutomatic.
  ///
  /// In fr, this message translates to:
  /// **'Automatique'**
  String get taxAutomatic;

  /// No description provided for @taxExempt.
  ///
  /// In fr, this message translates to:
  /// **'Exonéré'**
  String get taxExempt;

  /// No description provided for @taxStandard.
  ///
  /// In fr, this message translates to:
  /// **'TVA Standard (19%)'**
  String get taxStandard;

  /// No description provided for @taxReduced.
  ///
  /// In fr, this message translates to:
  /// **'TVA Réduite (10%)'**
  String get taxReduced;

  /// No description provided for @taxCustom.
  ///
  /// In fr, this message translates to:
  /// **'Personnalisé'**
  String get taxCustom;

  /// No description provided for @views.
  ///
  /// In fr, this message translates to:
  /// **'vues'**
  String get views;

  /// No description provided for @reviews.
  ///
  /// In fr, this message translates to:
  /// **'Avis'**
  String get reviews;

  /// No description provided for @contactAction.
  ///
  /// In fr, this message translates to:
  /// **'Contacter'**
  String get contactAction;

  /// No description provided for @addAction.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter'**
  String get addAction;

  /// No description provided for @viewAll.
  ///
  /// In fr, this message translates to:
  /// **'Voir tout'**
  String get viewAll;

  /// No description provided for @modify.
  ///
  /// In fr, this message translates to:
  /// **'Modifier'**
  String get modify;

  /// No description provided for @retryAction.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get retryAction;

  /// No description provided for @tooltipFavorites.
  ///
  /// In fr, this message translates to:
  /// **'Favoris'**
  String get tooltipFavorites;

  /// No description provided for @tooltipForward.
  ///
  /// In fr, this message translates to:
  /// **'Transférer'**
  String get tooltipForward;

  /// No description provided for @tooltipDelete.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get tooltipDelete;

  /// No description provided for @tooltipVoiceCall.
  ///
  /// In fr, this message translates to:
  /// **'Appel vocal'**
  String get tooltipVoiceCall;

  /// No description provided for @tooltipVideoCall.
  ///
  /// In fr, this message translates to:
  /// **'Appel vidéo'**
  String get tooltipVideoCall;

  /// No description provided for @addCaption.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une légende...'**
  String get addCaption;

  /// No description provided for @photosLabel.
  ///
  /// In fr, this message translates to:
  /// **'Photos'**
  String get photosLabel;

  /// No description provided for @videosLabel.
  ///
  /// In fr, this message translates to:
  /// **'Vidéos'**
  String get videosLabel;

  /// No description provided for @audioLabel.
  ///
  /// In fr, this message translates to:
  /// **'Audio'**
  String get audioLabel;

  /// No description provided for @documentsLabel.
  ///
  /// In fr, this message translates to:
  /// **'Documents'**
  String get documentsLabel;

  /// No description provided for @photoLabel.
  ///
  /// In fr, this message translates to:
  /// **'Photo'**
  String get photoLabel;

  /// No description provided for @videoLabel.
  ///
  /// In fr, this message translates to:
  /// **'Vidéo'**
  String get videoLabel;

  /// No description provided for @positionLabel.
  ///
  /// In fr, this message translates to:
  /// **'Position'**
  String get positionLabel;

  /// No description provided for @microphonePermissionRequired.
  ///
  /// In fr, this message translates to:
  /// **'Permission du microphone requise'**
  String get microphonePermissionRequired;

  /// No description provided for @cannotDeleteAfter1Hour.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de supprimer le message après 1h'**
  String get cannotDeleteAfter1Hour;

  /// No description provided for @sendAction.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer'**
  String get sendAction;

  /// No description provided for @forwardError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors du transfert'**
  String get forwardError;

  /// No description provided for @cannotStartCall.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de démarrer l\'appel'**
  String get cannotStartCall;

  /// No description provided for @remindMeLater.
  ///
  /// In fr, this message translates to:
  /// **'Me rappeler plus tard'**
  String get remindMeLater;

  /// No description provided for @in1Hour.
  ///
  /// In fr, this message translates to:
  /// **'Dans 1 heure'**
  String get in1Hour;

  /// No description provided for @tomorrowMorning.
  ///
  /// In fr, this message translates to:
  /// **'Demain matin (9h)'**
  String get tomorrowMorning;

  /// No description provided for @flipCamera.
  ///
  /// In fr, this message translates to:
  /// **'Flip'**
  String get flipCamera;

  /// No description provided for @permissionRequired.
  ///
  /// In fr, this message translates to:
  /// **'Permission requise'**
  String get permissionRequired;

  /// No description provided for @adminOverview.
  ///
  /// In fr, this message translates to:
  /// **'Aperçu'**
  String get adminOverview;

  /// No description provided for @adminUsers.
  ///
  /// In fr, this message translates to:
  /// **'Utilisateurs'**
  String get adminUsers;

  /// No description provided for @adminBusinesses.
  ///
  /// In fr, this message translates to:
  /// **'Commerces'**
  String get adminBusinesses;

  /// No description provided for @adminContent.
  ///
  /// In fr, this message translates to:
  /// **'Contenu'**
  String get adminContent;

  /// No description provided for @adminReports.
  ///
  /// In fr, this message translates to:
  /// **'Signalements'**
  String get adminReports;

  /// No description provided for @adminSupport.
  ///
  /// In fr, this message translates to:
  /// **'Support'**
  String get adminSupport;

  /// No description provided for @adminLiveRooms.
  ///
  /// In fr, this message translates to:
  /// **'Salons Live'**
  String get adminLiveRooms;

  /// No description provided for @adminMarketplace.
  ///
  /// In fr, this message translates to:
  /// **'Marketplace'**
  String get adminMarketplace;

  /// No description provided for @adminTransfers.
  ///
  /// In fr, this message translates to:
  /// **'Transferts'**
  String get adminTransfers;

  /// No description provided for @adminEmbassies.
  ///
  /// In fr, this message translates to:
  /// **'Ambassades'**
  String get adminEmbassies;

  /// No description provided for @adminAnalytics.
  ///
  /// In fr, this message translates to:
  /// **'Analytics'**
  String get adminAnalytics;

  /// No description provided for @adminNotifications.
  ///
  /// In fr, this message translates to:
  /// **'Notifications'**
  String get adminNotifications;

  /// No description provided for @adminConfiguration.
  ///
  /// In fr, this message translates to:
  /// **'Configuration'**
  String get adminConfiguration;

  /// No description provided for @adminFeatures.
  ///
  /// In fr, this message translates to:
  /// **'Features'**
  String get adminFeatures;

  /// No description provided for @adminAudit.
  ///
  /// In fr, this message translates to:
  /// **'Audit'**
  String get adminAudit;

  /// No description provided for @adminRoles.
  ///
  /// In fr, this message translates to:
  /// **'Rôles Admin'**
  String get adminRoles;

  /// No description provided for @adminRefresh.
  ///
  /// In fr, this message translates to:
  /// **'Actualiser'**
  String get adminRefresh;

  /// No description provided for @adminLogout.
  ///
  /// In fr, this message translates to:
  /// **'Déconnexion'**
  String get adminLogout;

  /// No description provided for @adminCreateEmbassy.
  ///
  /// In fr, this message translates to:
  /// **'Créer une ambassade'**
  String get adminCreateEmbassy;

  /// No description provided for @adminModerate.
  ///
  /// In fr, this message translates to:
  /// **'Modérer'**
  String get adminModerate;

  /// No description provided for @adminModerationMode.
  ///
  /// In fr, this message translates to:
  /// **'Mode Modération'**
  String get adminModerationMode;

  /// No description provided for @adminGhostModeDescription.
  ///
  /// In fr, this message translates to:
  /// **'Vous allez rejoindre ce salon en mode invisible (ghost mode). Les participants ne pourront pas vous voir.\n\nVous pourrez:\n• Écouter les conversations\n• Voir les vidéos (si activées)\n• Avertir l\'hôte\n• Fermer le salon si nécessaire'**
  String get adminGhostModeDescription;

  /// No description provided for @adminJoin.
  ///
  /// In fr, this message translates to:
  /// **'Rejoindre'**
  String get adminJoin;

  /// No description provided for @adminViewReports.
  ///
  /// In fr, this message translates to:
  /// **'Voir Signalements'**
  String get adminViewReports;

  /// No description provided for @adminManageUsers.
  ///
  /// In fr, this message translates to:
  /// **'Gérer Utilisateurs'**
  String get adminManageUsers;

  /// No description provided for @adminSendNotification.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer Notification'**
  String get adminSendNotification;

  /// No description provided for @adminViewAnalytics.
  ///
  /// In fr, this message translates to:
  /// **'Voir Analytics'**
  String get adminViewAnalytics;

  /// No description provided for @adminFeatureFlags.
  ///
  /// In fr, this message translates to:
  /// **'Feature Flags'**
  String get adminFeatureFlags;

  /// No description provided for @adminAuditHistory.
  ///
  /// In fr, this message translates to:
  /// **'Historique Audit'**
  String get adminAuditHistory;

  /// No description provided for @adminNewAdmin.
  ///
  /// In fr, this message translates to:
  /// **'Nouvel Admin'**
  String get adminNewAdmin;

  /// No description provided for @adminChangeRole.
  ///
  /// In fr, this message translates to:
  /// **'Changer le rôle'**
  String adminChangeRole(String role);

  /// No description provided for @adminRevokeAccess.
  ///
  /// In fr, this message translates to:
  /// **'Révoquer l\'accès admin'**
  String get adminRevokeAccess;

  /// No description provided for @adminAccessDenied.
  ///
  /// In fr, this message translates to:
  /// **'Accès refusé. Compte administrateur requis.'**
  String get adminAccessDenied;

  /// No description provided for @adminBack.
  ///
  /// In fr, this message translates to:
  /// **'Retour'**
  String get adminBack;

  /// No description provided for @adminAllTab.
  ///
  /// In fr, this message translates to:
  /// **'Tous ({count})'**
  String adminAllTab(int count);

  /// No description provided for @adminPendingTab.
  ///
  /// In fr, this message translates to:
  /// **'En attente ({count})'**
  String adminPendingTab(int count);

  /// No description provided for @adminBoostedTab.
  ///
  /// In fr, this message translates to:
  /// **'Boostés ({count})'**
  String adminBoostedTab(int count);

  /// No description provided for @adminVerify.
  ///
  /// In fr, this message translates to:
  /// **'Vérifier'**
  String get adminVerify;

  /// No description provided for @adminRemoveVerification.
  ///
  /// In fr, this message translates to:
  /// **'Retirer vérification'**
  String get adminRemoveVerification;

  /// No description provided for @adminBoost30Days.
  ///
  /// In fr, this message translates to:
  /// **'Booster (30 jours)'**
  String get adminBoost30Days;

  /// No description provided for @adminRemoveBoost.
  ///
  /// In fr, this message translates to:
  /// **'Retirer boost'**
  String get adminRemoveBoost;

  /// No description provided for @adminConfirmDeletion.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer la suppression'**
  String get adminConfirmDeletion;

  /// No description provided for @adminGroupPrivate.
  ///
  /// In fr, this message translates to:
  /// **'Groupe rendu privé'**
  String get adminGroupPrivate;

  /// No description provided for @adminGroupPublic.
  ///
  /// In fr, this message translates to:
  /// **'Groupe rendu public'**
  String get adminGroupPublic;

  /// No description provided for @makePublic.
  ///
  /// In fr, this message translates to:
  /// **'Rendre public'**
  String get makePublic;

  /// No description provided for @makePrivate.
  ///
  /// In fr, this message translates to:
  /// **'Rendre privé'**
  String get makePrivate;

  /// No description provided for @adminEmailLabel.
  ///
  /// In fr, this message translates to:
  /// **'Email'**
  String get adminEmailLabel;

  /// No description provided for @adminEmailHint.
  ///
  /// In fr, this message translates to:
  /// **'utilisateur@exemple.com'**
  String get adminEmailHint;

  /// No description provided for @adminEmbassyCreated.
  ///
  /// In fr, this message translates to:
  /// **'Ambassade créée avec succès!'**
  String get adminEmbassyCreated;

  /// No description provided for @adminConnectionError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la connexion au salon'**
  String get adminConnectionError;

  /// No description provided for @adminSearchPlaceholder.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher par nom, raison, ID...'**
  String get adminSearchPlaceholder;

  /// No description provided for @adminAllActions.
  ///
  /// In fr, this message translates to:
  /// **'Toutes les actions'**
  String get adminAllActions;

  /// No description provided for @adminActionUsers.
  ///
  /// In fr, this message translates to:
  /// **'Utilisateurs'**
  String get adminActionUsers;

  /// No description provided for @adminActionBusinesses.
  ///
  /// In fr, this message translates to:
  /// **'Commerces'**
  String get adminActionBusinesses;

  /// No description provided for @adminActionContent.
  ///
  /// In fr, this message translates to:
  /// **'Contenu'**
  String get adminActionContent;

  /// No description provided for @adminActionReports.
  ///
  /// In fr, this message translates to:
  /// **'Signalements'**
  String get adminActionReports;

  /// No description provided for @adminActionTransactions.
  ///
  /// In fr, this message translates to:
  /// **'Transactions'**
  String get adminActionTransactions;

  /// No description provided for @adminActionSettings.
  ///
  /// In fr, this message translates to:
  /// **'Configuration'**
  String get adminActionSettings;

  /// No description provided for @adminFeatureFlagsUpdated.
  ///
  /// In fr, this message translates to:
  /// **'Feature flags mis à jour'**
  String get adminFeatureFlagsUpdated;

  /// No description provided for @adminMaintenanceHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex: Application en maintenance...'**
  String get adminMaintenanceHint;

  /// No description provided for @adminSignInWithGoogle.
  ///
  /// In fr, this message translates to:
  /// **'Se connecter avec Google'**
  String get adminSignInWithGoogle;

  /// No description provided for @adminEmailField.
  ///
  /// In fr, this message translates to:
  /// **'Email'**
  String get adminEmailField;

  /// No description provided for @adminPasswordField.
  ///
  /// In fr, this message translates to:
  /// **'Password'**
  String get adminPasswordField;

  /// No description provided for @adminLogin.
  ///
  /// In fr, this message translates to:
  /// **'Connexion'**
  String get adminLogin;

  /// No description provided for @adminProductsTab.
  ///
  /// In fr, this message translates to:
  /// **'Produits ({count})'**
  String adminProductsTab(int count);

  /// No description provided for @adminOrdersTab.
  ///
  /// In fr, this message translates to:
  /// **'Commandes ({count})'**
  String adminOrdersTab(int count);

  /// No description provided for @adminDisputesTab.
  ///
  /// In fr, this message translates to:
  /// **'Litiges ({count})'**
  String adminDisputesTab(int count);

  /// No description provided for @adminBuyer.
  ///
  /// In fr, this message translates to:
  /// **'Acheteur'**
  String get adminBuyer;

  /// No description provided for @adminSeller.
  ///
  /// In fr, this message translates to:
  /// **'Vendeur'**
  String get adminSeller;

  /// No description provided for @adminRefund.
  ///
  /// In fr, this message translates to:
  /// **'Rembourser'**
  String get adminRefund;

  /// No description provided for @adminGroupsTab.
  ///
  /// In fr, this message translates to:
  /// **'Groupes ({count})'**
  String adminGroupsTab(int count);

  /// No description provided for @adminSendTab.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer'**
  String get adminSendTab;

  /// No description provided for @adminHistoryTab.
  ///
  /// In fr, this message translates to:
  /// **'Historique'**
  String get adminHistoryTab;

  /// No description provided for @adminTitleLabel.
  ///
  /// In fr, this message translates to:
  /// **'Titre'**
  String get adminTitleLabel;

  /// No description provided for @adminMessageLabel.
  ///
  /// In fr, this message translates to:
  /// **'Message'**
  String get adminMessageLabel;

  /// No description provided for @adminClearAction.
  ///
  /// In fr, this message translates to:
  /// **'Effacer'**
  String get adminClearAction;

  /// No description provided for @adminConfirmSend.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer l\'envoi'**
  String get adminConfirmSend;

  /// No description provided for @adminSendingNotificationTo.
  ///
  /// In fr, this message translates to:
  /// **'Vous êtes sur le point d\'envoyer une notification à:'**
  String get adminSendingNotificationTo;

  /// No description provided for @adminMessagePreview.
  ///
  /// In fr, this message translates to:
  /// **'Message: {message}'**
  String adminMessagePreview(String message);

  /// No description provided for @adminSearchReportsPlaceholder.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher par nom, raison, ID...'**
  String get adminSearchReportsPlaceholder;

  /// No description provided for @adminViewTarget.
  ///
  /// In fr, this message translates to:
  /// **'Voir le {type}'**
  String adminViewTarget(String type);

  /// No description provided for @adminReject.
  ///
  /// In fr, this message translates to:
  /// **'Rejeter'**
  String get adminReject;

  /// No description provided for @adminProcess.
  ///
  /// In fr, this message translates to:
  /// **'Traiter'**
  String get adminProcess;

  /// No description provided for @adminDeleteContent.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer contenu'**
  String get adminDeleteContent;

  /// No description provided for @adminClearFilters.
  ///
  /// In fr, this message translates to:
  /// **'Effacer les filtres'**
  String get adminClearFilters;

  /// No description provided for @adminRejectReasonHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex: Signalement non fondé, contenu conforme aux règles...'**
  String get adminRejectReasonHint;

  /// No description provided for @adminProcessNoteHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex: Avertissement envoyé, contenu modifié...'**
  String get adminProcessNoteHint;

  /// No description provided for @adminChangeToRole.
  ///
  /// In fr, this message translates to:
  /// **'Changer en {role}'**
  String adminChangeToRole(String role);

  /// No description provided for @adminFeesTab.
  ///
  /// In fr, this message translates to:
  /// **'Frais'**
  String get adminFeesTab;

  /// No description provided for @adminBoostsTab.
  ///
  /// In fr, this message translates to:
  /// **'Boosts'**
  String get adminBoostsTab;

  /// No description provided for @adminTaxesTab.
  ///
  /// In fr, this message translates to:
  /// **'Taxes'**
  String get adminTaxesTab;

  /// No description provided for @adminMediaTab.
  ///
  /// In fr, this message translates to:
  /// **'Médias'**
  String get adminMediaTab;

  /// No description provided for @adminSystemTab.
  ///
  /// In fr, this message translates to:
  /// **'Système'**
  String get adminSystemTab;

  /// No description provided for @adminAudioTab.
  ///
  /// In fr, this message translates to:
  /// **'Audio'**
  String get adminAudioTab;

  /// No description provided for @adminFeesUpdated.
  ///
  /// In fr, this message translates to:
  /// **'Frais mis à jour'**
  String get adminFeesUpdated;

  /// No description provided for @adminFeePercentage.
  ///
  /// In fr, this message translates to:
  /// **'Pourcentage des frais'**
  String get adminFeePercentage;

  /// No description provided for @adminMinFee.
  ///
  /// In fr, this message translates to:
  /// **'Frais minimum (XOF)'**
  String get adminMinFee;

  /// No description provided for @adminMaxFee.
  ///
  /// In fr, this message translates to:
  /// **'Frais maximum (XOF)'**
  String get adminMaxFee;

  /// No description provided for @adminPlatformCommission.
  ///
  /// In fr, this message translates to:
  /// **'Commission plateforme'**
  String get adminPlatformCommission;

  /// No description provided for @adminMinCommission.
  ///
  /// In fr, this message translates to:
  /// **'Commission min (XOF)'**
  String get adminMinCommission;

  /// No description provided for @adminMaxCommission.
  ///
  /// In fr, this message translates to:
  /// **'Commission max (XOF)'**
  String get adminMaxCommission;

  /// No description provided for @adminBoostPricesUpdated.
  ///
  /// In fr, this message translates to:
  /// **'Tarifs boost mis à jour'**
  String get adminBoostPricesUpdated;

  /// No description provided for @adminVatRatesUpdated.
  ///
  /// In fr, this message translates to:
  /// **'Taux de TVA mis à jour'**
  String get adminVatRatesUpdated;

  /// No description provided for @adminMediaLimitsUpdated.
  ///
  /// In fr, this message translates to:
  /// **'Limites médias mises à jour'**
  String get adminMediaLimitsUpdated;

  /// No description provided for @adminMaxDimension.
  ///
  /// In fr, this message translates to:
  /// **'Dimension max (px)'**
  String get adminMaxDimension;

  /// No description provided for @adminCompressionQuality.
  ///
  /// In fr, this message translates to:
  /// **'Qualité compression (%)'**
  String get adminCompressionQuality;

  /// No description provided for @adminMaxImagesUpload.
  ///
  /// In fr, this message translates to:
  /// **'Max images/upload'**
  String get adminMaxImagesUpload;

  /// No description provided for @adminMaxImageSize.
  ///
  /// In fr, this message translates to:
  /// **'Taille max image (MB)'**
  String get adminMaxImageSize;

  /// No description provided for @adminMaxVideoSize.
  ///
  /// In fr, this message translates to:
  /// **'Taille max vidéo (MB)'**
  String get adminMaxVideoSize;

  /// No description provided for @adminMaxMessageChars.
  ///
  /// In fr, this message translates to:
  /// **'Caractères max par message'**
  String get adminMaxMessageChars;

  /// No description provided for @adminUrlsUpdated.
  ///
  /// In fr, this message translates to:
  /// **'URLs mises à jour'**
  String get adminUrlsUpdated;

  /// No description provided for @adminIntervalsUpdated.
  ///
  /// In fr, this message translates to:
  /// **'Intervalles mis à jour'**
  String get adminIntervalsUpdated;

  /// No description provided for @adminShareBaseUrl.
  ///
  /// In fr, this message translates to:
  /// **'URL de base pour partage'**
  String get adminShareBaseUrl;

  /// No description provided for @adminSupportEmail.
  ///
  /// In fr, this message translates to:
  /// **'Email support'**
  String get adminSupportEmail;

  /// No description provided for @adminPrivacyEmail.
  ///
  /// In fr, this message translates to:
  /// **'Email confidentialité (RGPD)'**
  String get adminPrivacyEmail;

  /// No description provided for @adminBugReportEmail.
  ///
  /// In fr, this message translates to:
  /// **'Email rapport de bugs'**
  String get adminBugReportEmail;

  /// No description provided for @adminFeedbackEmail.
  ///
  /// In fr, this message translates to:
  /// **'Email feedback'**
  String get adminFeedbackEmail;

  /// No description provided for @adminModerationEmail.
  ///
  /// In fr, this message translates to:
  /// **'Email modération'**
  String get adminModerationEmail;

  /// No description provided for @adminLocationUpdateInterval.
  ///
  /// In fr, this message translates to:
  /// **'Mise à jour localisation (min)'**
  String get adminLocationUpdateInterval;

  /// No description provided for @adminOnlineHeartbeat.
  ///
  /// In fr, this message translates to:
  /// **'Heartbeat statut en ligne (min)'**
  String get adminOnlineHeartbeat;

  /// No description provided for @adminCacheDuration.
  ///
  /// In fr, this message translates to:
  /// **'Durée cache (min)'**
  String get adminCacheDuration;

  /// No description provided for @adminAudioSettingsUpdated.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres audio mis à jour'**
  String get adminAudioSettingsUpdated;

  /// No description provided for @adminTicketPrices.
  ///
  /// In fr, this message translates to:
  /// **'Prix tickets (XOF)'**
  String get adminTicketPrices;

  /// No description provided for @adminTipAmounts.
  ///
  /// In fr, this message translates to:
  /// **'Montant pourboires (XOF)'**
  String get adminTipAmounts;

  /// No description provided for @adminPriceHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex: 1, 2, 5, 10, 20'**
  String get adminPriceHint;

  /// No description provided for @adminComplete.
  ///
  /// In fr, this message translates to:
  /// **'Compléter'**
  String get adminComplete;

  /// No description provided for @adminSearchUserPlaceholder.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un utilisateur...'**
  String get adminSearchUserPlaceholder;

  /// No description provided for @adminLoadingText.
  ///
  /// In fr, this message translates to:
  /// **'Chargement...'**
  String get adminLoadingText;

  /// No description provided for @adminNoUserFound.
  ///
  /// In fr, this message translates to:
  /// **'Aucun utilisateur trouvé'**
  String get adminNoUserFound;

  /// No description provided for @adminUserActivity.
  ///
  /// In fr, this message translates to:
  /// **'Activité de {name}'**
  String adminUserActivity(String name);

  /// No description provided for @adminNoActivity.
  ///
  /// In fr, this message translates to:
  /// **'Aucune activité enregistrée'**
  String get adminNoActivity;

  /// No description provided for @adminConfirmLogout.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer la déconnexion'**
  String get adminConfirmLogout;

  /// No description provided for @adminDisconnect.
  ///
  /// In fr, this message translates to:
  /// **'Déconnecter'**
  String get adminDisconnect;

  /// No description provided for @adminReactivate.
  ///
  /// In fr, this message translates to:
  /// **'Réactiver'**
  String get adminReactivate;

  /// No description provided for @adminApprove.
  ///
  /// In fr, this message translates to:
  /// **'Approuver'**
  String get adminApprove;

  /// No description provided for @adminSuspend.
  ///
  /// In fr, this message translates to:
  /// **'Suspendre'**
  String get adminSuspend;

  /// No description provided for @adminEmbassyApproved.
  ///
  /// In fr, this message translates to:
  /// **'Ambassade {name} approuvée'**
  String adminEmbassyApproved(String name);

  /// No description provided for @adminEmbassyRejected.
  ///
  /// In fr, this message translates to:
  /// **'Ambassade {name} rejetée'**
  String adminEmbassyRejected(String name);

  /// No description provided for @adminEmbassySuspended.
  ///
  /// In fr, this message translates to:
  /// **'Ambassade {name} suspendue'**
  String adminEmbassySuspended(String name);

  /// No description provided for @adminEmbassyReactivated.
  ///
  /// In fr, this message translates to:
  /// **'Ambassade {name} réactivée'**
  String adminEmbassyReactivated(String name);

  /// No description provided for @adminRejectRequest.
  ///
  /// In fr, this message translates to:
  /// **'Rejeter la demande'**
  String get adminRejectRequest;

  /// No description provided for @adminRejectReason.
  ///
  /// In fr, this message translates to:
  /// **'Raison du rejet'**
  String get adminRejectReason;

  /// No description provided for @adminExportInProgress.
  ///
  /// In fr, this message translates to:
  /// **'Export des {type} en cours...'**
  String adminExportInProgress(String type);

  /// No description provided for @audioRoomWarnHost.
  ///
  /// In fr, this message translates to:
  /// **'Avertir l\'hôte'**
  String get audioRoomWarnHost;

  /// No description provided for @audioRoomTicketHelper.
  ///
  /// In fr, this message translates to:
  /// **'Min: {min} {currency} - Max: {max} {currency}'**
  String audioRoomTicketHelper(String min, String max, String currency);

  /// No description provided for @audioRoomGoalHelper.
  ///
  /// In fr, this message translates to:
  /// **'Min: {min} XOF - Max: {max} XOF'**
  String audioRoomGoalHelper(String min, String max);

  /// No description provided for @heritageStories.
  ///
  /// In fr, this message translates to:
  /// **'Contes'**
  String get heritageStories;

  /// No description provided for @heritageProverbs.
  ///
  /// In fr, this message translates to:
  /// **'Proverbes'**
  String get heritageProverbs;

  /// No description provided for @heritageHistory.
  ///
  /// In fr, this message translates to:
  /// **'Histoire'**
  String get heritageHistory;

  /// No description provided for @heritageCeremonies.
  ///
  /// In fr, this message translates to:
  /// **'Cérémonies'**
  String get heritageCeremonies;

  /// No description provided for @heritageLanguage.
  ///
  /// In fr, this message translates to:
  /// **'Langue'**
  String get heritageLanguage;

  /// No description provided for @heritageCraft.
  ///
  /// In fr, this message translates to:
  /// **'Artisanat'**
  String get heritageCraft;

  /// No description provided for @heritageRecipes.
  ///
  /// In fr, this message translates to:
  /// **'Recettes'**
  String get heritageRecipes;

  /// No description provided for @heritageMedicine.
  ///
  /// In fr, this message translates to:
  /// **'Médecine'**
  String get heritageMedicine;

  /// No description provided for @boostType.
  ///
  /// In fr, this message translates to:
  /// **'Type :'**
  String get boostType;

  /// No description provided for @boostDuration.
  ///
  /// In fr, this message translates to:
  /// **'Durée :'**
  String get boostDuration;

  /// No description provided for @boostTotal.
  ///
  /// In fr, this message translates to:
  /// **'Total :'**
  String get boostTotal;

  /// No description provided for @businessViews.
  ///
  /// In fr, this message translates to:
  /// **'Vues'**
  String get businessViews;

  /// No description provided for @businessReviews.
  ///
  /// In fr, this message translates to:
  /// **'Avis'**
  String get businessReviews;

  /// No description provided for @businessContact.
  ///
  /// In fr, this message translates to:
  /// **'Contacter'**
  String get businessContact;

  /// No description provided for @businessAdd.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter'**
  String get businessAdd;

  /// No description provided for @businessNewPost.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle publication'**
  String get businessNewPost;

  /// No description provided for @businessPostType.
  ///
  /// In fr, this message translates to:
  /// **'Type'**
  String get businessPostType;

  /// No description provided for @businessPostTitle.
  ///
  /// In fr, this message translates to:
  /// **'Titre'**
  String get businessPostTitle;

  /// No description provided for @businessPostTitleHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex: Nouvelle collection disponible'**
  String get businessPostTitleHint;

  /// No description provided for @businessPostContent.
  ///
  /// In fr, this message translates to:
  /// **'Contenu'**
  String get businessPostContent;

  /// No description provided for @businessPostContentHint.
  ///
  /// In fr, this message translates to:
  /// **'Décrivez votre actualité...'**
  String get businessPostContentHint;

  /// No description provided for @businessDeletePost.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get businessDeletePost;

  /// No description provided for @businessSeeAllReviews.
  ///
  /// In fr, this message translates to:
  /// **'Voir les {count} autres avis'**
  String businessSeeAllReviews(int count);

  /// No description provided for @reviewMustBeLoggedIn.
  ///
  /// In fr, this message translates to:
  /// **'Vous devez être connecté pour laisser un avis'**
  String get reviewMustBeLoggedIn;

  /// No description provided for @reviewDeleteTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer l\'avis'**
  String get reviewDeleteTitle;

  /// No description provided for @reviewDeleteConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Voulez-vous vraiment supprimer cet avis ? Cette action est irréversible.'**
  String get reviewDeleteConfirm;

  /// No description provided for @reviewReportTitle.
  ///
  /// In fr, this message translates to:
  /// **'Signaler cet avis'**
  String get reviewReportTitle;

  /// No description provided for @reviewReportReason.
  ///
  /// In fr, this message translates to:
  /// **'Raison du signalement'**
  String get reviewReportReason;

  /// No description provided for @reviewReportHint.
  ///
  /// In fr, this message translates to:
  /// **'Pourquoi signalez-vous cet avis ?'**
  String get reviewReportHint;

  /// No description provided for @reviewReportNoReason.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez indiquer une raison'**
  String get reviewReportNoReason;

  /// No description provided for @reviewModify.
  ///
  /// In fr, this message translates to:
  /// **'Modifier'**
  String get reviewModify;

  /// No description provided for @reviewReport.
  ///
  /// In fr, this message translates to:
  /// **'Signaler'**
  String get reviewReport;

  /// No description provided for @reviewSubmitError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la soumission'**
  String get reviewSubmitError;

  /// No description provided for @reviewTitleOptional.
  ///
  /// In fr, this message translates to:
  /// **'Titre (optionnel)'**
  String get reviewTitleOptional;

  /// No description provided for @reviewTitleHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex: Excellent service'**
  String get reviewTitleHint;

  /// No description provided for @reviewYourReview.
  ///
  /// In fr, this message translates to:
  /// **'Votre avis'**
  String get reviewYourReview;

  /// No description provided for @reviewShareExperience.
  ///
  /// In fr, this message translates to:
  /// **'Partagez votre expérience...'**
  String get reviewShareExperience;

  /// No description provided for @businessSearchCountry.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un pays'**
  String get businessSearchCountry;

  /// No description provided for @businessCityHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex: Paris, Niamey, New York...'**
  String get businessCityHint;

  /// No description provided for @businessNewTitle.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle entreprise'**
  String get businessNewTitle;

  /// No description provided for @businessPhotosSection.
  ///
  /// In fr, this message translates to:
  /// **'Photos'**
  String get businessPhotosSection;

  /// No description provided for @businessCategorySection.
  ///
  /// In fr, this message translates to:
  /// **'Catégorie'**
  String get businessCategorySection;

  /// No description provided for @businessNameLabel.
  ///
  /// In fr, this message translates to:
  /// **'Nom de l\'entreprise *'**
  String get businessNameLabel;

  /// No description provided for @businessDescriptionLabel.
  ///
  /// In fr, this message translates to:
  /// **'Description *'**
  String get businessDescriptionLabel;

  /// No description provided for @businessContactSection.
  ///
  /// In fr, this message translates to:
  /// **'Contact'**
  String get businessContactSection;

  /// No description provided for @businessPhoneLabel.
  ///
  /// In fr, this message translates to:
  /// **'Téléphone'**
  String get businessPhoneLabel;

  /// No description provided for @businessEmailLabel.
  ///
  /// In fr, this message translates to:
  /// **'Email'**
  String get businessEmailLabel;

  /// No description provided for @businessWebsiteLabel.
  ///
  /// In fr, this message translates to:
  /// **'Site web'**
  String get businessWebsiteLabel;

  /// No description provided for @businessLocationSection.
  ///
  /// In fr, this message translates to:
  /// **'Localisation'**
  String get businessLocationSection;

  /// No description provided for @businessSearchCountryHint.
  ///
  /// In fr, this message translates to:
  /// **'Tapez le nom du pays'**
  String get businessSearchCountryHint;

  /// No description provided for @businessCountryLabel.
  ///
  /// In fr, this message translates to:
  /// **'Pays'**
  String get businessCountryLabel;

  /// No description provided for @businessCityLabel.
  ///
  /// In fr, this message translates to:
  /// **'Ville'**
  String get businessCityLabel;

  /// No description provided for @businessAddressLabel.
  ///
  /// In fr, this message translates to:
  /// **'Adresse'**
  String get businessAddressLabel;

  /// No description provided for @businessServicesSection.
  ///
  /// In fr, this message translates to:
  /// **'Services proposés'**
  String get businessServicesSection;

  /// No description provided for @businessAddServiceHint.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un service'**
  String get businessAddServiceHint;

  /// No description provided for @businessCreateButton.
  ///
  /// In fr, this message translates to:
  /// **'Créer l\'entreprise'**
  String get businessCreateButton;

  /// No description provided for @callPermissionTitle.
  ///
  /// In fr, this message translates to:
  /// **'Permission requise'**
  String get callPermissionTitle;

  /// No description provided for @callClose.
  ///
  /// In fr, this message translates to:
  /// **'Fermer'**
  String get callClose;

  /// No description provided for @embassyRequestSubmitted.
  ///
  /// In fr, this message translates to:
  /// **'Demande soumise avec succès !'**
  String get embassyRequestSubmitted;

  /// No description provided for @embassyNewRequest.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle demande'**
  String get embassyNewRequest;

  /// No description provided for @embassyReopenDate.
  ///
  /// In fr, this message translates to:
  /// **'Réouverture prévue: {date}'**
  String embassyReopenDate(String date);

  /// No description provided for @embassyContact.
  ///
  /// In fr, this message translates to:
  /// **'Contacter'**
  String get embassyContact;

  /// No description provided for @embassyRequest.
  ///
  /// In fr, this message translates to:
  /// **'Demande'**
  String get embassyRequest;

  /// No description provided for @embassyStaff.
  ///
  /// In fr, this message translates to:
  /// **'Personnel'**
  String get embassyStaff;

  /// No description provided for @embassyCall.
  ///
  /// In fr, this message translates to:
  /// **'Appeler'**
  String get embassyCall;

  /// No description provided for @embassyEmail.
  ///
  /// In fr, this message translates to:
  /// **'Email'**
  String get embassyEmail;

  /// No description provided for @embassyWebsite.
  ///
  /// In fr, this message translates to:
  /// **'Site Web'**
  String get embassyWebsite;

  /// No description provided for @embassyDirections.
  ///
  /// In fr, this message translates to:
  /// **'Y aller'**
  String get embassyDirections;

  /// No description provided for @embassyMessageSent.
  ///
  /// In fr, this message translates to:
  /// **'Message envoyé avec succès!'**
  String get embassyMessageSent;

  /// No description provided for @embassyContactTitle.
  ///
  /// In fr, this message translates to:
  /// **'Contacter l\'ambassade'**
  String get embassyContactTitle;

  /// No description provided for @embassySubjectHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex: Demande de renseignements sur le passeport'**
  String get embassySubjectHint;

  /// No description provided for @embassyMessageHint.
  ///
  /// In fr, this message translates to:
  /// **'Décrivez votre demande en détail...'**
  String get embassyMessageHint;

  /// No description provided for @embassyDepartment.
  ///
  /// In fr, this message translates to:
  /// **'Département'**
  String get embassyDepartment;

  /// No description provided for @embassyCallAction.
  ///
  /// In fr, this message translates to:
  /// **'Appeler'**
  String get embassyCallAction;

  /// No description provided for @embassyRoute.
  ///
  /// In fr, this message translates to:
  /// **'Itinéraire'**
  String get embassyRoute;

  /// No description provided for @embassyDetails.
  ///
  /// In fr, this message translates to:
  /// **'Détails'**
  String get embassyDetails;

  /// No description provided for @eventImageSelectionError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la sélection des images: {error}'**
  String eventImageSelectionError(String error);

  /// No description provided for @eventSelectImages.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionner des images'**
  String get eventSelectImages;

  /// No description provided for @eventPosterLimit.
  ///
  /// In fr, this message translates to:
  /// **'Limite de 5 affiches atteinte'**
  String get eventPosterLimit;

  /// No description provided for @eventShareRecap.
  ///
  /// In fr, this message translates to:
  /// **'Partager le récapitulatif'**
  String get eventShareRecap;

  /// No description provided for @eventPhotoLimit.
  ///
  /// In fr, this message translates to:
  /// **'Limite de 10 photos atteinte'**
  String get eventPhotoLimit;

  /// No description provided for @eventAddPhotoMin.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez ajouter au moins une photo'**
  String get eventAddPhotoMin;

  /// No description provided for @eventSelectPhotos.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionner des photos'**
  String get eventSelectPhotos;

  /// No description provided for @eventAddPhotos.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter des photos ({count}/10)'**
  String eventAddPhotos(int count);

  /// No description provided for @friendSendMessage.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer un message'**
  String get friendSendMessage;

  /// No description provided for @friendRemoveTitle.
  ///
  /// In fr, this message translates to:
  /// **'Retirer des amis'**
  String get friendRemoveTitle;

  /// No description provided for @friendRemoveAction.
  ///
  /// In fr, this message translates to:
  /// **'Retirer'**
  String get friendRemoveAction;

  /// No description provided for @friendRequestDeclined.
  ///
  /// In fr, this message translates to:
  /// **'Demande refusée'**
  String get friendRequestDeclined;

  /// No description provided for @friendDecline.
  ///
  /// In fr, this message translates to:
  /// **'Refuser'**
  String get friendDecline;

  /// No description provided for @friendRequestAccepted.
  ///
  /// In fr, this message translates to:
  /// **'Demande acceptée'**
  String get friendRequestAccepted;

  /// No description provided for @friendAccept.
  ///
  /// In fr, this message translates to:
  /// **'Accepter'**
  String get friendAccept;

  /// No description provided for @friendRequestCancelled.
  ///
  /// In fr, this message translates to:
  /// **'Demande annulée'**
  String get friendRequestCancelled;

  /// No description provided for @friendCancelRequest.
  ///
  /// In fr, this message translates to:
  /// **'Annuler la demande'**
  String get friendCancelRequest;

  /// No description provided for @groupCreateTitle.
  ///
  /// In fr, this message translates to:
  /// **'Créer un groupe'**
  String get groupCreateTitle;

  /// No description provided for @groupEditTitle.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le groupe'**
  String get groupEditTitle;

  /// No description provided for @groupPromoteAdmin.
  ///
  /// In fr, this message translates to:
  /// **'Promouvoir Admin'**
  String get groupPromoteAdmin;

  /// No description provided for @groupDemoteAdmin.
  ///
  /// In fr, this message translates to:
  /// **'Retirer Admin'**
  String get groupDemoteAdmin;

  /// No description provided for @groupConfirmAction.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer'**
  String get groupConfirmAction;

  /// No description provided for @groupMembershipRequests.
  ///
  /// In fr, this message translates to:
  /// **'Demandes d\'adhésion'**
  String get groupMembershipRequests;

  /// No description provided for @groupRejectTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Refuser'**
  String get groupRejectTooltip;

  /// No description provided for @groupApproveTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Approuver'**
  String get groupApproveTooltip;

  /// No description provided for @groupFilterAll.
  ///
  /// In fr, this message translates to:
  /// **'Tous'**
  String get groupFilterAll;

  /// No description provided for @groupFilterAllFeminine.
  ///
  /// In fr, this message translates to:
  /// **'Toutes'**
  String get groupFilterAllFeminine;

  /// No description provided for @shareWhatsApp.
  ///
  /// In fr, this message translates to:
  /// **'WhatsApp'**
  String get shareWhatsApp;

  /// No description provided for @shareFacebook.
  ///
  /// In fr, this message translates to:
  /// **'Facebook'**
  String get shareFacebook;

  /// No description provided for @shareX.
  ///
  /// In fr, this message translates to:
  /// **'X'**
  String get shareX;

  /// No description provided for @shareMore.
  ///
  /// In fr, this message translates to:
  /// **'Plus'**
  String get shareMore;

  /// No description provided for @homeMessages.
  ///
  /// In fr, this message translates to:
  /// **'Messages'**
  String get homeMessages;

  /// No description provided for @homeGroups.
  ///
  /// In fr, this message translates to:
  /// **'Groupes'**
  String get homeGroups;

  /// No description provided for @homeMarketplace.
  ///
  /// In fr, this message translates to:
  /// **'Marketplace'**
  String get homeMarketplace;

  /// No description provided for @homeTransfers.
  ///
  /// In fr, this message translates to:
  /// **'Transferts'**
  String get homeTransfers;

  /// No description provided for @homeDirectory.
  ///
  /// In fr, this message translates to:
  /// **'Annuaire'**
  String get homeDirectory;

  /// No description provided for @mapEnable.
  ///
  /// In fr, this message translates to:
  /// **'ACTIVER'**
  String get mapEnable;

  /// No description provided for @mapTestTitle.
  ///
  /// In fr, this message translates to:
  /// **'Test Carte Simple'**
  String get mapTestTitle;

  /// No description provided for @marketplaceAddImageMin.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez au moins une image'**
  String get marketplaceAddImageMin;

  /// No description provided for @marketplaceCustomTaxRate.
  ///
  /// In fr, this message translates to:
  /// **'Taux personnalisé (%)'**
  String get marketplaceCustomTaxRate;

  /// No description provided for @marketplaceCustomTaxHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex: 15'**
  String get marketplaceCustomTaxHint;

  /// No description provided for @marketplacePriceTTC.
  ///
  /// In fr, this message translates to:
  /// **'Prix TTC'**
  String get marketplacePriceTTC;

  /// No description provided for @marketplaceSubtotal.
  ///
  /// In fr, this message translates to:
  /// **'Sous-total'**
  String get marketplaceSubtotal;

  /// No description provided for @marketplaceTaxRate.
  ///
  /// In fr, this message translates to:
  /// **'Taxe ({rate}%)'**
  String marketplaceTaxRate(String rate);

  /// No description provided for @marketplaceTitleLabel.
  ///
  /// In fr, this message translates to:
  /// **'Titre'**
  String get marketplaceTitleLabel;

  /// No description provided for @marketplaceTitleHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex: iPhone 13 Pro Max'**
  String get marketplaceTitleHint;

  /// No description provided for @marketplaceDescriptionLabel.
  ///
  /// In fr, this message translates to:
  /// **'Description'**
  String get marketplaceDescriptionLabel;

  /// No description provided for @marketplaceDescriptionHint.
  ///
  /// In fr, this message translates to:
  /// **'Décrivez votre produit...'**
  String get marketplaceDescriptionHint;

  /// No description provided for @marketplacePriceLabel.
  ///
  /// In fr, this message translates to:
  /// **'Prix'**
  String get marketplacePriceLabel;

  /// No description provided for @marketplaceQuantityLabel.
  ///
  /// In fr, this message translates to:
  /// **'Quantité'**
  String get marketplaceQuantityLabel;

  /// No description provided for @marketplaceCurrencyLabel.
  ///
  /// In fr, this message translates to:
  /// **'Devise'**
  String get marketplaceCurrencyLabel;

  /// No description provided for @marketplaceCategoryLabel.
  ///
  /// In fr, this message translates to:
  /// **'Catégorie'**
  String get marketplaceCategoryLabel;

  /// No description provided for @marketplaceConditionLabel.
  ///
  /// In fr, this message translates to:
  /// **'État'**
  String get marketplaceConditionLabel;

  /// No description provided for @marketplaceCountryLabel.
  ///
  /// In fr, this message translates to:
  /// **'Pays'**
  String get marketplaceCountryLabel;

  /// No description provided for @marketplaceCityLabel.
  ///
  /// In fr, this message translates to:
  /// **'Ville/Adresse (optionnel)'**
  String get marketplaceCityLabel;

  /// No description provided for @marketplaceCityHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex: Niamey'**
  String get marketplaceCityHint;

  /// No description provided for @marketplaceAllCategory.
  ///
  /// In fr, this message translates to:
  /// **'Tout'**
  String get marketplaceAllCategory;

  /// No description provided for @marketplaceMyOrders.
  ///
  /// In fr, this message translates to:
  /// **'Mes commandes'**
  String get marketplaceMyOrders;

  /// No description provided for @marketplaceDiscoverProducts.
  ///
  /// In fr, this message translates to:
  /// **'Découvrir les produits'**
  String get marketplaceDiscoverProducts;

  /// No description provided for @marketplacePaymentSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Paiement effectué avec succès !'**
  String get marketplacePaymentSuccess;

  /// No description provided for @marketplaceOrderUpdateError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la mise à jour de la commande'**
  String get marketplaceOrderUpdateError;

  /// No description provided for @marketplacePaymentError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur de paiement: {error}'**
  String marketplacePaymentError(String error);

  /// No description provided for @marketplaceDeliveryConfirmed.
  ///
  /// In fr, this message translates to:
  /// **'Livraison confirmée'**
  String get marketplaceDeliveryConfirmed;

  /// No description provided for @marketplaceMarkedAsShipped.
  ///
  /// In fr, this message translates to:
  /// **'Commande marquée comme expédiée'**
  String get marketplaceMarkedAsShipped;

  /// No description provided for @marketplaceTrackingNumber.
  ///
  /// In fr, this message translates to:
  /// **'Numéro de suivi'**
  String get marketplaceTrackingNumber;

  /// No description provided for @marketplaceTrackingHint.
  ///
  /// In fr, this message translates to:
  /// **'Entrez le numéro de suivi (optionnel)'**
  String get marketplaceTrackingHint;

  /// No description provided for @marketplaceLoadingLabel.
  ///
  /// In fr, this message translates to:
  /// **'Chargement...'**
  String get marketplaceLoadingLabel;

  /// No description provided for @marketplaceViewsLabel.
  ///
  /// In fr, this message translates to:
  /// **'vues'**
  String get marketplaceViewsLabel;

  /// No description provided for @marketplacePublishedLabel.
  ///
  /// In fr, this message translates to:
  /// **'publié'**
  String get marketplacePublishedLabel;

  /// No description provided for @marketplaceAddedToCart.
  ///
  /// In fr, this message translates to:
  /// **'Ajouté au panier'**
  String get marketplaceAddedToCart;

  /// No description provided for @marketplaceViewCart.
  ///
  /// In fr, this message translates to:
  /// **'Voir'**
  String get marketplaceViewCart;

  /// No description provided for @marketplaceAddToCart.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter au panier'**
  String get marketplaceAddToCart;

  /// No description provided for @marketplaceDeleteProduct.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le produit'**
  String get marketplaceDeleteProduct;

  /// No description provided for @marketplaceConversationError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la création de la conversation'**
  String get marketplaceConversationError;

  /// No description provided for @messageVideoPlayError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur de lecture de la vidéo'**
  String get messageVideoPlayError;

  /// No description provided for @messageVideoSaved.
  ///
  /// In fr, this message translates to:
  /// **'Vidéo enregistrée dans la galerie'**
  String get messageVideoSaved;

  /// No description provided for @messageVideoSaveError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de l\'enregistrement'**
  String get messageVideoSaveError;

  /// No description provided for @messageInfo.
  ///
  /// In fr, this message translates to:
  /// **'Info'**
  String get messageInfo;

  /// No description provided for @messageBackgroundError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la sélection de l\'image: {error}'**
  String messageBackgroundError(String error);

  /// No description provided for @messageBackgroundApplyError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de l\'application: {error}'**
  String messageBackgroundApplyError(String error);

  /// No description provided for @messagePhotosCount.
  ///
  /// In fr, this message translates to:
  /// **'Photos ({count})'**
  String messagePhotosCount(int count);

  /// No description provided for @messageFilesCount.
  ///
  /// In fr, this message translates to:
  /// **'Fichiers ({count})'**
  String messageFilesCount(int count);

  /// No description provided for @messageLocationSearchHint.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un lieu...'**
  String get messageLocationSearchHint;

  /// No description provided for @messageLocationError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'obtenir la position'**
  String get messageLocationError;

  /// No description provided for @messageSendThisPosition.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer cette position'**
  String get messageSendThisPosition;

  /// No description provided for @fileLabel.
  ///
  /// In fr, this message translates to:
  /// **'Fichier'**
  String get fileLabel;

  /// No description provided for @messageTypeAudio.
  ///
  /// In fr, this message translates to:
  /// **'🎵 Audio'**
  String get messageTypeAudio;

  /// No description provided for @messageTypeVoiceNote.
  ///
  /// In fr, this message translates to:
  /// **'Note vocale'**
  String get messageTypeVoiceNote;

  /// No description provided for @shareError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de partager ce contenu'**
  String get shareError;

  /// No description provided for @shareDownloadingMedia.
  ///
  /// In fr, this message translates to:
  /// **'Préparation du média...'**
  String get shareDownloadingMedia;

  /// No description provided for @messageInfoTitle.
  ///
  /// In fr, this message translates to:
  /// **'Infos du message'**
  String get messageInfoTitle;

  /// No description provided for @messageSentAt.
  ///
  /// In fr, this message translates to:
  /// **'Envoyé · {time}'**
  String messageSentAt(String time);

  /// No description provided for @tabReadBy.
  ///
  /// In fr, this message translates to:
  /// **'Lu · {n}'**
  String tabReadBy(int n);

  /// No description provided for @tabDeliveredTo.
  ///
  /// In fr, this message translates to:
  /// **'Reçu · {n}'**
  String tabDeliveredTo(int n);

  /// No description provided for @tabReactions.
  ///
  /// In fr, this message translates to:
  /// **'Réactions · {n}'**
  String tabReactions(int n);

  /// No description provided for @allReactions.
  ///
  /// In fr, this message translates to:
  /// **'Tous'**
  String get allReactions;

  /// No description provided for @noReactionsYet.
  ///
  /// In fr, this message translates to:
  /// **'Aucune réaction pour l\'instant'**
  String get noReactionsYet;

  /// No description provided for @notReadYet.
  ///
  /// In fr, this message translates to:
  /// **'Aucun membre n\'a encore lu ce message'**
  String get notReadYet;

  /// No description provided for @notDeliveredYet.
  ///
  /// In fr, this message translates to:
  /// **'Pas encore reçu'**
  String get notDeliveredYet;

  /// No description provided for @documentPDF.
  ///
  /// In fr, this message translates to:
  /// **'PDF'**
  String get documentPDF;

  /// No description provided for @documentDOC.
  ///
  /// In fr, this message translates to:
  /// **'DOC'**
  String get documentDOC;

  /// No description provided for @documentXLS.
  ///
  /// In fr, this message translates to:
  /// **'XLS'**
  String get documentXLS;

  /// No description provided for @documentPPT.
  ///
  /// In fr, this message translates to:
  /// **'PPT'**
  String get documentPPT;

  /// No description provided for @documentZIP.
  ///
  /// In fr, this message translates to:
  /// **'ZIP'**
  String get documentZIP;

  /// No description provided for @documentTXT.
  ///
  /// In fr, this message translates to:
  /// **'TXT'**
  String get documentTXT;

  /// No description provided for @documentCSV.
  ///
  /// In fr, this message translates to:
  /// **'CSV'**
  String get documentCSV;

  /// No description provided for @documentJSON.
  ///
  /// In fr, this message translates to:
  /// **'JSON'**
  String get documentJSON;

  /// No description provided for @notificationIn1Hour.
  ///
  /// In fr, this message translates to:
  /// **'Dans 1 heure'**
  String get notificationIn1Hour;

  /// No description provided for @notificationTomorrowMorning.
  ///
  /// In fr, this message translates to:
  /// **'Demain matin (9h)'**
  String get notificationTomorrowMorning;

  /// No description provided for @notificationReminderScheduled.
  ///
  /// In fr, this message translates to:
  /// **'Rappel programmé'**
  String get notificationReminderScheduled;

  /// No description provided for @paymentBankHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex: BCEAO, Ecobank...'**
  String get paymentBankHint;

  /// No description provided for @paymentIbanHint.
  ///
  /// In fr, this message translates to:
  /// **'NEXX XXXX XXXX XXXX'**
  String get paymentIbanHint;

  /// No description provided for @podcastTitleLabel.
  ///
  /// In fr, this message translates to:
  /// **'Titre du podcast *'**
  String get podcastTitleLabel;

  /// No description provided for @podcastDescriptionLabel.
  ///
  /// In fr, this message translates to:
  /// **'Description'**
  String get podcastDescriptionLabel;

  /// No description provided for @podcastCategoryLabel.
  ///
  /// In fr, this message translates to:
  /// **'Catégorie *'**
  String get podcastCategoryLabel;

  /// No description provided for @podcastLanguageLabel.
  ///
  /// In fr, this message translates to:
  /// **'Langue *'**
  String get podcastLanguageLabel;

  /// No description provided for @podcastFrequencyLabel.
  ///
  /// In fr, this message translates to:
  /// **'Fréquence de publication'**
  String get podcastFrequencyLabel;

  /// No description provided for @podcastTagsLabel.
  ///
  /// In fr, this message translates to:
  /// **'Tags'**
  String get podcastTagsLabel;

  /// No description provided for @podcastTagsHint.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un tag'**
  String get podcastTagsHint;

  /// No description provided for @podcastLike.
  ///
  /// In fr, this message translates to:
  /// **'J\'aime'**
  String get podcastLike;

  /// No description provided for @podcastSleepTimerDisabled.
  ///
  /// In fr, this message translates to:
  /// **'Désactivé'**
  String get podcastSleepTimerDisabled;

  /// No description provided for @podcastEpisodeEnd.
  ///
  /// In fr, this message translates to:
  /// **'Fin de l\'épisode'**
  String get podcastEpisodeEnd;

  /// No description provided for @podcastSleepTimerEnabled.
  ///
  /// In fr, this message translates to:
  /// **'Arrêt à la fin de l\'épisode activé'**
  String get podcastSleepTimerEnabled;

  /// No description provided for @podcastSleepTimerEnded.
  ///
  /// In fr, this message translates to:
  /// **'Minuterie de sommeil terminée'**
  String get podcastSleepTimerEnded;

  /// No description provided for @podcastTimerMinutes.
  ///
  /// In fr, this message translates to:
  /// **'Minuterie: {minutes} minutes'**
  String podcastTimerMinutes(int minutes);

  /// No description provided for @podcastAddChapter.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un chapitre'**
  String get podcastAddChapter;

  /// No description provided for @podcastChapterTitle.
  ///
  /// In fr, this message translates to:
  /// **'Titre du chapitre'**
  String get podcastChapterTitle;

  /// No description provided for @podcastMinutes.
  ///
  /// In fr, this message translates to:
  /// **'Minutes'**
  String get podcastMinutes;

  /// No description provided for @podcastSeconds.
  ///
  /// In fr, this message translates to:
  /// **'Secondes'**
  String get podcastSeconds;

  /// No description provided for @podcastSelectAudioFile.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez sélectionner un fichier audio'**
  String get podcastSelectAudioFile;

  /// No description provided for @podcastNewEpisode.
  ///
  /// In fr, this message translates to:
  /// **'Nouvel épisode'**
  String get podcastNewEpisode;

  /// No description provided for @podcastEpisodeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Titre de l\'épisode *'**
  String get podcastEpisodeTitle;

  /// No description provided for @podcastEpisodeNotes.
  ///
  /// In fr, this message translates to:
  /// **'Description / Notes'**
  String get podcastEpisodeNotes;

  /// No description provided for @podcastPremiumOnly.
  ///
  /// In fr, this message translates to:
  /// **'Réservé aux abonnés payants'**
  String get podcastPremiumOnly;

  /// No description provided for @podcastDownloaded.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargé'**
  String get podcastDownloaded;

  /// No description provided for @podcastDownload.
  ///
  /// In fr, this message translates to:
  /// **'Télécharger'**
  String get podcastDownload;

  /// No description provided for @podcastDeleteDownload.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le téléchargement'**
  String get podcastDeleteDownload;

  /// No description provided for @podcastDownloadRemoved.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargement supprimé'**
  String get podcastDownloadRemoved;

  /// No description provided for @podcastSelectOrCreate.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionnez un podcast ou créez-en un nouveau'**
  String get podcastSelectOrCreate;

  /// No description provided for @podcastRecordingComingSoon.
  ///
  /// In fr, this message translates to:
  /// **'L\'enregistrement du salon sera bientôt disponible'**
  String get podcastRecordingComingSoon;

  /// No description provided for @podcastAudioNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Fichier audio introuvable'**
  String get podcastAudioNotFound;

  /// No description provided for @podcastPublishError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la publication'**
  String get podcastPublishError;

  /// No description provided for @podcastEpisodeTitleHint.
  ///
  /// In fr, this message translates to:
  /// **'Titre de l\'épisode'**
  String get podcastEpisodeTitleHint;

  /// No description provided for @podcastEpisodeDescriptionHint.
  ///
  /// In fr, this message translates to:
  /// **'Description de l\'épisode (optionnel)'**
  String get podcastEpisodeDescriptionHint;

  /// No description provided for @podcastPublish.
  ///
  /// In fr, this message translates to:
  /// **'Publier'**
  String get podcastPublish;

  /// No description provided for @podcastCreateNew.
  ///
  /// In fr, this message translates to:
  /// **'Créer un podcast'**
  String get podcastCreateNew;

  /// No description provided for @profileSpecifyProfession.
  ///
  /// In fr, this message translates to:
  /// **'Précisez votre profession'**
  String get profileSpecifyProfession;

  /// No description provided for @profileSpecifyCountry.
  ///
  /// In fr, this message translates to:
  /// **'Ou saisissez votre pays'**
  String get profileSpecifyCountry;

  /// No description provided for @profileRegion.
  ///
  /// In fr, this message translates to:
  /// **'Région'**
  String get profileRegion;

  /// No description provided for @profileOriginCity.
  ///
  /// In fr, this message translates to:
  /// **'Ville d\'origine'**
  String get profileOriginCity;

  /// No description provided for @profileSpecifyOriginCity.
  ///
  /// In fr, this message translates to:
  /// **'Précisez votre ville d\'origine'**
  String get profileSpecifyOriginCity;

  /// No description provided for @profilePhoneVerified.
  ///
  /// In fr, this message translates to:
  /// **'Numéro vérifié avec succès !'**
  String get profilePhoneVerified;

  /// No description provided for @profileCodeSent.
  ///
  /// In fr, this message translates to:
  /// **'Code envoyé au {phone}'**
  String profileCodeSent(String phone);

  /// No description provided for @profileConfigTitle.
  ///
  /// In fr, this message translates to:
  /// **'Configuration du profil'**
  String get profileConfigTitle;

  /// No description provided for @profilePrevious.
  ///
  /// In fr, this message translates to:
  /// **'Précédent'**
  String get profilePrevious;

  /// No description provided for @profileFullNameLabel.
  ///
  /// In fr, this message translates to:
  /// **'Nom complet'**
  String get profileFullNameLabel;

  /// No description provided for @profileFullNameHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex: Jean Dupont'**
  String get profileFullNameHint;

  /// No description provided for @profileProfessionLabel.
  ///
  /// In fr, this message translates to:
  /// **'Profession'**
  String get profileProfessionLabel;

  /// No description provided for @profileProfessionHint.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionnez votre profession'**
  String get profileProfessionHint;

  /// No description provided for @profileCurrentCityLabel.
  ///
  /// In fr, this message translates to:
  /// **'Ville actuelle'**
  String get profileCurrentCityLabel;

  /// No description provided for @profileCurrentCityHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex: Paris, Niamey, New York...'**
  String get profileCurrentCityHint;

  /// No description provided for @profileOriginCityHint.
  ///
  /// In fr, this message translates to:
  /// **'Votre ville...'**
  String get profileOriginCityHint;

  /// No description provided for @profileShareLocation.
  ///
  /// In fr, this message translates to:
  /// **'Partager ma localisation'**
  String get profileShareLocation;

  /// No description provided for @profileEnableNotifications.
  ///
  /// In fr, this message translates to:
  /// **'Activer les notifications'**
  String get profileEnableNotifications;

  /// No description provided for @profileReceiveAllNotifications.
  ///
  /// In fr, this message translates to:
  /// **'Recevoir toutes les notifications'**
  String get profileReceiveAllNotifications;

  /// No description provided for @profileNewEventsInCity.
  ///
  /// In fr, this message translates to:
  /// **'Nouveaux événements dans votre ville'**
  String get profileNewEventsInCity;

  /// No description provided for @profileMessagesNotifications.
  ///
  /// In fr, this message translates to:
  /// **'Messages'**
  String get profileMessagesNotifications;

  /// No description provided for @profileNewMessagesNotifications.
  ///
  /// In fr, this message translates to:
  /// **'Nouveaux messages et conversations'**
  String get profileNewMessagesNotifications;

  /// No description provided for @profileCurrentCountryLabel.
  ///
  /// In fr, this message translates to:
  /// **'Pays actuel'**
  String get profileCurrentCountryLabel;

  /// No description provided for @profileSelectCountry.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionnez votre pays'**
  String get profileSelectCountry;

  /// No description provided for @profileOriginRegionLabel.
  ///
  /// In fr, this message translates to:
  /// **'Région d\'origine'**
  String get profileOriginRegionLabel;

  /// No description provided for @profileSelectRegion.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionnez votre région'**
  String get profileSelectRegion;

  /// No description provided for @profileOriginCityLabel.
  ///
  /// In fr, this message translates to:
  /// **'Ville d\'origine'**
  String get profileOriginCityLabel;

  /// No description provided for @profileSelectCity.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionnez votre ville'**
  String get profileSelectCity;

  /// No description provided for @profileLocationDenied.
  ///
  /// In fr, this message translates to:
  /// **'Permission de localisation refusée'**
  String get profileLocationDenied;

  /// No description provided for @profileCannotChatDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de discuter avec un utilisateur supprimé'**
  String get profileCannotChatDeleted;

  /// No description provided for @profileCannotCall.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'appeler cet utilisateur'**
  String get profileCannotCall;

  /// No description provided for @profileBlockUser.
  ///
  /// In fr, this message translates to:
  /// **'Bloquer l\'utilisateur'**
  String get profileBlockUser;

  /// No description provided for @profileTravelMode.
  ///
  /// In fr, this message translates to:
  /// **'Mode Voyage'**
  String get profileTravelMode;

  /// No description provided for @profileAudioCall.
  ///
  /// In fr, this message translates to:
  /// **'Audio'**
  String get profileAudioCall;

  /// No description provided for @profileVideoCall.
  ///
  /// In fr, this message translates to:
  /// **'Vidéo'**
  String get profileVideoCall;

  /// No description provided for @profileRequestCancelled.
  ///
  /// In fr, this message translates to:
  /// **'Demande d\'ami annulée'**
  String get profileRequestCancelled;

  /// No description provided for @profileRequestNotExist.
  ///
  /// In fr, this message translates to:
  /// **'Cette demande n\'existe plus.'**
  String get profileRequestNotExist;

  /// No description provided for @profileCancelRequestAction.
  ///
  /// In fr, this message translates to:
  /// **'Annuler la demande'**
  String get profileCancelRequestAction;

  /// No description provided for @profileRequestDeclined.
  ///
  /// In fr, this message translates to:
  /// **'Demande d\'ami refusée'**
  String get profileRequestDeclined;

  /// No description provided for @profileDeclineAction.
  ///
  /// In fr, this message translates to:
  /// **'Refuser'**
  String get profileDeclineAction;

  /// No description provided for @profileRequestAccepted.
  ///
  /// In fr, this message translates to:
  /// **'Demande d\'ami acceptée'**
  String get profileRequestAccepted;

  /// No description provided for @profileAcceptAction.
  ///
  /// In fr, this message translates to:
  /// **'Accepter'**
  String get profileAcceptAction;

  /// No description provided for @profileQRScanned.
  ///
  /// In fr, this message translates to:
  /// **'QR code scanné avec succès'**
  String get profileQRScanned;

  /// No description provided for @reportMyReports.
  ///
  /// In fr, this message translates to:
  /// **'Mes signalements'**
  String get reportMyReports;

  /// No description provided for @reportDescribeIssue.
  ///
  /// In fr, this message translates to:
  /// **'Décrivez le problème...'**
  String get reportDescribeIssue;

  /// No description provided for @reportSendReport.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer le signalement'**
  String get reportSendReport;

  /// No description provided for @settingsRenameDevice.
  ///
  /// In fr, this message translates to:
  /// **'Renommer l\'appareil'**
  String get settingsRenameDevice;

  /// No description provided for @settingsDeviceName.
  ///
  /// In fr, this message translates to:
  /// **'Nom de l\'appareil'**
  String get settingsDeviceName;

  /// No description provided for @settingsRenameAction.
  ///
  /// In fr, this message translates to:
  /// **'Renommer'**
  String get settingsRenameAction;

  /// No description provided for @settingsRevokeDevice.
  ///
  /// In fr, this message translates to:
  /// **'Révoquer l\'appareil ?'**
  String get settingsRevokeDevice;

  /// No description provided for @settingsRevokeAction.
  ///
  /// In fr, this message translates to:
  /// **'Révoquer'**
  String get settingsRevokeAction;

  /// No description provided for @settingsConnectedDevices.
  ///
  /// In fr, this message translates to:
  /// **'Appareils connectés'**
  String get settingsConnectedDevices;

  /// No description provided for @settingsDeleteBackup.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer la sauvegarde ?'**
  String get settingsDeleteBackup;

  /// No description provided for @settingsKeyBackup.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarde des clés'**
  String get settingsKeyBackup;

  /// No description provided for @settingsPassphraseLabel.
  ///
  /// In fr, this message translates to:
  /// **'Passphrase'**
  String get settingsPassphraseLabel;

  /// No description provided for @settingsRestoreKeys.
  ///
  /// In fr, this message translates to:
  /// **'Restaurer les clés'**
  String get settingsRestoreKeys;

  /// No description provided for @settingsGeneratePassphrase.
  ///
  /// In fr, this message translates to:
  /// **'Générer une passphrase sécurisée'**
  String get settingsGeneratePassphrase;

  /// No description provided for @settingsPassphraseHint.
  ///
  /// In fr, this message translates to:
  /// **'Minimum 8 caractères'**
  String get settingsPassphraseHint;

  /// No description provided for @settingsConfirmPassphrase.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer la passphrase'**
  String get settingsConfirmPassphrase;

  /// No description provided for @settingsCreateBackup.
  ///
  /// In fr, this message translates to:
  /// **'Créer la sauvegarde'**
  String get settingsCreateBackup;

  /// No description provided for @settingsTermsOfService.
  ///
  /// In fr, this message translates to:
  /// **'Conditions d\'utilisation'**
  String get settingsTermsOfService;

  /// No description provided for @settingsBugDescriptionLabel.
  ///
  /// In fr, this message translates to:
  /// **'Description du bug'**
  String get settingsBugDescriptionLabel;

  /// No description provided for @settingsBugDescriptionHint.
  ///
  /// In fr, this message translates to:
  /// **'Décrivez le problème rencontré...'**
  String get settingsBugDescriptionHint;

  /// No description provided for @settingsCurrencySearchHint.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher une devise...'**
  String get settingsCurrencySearchHint;

  /// No description provided for @transferFullNameLabel.
  ///
  /// In fr, this message translates to:
  /// **'Nom complet *'**
  String get transferFullNameLabel;

  /// No description provided for @transferFullNameHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex: Amadou Boubacar'**
  String get transferFullNameHint;

  /// No description provided for @transferPhoneLabel.
  ///
  /// In fr, this message translates to:
  /// **'Numéro de téléphone *'**
  String get transferPhoneLabel;

  /// No description provided for @transferEmailOptional.
  ///
  /// In fr, this message translates to:
  /// **'Email (optionnel)'**
  String get transferEmailOptional;

  /// No description provided for @transferEmailHint.
  ///
  /// In fr, this message translates to:
  /// **'exemple@email.com'**
  String get transferEmailHint;

  /// No description provided for @transferCardNameLabel.
  ///
  /// In fr, this message translates to:
  /// **'Nom sur la carte *'**
  String get transferCardNameLabel;

  /// No description provided for @transferCardNameHint.
  ///
  /// In fr, this message translates to:
  /// **'JEAN DUPONT'**
  String get transferCardNameHint;

  /// No description provided for @transferChangeCard.
  ///
  /// In fr, this message translates to:
  /// **'Changer'**
  String get transferChangeCard;

  /// No description provided for @transferCardInfoLabel.
  ///
  /// In fr, this message translates to:
  /// **'Informations de carte *'**
  String get transferCardInfoLabel;

  /// No description provided for @transferCountryLabel.
  ///
  /// In fr, this message translates to:
  /// **'Pays'**
  String get transferCountryLabel;

  /// No description provided for @transferCityLabel.
  ///
  /// In fr, this message translates to:
  /// **'Ville'**
  String get transferCityLabel;

  /// No description provided for @transferAddressOptional.
  ///
  /// In fr, this message translates to:
  /// **'Adresse (optionnel)'**
  String get transferAddressOptional;

  /// No description provided for @transferAddressHint.
  ///
  /// In fr, this message translates to:
  /// **'Quartier, rue...'**
  String get transferAddressHint;

  /// No description provided for @transferAddToFavorites.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter aux favoris'**
  String get transferAddToFavorites;

  /// No description provided for @transferFavoritesSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Accès rapide lors des prochains transferts'**
  String get transferFavoritesSubtitle;

  /// No description provided for @transferEnterCardInfo.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez saisir les informations de carte complètes'**
  String get transferEnterCardInfo;

  /// No description provided for @transferDeleteRecipient.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le bénéficiaire ?'**
  String get transferDeleteRecipient;

  /// No description provided for @transferRecipientDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Bénéficiaire supprimé'**
  String get transferRecipientDeleted;

  /// No description provided for @transferNewRecipient.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau'**
  String get transferNewRecipient;

  /// No description provided for @transferAddManually.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter manuellement'**
  String get transferAddManually;

  /// No description provided for @transferChooseRecipient.
  ///
  /// In fr, this message translates to:
  /// **'Choisir un bénéficiaire'**
  String get transferChooseRecipient;

  /// No description provided for @transferAddRecipientTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un bénéficiaire'**
  String get transferAddRecipientTooltip;

  /// No description provided for @transferEditRecipient.
  ///
  /// In fr, this message translates to:
  /// **'Modifier'**
  String get transferEditRecipient;

  /// No description provided for @transferDeleteConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer {name} ?'**
  String transferDeleteConfirm(String name);

  /// No description provided for @transferAccountNumber.
  ///
  /// In fr, this message translates to:
  /// **'Numéro de compte / IBAN *'**
  String get transferAccountNumber;

  /// No description provided for @transferAccountHint.
  ///
  /// In fr, this message translates to:
  /// **'XXXX XXXX XXXX XXXX'**
  String get transferAccountHint;

  /// No description provided for @transferCurrencyLabel.
  ///
  /// In fr, this message translates to:
  /// **'Devise'**
  String get transferCurrencyLabel;

  /// No description provided for @transferMessageTitle.
  ///
  /// In fr, this message translates to:
  /// **'Message'**
  String get transferMessageTitle;

  /// No description provided for @transferSelectRecipient.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionnez un bénéficiaire'**
  String get transferSelectRecipient;

  /// No description provided for @transferTotal.
  ///
  /// In fr, this message translates to:
  /// **'Total :'**
  String get transferTotal;

  /// No description provided for @transferDebitInProgress.
  ///
  /// In fr, this message translates to:
  /// **'Débit {provider} en cours...'**
  String transferDebitInProgress(String provider);

  /// No description provided for @transferDetails.
  ///
  /// In fr, this message translates to:
  /// **'Détails du transfert'**
  String get transferDetails;

  /// No description provided for @transferAmountSentLabel.
  ///
  /// In fr, this message translates to:
  /// **'Montant envoyé'**
  String get transferAmountSentLabel;

  /// No description provided for @transferCopied.
  ///
  /// In fr, this message translates to:
  /// **'Copié dans le presse-papiers'**
  String get transferCopied;

  /// No description provided for @transferRetry.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer le transfert'**
  String get transferRetry;

  /// No description provided for @transferContactSupport.
  ///
  /// In fr, this message translates to:
  /// **'Contacter le support'**
  String get transferContactSupport;

  /// No description provided for @transferHistory.
  ///
  /// In fr, this message translates to:
  /// **'Historique des transferts'**
  String get transferHistory;

  /// No description provided for @transferSendAction.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer'**
  String get transferSendAction;

  /// No description provided for @transferActiveFilters.
  ///
  /// In fr, this message translates to:
  /// **'Filtres actifs: '**
  String get transferActiveFilters;

  /// No description provided for @transferClearAll.
  ///
  /// In fr, this message translates to:
  /// **'Effacer tout'**
  String get transferClearAll;

  /// No description provided for @transferSendMoney2.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer de l\'argent'**
  String get transferSendMoney2;

  /// No description provided for @transferChoosePeriod.
  ///
  /// In fr, this message translates to:
  /// **'Choisir une période'**
  String get transferChoosePeriod;

  /// No description provided for @transferApplyFilters.
  ///
  /// In fr, this message translates to:
  /// **'Appliquer les filtres'**
  String get transferApplyFilters;

  /// No description provided for @transferTitle.
  ///
  /// In fr, this message translates to:
  /// **'Transferts'**
  String get transferTitle;

  /// No description provided for @transferRecipientsTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Bénéficiaires'**
  String get transferRecipientsTooltip;

  /// No description provided for @transferHistoryTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Historique'**
  String get transferHistoryTooltip;

  /// No description provided for @transferSendMoneyDescription.
  ///
  /// In fr, this message translates to:
  /// **'Transférez de l\'argent vers le Niger en quelques clics'**
  String get transferSendMoneyDescription;

  /// No description provided for @transferRecentTransactions.
  ///
  /// In fr, this message translates to:
  /// **'Transactions récentes'**
  String get transferRecentTransactions;

  /// No description provided for @transferNoTransactions.
  ///
  /// In fr, this message translates to:
  /// **'Aucune transaction'**
  String get transferNoTransactions;

  /// No description provided for @transferTransactionsWillAppear.
  ///
  /// In fr, this message translates to:
  /// **'Vos transferts apparaîtront ici'**
  String get transferTransactionsWillAppear;

  /// No description provided for @transferSend.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer'**
  String get transferSend;

  /// No description provided for @personalInfo.
  ///
  /// In fr, this message translates to:
  /// **'Informations personnelles'**
  String get personalInfo;

  /// No description provided for @recipientTypeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mode de réception'**
  String get recipientTypeTitle;

  /// No description provided for @paymentDetailsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Détails de paiement'**
  String get paymentDetailsTitle;

  /// No description provided for @locationTitle.
  ///
  /// In fr, this message translates to:
  /// **'Localisation'**
  String get locationTitle;

  /// No description provided for @mobileTransferInfo.
  ///
  /// In fr, this message translates to:
  /// **'Le transfert sera effectué via {service} sur le numéro de téléphone du bénéficiaire.'**
  String mobileTransferInfo(String service);

  /// No description provided for @cashPickupInfo.
  ///
  /// In fr, this message translates to:
  /// **'Le bénéficiaire pourra retirer l\'argent dans un point de service NITA avec une pièce d\'identité.'**
  String get cashPickupInfo;

  /// No description provided for @addRecipientButton.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter le bénéficiaire'**
  String get addRecipientButton;

  /// No description provided for @recipientModified.
  ///
  /// In fr, this message translates to:
  /// **'Bénéficiaire modifié avec succès'**
  String get recipientModified;

  /// No description provided for @recipientAdded.
  ///
  /// In fr, this message translates to:
  /// **'Bénéficiaire ajouté avec succès'**
  String get recipientAdded;

  /// No description provided for @supportEmailTitle.
  ///
  /// In fr, this message translates to:
  /// **'Email'**
  String get supportEmailTitle;

  /// No description provided for @supportLiveChat.
  ///
  /// In fr, this message translates to:
  /// **'Chat en direct'**
  String get supportLiveChat;

  /// No description provided for @supportAvailable247.
  ///
  /// In fr, this message translates to:
  /// **'Disponible 24/7'**
  String get supportAvailable247;

  /// No description provided for @supportChatUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Chat non disponible pour le moment'**
  String get supportChatUnavailable;

  /// No description provided for @supportPhone.
  ///
  /// In fr, this message translates to:
  /// **'Téléphone'**
  String get supportPhone;

  /// No description provided for @imagePickerCamera.
  ///
  /// In fr, this message translates to:
  /// **'Caméra'**
  String get imagePickerCamera;

  /// No description provided for @imagePickerGallery.
  ///
  /// In fr, this message translates to:
  /// **'Galerie'**
  String get imagePickerGallery;

  /// No description provided for @notificationEnableDescription.
  ///
  /// In fr, this message translates to:
  /// **'Recevez des alertes lorsque vous avez de nouveaux messages, appels entrants ou activités importantes.\n\nVous pouvez modifier ce paramètre à tout moment.'**
  String get notificationEnableDescription;

  /// No description provided for @notificationDisabledDescription.
  ///
  /// In fr, this message translates to:
  /// **'Les notifications sont désactivées. Vous ne recevrez pas d\'alertes pour les nouveaux messages et appels.\n\nPour les activer, allez dans les paramètres de l\'application.'**
  String get notificationDisabledDescription;

  /// No description provided for @notificationBlockedDescription.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez bloqué les notifications pour cette application.\n\nPour recevoir des notifications de nouveaux messages et appels, vous devez les activer manuellement dans les paramètres système.'**
  String get notificationBlockedDescription;

  /// No description provided for @installFromPlayStore.
  ///
  /// In fr, this message translates to:
  /// **'Pour accéder à cette fonctionnalité, veuillez installer l\'application depuis Google Play Store.'**
  String get installFromPlayStore;

  /// No description provided for @accessRestricted.
  ///
  /// In fr, this message translates to:
  /// **'Accès restreint'**
  String get accessRestricted;

  /// No description provided for @securityCheckFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de vérifier la sécurité: {error}'**
  String securityCheckFailed(String error);

  /// No description provided for @deviceBasicSecurityFailed.
  ///
  /// In fr, this message translates to:
  /// **'Cet appareil ne répond pas aux exigences de sécurité de base.'**
  String get deviceBasicSecurityFailed;

  /// No description provided for @deviceSecurityFailed.
  ///
  /// In fr, this message translates to:
  /// **'Cet appareil ne répond pas aux exigences de sécurité.'**
  String get deviceSecurityFailed;

  /// No description provided for @playStoreRequired.
  ///
  /// In fr, this message translates to:
  /// **'Cette fonctionnalité nécessite l\'installation depuis Google Play Store.'**
  String get playStoreRequired;

  /// No description provided for @highSecurityFailed.
  ///
  /// In fr, this message translates to:
  /// **'Cet appareil ne répond pas aux exigences de sécurité élevées.'**
  String get highSecurityFailed;

  /// No description provided for @signedInElsewhere.
  ///
  /// In fr, this message translates to:
  /// **'Connecté ailleurs'**
  String get signedInElsewhere;

  /// No description provided for @signedInElsewhereDescription.
  ///
  /// In fr, this message translates to:
  /// **'Votre compte a été connecté sur un autre appareil. Vous avez été déconnecté de cet appareil pour sécurité.'**
  String get signedInElsewhereDescription;

  /// No description provided for @cameraPermissionRestricted.
  ///
  /// In fr, this message translates to:
  /// **'L\'accès à la caméra est restreint sur cet appareil.'**
  String get cameraPermissionRestricted;

  /// No description provided for @cameraPermissionRequired.
  ///
  /// In fr, this message translates to:
  /// **'L\'accès à la caméra est nécessaire pour prendre des photos.'**
  String get cameraPermissionRequired;

  /// No description provided for @photoLibraryPermissionDenied.
  ///
  /// In fr, this message translates to:
  /// **'L\'accès aux photos a été refusé. Veuillez l\'activer dans les paramètres de l\'application.'**
  String get photoLibraryPermissionDenied;

  /// No description provided for @photoLibraryPermissionRestricted.
  ///
  /// In fr, this message translates to:
  /// **'L\'accès aux photos est restreint sur cet appareil.'**
  String get photoLibraryPermissionRestricted;

  /// No description provided for @photoLibraryPermissionRequired.
  ///
  /// In fr, this message translates to:
  /// **'L\'accès aux photos est nécessaire pour sélectionner des images.'**
  String get photoLibraryPermissionRequired;

  /// No description provided for @selectAnElement.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionnez un élément'**
  String get selectAnElement;

  /// No description provided for @cameraPermissionRequiredTitle.
  ///
  /// In fr, this message translates to:
  /// **'Permission caméra requise'**
  String get cameraPermissionRequiredTitle;

  /// No description provided for @specifyYourProfession.
  ///
  /// In fr, this message translates to:
  /// **'Précisez votre profession'**
  String get specifyYourProfession;

  /// No description provided for @orEnterYourCountry.
  ///
  /// In fr, this message translates to:
  /// **'Ou saisissez votre pays'**
  String get orEnterYourCountry;

  /// No description provided for @profileConfiguration.
  ///
  /// In fr, this message translates to:
  /// **'Configuration du profil'**
  String get profileConfiguration;

  /// No description provided for @locationPermissionDeniedForever.
  ///
  /// In fr, this message translates to:
  /// **'Permission de localisation refusée définitivement'**
  String get locationPermissionDeniedForever;

  /// No description provided for @travelModeEnabled.
  ///
  /// In fr, this message translates to:
  /// **'Mode Voyage activé (Localisation en arrière-plan)'**
  String get travelModeEnabled;

  /// No description provided for @travelModeDisabled.
  ///
  /// In fr, this message translates to:
  /// **'Mode Voyage désactivé'**
  String get travelModeDisabled;

  /// No description provided for @cannotChatWithDeletedUser.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de discuter avec un utilisateur supprimé'**
  String get cannotChatWithDeletedUser;

  /// No description provided for @qrCodeScannedSuccess.
  ///
  /// In fr, this message translates to:
  /// **'QR code scanné avec succès'**
  String get qrCodeScannedSuccess;

  /// No description provided for @whatsApp.
  ///
  /// In fr, this message translates to:
  /// **'WhatsApp'**
  String get whatsApp;

  /// No description provided for @facebook.
  ///
  /// In fr, this message translates to:
  /// **'Facebook'**
  String get facebook;

  /// No description provided for @sendAMessage.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer un message'**
  String get sendAMessage;

  /// No description provided for @removeFromFriends.
  ///
  /// In fr, this message translates to:
  /// **'Retirer des amis'**
  String get removeFromFriends;

  /// No description provided for @requestDeclinedMessage.
  ///
  /// In fr, this message translates to:
  /// **'Demande refusée'**
  String get requestDeclinedMessage;

  /// No description provided for @decline.
  ///
  /// In fr, this message translates to:
  /// **'Refuser'**
  String get decline;

  /// No description provided for @requestSentSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Demande envoyée avec succès'**
  String get requestSentSuccess;

  /// No description provided for @removeAdmin.
  ///
  /// In fr, this message translates to:
  /// **'Retirer Admin'**
  String get removeAdmin;

  /// No description provided for @membershipRequests.
  ///
  /// In fr, this message translates to:
  /// **'Demandes d\'adhésion'**
  String get membershipRequests;

  /// No description provided for @errorPrefix.
  ///
  /// In fr, this message translates to:
  /// **'Erreur: {error}'**
  String errorPrefix(String error);

  /// No description provided for @favorites.
  ///
  /// In fr, this message translates to:
  /// **'Favoris'**
  String get favorites;

  /// No description provided for @photosCount.
  ///
  /// In fr, this message translates to:
  /// **'Photos ({count})'**
  String photosCount(int count);

  /// No description provided for @filesCount.
  ///
  /// In fr, this message translates to:
  /// **'Fichiers ({count})'**
  String filesCount(int count);

  /// No description provided for @videoPlaybackError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur de lecture de la vidéo'**
  String get videoPlaybackError;

  /// No description provided for @videoSavedToGallery.
  ///
  /// In fr, this message translates to:
  /// **'Vidéo enregistrée dans la galerie'**
  String get videoSavedToGallery;

  /// No description provided for @info.
  ///
  /// In fr, this message translates to:
  /// **'Info'**
  String get info;

  /// No description provided for @imageSelectionError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la sélection de l\'image: {error}'**
  String imageSelectionError(String error);

  /// No description provided for @cannotDeleteMessageAfter1h.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de supprimer le message après 1h'**
  String get cannotDeleteMessageAfter1h;

  /// No description provided for @pdf.
  ///
  /// In fr, this message translates to:
  /// **'PDF'**
  String get pdf;

  /// No description provided for @doc.
  ///
  /// In fr, this message translates to:
  /// **'DOC'**
  String get doc;

  /// No description provided for @joinCall.
  ///
  /// In fr, this message translates to:
  /// **'Join'**
  String get joinCall;

  /// No description provided for @groupCall.
  ///
  /// In fr, this message translates to:
  /// **'Appel de groupe'**
  String get groupCall;

  /// No description provided for @cannotGetPosition.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'obtenir la position'**
  String get cannotGetPosition;

  /// No description provided for @searchPlace.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un lieu...'**
  String get searchPlace;

  /// No description provided for @modifyGroup.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le groupe'**
  String get modifyGroup;

  /// No description provided for @themeMode.
  ///
  /// In fr, this message translates to:
  /// **'Mode'**
  String get themeMode;

  /// No description provided for @themeAppearance.
  ///
  /// In fr, this message translates to:
  /// **'Apparence'**
  String get themeAppearance;

  /// No description provided for @themeGreenDefault.
  ///
  /// In fr, this message translates to:
  /// **'Vert (Défaut)'**
  String get themeGreenDefault;

  /// No description provided for @themeOrangeClassic.
  ///
  /// In fr, this message translates to:
  /// **'Orange (Classique)'**
  String get themeOrangeClassic;

  /// No description provided for @scanProfile.
  ///
  /// In fr, this message translates to:
  /// **'Scanner un profil'**
  String get scanProfile;

  /// No description provided for @placeQrCodeInFrame.
  ///
  /// In fr, this message translates to:
  /// **'Placez le QR code dans le cadre pour scanner'**
  String get placeQrCodeInFrame;

  /// No description provided for @flashActive.
  ///
  /// In fr, this message translates to:
  /// **'Flash actif'**
  String get flashActive;

  /// No description provided for @flash.
  ///
  /// In fr, this message translates to:
  /// **'Flash'**
  String get flash;

  /// No description provided for @cameraErrorCode.
  ///
  /// In fr, this message translates to:
  /// **'Erreur caméra: {errorCode}'**
  String cameraErrorCode(String errorCode);

  /// No description provided for @invalidQrCode.
  ///
  /// In fr, this message translates to:
  /// **'QR code invalide'**
  String get invalidQrCode;

  /// No description provided for @linkExpiredOrNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Lien expiré ou introuvable'**
  String get linkExpiredOrNotFound;

  /// No description provided for @connectionError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur de connexion'**
  String get connectionError;

  /// No description provided for @invalidQrCodeFormat.
  ///
  /// In fr, this message translates to:
  /// **'QR code invalide ou format non reconnu'**
  String get invalidQrCodeFormat;

  /// No description provided for @shareMyProfileTitle.
  ///
  /// In fr, this message translates to:
  /// **'Partager mon profil'**
  String get shareMyProfileTitle;

  /// No description provided for @generatingLink.
  ///
  /// In fr, this message translates to:
  /// **'Génération du lien...'**
  String get generatingLink;

  /// No description provided for @unableToGenerateShareLink.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de générer le lien de partage'**
  String get unableToGenerateShareLink;

  /// No description provided for @oops.
  ///
  /// In fr, this message translates to:
  /// **'Oups!'**
  String get oops;

  /// No description provided for @errorOccurred.
  ///
  /// In fr, this message translates to:
  /// **'Une erreur est survenue'**
  String get errorOccurred;

  /// No description provided for @scanToFindMe.
  ///
  /// In fr, this message translates to:
  /// **'Scannez pour me retrouver'**
  String get scanToFindMe;

  /// No description provided for @scanQrCode.
  ///
  /// In fr, this message translates to:
  /// **'Scanner un QR code'**
  String get scanQrCode;

  /// No description provided for @discoverMyProfile.
  ///
  /// In fr, this message translates to:
  /// **'Découvrez mon profil sur Diaspo Niger: {url}'**
  String discoverMyProfile(String url);

  /// No description provided for @myProfileOnDiaspoNiger.
  ///
  /// In fr, this message translates to:
  /// **'Mon profil Diaspo Niger'**
  String get myProfileOnDiaspoNiger;

  /// No description provided for @atTime.
  ///
  /// In fr, this message translates to:
  /// **'à {time}'**
  String atTime(String time);

  /// No description provided for @saveVideoError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de l\'enregistrement'**
  String get saveVideoError;

  /// No description provided for @fileNotAvailable.
  ///
  /// In fr, this message translates to:
  /// **'Fichier non disponible'**
  String get fileNotAvailable;

  /// No description provided for @fileCouldNotLoad.
  ///
  /// In fr, this message translates to:
  /// **'Le fichier n\'a pas pu être chargé'**
  String get fileCouldNotLoad;

  /// No description provided for @host.
  ///
  /// In fr, this message translates to:
  /// **'Hôte'**
  String get host;

  /// No description provided for @live.
  ///
  /// In fr, this message translates to:
  /// **'En direct'**
  String get live;

  /// No description provided for @waiting.
  ///
  /// In fr, this message translates to:
  /// **'En attente'**
  String get waiting;

  /// No description provided for @endToEndEncrypted.
  ///
  /// In fr, this message translates to:
  /// **'Chiffré de bout en bout'**
  String get endToEndEncrypted;

  /// No description provided for @noPhotos.
  ///
  /// In fr, this message translates to:
  /// **'Aucune photo'**
  String get noPhotos;

  /// No description provided for @noFiles.
  ///
  /// In fr, this message translates to:
  /// **'Aucun fichier'**
  String get noFiles;

  /// No description provided for @loadingVideo.
  ///
  /// In fr, this message translates to:
  /// **'Chargement de la vidéo...'**
  String get loadingVideo;

  /// No description provided for @playbackError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur de lecture'**
  String get playbackError;

  /// No description provided for @deleteMessage.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le message'**
  String get deleteMessage;

  /// No description provided for @selectAction.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionner'**
  String get selectAction;

  /// No description provided for @sendToConversations.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer à {count} conversation(s)'**
  String sendToConversations(int count);

  /// No description provided for @cannotResendMessage.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de renvoyer ce type de message. Veuillez le renvoyer manuellement.'**
  String get cannotResendMessage;

  /// No description provided for @searchError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur de recherche'**
  String get searchError;

  /// No description provided for @applyError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de l\'application: {error}'**
  String applyError(String error);

  /// No description provided for @deleteForMeSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Le message sera supprimé uniquement de votre vue'**
  String get deleteForMeSubtitle;

  /// No description provided for @deleteForEveryoneSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Le message sera supprimé pour tous les participants'**
  String get deleteForEveryoneSubtitle;

  /// No description provided for @audioNotAvailable.
  ///
  /// In fr, this message translates to:
  /// **'Audio non disponible'**
  String get audioNotAvailable;

  /// No description provided for @invalidAudioUrl.
  ///
  /// In fr, this message translates to:
  /// **'URL audio invalide'**
  String get invalidAudioUrl;

  /// No description provided for @audioPlaybackError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur de lecture'**
  String get audioPlaybackError;

  /// No description provided for @audioNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Audio introuvable'**
  String get audioNotFound;

  /// No description provided for @insufficientPermissionMessage.
  ///
  /// In fr, this message translates to:
  /// **'Vous n\'avez pas la permission d\'accéder à cette page.'**
  String get insufficientPermissionMessage;

  /// No description provided for @shareALocation.
  ///
  /// In fr, this message translates to:
  /// **'Partager une position'**
  String get shareALocation;

  /// No description provided for @searchLocation.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un lieu...'**
  String get searchLocation;

  /// No description provided for @selectedPosition.
  ///
  /// In fr, this message translates to:
  /// **'Position sélectionnée'**
  String get selectedPosition;

  /// No description provided for @gettingLocation.
  ///
  /// In fr, this message translates to:
  /// **'Obtention de la position...'**
  String get gettingLocation;

  /// No description provided for @myCurrentLocation.
  ///
  /// In fr, this message translates to:
  /// **'Ma position actuelle'**
  String get myCurrentLocation;

  /// No description provided for @orSelectOnMap.
  ///
  /// In fr, this message translates to:
  /// **'ou sélectionnez sur la carte'**
  String get orSelectOnMap;

  /// No description provided for @loadingMap.
  ///
  /// In fr, this message translates to:
  /// **'Chargement de la carte...'**
  String get loadingMap;

  /// No description provided for @sendThisLocation.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer cette position'**
  String get sendThisLocation;

  /// No description provided for @thisGroupWasDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Ce groupe a été supprimé'**
  String get thisGroupWasDeleted;

  /// No description provided for @thisUserWasDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Cet utilisateur a été supprimé'**
  String get thisUserWasDeleted;

  /// No description provided for @youBlockedThisUser.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez bloqué cet utilisateur'**
  String get youBlockedThisUser;

  /// No description provided for @messageResendFailed.
  ///
  /// In fr, this message translates to:
  /// **'Échec du renvoi du message'**
  String get messageResendFailed;

  /// No description provided for @unableToStartCall.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de démarrer l\'appel'**
  String get unableToStartCall;

  /// No description provided for @encrypted.
  ///
  /// In fr, this message translates to:
  /// **'Chiffré'**
  String get encrypted;

  /// No description provided for @typeYourMessageBelow.
  ///
  /// In fr, this message translates to:
  /// **'Tapez votre message ci-dessous'**
  String get typeYourMessageBelow;

  /// No description provided for @sendFirstMessageGroup.
  ///
  /// In fr, this message translates to:
  /// **'Soyez le premier à envoyer un message dans ce groupe !'**
  String get sendFirstMessageGroup;

  /// No description provided for @accept.
  ///
  /// In fr, this message translates to:
  /// **'Accepter'**
  String get accept;

  /// No description provided for @confirmRemoveFriend.
  ///
  /// In fr, this message translates to:
  /// **'Voulez-vous vraiment retirer {name} de vos amis ?'**
  String confirmRemoveFriend(String name);

  /// No description provided for @groupCreatedSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Groupe créé avec succès'**
  String get groupCreatedSuccess;

  /// No description provided for @groupUpdatedSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Groupe modifié avec succès'**
  String get groupUpdatedSuccess;

  /// No description provided for @groupUpdateError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la modification du groupe'**
  String get groupUpdateError;

  /// No description provided for @addPhoto.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une photo'**
  String get addPhoto;

  /// No description provided for @groupNamePlaceholder.
  ///
  /// In fr, this message translates to:
  /// **'Ex: Entrepreneurs Niger'**
  String get groupNamePlaceholder;

  /// No description provided for @describeYourGroup.
  ///
  /// In fr, this message translates to:
  /// **'Décrivez votre groupe...'**
  String get describeYourGroup;

  /// No description provided for @descriptionMinLength.
  ///
  /// In fr, this message translates to:
  /// **'La description doit contenir au moins 10 caractères'**
  String get descriptionMinLength;

  /// No description provided for @selectCountry.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionner un pays'**
  String get selectCountry;

  /// No description provided for @hostCountryHelp.
  ///
  /// In fr, this message translates to:
  /// **'Le pays où se trouve la communauté du groupe'**
  String get hostCountryHelp;

  /// No description provided for @selectRegion.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionner une région'**
  String get selectRegion;

  /// No description provided for @originRegionHelp.
  ///
  /// In fr, this message translates to:
  /// **'Pour regrouper les membres par région d\'origine'**
  String get originRegionHelp;

  /// No description provided for @detailedLocation.
  ///
  /// In fr, this message translates to:
  /// **'Localisation détaillée (optionnel)'**
  String get detailedLocation;

  /// No description provided for @tagsHint.
  ///
  /// In fr, this message translates to:
  /// **'Séparez les tags par des virgules'**
  String get tagsHint;

  /// No description provided for @membersNeedApproval.
  ///
  /// In fr, this message translates to:
  /// **'Les membres doivent être approuvés'**
  String get membersNeedApproval;

  /// No description provided for @createTheGroup.
  ///
  /// In fr, this message translates to:
  /// **'Créer le groupe'**
  String get createTheGroup;

  /// No description provided for @sendFileTitle.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer un fichier'**
  String get sendFileTitle;

  /// No description provided for @cameraSection.
  ///
  /// In fr, this message translates to:
  /// **'Caméra'**
  String get cameraSection;

  /// No description provided for @locationSection.
  ///
  /// In fr, this message translates to:
  /// **'Localisation'**
  String get locationSection;

  /// No description provided for @originAtNiger.
  ///
  /// In fr, this message translates to:
  /// **'Origine au Niger'**
  String get originAtNiger;

  /// No description provided for @next.
  ///
  /// In fr, this message translates to:
  /// **'Suivant'**
  String get next;

  /// No description provided for @finish.
  ///
  /// In fr, this message translates to:
  /// **'Terminer'**
  String get finish;

  /// No description provided for @connectionErrorRetry.
  ///
  /// In fr, this message translates to:
  /// **'Erreur de connexion. Veuillez réessayer.'**
  String get connectionErrorRetry;

  /// No description provided for @errorGeneric.
  ///
  /// In fr, this message translates to:
  /// **'Erreur: {error}'**
  String errorGeneric(String error);

  /// No description provided for @blockUserConfirmMessage.
  ///
  /// In fr, this message translates to:
  /// **'Voulez-vous vraiment bloquer {name} ? Vous ne recevrez plus de messages de sa part.'**
  String blockUserConfirmMessage(String name);

  /// No description provided for @blockingError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors du blocage'**
  String get blockingError;

  /// No description provided for @infoLabel.
  ///
  /// In fr, this message translates to:
  /// **'Info'**
  String get infoLabel;

  /// No description provided for @viewCart.
  ///
  /// In fr, this message translates to:
  /// **'Voir'**
  String get viewCart;

  /// No description provided for @selectImages.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionner des images'**
  String get selectImages;

  /// No description provided for @selectPhotos.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionner des photos'**
  String get selectPhotos;

  /// No description provided for @addPhotosCount.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter des photos ({count}/10)'**
  String addPhotosCount(int count);

  /// No description provided for @photosLimitReached.
  ///
  /// In fr, this message translates to:
  /// **'Limite de {count} photos atteinte'**
  String photosLimitReached(int count);

  /// No description provided for @selectionError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la sélection: {error}'**
  String selectionError(String error);

  /// No description provided for @addAtLeastOnePhoto.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez ajouter au moins une photo'**
  String get addAtLeastOnePhoto;

  /// No description provided for @shareRecap.
  ///
  /// In fr, this message translates to:
  /// **'Partager le récapitulatif'**
  String get shareRecap;

  /// No description provided for @okButton.
  ///
  /// In fr, this message translates to:
  /// **'OK'**
  String get okButton;

  /// No description provided for @profilePhotoTitle.
  ///
  /// In fr, this message translates to:
  /// **'Photo de profil'**
  String get profilePhotoTitle;

  /// No description provided for @profilePhotoOptional.
  ///
  /// In fr, this message translates to:
  /// **'Optionnel'**
  String get profilePhotoOptional;

  /// No description provided for @yourLocation.
  ///
  /// In fr, this message translates to:
  /// **'Votre localisation'**
  String get yourLocation;

  /// No description provided for @locationConnectHelp.
  ///
  /// In fr, this message translates to:
  /// **'Cela nous aide à vous connecter avec des membres proches de chez vous.'**
  String get locationConnectHelp;

  /// No description provided for @interestsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Vos centres d\'intérêt'**
  String get interestsTitle;

  /// No description provided for @interestsHelp.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionnez vos domaines d\'intérêt pour personnaliser votre expérience.'**
  String get interestsHelp;

  /// No description provided for @themeAppTitle.
  ///
  /// In fr, this message translates to:
  /// **'Thème de l\'application'**
  String get themeAppTitle;

  /// No description provided for @themeCustomizeHelp.
  ///
  /// In fr, this message translates to:
  /// **'Personnalisez l\'apparence de l\'application selon vos préférences.'**
  String get themeCustomizeHelp;

  /// No description provided for @displayMode.
  ///
  /// In fr, this message translates to:
  /// **'Mode d\'affichage'**
  String get displayMode;

  /// No description provided for @lightMode.
  ///
  /// In fr, this message translates to:
  /// **'Clair'**
  String get lightMode;

  /// No description provided for @lightModeSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Thème lumineux'**
  String get lightModeSubtitle;

  /// No description provided for @darkMode.
  ///
  /// In fr, this message translates to:
  /// **'Sombre'**
  String get darkMode;

  /// No description provided for @darkModeSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Thème sombre'**
  String get darkModeSubtitle;

  /// No description provided for @autoMode.
  ///
  /// In fr, this message translates to:
  /// **'Automatique'**
  String get autoMode;

  /// No description provided for @autoModeSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Suit les paramètres du système'**
  String get autoModeSubtitle;

  /// No description provided for @themeColorTitle.
  ///
  /// In fr, this message translates to:
  /// **'Couleur du thème'**
  String get themeColorTitle;

  /// No description provided for @greenColor.
  ///
  /// In fr, this message translates to:
  /// **'Vert'**
  String get greenColor;

  /// No description provided for @orangeColor.
  ///
  /// In fr, this message translates to:
  /// **'Orange'**
  String get orangeColor;

  /// No description provided for @takePhotoTitle.
  ///
  /// In fr, this message translates to:
  /// **'Prendre une photo'**
  String get takePhotoTitle;

  /// No description provided for @takePhotoSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Utiliser l\'appareil photo'**
  String get takePhotoSubtitle;

  /// No description provided for @galleryTitle.
  ///
  /// In fr, this message translates to:
  /// **'Choisir dans la galerie'**
  String get galleryTitle;

  /// No description provided for @gallerySubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionner une image existante'**
  String get gallerySubtitle;

  /// No description provided for @deletePhotoTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer la photo'**
  String get deletePhotoTitle;

  /// No description provided for @deletePhotoSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Utiliser les initiales par défaut'**
  String get deletePhotoSubtitle;

  /// No description provided for @adminHistoryAudit.
  ///
  /// In fr, this message translates to:
  /// **'Historique Audit'**
  String get adminHistoryAudit;

  /// No description provided for @adminGoBack.
  ///
  /// In fr, this message translates to:
  /// **'Retour'**
  String get adminGoBack;

  /// No description provided for @adminAll.
  ///
  /// In fr, this message translates to:
  /// **'Tous'**
  String get adminAll;

  /// No description provided for @adminPending.
  ///
  /// In fr, this message translates to:
  /// **'En attente'**
  String get adminPending;

  /// No description provided for @adminBoosted.
  ///
  /// In fr, this message translates to:
  /// **'Boostés'**
  String get adminBoosted;

  /// No description provided for @adminConfirmDelete.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer la suppression'**
  String get adminConfirmDelete;

  /// No description provided for @adminRevoke.
  ///
  /// In fr, this message translates to:
  /// **'Révoquer'**
  String get adminRevoke;

  /// No description provided for @adminTaxFees.
  ///
  /// In fr, this message translates to:
  /// **'Frais'**
  String get adminTaxFees;

  /// No description provided for @adminTaxBoosts.
  ///
  /// In fr, this message translates to:
  /// **'Boosts'**
  String get adminTaxBoosts;

  /// No description provided for @adminTaxes.
  ///
  /// In fr, this message translates to:
  /// **'Taxes'**
  String get adminTaxes;

  /// No description provided for @adminMedias.
  ///
  /// In fr, this message translates to:
  /// **'Medias'**
  String get adminMedias;

  /// No description provided for @adminSystem.
  ///
  /// In fr, this message translates to:
  /// **'Système'**
  String get adminSystem;

  /// No description provided for @adminAudio.
  ///
  /// In fr, this message translates to:
  /// **'Audio'**
  String get adminAudio;

  /// No description provided for @adminFeeMinimum.
  ///
  /// In fr, this message translates to:
  /// **'Frais minimum (XOF)'**
  String get adminFeeMinimum;

  /// No description provided for @adminFeeMaximum.
  ///
  /// In fr, this message translates to:
  /// **'Frais maximum (XOF)'**
  String get adminFeeMaximum;

  /// No description provided for @adminCommissionMin.
  ///
  /// In fr, this message translates to:
  /// **'Commission min (XOF)'**
  String get adminCommissionMin;

  /// No description provided for @adminCommissionMax.
  ///
  /// In fr, this message translates to:
  /// **'Commission max (XOF)'**
  String get adminCommissionMax;

  /// No description provided for @adminVatRateUpdated.
  ///
  /// In fr, this message translates to:
  /// **'Taux de TVA mis à jour'**
  String get adminVatRateUpdated;

  /// No description provided for @adminBaseShareUrl.
  ///
  /// In fr, this message translates to:
  /// **'URL de base pour partage'**
  String get adminBaseShareUrl;

  /// No description provided for @adminAudioUpdated.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres audio mis à jour'**
  String get adminAudioUpdated;

  /// No description provided for @adminClear.
  ///
  /// In fr, this message translates to:
  /// **'Effacer'**
  String get adminClear;

  /// No description provided for @adminAboutToSend.
  ///
  /// In fr, this message translates to:
  /// **'Vous êtes sur le point d\'envoyer une notification à:'**
  String get adminAboutToSend;

  /// No description provided for @adminLoginWithGoogle.
  ///
  /// In fr, this message translates to:
  /// **'Sign in with Google'**
  String get adminLoginWithGoogle;

  /// No description provided for @adminPasswordLabel.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe'**
  String get adminPasswordLabel;

  /// No description provided for @adminLoginButton.
  ///
  /// In fr, this message translates to:
  /// **'Login'**
  String get adminLoginButton;

  /// No description provided for @adminProductsCount.
  ///
  /// In fr, this message translates to:
  /// **'Produits ({count})'**
  String adminProductsCount(int count);

  /// No description provided for @adminOrdersCount.
  ///
  /// In fr, this message translates to:
  /// **'Commandes ({count})'**
  String adminOrdersCount(int count);

  /// No description provided for @adminDisputesCount.
  ///
  /// In fr, this message translates to:
  /// **'Litiges ({count})'**
  String adminDisputesCount(int count);

  /// No description provided for @adminDelete.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get adminDelete;

  /// No description provided for @adminGroupsCount.
  ///
  /// In fr, this message translates to:
  /// **'Groupes ({count})'**
  String adminGroupsCount(int count);

  /// No description provided for @adminSearchUser.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un utilisateur...'**
  String get adminSearchUser;

  /// No description provided for @adminLoading.
  ///
  /// In fr, this message translates to:
  /// **'Chargement...'**
  String get adminLoading;

  /// No description provided for @adminNoUsersFound.
  ///
  /// In fr, this message translates to:
  /// **'Aucun utilisateur trouvé'**
  String get adminNoUsersFound;

  /// No description provided for @adminActivityOf.
  ///
  /// In fr, this message translates to:
  /// **'Activité de {name}'**
  String adminActivityOf(String name);

  /// No description provided for @adminSearchReports.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher par nom, raison, ID...'**
  String get adminSearchReports;

  /// No description provided for @adminViewType.
  ///
  /// In fr, this message translates to:
  /// **'Voir le {type}'**
  String adminViewType(String type);

  /// No description provided for @adminRejectionHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex: Signalement non fondé, contenu conforme aux règles...'**
  String get adminRejectionHint;

  /// No description provided for @adminResolutionHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex: Avertissement envoyé, contenu modifié...'**
  String get adminResolutionHint;

  /// No description provided for @adminDeleteContentTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le contenu'**
  String get adminDeleteContentTitle;

  /// No description provided for @adminCreateEmbassyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Créer une ambassade'**
  String get adminCreateEmbassyTitle;

  /// No description provided for @adminWarnHost.
  ///
  /// In fr, this message translates to:
  /// **'Avertir l\'hôte'**
  String get adminWarnHost;

  /// No description provided for @adminGoalHint.
  ///
  /// In fr, this message translates to:
  /// **'Min: {min} XOF - Max: {max} XOF'**
  String adminGoalHint(String min, String max);

  /// No description provided for @interestCulture.
  ///
  /// In fr, this message translates to:
  /// **'Culture'**
  String get interestCulture;

  /// No description provided for @interestSport.
  ///
  /// In fr, this message translates to:
  /// **'Sport'**
  String get interestSport;

  /// No description provided for @interestBusiness.
  ///
  /// In fr, this message translates to:
  /// **'Business'**
  String get interestBusiness;

  /// No description provided for @interestEducation.
  ///
  /// In fr, this message translates to:
  /// **'Éducation'**
  String get interestEducation;

  /// No description provided for @interestTechnology.
  ///
  /// In fr, this message translates to:
  /// **'Technologie'**
  String get interestTechnology;

  /// No description provided for @interestArts.
  ///
  /// In fr, this message translates to:
  /// **'Arts'**
  String get interestArts;

  /// No description provided for @interestHealth.
  ///
  /// In fr, this message translates to:
  /// **'Santé'**
  String get interestHealth;

  /// No description provided for @interestPolitics.
  ///
  /// In fr, this message translates to:
  /// **'Politique'**
  String get interestPolitics;

  /// No description provided for @noBusinessFound.
  ///
  /// In fr, this message translates to:
  /// **'Aucune entreprise trouvée'**
  String get noBusinessFound;

  /// No description provided for @beFirstToAddBusiness.
  ///
  /// In fr, this message translates to:
  /// **'Soyez le premier à ajouter votre entreprise !'**
  String get beFirstToAddBusiness;

  /// No description provided for @filterByLocation.
  ///
  /// In fr, this message translates to:
  /// **'Filtrer par localisation'**
  String get filterByLocation;

  /// No description provided for @searchCountryLabel.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un pays'**
  String get searchCountryLabel;

  /// No description provided for @countryPlaceholder.
  ///
  /// In fr, this message translates to:
  /// **'Pays'**
  String get countryPlaceholder;

  /// No description provided for @cityPlaceholder.
  ///
  /// In fr, this message translates to:
  /// **'Ville'**
  String get cityPlaceholder;

  /// No description provided for @cityHintExample.
  ///
  /// In fr, this message translates to:
  /// **'Ex: Paris, Niamey, New York...'**
  String get cityHintExample;

  /// No description provided for @verifiedBadge.
  ///
  /// In fr, this message translates to:
  /// **'Vérifié'**
  String get verifiedBadge;

  /// No description provided for @premiumBadge.
  ///
  /// In fr, this message translates to:
  /// **'Premium'**
  String get premiumBadge;

  /// No description provided for @reviewsCountLabel.
  ///
  /// In fr, this message translates to:
  /// **'{rating} ({count} avis)'**
  String reviewsCountLabel(String rating, int count);

  /// No description provided for @contactSectionTitle.
  ///
  /// In fr, this message translates to:
  /// **'Contact'**
  String get contactSectionTitle;

  /// No description provided for @servicesSectionTitle.
  ///
  /// In fr, this message translates to:
  /// **'Services'**
  String get servicesSectionTitle;

  /// No description provided for @viewsStatLabel.
  ///
  /// In fr, this message translates to:
  /// **'Vues'**
  String get viewsStatLabel;

  /// No description provided for @reviewsStatLabel.
  ///
  /// In fr, this message translates to:
  /// **'Avis'**
  String get reviewsStatLabel;

  /// No description provided for @openingHoursTitle.
  ///
  /// In fr, this message translates to:
  /// **'Horaires d\'ouverture'**
  String get openingHoursTitle;

  /// No description provided for @dayMondayLabel.
  ///
  /// In fr, this message translates to:
  /// **'Lundi'**
  String get dayMondayLabel;

  /// No description provided for @dayTuesdayLabel.
  ///
  /// In fr, this message translates to:
  /// **'Mardi'**
  String get dayTuesdayLabel;

  /// No description provided for @dayWednesdayLabel.
  ///
  /// In fr, this message translates to:
  /// **'Mercredi'**
  String get dayWednesdayLabel;

  /// No description provided for @dayThursdayLabel.
  ///
  /// In fr, this message translates to:
  /// **'Jeudi'**
  String get dayThursdayLabel;

  /// No description provided for @dayFridayLabel.
  ///
  /// In fr, this message translates to:
  /// **'Vendredi'**
  String get dayFridayLabel;

  /// No description provided for @daySaturdayLabel.
  ///
  /// In fr, this message translates to:
  /// **'Samedi'**
  String get daySaturdayLabel;

  /// No description provided for @daySundayLabel.
  ///
  /// In fr, this message translates to:
  /// **'Dimanche'**
  String get daySundayLabel;

  /// No description provided for @closedStatus.
  ///
  /// In fr, this message translates to:
  /// **'Fermé'**
  String get closedStatus;

  /// No description provided for @currentOffersTitle.
  ///
  /// In fr, this message translates to:
  /// **'Offres en cours'**
  String get currentOffersTitle;

  /// No description provided for @noCurrentOffersMessage.
  ///
  /// In fr, this message translates to:
  /// **'Aucune offre en cours'**
  String get noCurrentOffersMessage;

  /// No description provided for @validUntilLabel.
  ///
  /// In fr, this message translates to:
  /// **'Valable jusqu\'au {date}'**
  String validUntilLabel(String date);

  /// No description provided for @newsSectionTitle.
  ///
  /// In fr, this message translates to:
  /// **'Actualités'**
  String get newsSectionTitle;

  /// No description provided for @addActionButton.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter'**
  String get addActionButton;

  /// No description provided for @noNewsMessage.
  ///
  /// In fr, this message translates to:
  /// **'Aucune actualité'**
  String get noNewsMessage;

  /// No description provided for @newPostDialogTitle.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle publication'**
  String get newPostDialogTitle;

  /// No description provided for @typeFieldLabel.
  ///
  /// In fr, this message translates to:
  /// **'Type'**
  String get typeFieldLabel;

  /// No description provided for @titleFieldPost.
  ///
  /// In fr, this message translates to:
  /// **'Titre'**
  String get titleFieldPost;

  /// No description provided for @titleHintPost.
  ///
  /// In fr, this message translates to:
  /// **'Ex: Nouvelle collection disponible'**
  String get titleHintPost;

  /// No description provided for @contentFieldPost.
  ///
  /// In fr, this message translates to:
  /// **'Contenu'**
  String get contentFieldPost;

  /// No description provided for @contentHintDescribe.
  ///
  /// In fr, this message translates to:
  /// **'Décrivez votre actualité...'**
  String get contentHintDescribe;

  /// No description provided for @publishAction.
  ///
  /// In fr, this message translates to:
  /// **'Publier'**
  String get publishAction;

  /// No description provided for @deleteDialogTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get deleteDialogTitle;

  /// No description provided for @confirmDeletePostMessage.
  ///
  /// In fr, this message translates to:
  /// **'Voulez-vous vraiment supprimer cette publication ?'**
  String get confirmDeletePostMessage;

  /// No description provided for @customerReviewsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Avis clients'**
  String get customerReviewsTitle;

  /// No description provided for @viewAllAction.
  ///
  /// In fr, this message translates to:
  /// **'Voir tout'**
  String get viewAllAction;

  /// No description provided for @noReviewsYetMessage.
  ///
  /// In fr, this message translates to:
  /// **'Aucun avis pour le moment'**
  String get noReviewsYetMessage;

  /// No description provided for @writeFirstReviewAction.
  ///
  /// In fr, this message translates to:
  /// **'Écrire le premier avis'**
  String get writeFirstReviewAction;

  /// No description provided for @writeReviewAction.
  ///
  /// In fr, this message translates to:
  /// **'Écrire un avis'**
  String get writeReviewAction;

  /// No description provided for @seeOtherReviewsLabel.
  ///
  /// In fr, this message translates to:
  /// **'Voir les {count} autres avis'**
  String seeOtherReviewsLabel(int count);

  /// No description provided for @loginRequiredForReview.
  ///
  /// In fr, this message translates to:
  /// **'Vous devez être connecté pour laisser un avis'**
  String get loginRequiredForReview;

  /// No description provided for @editAction.
  ///
  /// In fr, this message translates to:
  /// **'Modifier'**
  String get editAction;

  /// No description provided for @boostAction.
  ///
  /// In fr, this message translates to:
  /// **'Booster'**
  String get boostAction;

  /// No description provided for @alreadyLeftReviewMessage.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez déjà laissé un avis'**
  String get alreadyLeftReviewMessage;

  /// No description provided for @reviewDeletedMessage.
  ///
  /// In fr, this message translates to:
  /// **'Avis supprimé'**
  String get reviewDeletedMessage;

  /// No description provided for @reportReviewTitle.
  ///
  /// In fr, this message translates to:
  /// **'Signaler cet avis'**
  String get reportReviewTitle;

  /// No description provided for @reportReasonField.
  ///
  /// In fr, this message translates to:
  /// **'Raison du signalement'**
  String get reportReasonField;

  /// No description provided for @reportReasonHintText.
  ///
  /// In fr, this message translates to:
  /// **'Pourquoi signalez-vous cet avis ?'**
  String get reportReasonHintText;

  /// No description provided for @reviewReportedMessage.
  ///
  /// In fr, this message translates to:
  /// **'Avis signalé'**
  String get reviewReportedMessage;

  /// No description provided for @reportErrorOccurred.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors du signalement'**
  String get reportErrorOccurred;

  /// No description provided for @deleteReviewDialogTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer l\'avis'**
  String get deleteReviewDialogTitle;

  /// No description provided for @confirmDeleteReviewMessage.
  ///
  /// In fr, this message translates to:
  /// **'Voulez-vous vraiment supprimer cet avis ? Cette action est irréversible.'**
  String get confirmDeleteReviewMessage;

  /// No description provided for @reviewsScreenLabel.
  ///
  /// In fr, this message translates to:
  /// **'Avis'**
  String get reviewsScreenLabel;

  /// No description provided for @beFirstToShareExperience.
  ///
  /// In fr, this message translates to:
  /// **'Soyez le premier à partager votre expérience !'**
  String get beFirstToShareExperience;

  /// No description provided for @loadingErrorMessage.
  ///
  /// In fr, this message translates to:
  /// **'Erreur de chargement'**
  String get loadingErrorMessage;

  /// No description provided for @retryButtonLabel.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get retryButtonLabel;

  /// No description provided for @nReviewsLabel.
  ///
  /// In fr, this message translates to:
  /// **'{count} avis'**
  String nReviewsLabel(int count);

  /// No description provided for @allCountriesOption.
  ///
  /// In fr, this message translates to:
  /// **'Tous les pays'**
  String get allCountriesOption;

  /// No description provided for @chooseCountryDialogTitle.
  ///
  /// In fr, this message translates to:
  /// **'Choisir un pays'**
  String get chooseCountryDialogTitle;

  /// No description provided for @noProductAvailableMessage.
  ///
  /// In fr, this message translates to:
  /// **'Aucun produit disponible'**
  String get noProductAvailableMessage;

  /// No description provided for @beFirstToSellMessage.
  ///
  /// In fr, this message translates to:
  /// **'Soyez le premier à vendre !'**
  String get beFirstToSellMessage;

  /// No description provided for @noSearchResultsForQuery.
  ///
  /// In fr, this message translates to:
  /// **'Aucun résultat pour \"{query}\"'**
  String noSearchResultsForQuery(String query);

  /// No description provided for @myOrdersScreenTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mes commandes'**
  String get myOrdersScreenTitle;

  /// No description provided for @myPurchasesTabLabel.
  ///
  /// In fr, this message translates to:
  /// **'Mes achats'**
  String get myPurchasesTabLabel;

  /// No description provided for @mySalesTabLabel.
  ///
  /// In fr, this message translates to:
  /// **'Mes ventes'**
  String get mySalesTabLabel;

  /// No description provided for @noOrdersYetMessage.
  ///
  /// In fr, this message translates to:
  /// **'Vous n\'avez pas encore passé de commande'**
  String get noOrdersYetMessage;

  /// No description provided for @noOrdersReceivedMessage.
  ///
  /// In fr, this message translates to:
  /// **'Vous n\'avez pas encore reçu de commande'**
  String get noOrdersReceivedMessage;

  /// No description provided for @sellerWithNameLabel.
  ///
  /// In fr, this message translates to:
  /// **'Vendeur: {name}'**
  String sellerWithNameLabel(String name);

  /// No description provided for @buyerWithNameLabel.
  ///
  /// In fr, this message translates to:
  /// **'Acheteur: {name}'**
  String buyerWithNameLabel(String name);

  /// No description provided for @articlesCountLabel.
  ///
  /// In fr, this message translates to:
  /// **'{count} article{count, plural, =1{} other{s}}'**
  String articlesCountLabel(int count);

  /// No description provided for @quantityShortLabel.
  ///
  /// In fr, this message translates to:
  /// **'Qté: {qty}'**
  String quantityShortLabel(int qty);

  /// No description provided for @payAmountLabel.
  ///
  /// In fr, this message translates to:
  /// **'Payer {amount}'**
  String payAmountLabel(String amount);

  /// No description provided for @confirmReceiptAction.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer la réception'**
  String get confirmReceiptAction;

  /// No description provided for @markAsShippedAction.
  ///
  /// In fr, this message translates to:
  /// **'Marquer comme expédié'**
  String get markAsShippedAction;

  /// No description provided for @trackingNumberDialogTitle.
  ///
  /// In fr, this message translates to:
  /// **'Numéro de suivi'**
  String get trackingNumberDialogTitle;

  /// No description provided for @trackingNumberHintOptional.
  ///
  /// In fr, this message translates to:
  /// **'Entrez le numéro de suivi (optionnel)'**
  String get trackingNumberHintOptional;

  /// No description provided for @confirmAction.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer'**
  String get confirmAction;

  /// No description provided for @paymentSuccessfulMessage.
  ///
  /// In fr, this message translates to:
  /// **'Paiement effectué avec succès !'**
  String get paymentSuccessfulMessage;

  /// No description provided for @orderUpdateErrorOccurred.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la mise à jour de la commande'**
  String get orderUpdateErrorOccurred;

  /// No description provided for @paymentErrorWithDetails.
  ///
  /// In fr, this message translates to:
  /// **'Erreur de paiement: {error}'**
  String paymentErrorWithDetails(String error);

  /// No description provided for @deliveryConfirmedSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Livraison confirmée'**
  String get deliveryConfirmedSuccess;

  /// No description provided for @availableQuantityInfo.
  ///
  /// In fr, this message translates to:
  /// **'{qty} disponible(s)'**
  String availableQuantityInfo(int qty);

  /// No description provided for @descriptionSectionTitle.
  ///
  /// In fr, this message translates to:
  /// **'Description'**
  String get descriptionSectionTitle;

  /// No description provided for @sellerSectionTitle.
  ///
  /// In fr, this message translates to:
  /// **'Vendeur'**
  String get sellerSectionTitle;

  /// No description provided for @loadingLabel.
  ///
  /// In fr, this message translates to:
  /// **'Chargement...'**
  String get loadingLabel;

  /// No description provided for @viewProfileAction.
  ///
  /// In fr, this message translates to:
  /// **'Voir le profil'**
  String get viewProfileAction;

  /// No description provided for @contactSellerAction.
  ///
  /// In fr, this message translates to:
  /// **'Contacter le vendeur'**
  String get contactSellerAction;

  /// No description provided for @connectingLabel.
  ///
  /// In fr, this message translates to:
  /// **'Connexion...'**
  String get connectingLabel;

  /// No description provided for @conversationCreationErrorMessage.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la création de la conversation'**
  String get conversationCreationErrorMessage;

  /// No description provided for @interestedInProductText.
  ///
  /// In fr, this message translates to:
  /// **'Bonjour, je suis intéressé par ce produit :'**
  String get interestedInProductText;

  /// No description provided for @addToCartAction.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter au panier'**
  String get addToCartAction;

  /// No description provided for @addedToCartSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Ajouté au panier'**
  String get addedToCartSuccess;

  /// No description provided for @viewAction.
  ///
  /// In fr, this message translates to:
  /// **'Voir'**
  String get viewAction;

  /// No description provided for @deleteProductDialogTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le produit'**
  String get deleteProductDialogTitle;

  /// No description provided for @confirmDeleteProductMessage.
  ///
  /// In fr, this message translates to:
  /// **'Êtes-vous sûr de vouloir supprimer ce produit ?'**
  String get confirmDeleteProductMessage;

  /// No description provided for @sellProductScreenTitle.
  ///
  /// In fr, this message translates to:
  /// **'Vendre un produit'**
  String get sellProductScreenTitle;

  /// No description provided for @editProductScreenTitle.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le produit'**
  String get editProductScreenTitle;

  /// No description provided for @addImageAction.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter'**
  String get addImageAction;

  /// No description provided for @photosSectionTitle.
  ///
  /// In fr, this message translates to:
  /// **'Photos'**
  String get photosSectionTitle;

  /// No description provided for @titleFieldProduct.
  ///
  /// In fr, this message translates to:
  /// **'Titre'**
  String get titleFieldProduct;

  /// No description provided for @titleHintProduct.
  ///
  /// In fr, this message translates to:
  /// **'Ex: iPhone 13 Pro Max'**
  String get titleHintProduct;

  /// No description provided for @titleRequiredError.
  ///
  /// In fr, this message translates to:
  /// **'Entrez un titre'**
  String get titleRequiredError;

  /// No description provided for @descriptionFieldProduct.
  ///
  /// In fr, this message translates to:
  /// **'Description'**
  String get descriptionFieldProduct;

  /// No description provided for @descriptionHintProduct.
  ///
  /// In fr, this message translates to:
  /// **'Décrivez votre produit...'**
  String get descriptionHintProduct;

  /// No description provided for @priceFieldProduct.
  ///
  /// In fr, this message translates to:
  /// **'Prix'**
  String get priceFieldProduct;

  /// No description provided for @priceRequiredError.
  ///
  /// In fr, this message translates to:
  /// **'Entrez un prix'**
  String get priceRequiredError;

  /// No description provided for @priceInvalidError.
  ///
  /// In fr, this message translates to:
  /// **'Prix invalide'**
  String get priceInvalidError;

  /// No description provided for @quantityFieldProduct.
  ///
  /// In fr, this message translates to:
  /// **'Quantité'**
  String get quantityFieldProduct;

  /// No description provided for @quantityRequiredError.
  ///
  /// In fr, this message translates to:
  /// **'Requis'**
  String get quantityRequiredError;

  /// No description provided for @quantityInvalidError.
  ///
  /// In fr, this message translates to:
  /// **'Invalide'**
  String get quantityInvalidError;

  /// No description provided for @currencyFieldProduct.
  ///
  /// In fr, this message translates to:
  /// **'Devise'**
  String get currencyFieldProduct;

  /// No description provided for @categoryFieldProduct.
  ///
  /// In fr, this message translates to:
  /// **'Catégorie'**
  String get categoryFieldProduct;

  /// No description provided for @conditionFieldProduct.
  ///
  /// In fr, this message translates to:
  /// **'État'**
  String get conditionFieldProduct;

  /// No description provided for @countryFieldProduct.
  ///
  /// In fr, this message translates to:
  /// **'Pays'**
  String get countryFieldProduct;

  /// No description provided for @countryRequiredError.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionnez un pays'**
  String get countryRequiredError;

  /// No description provided for @cityAddressOptionalField.
  ///
  /// In fr, this message translates to:
  /// **'Ville/Adresse (optionnel)'**
  String get cityAddressOptionalField;

  /// No description provided for @cityAddressHintProduct.
  ///
  /// In fr, this message translates to:
  /// **'Ex: Niamey'**
  String get cityAddressHintProduct;

  /// No description provided for @taxSettingsSectionTitle.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres de taxe'**
  String get taxSettingsSectionTitle;

  /// No description provided for @taxExemptCategoryMessage.
  ///
  /// In fr, this message translates to:
  /// **'Cette catégorie est exonérée de taxe par défaut'**
  String get taxExemptCategoryMessage;

  /// No description provided for @defaultTaxForCategoryInfo.
  ///
  /// In fr, this message translates to:
  /// **'Taxe par défaut pour cette catégorie: {rate}%'**
  String defaultTaxForCategoryInfo(String rate);

  /// No description provided for @customRateField.
  ///
  /// In fr, this message translates to:
  /// **'Taux personnalisé (%)'**
  String get customRateField;

  /// No description provided for @customRateHintExample.
  ///
  /// In fr, this message translates to:
  /// **'Ex: 15'**
  String get customRateHintExample;

  /// No description provided for @priceTtcToggle.
  ///
  /// In fr, this message translates to:
  /// **'Prix TTC'**
  String get priceTtcToggle;

  /// No description provided for @priceTtcEnabledInfo.
  ///
  /// In fr, this message translates to:
  /// **'Le prix affiché inclut déjà la taxe'**
  String get priceTtcEnabledInfo;

  /// No description provided for @priceTtcDisabledInfo.
  ///
  /// In fr, this message translates to:
  /// **'La taxe sera ajoutée au prix affiché'**
  String get priceTtcDisabledInfo;

  /// No description provided for @previewSectionTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aperçu'**
  String get previewSectionTitle;

  /// No description provided for @subtotalLine.
  ///
  /// In fr, this message translates to:
  /// **'Sous-total'**
  String get subtotalLine;

  /// No description provided for @taxRateLine.
  ///
  /// In fr, this message translates to:
  /// **'Taxe ({rate}%)'**
  String taxRateLine(String rate);

  /// No description provided for @totalLine.
  ///
  /// In fr, this message translates to:
  /// **'Total'**
  String get totalLine;

  /// No description provided for @publishProductAction.
  ///
  /// In fr, this message translates to:
  /// **'Publier'**
  String get publishProductAction;

  /// No description provided for @saveProductAction.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get saveProductAction;

  /// No description provided for @addImageRequiredError.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez au moins une image'**
  String get addImageRequiredError;

  /// No description provided for @userNotConnectedMessage.
  ///
  /// In fr, this message translates to:
  /// **'Utilisateur non connecté'**
  String get userNotConnectedMessage;

  /// No description provided for @productModifiedMessage.
  ///
  /// In fr, this message translates to:
  /// **'Produit modifié'**
  String get productModifiedMessage;

  /// No description provided for @productPublishedMessage.
  ///
  /// In fr, this message translates to:
  /// **'Produit publié'**
  String get productPublishedMessage;

  /// No description provided for @orderAction.
  ///
  /// In fr, this message translates to:
  /// **'Commander'**
  String get orderAction;

  /// No description provided for @convertedNote.
  ///
  /// In fr, this message translates to:
  /// **'(converti)'**
  String get convertedNote;

  /// No description provided for @securePurchaseDialogTitle.
  ///
  /// In fr, this message translates to:
  /// **'Achat sécurisé'**
  String get securePurchaseDialogTitle;

  /// No description provided for @purchaseSecurityNote.
  ///
  /// In fr, this message translates to:
  /// **'Les achats sur le marketplace nécessitent l\'installation de l\'application depuis Google Play Store.'**
  String get purchaseSecurityNote;

  /// No description provided for @publishedDateLabel.
  ///
  /// In fr, this message translates to:
  /// **'publié'**
  String get publishedDateLabel;

  /// No description provided for @unknownUserLabel.
  ///
  /// In fr, this message translates to:
  /// **'Inconnu'**
  String get unknownUserLabel;

  /// No description provided for @allCategoryFilter.
  ///
  /// In fr, this message translates to:
  /// **'Tout'**
  String get allCategoryFilter;

  /// No description provided for @replyAction.
  ///
  /// In fr, this message translates to:
  /// **'Répondre'**
  String get replyAction;

  /// No description provided for @readAction.
  ///
  /// In fr, this message translates to:
  /// **'Lu'**
  String get readAction;

  /// No description provided for @taxAutomaticDesc.
  ///
  /// In fr, this message translates to:
  /// **'Taxe calculée selon la catégorie du produit'**
  String get taxAutomaticDesc;

  /// No description provided for @taxExemptDesc.
  ///
  /// In fr, this message translates to:
  /// **'Pas de taxe sur ce produit'**
  String get taxExemptDesc;

  /// No description provided for @taxStandardDesc.
  ///
  /// In fr, this message translates to:
  /// **'Taux standard de TVA'**
  String get taxStandardDesc;

  /// No description provided for @taxReducedDesc.
  ///
  /// In fr, this message translates to:
  /// **'Taux réduit pour produits essentiels'**
  String get taxReducedDesc;

  /// No description provided for @taxCustomDesc.
  ///
  /// In fr, this message translates to:
  /// **'Définir un taux personnalisé'**
  String get taxCustomDesc;

  /// No description provided for @adminSearchByAdminOrAction.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher par admin ou action...'**
  String get adminSearchByAdminOrAction;

  /// No description provided for @adminTransactions.
  ///
  /// In fr, this message translates to:
  /// **'Transactions'**
  String get adminTransactions;

  /// No description provided for @adminAllCount.
  ///
  /// In fr, this message translates to:
  /// **'Tous ({count})'**
  String adminAllCount(int count);

  /// No description provided for @adminPendingCount.
  ///
  /// In fr, this message translates to:
  /// **'{count} en attente'**
  String adminPendingCount(int count);

  /// No description provided for @adminBoostedCount.
  ///
  /// In fr, this message translates to:
  /// **'Boostés ({count})'**
  String adminBoostedCount(int count);

  /// No description provided for @adminGroupType.
  ///
  /// In fr, this message translates to:
  /// **'Groupe • {type}'**
  String adminGroupType(String type);

  /// No description provided for @adminEmailAddress.
  ///
  /// In fr, this message translates to:
  /// **'Adresse email'**
  String get adminEmailAddress;

  /// No description provided for @adminRoomConnectionError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la connexion au salon'**
  String get adminRoomConnectionError;

  /// No description provided for @adminSend.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer'**
  String get adminSend;

  /// No description provided for @adminHistory.
  ///
  /// In fr, this message translates to:
  /// **'Historique'**
  String get adminHistory;

  /// No description provided for @adminTitle.
  ///
  /// In fr, this message translates to:
  /// **'Titre'**
  String get adminTitle;

  /// No description provided for @adminMessage.
  ///
  /// In fr, this message translates to:
  /// **'Message'**
  String get adminMessage;

  /// No description provided for @adminRejectHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex: Signalement non fondé, contenu conforme aux règles...'**
  String get adminRejectHint;

  /// No description provided for @adminProcessHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex: Avertissement envoyé, contenu modifié...'**
  String get adminProcessHint;

  /// No description provided for @adminChangeRoleTitle.
  ///
  /// In fr, this message translates to:
  /// **'Changer le rôle'**
  String get adminChangeRoleTitle;

  /// No description provided for @adminRevokeAction.
  ///
  /// In fr, this message translates to:
  /// **'Révoquer'**
  String get adminRevokeAction;

  /// No description provided for @adminFees.
  ///
  /// In fr, this message translates to:
  /// **'Frais'**
  String get adminFees;

  /// No description provided for @adminBoosts.
  ///
  /// In fr, this message translates to:
  /// **'Boosts'**
  String get adminBoosts;

  /// No description provided for @adminMedia.
  ///
  /// In fr, this message translates to:
  /// **'Médias'**
  String get adminMedia;

  /// No description provided for @adminMaxImagesPerUpload.
  ///
  /// In fr, this message translates to:
  /// **'Max images/upload'**
  String get adminMaxImagesPerUpload;

  /// No description provided for @adminMaxCharsPerMessage.
  ///
  /// In fr, this message translates to:
  /// **'Caractères max par message'**
  String get adminMaxCharsPerMessage;

  /// No description provided for @adminCustomAmountsHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex: 1, 2, 5, 10, 20'**
  String get adminCustomAmountsHint;

  /// No description provided for @adminNoActivityRecorded.
  ///
  /// In fr, this message translates to:
  /// **'Aucune activité enregistrée'**
  String get adminNoActivityRecorded;

  /// No description provided for @audioRoomCollectionHelper.
  ///
  /// In fr, this message translates to:
  /// **'Min: {min} XOF - Max: {max} XOF'**
  String audioRoomCollectionHelper(int min, int max);

  /// No description provided for @audioRoomStoriesLabel.
  ///
  /// In fr, this message translates to:
  /// **'Contes'**
  String get audioRoomStoriesLabel;

  /// No description provided for @audioRoomProverbsLabel.
  ///
  /// In fr, this message translates to:
  /// **'Proverbes'**
  String get audioRoomProverbsLabel;

  /// No description provided for @audioRoomHistoryLabel.
  ///
  /// In fr, this message translates to:
  /// **'Histoire'**
  String get audioRoomHistoryLabel;

  /// No description provided for @audioRoomCeremoniesLabel.
  ///
  /// In fr, this message translates to:
  /// **'Cérémonies'**
  String get audioRoomCeremoniesLabel;

  /// No description provided for @audioRoomLanguageLabelNav.
  ///
  /// In fr, this message translates to:
  /// **'Langue'**
  String get audioRoomLanguageLabelNav;

  /// No description provided for @audioRoomCraftLabel.
  ///
  /// In fr, this message translates to:
  /// **'Artisanat'**
  String get audioRoomCraftLabel;

  /// No description provided for @audioRoomRecipesLabel.
  ///
  /// In fr, this message translates to:
  /// **'Recettes'**
  String get audioRoomRecipesLabel;

  /// No description provided for @audioRoomMedicineLabel.
  ///
  /// In fr, this message translates to:
  /// **'Médecine'**
  String get audioRoomMedicineLabel;

  /// No description provided for @businessBoostActivated.
  ///
  /// In fr, this message translates to:
  /// **'Boost activé avec succès!'**
  String get businessBoostActivated;

  /// No description provided for @businessBoostError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de l\'achat du boost'**
  String get businessBoostError;

  /// No description provided for @businessBoostTitle.
  ///
  /// In fr, this message translates to:
  /// **'Booster votre entreprise'**
  String get businessBoostTitle;

  /// No description provided for @businessTypeLabel.
  ///
  /// In fr, this message translates to:
  /// **'Type:'**
  String get businessTypeLabel;

  /// No description provided for @businessDurationLabel.
  ///
  /// In fr, this message translates to:
  /// **'Durée:'**
  String get businessDurationLabel;

  /// No description provided for @businessTotalLabel.
  ///
  /// In fr, this message translates to:
  /// **'Total:'**
  String get businessTotalLabel;

  /// No description provided for @businessPhotosLabel.
  ///
  /// In fr, this message translates to:
  /// **'Photos'**
  String get businessPhotosLabel;

  /// No description provided for @businessCategoryLabel.
  ///
  /// In fr, this message translates to:
  /// **'Catégorie'**
  String get businessCategoryLabel;

  /// No description provided for @businessNameRequired.
  ///
  /// In fr, this message translates to:
  /// **'Nom de l\'entreprise *'**
  String get businessNameRequired;

  /// No description provided for @businessDescriptionRequired.
  ///
  /// In fr, this message translates to:
  /// **'Description *'**
  String get businessDescriptionRequired;

  /// No description provided for @businessContactLabel.
  ///
  /// In fr, this message translates to:
  /// **'Contact'**
  String get businessContactLabel;

  /// No description provided for @businessLocationLabel.
  ///
  /// In fr, this message translates to:
  /// **'Localisation'**
  String get businessLocationLabel;

  /// No description provided for @businessCountryHint.
  ///
  /// In fr, this message translates to:
  /// **'Tapez le nom du pays'**
  String get businessCountryHint;

  /// No description provided for @businessServicesOffered.
  ///
  /// In fr, this message translates to:
  /// **'Services proposés'**
  String get businessServicesOffered;

  /// No description provided for @businessAddService.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un service'**
  String get businessAddService;

  /// No description provided for @businessCreateAction.
  ///
  /// In fr, this message translates to:
  /// **'Créer l\'entreprise'**
  String get businessCreateAction;

  /// No description provided for @businessEditReview.
  ///
  /// In fr, this message translates to:
  /// **'Modifier'**
  String get businessEditReview;

  /// No description provided for @businessReportReview.
  ///
  /// In fr, this message translates to:
  /// **'Signaler'**
  String get businessReportReview;

  /// No description provided for @businessGiveRating.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez donner une note'**
  String get businessGiveRating;

  /// No description provided for @businessWriteReview.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez écrire un avis'**
  String get businessWriteReview;

  /// No description provided for @businessSubmissionError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la soumission'**
  String get businessSubmissionError;

  /// No description provided for @businessTitleOptional.
  ///
  /// In fr, this message translates to:
  /// **'Titre (optionnel)'**
  String get businessTitleOptional;

  /// No description provided for @businessTitleHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex: Excellent service'**
  String get businessTitleHint;

  /// No description provided for @businessYourReview.
  ///
  /// In fr, this message translates to:
  /// **'Votre avis'**
  String get businessYourReview;

  /// No description provided for @businessShareExperience.
  ///
  /// In fr, this message translates to:
  /// **'Partagez votre expérience...'**
  String get businessShareExperience;

  /// No description provided for @businessAddReview.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter'**
  String get businessAddReview;

  /// No description provided for @callPermissionRequired.
  ///
  /// In fr, this message translates to:
  /// **'Permission requise'**
  String get callPermissionRequired;

  /// No description provided for @callSettings.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres'**
  String get callSettings;

  /// No description provided for @callEnd.
  ///
  /// In fr, this message translates to:
  /// **'Terminer'**
  String get callEnd;

  /// No description provided for @eventImageSelectionErrorMsg.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la sélection des images: {error}'**
  String eventImageSelectionErrorMsg(String error);

  /// No description provided for @eventPosterLimitReached.
  ///
  /// In fr, this message translates to:
  /// **'Limite de 5 affiches atteinte'**
  String get eventPosterLimitReached;

  /// No description provided for @eventSelectionError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la sélection: {error}'**
  String eventSelectionError(String error);

  /// No description provided for @eventPhotoLimitReached.
  ///
  /// In fr, this message translates to:
  /// **'Limite de 10 photos atteinte'**
  String get eventPhotoLimitReached;

  /// No description provided for @eventAddAtLeastOnePhoto.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez ajouter au moins une photo'**
  String get eventAddAtLeastOnePhoto;

  /// No description provided for @eventRecapShareTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Partager le récapitulatif'**
  String get eventRecapShareTooltip;

  /// No description provided for @eventPhotosAddCount.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter des photos ({count}/10)'**
  String eventPhotosAddCount(int count);

  /// No description provided for @groupRequestSentSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Demande envoyée avec succès'**
  String get groupRequestSentSuccess;

  /// No description provided for @groupPromoteAdminTitle.
  ///
  /// In fr, this message translates to:
  /// **'Promouvoir Admin'**
  String get groupPromoteAdminTitle;

  /// No description provided for @groupDemoteAdminTitle.
  ///
  /// In fr, this message translates to:
  /// **'Retirer Admin'**
  String get groupDemoteAdminTitle;

  /// No description provided for @groupConfirmTitle.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer'**
  String get groupConfirmTitle;

  /// No description provided for @groupMembershipRequestsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Demandes d\'adhésion'**
  String get groupMembershipRequestsTitle;

  /// No description provided for @groupApprovedRequest.
  ///
  /// In fr, this message translates to:
  /// **'Demande approuvée'**
  String get groupApprovedRequest;

  /// No description provided for @groupDeclinedRequest.
  ///
  /// In fr, this message translates to:
  /// **'Demande refusée'**
  String get groupDeclinedRequest;

  /// No description provided for @groupRejectAction.
  ///
  /// In fr, this message translates to:
  /// **'Refuser'**
  String get groupRejectAction;

  /// No description provided for @groupApproveAction.
  ///
  /// In fr, this message translates to:
  /// **'Approuver'**
  String get groupApproveAction;

  /// No description provided for @groupAllFilter.
  ///
  /// In fr, this message translates to:
  /// **'Tous'**
  String get groupAllFilter;

  /// No description provided for @mediaGalleryPhotos.
  ///
  /// In fr, this message translates to:
  /// **'Photos ({count})'**
  String mediaGalleryPhotos(int count);

  /// No description provided for @mediaGalleryFiles.
  ///
  /// In fr, this message translates to:
  /// **'Fichiers ({count})'**
  String mediaGalleryFiles(int count);

  /// No description provided for @mediaCaptionHint.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une légende...'**
  String get mediaCaptionHint;

  /// No description provided for @messageConversationError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur: {error}'**
  String messageConversationError(String error);

  /// No description provided for @messageInfoLabel.
  ///
  /// In fr, this message translates to:
  /// **'Info'**
  String get messageInfoLabel;

  /// No description provided for @notificationRemindLater.
  ///
  /// In fr, this message translates to:
  /// **'Me rappeler plus tard'**
  String get notificationRemindLater;

  /// No description provided for @notificationIn1HourOption.
  ///
  /// In fr, this message translates to:
  /// **'Dans 1 heure'**
  String get notificationIn1HourOption;

  /// No description provided for @notificationScheduled.
  ///
  /// In fr, this message translates to:
  /// **'Rappel programmé'**
  String get notificationScheduled;

  /// No description provided for @notificationTomorrowOption.
  ///
  /// In fr, this message translates to:
  /// **'Demain matin (9h)'**
  String get notificationTomorrowOption;

  /// No description provided for @podcastDisabledOption.
  ///
  /// In fr, this message translates to:
  /// **'Désactivé'**
  String get podcastDisabledOption;

  /// No description provided for @podcastEndOfEpisodeOption.
  ///
  /// In fr, this message translates to:
  /// **'Fin de l\'épisode'**
  String get podcastEndOfEpisodeOption;

  /// No description provided for @podcastSleepEndActivated.
  ///
  /// In fr, this message translates to:
  /// **'Arrêt à la fin de l\'épisode activé'**
  String get podcastSleepEndActivated;

  /// No description provided for @podcastSleepEnded.
  ///
  /// In fr, this message translates to:
  /// **'Minuterie de sommeil terminée'**
  String get podcastSleepEnded;

  /// No description provided for @podcastTimerSet.
  ///
  /// In fr, this message translates to:
  /// **'Minuterie: {minutes} minutes'**
  String podcastTimerSet(int minutes);

  /// No description provided for @podcastNotFoundError.
  ///
  /// In fr, this message translates to:
  /// **'Podcast non trouvé'**
  String get podcastNotFoundError;

  /// No description provided for @podcastAddEpisode.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter'**
  String get podcastAddEpisode;

  /// No description provided for @podcastErrorPrefix.
  ///
  /// In fr, this message translates to:
  /// **'Erreur: {error}'**
  String podcastErrorPrefix(String error);

  /// No description provided for @podcastAddChapterTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un chapitre'**
  String get podcastAddChapterTitle;

  /// No description provided for @podcastChapterTitleLabel.
  ///
  /// In fr, this message translates to:
  /// **'Titre du chapitre'**
  String get podcastChapterTitleLabel;

  /// No description provided for @podcastMinutesLabel.
  ///
  /// In fr, this message translates to:
  /// **'Minutes'**
  String get podcastMinutesLabel;

  /// No description provided for @podcastSecondsLabel.
  ///
  /// In fr, this message translates to:
  /// **'Secondes'**
  String get podcastSecondsLabel;

  /// No description provided for @podcastSelectAudio.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez sélectionner un fichier audio'**
  String get podcastSelectAudio;

  /// No description provided for @podcastEpisodeError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur: {error}'**
  String podcastEpisodeError(String error);

  /// No description provided for @podcastEpisodeTitleRequired.
  ///
  /// In fr, this message translates to:
  /// **'Titre de l\'épisode *'**
  String get podcastEpisodeTitleRequired;

  /// No description provided for @podcastDescriptionNotes.
  ///
  /// In fr, this message translates to:
  /// **'Description / Notes'**
  String get podcastDescriptionNotes;

  /// No description provided for @podcastSubscribersOnlyLabel.
  ///
  /// In fr, this message translates to:
  /// **'Réservé aux abonnés payants'**
  String get podcastSubscribersOnlyLabel;

  /// No description provided for @podcastDownloadedTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargé'**
  String get podcastDownloadedTooltip;

  /// No description provided for @podcastDownloadTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Télécharger'**
  String get podcastDownloadTooltip;

  /// No description provided for @podcastDeleteDownloadTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le téléchargement'**
  String get podcastDeleteDownloadTitle;

  /// No description provided for @podcastDownloadDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargement supprimé'**
  String get podcastDownloadDeleted;

  /// No description provided for @podcastSelectOrCreateNew.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionnez un podcast ou créez-en un nouveau'**
  String get podcastSelectOrCreateNew;

  /// No description provided for @podcastRecordingSoon.
  ///
  /// In fr, this message translates to:
  /// **'L\'enregistrement du salon sera bientôt disponible'**
  String get podcastRecordingSoon;

  /// No description provided for @podcastAudioMissing.
  ///
  /// In fr, this message translates to:
  /// **'Fichier audio introuvable'**
  String get podcastAudioMissing;

  /// No description provided for @podcastPublishingError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la publication'**
  String get podcastPublishingError;

  /// No description provided for @podcastEpisodeTitleInput.
  ///
  /// In fr, this message translates to:
  /// **'Titre de l\'épisode'**
  String get podcastEpisodeTitleInput;

  /// No description provided for @podcastEpisodeDescInput.
  ///
  /// In fr, this message translates to:
  /// **'Description de l\'épisode (optionnel)'**
  String get podcastEpisodeDescInput;

  /// No description provided for @podcastPublishAction.
  ///
  /// In fr, this message translates to:
  /// **'Publier'**
  String get podcastPublishAction;

  /// No description provided for @podcastCreateAction.
  ///
  /// In fr, this message translates to:
  /// **'Créer un podcast'**
  String get podcastCreateAction;

  /// No description provided for @profileCodeSentTo.
  ///
  /// In fr, this message translates to:
  /// **'Code envoyé au {phone}'**
  String profileCodeSentTo(String phone);

  /// No description provided for @profileTravelModeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mode Voyage'**
  String get profileTravelModeTitle;

  /// No description provided for @reportMyReportsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mes signalements'**
  String get reportMyReportsTitle;

  /// No description provided for @reportDescribeProblem.
  ///
  /// In fr, this message translates to:
  /// **'Décrivez le problème...'**
  String get reportDescribeProblem;

  /// No description provided for @reportSendAction.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer le signalement'**
  String get reportSendAction;

  /// No description provided for @settingsRenameDeviceTitle.
  ///
  /// In fr, this message translates to:
  /// **'Renommer l\'appareil'**
  String get settingsRenameDeviceTitle;

  /// No description provided for @settingsDeviceNameLabel.
  ///
  /// In fr, this message translates to:
  /// **'Nom de l\'appareil'**
  String get settingsDeviceNameLabel;

  /// No description provided for @settingsRename.
  ///
  /// In fr, this message translates to:
  /// **'Renommer'**
  String get settingsRename;

  /// No description provided for @settingsRevokeDeviceTitle.
  ///
  /// In fr, this message translates to:
  /// **'Révoquer l\'appareil ?'**
  String get settingsRevokeDeviceTitle;

  /// No description provided for @settingsRevokeConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Révoquer'**
  String get settingsRevokeConfirm;

  /// No description provided for @settingsConnectedDevicesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Appareils connectés'**
  String get settingsConnectedDevicesTitle;

  /// No description provided for @settingsDeleteBackupTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer la sauvegarde ?'**
  String get settingsDeleteBackupTitle;

  /// No description provided for @settingsKeyBackupTitle.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarde des clés'**
  String get settingsKeyBackupTitle;

  /// No description provided for @settingsPassphrase.
  ///
  /// In fr, this message translates to:
  /// **'Passphrase'**
  String get settingsPassphrase;

  /// No description provided for @settingsRestoreKeysAction.
  ///
  /// In fr, this message translates to:
  /// **'Restaurer les clés'**
  String get settingsRestoreKeysAction;

  /// No description provided for @settingsGenerateSecurePassphrase.
  ///
  /// In fr, this message translates to:
  /// **'Générer une passphrase sécurisée'**
  String get settingsGenerateSecurePassphrase;

  /// No description provided for @settingsPassphraseMinChars.
  ///
  /// In fr, this message translates to:
  /// **'Minimum 8 caractères'**
  String get settingsPassphraseMinChars;

  /// No description provided for @settingsConfirmPassphraseLabel.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer la passphrase'**
  String get settingsConfirmPassphraseLabel;

  /// No description provided for @settingsCreateBackupAction.
  ///
  /// In fr, this message translates to:
  /// **'Créer la sauvegarde'**
  String get settingsCreateBackupAction;

  /// No description provided for @settingsTermsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Conditions d\'utilisation'**
  String get settingsTermsTitle;

  /// No description provided for @settingsBugDescLabel.
  ///
  /// In fr, this message translates to:
  /// **'Description du bug'**
  String get settingsBugDescLabel;

  /// No description provided for @settingsBugDescHint.
  ///
  /// In fr, this message translates to:
  /// **'Décrivez le problème rencontré...'**
  String get settingsBugDescHint;

  /// No description provided for @settingsCurrencySearch.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher une devise...'**
  String get settingsCurrencySearch;

  /// No description provided for @settingsOk.
  ///
  /// In fr, this message translates to:
  /// **'OK'**
  String get settingsOk;

  /// No description provided for @transferAddRecipientTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un bénéficiaire'**
  String get transferAddRecipientTitle;

  /// No description provided for @transferErrorPrefix.
  ///
  /// In fr, this message translates to:
  /// **'Erreur: {error}'**
  String transferErrorPrefix(String error);

  /// No description provided for @transferNewAction.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau'**
  String get transferNewAction;

  /// No description provided for @transferAddManuallyAction.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter manuellement'**
  String get transferAddManuallyAction;

  /// No description provided for @transferChooseRecipientTitle.
  ///
  /// In fr, this message translates to:
  /// **'Choisir un bénéficiaire'**
  String get transferChooseRecipientTitle;

  /// No description provided for @transferAddRecipientHint.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un bénéficiaire'**
  String get transferAddRecipientHint;

  /// No description provided for @transferSendMoneyAction.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer de l\'argent'**
  String get transferSendMoneyAction;

  /// No description provided for @transferEditAction.
  ///
  /// In fr, this message translates to:
  /// **'Modifier'**
  String get transferEditAction;

  /// No description provided for @transferDeleteTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer ?'**
  String get transferDeleteTitle;

  /// No description provided for @transferDeleteMsg.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer {name} ?'**
  String transferDeleteMsg(String name);

  /// No description provided for @transferDetailsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Détails du transfert'**
  String get transferDetailsTitle;

  /// No description provided for @transferAmountSentLine.
  ///
  /// In fr, this message translates to:
  /// **'Montant envoyé'**
  String get transferAmountSentLine;

  /// No description provided for @transferFeesLine.
  ///
  /// In fr, this message translates to:
  /// **'Frais'**
  String get transferFeesLine;

  /// No description provided for @transferExchangeRateLine.
  ///
  /// In fr, this message translates to:
  /// **'Taux de change'**
  String get transferExchangeRateLine;

  /// No description provided for @transferCopiedToClipboard.
  ///
  /// In fr, this message translates to:
  /// **'Copié dans le presse-papiers'**
  String get transferCopiedToClipboard;

  /// No description provided for @transferRetryAction.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer le transfert'**
  String get transferRetryAction;

  /// No description provided for @transferContactSupportAction.
  ///
  /// In fr, this message translates to:
  /// **'Contacter le support'**
  String get transferContactSupportAction;

  /// No description provided for @transferStatusPending.
  ///
  /// In fr, this message translates to:
  /// **'En attente'**
  String get transferStatusPending;

  /// No description provided for @transferStatusDebiting.
  ///
  /// In fr, this message translates to:
  /// **'Débit en cours'**
  String get transferStatusDebiting;

  /// No description provided for @transferStatusProcessing.
  ///
  /// In fr, this message translates to:
  /// **'En cours'**
  String get transferStatusProcessing;

  /// No description provided for @transferStatusSending.
  ///
  /// In fr, this message translates to:
  /// **'Envoi en cours'**
  String get transferStatusSending;

  /// No description provided for @transferStatusCompleted.
  ///
  /// In fr, this message translates to:
  /// **'Terminé'**
  String get transferStatusCompleted;

  /// No description provided for @transferStatusFailed.
  ///
  /// In fr, this message translates to:
  /// **'Échoué'**
  String get transferStatusFailed;

  /// No description provided for @transferStatusRefunding.
  ///
  /// In fr, this message translates to:
  /// **'Remboursement en cours'**
  String get transferStatusRefunding;

  /// No description provided for @transferStatusRefunded.
  ///
  /// In fr, this message translates to:
  /// **'Remboursé'**
  String get transferStatusRefunded;

  /// No description provided for @transferStatusCancelled.
  ///
  /// In fr, this message translates to:
  /// **'Annulé'**
  String get transferStatusCancelled;

  /// No description provided for @transferStatusPendingDesc.
  ///
  /// In fr, this message translates to:
  /// **'Votre transfert est en attente de traitement.'**
  String get transferStatusPendingDesc;

  /// No description provided for @transferStatusDebitingDesc.
  ///
  /// In fr, this message translates to:
  /// **'Le prélèvement est en cours sur votre compte.'**
  String get transferStatusDebitingDesc;

  /// No description provided for @transferStatusProcessingDesc.
  ///
  /// In fr, this message translates to:
  /// **'Votre transfert est en cours de traitement.'**
  String get transferStatusProcessingDesc;

  /// No description provided for @transferStatusSendingDesc.
  ///
  /// In fr, this message translates to:
  /// **'L\'argent est en cours d\'envoi au bénéficiaire.'**
  String get transferStatusSendingDesc;

  /// No description provided for @transferStatusCompletedDesc.
  ///
  /// In fr, this message translates to:
  /// **'Votre transfert a été effectué avec succès !'**
  String get transferStatusCompletedDesc;

  /// No description provided for @transferStatusFailedDesc.
  ///
  /// In fr, this message translates to:
  /// **'Le transfert a échoué. Veuillez réessayer.'**
  String get transferStatusFailedDesc;

  /// No description provided for @transferStatusRefundingDesc.
  ///
  /// In fr, this message translates to:
  /// **'Le remboursement est en cours de traitement.'**
  String get transferStatusRefundingDesc;

  /// No description provided for @transferStatusRefundedDesc.
  ///
  /// In fr, this message translates to:
  /// **'Le montant a été remboursé sur votre compte.'**
  String get transferStatusRefundedDesc;

  /// No description provided for @transferStatusCancelledDesc.
  ///
  /// In fr, this message translates to:
  /// **'Ce transfert a été annulé.'**
  String get transferStatusCancelledDesc;

  /// No description provided for @transferEmailOption.
  ///
  /// In fr, this message translates to:
  /// **'Email'**
  String get transferEmailOption;

  /// No description provided for @transferLiveChat.
  ///
  /// In fr, this message translates to:
  /// **'Chat en direct'**
  String get transferLiveChat;

  /// No description provided for @transferAvailable247.
  ///
  /// In fr, this message translates to:
  /// **'Disponible 24/7'**
  String get transferAvailable247;

  /// No description provided for @transferChatUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Chat non disponible pour le moment'**
  String get transferChatUnavailable;

  /// No description provided for @transferPhoneOption.
  ///
  /// In fr, this message translates to:
  /// **'Téléphone'**
  String get transferPhoneOption;

  /// No description provided for @transferHistoryTitle.
  ///
  /// In fr, this message translates to:
  /// **'Historique des transferts'**
  String get transferHistoryTitle;

  /// No description provided for @transferSendActionLabel.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer'**
  String get transferSendActionLabel;

  /// No description provided for @transferActiveFiltersLabel.
  ///
  /// In fr, this message translates to:
  /// **'Filtres actifs: '**
  String get transferActiveFiltersLabel;

  /// No description provided for @transferClearAllAction.
  ///
  /// In fr, this message translates to:
  /// **'Effacer tout'**
  String get transferClearAllAction;

  /// No description provided for @transferChoosePeriodAction.
  ///
  /// In fr, this message translates to:
  /// **'Choisir une période'**
  String get transferChoosePeriodAction;

  /// No description provided for @transferApplyFiltersAction.
  ///
  /// In fr, this message translates to:
  /// **'Appliquer les filtres'**
  String get transferApplyFiltersAction;

  /// No description provided for @widgetRetryAction.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get widgetRetryAction;

  /// No description provided for @widgetCameraOption.
  ///
  /// In fr, this message translates to:
  /// **'Caméra'**
  String get widgetCameraOption;

  /// No description provided for @widgetGalleryOption.
  ///
  /// In fr, this message translates to:
  /// **'Galerie'**
  String get widgetGalleryOption;

  /// No description provided for @adminDashboardTitle.
  ///
  /// In fr, this message translates to:
  /// **'Tableau de Bord'**
  String get adminDashboardTitle;

  /// No description provided for @adminDashboardWelcome.
  ///
  /// In fr, this message translates to:
  /// **'Bienvenue dans le panneau d\'administration DiaspoNiger'**
  String get adminDashboardWelcome;

  /// No description provided for @adminGeneralStats.
  ///
  /// In fr, this message translates to:
  /// **'Statistiques Générales'**
  String get adminGeneralStats;

  /// No description provided for @adminActiveSessions.
  ///
  /// In fr, this message translates to:
  /// **'Sessions Actives'**
  String get adminActiveSessions;

  /// No description provided for @adminCommerceMarketplace.
  ///
  /// In fr, this message translates to:
  /// **'Commerce & Marketplace'**
  String get adminCommerceMarketplace;

  /// No description provided for @adminProducts.
  ///
  /// In fr, this message translates to:
  /// **'Produits'**
  String get adminProducts;

  /// No description provided for @adminQuickActions.
  ///
  /// In fr, this message translates to:
  /// **'Actions Rapides'**
  String get adminQuickActions;

  /// No description provided for @adminNoLiveRooms.
  ///
  /// In fr, this message translates to:
  /// **'Aucun salon en direct'**
  String get adminNoLiveRooms;

  /// No description provided for @adminNoLiveRoomsDesc.
  ///
  /// In fr, this message translates to:
  /// **'Il n\'y a actuellement aucun salon audio en cours.'**
  String get adminNoLiveRoomsDesc;

  /// No description provided for @adminLiveAudioRooms.
  ///
  /// In fr, this message translates to:
  /// **'Salons Audio Live'**
  String get adminLiveAudioRooms;

  /// No description provided for @adminLiveAudioRoomsDesc.
  ///
  /// In fr, this message translates to:
  /// **'Surveillez et modérez les salons audio en direct'**
  String get adminLiveAudioRoomsDesc;

  /// No description provided for @adminEmbassyManagement.
  ///
  /// In fr, this message translates to:
  /// **'Gestion des Ambassades'**
  String get adminEmbassyManagement;

  /// No description provided for @adminEmbassyManagementDesc.
  ///
  /// In fr, this message translates to:
  /// **'Créez et gérez les comptes ambassades'**
  String get adminEmbassyManagementDesc;

  /// No description provided for @adminLoadingData.
  ///
  /// In fr, this message translates to:
  /// **'Chargement des données...'**
  String get adminLoadingData;

  /// No description provided for @adminErrorOccurred.
  ///
  /// In fr, this message translates to:
  /// **'Une erreur est survenue'**
  String get adminErrorOccurred;

  /// No description provided for @adminActive.
  ///
  /// In fr, this message translates to:
  /// **'actif'**
  String get adminActive;

  /// No description provided for @adminPaid.
  ///
  /// In fr, this message translates to:
  /// **'Payant'**
  String get adminPaid;

  /// No description provided for @adminVideo.
  ///
  /// In fr, this message translates to:
  /// **'Vidéo'**
  String get adminVideo;

  /// No description provided for @adminHost.
  ///
  /// In fr, this message translates to:
  /// **'Hôte'**
  String get adminHost;

  /// No description provided for @adminModerationDialogContent.
  ///
  /// In fr, this message translates to:
  /// **'Vous allez rejoindre ce salon en mode invisible (ghost mode). Les participants ne pourront pas vous voir.\n\nVous pourrez:\n- Écouter les conversations\n- Voir les vidéos (si activées)\n- Avertir l\'hôte\n- Fermer le salon si nécessaire'**
  String get adminModerationDialogContent;

  /// No description provided for @eventPostersOptional.
  ///
  /// In fr, this message translates to:
  /// **'Affiches de l\'événement (optionnel)'**
  String get eventPostersOptional;

  /// No description provided for @eventPostersLabel.
  ///
  /// In fr, this message translates to:
  /// **'Affiches de l\'événement'**
  String get eventPostersLabel;

  /// No description provided for @eventPostersUpTo5.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez jusqu\'à 5 affiches pour votre événement'**
  String get eventPostersUpTo5;

  /// No description provided for @eventManagePosters.
  ///
  /// In fr, this message translates to:
  /// **'Gérer les affiches ({count}/5)'**
  String eventManagePosters(int count);

  /// No description provided for @eventCurrentPosters.
  ///
  /// In fr, this message translates to:
  /// **'Affiches actuelles'**
  String get eventCurrentPosters;

  /// No description provided for @eventNewPosters.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelles affiches'**
  String get eventNewPosters;

  /// No description provided for @eventAddImages.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter des images'**
  String get eventAddImages;

  /// No description provided for @eventAddPosterCount.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter ({count}/5)'**
  String eventAddPosterCount(int count);

  /// No description provided for @eventRecapTitle.
  ///
  /// In fr, this message translates to:
  /// **'Récapitulatif'**
  String get eventRecapTitle;

  /// No description provided for @eventCreateRecap.
  ///
  /// In fr, this message translates to:
  /// **'Créer un récapitulatif'**
  String get eventCreateRecap;

  /// No description provided for @eventEditRecap.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le récapitulatif'**
  String get eventEditRecap;

  /// No description provided for @eventRecapInfo.
  ///
  /// In fr, this message translates to:
  /// **'Partagez les meilleurs moments de votre événement avec des photos et une description.'**
  String get eventRecapInfo;

  /// No description provided for @eventRecapPhotosLabel.
  ///
  /// In fr, this message translates to:
  /// **'Photos du récapitulatif'**
  String get eventRecapPhotosLabel;

  /// No description provided for @eventRecapUpTo10Photos.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez jusqu\'à 10 photos ({count}/10)'**
  String eventRecapUpTo10Photos(int count);

  /// No description provided for @eventExistingPhotos.
  ///
  /// In fr, this message translates to:
  /// **'Photos existantes'**
  String get eventExistingPhotos;

  /// No description provided for @eventNewPhotos.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelles photos'**
  String get eventNewPhotos;

  /// No description provided for @eventRecapDescriptionHint.
  ///
  /// In fr, this message translates to:
  /// **'Racontez comment s\'est passé l\'événement...'**
  String get eventRecapDescriptionHint;

  /// No description provided for @eventRecapDescriptionRequired.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez ajouter une description'**
  String get eventRecapDescriptionRequired;

  /// No description provided for @eventRecapDescriptionTooShort.
  ///
  /// In fr, this message translates to:
  /// **'La description doit faire au moins 20 caractères'**
  String get eventRecapDescriptionTooShort;

  /// No description provided for @eventRecapUpdateButton.
  ///
  /// In fr, this message translates to:
  /// **'Mettre à jour'**
  String get eventRecapUpdateButton;

  /// No description provided for @eventRecapCreateButton.
  ///
  /// In fr, this message translates to:
  /// **'Créer le récapitulatif'**
  String get eventRecapCreateButton;

  /// No description provided for @eventRecapUpdatedSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Récapitulatif mis à jour avec succès'**
  String get eventRecapUpdatedSuccess;

  /// No description provided for @eventRecapCreatedSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Récapitulatif créé avec succès'**
  String get eventRecapCreatedSuccess;

  /// No description provided for @eventRecapError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur: {error}'**
  String eventRecapError(String error);

  /// No description provided for @noConnection.
  ///
  /// In fr, this message translates to:
  /// **'Pas de connexion'**
  String get noConnection;

  /// No description provided for @weakConnection.
  ///
  /// In fr, this message translates to:
  /// **'Connexion faible'**
  String get weakConnection;

  /// No description provided for @unstableConnection.
  ///
  /// In fr, this message translates to:
  /// **'Connexion instable'**
  String get unstableConnection;

  /// No description provided for @goodConnection.
  ///
  /// In fr, this message translates to:
  /// **'Bonne connexion'**
  String get goodConnection;

  /// No description provided for @noInternetConnection.
  ///
  /// In fr, this message translates to:
  /// **'Pas de connexion internet'**
  String get noInternetConnection;

  /// No description provided for @poorConnectionLimitedFunctions.
  ///
  /// In fr, this message translates to:
  /// **'Connexion faible - certaines fonctions peuvent être limitées'**
  String get poorConnectionLimitedFunctions;

  /// No description provided for @chooseAnImage.
  ///
  /// In fr, this message translates to:
  /// **'Choisir une image'**
  String get chooseAnImage;

  /// No description provided for @chooseImages.
  ///
  /// In fr, this message translates to:
  /// **'Choisir des images'**
  String get chooseImages;

  /// No description provided for @permissionDeniedGeneric.
  ///
  /// In fr, this message translates to:
  /// **'Permission refusée'**
  String get permissionDeniedGeneric;

  /// No description provided for @maximumImages.
  ///
  /// In fr, this message translates to:
  /// **'Maximum {count} images'**
  String maximumImages(int count);

  /// No description provided for @callPermissionMicrophone.
  ///
  /// In fr, this message translates to:
  /// **'microphone'**
  String get callPermissionMicrophone;

  /// No description provided for @callPermissionCamera.
  ///
  /// In fr, this message translates to:
  /// **'caméra'**
  String get callPermissionCamera;

  /// No description provided for @callPermissionDenied.
  ///
  /// In fr, this message translates to:
  /// **'L\'accès au {permissions} est nécessaire pour passer des appels. Veuillez l\'autoriser dans les paramètres.'**
  String callPermissionDenied(String permissions);

  /// No description provided for @callEndConfirmMessage.
  ///
  /// In fr, this message translates to:
  /// **'Voulez-vous vraiment terminer cet appel ?'**
  String get callEndConfirmMessage;

  /// No description provided for @callEndButton.
  ///
  /// In fr, this message translates to:
  /// **'Terminer'**
  String get callEndButton;

  /// No description provided for @callDeclinedStatus.
  ///
  /// In fr, this message translates to:
  /// **'Appel refusé'**
  String get callDeclinedStatus;

  /// No description provided for @callNoAnswer.
  ///
  /// In fr, this message translates to:
  /// **'Pas de réponse'**
  String get callNoAnswer;

  /// No description provided for @callEndedStatus.
  ///
  /// In fr, this message translates to:
  /// **'Appel terminé'**
  String get callEndedStatus;

  /// No description provided for @callCameraInitializing.
  ///
  /// In fr, this message translates to:
  /// **'Initialisation de la caméra...'**
  String get callCameraInitializing;

  /// No description provided for @callCameraDisabled.
  ///
  /// In fr, this message translates to:
  /// **'Caméra désactivée'**
  String get callCameraDisabled;

  /// No description provided for @callReconnectingStatus.
  ///
  /// In fr, this message translates to:
  /// **'Reconnexion en cours...'**
  String get callReconnectingStatus;

  /// No description provided for @callPleaseWait.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez patienter'**
  String get callPleaseWait;

  /// No description provided for @callReenableButton.
  ///
  /// In fr, this message translates to:
  /// **'Réactiver'**
  String get callReenableButton;

  /// No description provided for @callConnectionQuality.
  ///
  /// In fr, this message translates to:
  /// **'Qualité de connexion'**
  String get callConnectionQuality;

  /// No description provided for @callLatency.
  ///
  /// In fr, this message translates to:
  /// **'Latence'**
  String get callLatency;

  /// No description provided for @callPacketLoss.
  ///
  /// In fr, this message translates to:
  /// **'Perte de paquets'**
  String get callPacketLoss;

  /// No description provided for @callJitter.
  ///
  /// In fr, this message translates to:
  /// **'Gigue'**
  String get callJitter;

  /// No description provided for @callBandwidth.
  ///
  /// In fr, this message translates to:
  /// **'Bande passante'**
  String get callBandwidth;

  /// No description provided for @callAudioCodec.
  ///
  /// In fr, this message translates to:
  /// **'Codec audio'**
  String get callAudioCodec;

  /// No description provided for @callVideoCodec.
  ///
  /// In fr, this message translates to:
  /// **'Codec vidéo'**
  String get callVideoCodec;

  /// No description provided for @callVideoLabel.
  ///
  /// In fr, this message translates to:
  /// **'Vidéo'**
  String get callVideoLabel;

  /// No description provided for @callCloseButton.
  ///
  /// In fr, this message translates to:
  /// **'Fermer'**
  String get callCloseButton;

  /// No description provided for @callPermissionAnd.
  ///
  /// In fr, this message translates to:
  /// **'et'**
  String get callPermissionAnd;

  /// No description provided for @businessBoostVisibilityTitle.
  ///
  /// In fr, this message translates to:
  /// **'Augmentez votre visibilité'**
  String get businessBoostVisibilityTitle;

  /// No description provided for @businessBoostVisibilityDesc.
  ///
  /// In fr, this message translates to:
  /// **'Apparaissez en premier dans les résultats de recherche et attirez plus de clients.'**
  String get businessBoostVisibilityDesc;

  /// No description provided for @businessBoostTypeLabel.
  ///
  /// In fr, this message translates to:
  /// **'Type de boost'**
  String get businessBoostTypeLabel;

  /// No description provided for @businessBoostRecommended.
  ///
  /// In fr, this message translates to:
  /// **'Recommandé'**
  String get businessBoostRecommended;

  /// No description provided for @marketplaceTaxSettings.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres de taxe'**
  String get marketplaceTaxSettings;

  /// No description provided for @marketplacePreview.
  ///
  /// In fr, this message translates to:
  /// **'Aperçu'**
  String get marketplacePreview;

  /// No description provided for @marketplaceChooseCountry.
  ///
  /// In fr, this message translates to:
  /// **'Choisir un pays'**
  String get marketplaceChooseCountry;

  /// No description provided for @marketplacePhotos.
  ///
  /// In fr, this message translates to:
  /// **'Photos'**
  String get marketplacePhotos;

  /// No description provided for @marketplaceAddPhoto.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter'**
  String get marketplaceAddPhoto;

  /// No description provided for @marketplaceTitleRequired.
  ///
  /// In fr, this message translates to:
  /// **'Entrez un titre'**
  String get marketplaceTitleRequired;

  /// No description provided for @marketplaceDescriptionRequired.
  ///
  /// In fr, this message translates to:
  /// **'Entrez une description'**
  String get marketplaceDescriptionRequired;

  /// No description provided for @marketplaceSelectCountry.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionnez un pays'**
  String get marketplaceSelectCountry;

  /// No description provided for @marketplaceTaxIncluded.
  ///
  /// In fr, this message translates to:
  /// **'Le prix affiché inclut déjà la taxe'**
  String get marketplaceTaxIncluded;

  /// No description provided for @marketplaceTaxAdded.
  ///
  /// In fr, this message translates to:
  /// **'La taxe sera ajoutée au prix affiché'**
  String get marketplaceTaxAdded;

  /// No description provided for @marketplaceErrorWithMessage.
  ///
  /// In fr, this message translates to:
  /// **'Erreur: {error}'**
  String marketplaceErrorWithMessage(String error);

  /// No description provided for @marketplaceNoResultFor.
  ///
  /// In fr, this message translates to:
  /// **'Aucun résultat pour \"{query}\"'**
  String marketplaceNoResultFor(String query);

  /// No description provided for @marketplaceNoProductAvailable.
  ///
  /// In fr, this message translates to:
  /// **'Aucun produit disponible'**
  String get marketplaceNoProductAvailable;

  /// No description provided for @marketplaceBeFirstToSell.
  ///
  /// In fr, this message translates to:
  /// **'Soyez le premier à vendre!'**
  String get marketplaceBeFirstToSell;

  /// No description provided for @marketplaceTodayLabel.
  ///
  /// In fr, this message translates to:
  /// **'Aujourd\'hui'**
  String get marketplaceTodayLabel;

  /// No description provided for @marketplaceYesterdayLabel.
  ///
  /// In fr, this message translates to:
  /// **'Hier'**
  String get marketplaceYesterdayLabel;

  /// No description provided for @marketplaceDaysAgoLabel.
  ///
  /// In fr, this message translates to:
  /// **'Il y a {days} jours'**
  String marketplaceDaysAgoLabel(int days);

  /// No description provided for @marketplaceWeeksAgoLabel.
  ///
  /// In fr, this message translates to:
  /// **'Il y a {weeks} semaine(s)'**
  String marketplaceWeeksAgoLabel(int weeks);

  /// No description provided for @marketplaceMonthsAgoLabel.
  ///
  /// In fr, this message translates to:
  /// **'Il y a {months} mois'**
  String marketplaceMonthsAgoLabel(int months);

  /// No description provided for @marketplaceUserNotConnected.
  ///
  /// In fr, this message translates to:
  /// **'Utilisateur non connecté'**
  String get marketplaceUserNotConnected;

  /// No description provided for @marketplaceAllCountries.
  ///
  /// In fr, this message translates to:
  /// **'Tous les pays'**
  String get marketplaceAllCountries;

  /// No description provided for @mapSimpleTestTitle.
  ///
  /// In fr, this message translates to:
  /// **'Test Carte Simple'**
  String get mapSimpleTestTitle;

  /// No description provided for @businessBoostStartingFrom.
  ///
  /// In fr, this message translates to:
  /// **'À partir de'**
  String get businessBoostStartingFrom;

  /// No description provided for @businessBoostDurationLabel.
  ///
  /// In fr, this message translates to:
  /// **'Durée'**
  String get businessBoostDurationLabel;

  /// No description provided for @businessBoostSavings25.
  ///
  /// In fr, this message translates to:
  /// **'~25% économisé'**
  String get businessBoostSavings25;

  /// No description provided for @businessBoostSavings42.
  ///
  /// In fr, this message translates to:
  /// **'~42% économisé'**
  String get businessBoostSavings42;

  /// No description provided for @businessBoostBuyFor.
  ///
  /// In fr, this message translates to:
  /// **'Acheter pour'**
  String get businessBoostBuyFor;

  /// No description provided for @businessBoostNote.
  ///
  /// In fr, this message translates to:
  /// **'Note: Le boost sera actif immédiatement après le paiement.'**
  String get businessBoostNote;

  /// No description provided for @businessNameRequiredError.
  ///
  /// In fr, this message translates to:
  /// **'Le nom est requis'**
  String get businessNameRequiredError;

  /// No description provided for @businessDescriptionRequiredError.
  ///
  /// In fr, this message translates to:
  /// **'La description est requise'**
  String get businessDescriptionRequiredError;

  /// No description provided for @businessSelectCountry.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionner un pays'**
  String get businessSelectCountry;

  /// No description provided for @businessSearchCountryPlaceholder.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un pays'**
  String get businessSearchCountryPlaceholder;

  /// No description provided for @businessTypeCountryName.
  ///
  /// In fr, this message translates to:
  /// **'Tapez le nom du pays'**
  String get businessTypeCountryName;

  /// No description provided for @reviewHelpful.
  ///
  /// In fr, this message translates to:
  /// **'Utile'**
  String get reviewHelpful;

  /// No description provided for @reviewHelpfulCount.
  ///
  /// In fr, this message translates to:
  /// **'Utile ({count})'**
  String reviewHelpfulCount(int count);

  /// No description provided for @reviewPleaseWriteReview.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez écrire un avis'**
  String get reviewPleaseWriteReview;

  /// No description provided for @reviewModifiedSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Avis modifié avec succès'**
  String get reviewModifiedSuccess;

  /// No description provided for @reviewPublishedSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Avis publié avec succès'**
  String get reviewPublishedSuccess;

  /// No description provided for @reviewWriteTitle.
  ///
  /// In fr, this message translates to:
  /// **'Écrire un avis'**
  String get reviewWriteTitle;

  /// No description provided for @reviewModifyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Modifier votre avis'**
  String get reviewModifyTitle;

  /// No description provided for @reviewYourRating.
  ///
  /// In fr, this message translates to:
  /// **'Votre note'**
  String get reviewYourRating;

  /// No description provided for @reviewPublish.
  ///
  /// In fr, this message translates to:
  /// **'Publier'**
  String get reviewPublish;

  /// No description provided for @reviewPhotosCount.
  ///
  /// In fr, this message translates to:
  /// **'Photos ({current}/{max})'**
  String reviewPhotosCount(int current, int max);

  /// No description provided for @activateCamera.
  ///
  /// In fr, this message translates to:
  /// **'Activer'**
  String get activateCamera;

  /// No description provided for @deactivateCamera.
  ///
  /// In fr, this message translates to:
  /// **'Désactiver'**
  String get deactivateCamera;

  /// No description provided for @minAmountIs.
  ///
  /// In fr, this message translates to:
  /// **'Le montant minimum est'**
  String get minAmountIs;

  /// No description provided for @maxAmountIs.
  ///
  /// In fr, this message translates to:
  /// **'Le montant maximum est'**
  String get maxAmountIs;

  /// No description provided for @heritageLanguageType.
  ///
  /// In fr, this message translates to:
  /// **'Langue'**
  String get heritageLanguageType;

  /// No description provided for @groupNameExample.
  ///
  /// In fr, this message translates to:
  /// **'Ex: Entrepreneurs Niger'**
  String get groupNameExample;

  /// No description provided for @groupNameIsRequired.
  ///
  /// In fr, this message translates to:
  /// **'Le nom est requis'**
  String get groupNameIsRequired;

  /// No description provided for @groupNameMinLength.
  ///
  /// In fr, this message translates to:
  /// **'Le nom doit contenir au moins 3 caractères'**
  String get groupNameMinLength;

  /// No description provided for @descriptionIsRequired.
  ///
  /// In fr, this message translates to:
  /// **'La description est requise'**
  String get descriptionIsRequired;

  /// No description provided for @hostCountryHint.
  ///
  /// In fr, this message translates to:
  /// **'Le pays où se trouve la communauté du groupe'**
  String get hostCountryHint;

  /// No description provided for @none.
  ///
  /// In fr, this message translates to:
  /// **'Aucun'**
  String get none;

  /// No description provided for @regionOriginHint.
  ///
  /// In fr, this message translates to:
  /// **'Pour regrouper les membres par région d\'origine'**
  String get regionOriginHint;

  /// No description provided for @detailedLocationExample.
  ///
  /// In fr, this message translates to:
  /// **'Ex: Paris 18e, Île-de-France'**
  String get detailedLocationExample;

  /// No description provided for @tagsExample.
  ///
  /// In fr, this message translates to:
  /// **'Ex: business, networking, tech'**
  String get tagsExample;

  /// No description provided for @tagsSeparatedByCommas.
  ///
  /// In fr, this message translates to:
  /// **'Séparez les tags par des virgules'**
  String get tagsSeparatedByCommas;

  /// No description provided for @privateGroupLabel.
  ///
  /// In fr, this message translates to:
  /// **'Groupe privé'**
  String get privateGroupLabel;

  /// No description provided for @membersMustBeApproved.
  ///
  /// In fr, this message translates to:
  /// **'Les membres doivent être approuvés'**
  String get membersMustBeApproved;

  /// No description provided for @modifyTheGroup.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le groupe'**
  String get modifyTheGroup;

  /// No description provided for @noPendingRequests.
  ///
  /// In fr, this message translates to:
  /// **'Aucune demande en attente'**
  String get noPendingRequests;

  /// No description provided for @membershipRequestsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Demandes d\'adhésion'**
  String get membershipRequestsTitle;

  /// No description provided for @requestApprovedSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Demande approuvée'**
  String get requestApprovedSuccess;

  /// No description provided for @requestRejectedSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Demande refusée'**
  String get requestRejectedSuccess;

  /// No description provided for @rejectAction.
  ///
  /// In fr, this message translates to:
  /// **'Refuser'**
  String get rejectAction;

  /// No description provided for @approveAction.
  ///
  /// In fr, this message translates to:
  /// **'Approuver'**
  String get approveAction;

  /// No description provided for @promoteToAdmin.
  ///
  /// In fr, this message translates to:
  /// **'Promouvoir Admin'**
  String get promoteToAdmin;

  /// No description provided for @removeFromGroup.
  ///
  /// In fr, this message translates to:
  /// **'Retirer du groupe'**
  String get removeFromGroup;

  /// No description provided for @confirmRemoveMember.
  ///
  /// In fr, this message translates to:
  /// **'Voulez-vous vraiment retirer ce membre du groupe ?'**
  String get confirmRemoveMember;

  /// No description provided for @memberPromotedAdmin.
  ///
  /// In fr, this message translates to:
  /// **'Membre promu admin'**
  String get memberPromotedAdmin;

  /// No description provided for @promoteError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la promotion'**
  String get promoteError;

  /// No description provided for @memberDemotedAdmin.
  ///
  /// In fr, this message translates to:
  /// **'Admin rétrogradé'**
  String get memberDemotedAdmin;

  /// No description provided for @demoteError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la rétrogradation'**
  String get demoteError;

  /// No description provided for @memberRemovedFromGroup.
  ///
  /// In fr, this message translates to:
  /// **'Membre retiré du groupe'**
  String get memberRemovedFromGroup;

  /// No description provided for @removalError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la suppression'**
  String get removalError;

  /// No description provided for @confirmTitle.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer'**
  String get confirmTitle;

  /// No description provided for @viewAllMembers.
  ///
  /// In fr, this message translates to:
  /// **'Voir tous les {count} membres'**
  String viewAllMembers(int count);

  /// No description provided for @allFeminine.
  ///
  /// In fr, this message translates to:
  /// **'Toutes'**
  String get allFeminine;

  /// No description provided for @originRegionLabel.
  ///
  /// In fr, this message translates to:
  /// **'Région d\'origine'**
  String get originRegionLabel;

  /// No description provided for @toutes.
  ///
  /// In fr, this message translates to:
  /// **'Toutes'**
  String get toutes;

  /// No description provided for @groupCreationSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Groupe créé avec succès'**
  String get groupCreationSuccess;

  /// No description provided for @requester.
  ///
  /// In fr, this message translates to:
  /// **'Demandeur'**
  String get requester;

  /// No description provided for @podcastsAddCover.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une couverture'**
  String get podcastsAddCover;

  /// No description provided for @podcastsCategoryRequired.
  ///
  /// In fr, this message translates to:
  /// **'Catégorie *'**
  String get podcastsCategoryRequired;

  /// No description provided for @podcastsLanguageRequired.
  ///
  /// In fr, this message translates to:
  /// **'Langue *'**
  String get podcastsLanguageRequired;

  /// No description provided for @podcastsPublicationFrequency.
  ///
  /// In fr, this message translates to:
  /// **'Fréquence de publication'**
  String get podcastsPublicationFrequency;

  /// No description provided for @podcastsAddTag.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un tag'**
  String get podcastsAddTag;

  /// No description provided for @podcastsNewEpisodeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Nouvel épisode'**
  String get podcastsNewEpisodeTitle;

  /// No description provided for @podcastsAddChapterDialog.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un chapitre'**
  String get podcastsAddChapterDialog;

  /// No description provided for @podcastsChapterTitleLabel.
  ///
  /// In fr, this message translates to:
  /// **'Titre du chapitre'**
  String get podcastsChapterTitleLabel;

  /// No description provided for @podcastsMinutes.
  ///
  /// In fr, this message translates to:
  /// **'Minutes'**
  String get podcastsMinutes;

  /// No description provided for @podcastsSeconds.
  ///
  /// In fr, this message translates to:
  /// **'Secondes'**
  String get podcastsSeconds;

  /// No description provided for @podcastsAdd.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter'**
  String get podcastsAdd;

  /// No description provided for @podcastsSelectAudioFile.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez sélectionner un fichier audio'**
  String get podcastsSelectAudioFile;

  /// No description provided for @podcastsEpisodePublished.
  ///
  /// In fr, this message translates to:
  /// **'Épisode publié avec succès!'**
  String get podcastsEpisodePublished;

  /// No description provided for @podcastsAudioFileTitle.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionner un fichier audio'**
  String get podcastsAudioFileTitle;

  /// No description provided for @podcastsFileSelected.
  ///
  /// In fr, this message translates to:
  /// **'Fichier sélectionné'**
  String get podcastsFileSelected;

  /// No description provided for @podcastsNoChaptersAdded.
  ///
  /// In fr, this message translates to:
  /// **'Aucun chapitre ajouté'**
  String get podcastsNoChaptersAdded;

  /// No description provided for @podcastsErrorNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Erreur: {error}'**
  String podcastsErrorNotFound(String error);

  /// No description provided for @podcastsNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Podcast non trouvé'**
  String get podcastsNotFound;

  /// No description provided for @podcastsEpisodeNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Épisode non trouvé'**
  String get podcastsEpisodeNotFound;

  /// No description provided for @podcastsBy.
  ///
  /// In fr, this message translates to:
  /// **'Par {name}'**
  String podcastsBy(String name);

  /// No description provided for @podcastsAbout.
  ///
  /// In fr, this message translates to:
  /// **'À propos'**
  String get podcastsAbout;

  /// No description provided for @podcastsNoEpisodes.
  ///
  /// In fr, this message translates to:
  /// **'Aucun épisode disponible'**
  String get podcastsNoEpisodes;

  /// No description provided for @podcastsDescriptionNotes.
  ///
  /// In fr, this message translates to:
  /// **'Description / Notes'**
  String get podcastsDescriptionNotes;

  /// No description provided for @podcastsLikeAction.
  ///
  /// In fr, this message translates to:
  /// **'J\'aime'**
  String get podcastsLikeAction;

  /// No description provided for @podcastsDownloadInProgress.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargement en cours'**
  String get podcastsDownloadInProgress;

  /// No description provided for @podcastsSleepTimerTitle.
  ///
  /// In fr, this message translates to:
  /// **'Minuterie de sommeil'**
  String get podcastsSleepTimerTitle;

  /// No description provided for @podcastsSleepTimerDisabled.
  ///
  /// In fr, this message translates to:
  /// **'Désactivé'**
  String get podcastsSleepTimerDisabled;

  /// No description provided for @podcastsSleepTimer15.
  ///
  /// In fr, this message translates to:
  /// **'15 minutes'**
  String get podcastsSleepTimer15;

  /// No description provided for @podcastsSleepTimer30.
  ///
  /// In fr, this message translates to:
  /// **'30 minutes'**
  String get podcastsSleepTimer30;

  /// No description provided for @podcastsSleepTimer45.
  ///
  /// In fr, this message translates to:
  /// **'45 minutes'**
  String get podcastsSleepTimer45;

  /// No description provided for @podcastsSleepTimer60.
  ///
  /// In fr, this message translates to:
  /// **'1 heure'**
  String get podcastsSleepTimer60;

  /// No description provided for @podcastsSleepTimerEnd.
  ///
  /// In fr, this message translates to:
  /// **'Fin de l\'épisode'**
  String get podcastsSleepTimerEnd;

  /// No description provided for @podcastsSleepTimerActivated.
  ///
  /// In fr, this message translates to:
  /// **'Arrêt à la fin de l\'épisode activé'**
  String get podcastsSleepTimerActivated;

  /// No description provided for @podcastsSleepTimerFinished.
  ///
  /// In fr, this message translates to:
  /// **'Minuterie de sommeil terminée'**
  String get podcastsSleepTimerFinished;

  /// No description provided for @podcastsSleepTimerSet.
  ///
  /// In fr, this message translates to:
  /// **'Minuterie: {minutes} minutes'**
  String podcastsSleepTimerSet(int minutes);

  /// No description provided for @podcastsEpisodeNumber.
  ///
  /// In fr, this message translates to:
  /// **'Épisode {number}'**
  String podcastsEpisodeNumber(int number);

  /// No description provided for @podcastsLiveLabel.
  ///
  /// In fr, this message translates to:
  /// **'Live'**
  String get podcastsLiveLabel;

  /// No description provided for @podcastsDownloaded.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargé'**
  String get podcastsDownloaded;

  /// No description provided for @podcastsAvailableOffline.
  ///
  /// In fr, this message translates to:
  /// **'Disponible hors-ligne'**
  String get podcastsAvailableOffline;

  /// No description provided for @podcastsDeleteDownload.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le téléchargement'**
  String get podcastsDeleteDownload;

  /// No description provided for @podcastsDownloadDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargement supprimé'**
  String get podcastsDownloadDeleted;

  /// No description provided for @podcastsSaveAsPodcast.
  ///
  /// In fr, this message translates to:
  /// **'Sauver comme Podcast'**
  String get podcastsSaveAsPodcast;

  /// No description provided for @podcastsSaveAsPodcastDesc.
  ///
  /// In fr, this message translates to:
  /// **'Publiez l\'enregistrement de ce salon comme épisode de podcast'**
  String get podcastsSaveAsPodcastDesc;

  /// No description provided for @podcastsSelectPodcast.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionner un podcast'**
  String get podcastsSelectPodcast;

  /// No description provided for @podcastsSelectOrCreate.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionnez un podcast ou créez-en un nouveau'**
  String get podcastsSelectOrCreate;

  /// No description provided for @podcastsRecordingSoon.
  ///
  /// In fr, this message translates to:
  /// **'L\'enregistrement du salon sera bientôt disponible'**
  String get podcastsRecordingSoon;

  /// No description provided for @podcastsAudioFileNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Fichier audio introuvable'**
  String get podcastsAudioFileNotFound;

  /// No description provided for @podcastsEpisodeTitleInput.
  ///
  /// In fr, this message translates to:
  /// **'Titre de l\'épisode'**
  String get podcastsEpisodeTitleInput;

  /// No description provided for @podcastsEpisodeDescriptionInput.
  ///
  /// In fr, this message translates to:
  /// **'Description de l\'épisode (optionnel)'**
  String get podcastsEpisodeDescriptionInput;

  /// No description provided for @podcastsSourceRoom.
  ///
  /// In fr, this message translates to:
  /// **'Salon source'**
  String get podcastsSourceRoom;

  /// No description provided for @podcastsPublish.
  ///
  /// In fr, this message translates to:
  /// **'Publier'**
  String get podcastsPublish;

  /// No description provided for @podcastsNoPodcastsYet.
  ///
  /// In fr, this message translates to:
  /// **'Vous n\'avez pas encore de podcast'**
  String get podcastsNoPodcastsYet;

  /// No description provided for @podcastsCreateFirstPodcast.
  ///
  /// In fr, this message translates to:
  /// **'Créez votre premier podcast pour pouvoir y ajouter des épisodes'**
  String get podcastsCreateFirstPodcast;

  /// No description provided for @podcastsCreateNewPodcast.
  ///
  /// In fr, this message translates to:
  /// **'Créer un nouveau podcast'**
  String get podcastsCreateNewPodcast;

  /// No description provided for @podcastsStartSeries.
  ///
  /// In fr, this message translates to:
  /// **'Commencez votre série de podcasts'**
  String get podcastsStartSeries;

  /// No description provided for @notificationReplySent.
  ///
  /// In fr, this message translates to:
  /// **'Message envoyé'**
  String get notificationReplySent;

  /// No description provided for @notificationReplyConfirmation.
  ///
  /// In fr, this message translates to:
  /// **'Votre réponse a été envoyée'**
  String get notificationReplyConfirmation;

  /// No description provided for @notificationPendingMessage.
  ///
  /// In fr, this message translates to:
  /// **'Message en attente'**
  String get notificationPendingMessage;

  /// No description provided for @notificationPendingReply.
  ///
  /// In fr, this message translates to:
  /// **'Votre réponse sera envoyée dès que possible'**
  String get notificationPendingReply;

  /// No description provided for @notificationIncomingVideoCall.
  ///
  /// In fr, this message translates to:
  /// **'Appel vidéo entrant...'**
  String get notificationIncomingVideoCall;

  /// No description provided for @notificationIncomingAudioCall.
  ///
  /// In fr, this message translates to:
  /// **'Appel vocal entrant...'**
  String get notificationIncomingAudioCall;

  /// No description provided for @notificationAnswerAction.
  ///
  /// In fr, this message translates to:
  /// **'Répondre'**
  String get notificationAnswerAction;

  /// No description provided for @notificationDeclineAction.
  ///
  /// In fr, this message translates to:
  /// **'Refuser'**
  String get notificationDeclineAction;

  /// No description provided for @notificationReplyAction.
  ///
  /// In fr, this message translates to:
  /// **'Répondre'**
  String get notificationReplyAction;

  /// No description provided for @notificationMarkReadAction.
  ///
  /// In fr, this message translates to:
  /// **'Marquer comme lu'**
  String get notificationMarkReadAction;

  /// No description provided for @notificationSendButton.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer'**
  String get notificationSendButton;

  /// No description provided for @notificationTypePlaceholder.
  ///
  /// In fr, this message translates to:
  /// **'Tapez votre réponse...'**
  String get notificationTypePlaceholder;

  /// No description provided for @notificationCallsChannel.
  ///
  /// In fr, this message translates to:
  /// **'Appels'**
  String get notificationCallsChannel;

  /// No description provided for @notificationCallsDescription.
  ///
  /// In fr, this message translates to:
  /// **'Notifications pour les appels entrants'**
  String get notificationCallsDescription;

  /// No description provided for @notificationUnknownCaller.
  ///
  /// In fr, this message translates to:
  /// **'Inconnu'**
  String get notificationUnknownCaller;

  /// No description provided for @taxExemptBySeller.
  ///
  /// In fr, this message translates to:
  /// **'Exonéré par le vendeur'**
  String get taxExemptBySeller;

  /// No description provided for @sharedMedia.
  ///
  /// In fr, this message translates to:
  /// **'Médias partagés'**
  String get sharedMedia;

  /// No description provided for @thisWeek.
  ///
  /// In fr, this message translates to:
  /// **'Cette semaine'**
  String get thisWeek;

  /// No description provided for @lastWeek.
  ///
  /// In fr, this message translates to:
  /// **'La semaine dernière'**
  String get lastWeek;

  /// No description provided for @thisMonth.
  ///
  /// In fr, this message translates to:
  /// **'Ce mois-ci'**
  String get thisMonth;

  /// No description provided for @sharedPhotosWillAppear.
  ///
  /// In fr, this message translates to:
  /// **'Les photos partagées apparaîtront ici'**
  String get sharedPhotosWillAppear;

  /// No description provided for @sharedFilesWillAppear.
  ///
  /// In fr, this message translates to:
  /// **'Les fichiers partagés apparaîtront ici'**
  String get sharedFilesWillAppear;

  /// No description provided for @otherMembers.
  ///
  /// In fr, this message translates to:
  /// **'Autres membres'**
  String get otherMembers;

  /// No description provided for @imagePreview.
  ///
  /// In fr, this message translates to:
  /// **'Aperçu de l\'image'**
  String get imagePreview;

  /// No description provided for @videoPreview.
  ///
  /// In fr, this message translates to:
  /// **'Aperçu de la vidéo'**
  String get videoPreview;

  /// No description provided for @documentPreview.
  ///
  /// In fr, this message translates to:
  /// **'Aperçu du document'**
  String get documentPreview;

  /// No description provided for @conversationBackground.
  ///
  /// In fr, this message translates to:
  /// **'Fond de conversation'**
  String get conversationBackground;

  /// No description provided for @defaultBackground.
  ///
  /// In fr, this message translates to:
  /// **'Fond par défaut'**
  String get defaultBackground;

  /// No description provided for @colors.
  ///
  /// In fr, this message translates to:
  /// **'Couleurs'**
  String get colors;

  /// No description provided for @defaultTheme.
  ///
  /// In fr, this message translates to:
  /// **'Thème par défaut'**
  String get defaultTheme;

  /// No description provided for @imageSelected.
  ///
  /// In fr, this message translates to:
  /// **'Image sélectionnée'**
  String get imageSelected;

  /// No description provided for @chooseImage.
  ///
  /// In fr, this message translates to:
  /// **'Choisir une image'**
  String get chooseImage;

  /// No description provided for @errorImageSelection.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la sélection de l\'image: {error}'**
  String errorImageSelection(String error);

  /// No description provided for @errorApplication.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de l\'application: {error}'**
  String errorApplication(String error);

  /// No description provided for @receivedMessage.
  ///
  /// In fr, this message translates to:
  /// **'Message reçu'**
  String get receivedMessage;

  /// No description provided for @sentMessage.
  ///
  /// In fr, this message translates to:
  /// **'Message envoyé'**
  String get sentMessage;

  /// No description provided for @messageDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Message supprimé'**
  String get messageDeleted;

  /// No description provided for @photo.
  ///
  /// In fr, this message translates to:
  /// **'Photo'**
  String get photo;

  /// No description provided for @video.
  ///
  /// In fr, this message translates to:
  /// **'Vidéo'**
  String get video;

  /// No description provided for @audio.
  ///
  /// In fr, this message translates to:
  /// **'Audio'**
  String get audio;

  /// No description provided for @document.
  ///
  /// In fr, this message translates to:
  /// **'Document'**
  String get document;

  /// No description provided for @systemMessage.
  ///
  /// In fr, this message translates to:
  /// **'Message système'**
  String get systemMessage;

  /// No description provided for @call.
  ///
  /// In fr, this message translates to:
  /// **'Appel'**
  String get call;

  /// No description provided for @pending.
  ///
  /// In fr, this message translates to:
  /// **'En attente'**
  String get pending;

  /// No description provided for @sharedLocation.
  ///
  /// In fr, this message translates to:
  /// **'Localisation partagée'**
  String get sharedLocation;

  /// No description provided for @embassyTemporarilyClosed.
  ///
  /// In fr, this message translates to:
  /// **'Temporairement fermé'**
  String get embassyTemporarilyClosed;

  /// No description provided for @embassyOfficialVerified.
  ///
  /// In fr, this message translates to:
  /// **'Compte Officiel Vérifié'**
  String get embassyOfficialVerified;

  /// No description provided for @embassyComingSoon.
  ///
  /// In fr, this message translates to:
  /// **'Bientôt disponible'**
  String get embassyComingSoon;

  /// No description provided for @embassyConsularServices.
  ///
  /// In fr, this message translates to:
  /// **'Services Consulaires'**
  String get embassyConsularServices;

  /// No description provided for @embassyOpeningHours.
  ///
  /// In fr, this message translates to:
  /// **'Horaires d\'ouverture'**
  String get embassyOpeningHours;

  /// No description provided for @embassyJurisdiction.
  ///
  /// In fr, this message translates to:
  /// **'Juridiction'**
  String get embassyJurisdiction;

  /// No description provided for @embassyJurisdictionDescription.
  ///
  /// In fr, this message translates to:
  /// **'Cette ambassade dessert les ressortissants se trouvant dans: '**
  String get embassyJurisdictionDescription;

  /// No description provided for @embassyNoActivities.
  ///
  /// In fr, this message translates to:
  /// **'Aucune activité prévue pour le moment.'**
  String get embassyNoActivities;

  /// No description provided for @embassyNoNews.
  ///
  /// In fr, this message translates to:
  /// **'Aucune actualité disponible.'**
  String get embassyNoNews;

  /// No description provided for @embassyInfoTab.
  ///
  /// In fr, this message translates to:
  /// **'Infos'**
  String get embassyInfoTab;

  /// No description provided for @embassyActivitiesTab.
  ///
  /// In fr, this message translates to:
  /// **'Activités'**
  String get embassyActivitiesTab;

  /// No description provided for @embassyNewsTab.
  ///
  /// In fr, this message translates to:
  /// **'Actualités'**
  String get embassyNewsTab;

  /// No description provided for @embassyFormPrefilledNotice.
  ///
  /// In fr, this message translates to:
  /// **'Formulaire pré-rempli à partir de votre profil. Veuillez vérifier et compléter les informations.'**
  String get embassyFormPrefilledNotice;

  /// No description provided for @embassyRequestType.
  ///
  /// In fr, this message translates to:
  /// **'Type de demande *'**
  String get embassyRequestType;

  /// No description provided for @embassyPersonalInfo.
  ///
  /// In fr, this message translates to:
  /// **'Informations personnelles'**
  String get embassyPersonalInfo;

  /// No description provided for @embassyFullName.
  ///
  /// In fr, this message translates to:
  /// **'Nom complet *'**
  String get embassyFullName;

  /// No description provided for @embassyDateOfBirth.
  ///
  /// In fr, this message translates to:
  /// **'Date de naissance *'**
  String get embassyDateOfBirth;

  /// No description provided for @embassyDateFormat.
  ///
  /// In fr, this message translates to:
  /// **'JJ/MM/AAAA'**
  String get embassyDateFormat;

  /// No description provided for @embassyPlaceOfBirth.
  ///
  /// In fr, this message translates to:
  /// **'Lieu de naissance'**
  String get embassyPlaceOfBirth;

  /// No description provided for @embassyNationality.
  ///
  /// In fr, this message translates to:
  /// **'Nationalité'**
  String get embassyNationality;

  /// No description provided for @embassyNigerien.
  ///
  /// In fr, this message translates to:
  /// **'Nigérienne'**
  String get embassyNigerien;

  /// No description provided for @embassyCurrentAddress.
  ///
  /// In fr, this message translates to:
  /// **'Adresse actuelle *'**
  String get embassyCurrentAddress;

  /// No description provided for @embassyContactSection.
  ///
  /// In fr, this message translates to:
  /// **'Contact'**
  String get embassyContactSection;

  /// No description provided for @embassyPhone.
  ///
  /// In fr, this message translates to:
  /// **'Téléphone *'**
  String get embassyPhone;

  /// No description provided for @embassyEmailField.
  ///
  /// In fr, this message translates to:
  /// **'Email'**
  String get embassyEmailField;

  /// No description provided for @embassyPassportInfo.
  ///
  /// In fr, this message translates to:
  /// **'Informations du passeport'**
  String get embassyPassportInfo;

  /// No description provided for @embassyPassportNumber.
  ///
  /// In fr, this message translates to:
  /// **'N° de passeport'**
  String get embassyPassportNumber;

  /// No description provided for @embassyPassportExpiry.
  ///
  /// In fr, this message translates to:
  /// **'Date d\'expiration'**
  String get embassyPassportExpiry;

  /// No description provided for @embassyNotesSection.
  ///
  /// In fr, this message translates to:
  /// **'Remarques / Informations complémentaires'**
  String get embassyNotesSection;

  /// No description provided for @embassyNotesPlaceholder.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez des détails supplémentaires si nécessaire...'**
  String get embassyNotesPlaceholder;

  /// No description provided for @embassyCharacterCount.
  ///
  /// In fr, this message translates to:
  /// **'{count} caractères'**
  String embassyCharacterCount(int count);

  /// No description provided for @embassyWarningMessage.
  ///
  /// In fr, this message translates to:
  /// **'Vous devrez peut-être vous rendre à l\'ambassade avec les documents originaux. Conservez votre numéro de suivi.'**
  String get embassyWarningMessage;

  /// No description provided for @embassySending.
  ///
  /// In fr, this message translates to:
  /// **'Envoi...'**
  String get embassySending;

  /// No description provided for @embassySubmitRequest.
  ///
  /// In fr, this message translates to:
  /// **'Soumettre la demande'**
  String get embassySubmitRequest;

  /// No description provided for @embassyFieldRequired.
  ///
  /// In fr, this message translates to:
  /// **'Champ obligatoire'**
  String get embassyFieldRequired;

  /// No description provided for @embassyFieldRequiredShort.
  ///
  /// In fr, this message translates to:
  /// **'Obligatoire'**
  String get embassyFieldRequiredShort;

  /// No description provided for @embassyUserNotConnected.
  ///
  /// In fr, this message translates to:
  /// **'Utilisateur non connecté'**
  String get embassyUserNotConnected;

  /// No description provided for @embassyErrorPrefix.
  ///
  /// In fr, this message translates to:
  /// **'Erreur: {error}'**
  String embassyErrorPrefix(String error);

  /// No description provided for @embassyPassportRenewal.
  ///
  /// In fr, this message translates to:
  /// **'Renouvellement de passeport'**
  String get embassyPassportRenewal;

  /// No description provided for @embassyPassportNewRequest.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle demande de passeport'**
  String get embassyPassportNewRequest;

  /// No description provided for @embassyVisaApplication.
  ///
  /// In fr, this message translates to:
  /// **'Demande de visa'**
  String get embassyVisaApplication;

  /// No description provided for @embassyBirthCertificate.
  ///
  /// In fr, this message translates to:
  /// **'Acte de naissance'**
  String get embassyBirthCertificate;

  /// No description provided for @embassyMarriageCertificate.
  ///
  /// In fr, this message translates to:
  /// **'Acte de mariage'**
  String get embassyMarriageCertificate;

  /// No description provided for @embassyDeathCertificate.
  ///
  /// In fr, this message translates to:
  /// **'Acte de décès'**
  String get embassyDeathCertificate;

  /// No description provided for @embassyConsularId.
  ///
  /// In fr, this message translates to:
  /// **'Carte consulaire'**
  String get embassyConsularId;

  /// No description provided for @embassyLegalDocument.
  ///
  /// In fr, this message translates to:
  /// **'Document légal'**
  String get embassyLegalDocument;

  /// No description provided for @embassyLaissezPasser.
  ///
  /// In fr, this message translates to:
  /// **'Laissez-passer'**
  String get embassyLaissezPasser;

  /// No description provided for @embassyPowerOfAttorney.
  ///
  /// In fr, this message translates to:
  /// **'Procuration'**
  String get embassyPowerOfAttorney;

  /// No description provided for @embassyInscription.
  ///
  /// In fr, this message translates to:
  /// **'Inscription consulaire'**
  String get embassyInscription;

  /// No description provided for @embassyOtherRequest.
  ///
  /// In fr, this message translates to:
  /// **'Autre demande'**
  String get embassyOtherRequest;

  /// No description provided for @embassyPassportRenewalDesc.
  ///
  /// In fr, this message translates to:
  /// **'Renouvellement d\'un passeport existant arrivant à expiration.'**
  String get embassyPassportRenewalDesc;

  /// No description provided for @embassyPassportNewRequestDesc.
  ///
  /// In fr, this message translates to:
  /// **'Première demande de passeport ou remplacement d\'un passeport perdu/volé.'**
  String get embassyPassportNewRequestDesc;

  /// No description provided for @embassyVisaApplicationDesc.
  ///
  /// In fr, this message translates to:
  /// **'Demande de visa pour les ressortissants étrangers.'**
  String get embassyVisaApplicationDesc;

  /// No description provided for @embassyBirthCertificateDesc.
  ///
  /// In fr, this message translates to:
  /// **'Copie ou extrait d\'acte de naissance.'**
  String get embassyBirthCertificateDesc;

  /// No description provided for @embassyMarriageCertificateDesc.
  ///
  /// In fr, this message translates to:
  /// **'Copie ou extrait d\'acte de mariage.'**
  String get embassyMarriageCertificateDesc;

  /// No description provided for @embassyDeathCertificateDesc.
  ///
  /// In fr, this message translates to:
  /// **'Copie ou extrait d\'acte de décès.'**
  String get embassyDeathCertificateDesc;

  /// No description provided for @embassyConsularIdDesc.
  ///
  /// In fr, this message translates to:
  /// **'Carte d\'immatriculation consulaire pour les ressortissants nigériens.'**
  String get embassyConsularIdDesc;

  /// No description provided for @embassyLegalDocumentDesc.
  ///
  /// In fr, this message translates to:
  /// **'Légalisation ou certification de documents officiels.'**
  String get embassyLegalDocumentDesc;

  /// No description provided for @embassyLaissezPasserDesc.
  ///
  /// In fr, this message translates to:
  /// **'Document de voyage temporaire en cas de perte de passeport.'**
  String get embassyLaissezPasserDesc;

  /// No description provided for @embassyPowerOfAttorneyDesc.
  ///
  /// In fr, this message translates to:
  /// **'Procuration pour représentation légale.'**
  String get embassyPowerOfAttorneyDesc;

  /// No description provided for @embassyInscriptionDesc.
  ///
  /// In fr, this message translates to:
  /// **'Inscription au registre des Nigériens à l\'étranger.'**
  String get embassyInscriptionDesc;

  /// No description provided for @embassyOtherRequestDesc.
  ///
  /// In fr, this message translates to:
  /// **'Autre type de demande administrative.'**
  String get embassyOtherRequestDesc;

  /// No description provided for @embassyMessageType.
  ///
  /// In fr, this message translates to:
  /// **'Type de message'**
  String get embassyMessageType;

  /// No description provided for @embassySubject.
  ///
  /// In fr, this message translates to:
  /// **'Objet *'**
  String get embassySubject;

  /// No description provided for @embassyMessage.
  ///
  /// In fr, this message translates to:
  /// **'Message *'**
  String get embassyMessage;

  /// No description provided for @embassyMessageNote.
  ///
  /// In fr, this message translates to:
  /// **'Votre message sera transmis à l\'ambassade. Vous recevrez une notification lors de la réponse.'**
  String get embassyMessageNote;

  /// No description provided for @embassySendMessage.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer le message'**
  String get embassySendMessage;

  /// No description provided for @embassySubjectRequired.
  ///
  /// In fr, this message translates to:
  /// **'L\'objet est obligatoire'**
  String get embassySubjectRequired;

  /// No description provided for @embassySubjectMinLength.
  ///
  /// In fr, this message translates to:
  /// **'L\'objet doit contenir au moins 5 caractères'**
  String get embassySubjectMinLength;

  /// No description provided for @embassyMessageRequired.
  ///
  /// In fr, this message translates to:
  /// **'Le message est obligatoire'**
  String get embassyMessageRequired;

  /// No description provided for @embassyMessageMinLength.
  ///
  /// In fr, this message translates to:
  /// **'Le message doit contenir au moins 20 caractères'**
  String get embassyMessageMinLength;

  /// No description provided for @embassyMessageCharacterCount.
  ///
  /// In fr, this message translates to:
  /// **'{count}/1000 caractères'**
  String embassyMessageCharacterCount(int count);

  /// No description provided for @embassyMessageGeneral.
  ///
  /// In fr, this message translates to:
  /// **'Question générale'**
  String get embassyMessageGeneral;

  /// No description provided for @embassyMessageRequest.
  ///
  /// In fr, this message translates to:
  /// **'Demande de service'**
  String get embassyMessageRequest;

  /// No description provided for @embassyMessageComplaint.
  ///
  /// In fr, this message translates to:
  /// **'Réclamation'**
  String get embassyMessageComplaint;

  /// No description provided for @embassyMessageInquiry.
  ///
  /// In fr, this message translates to:
  /// **'Renseignement'**
  String get embassyMessageInquiry;

  /// No description provided for @embassyMessageFollowUp.
  ///
  /// In fr, this message translates to:
  /// **'Suivi de dossier'**
  String get embassyMessageFollowUp;

  /// No description provided for @embassySearchTitle.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un employé'**
  String get embassySearchTitle;

  /// No description provided for @embassyStaffTitle.
  ///
  /// In fr, this message translates to:
  /// **'Personnel - {name}'**
  String embassyStaffTitle(String name);

  /// No description provided for @embassyAllDepartments.
  ///
  /// In fr, this message translates to:
  /// **'Tous les départements'**
  String get embassyAllDepartments;

  /// No description provided for @embassyDepartmentDirection.
  ///
  /// In fr, this message translates to:
  /// **'Direction'**
  String get embassyDepartmentDirection;

  /// No description provided for @embassyDepartmentConsular.
  ///
  /// In fr, this message translates to:
  /// **'Services consulaires'**
  String get embassyDepartmentConsular;

  /// No description provided for @embassyDepartmentVisa.
  ///
  /// In fr, this message translates to:
  /// **'Section des visas'**
  String get embassyDepartmentVisa;

  /// No description provided for @embassyDepartmentCivilStatus.
  ///
  /// In fr, this message translates to:
  /// **'État civil'**
  String get embassyDepartmentCivilStatus;

  /// No description provided for @embassyDepartmentSocial.
  ///
  /// In fr, this message translates to:
  /// **'Affaires sociales'**
  String get embassyDepartmentSocial;

  /// No description provided for @embassyDepartmentChancellery.
  ///
  /// In fr, this message translates to:
  /// **'Chancellerie'**
  String get embassyDepartmentChancellery;

  /// No description provided for @embassyDepartmentCommunication.
  ///
  /// In fr, this message translates to:
  /// **'Communication'**
  String get embassyDepartmentCommunication;

  /// No description provided for @embassyDepartmentAdministration.
  ///
  /// In fr, this message translates to:
  /// **'Administration'**
  String get embassyDepartmentAdministration;

  /// No description provided for @embassyLoadingError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur de chargement'**
  String get embassyLoadingError;

  /// No description provided for @embassyRetry.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get embassyRetry;

  /// No description provided for @embassyNoEmployeeFound.
  ///
  /// In fr, this message translates to:
  /// **'Aucun employé trouvé'**
  String get embassyNoEmployeeFound;

  /// No description provided for @embassyModifySearch.
  ///
  /// In fr, this message translates to:
  /// **'Essayez de modifier vos critères de recherche'**
  String get embassyModifySearch;

  /// No description provided for @adminAnalyticsAndReports.
  ///
  /// In fr, this message translates to:
  /// **'Analytique & Rapports'**
  String get adminAnalyticsAndReports;

  /// No description provided for @adminAnalyticsSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Statistiques et métriques de l\'application'**
  String get adminAnalyticsSubtitle;

  /// No description provided for @adminLoadingError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur de chargement'**
  String get adminLoadingError;

  /// No description provided for @adminUserGrowth.
  ///
  /// In fr, this message translates to:
  /// **'Croissance Utilisateurs'**
  String get adminUserGrowth;

  /// No description provided for @adminToday.
  ///
  /// In fr, this message translates to:
  /// **'Aujourd\'hui'**
  String get adminToday;

  /// No description provided for @adminThisWeek.
  ///
  /// In fr, this message translates to:
  /// **'Cette semaine'**
  String get adminThisWeek;

  /// No description provided for @adminThisMonth.
  ///
  /// In fr, this message translates to:
  /// **'Ce mois'**
  String get adminThisMonth;

  /// No description provided for @adminMonthlyEvolution.
  ///
  /// In fr, this message translates to:
  /// **'Évolution Mensuelle (6 derniers mois)'**
  String get adminMonthlyEvolution;

  /// No description provided for @adminNoDataAvailable.
  ///
  /// In fr, this message translates to:
  /// **'Aucune donnée disponible'**
  String get adminNoDataAvailable;

  /// No description provided for @adminEventsByCategory.
  ///
  /// In fr, this message translates to:
  /// **'Événements par Catégorie'**
  String get adminEventsByCategory;

  /// No description provided for @adminBusinessesByCategory.
  ///
  /// In fr, this message translates to:
  /// **'Commerces par Catégorie'**
  String get adminBusinessesByCategory;

  /// No description provided for @adminNoData.
  ///
  /// In fr, this message translates to:
  /// **'Aucune donnée'**
  String get adminNoData;

  /// No description provided for @adminDataExport.
  ///
  /// In fr, this message translates to:
  /// **'Export de Données'**
  String get adminDataExport;

  /// No description provided for @adminExportUsers.
  ///
  /// In fr, this message translates to:
  /// **'Exporter Utilisateurs'**
  String get adminExportUsers;

  /// No description provided for @adminExportEvents.
  ///
  /// In fr, this message translates to:
  /// **'Exporter Événements'**
  String get adminExportEvents;

  /// No description provided for @adminExportBusinesses.
  ///
  /// In fr, this message translates to:
  /// **'Exporter Commerces'**
  String get adminExportBusinesses;

  /// No description provided for @adminExportTransactions.
  ///
  /// In fr, this message translates to:
  /// **'Exporter Transactions'**
  String get adminExportTransactions;

  /// No description provided for @adminPanelTitle.
  ///
  /// In fr, this message translates to:
  /// **'Admin Panel'**
  String get adminPanelTitle;

  /// No description provided for @adminDiaspoNigerMonitoring.
  ///
  /// In fr, this message translates to:
  /// **'DiaspoNiger Monitoring'**
  String get adminDiaspoNigerMonitoring;

  /// No description provided for @adminOrText.
  ///
  /// In fr, this message translates to:
  /// **'OR'**
  String get adminOrText;

  /// No description provided for @adminGoogleError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur de connexion Google'**
  String get adminGoogleError;

  /// No description provided for @adminAccessDeniedMessage.
  ///
  /// In fr, this message translates to:
  /// **'Accès refusé. Compte administrateur requis.'**
  String get adminAccessDeniedMessage;

  /// No description provided for @adminContentModeration.
  ///
  /// In fr, this message translates to:
  /// **'Modération de Contenu'**
  String get adminContentModeration;

  /// No description provided for @adminContentSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Gérez les événements et groupes de la communauté'**
  String get adminContentSubtitle;

  /// No description provided for @adminEventsTabCount.
  ///
  /// In fr, this message translates to:
  /// **'Événements ({count})'**
  String adminEventsTabCount(int count);

  /// No description provided for @adminGroupsTabCount.
  ///
  /// In fr, this message translates to:
  /// **'Groupes ({count})'**
  String adminGroupsTabCount(int count);

  /// No description provided for @adminLoadingContent.
  ///
  /// In fr, this message translates to:
  /// **'Chargement du contenu...'**
  String get adminLoadingContent;

  /// No description provided for @adminOrganizerLabel.
  ///
  /// In fr, this message translates to:
  /// **'Organisateur'**
  String get adminOrganizerLabel;

  /// No description provided for @adminMembersCount.
  ///
  /// In fr, this message translates to:
  /// **'membres'**
  String get adminMembersCount;

  /// No description provided for @adminCategoryLabel.
  ///
  /// In fr, this message translates to:
  /// **'Catégorie'**
  String get adminCategoryLabel;

  /// No description provided for @adminCancelAction.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get adminCancelAction;

  /// No description provided for @adminDeleteAction.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get adminDeleteAction;

  /// No description provided for @adminConfirmAction.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer'**
  String get adminConfirmAction;

  /// No description provided for @adminCancelEventTitle.
  ///
  /// In fr, this message translates to:
  /// **'Annuler l\'événement'**
  String get adminCancelEventTitle;

  /// No description provided for @adminCancelEventMsg.
  ///
  /// In fr, this message translates to:
  /// **'Êtes-vous sûr de vouloir annuler cet événement ?'**
  String get adminCancelEventMsg;

  /// No description provided for @adminDeleteEventTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer l\'événement'**
  String get adminDeleteEventTitle;

  /// No description provided for @adminDeleteEventMsg.
  ///
  /// In fr, this message translates to:
  /// **'Êtes-vous sûr de vouloir supprimer cet événement ? Cette action est irréversible.'**
  String get adminDeleteEventMsg;

  /// No description provided for @adminMakePublicAction.
  ///
  /// In fr, this message translates to:
  /// **'Rendre public'**
  String get adminMakePublicAction;

  /// No description provided for @adminMakePrivateAction.
  ///
  /// In fr, this message translates to:
  /// **'Rendre privé'**
  String get adminMakePrivateAction;

  /// No description provided for @adminEventCancelled.
  ///
  /// In fr, this message translates to:
  /// **'Événement annulé'**
  String get adminEventCancelled;

  /// No description provided for @adminEventDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Événement supprimé'**
  String get adminEventDeleted;

  /// No description provided for @adminGroupMadePublic.
  ///
  /// In fr, this message translates to:
  /// **'Groupe rendu public'**
  String get adminGroupMadePublic;

  /// No description provided for @adminGroupMadePrivate.
  ///
  /// In fr, this message translates to:
  /// **'Groupe rendu privé'**
  String get adminGroupMadePrivate;

  /// No description provided for @adminGroupDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Groupe supprimé'**
  String get adminGroupDeleted;

  /// No description provided for @adminNoEventsFound.
  ///
  /// In fr, this message translates to:
  /// **'Aucun événement trouvé'**
  String get adminNoEventsFound;

  /// No description provided for @adminNoGroupsFound.
  ///
  /// In fr, this message translates to:
  /// **'Aucun groupe trouvé'**
  String get adminNoGroupsFound;

  /// No description provided for @adminErrorNotConnected.
  ///
  /// In fr, this message translates to:
  /// **'Erreur: Admin non connecté'**
  String get adminErrorNotConnected;

  /// No description provided for @adminReportsManagement.
  ///
  /// In fr, this message translates to:
  /// **'Gestion des Signalements'**
  String get adminReportsManagement;

  /// No description provided for @adminReportsSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Traitez les signalements de contenu inapproprié'**
  String get adminReportsSubtitle;

  /// No description provided for @adminPendingLabel.
  ///
  /// In fr, this message translates to:
  /// **'En attente'**
  String get adminPendingLabel;

  /// No description provided for @adminResolvedLabel.
  ///
  /// In fr, this message translates to:
  /// **'Résolu'**
  String get adminResolvedLabel;

  /// No description provided for @adminDismissedLabel.
  ///
  /// In fr, this message translates to:
  /// **'Rejeté'**
  String get adminDismissedLabel;

  /// No description provided for @adminTotalLabel.
  ///
  /// In fr, this message translates to:
  /// **'Total'**
  String get adminTotalLabel;

  /// No description provided for @adminProcessedTabCount.
  ///
  /// In fr, this message translates to:
  /// **'Traités ({count})'**
  String adminProcessedTabCount(int count);

  /// No description provided for @adminTypeFilterLabel.
  ///
  /// In fr, this message translates to:
  /// **'Type:'**
  String get adminTypeFilterLabel;

  /// No description provided for @adminAllTypesOption.
  ///
  /// In fr, this message translates to:
  /// **'Tous'**
  String get adminAllTypesOption;

  /// No description provided for @adminReportedOnLabel.
  ///
  /// In fr, this message translates to:
  /// **'Signalé le:'**
  String get adminReportedOnLabel;

  /// No description provided for @adminTargetNameLabel.
  ///
  /// In fr, this message translates to:
  /// **'Nom'**
  String get adminTargetNameLabel;

  /// No description provided for @adminCapturedContentLabel.
  ///
  /// In fr, this message translates to:
  /// **'Contenu capturé (préservé)'**
  String get adminCapturedContentLabel;

  /// No description provided for @adminHostLabel.
  ///
  /// In fr, this message translates to:
  /// **'Hôte'**
  String get adminHostLabel;

  /// No description provided for @adminDescriptionLabel.
  ///
  /// In fr, this message translates to:
  /// **'Description'**
  String get adminDescriptionLabel;

  /// No description provided for @adminAdminNoteLabel.
  ///
  /// In fr, this message translates to:
  /// **'Note admin'**
  String get adminAdminNoteLabel;

  /// No description provided for @adminReportDismissed.
  ///
  /// In fr, this message translates to:
  /// **'Signalement rejeté'**
  String get adminReportDismissed;

  /// No description provided for @adminReportProcessed.
  ///
  /// In fr, this message translates to:
  /// **'Signalement traité'**
  String get adminReportProcessed;

  /// No description provided for @adminReportProcessedNotified.
  ///
  /// In fr, this message translates to:
  /// **'Signalement traité (utilisateur notifié)'**
  String get adminReportProcessedNotified;

  /// No description provided for @adminContentDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Contenu supprimé'**
  String get adminContentDeleted;

  /// No description provided for @adminContentDeletedNotified.
  ///
  /// In fr, this message translates to:
  /// **'Contenu supprimé (utilisateur notifié)'**
  String get adminContentDeletedNotified;

  /// No description provided for @adminDismissReportTitle.
  ///
  /// In fr, this message translates to:
  /// **'Rejeter le signalement'**
  String get adminDismissReportTitle;

  /// No description provided for @adminDismissReportPrompt.
  ///
  /// In fr, this message translates to:
  /// **'Raison du rejet:'**
  String get adminDismissReportPrompt;

  /// No description provided for @adminProcessReportTitle.
  ///
  /// In fr, this message translates to:
  /// **'Traiter le signalement'**
  String get adminProcessReportTitle;

  /// No description provided for @adminProcessReportPrompt.
  ///
  /// In fr, this message translates to:
  /// **'Note de résolution:'**
  String get adminProcessReportPrompt;

  /// No description provided for @adminDeleteContentMsg.
  ///
  /// In fr, this message translates to:
  /// **'Êtes-vous sûr de vouloir supprimer ce contenu ?'**
  String get adminDeleteContentMsg;

  /// No description provided for @adminDeleteIrreversibleMsg.
  ///
  /// In fr, this message translates to:
  /// **'Cette action est irréversible et supprimera définitivement le {type}.'**
  String adminDeleteIrreversibleMsg(String type);

  /// No description provided for @adminNoResultsSearch.
  ///
  /// In fr, this message translates to:
  /// **'Aucun résultat pour cette recherche'**
  String get adminNoResultsSearch;

  /// No description provided for @adminNoReportsAvailable.
  ///
  /// In fr, this message translates to:
  /// **'Aucun signalement'**
  String get adminNoReportsAvailable;

  /// No description provided for @adminTargetIdLabel.
  ///
  /// In fr, this message translates to:
  /// **'ID cible'**
  String get adminTargetIdLabel;

  /// No description provided for @adminReportedByLabel.
  ///
  /// In fr, this message translates to:
  /// **'Signalé par'**
  String get adminReportedByLabel;

  /// No description provided for @adminReportedUserLabel.
  ///
  /// In fr, this message translates to:
  /// **'Utilisateur signalé'**
  String get adminReportedUserLabel;

  /// No description provided for @adminLoadingReports.
  ///
  /// In fr, this message translates to:
  /// **'Chargement des signalements...'**
  String get adminLoadingReports;

  /// No description provided for @adminRejectAction.
  ///
  /// In fr, this message translates to:
  /// **'Rejeter'**
  String get adminRejectAction;

  /// No description provided for @adminProcessAction.
  ///
  /// In fr, this message translates to:
  /// **'Traiter'**
  String get adminProcessAction;

  /// No description provided for @adminDeleteContentAction.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer contenu'**
  String get adminDeleteContentAction;

  /// No description provided for @adminClearFiltersAction.
  ///
  /// In fr, this message translates to:
  /// **'Effacer les filtres'**
  String get adminClearFiltersAction;

  /// No description provided for @adminViewTheLabel.
  ///
  /// In fr, this message translates to:
  /// **'Voir le'**
  String get adminViewTheLabel;

  /// No description provided for @adminGeneralStatsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Statistiques Générales'**
  String get adminGeneralStatsTitle;

  /// No description provided for @adminActiveSessionsLabel.
  ///
  /// In fr, this message translates to:
  /// **'Sessions Actives'**
  String get adminActiveSessionsLabel;

  /// No description provided for @adminEventsLabel.
  ///
  /// In fr, this message translates to:
  /// **'Événements'**
  String get adminEventsLabel;

  /// No description provided for @adminGroupsLabel.
  ///
  /// In fr, this message translates to:
  /// **'Groupes'**
  String get adminGroupsLabel;

  /// No description provided for @adminCommerceTitle.
  ///
  /// In fr, this message translates to:
  /// **'Commerce & Marketplace'**
  String get adminCommerceTitle;

  /// No description provided for @adminBusinessesLabel.
  ///
  /// In fr, this message translates to:
  /// **'Commerces'**
  String get adminBusinessesLabel;

  /// No description provided for @adminProductsLabel.
  ///
  /// In fr, this message translates to:
  /// **'Produits'**
  String get adminProductsLabel;

  /// No description provided for @adminTransactionsLabel.
  ///
  /// In fr, this message translates to:
  /// **'Transactions'**
  String get adminTransactionsLabel;

  /// No description provided for @adminReportsLabel.
  ///
  /// In fr, this message translates to:
  /// **'Signalements'**
  String get adminReportsLabel;

  /// No description provided for @adminQuickActionsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Actions Rapides'**
  String get adminQuickActionsTitle;

  /// No description provided for @adminActiveStatus.
  ///
  /// In fr, this message translates to:
  /// **'actif'**
  String get adminActiveStatus;

  /// No description provided for @adminManageEmbassiesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Gestion des Ambassades'**
  String get adminManageEmbassiesTitle;

  /// No description provided for @adminManageEmbassiesDesc.
  ///
  /// In fr, this message translates to:
  /// **'Créez et gérez les comptes ambassades'**
  String get adminManageEmbassiesDesc;

  /// No description provided for @adminLiveAudioRoomsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Salons Audio Live'**
  String get adminLiveAudioRoomsTitle;

  /// No description provided for @adminNoLiveRoomsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aucun salon en direct'**
  String get adminNoLiveRoomsTitle;

  /// No description provided for @adminNoLiveRoomsMsg.
  ///
  /// In fr, this message translates to:
  /// **'Il n\'y a actuellement aucun salon audio en cours.'**
  String get adminNoLiveRoomsMsg;

  /// No description provided for @adminLiveLabel.
  ///
  /// In fr, this message translates to:
  /// **'LIVE'**
  String get adminLiveLabel;

  /// No description provided for @adminPaidTag.
  ///
  /// In fr, this message translates to:
  /// **'Payant'**
  String get adminPaidTag;

  /// No description provided for @adminVideoTag.
  ///
  /// In fr, this message translates to:
  /// **'Vidéo'**
  String get adminVideoTag;

  /// No description provided for @adminModeratorModeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mode Modération'**
  String get adminModeratorModeTitle;

  /// No description provided for @adminModeratorModeMsg.
  ///
  /// In fr, this message translates to:
  /// **'Vous allez rejoindre ce salon en mode invisible (ghost mode). Les participants ne pourront pas vous voir.\n\nVous pourrez:\n• Écouter les conversations\n• Voir les vidéos (si activées)\n• Avertir l\'hôte\n• Fermer le salon si nécessaire'**
  String get adminModeratorModeMsg;

  /// No description provided for @adminJoinAction.
  ///
  /// In fr, this message translates to:
  /// **'Rejoindre'**
  String get adminJoinAction;

  /// No description provided for @adminTransferFeesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Frais de Transfert'**
  String get adminTransferFeesTitle;

  /// No description provided for @adminTransferFeesDesc.
  ///
  /// In fr, this message translates to:
  /// **'Configuration des frais sur les envois d\'argent'**
  String get adminTransferFeesDesc;

  /// No description provided for @adminMarketplaceFeesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Frais Marketplace'**
  String get adminMarketplaceFeesTitle;

  /// No description provided for @adminMarketplaceFeesDesc.
  ///
  /// In fr, this message translates to:
  /// **'Commission sur les ventes de produits'**
  String get adminMarketplaceFeesDesc;

  /// No description provided for @adminSaveChanges.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer les modifications'**
  String get adminSaveChanges;

  /// No description provided for @adminFieldRequired.
  ///
  /// In fr, this message translates to:
  /// **'Requis'**
  String get adminFieldRequired;

  /// No description provided for @adminValueBetweenError.
  ///
  /// In fr, this message translates to:
  /// **'Valeur entre 0 et 100'**
  String get adminValueBetweenError;

  /// No description provided for @adminInvalidNumberError.
  ///
  /// In fr, this message translates to:
  /// **'Nombre invalide'**
  String get adminInvalidNumberError;

  /// No description provided for @adminBasePricesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Prix de base (7 jours)'**
  String get adminBasePricesTitle;

  /// No description provided for @adminStandardTier.
  ///
  /// In fr, this message translates to:
  /// **'Standard'**
  String get adminStandardTier;

  /// No description provided for @adminStandardTierDesc.
  ///
  /// In fr, this message translates to:
  /// **'Visibilité améliorée'**
  String get adminStandardTierDesc;

  /// No description provided for @adminFeaturedTier.
  ///
  /// In fr, this message translates to:
  /// **'Featured'**
  String get adminFeaturedTier;

  /// No description provided for @adminFeaturedTierDesc.
  ///
  /// In fr, this message translates to:
  /// **'Badge + meilleure position'**
  String get adminFeaturedTierDesc;

  /// No description provided for @adminPremiumTier.
  ///
  /// In fr, this message translates to:
  /// **'Premium'**
  String get adminPremiumTier;

  /// No description provided for @adminPremiumTierDesc.
  ///
  /// In fr, this message translates to:
  /// **'Top position + section dédiée'**
  String get adminPremiumTierDesc;

  /// No description provided for @adminDurationMultipliersTitle.
  ///
  /// In fr, this message translates to:
  /// **'Multiplicateurs de durée'**
  String get adminDurationMultipliersTitle;

  /// No description provided for @adminDays7Label.
  ///
  /// In fr, this message translates to:
  /// **'7 jours'**
  String get adminDays7Label;

  /// No description provided for @adminDays30Label.
  ///
  /// In fr, this message translates to:
  /// **'30 jours'**
  String get adminDays30Label;

  /// No description provided for @adminDays90Label.
  ///
  /// In fr, this message translates to:
  /// **'90 jours'**
  String get adminDays90Label;

  /// No description provided for @adminPricePreviewTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aperçu des prix (Standard)'**
  String get adminPricePreviewTitle;

  /// No description provided for @adminPercentageHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex: 2.5 pour 2.5%'**
  String get adminPercentageHint;

  /// No description provided for @adminFeesUpdatedSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Frais mis à jour'**
  String get adminFeesUpdatedSuccess;

  /// No description provided for @adminBoostPricesUpdatedSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Tarifs boost mis à jour'**
  String get adminBoostPricesUpdatedSuccess;

  /// No description provided for @adminConfigurationAppTitle.
  ///
  /// In fr, this message translates to:
  /// **'Configuration App'**
  String get adminConfigurationAppTitle;

  /// No description provided for @podcastsSubscribersLabel.
  ///
  /// In fr, this message translates to:
  /// **'abonnés'**
  String get podcastsSubscribersLabel;

  /// No description provided for @podcastsEpisodesLabel.
  ///
  /// In fr, this message translates to:
  /// **'épisodes'**
  String get podcastsEpisodesLabel;

  /// No description provided for @podcastsPlaysLabel.
  ///
  /// In fr, this message translates to:
  /// **'écoutes'**
  String get podcastsPlaysLabel;

  /// No description provided for @securityDeleteBackupTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer la sauvegarde ?'**
  String get securityDeleteBackupTitle;

  /// No description provided for @securityDeleteBackupContent.
  ///
  /// In fr, this message translates to:
  /// **'Cette action est irréversible. Si vous perdez vos clés et n\'avez plus de sauvegarde, vous ne pourrez plus lire vos anciens messages.'**
  String get securityDeleteBackupContent;

  /// No description provided for @securityBackupDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarde supprimée'**
  String get securityBackupDeleted;

  /// No description provided for @securityBackupTitle.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarde des clés'**
  String get securityBackupTitle;

  /// No description provided for @e2eeBackupNudgeMessage.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegardez vos clés de chiffrement pour ne pas perdre l\'accès à vos messages si vous changez d\'appareil.'**
  String get e2eeBackupNudgeMessage;

  /// No description provided for @e2eeBackupNudgeAction.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarder'**
  String get e2eeBackupNudgeAction;

  /// No description provided for @e2eeRestoreNudgeMessage.
  ///
  /// In fr, this message translates to:
  /// **'Restaurez vos clés de chiffrement pour lire vos messages chiffrés sur cet appareil.'**
  String get e2eeRestoreNudgeMessage;

  /// No description provided for @e2eeRestoreNudgeAction.
  ///
  /// In fr, this message translates to:
  /// **'Restaurer'**
  String get e2eeRestoreNudgeAction;

  /// No description provided for @securityRestoreKeys.
  ///
  /// In fr, this message translates to:
  /// **'Restaurer les clés'**
  String get securityRestoreKeys;

  /// No description provided for @securityGeneratePassphrase.
  ///
  /// In fr, this message translates to:
  /// **'Générer une passphrase sécurisée'**
  String get securityGeneratePassphrase;

  /// No description provided for @securityCreateBackup.
  ///
  /// In fr, this message translates to:
  /// **'Créer la sauvegarde'**
  String get securityCreateBackup;

  /// No description provided for @securityPassphrase.
  ///
  /// In fr, this message translates to:
  /// **'Passphrase'**
  String get securityPassphrase;

  /// No description provided for @securityPassphraseMin.
  ///
  /// In fr, this message translates to:
  /// **'Minimum 8 caractères'**
  String get securityPassphraseMin;

  /// No description provided for @securityConfirmPassphrase.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer la passphrase'**
  String get securityConfirmPassphrase;

  /// No description provided for @securityDeletionError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la suppression: {error}'**
  String securityDeletionError(String error);

  /// No description provided for @bugReportDescription.
  ///
  /// In fr, this message translates to:
  /// **'Description du bug'**
  String get bugReportDescription;

  /// No description provided for @bugReportDescriptionHint.
  ///
  /// In fr, this message translates to:
  /// **'Décrivez le problème rencontré...'**
  String get bugReportDescriptionHint;

  /// No description provided for @bugReportDescriptionRequired.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez décrire le bug'**
  String get bugReportDescriptionRequired;

  /// No description provided for @bugReportStepsOptional.
  ///
  /// In fr, this message translates to:
  /// **'Étapes pour reproduire (optionnel)'**
  String get bugReportStepsOptional;

  /// No description provided for @bugReportStepsHint.
  ///
  /// In fr, this message translates to:
  /// **'1. Ouvrir l\'application\n2. ...'**
  String get bugReportStepsHint;

  /// No description provided for @bugReportEmailOpened.
  ///
  /// In fr, this message translates to:
  /// **'Application de messagerie ouverte'**
  String get bugReportEmailOpened;

  /// No description provided for @bugReportEmailFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'ouvrir l\'application de messagerie'**
  String get bugReportEmailFailed;

  /// No description provided for @reminder.
  ///
  /// In fr, this message translates to:
  /// **'Rappel'**
  String get reminder;

  /// No description provided for @confirmSend.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer l\'envoi'**
  String get confirmSend;

  /// No description provided for @titleLabel.
  ///
  /// In fr, this message translates to:
  /// **'Titre'**
  String get titleLabel;

  /// No description provided for @adminGlobalNotifications.
  ///
  /// In fr, this message translates to:
  /// **'Notifications Globales'**
  String get adminGlobalNotifications;

  /// No description provided for @adminGlobalNotificationsDesc.
  ///
  /// In fr, this message translates to:
  /// **'Envoyez des notifications à tous les utilisateurs'**
  String get adminGlobalNotificationsDesc;

  /// No description provided for @adminNewNotification.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle Notification'**
  String get adminNewNotification;

  /// No description provided for @adminNotifTitleHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex: Mise à jour importante'**
  String get adminNotifTitleHint;

  /// No description provided for @adminNotifMessageHint.
  ///
  /// In fr, this message translates to:
  /// **'Contenu de la notification...'**
  String get adminNotifMessageHint;

  /// No description provided for @adminRecipients.
  ///
  /// In fr, this message translates to:
  /// **'Destinataires'**
  String get adminRecipients;

  /// No description provided for @adminAllUsers.
  ///
  /// In fr, this message translates to:
  /// **'Tous les utilisateurs'**
  String get adminAllUsers;

  /// No description provided for @adminAdministrators.
  ///
  /// In fr, this message translates to:
  /// **'Administrateurs'**
  String get adminAdministrators;

  /// No description provided for @adminVerifiedProfiles.
  ///
  /// In fr, this message translates to:
  /// **'Profils vérifiés'**
  String get adminVerifiedProfiles;

  /// No description provided for @adminBusinessOwners.
  ///
  /// In fr, this message translates to:
  /// **'Propriétaires de commerces'**
  String get adminBusinessOwners;

  /// No description provided for @adminSending.
  ///
  /// In fr, this message translates to:
  /// **'Envoi en cours...'**
  String get adminSending;

  /// No description provided for @adminNoTitle.
  ///
  /// In fr, this message translates to:
  /// **'Sans titre'**
  String get adminNoTitle;

  /// No description provided for @adminStatusSent.
  ///
  /// In fr, this message translates to:
  /// **'Envoyé'**
  String get adminStatusSent;

  /// No description provided for @adminStatusPending.
  ///
  /// In fr, this message translates to:
  /// **'En attente'**
  String get adminStatusPending;

  /// No description provided for @adminStatusFailed.
  ///
  /// In fr, this message translates to:
  /// **'Échoué'**
  String get adminStatusFailed;

  /// No description provided for @adminTargetAll.
  ///
  /// In fr, this message translates to:
  /// **'Tous'**
  String get adminTargetAll;

  /// No description provided for @adminTargetAdmins.
  ///
  /// In fr, this message translates to:
  /// **'Admins'**
  String get adminTargetAdmins;

  /// No description provided for @adminTargetVerified.
  ///
  /// In fr, this message translates to:
  /// **'Vérifiés'**
  String get adminTargetVerified;

  /// No description provided for @adminTargetBusinesses.
  ///
  /// In fr, this message translates to:
  /// **'Commerces'**
  String get adminTargetBusinesses;

  /// No description provided for @adminNoNotificationsSent.
  ///
  /// In fr, this message translates to:
  /// **'Aucune notification envoyée'**
  String get adminNoNotificationsSent;

  /// No description provided for @adminFillTitleAndMessage.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez remplir le titre et le message'**
  String get adminFillTitleAndMessage;

  /// No description provided for @adminNotConnected.
  ///
  /// In fr, this message translates to:
  /// **'Erreur: Admin non connecté'**
  String get adminNotConnected;

  /// No description provided for @typeLabel.
  ///
  /// In fr, this message translates to:
  /// **'Type:'**
  String get typeLabel;

  /// No description provided for @contentDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Contenu supprimé'**
  String get contentDeleted;

  /// No description provided for @contentDeletedUserNotified.
  ///
  /// In fr, this message translates to:
  /// **'Contenu supprimé (utilisateur notifié)'**
  String get contentDeletedUserNotified;

  /// No description provided for @adminRejectionReason.
  ///
  /// In fr, this message translates to:
  /// **'Raison du rejet'**
  String get adminRejectionReason;

  /// No description provided for @adminMaintenanceMessageHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex: Application en maintenance...'**
  String get adminMaintenanceMessageHint;

  /// No description provided for @adminReportRejected.
  ///
  /// In fr, this message translates to:
  /// **'Signalement rejeté'**
  String get adminReportRejected;

  /// No description provided for @adminReportProcessedUserNotified.
  ///
  /// In fr, this message translates to:
  /// **'Signalement traité (utilisateur notifié)'**
  String get adminReportProcessedUserNotified;

  /// No description provided for @adminReportsManagementDesc.
  ///
  /// In fr, this message translates to:
  /// **'Traitez les signalements de contenu inapproprié'**
  String get adminReportsManagementDesc;

  /// No description provided for @adminRejectReport.
  ///
  /// In fr, this message translates to:
  /// **'Rejeter le signalement'**
  String get adminRejectReport;

  /// No description provided for @adminRejectionReasonLabel.
  ///
  /// In fr, this message translates to:
  /// **'Raison du rejet:'**
  String get adminRejectionReasonLabel;

  /// No description provided for @adminProcessReport.
  ///
  /// In fr, this message translates to:
  /// **'Traiter le signalement'**
  String get adminProcessReport;

  /// No description provided for @adminResolutionNoteLabel.
  ///
  /// In fr, this message translates to:
  /// **'Note de résolution:'**
  String get adminResolutionNoteLabel;

  /// No description provided for @adminMinimumFee.
  ///
  /// In fr, this message translates to:
  /// **'Frais minimum (XOF)'**
  String get adminMinimumFee;

  /// No description provided for @adminMaximumFee.
  ///
  /// In fr, this message translates to:
  /// **'Frais maximum (XOF)'**
  String get adminMaximumFee;

  /// No description provided for @adminBoostRatesUpdated.
  ///
  /// In fr, this message translates to:
  /// **'Tarifs boost mis à jour'**
  String get adminBoostRatesUpdated;

  /// No description provided for @adminLocationUpdateMin.
  ///
  /// In fr, this message translates to:
  /// **'Mise à jour localisation (min)'**
  String get adminLocationUpdateMin;

  /// No description provided for @adminOnlineHeartbeatMin.
  ///
  /// In fr, this message translates to:
  /// **'Heartbeat statut en ligne (min)'**
  String get adminOnlineHeartbeatMin;

  /// No description provided for @adminCacheDurationMin.
  ///
  /// In fr, this message translates to:
  /// **'Durée cache (min)'**
  String get adminCacheDurationMin;

  /// No description provided for @adminExampleValues.
  ///
  /// In fr, this message translates to:
  /// **'Ex: 1, 2, 5, 10, 20'**
  String get adminExampleValues;

  /// No description provided for @adminSearchUserHint.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un utilisateur...'**
  String get adminSearchUserHint;

  /// No description provided for @adminUserActivityTitle.
  ///
  /// In fr, this message translates to:
  /// **'Activité de {name}'**
  String adminUserActivityTitle(String name);

  /// No description provided for @adminChangeTo.
  ///
  /// In fr, this message translates to:
  /// **'Changer en {role}'**
  String adminChangeTo(String role);

  /// No description provided for @revoke.
  ///
  /// In fr, this message translates to:
  /// **'Révoquer'**
  String get revoke;

  /// No description provided for @refresh.
  ///
  /// In fr, this message translates to:
  /// **'Actualiser'**
  String get refresh;

  /// No description provided for @adminRoleManagementTitle.
  ///
  /// In fr, this message translates to:
  /// **'Gestion des Rôles Admin'**
  String get adminRoleManagementTitle;

  /// No description provided for @adminRoleManagementSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Attribuez et gérez les rôles des administrateurs'**
  String get adminRoleManagementSubtitle;

  /// No description provided for @adminNoAdminsConfigured.
  ///
  /// In fr, this message translates to:
  /// **'Aucun administrateur configuré'**
  String get adminNoAdminsConfigured;

  /// No description provided for @noName.
  ///
  /// In fr, this message translates to:
  /// **'Sans nom'**
  String get noName;

  /// No description provided for @lastLoginAt.
  ///
  /// In fr, this message translates to:
  /// **'Dernière connexion: {lastLogin}'**
  String lastLoginAt(String lastLogin);

  /// No description provided for @adminChangeRoleConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Voulez-vous changer le rôle de {name} de {oldRole} à {newRole}?'**
  String adminChangeRoleConfirm(String name, String oldRole, String newRole);

  /// No description provided for @adminRevokeAccessConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Voulez-vous vraiment révoquer l\'accès admin de {name}? Cette personne ne pourra plus accéder au panneau d\'administration.'**
  String adminRevokeAccessConfirm(String name);

  /// No description provided for @groupsCount.
  ///
  /// In fr, this message translates to:
  /// **'Groupes ({count})'**
  String groupsCount(int count);

  /// No description provided for @groupLabel.
  ///
  /// In fr, this message translates to:
  /// **'Groupe'**
  String get groupLabel;

  /// No description provided for @refund.
  ///
  /// In fr, this message translates to:
  /// **'Rembourser'**
  String get refund;

  /// No description provided for @adminFeesPercentageLabel.
  ///
  /// In fr, this message translates to:
  /// **'Pourcentage des frais'**
  String get adminFeesPercentageLabel;

  /// No description provided for @adminMinFeesLabel.
  ///
  /// In fr, this message translates to:
  /// **'Frais minimum (XOF)'**
  String get adminMinFeesLabel;

  /// No description provided for @adminMaxFeesLabel.
  ///
  /// In fr, this message translates to:
  /// **'Frais maximum (XOF)'**
  String get adminMaxFeesLabel;

  /// No description provided for @adminPlatformCommissionLabel.
  ///
  /// In fr, this message translates to:
  /// **'Commission plateforme'**
  String get adminPlatformCommissionLabel;

  /// No description provided for @adminMinCommissionLabel.
  ///
  /// In fr, this message translates to:
  /// **'Commission min (XOF)'**
  String get adminMinCommissionLabel;

  /// No description provided for @adminMaxCommissionLabel.
  ///
  /// In fr, this message translates to:
  /// **'Commission max (XOF)'**
  String get adminMaxCommissionLabel;

  /// No description provided for @adminMaxDimensionLabel.
  ///
  /// In fr, this message translates to:
  /// **'Dimension max (px)'**
  String get adminMaxDimensionLabel;

  /// No description provided for @adminUserActivityTitleParam.
  ///
  /// In fr, this message translates to:
  /// **'Activité de {name}'**
  String adminUserActivityTitleParam(String name);

  /// No description provided for @myReports.
  ///
  /// In fr, this message translates to:
  /// **'Mes signalements'**
  String get myReports;

  /// No description provided for @myReportsSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Voir l\'historique de vos signalements'**
  String get myReportsSubtitle;

  /// No description provided for @calls.
  ///
  /// In fr, this message translates to:
  /// **'Appels'**
  String get calls;

  /// No description provided for @noiseSuppression.
  ///
  /// In fr, this message translates to:
  /// **'Suppression du bruit'**
  String get noiseSuppression;

  /// No description provided for @noiseSuppressionSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Réduit les bruits de fond pendant les appels'**
  String get noiseSuppressionSubtitle;

  /// No description provided for @soundAndVibration.
  ///
  /// In fr, this message translates to:
  /// **'Son et Vibration'**
  String get soundAndVibration;

  /// No description provided for @sound.
  ///
  /// In fr, this message translates to:
  /// **'Son'**
  String get sound;

  /// No description provided for @vibration.
  ///
  /// In fr, this message translates to:
  /// **'Vibration'**
  String get vibration;

  /// No description provided for @chooseCurrency.
  ///
  /// In fr, this message translates to:
  /// **'Choisir la devise'**
  String get chooseCurrency;

  /// No description provided for @pricesDisplayedIn.
  ///
  /// In fr, this message translates to:
  /// **'Les prix seront affichés dans cette devise'**
  String get pricesDisplayedIn;

  /// No description provided for @noCurrencyFound.
  ///
  /// In fr, this message translates to:
  /// **'Aucune devise trouvée'**
  String get noCurrencyFound;

  /// No description provided for @chatBackground.
  ///
  /// In fr, this message translates to:
  /// **'Fond d\'écran des conversations'**
  String get chatBackground;

  /// No description provided for @customColor.
  ///
  /// In fr, this message translates to:
  /// **'Couleur personnalisée'**
  String get customColor;

  /// No description provided for @customImage.
  ///
  /// In fr, this message translates to:
  /// **'Image personnalisée'**
  String get customImage;

  /// No description provided for @greenDefault.
  ///
  /// In fr, this message translates to:
  /// **'Vert (Défaut)'**
  String get greenDefault;

  /// No description provided for @orangeClassic.
  ///
  /// In fr, this message translates to:
  /// **'Orange (Classique)'**
  String get orangeClassic;

  /// No description provided for @chooseColor.
  ///
  /// In fr, this message translates to:
  /// **'Choisir la couleur'**
  String get chooseColor;

  /// No description provided for @mainCurrencies.
  ///
  /// In fr, this message translates to:
  /// **'Devises principales'**
  String get mainCurrencies;

  /// No description provided for @africa.
  ///
  /// In fr, this message translates to:
  /// **'Afrique'**
  String get africa;

  /// No description provided for @asia.
  ///
  /// In fr, this message translates to:
  /// **'Asie'**
  String get asia;

  /// No description provided for @europe.
  ///
  /// In fr, this message translates to:
  /// **'Europe'**
  String get europe;

  /// No description provided for @americas.
  ///
  /// In fr, this message translates to:
  /// **'Amériques'**
  String get americas;

  /// No description provided for @oceaniaMiddleEast.
  ///
  /// In fr, this message translates to:
  /// **'Océanie & Moyen-Orient'**
  String get oceaniaMiddleEast;

  /// No description provided for @describeTheProblem.
  ///
  /// In fr, this message translates to:
  /// **'Décrivez le problème...'**
  String get describeTheProblem;

  /// No description provided for @sendReport.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer le signalement'**
  String get sendReport;

  /// No description provided for @deviceNameLabel.
  ///
  /// In fr, this message translates to:
  /// **'Nom de l\'appareil'**
  String get deviceNameLabel;

  /// No description provided for @renameDeviceTitle.
  ///
  /// In fr, this message translates to:
  /// **'Renommer l\'appareil'**
  String get renameDeviceTitle;

  /// No description provided for @searchCurrency.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher une devise...'**
  String get searchCurrency;

  /// No description provided for @restoreKeys.
  ///
  /// In fr, this message translates to:
  /// **'Restaurer les clés'**
  String get restoreKeys;

  /// No description provided for @tags.
  ///
  /// In fr, this message translates to:
  /// **'Tags'**
  String get tags;

  /// No description provided for @requestToJoin.
  ///
  /// In fr, this message translates to:
  /// **'Demander à rejoindre'**
  String get requestToJoin;

  /// No description provided for @podcastsCancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get podcastsCancel;

  /// No description provided for @addFriendsAsRecipients.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez vos amis comme bénéficiaires'**
  String get addFriendsAsRecipients;

  /// No description provided for @noFriendMatchesSearch.
  ///
  /// In fr, this message translates to:
  /// **'Aucun ami ne correspond à votre recherche'**
  String get noFriendMatchesSearch;

  /// No description provided for @addManually.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter manuellement'**
  String get addManually;

  /// No description provided for @chooseRecipient.
  ///
  /// In fr, this message translates to:
  /// **'Choisir un bénéficiaire'**
  String get chooseRecipient;

  /// No description provided for @cardLabel.
  ///
  /// In fr, this message translates to:
  /// **'Carte'**
  String get cardLabel;

  /// No description provided for @cashLabel.
  ///
  /// In fr, this message translates to:
  /// **'Espèces'**
  String get cashLabel;

  /// No description provided for @noRecipientFound.
  ///
  /// In fr, this message translates to:
  /// **'Aucun bénéficiaire trouvé'**
  String get noRecipientFound;

  /// No description provided for @noRecipientRegistered.
  ///
  /// In fr, this message translates to:
  /// **'Aucun bénéficiaire enregistré'**
  String get noRecipientRegistered;

  /// No description provided for @tryModifyingFilters.
  ///
  /// In fr, this message translates to:
  /// **'Essayez de modifier les filtres'**
  String get tryModifyingFilters;

  /// No description provided for @addFirstRecipient.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez votre premier bénéficiaire'**
  String get addFirstRecipient;

  /// No description provided for @confirmDeleteRecipient.
  ///
  /// In fr, this message translates to:
  /// **'Êtes-vous sûr de vouloir supprimer {name}?'**
  String confirmDeleteRecipient(String name);

  /// No description provided for @recipientDeletedSuccess.
  ///
  /// In fr, this message translates to:
  /// **'{name} a été supprimé'**
  String recipientDeletedSuccess(String name);

  /// No description provided for @removeFromFavorites.
  ///
  /// In fr, this message translates to:
  /// **'Retirer des favoris'**
  String get removeFromFavorites;

  /// No description provided for @confirmDeleteTitle.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer la suppression'**
  String get confirmDeleteTitle;

  /// No description provided for @amountSent.
  ///
  /// In fr, this message translates to:
  /// **'Montant envoyé'**
  String get amountSent;

  /// No description provided for @fees.
  ///
  /// In fr, this message translates to:
  /// **'Frais'**
  String get fees;

  /// No description provided for @totalDebited.
  ///
  /// In fr, this message translates to:
  /// **'Total débité'**
  String get totalDebited;

  /// No description provided for @exchangeRate.
  ///
  /// In fr, this message translates to:
  /// **'Taux de change'**
  String get exchangeRate;

  /// No description provided for @amountReceived.
  ///
  /// In fr, this message translates to:
  /// **'Montant reçu'**
  String get amountReceived;

  /// No description provided for @recipient.
  ///
  /// In fr, this message translates to:
  /// **'Bénéficiaire'**
  String get recipient;

  /// No description provided for @unknown.
  ///
  /// In fr, this message translates to:
  /// **'Inconnu'**
  String get unknown;

  /// No description provided for @information.
  ///
  /// In fr, this message translates to:
  /// **'Information'**
  String get information;

  /// No description provided for @reference.
  ///
  /// In fr, this message translates to:
  /// **'Référence'**
  String get reference;

  /// No description provided for @paymentMode.
  ///
  /// In fr, this message translates to:
  /// **'Mode de paiement'**
  String get paymentMode;

  /// No description provided for @stripeId.
  ///
  /// In fr, this message translates to:
  /// **'ID Stripe'**
  String get stripeId;

  /// No description provided for @mynitaRef.
  ///
  /// In fr, this message translates to:
  /// **'Réf Mynita'**
  String get mynitaRef;

  /// No description provided for @date.
  ///
  /// In fr, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @notAvailable.
  ///
  /// In fr, this message translates to:
  /// **'N/D'**
  String get notAvailable;

  /// No description provided for @completionDate.
  ///
  /// In fr, this message translates to:
  /// **'Date de complétion'**
  String get completionDate;

  /// No description provided for @failureReason.
  ///
  /// In fr, this message translates to:
  /// **'Raison de l\'échec'**
  String get failureReason;

  /// No description provided for @copiedToClipboard.
  ///
  /// In fr, this message translates to:
  /// **'Copié dans le presse-papiers'**
  String get copiedToClipboard;

  /// No description provided for @notes.
  ///
  /// In fr, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @activeFilters.
  ///
  /// In fr, this message translates to:
  /// **'Filtres actifs'**
  String get activeFilters;

  /// No description provided for @clearAll.
  ///
  /// In fr, this message translates to:
  /// **'Tout effacer'**
  String get clearAll;

  /// No description provided for @unknownDate.
  ///
  /// In fr, this message translates to:
  /// **'Date inconnue'**
  String get unknownDate;

  /// No description provided for @reviewedOn.
  ///
  /// In fr, this message translates to:
  /// **'Traité le {date}'**
  String reviewedOn(String date);

  /// No description provided for @unknownRecipient.
  ///
  /// In fr, this message translates to:
  /// **'Bénéficiaire inconnu'**
  String get unknownRecipient;

  /// No description provided for @noTransferFound.
  ///
  /// In fr, this message translates to:
  /// **'Aucun transfert trouvé'**
  String get noTransferFound;

  /// No description provided for @noTransferCompleted.
  ///
  /// In fr, this message translates to:
  /// **'Aucun transfert effectué'**
  String get noTransferCompleted;

  /// No description provided for @sendMoneyToLovedOnes.
  ///
  /// In fr, this message translates to:
  /// **'Envoyez de l\'argent à vos proches'**
  String get sendMoneyToLovedOnes;

  /// No description provided for @filterTransfers.
  ///
  /// In fr, this message translates to:
  /// **'Filtrer les transferts'**
  String get filterTransfers;

  /// No description provided for @status.
  ///
  /// In fr, this message translates to:
  /// **'Statut'**
  String get status;

  /// No description provided for @period.
  ///
  /// In fr, this message translates to:
  /// **'Période'**
  String get period;

  /// No description provided for @allPeriods.
  ///
  /// In fr, this message translates to:
  /// **'Toutes'**
  String get allPeriods;

  /// No description provided for @last7Days.
  ///
  /// In fr, this message translates to:
  /// **'7 derniers jours'**
  String get last7Days;

  /// No description provided for @last30Days.
  ///
  /// In fr, this message translates to:
  /// **'30 derniers jours'**
  String get last30Days;

  /// No description provided for @last3Months.
  ///
  /// In fr, this message translates to:
  /// **'3 derniers mois'**
  String get last3Months;

  /// No description provided for @choosePeriod.
  ///
  /// In fr, this message translates to:
  /// **'Choisir la période'**
  String get choosePeriod;

  /// No description provided for @applyFilters.
  ///
  /// In fr, this message translates to:
  /// **'Appliquer les filtres'**
  String get applyFilters;

  /// No description provided for @statusDebiting.
  ///
  /// In fr, this message translates to:
  /// **'Débit en cours'**
  String get statusDebiting;

  /// No description provided for @statusSending.
  ///
  /// In fr, this message translates to:
  /// **'Envoi en cours'**
  String get statusSending;

  /// No description provided for @statusRefunding.
  ///
  /// In fr, this message translates to:
  /// **'Remboursement'**
  String get statusRefunding;

  /// No description provided for @noDeviceRegistered.
  ///
  /// In fr, this message translates to:
  /// **'Aucun appareil enregistré'**
  String get noDeviceRegistered;

  /// No description provided for @devicesE2eeWillAppear.
  ///
  /// In fr, this message translates to:
  /// **'Les appareils utilisant le chiffrement de bout en bout apparaîtront ici.'**
  String get devicesE2eeWillAppear;

  /// No description provided for @rename.
  ///
  /// In fr, this message translates to:
  /// **'Renommer'**
  String get rename;

  /// No description provided for @revokeDeviceQuestion.
  ///
  /// In fr, this message translates to:
  /// **'Révoquer l\'appareil ?'**
  String get revokeDeviceQuestion;

  /// No description provided for @revokeDeviceConfirmMessage.
  ///
  /// In fr, this message translates to:
  /// **'Voulez-vous vraiment révoquer l\'accès de \"{deviceName}\" ?'**
  String revokeDeviceConfirmMessage(String deviceName);

  /// No description provided for @deviceRenameSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Appareil renommé'**
  String get deviceRenameSuccess;

  /// No description provided for @deviceRenameError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors du renommage'**
  String get deviceRenameError;

  /// No description provided for @restoreOnThisDevice.
  ///
  /// In fr, this message translates to:
  /// **'Restaurer sur cet appareil'**
  String get restoreOnThisDevice;

  /// No description provided for @enterPassphraseToRestore.
  ///
  /// In fr, this message translates to:
  /// **'Entrez votre passphrase pour restaurer vos clés:'**
  String get enterPassphraseToRestore;

  /// No description provided for @createABackup.
  ///
  /// In fr, this message translates to:
  /// **'Créer une sauvegarde'**
  String get createABackup;

  /// No description provided for @createBackupButton.
  ///
  /// In fr, this message translates to:
  /// **'Créer une sauvegarde'**
  String get createBackupButton;

  /// No description provided for @confirmPassphraseLabel.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer la passphrase'**
  String get confirmPassphraseLabel;

  /// No description provided for @passphraseCopied.
  ///
  /// In fr, this message translates to:
  /// **'Passphrase copiée'**
  String get passphraseCopied;

  /// No description provided for @xTwitter.
  ///
  /// In fr, this message translates to:
  /// **'X'**
  String get xTwitter;

  /// No description provided for @more.
  ///
  /// In fr, this message translates to:
  /// **'Plus'**
  String get more;

  /// No description provided for @travelMode.
  ///
  /// In fr, this message translates to:
  /// **'Mode Voyage'**
  String get travelMode;

  /// No description provided for @codeSentTo.
  ///
  /// In fr, this message translates to:
  /// **'Code envoyé au {phoneNumber}'**
  String codeSentTo(String phoneNumber);

  /// No description provided for @addParticipant.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un participant'**
  String get addParticipant;

  /// No description provided for @addToCall.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter à l\'appel'**
  String get addToCall;

  /// No description provided for @convertingToGroupCall.
  ///
  /// In fr, this message translates to:
  /// **'Conversion en appel de groupe...'**
  String get convertingToGroupCall;

  /// No description provided for @selectParticipantToAdd.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionner un participant'**
  String get selectParticipantToAdd;

  /// No description provided for @noEligibleParticipants.
  ///
  /// In fr, this message translates to:
  /// **'Aucun participant disponible'**
  String get noEligibleParticipants;

  /// No description provided for @noEligibleParticipantsHint.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez des amis ou démarrez une conversation pour pouvoir les ajouter à un appel'**
  String get noEligibleParticipantsHint;

  /// No description provided for @recentConversations.
  ///
  /// In fr, this message translates to:
  /// **'Conversations récentes'**
  String get recentConversations;

  /// No description provided for @callConvertedToGroup.
  ///
  /// In fr, this message translates to:
  /// **'Converti en appel de groupe'**
  String get callConvertedToGroup;

  /// No description provided for @participantBusy.
  ///
  /// In fr, this message translates to:
  /// **'{name} est en appel'**
  String participantBusy(String name);

  /// No description provided for @conversionFailed.
  ///
  /// In fr, this message translates to:
  /// **'Échec de l\'ajout du participant'**
  String get conversionFailed;

  /// No description provided for @slideToCancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get slideToCancel;

  /// No description provided for @releaseToCancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get releaseToCancel;

  /// No description provided for @recordingLocked.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrement verrouillé'**
  String get recordingLocked;

  /// No description provided for @releaseToLock.
  ///
  /// In fr, this message translates to:
  /// **'Relâchez pour verrouiller'**
  String get releaseToLock;

  /// No description provided for @slideUpToLock.
  ///
  /// In fr, this message translates to:
  /// **'Glissez vers le haut'**
  String get slideUpToLock;

  /// No description provided for @timeRemaining.
  ///
  /// In fr, this message translates to:
  /// **'Temps restant: {time}'**
  String timeRemaining(String time);

  /// No description provided for @lock.
  ///
  /// In fr, this message translates to:
  /// **'Verrouiller'**
  String get lock;

  /// No description provided for @localEvents.
  ///
  /// In fr, this message translates to:
  /// **'Événements locaux'**
  String get localEvents;

  /// No description provided for @localEventsSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Recevoir des notifications pour les nouveaux événements dans ma ville'**
  String get localEventsSubtitle;

  /// No description provided for @systemMessages.
  ///
  /// In fr, this message translates to:
  /// **'Messages système'**
  String get systemMessages;

  /// No description provided for @systemMessagesSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Recevoir des notifications pour les évènements système (ex: nouveau membre)'**
  String get systemMessagesSubtitle;

  /// No description provided for @confidentiality.
  ///
  /// In fr, this message translates to:
  /// **'Confidentialité'**
  String get confidentiality;

  /// No description provided for @messagePreview.
  ///
  /// In fr, this message translates to:
  /// **'Aperçu des messages'**
  String get messagePreview;

  /// No description provided for @messagePreviewSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Afficher le contenu des messages dans les notifications'**
  String get messagePreviewSubtitle;

  /// No description provided for @onlineStatus.
  ///
  /// In fr, this message translates to:
  /// **'En ligne'**
  String get onlineStatus;

  /// No description provided for @seenAgo.
  ///
  /// In fr, this message translates to:
  /// **'Vu {ago}'**
  String seenAgo(String ago);

  /// No description provided for @offline.
  ///
  /// In fr, this message translates to:
  /// **'Hors ligne'**
  String get offline;

  /// No description provided for @discoverProfile.
  ///
  /// In fr, this message translates to:
  /// **'Découvrez mon profil sur Diaspo Niger: {link}'**
  String discoverProfile(String link);

  /// No description provided for @profileOf.
  ///
  /// In fr, this message translates to:
  /// **'Profil de {name}'**
  String profileOf(String name);

  /// No description provided for @unableToGenerateLink.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de générer le lien de partage'**
  String get unableToGenerateLink;

  /// No description provided for @profileSendFriendRequest.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer une demande d\'ami'**
  String get profileSendFriendRequest;

  /// No description provided for @profileFriendRequestSent.
  ///
  /// In fr, this message translates to:
  /// **'Demande d\'ami envoyée'**
  String get profileFriendRequestSent;

  /// No description provided for @profileFriendRequestFailed.
  ///
  /// In fr, this message translates to:
  /// **'Échec de l\'envoi'**
  String get profileFriendRequestFailed;

  /// No description provided for @profileNewMember.
  ///
  /// In fr, this message translates to:
  /// **'Nouvel utilisateur'**
  String get profileNewMember;

  /// No description provided for @profileNoBio.
  ///
  /// In fr, this message translates to:
  /// **'Aucune biographie'**
  String get profileNoBio;

  /// No description provided for @profileNoSkillsAdded.
  ///
  /// In fr, this message translates to:
  /// **'Aucune compétence ajoutée'**
  String get profileNoSkillsAdded;

  /// No description provided for @profileNoInterestsAdded.
  ///
  /// In fr, this message translates to:
  /// **'Aucun intérêt ajouté'**
  String get profileNoInterestsAdded;

  /// No description provided for @profileShowOnlineStatus.
  ///
  /// In fr, this message translates to:
  /// **'Afficher mon statut en ligne'**
  String get profileShowOnlineStatus;

  /// No description provided for @profileReport.
  ///
  /// In fr, this message translates to:
  /// **'Signaler'**
  String get profileReport;

  /// No description provided for @profileSettings.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres'**
  String get profileSettings;

  /// No description provided for @profileSendingRequest.
  ///
  /// In fr, this message translates to:
  /// **'Envoi en cours...'**
  String get profileSendingRequest;

  /// No description provided for @profileTravelModeSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Permettre la localisation même quand l\'application est fermée (Mise à jour toutes les 5 min)'**
  String get profileTravelModeSubtitle;

  /// No description provided for @profileShowOnlineStatusSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Permet de voir et d\'être vu en ligne. Si désactivé, vous ne verrez pas le statut des autres.'**
  String get profileShowOnlineStatusSubtitle;

  /// No description provided for @whoSeesYou.
  ///
  /// In fr, this message translates to:
  /// **'Qui vous voit'**
  String get whoSeesYou;

  /// No description provided for @dataSaverMode.
  ///
  /// In fr, this message translates to:
  /// **'Mode données réduites'**
  String get dataSaverMode;

  /// No description provided for @dataSaverModeSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Médias non téléchargés automatiquement en discussion'**
  String get dataSaverModeSubtitle;

  /// No description provided for @displayCurrency.
  ///
  /// In fr, this message translates to:
  /// **'Devise'**
  String get displayCurrency;

  /// No description provided for @displayCurrencySubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Les prix seront affichés dans cette devise'**
  String get displayCurrencySubtitle;

  /// No description provided for @profileUpdateError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la mise à jour: {error}'**
  String profileUpdateError(String error);

  /// No description provided for @profileLoadingText.
  ///
  /// In fr, this message translates to:
  /// **'Chargement...'**
  String get profileLoadingText;

  /// No description provided for @profileLoadError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur de chargement'**
  String get profileLoadError;

  /// No description provided for @conversationYouPrefix.
  ///
  /// In fr, this message translates to:
  /// **'Vous: {message}'**
  String conversationYouPrefix(String message);

  /// No description provided for @emojis.
  ///
  /// In fr, this message translates to:
  /// **'Emojis'**
  String get emojis;

  /// No description provided for @gifs.
  ///
  /// In fr, this message translates to:
  /// **'GIFs'**
  String get gifs;

  /// No description provided for @searchGifs.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher des GIFs'**
  String get searchGifs;

  /// No description provided for @gifNoResults.
  ///
  /// In fr, this message translates to:
  /// **'Aucun résultat.'**
  String get gifNoResults;

  /// No description provided for @gifLoadError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger les GIFs.'**
  String get gifLoadError;

  /// No description provided for @gifProviderNotConfigured.
  ///
  /// In fr, this message translates to:
  /// **'Les GIFs ne sont pas encore configurés.'**
  String get gifProviderNotConfigured;

  /// No description provided for @showKeyboard.
  ///
  /// In fr, this message translates to:
  /// **'Afficher le clavier'**
  String get showKeyboard;

  /// No description provided for @stickers.
  ///
  /// In fr, this message translates to:
  /// **'Stickers'**
  String get stickers;

  /// No description provided for @stickerPacks.
  ///
  /// In fr, this message translates to:
  /// **'Packs de stickers'**
  String get stickerPacks;

  /// No description provided for @recentStickers.
  ///
  /// In fr, this message translates to:
  /// **'Récents'**
  String get recentStickers;

  /// No description provided for @favoriteStickers.
  ///
  /// In fr, this message translates to:
  /// **'Favoris'**
  String get favoriteStickers;

  /// No description provided for @addStickerPack.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un pack'**
  String get addStickerPack;

  /// No description provided for @removeStickerPack.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le pack'**
  String get removeStickerPack;

  /// No description provided for @stickerPackAdded.
  ///
  /// In fr, this message translates to:
  /// **'Pack de stickers ajouté'**
  String get stickerPackAdded;

  /// No description provided for @stickerPackRemoved.
  ///
  /// In fr, this message translates to:
  /// **'Pack de stickers supprimé'**
  String get stickerPackRemoved;

  /// No description provided for @noStickersYet.
  ///
  /// In fr, this message translates to:
  /// **'Pas encore de stickers'**
  String get noStickersYet;

  /// No description provided for @browseStickers.
  ///
  /// In fr, this message translates to:
  /// **'Parcourir les packs'**
  String get browseStickers;

  /// No description provided for @stickerLabel.
  ///
  /// In fr, this message translates to:
  /// **'Sticker'**
  String get stickerLabel;

  /// No description provided for @myStickerPacks.
  ///
  /// In fr, this message translates to:
  /// **'Mes packs de stickers'**
  String get myStickerPacks;

  /// No description provided for @createStickerPack.
  ///
  /// In fr, this message translates to:
  /// **'Créer un pack'**
  String get createStickerPack;

  /// No description provided for @stickerPackName.
  ///
  /// In fr, this message translates to:
  /// **'Nom du pack'**
  String get stickerPackName;

  /// No description provided for @stickerPackDescription.
  ///
  /// In fr, this message translates to:
  /// **'Description (optionnel)'**
  String get stickerPackDescription;

  /// No description provided for @stickerPackThumbnail.
  ///
  /// In fr, this message translates to:
  /// **'Miniature'**
  String get stickerPackThumbnail;

  /// No description provided for @addStickers.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter des stickers'**
  String get addStickers;

  /// No description provided for @stickerPackCreated.
  ///
  /// In fr, this message translates to:
  /// **'Pack de stickers créé'**
  String get stickerPackCreated;

  /// No description provided for @stickerPackPending.
  ///
  /// In fr, this message translates to:
  /// **'En attente de modération'**
  String get stickerPackPending;

  /// No description provided for @stickerPackApproved.
  ///
  /// In fr, this message translates to:
  /// **'Approuvé'**
  String get stickerPackApproved;

  /// No description provided for @stickerPackRejected.
  ///
  /// In fr, this message translates to:
  /// **'Rejeté'**
  String get stickerPackRejected;

  /// No description provided for @deleteStickerPack.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le pack'**
  String get deleteStickerPack;

  /// No description provided for @confirmDeleteStickerPack.
  ///
  /// In fr, this message translates to:
  /// **'Voulez-vous vraiment supprimer ce pack de stickers ?'**
  String get confirmDeleteStickerPack;

  /// No description provided for @noStickerPacks.
  ///
  /// In fr, this message translates to:
  /// **'Aucun pack de stickers'**
  String get noStickerPacks;

  /// No description provided for @officialPacks.
  ///
  /// In fr, this message translates to:
  /// **'Packs officiels'**
  String get officialPacks;

  /// No description provided for @communityPacks.
  ///
  /// In fr, this message translates to:
  /// **'Packs de la communauté'**
  String get communityPacks;

  /// No description provided for @serviceFeed.
  ///
  /// In fr, this message translates to:
  /// **'Fil d\'actualité'**
  String get serviceFeed;

  /// No description provided for @feedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Fil d\'actualité'**
  String get feedTitle;

  /// No description provided for @feedEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune publication pour le moment.\nSoyez le premier à partager !'**
  String get feedEmpty;

  /// No description provided for @feedNewPostsPill.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 nouvelle publication} other{{count} nouvelles publications}}'**
  String feedNewPostsPill(int count);

  /// No description provided for @createPost.
  ///
  /// In fr, this message translates to:
  /// **'Créer une publication'**
  String get createPost;

  /// No description provided for @postPlaceholder.
  ///
  /// In fr, this message translates to:
  /// **'Quoi de neuf ?'**
  String get postPlaceholder;

  /// No description provided for @publishPost.
  ///
  /// In fr, this message translates to:
  /// **'Publier'**
  String get publishPost;

  /// No description provided for @likePost.
  ///
  /// In fr, this message translates to:
  /// **'J\'aime'**
  String get likePost;

  /// No description provided for @commentPost.
  ///
  /// In fr, this message translates to:
  /// **'Commenter'**
  String get commentPost;

  /// No description provided for @sharePost.
  ///
  /// In fr, this message translates to:
  /// **'Partager'**
  String get sharePost;

  /// No description provided for @deletePost.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer la publication'**
  String get deletePost;

  /// No description provided for @confirmDeletePost.
  ///
  /// In fr, this message translates to:
  /// **'Voulez-vous vraiment supprimer cette publication ?'**
  String get confirmDeletePost;

  /// No description provided for @followUser.
  ///
  /// In fr, this message translates to:
  /// **'Suivre'**
  String get followUser;

  /// No description provided for @unfollowUser.
  ///
  /// In fr, this message translates to:
  /// **'Ne plus suivre'**
  String get unfollowUser;

  /// No description provided for @followTitle.
  ///
  /// In fr, this message translates to:
  /// **'Abonnés et abonnements'**
  String get followTitle;

  /// No description provided for @followersTitle.
  ///
  /// In fr, this message translates to:
  /// **'Abonnés'**
  String get followersTitle;

  /// No description provided for @followingTitle.
  ///
  /// In fr, this message translates to:
  /// **'Abonnements'**
  String get followingTitle;

  /// No description provided for @noFollowersYet.
  ///
  /// In fr, this message translates to:
  /// **'Aucun abonné pour le moment.'**
  String get noFollowersYet;

  /// No description provided for @noFollowingYet.
  ///
  /// In fr, this message translates to:
  /// **'Vous ne suivez encore personne.'**
  String get noFollowingYet;

  /// No description provided for @myFollowsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Abonnés et abonnements'**
  String get myFollowsTitle;

  /// No description provided for @myFollowsSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Voyez qui vous suit et qui vous suivez'**
  String get myFollowsSubtitle;

  /// No description provided for @errorLoadingData.
  ///
  /// In fr, this message translates to:
  /// **'Échec du chargement. Réessayez.'**
  String get errorLoadingData;

  /// No description provided for @commentPlaceholder.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un commentaire…'**
  String get commentPlaceholder;

  /// No description provided for @addComment.
  ///
  /// In fr, this message translates to:
  /// **'Publier'**
  String get addComment;

  /// No description provided for @postDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Publication supprimée'**
  String get postDeleted;

  /// No description provided for @postShared.
  ///
  /// In fr, this message translates to:
  /// **'Publication partagée'**
  String get postShared;

  /// No description provided for @noComments.
  ///
  /// In fr, this message translates to:
  /// **'Aucun commentaire pour le moment'**
  String get noComments;

  /// No description provided for @deleteComment.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le commentaire'**
  String get deleteComment;

  /// No description provided for @confirmDeleteComment.
  ///
  /// In fr, this message translates to:
  /// **'Voulez-vous vraiment supprimer ce commentaire ?'**
  String get confirmDeleteComment;

  /// No description provided for @commentDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Commentaire supprimé'**
  String get commentDeleted;

  /// No description provided for @editPost.
  ///
  /// In fr, this message translates to:
  /// **'Modifier la publication'**
  String get editPost;

  /// No description provided for @editPostTitle.
  ///
  /// In fr, this message translates to:
  /// **'Modifier la publication'**
  String get editPostTitle;

  /// No description provided for @likeComment.
  ///
  /// In fr, this message translates to:
  /// **'J\'aime'**
  String get likeComment;

  /// No description provided for @replyingTo.
  ///
  /// In fr, this message translates to:
  /// **'Réponse à {name}'**
  String replyingTo(String name);

  /// No description provided for @viewReplies.
  ///
  /// In fr, this message translates to:
  /// **'Voir {count} réponses'**
  String viewReplies(int count);

  /// No description provided for @hideReplies.
  ///
  /// In fr, this message translates to:
  /// **'Masquer les réponses'**
  String get hideReplies;

  /// No description provided for @loadingMore.
  ///
  /// In fr, this message translates to:
  /// **'Chargement…'**
  String get loadingMore;

  /// No description provided for @feedError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger le fil d\'actualité'**
  String get feedError;

  /// No description provided for @postError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger la publication'**
  String get postError;

  /// No description provided for @addMedia.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter des médias'**
  String get addMedia;

  /// No description provided for @addVideo.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une vidéo'**
  String get addVideo;

  /// No description provided for @publishing.
  ///
  /// In fr, this message translates to:
  /// **'Publication en cours…'**
  String get publishing;

  /// No description provided for @publishSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Publication créée avec succès'**
  String get publishSuccess;

  /// No description provided for @publishError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la publication'**
  String get publishError;

  /// No description provided for @followers.
  ///
  /// In fr, this message translates to:
  /// **'{count} abonnés'**
  String followers(int count);

  /// No description provided for @following.
  ///
  /// In fr, this message translates to:
  /// **'{count} abonnements'**
  String following(int count);

  /// No description provided for @postLikes.
  ///
  /// In fr, this message translates to:
  /// **'{count} j\'aime'**
  String postLikes(int count);

  /// No description provided for @postComments.
  ///
  /// In fr, this message translates to:
  /// **'{count} commentaire(s)'**
  String postComments(int count);

  /// No description provided for @mentionSuggestionHint.
  ///
  /// In fr, this message translates to:
  /// **'Mentionner un membre'**
  String get mentionSuggestionHint;

  /// No description provided for @mentionNotificationTitle.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez été mentionné'**
  String get mentionNotificationTitle;

  /// No description provided for @mentionNotificationBody.
  ///
  /// In fr, this message translates to:
  /// **'{senderName} vous a mentionné dans {groupName}'**
  String mentionNotificationBody(String senderName, String groupName);

  /// No description provided for @mentionedBy.
  ///
  /// In fr, this message translates to:
  /// **'Mentionné par {name}'**
  String mentionedBy(String name);

  /// No description provided for @loadingEllipsis.
  ///
  /// In fr, this message translates to:
  /// **'Chargement...'**
  String get loadingEllipsis;

  /// No description provided for @rejected.
  ///
  /// In fr, this message translates to:
  /// **'Rejeté'**
  String get rejected;

  /// No description provided for @suspended.
  ///
  /// In fr, this message translates to:
  /// **'Suspendu'**
  String get suspended;

  /// No description provided for @reactivate.
  ///
  /// In fr, this message translates to:
  /// **'Réactiver'**
  String get reactivate;

  /// No description provided for @reject.
  ///
  /// In fr, this message translates to:
  /// **'Rejeter'**
  String get reject;

  /// No description provided for @approve.
  ///
  /// In fr, this message translates to:
  /// **'Approuver'**
  String get approve;

  /// No description provided for @suspend.
  ///
  /// In fr, this message translates to:
  /// **'Suspendre'**
  String get suspend;

  /// No description provided for @rejectionReason.
  ///
  /// In fr, this message translates to:
  /// **'Raison du rejet'**
  String get rejectionReason;

  /// No description provided for @complete.
  ///
  /// In fr, this message translates to:
  /// **'Complet'**
  String get complete;

  /// No description provided for @buyer.
  ///
  /// In fr, this message translates to:
  /// **'Acheteur'**
  String get buyer;

  /// No description provided for @seller.
  ///
  /// In fr, this message translates to:
  /// **'Vendeur'**
  String get seller;

  /// No description provided for @deleteContent.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le contenu'**
  String get deleteContent;

  /// No description provided for @process.
  ///
  /// In fr, this message translates to:
  /// **'Traiter'**
  String get process;

  /// No description provided for @clearFilters.
  ///
  /// In fr, this message translates to:
  /// **'Effacer les filtres'**
  String get clearFilters;

  /// No description provided for @newAdmin.
  ///
  /// In fr, this message translates to:
  /// **'Nouvel administrateur'**
  String get newAdmin;

  /// No description provided for @changeRole.
  ///
  /// In fr, this message translates to:
  /// **'Changer le rôle'**
  String get changeRole;

  /// No description provided for @revokeAccess.
  ///
  /// In fr, this message translates to:
  /// **'Révoquer l\'accès'**
  String get revokeAccess;

  /// No description provided for @exportInProgress.
  ///
  /// In fr, this message translates to:
  /// **'Export de {type} en cours...'**
  String exportInProgress(String type);

  /// No description provided for @embassyCreated.
  ///
  /// In fr, this message translates to:
  /// **'Ambassade créée avec succès !'**
  String get embassyCreated;

  /// No description provided for @createEmbassy.
  ///
  /// In fr, this message translates to:
  /// **'Créer une ambassade'**
  String get createEmbassy;

  /// No description provided for @joinAction.
  ///
  /// In fr, this message translates to:
  /// **'Rejoindre'**
  String get joinAction;

  /// No description provided for @viewReports.
  ///
  /// In fr, this message translates to:
  /// **'Voir les rapports'**
  String get viewReports;

  /// No description provided for @manageUsers.
  ///
  /// In fr, this message translates to:
  /// **'Gérer les utilisateurs'**
  String get manageUsers;

  /// No description provided for @sendNotification.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer une notification'**
  String get sendNotification;

  /// No description provided for @viewAnalytics.
  ///
  /// In fr, this message translates to:
  /// **'Voir les analyses'**
  String get viewAnalytics;

  /// No description provided for @configuration.
  ///
  /// In fr, this message translates to:
  /// **'Configuration'**
  String get configuration;

  /// No description provided for @featureFlags.
  ///
  /// In fr, this message translates to:
  /// **'Drapeaux de fonctionnalités'**
  String get featureFlags;

  /// No description provided for @auditHistory.
  ///
  /// In fr, this message translates to:
  /// **'Historique d\'audit'**
  String get auditHistory;

  /// No description provided for @emailAction.
  ///
  /// In fr, this message translates to:
  /// **'Email'**
  String get emailAction;

  /// No description provided for @website.
  ///
  /// In fr, this message translates to:
  /// **'Site web'**
  String get website;

  /// No description provided for @getDirections.
  ///
  /// In fr, this message translates to:
  /// **'Obtenir l\'itinéraire'**
  String get getDirections;

  /// No description provided for @department.
  ///
  /// In fr, this message translates to:
  /// **'Département'**
  String get department;

  /// No description provided for @messageTitle.
  ///
  /// In fr, this message translates to:
  /// **'Titre'**
  String get messageTitle;

  /// No description provided for @messageBody.
  ///
  /// In fr, this message translates to:
  /// **'Message'**
  String get messageBody;

  /// No description provided for @confirmSending.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer l\'envoi'**
  String get confirmSending;

  /// No description provided for @aboutToSend.
  ///
  /// In fr, this message translates to:
  /// **'Vous êtes sur le point d\'envoyer une notification à :'**
  String get aboutToSend;

  /// No description provided for @messageLabel.
  ///
  /// In fr, this message translates to:
  /// **'Message : {message}'**
  String messageLabel(String message);

  /// No description provided for @searchBy.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher par nom, raison, ID...'**
  String get searchBy;

  /// No description provided for @viewTheItem.
  ///
  /// In fr, this message translates to:
  /// **'Voir le {item}'**
  String viewTheItem(String item);

  /// No description provided for @changeToRole.
  ///
  /// In fr, this message translates to:
  /// **'Passer à {role}'**
  String changeToRole(String role);

  /// No description provided for @revokeAdminAccess.
  ///
  /// In fr, this message translates to:
  /// **'Révoquer l\'accès administrateur'**
  String get revokeAdminAccess;

  /// No description provided for @revokeAction.
  ///
  /// In fr, this message translates to:
  /// **'Révoquer'**
  String get revokeAction;

  /// No description provided for @feesUpdated.
  ///
  /// In fr, this message translates to:
  /// **'Frais mis à jour'**
  String get feesUpdated;

  /// No description provided for @feePercentage.
  ///
  /// In fr, this message translates to:
  /// **'Pourcentage de frais'**
  String get feePercentage;

  /// No description provided for @minimumFee.
  ///
  /// In fr, this message translates to:
  /// **'Frais minimum (XOF)'**
  String get minimumFee;

  /// No description provided for @maximumFee.
  ///
  /// In fr, this message translates to:
  /// **'Frais maximum (XOF)'**
  String get maximumFee;

  /// No description provided for @platformCommission.
  ///
  /// In fr, this message translates to:
  /// **'Commission plateforme'**
  String get platformCommission;

  /// No description provided for @minimumCommission.
  ///
  /// In fr, this message translates to:
  /// **'Commission minimum (XOF)'**
  String get minimumCommission;

  /// No description provided for @maximumCommission.
  ///
  /// In fr, this message translates to:
  /// **'Commission maximum (XOF)'**
  String get maximumCommission;

  /// No description provided for @boostRatesUpdated.
  ///
  /// In fr, this message translates to:
  /// **'Taux de boost mis à jour'**
  String get boostRatesUpdated;

  /// No description provided for @vatRateUpdated.
  ///
  /// In fr, this message translates to:
  /// **'Taux de TVA mis à jour'**
  String get vatRateUpdated;

  /// No description provided for @mediaLimitsUpdated.
  ///
  /// In fr, this message translates to:
  /// **'Limites médias mises à jour'**
  String get mediaLimitsUpdated;

  /// No description provided for @maxDimension.
  ///
  /// In fr, this message translates to:
  /// **'Dimension max (px)'**
  String get maxDimension;

  /// No description provided for @compressionQuality.
  ///
  /// In fr, this message translates to:
  /// **'Qualité de compression (%)'**
  String get compressionQuality;

  /// No description provided for @maxImagesPerUpload.
  ///
  /// In fr, this message translates to:
  /// **'Max images/upload'**
  String get maxImagesPerUpload;

  /// No description provided for @maxImageSize.
  ///
  /// In fr, this message translates to:
  /// **'Taille max image (MB)'**
  String get maxImageSize;

  /// No description provided for @maxVideoSize.
  ///
  /// In fr, this message translates to:
  /// **'Taille max vidéo (MB)'**
  String get maxVideoSize;

  /// No description provided for @maxCharsPerMessage.
  ///
  /// In fr, this message translates to:
  /// **'Max caractères par message'**
  String get maxCharsPerMessage;

  /// No description provided for @urlsUpdated.
  ///
  /// In fr, this message translates to:
  /// **'URLs mises à jour'**
  String get urlsUpdated;

  /// No description provided for @intervalsUpdated.
  ///
  /// In fr, this message translates to:
  /// **'Intervalles mis à jour'**
  String get intervalsUpdated;

  /// No description provided for @baseShareUrl.
  ///
  /// In fr, this message translates to:
  /// **'URL de base pour le partage'**
  String get baseShareUrl;

  /// No description provided for @privacyEmail.
  ///
  /// In fr, this message translates to:
  /// **'Email confidentialité (RGPD)'**
  String get privacyEmail;

  /// No description provided for @bugReportEmail.
  ///
  /// In fr, this message translates to:
  /// **'Email de signalement de bug'**
  String get bugReportEmail;

  /// No description provided for @feedbackEmail.
  ///
  /// In fr, this message translates to:
  /// **'Email de retour'**
  String get feedbackEmail;

  /// No description provided for @moderationEmail.
  ///
  /// In fr, this message translates to:
  /// **'Email de modération'**
  String get moderationEmail;

  /// No description provided for @locationUpdateInterval.
  ///
  /// In fr, this message translates to:
  /// **'Mise à jour localisation (min)'**
  String get locationUpdateInterval;

  /// No description provided for @onlineStatusHeartbeat.
  ///
  /// In fr, this message translates to:
  /// **'Battement statut en ligne (min)'**
  String get onlineStatusHeartbeat;

  /// No description provided for @cacheDuration.
  ///
  /// In fr, this message translates to:
  /// **'Durée du cache (min)'**
  String get cacheDuration;

  /// No description provided for @audioSettingsUpdated.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres audio mis à jour'**
  String get audioSettingsUpdated;

  /// No description provided for @exampleValues.
  ///
  /// In fr, this message translates to:
  /// **'Ex : 1, 2, 5, 10, 20'**
  String get exampleValues;

  /// No description provided for @searchUser.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un utilisateur...'**
  String get searchUser;

  /// No description provided for @noUserFound.
  ///
  /// In fr, this message translates to:
  /// **'Aucun utilisateur trouvé'**
  String get noUserFound;

  /// No description provided for @noActivityRecorded.
  ///
  /// In fr, this message translates to:
  /// **'Aucune activité enregistrée'**
  String get noActivityRecorded;

  /// No description provided for @activityOf.
  ///
  /// In fr, this message translates to:
  /// **'Activité de {name}'**
  String activityOf(String name);

  /// No description provided for @confirmLogoutTitle.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer la déconnexion'**
  String get confirmLogoutTitle;

  /// No description provided for @disconnect.
  ///
  /// In fr, this message translates to:
  /// **'Déconnecter'**
  String get disconnect;

  /// No description provided for @publicGroup.
  ///
  /// In fr, this message translates to:
  /// **'Public'**
  String get publicGroup;

  /// No description provided for @embassyApproved.
  ///
  /// In fr, this message translates to:
  /// **'Ambassade {name} approuvée'**
  String embassyApproved(String name);

  /// No description provided for @embassyRejected.
  ///
  /// In fr, this message translates to:
  /// **'Ambassade {name} rejetée'**
  String embassyRejected(String name);

  /// No description provided for @embassySuspended.
  ///
  /// In fr, this message translates to:
  /// **'Ambassade {name} suspendue'**
  String embassySuspended(String name);

  /// No description provided for @embassyReactivated.
  ///
  /// In fr, this message translates to:
  /// **'Ambassade {name} réactivée'**
  String embassyReactivated(String name);

  /// No description provided for @rejectRequest.
  ///
  /// In fr, this message translates to:
  /// **'Rejeter la demande'**
  String get rejectRequest;

  /// No description provided for @featureFlagsUpdated.
  ///
  /// In fr, this message translates to:
  /// **'Drapeaux de fonctionnalités mis à jour'**
  String get featureFlagsUpdated;

  /// No description provided for @maintenanceMessage.
  ///
  /// In fr, this message translates to:
  /// **'Ex : Application en maintenance...'**
  String get maintenanceMessage;

  /// No description provided for @signInWithGoogle.
  ///
  /// In fr, this message translates to:
  /// **'Se connecter avec Google'**
  String get signInWithGoogle;

  /// No description provided for @loginButton.
  ///
  /// In fr, this message translates to:
  /// **'Connexion'**
  String get loginButton;

  /// No description provided for @products.
  ///
  /// In fr, this message translates to:
  /// **'Produits ({count})'**
  String products(int count);

  /// No description provided for @orders.
  ///
  /// In fr, this message translates to:
  /// **'Commandes ({count})'**
  String orders(int count);

  /// No description provided for @disputes.
  ///
  /// In fr, this message translates to:
  /// **'Litiges ({count})'**
  String disputes(int count);

  /// No description provided for @sendButton.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer'**
  String get sendButton;

  /// No description provided for @emailAddress.
  ///
  /// In fr, this message translates to:
  /// **'Adresse email'**
  String get emailAddress;

  /// No description provided for @emailPlaceholder.
  ///
  /// In fr, this message translates to:
  /// **'utilisateur@example.com'**
  String get emailPlaceholder;

  /// No description provided for @passwordLabel.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe'**
  String get passwordLabel;

  /// No description provided for @businessCreated.
  ///
  /// In fr, this message translates to:
  /// **'Entreprise créée avec succès !'**
  String get businessCreated;

  /// No description provided for @businessName.
  ///
  /// In fr, this message translates to:
  /// **'Nom de l\'entreprise *'**
  String get businessName;

  /// No description provided for @telephone.
  ///
  /// In fr, this message translates to:
  /// **'Téléphone'**
  String get telephone;

  /// No description provided for @address.
  ///
  /// In fr, this message translates to:
  /// **'Adresse'**
  String get address;

  /// No description provided for @offeredServices.
  ///
  /// In fr, this message translates to:
  /// **'Services proposés'**
  String get offeredServices;

  /// No description provided for @addService.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un service'**
  String get addService;

  /// No description provided for @createBusiness.
  ///
  /// In fr, this message translates to:
  /// **'Créer l\'entreprise'**
  String get createBusiness;

  /// No description provided for @typeColon.
  ///
  /// In fr, this message translates to:
  /// **'Type :'**
  String get typeColon;

  /// No description provided for @durationColon.
  ///
  /// In fr, this message translates to:
  /// **'Durée :'**
  String get durationColon;

  /// No description provided for @totalColon.
  ///
  /// In fr, this message translates to:
  /// **'Total :'**
  String get totalColon;

  /// No description provided for @modifyReview.
  ///
  /// In fr, this message translates to:
  /// **'Modifier'**
  String get modifyReview;

  /// No description provided for @pleaseRate.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez noter'**
  String get pleaseRate;

  /// No description provided for @titleOptional.
  ///
  /// In fr, this message translates to:
  /// **'Titre (optionnel)'**
  String get titleOptional;

  /// No description provided for @titleExample.
  ///
  /// In fr, this message translates to:
  /// **'Ex : Excellent service'**
  String get titleExample;

  /// No description provided for @yourReview.
  ///
  /// In fr, this message translates to:
  /// **'Votre avis'**
  String get yourReview;

  /// No description provided for @shareExperience.
  ///
  /// In fr, this message translates to:
  /// **'Partagez votre expérience...'**
  String get shareExperience;

  /// No description provided for @addButton.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter'**
  String get addButton;

  /// No description provided for @imageLimitReached.
  ///
  /// In fr, this message translates to:
  /// **'Limite de 5 affiches atteinte'**
  String get imageLimitReached;

  /// No description provided for @photoLimitReached.
  ///
  /// In fr, this message translates to:
  /// **'Limite de 10 photos atteinte'**
  String get photoLimitReached;

  /// No description provided for @addPhotos.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter des photos ({current}/{max})'**
  String addPhotos(int current, int max);

  /// No description provided for @requestSubmitted.
  ///
  /// In fr, this message translates to:
  /// **'Demande soumise avec succès !'**
  String get requestSubmitted;

  /// No description provided for @exampleRequest.
  ///
  /// In fr, this message translates to:
  /// **'Ex : Demande concernant le passeport'**
  String get exampleRequest;

  /// No description provided for @describeRequest.
  ///
  /// In fr, this message translates to:
  /// **'Décrivez votre demande en détail...'**
  String get describeRequest;

  /// No description provided for @searchCountry.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un pays'**
  String get searchCountry;

  /// No description provided for @typeCountryName.
  ///
  /// In fr, this message translates to:
  /// **'Tapez le nom du pays'**
  String get typeCountryName;

  /// No description provided for @itinerary.
  ///
  /// In fr, this message translates to:
  /// **'Itinéraire'**
  String get itinerary;

  /// No description provided for @promoteAdminTitle.
  ///
  /// In fr, this message translates to:
  /// **'Promouvoir en administrateur'**
  String get promoteAdminTitle;

  /// No description provided for @removeAdminTitle.
  ///
  /// In fr, this message translates to:
  /// **'Retirer le rôle d\'administrateur'**
  String get removeAdminTitle;

  /// No description provided for @requestRefused.
  ///
  /// In fr, this message translates to:
  /// **'Demande refusée'**
  String get requestRefused;

  /// No description provided for @refuse.
  ///
  /// In fr, this message translates to:
  /// **'Refuser'**
  String get refuse;

  /// No description provided for @allLabel.
  ///
  /// In fr, this message translates to:
  /// **'Tous'**
  String get allLabel;

  /// No description provided for @allCategories.
  ///
  /// In fr, this message translates to:
  /// **'Tous'**
  String get allCategories;

  /// No description provided for @messagesLabel.
  ///
  /// In fr, this message translates to:
  /// **'Messages'**
  String get messagesLabel;

  /// No description provided for @groupsLabel.
  ///
  /// In fr, this message translates to:
  /// **'Groupes'**
  String get groupsLabel;

  /// No description provided for @directory.
  ///
  /// In fr, this message translates to:
  /// **'Annuaire'**
  String get directory;

  /// No description provided for @activateButton.
  ///
  /// In fr, this message translates to:
  /// **'ACTIVER'**
  String get activateButton;

  /// No description provided for @simpleMapTest.
  ///
  /// In fr, this message translates to:
  /// **'Test de carte simple'**
  String get simpleMapTest;

  /// No description provided for @addImage.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez au moins une image'**
  String get addImage;

  /// No description provided for @customRate.
  ///
  /// In fr, this message translates to:
  /// **'Taux personnalisé (%)'**
  String get customRate;

  /// No description provided for @rateExample.
  ///
  /// In fr, this message translates to:
  /// **'Ex : 15'**
  String get rateExample;

  /// No description provided for @tax.
  ///
  /// In fr, this message translates to:
  /// **'TVA ({rate}%)'**
  String tax(String rate);

  /// No description provided for @titlePlaceholder.
  ///
  /// In fr, this message translates to:
  /// **'Ex : iPhone 13 Pro Max'**
  String get titlePlaceholder;

  /// No description provided for @descriptionPlaceholder.
  ///
  /// In fr, this message translates to:
  /// **'Décrivez votre produit...'**
  String get descriptionPlaceholder;

  /// No description provided for @quantity.
  ///
  /// In fr, this message translates to:
  /// **'Quantité'**
  String get quantity;

  /// No description provided for @categoryLabel.
  ///
  /// In fr, this message translates to:
  /// **'Catégorie'**
  String get categoryLabel;

  /// No description provided for @condition.
  ///
  /// In fr, this message translates to:
  /// **'État'**
  String get condition;

  /// No description provided for @cityAddress.
  ///
  /// In fr, this message translates to:
  /// **'Ville/Adresse (optionnel)'**
  String get cityAddress;

  /// No description provided for @cityExample.
  ///
  /// In fr, this message translates to:
  /// **'Ex : Niamey'**
  String get cityExample;

  /// No description provided for @everything.
  ///
  /// In fr, this message translates to:
  /// **'Tout'**
  String get everything;

  /// No description provided for @published.
  ///
  /// In fr, this message translates to:
  /// **'publié'**
  String get published;

  /// No description provided for @pdfLabel.
  ///
  /// In fr, this message translates to:
  /// **'PDF'**
  String get pdfLabel;

  /// No description provided for @docLabel.
  ///
  /// In fr, this message translates to:
  /// **'DOC'**
  String get docLabel;

  /// No description provided for @xlsLabel.
  ///
  /// In fr, this message translates to:
  /// **'XLS'**
  String get xlsLabel;

  /// No description provided for @pptLabel.
  ///
  /// In fr, this message translates to:
  /// **'PPT'**
  String get pptLabel;

  /// No description provided for @zipLabel.
  ///
  /// In fr, this message translates to:
  /// **'ZIP'**
  String get zipLabel;

  /// No description provided for @txtLabel.
  ///
  /// In fr, this message translates to:
  /// **'TXT'**
  String get txtLabel;

  /// No description provided for @csvLabel.
  ///
  /// In fr, this message translates to:
  /// **'CSV'**
  String get csvLabel;

  /// No description provided for @jsonLabel.
  ///
  /// In fr, this message translates to:
  /// **'JSON'**
  String get jsonLabel;

  /// No description provided for @joinLabel.
  ///
  /// In fr, this message translates to:
  /// **'Rejoindre'**
  String get joinLabel;

  /// No description provided for @remindLater.
  ///
  /// In fr, this message translates to:
  /// **'Me rappeler plus tard'**
  String get remindLater;

  /// No description provided for @audioRoomsReminderSet.
  ///
  /// In fr, this message translates to:
  /// **'Rappel activé — vous serez prévenu'**
  String get audioRoomsReminderSet;

  /// No description provided for @audioRoomsStartingSoon.
  ///
  /// In fr, this message translates to:
  /// **'Le salon va commencer'**
  String get audioRoomsStartingSoon;

  /// No description provided for @inOneHour.
  ///
  /// In fr, this message translates to:
  /// **'Dans 1 heure'**
  String get inOneHour;

  /// No description provided for @exampleBank.
  ///
  /// In fr, this message translates to:
  /// **'Ex : BCEAO, Ecobank...'**
  String get exampleBank;

  /// No description provided for @ibanExample.
  ///
  /// In fr, this message translates to:
  /// **'NEXX XXXX XXXX XXXX'**
  String get ibanExample;

  /// No description provided for @categoryRequired.
  ///
  /// In fr, this message translates to:
  /// **'Catégorie *'**
  String get categoryRequired;

  /// No description provided for @languageRequired.
  ///
  /// In fr, this message translates to:
  /// **'Langue *'**
  String get languageRequired;

  /// No description provided for @publicationFrequency.
  ///
  /// In fr, this message translates to:
  /// **'Fréquence de publication'**
  String get publicationFrequency;

  /// No description provided for @addTag.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un tag'**
  String get addTag;

  /// No description provided for @likes.
  ///
  /// In fr, this message translates to:
  /// **'J\'aime'**
  String get likes;

  /// No description provided for @sleepTimerEnded.
  ///
  /// In fr, this message translates to:
  /// **'Minuteur de sommeil terminé'**
  String get sleepTimerEnded;

  /// No description provided for @timerMinutes.
  ///
  /// In fr, this message translates to:
  /// **'Minuteur : {minutes} minutes'**
  String timerMinutes(int minutes);

  /// No description provided for @episodeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Titre de l\'épisode *'**
  String get episodeTitle;

  /// No description provided for @episodeDescription.
  ///
  /// In fr, this message translates to:
  /// **'Description / Notes'**
  String get episodeDescription;

  /// No description provided for @reservedForSubscribers.
  ///
  /// In fr, this message translates to:
  /// **'Réservé aux abonnés payants'**
  String get reservedForSubscribers;

  /// No description provided for @downloaded.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargé'**
  String get downloaded;

  /// No description provided for @selectPodcast.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionnez un podcast ou créez-en un nouveau'**
  String get selectPodcast;

  /// No description provided for @recordingAvailableSoon.
  ///
  /// In fr, this message translates to:
  /// **'L\'enregistrement sera disponible bientôt'**
  String get recordingAvailableSoon;

  /// No description provided for @episodeTitlePlaceholder.
  ///
  /// In fr, this message translates to:
  /// **'Titre de l\'épisode'**
  String get episodeTitlePlaceholder;

  /// No description provided for @episodeDescriptionPlaceholder.
  ///
  /// In fr, this message translates to:
  /// **'Description de l\'épisode (optionnel)'**
  String get episodeDescriptionPlaceholder;

  /// No description provided for @codeSent.
  ///
  /// In fr, this message translates to:
  /// **'Code envoyé à {phone}'**
  String codeSent(String phone);

  /// No description provided for @describeIssue.
  ///
  /// In fr, this message translates to:
  /// **'Décrivez le problème...'**
  String get describeIssue;

  /// No description provided for @connectedDevicesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Appareils connectés'**
  String get connectedDevicesTitle;

  /// No description provided for @backupKeys.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarde des clés'**
  String get backupKeys;

  /// No description provided for @deleteBackupQuestion.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer la sauvegarde ?'**
  String get deleteBackupQuestion;

  /// No description provided for @generateSecurePassphrase.
  ///
  /// In fr, this message translates to:
  /// **'Générer une phrase secrète sécurisée'**
  String get generateSecurePassphrase;

  /// No description provided for @minimumChars.
  ///
  /// In fr, this message translates to:
  /// **'Minimum 8 caractères'**
  String get minimumChars;

  /// No description provided for @termsOfUse.
  ///
  /// In fr, this message translates to:
  /// **'Conditions d\'utilisation'**
  String get termsOfUse;

  /// No description provided for @bugDescriptionLabel.
  ///
  /// In fr, this message translates to:
  /// **'Description du bug'**
  String get bugDescriptionLabel;

  /// No description provided for @bugDescriptionPlaceholder.
  ///
  /// In fr, this message translates to:
  /// **'Décrivez le problème rencontré...'**
  String get bugDescriptionPlaceholder;

  /// No description provided for @addRecipient.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un destinataire'**
  String get addRecipient;

  /// No description provided for @newRecipient.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau'**
  String get newRecipient;

  /// No description provided for @deleteRecipientQuestion.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le destinataire ?'**
  String get deleteRecipientQuestion;

  /// No description provided for @deleteRecipientConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Voulez-vous supprimer {name} ?'**
  String deleteRecipientConfirm(String name);

  /// No description provided for @deleteQuestion.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer ?'**
  String get deleteQuestion;

  /// No description provided for @sendMoney.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer de l\'argent'**
  String get sendMoney;

  /// No description provided for @deleteConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer {name} ?'**
  String deleteConfirm(String name);

  /// No description provided for @retryTransfer.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer le transfert'**
  String get retryTransfer;

  /// No description provided for @contactSupport.
  ///
  /// In fr, this message translates to:
  /// **'Contacter le support'**
  String get contactSupport;

  /// No description provided for @debitInProgress.
  ///
  /// In fr, this message translates to:
  /// **'Débit en cours'**
  String get debitInProgress;

  /// No description provided for @inProgress.
  ///
  /// In fr, this message translates to:
  /// **'En cours'**
  String get inProgress;

  /// No description provided for @sendingInProgress.
  ///
  /// In fr, this message translates to:
  /// **'Envoi en cours'**
  String get sendingInProgress;

  /// No description provided for @completed.
  ///
  /// In fr, this message translates to:
  /// **'Terminé'**
  String get completed;

  /// No description provided for @failed.
  ///
  /// In fr, this message translates to:
  /// **'Échoué'**
  String get failed;

  /// No description provided for @refundInProgress.
  ///
  /// In fr, this message translates to:
  /// **'Remboursement en cours'**
  String get refundInProgress;

  /// No description provided for @refunded.
  ///
  /// In fr, this message translates to:
  /// **'Remboursé'**
  String get refunded;

  /// No description provided for @cancelled.
  ///
  /// In fr, this message translates to:
  /// **'Annulé'**
  String get cancelled;

  /// No description provided for @liveChat.
  ///
  /// In fr, this message translates to:
  /// **'Chat en direct'**
  String get liveChat;

  /// No description provided for @liveChatAvailable.
  ///
  /// In fr, this message translates to:
  /// **'Disponible 24h/24 7j/7'**
  String get liveChatAvailable;

  /// No description provided for @chatNotAvailable.
  ///
  /// In fr, this message translates to:
  /// **'Chat non disponible pour le moment'**
  String get chatNotAvailable;

  /// No description provided for @sendMoneyButton.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer de l\'argent'**
  String get sendMoneyButton;

  /// No description provided for @applicationError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de l\'application : {error}'**
  String applicationError(String error);

  /// No description provided for @helperText.
  ///
  /// In fr, this message translates to:
  /// **'Min : {min} XOF - Max : {max} XOF'**
  String helperText(String min, String max);

  /// No description provided for @tales.
  ///
  /// In fr, this message translates to:
  /// **'Contes'**
  String get tales;

  /// No description provided for @proverbs.
  ///
  /// In fr, this message translates to:
  /// **'Proverbes'**
  String get proverbs;

  /// No description provided for @ceremonies.
  ///
  /// In fr, this message translates to:
  /// **'Cérémonies'**
  String get ceremonies;

  /// No description provided for @craft.
  ///
  /// In fr, this message translates to:
  /// **'Artisanat'**
  String get craft;

  /// No description provided for @recipes.
  ///
  /// In fr, this message translates to:
  /// **'Recettes'**
  String get recipes;

  /// No description provided for @medicine.
  ///
  /// In fr, this message translates to:
  /// **'Médecine'**
  String get medicine;

  /// No description provided for @automatic.
  ///
  /// In fr, this message translates to:
  /// **'Automatique'**
  String get automatic;

  /// No description provided for @exempt.
  ///
  /// In fr, this message translates to:
  /// **'Exempté'**
  String get exempt;

  /// No description provided for @standardVAT.
  ///
  /// In fr, this message translates to:
  /// **'TVA standard (19%)'**
  String get standardVAT;

  /// No description provided for @reducedVAT.
  ///
  /// In fr, this message translates to:
  /// **'TVA réduite (10%)'**
  String get reducedVAT;

  /// No description provided for @custom.
  ///
  /// In fr, this message translates to:
  /// **'Personnalisé'**
  String get custom;

  /// No description provided for @typeYourResponse.
  ///
  /// In fr, this message translates to:
  /// **'Tapez votre réponse...'**
  String get typeYourResponse;

  /// No description provided for @forYouTab.
  ///
  /// In fr, this message translates to:
  /// **'Pour toi'**
  String get forYouTab;

  /// No description provided for @followingTab.
  ///
  /// In fr, this message translates to:
  /// **'Suivis'**
  String get followingTab;

  /// No description provided for @recentTab.
  ///
  /// In fr, this message translates to:
  /// **'Récent'**
  String get recentTab;

  /// No description provided for @audioRoomsAvailableCount.
  ///
  /// In fr, this message translates to:
  /// **'{count} salons disponibles'**
  String audioRoomsAvailableCount(int count);

  /// No description provided for @audioRoomsLiveTabLabel.
  ///
  /// In fr, this message translates to:
  /// **'Live ({count})'**
  String audioRoomsLiveTabLabel(int count);

  /// No description provided for @audioRoomsScheduledTabLabel.
  ///
  /// In fr, this message translates to:
  /// **'Programmés ({count})'**
  String audioRoomsScheduledTabLabel(int count);

  /// No description provided for @audioRoomsNoLiveRooms.
  ///
  /// In fr, this message translates to:
  /// **'Aucun salon live'**
  String get audioRoomsNoLiveRooms;

  /// No description provided for @audioRoomsNoLiveSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Soyez le premier à démarrer'**
  String get audioRoomsNoLiveSubtitle;

  /// No description provided for @audioRoomsNoScheduledRooms.
  ///
  /// In fr, this message translates to:
  /// **'Aucun salon programmé'**
  String get audioRoomsNoScheduledRooms;

  /// No description provided for @audioRoomsNoScheduledSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Planifiez une session'**
  String get audioRoomsNoScheduledSubtitle;

  /// No description provided for @audioRoomsLiveListeners.
  ///
  /// In fr, this message translates to:
  /// **'LIVE · {count} auditeurs'**
  String audioRoomsLiveListeners(int count);

  /// No description provided for @audioRoomsRegisteredCount.
  ///
  /// In fr, this message translates to:
  /// **'{count} inscrits'**
  String audioRoomsRegisteredCount(int count);

  /// No description provided for @audioRoomsScheduleButton.
  ///
  /// In fr, this message translates to:
  /// **'Programmer'**
  String get audioRoomsScheduleButton;

  /// No description provided for @audioRoomConnecting.
  ///
  /// In fr, this message translates to:
  /// **'Connexion en cours…'**
  String get audioRoomConnecting;

  /// No description provided for @audioRoomDefaultTitle.
  ///
  /// In fr, this message translates to:
  /// **'Salon audio'**
  String get audioRoomDefaultTitle;

  /// No description provided for @audioRoomParticipantsOnStage.
  ///
  /// In fr, this message translates to:
  /// **'Sur scène · {count}/{max}'**
  String audioRoomParticipantsOnStage(int count, int max);

  /// No description provided for @audioRoomListenersCount.
  ///
  /// In fr, this message translates to:
  /// **'Auditeurs · {count}'**
  String audioRoomListenersCount(int count);

  /// No description provided for @audioRoomHandsRaisedCount.
  ///
  /// In fr, this message translates to:
  /// **'{count} mains levées'**
  String audioRoomHandsRaisedCount(int count);

  /// No description provided for @audioRoomHandsRaisedSection.
  ///
  /// In fr, this message translates to:
  /// **'Mains levées · {count}'**
  String audioRoomHandsRaisedSection(int count);

  /// No description provided for @audioRoomEndConfirmTitle.
  ///
  /// In fr, this message translates to:
  /// **'Terminer le salon ?'**
  String get audioRoomEndConfirmTitle;

  /// No description provided for @audioRoomEndConfirmMessage.
  ///
  /// In fr, this message translates to:
  /// **'Tous les participants seront déconnectés.'**
  String get audioRoomEndConfirmMessage;

  /// No description provided for @audioRoomGhostMode.
  ///
  /// In fr, this message translates to:
  /// **'Mode fantôme · admin invisible'**
  String get audioRoomGhostMode;

  /// No description provided for @audioRoomSuperAdmin.
  ///
  /// In fr, this message translates to:
  /// **'SuperAdmin'**
  String get audioRoomSuperAdmin;

  /// No description provided for @audioRoomModerators.
  ///
  /// In fr, this message translates to:
  /// **'Modérateurs'**
  String get audioRoomModerators;

  /// No description provided for @audioRoomMuteLabel.
  ///
  /// In fr, this message translates to:
  /// **'Muet'**
  String get audioRoomMuteLabel;

  /// No description provided for @audioRoomActiveLabel.
  ///
  /// In fr, this message translates to:
  /// **'Activé'**
  String get audioRoomActiveLabel;

  /// No description provided for @audioRoomStatsLabel.
  ///
  /// In fr, this message translates to:
  /// **'Stats'**
  String get audioRoomStatsLabel;

  /// No description provided for @audioRoomCameraLabel.
  ///
  /// In fr, this message translates to:
  /// **'Caméra'**
  String get audioRoomCameraLabel;

  /// No description provided for @audioRoomHandLabel.
  ///
  /// In fr, this message translates to:
  /// **'Main'**
  String get audioRoomHandLabel;

  /// No description provided for @audioRoomGoDownLabel.
  ///
  /// In fr, this message translates to:
  /// **'Descendre'**
  String get audioRoomGoDownLabel;

  /// No description provided for @audioRoomTipLabel.
  ///
  /// In fr, this message translates to:
  /// **'Pourboire'**
  String get audioRoomTipLabel;

  /// No description provided for @audioRoomShareLabel.
  ///
  /// In fr, this message translates to:
  /// **'Partager'**
  String get audioRoomShareLabel;

  /// No description provided for @audioRoomLeaveLabel.
  ///
  /// In fr, this message translates to:
  /// **'Quitter'**
  String get audioRoomLeaveLabel;

  /// No description provided for @audioRoomEndLabel.
  ///
  /// In fr, this message translates to:
  /// **'Terminer'**
  String get audioRoomEndLabel;

  /// No description provided for @audioRoomInviteLabel.
  ///
  /// In fr, this message translates to:
  /// **'Inviter'**
  String get audioRoomInviteLabel;

  /// No description provided for @audioRoomCoHostLabel.
  ///
  /// In fr, this message translates to:
  /// **'Co-hôte'**
  String get audioRoomCoHostLabel;

  /// No description provided for @audioRoomMuteAction.
  ///
  /// In fr, this message translates to:
  /// **'Muet'**
  String get audioRoomMuteAction;

  /// No description provided for @audioRoomKickLabel.
  ///
  /// In fr, this message translates to:
  /// **'Exclure'**
  String get audioRoomKickLabel;

  /// No description provided for @audioRoomBlockLabel.
  ///
  /// In fr, this message translates to:
  /// **'Bloquer'**
  String get audioRoomBlockLabel;

  /// No description provided for @audioRoomWarnLabel.
  ///
  /// In fr, this message translates to:
  /// **'Avertir'**
  String get audioRoomWarnLabel;

  /// No description provided for @cannotLaunchPhoneDialer.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de lancer le téléphone'**
  String get cannotLaunchPhoneDialer;

  /// No description provided for @cannotLaunchEmailClient.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de lancer le client email'**
  String get cannotLaunchEmailClient;

  /// No description provided for @cannotOpenWebsite.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'ouvrir le site web'**
  String get cannotOpenWebsite;

  /// No description provided for @cannotOpenMaps.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'ouvrir les cartes'**
  String get cannotOpenMaps;

  /// No description provided for @liveMicLabel.
  ///
  /// In fr, this message translates to:
  /// **'Micro'**
  String get liveMicLabel;

  /// No description provided for @liveMicMuted.
  ///
  /// In fr, this message translates to:
  /// **'Micro coupé'**
  String get liveMicMuted;

  /// No description provided for @liveCameraLabel.
  ///
  /// In fr, this message translates to:
  /// **'Caméra'**
  String get liveCameraLabel;

  /// No description provided for @liveCameraOff.
  ///
  /// In fr, this message translates to:
  /// **'Caméra off'**
  String get liveCameraOff;

  /// No description provided for @liveEndLabel.
  ///
  /// In fr, this message translates to:
  /// **'Terminer'**
  String get liveEndLabel;

  /// No description provided for @liveStartBroadcast.
  ///
  /// In fr, this message translates to:
  /// **'Démarrer le direct'**
  String get liveStartBroadcast;

  /// No description provided for @liveConnecting.
  ///
  /// In fr, this message translates to:
  /// **'Connexion…'**
  String get liveConnecting;

  /// No description provided for @searchForGroupLabel.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un groupe'**
  String get searchForGroupLabel;

  /// No description provided for @searchForDiscussionLabel.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher une discussion'**
  String get searchForDiscussionLabel;

  /// No description provided for @searchForFriendLabel.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un ami'**
  String get searchForFriendLabel;

  /// No description provided for @searchForMemberLabel.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un membre'**
  String get searchForMemberLabel;

  /// No description provided for @searchLabel.
  ///
  /// In fr, this message translates to:
  /// **'Recherche'**
  String get searchLabel;

  /// No description provided for @searchDiscussionHint.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher une discussion...'**
  String get searchDiscussionHint;

  /// No description provided for @searchFriendHint.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un ami...'**
  String get searchFriendHint;

  /// No description provided for @searchMembersOrGroupsHint.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher des membres ou groupes...'**
  String get searchMembersOrGroupsHint;

  /// No description provided for @searchMembersOrGroupsPrompt.
  ///
  /// In fr, this message translates to:
  /// **'Recherchez des membres ou groupes'**
  String get searchMembersOrGroupsPrompt;

  /// No description provided for @membersSection.
  ///
  /// In fr, this message translates to:
  /// **'Membres'**
  String get membersSection;

  /// No description provided for @groupsSection.
  ///
  /// In fr, this message translates to:
  /// **'Groupes'**
  String get groupsSection;

  /// No description provided for @conversationsSection.
  ///
  /// In fr, this message translates to:
  /// **'Discussions'**
  String get conversationsSection;

  /// No description provided for @memberDefault.
  ///
  /// In fr, this message translates to:
  /// **'Membre'**
  String get memberDefault;

  /// No description provided for @friendLabel.
  ///
  /// In fr, this message translates to:
  /// **'Ami'**
  String get friendLabel;

  /// No description provided for @conversationDefault.
  ///
  /// In fr, this message translates to:
  /// **'Conversation'**
  String get conversationDefault;

  /// No description provided for @adminConfirmDisconnect.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer la déconnexion'**
  String get adminConfirmDisconnect;

  /// No description provided for @adminDisconnectDevicesConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Voulez-vous vraiment déconnecter {userName} de tous ses appareils ?'**
  String adminDisconnectDevicesConfirm(String userName);

  /// No description provided for @adminNotConnectedError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur: Admin non connecté'**
  String get adminNotConnectedError;

  /// No description provided for @adminUsersTitle.
  ///
  /// In fr, this message translates to:
  /// **'Gestion des Utilisateurs'**
  String get adminUsersTitle;

  /// No description provided for @adminUsersDesc.
  ///
  /// In fr, this message translates to:
  /// **'Gérez les comptes utilisateurs et les sessions'**
  String get adminUsersDesc;

  /// No description provided for @neverConnected.
  ///
  /// In fr, this message translates to:
  /// **'Jamais'**
  String get neverConnected;

  /// No description provided for @noEmail.
  ///
  /// In fr, this message translates to:
  /// **'Pas d\'email'**
  String get noEmail;

  /// No description provided for @adminRoleLabel.
  ///
  /// In fr, this message translates to:
  /// **'Admin'**
  String get adminRoleLabel;

  /// No description provided for @bannedLabel.
  ///
  /// In fr, this message translates to:
  /// **'Banni'**
  String get bannedLabel;

  /// No description provided for @userDefault.
  ///
  /// In fr, this message translates to:
  /// **'Utilisateur'**
  String get userDefault;

  /// No description provided for @adminForceDisconnect.
  ///
  /// In fr, this message translates to:
  /// **'Déconnecter de force'**
  String get adminForceDisconnect;

  /// No description provided for @loadingUsers.
  ///
  /// In fr, this message translates to:
  /// **'Chargement des utilisateurs...'**
  String get loadingUsers;

  /// No description provided for @noUsersFound.
  ///
  /// In fr, this message translates to:
  /// **'Aucun utilisateur trouvé'**
  String get noUsersFound;

  /// No description provided for @adminTaxRatesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Taux de TVA par catégorie'**
  String get adminTaxRatesTitle;

  /// No description provided for @adminTaxRatesDesc.
  ///
  /// In fr, this message translates to:
  /// **'Définissez les taux applicables à chaque catégorie'**
  String get adminTaxRatesDesc;

  /// No description provided for @adminImagesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Images'**
  String get adminImagesTitle;

  /// No description provided for @adminImagesDesc.
  ///
  /// In fr, this message translates to:
  /// **'Configuration des images uploadées'**
  String get adminImagesDesc;

  /// No description provided for @adminImagesDimensionHint.
  ///
  /// In fr, this message translates to:
  /// **'Largeur et hauteur max'**
  String get adminImagesDimensionHint;

  /// No description provided for @adminVideosTitle.
  ///
  /// In fr, this message translates to:
  /// **'Vidéos'**
  String get adminVideosTitle;

  /// No description provided for @adminVideosDesc.
  ///
  /// In fr, this message translates to:
  /// **'Limites pour les vidéos'**
  String get adminVideosDesc;

  /// No description provided for @adminMessagesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Messages'**
  String get adminMessagesTitle;

  /// No description provided for @adminMessagesDesc.
  ///
  /// In fr, this message translates to:
  /// **'Configuration des messages'**
  String get adminMessagesDesc;

  /// No description provided for @adminMaxValueConstraint.
  ///
  /// In fr, this message translates to:
  /// **'Max: {max}'**
  String adminMaxValueConstraint(int max);

  /// No description provided for @adminUrlsAndContactTitle.
  ///
  /// In fr, this message translates to:
  /// **'URLs & Contact'**
  String get adminUrlsAndContactTitle;

  /// No description provided for @adminUrlsAndContactDesc.
  ///
  /// In fr, this message translates to:
  /// **'Configuration des liens et emails'**
  String get adminUrlsAndContactDesc;

  /// No description provided for @adminIntervalsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Intervalles système'**
  String get adminIntervalsTitle;

  /// No description provided for @adminIntervalsDesc.
  ///
  /// In fr, this message translates to:
  /// **'Fréquences de mise à jour'**
  String get adminIntervalsDesc;

  /// No description provided for @audioRoomForceCloseTitle.
  ///
  /// In fr, this message translates to:
  /// **'Forcer la fermeture ?'**
  String get audioRoomForceCloseTitle;

  /// No description provided for @audioRoomForceButton.
  ///
  /// In fr, this message translates to:
  /// **'Forcer'**
  String get audioRoomForceButton;

  /// No description provided for @scheduleRoomTitle.
  ///
  /// In fr, this message translates to:
  /// **'Programmer'**
  String get scheduleRoomTitle;

  /// No description provided for @scheduleRoomMultiTimezone.
  ///
  /// In fr, this message translates to:
  /// **'multi-fuseaux horaires'**
  String get scheduleRoomMultiTimezone;

  /// No description provided for @scheduleNewRoomLabel.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau salon'**
  String get scheduleNewRoomLabel;

  /// No description provided for @errorLoadingStickers.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors du chargement des stickers'**
  String get errorLoadingStickers;

  /// No description provided for @noRecentStickers.
  ///
  /// In fr, this message translates to:
  /// **'Aucun sticker récent'**
  String get noRecentStickers;

  /// No description provided for @errorLoadingRecentStickers.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors du chargement des stickers récents'**
  String get errorLoadingRecentStickers;

  /// No description provided for @noFavoriteStickers.
  ///
  /// In fr, this message translates to:
  /// **'Aucun sticker favori'**
  String get noFavoriteStickers;

  /// No description provided for @addToFavoritesHint.
  ///
  /// In fr, this message translates to:
  /// **'Appui long pour ajouter aux favoris'**
  String get addToFavoritesHint;

  /// No description provided for @errorLoadingFavorites.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors du chargement des favoris'**
  String get errorLoadingFavorites;

  /// No description provided for @noStickersInPack.
  ///
  /// In fr, this message translates to:
  /// **'Aucun sticker dans ce pack'**
  String get noStickersInPack;

  /// No description provided for @addToFavorites.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter aux favoris'**
  String get addToFavorites;

  /// No description provided for @audioRoomForceCloseLabel.
  ///
  /// In fr, this message translates to:
  /// **'Forcer la fermeture'**
  String get audioRoomForceCloseLabel;

  /// No description provided for @audioRoomForceCloseDesc.
  ///
  /// In fr, this message translates to:
  /// **'Le salon sera immédiatement fermé et l\'action sera auditée.'**
  String get audioRoomForceCloseDesc;

  /// No description provided for @audioRoomForceCloseAuditNote.
  ///
  /// In fr, this message translates to:
  /// **'Action irréversible · log audit'**
  String get audioRoomForceCloseAuditNote;

  /// No description provided for @ghostListeners.
  ///
  /// In fr, this message translates to:
  /// **'Auditeurs'**
  String get ghostListeners;

  /// No description provided for @ghostSpeakers.
  ///
  /// In fr, this message translates to:
  /// **'Speakers'**
  String get ghostSpeakers;

  /// No description provided for @ghostReports.
  ///
  /// In fr, this message translates to:
  /// **'Signalements'**
  String get ghostReports;

  /// No description provided for @ghostDuration.
  ///
  /// In fr, this message translates to:
  /// **'Durée'**
  String get ghostDuration;

  /// No description provided for @creatorEarningsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mes Gains'**
  String get creatorEarningsTitle;

  /// No description provided for @withdrawalRequestTitle.
  ///
  /// In fr, this message translates to:
  /// **'Demande de retrait'**
  String get withdrawalRequestTitle;

  /// No description provided for @withdrawalAmountLabel.
  ///
  /// In fr, this message translates to:
  /// **'Montant à retirer'**
  String get withdrawalAmountLabel;

  /// No description provided for @tipEarningsLabel.
  ///
  /// In fr, this message translates to:
  /// **'Pourboires'**
  String get tipEarningsLabel;

  /// No description provided for @ticketEarningsLabel.
  ///
  /// In fr, this message translates to:
  /// **'Billets de salle'**
  String get ticketEarningsLabel;

  /// No description provided for @subscriptionEarningsLabel.
  ///
  /// In fr, this message translates to:
  /// **'Abonnements'**
  String get subscriptionEarningsLabel;

  /// No description provided for @replayEarningsLabel.
  ///
  /// In fr, this message translates to:
  /// **'Replays'**
  String get replayEarningsLabel;

  /// No description provided for @totalLabel.
  ///
  /// In fr, this message translates to:
  /// **'Total'**
  String get totalLabel;

  /// No description provided for @stripeDashboardButton.
  ///
  /// In fr, this message translates to:
  /// **'Tableau de bord Stripe'**
  String get stripeDashboardButton;

  /// No description provided for @audioRoomVideoEnabled.
  ///
  /// In fr, this message translates to:
  /// **'Vidéo activée'**
  String get audioRoomVideoEnabled;

  /// No description provided for @audioRoomTicketPriceField.
  ///
  /// In fr, this message translates to:
  /// **'Prix du billet (€)'**
  String get audioRoomTicketPriceField;

  /// No description provided for @audioRoomEnableFundraising.
  ///
  /// In fr, this message translates to:
  /// **'Activer une collecte'**
  String get audioRoomEnableFundraising;

  /// No description provided for @audioRoomFundraisingGoal.
  ///
  /// In fr, this message translates to:
  /// **'Objectif (€)'**
  String get audioRoomFundraisingGoal;

  /// No description provided for @audioRoomBeneficiary.
  ///
  /// In fr, this message translates to:
  /// **'Bénéficiaire'**
  String get audioRoomBeneficiary;

  /// No description provided for @audioRoomLinkedTo.
  ///
  /// In fr, this message translates to:
  /// **'Lié à'**
  String get audioRoomLinkedTo;

  /// No description provided for @audioRoomEmbassyLink.
  ///
  /// In fr, this message translates to:
  /// **'Ambassade'**
  String get audioRoomEmbassyLink;

  /// No description provided for @selectVideoFirst.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez sélectionner une vidéo'**
  String get selectVideoFirst;

  /// No description provided for @subscribeButton.
  ///
  /// In fr, this message translates to:
  /// **'S\'abonner'**
  String get subscribeButton;

  /// No description provided for @previewTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Prévisualiser'**
  String get previewTooltip;

  /// No description provided for @subscriptionActivated.
  ///
  /// In fr, this message translates to:
  /// **'Abonnement activé !'**
  String get subscriptionActivated;

  /// No description provided for @liveBadge.
  ///
  /// In fr, this message translates to:
  /// **'DIRECT'**
  String get liveBadge;

  /// No description provided for @chaptersPill.
  ///
  /// In fr, this message translates to:
  /// **'Chapitres'**
  String get chaptersPill;

  /// No description provided for @replayBadge.
  ///
  /// In fr, this message translates to:
  /// **'REPLAY'**
  String get replayBadge;

  /// No description provided for @sleepTimer.
  ///
  /// In fr, this message translates to:
  /// **'Minuteur'**
  String get sleepTimer;

  /// No description provided for @sleepTimerOff.
  ///
  /// In fr, this message translates to:
  /// **'Désactivé'**
  String get sleepTimerOff;

  /// No description provided for @saveAsPodcastTitle.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarder comme podcast'**
  String get saveAsPodcastTitle;

  /// No description provided for @saveAsPodcastSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'post-production'**
  String get saveAsPodcastSubtitle;

  /// No description provided for @postPublicationTips.
  ///
  /// In fr, this message translates to:
  /// **'Pourboires post-publication'**
  String get postPublicationTips;

  /// No description provided for @keepPrivate.
  ///
  /// In fr, this message translates to:
  /// **'Garder privé'**
  String get keepPrivate;

  /// No description provided for @paidRoomBadge.
  ///
  /// In fr, this message translates to:
  /// **'SALON PAYANT'**
  String get paidRoomBadge;

  /// No description provided for @verifiedHostBadge.
  ///
  /// In fr, this message translates to:
  /// **'hôte vérifié'**
  String get verifiedHostBadge;

  /// No description provided for @hostShareLabel.
  ///
  /// In fr, this message translates to:
  /// **'Reversé à l\'hôte'**
  String get hostShareLabel;

  /// No description provided for @paymentMethodLabel.
  ///
  /// In fr, this message translates to:
  /// **'MÉTHODE DE PAIEMENT'**
  String get paymentMethodLabel;

  /// No description provided for @optionalMessageHint.
  ///
  /// In fr, this message translates to:
  /// **'Message (optionnel)…'**
  String get optionalMessageHint;

  /// No description provided for @creditCardMethod.
  ///
  /// In fr, this message translates to:
  /// **'Carte bancaire (Stripe)'**
  String get creditCardMethod;

  /// No description provided for @creditCardBrands.
  ///
  /// In fr, this message translates to:
  /// **'Visa, Mastercard, Apple Pay, Google Pay'**
  String get creditCardBrands;

  /// No description provided for @mobileMoneyMethod.
  ///
  /// In fr, this message translates to:
  /// **'Mobile Money'**
  String get mobileMoneyMethod;

  /// No description provided for @mobileMoneyBrands.
  ///
  /// In fr, this message translates to:
  /// **'Mynita, Wave (bientot)'**
  String get mobileMoneyBrands;

  /// No description provided for @ceremonyRoomLabel.
  ///
  /// In fr, this message translates to:
  /// **'Cérémonie · Diffusion famille élargie'**
  String get ceremonyRoomLabel;

  /// No description provided for @moderatorInitialLabel.
  ///
  /// In fr, this message translates to:
  /// **'M'**
  String get moderatorInitialLabel;

  /// No description provided for @timezonesLabel.
  ///
  /// In fr, this message translates to:
  /// **'FUSEAUX HORAIRES'**
  String get timezonesLabel;

  /// No description provided for @niamieyTimezoneLabel.
  ///
  /// In fr, this message translates to:
  /// **'GMT+1 · Niamey'**
  String get niamieyTimezoneLabel;

  /// No description provided for @kenteMotifAuto.
  ///
  /// In fr, this message translates to:
  /// **'Motif kente auto-généré'**
  String get kenteMotifAuto;

  /// No description provided for @autoLabel.
  ///
  /// In fr, this message translates to:
  /// **'AUTO'**
  String get autoLabel;

  /// No description provided for @laterButton.
  ///
  /// In fr, this message translates to:
  /// **'Plus tard'**
  String get laterButton;

  /// No description provided for @bankNameHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex: BCEAO, Ecobank...'**
  String get bankNameHint;

  /// No description provided for @ibanHint.
  ///
  /// In fr, this message translates to:
  /// **'NEXX XXXX XXXX XXXX'**
  String get ibanHint;

  /// No description provided for @adTransferTitle.
  ///
  /// In fr, this message translates to:
  /// **'Envoyez de l\'argent au Niger'**
  String get adTransferTitle;

  /// No description provided for @adTransferSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Transferts rapides et sécurisés vers vos proches'**
  String get adTransferSubtitle;

  /// No description provided for @adTransferCta.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer maintenant'**
  String get adTransferCta;

  /// No description provided for @adGroupTitle.
  ///
  /// In fr, this message translates to:
  /// **'Rejoignez un groupe diaspora'**
  String get adGroupTitle;

  /// No description provided for @adGroupSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Connectez-vous avec des Nigériens près de chez vous'**
  String get adGroupSubtitle;

  /// No description provided for @adGroupCta.
  ///
  /// In fr, this message translates to:
  /// **'Découvrir les groupes'**
  String get adGroupCta;

  /// No description provided for @adMarketplaceTitle.
  ///
  /// In fr, this message translates to:
  /// **'Marketplace Diaspo Niger'**
  String get adMarketplaceTitle;

  /// No description provided for @adMarketplaceSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Achetez et vendez au sein de la communauté'**
  String get adMarketplaceSubtitle;

  /// No description provided for @adMarketplaceCta.
  ///
  /// In fr, this message translates to:
  /// **'Explorer le marché'**
  String get adMarketplaceCta;

  /// No description provided for @adAudioRoomsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Salons audio en direct'**
  String get adAudioRoomsTitle;

  /// No description provided for @adAudioRoomsSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Rejoignez des discussions en temps réel'**
  String get adAudioRoomsSubtitle;

  /// No description provided for @adAudioRoomsCta.
  ///
  /// In fr, this message translates to:
  /// **'Voir les salons'**
  String get adAudioRoomsCta;

  /// No description provided for @notifGroupOrders.
  ///
  /// In fr, this message translates to:
  /// **'Commandes'**
  String get notifGroupOrders;

  /// No description provided for @notifGroupProximity.
  ///
  /// In fr, this message translates to:
  /// **'Alertes proximité'**
  String get notifGroupProximity;

  /// No description provided for @notifGroupCalls.
  ///
  /// In fr, this message translates to:
  /// **'Appels'**
  String get notifGroupCalls;

  /// No description provided for @notifGroupAudioRooms.
  ///
  /// In fr, this message translates to:
  /// **'Salons Audio'**
  String get notifGroupAudioRooms;

  /// No description provided for @notifGroupPodcasts.
  ///
  /// In fr, this message translates to:
  /// **'Podcasts'**
  String get notifGroupPodcasts;

  /// No description provided for @notifGroupTransfers.
  ///
  /// In fr, this message translates to:
  /// **'Transferts'**
  String get notifGroupTransfers;

  /// No description provided for @notifGroupAll.
  ///
  /// In fr, this message translates to:
  /// **'Notifications'**
  String get notifGroupAll;

  /// No description provided for @notifNewMessagesCount.
  ///
  /// In fr, this message translates to:
  /// **'{count} nouveaux messages'**
  String notifNewMessagesCount(int count);

  /// No description provided for @notifMessagesFrom.
  ///
  /// In fr, this message translates to:
  /// **'{count} messages de {conversations} conversations'**
  String notifMessagesFrom(int count, int conversations);

  /// No description provided for @notifFriendRequestsCount.
  ///
  /// In fr, this message translates to:
  /// **'{count} demandes d\'ami'**
  String notifFriendRequestsCount(int count);

  /// No description provided for @notifNow.
  ///
  /// In fr, this message translates to:
  /// **'maintenant'**
  String get notifNow;

  /// No description provided for @imageSaved.
  ///
  /// In fr, this message translates to:
  /// **'Image enregistrée'**
  String get imageSaved;

  /// No description provided for @saveFailed.
  ///
  /// In fr, this message translates to:
  /// **'Échec de l\'enregistrement'**
  String get saveFailed;

  /// No description provided for @videoSaved.
  ///
  /// In fr, this message translates to:
  /// **'Vidéo enregistrée'**
  String get videoSaved;

  /// No description provided for @embassiesFoundCount.
  ///
  /// In fr, this message translates to:
  /// **'{count} ambassade(s) trouvée(s)'**
  String embassiesFoundCount(int count);

  /// No description provided for @embassiesHelperText.
  ///
  /// In fr, this message translates to:
  /// **'Les ambassades et consulats disponibles apparaîtront ici.'**
  String get embassiesHelperText;

  /// No description provided for @startNowLabel.
  ///
  /// In fr, this message translates to:
  /// **'Démarrer maintenant'**
  String get startNowLabel;

  /// No description provided for @recipientReceives.
  ///
  /// In fr, this message translates to:
  /// **'{name} reçoit'**
  String recipientReceives(String name);

  /// No description provided for @configCompleteLabel.
  ///
  /// In fr, this message translates to:
  /// **'configuration complète'**
  String get configCompleteLabel;

  /// No description provided for @familyEventLabel.
  ///
  /// In fr, this message translates to:
  /// **'Événement familial'**
  String get familyEventLabel;

  /// No description provided for @eventLabel.
  ///
  /// In fr, this message translates to:
  /// **'Événement'**
  String get eventLabel;

  /// No description provided for @sessionRecorded.
  ///
  /// In fr, this message translates to:
  /// **'Session enregistrée'**
  String get sessionRecorded;

  /// No description provided for @incompleteStripeConfig.
  ///
  /// In fr, this message translates to:
  /// **'Configuration incomplète. Complétez votre profil Stripe.'**
  String get incompleteStripeConfig;

  /// No description provided for @userNotLoggedIn.
  ///
  /// In fr, this message translates to:
  /// **'Utilisateur non connecté'**
  String get userNotLoggedIn;

  /// No description provided for @adminBanUserTitle.
  ///
  /// In fr, this message translates to:
  /// **'Bannir l\'utilisateur'**
  String get adminBanUserTitle;

  /// No description provided for @adminBanReasonLabel.
  ///
  /// In fr, this message translates to:
  /// **'Raison du bannissement:'**
  String get adminBanReasonLabel;

  /// No description provided for @adminUserBanned.
  ///
  /// In fr, this message translates to:
  /// **'Utilisateur banni'**
  String get adminUserBanned;

  /// No description provided for @adminUnbanUserTitle.
  ///
  /// In fr, this message translates to:
  /// **'Débannir l\'utilisateur'**
  String get adminUnbanUserTitle;

  /// No description provided for @adminUnbanConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Êtes-vous sûr de vouloir débannir cet utilisateur ?'**
  String get adminUnbanConfirm;

  /// No description provided for @adminUserUnbanned.
  ///
  /// In fr, this message translates to:
  /// **'Utilisateur débanni'**
  String get adminUserUnbanned;

  /// No description provided for @adminPromoteToAdminTitle.
  ///
  /// In fr, this message translates to:
  /// **'Promouvoir en admin'**
  String get adminPromoteToAdminTitle;

  /// No description provided for @adminPromoteConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Êtes-vous sûr de vouloir promouvoir cet utilisateur en administrateur ?'**
  String get adminPromoteConfirm;

  /// No description provided for @adminUserPromoted.
  ///
  /// In fr, this message translates to:
  /// **'Utilisateur promu admin'**
  String get adminUserPromoted;

  /// No description provided for @adminRevokeAdminTitle.
  ///
  /// In fr, this message translates to:
  /// **'Retirer les droits admin'**
  String get adminRevokeAdminTitle;

  /// No description provided for @adminRevokeAdminConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Êtes-vous sûr de vouloir retirer les droits administrateur ?'**
  String get adminRevokeAdminConfirm;

  /// No description provided for @adminAdminRightsRevoked.
  ///
  /// In fr, this message translates to:
  /// **'Droits admin retirés'**
  String get adminAdminRightsRevoked;

  /// No description provided for @adminCertifyUserTitle.
  ///
  /// In fr, this message translates to:
  /// **'Certifier l\'utilisateur'**
  String get adminCertifyUserTitle;

  /// No description provided for @adminCertifyConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Accorder la certification à {name} ?'**
  String adminCertifyConfirm(String name);

  /// No description provided for @adminUserCertified.
  ///
  /// In fr, this message translates to:
  /// **'Utilisateur certifié'**
  String get adminUserCertified;

  /// No description provided for @adminRevokeCertTitle.
  ///
  /// In fr, this message translates to:
  /// **'Révoquer la certification'**
  String get adminRevokeCertTitle;

  /// No description provided for @adminRevokeCertConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Retirer la certification de {name} ?'**
  String adminRevokeCertConfirm(String name);

  /// No description provided for @adminCertRevoked.
  ///
  /// In fr, this message translates to:
  /// **'Certification révoquée'**
  String get adminCertRevoked;

  /// No description provided for @adminForceDisconnectConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Cela déconnectera l\'utilisateur de tous ses appareils.'**
  String get adminForceDisconnectConfirm;

  /// No description provided for @adminUserDisconnected.
  ///
  /// In fr, this message translates to:
  /// **'Utilisateur déconnecté'**
  String get adminUserDisconnected;

  /// No description provided for @adminDisconnectedSuccess.
  ///
  /// In fr, this message translates to:
  /// **'{name} a été déconnecté.'**
  String adminDisconnectedSuccess(String name);

  /// No description provided for @adminBusinessVerified.
  ///
  /// In fr, this message translates to:
  /// **'Commerce vérifié'**
  String get adminBusinessVerified;

  /// No description provided for @adminVerificationRemoved.
  ///
  /// In fr, this message translates to:
  /// **'Vérification retirée'**
  String get adminVerificationRemoved;

  /// No description provided for @adminBusinessBoosted.
  ///
  /// In fr, this message translates to:
  /// **'Commerce boosté pour 30 jours'**
  String get adminBusinessBoosted;

  /// No description provided for @adminBoostRemoved.
  ///
  /// In fr, this message translates to:
  /// **'Boost retiré'**
  String get adminBoostRemoved;

  /// No description provided for @adminDeleteBusinessTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le commerce'**
  String get adminDeleteBusinessTitle;

  /// No description provided for @adminDeleteBusinessConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Êtes-vous sûr de vouloir supprimer ce commerce ? Cette action est irréversible.'**
  String get adminDeleteBusinessConfirm;

  /// No description provided for @adminBusinessDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Commerce supprimé'**
  String get adminBusinessDeleted;

  /// No description provided for @adminProductActivated.
  ///
  /// In fr, this message translates to:
  /// **'Produit activé'**
  String get adminProductActivated;

  /// No description provided for @adminProductDeactivated.
  ///
  /// In fr, this message translates to:
  /// **'Produit désactivé'**
  String get adminProductDeactivated;

  /// No description provided for @adminDeleteProductTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le produit'**
  String get adminDeleteProductTitle;

  /// No description provided for @adminDeleteProductConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Êtes-vous sûr de vouloir supprimer ce produit ?'**
  String get adminDeleteProductConfirm;

  /// No description provided for @adminProductDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Produit supprimé'**
  String get adminProductDeleted;

  /// No description provided for @adminResolveDisputeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Résoudre le litige'**
  String get adminResolveDisputeTitle;

  /// No description provided for @adminDisputeResolved.
  ///
  /// In fr, this message translates to:
  /// **'Litige résolu'**
  String get adminDisputeResolved;

  /// No description provided for @adminCancelEventConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Êtes-vous sûr de vouloir annuler cet événement ?'**
  String get adminCancelEventConfirm;

  /// No description provided for @adminDeleteEventConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Êtes-vous sûr de vouloir supprimer cet événement ? Cette action est irréversible.'**
  String get adminDeleteEventConfirm;

  /// No description provided for @adminDeleteGroupTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le groupe'**
  String get adminDeleteGroupTitle;

  /// No description provided for @adminDeleteGroupConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Êtes-vous sûr de vouloir supprimer ce groupe ? Cette action est irréversible.'**
  String get adminDeleteGroupConfirm;

  /// No description provided for @adminTransactionFailReasonLabel.
  ///
  /// In fr, this message translates to:
  /// **'Raison de l\'échec:'**
  String get adminTransactionFailReasonLabel;

  /// No description provided for @adminTransactionFailed.
  ///
  /// In fr, this message translates to:
  /// **'Transaction marquée comme échouée'**
  String get adminTransactionFailed;

  /// No description provided for @adminMarkCompleteTitle.
  ///
  /// In fr, this message translates to:
  /// **'Marquer comme complétée'**
  String get adminMarkCompleteTitle;

  /// No description provided for @adminMarkCompleteConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Êtes-vous sûr de vouloir marquer cette transaction comme complétée ?'**
  String get adminMarkCompleteConfirm;

  /// No description provided for @adminTransactionCompleted.
  ///
  /// In fr, this message translates to:
  /// **'Transaction complétée'**
  String get adminTransactionCompleted;

  /// No description provided for @adminRefundReasonLabel.
  ///
  /// In fr, this message translates to:
  /// **'Raison du remboursement:'**
  String get adminRefundReasonLabel;

  /// No description provided for @adminTransactionRefunded.
  ///
  /// In fr, this message translates to:
  /// **'Transaction remboursée'**
  String get adminTransactionRefunded;

  /// No description provided for @adminUnknownAdmin.
  ///
  /// In fr, this message translates to:
  /// **'Admin inconnu'**
  String get adminUnknownAdmin;

  /// No description provided for @adminUnknownDate.
  ///
  /// In fr, this message translates to:
  /// **'Date inconnue'**
  String get adminUnknownDate;

  /// No description provided for @adminEventByOrganizer.
  ///
  /// In fr, this message translates to:
  /// **'Événement par {id}'**
  String adminEventByOrganizer(String id);

  /// No description provided for @adminEventsTab.
  ///
  /// In fr, this message translates to:
  /// **'Événements ({count})'**
  String adminEventsTab(int count);

  /// No description provided for @adminAvailable.
  ///
  /// In fr, this message translates to:
  /// **'Disponible'**
  String get adminAvailable;

  /// No description provided for @adminUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Indisponible'**
  String get adminUnavailable;

  /// No description provided for @adminNoOrders.
  ///
  /// In fr, this message translates to:
  /// **'Aucune commande trouvée'**
  String get adminNoOrders;

  /// No description provided for @adminNoDisputes.
  ///
  /// In fr, this message translates to:
  /// **'Aucun litige en cours'**
  String get adminNoDisputes;

  /// No description provided for @adminDisputeId.
  ///
  /// In fr, this message translates to:
  /// **'Litige #{id}'**
  String adminDisputeId(String id);

  /// No description provided for @adminDisputeReasonLabel.
  ///
  /// In fr, this message translates to:
  /// **'Raison: {reason}'**
  String adminDisputeReasonLabel(String reason);

  /// No description provided for @adminReasonUnspecified.
  ///
  /// In fr, this message translates to:
  /// **'Non spécifiée'**
  String get adminReasonUnspecified;

  /// No description provided for @adminAmountHeader.
  ///
  /// In fr, this message translates to:
  /// **'Montant'**
  String get adminAmountHeader;

  /// No description provided for @adminAmountXofHeader.
  ///
  /// In fr, this message translates to:
  /// **'Montant en XOF'**
  String get adminAmountXofHeader;

  /// No description provided for @adminFailReasonHeader.
  ///
  /// In fr, this message translates to:
  /// **'Raison échec'**
  String get adminFailReasonHeader;

  /// No description provided for @adminTipAmountXof.
  ///
  /// In fr, this message translates to:
  /// **'Montant pourboires (XOF)'**
  String get adminTipAmountXof;

  /// No description provided for @adminRoomLimitsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Limites des salons'**
  String get adminRoomLimitsTitle;

  /// No description provided for @adminRoomLimitsSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Capacite et duree maximales'**
  String get adminRoomLimitsSubtitle;

  /// No description provided for @adminMaxDurationLabel.
  ///
  /// In fr, this message translates to:
  /// **'Duree max (minutes)'**
  String get adminMaxDurationLabel;

  /// No description provided for @adminPredefinedTipsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Montants de tips predefinis'**
  String get adminPredefinedTipsTitle;

  /// No description provided for @adminPredefinedTipsSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Separes par virgule (en unites, pas en centimes)'**
  String get adminPredefinedTipsSubtitle;

  /// No description provided for @wifiAndMobileData.
  ///
  /// In fr, this message translates to:
  /// **'WiFi et données mobiles'**
  String get wifiAndMobileData;

  /// No description provided for @wifiOnly.
  ///
  /// In fr, this message translates to:
  /// **'WiFi uniquement'**
  String get wifiOnly;

  /// No description provided for @autoDownloads.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargements automatiques'**
  String get autoDownloads;

  /// No description provided for @passphraseMinLength.
  ///
  /// In fr, this message translates to:
  /// **'La passphrase doit contenir au moins 8 caractères'**
  String get passphraseMinLength;

  /// No description provided for @backupCreatedSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarde créée avec succès'**
  String get backupCreatedSuccess;

  /// No description provided for @backupCreateError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la création de la sauvegarde: {error}'**
  String backupCreateError(String error);

  /// No description provided for @keysRestoredSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Clés restaurées avec succès'**
  String get keysRestoredSuccess;

  /// No description provided for @backupCreatedOn.
  ///
  /// In fr, this message translates to:
  /// **'Créée le: {date}'**
  String backupCreatedOn(String date);

  /// No description provided for @passphraseRequiredNote.
  ///
  /// In fr, this message translates to:
  /// **'Sans elle, vos clés ne pourront pas être restaurées.'**
  String get passphraseRequiredNote;

  /// No description provided for @minTipAmountError.
  ///
  /// In fr, this message translates to:
  /// **'Montant minimum: {amount} {currency}'**
  String minTipAmountError(int amount, String currency);

  /// No description provided for @maxTipAmountError.
  ///
  /// In fr, this message translates to:
  /// **'Montant maximum: {amount} {currency}'**
  String maxTipAmountError(int amount, String currency);

  /// No description provided for @ghostSuperAdminBadge.
  ///
  /// In fr, this message translates to:
  /// **'GHOST · SuperAdmin'**
  String get ghostSuperAdminBadge;

  /// No description provided for @ghostInvisibleNotice.
  ///
  /// In fr, this message translates to:
  /// **'Vous êtes invisible. Actions loggées.'**
  String get ghostInvisibleNotice;

  /// No description provided for @ghostActionsTitle.
  ///
  /// In fr, this message translates to:
  /// **'ACTIONS GHOST'**
  String get ghostActionsTitle;

  /// No description provided for @ghostMuteSilent.
  ///
  /// In fr, this message translates to:
  /// **'Muet silencieux'**
  String get ghostMuteSilent;

  /// No description provided for @ghostExclude.
  ///
  /// In fr, this message translates to:
  /// **'Exclure'**
  String get ghostExclude;

  /// No description provided for @ghostBlockGlobal.
  ///
  /// In fr, this message translates to:
  /// **'Bloquer global'**
  String get ghostBlockGlobal;

  /// No description provided for @payoutHistoryTitle.
  ///
  /// In fr, this message translates to:
  /// **'Historique des retraits'**
  String get payoutHistoryTitle;

  /// No description provided for @noWithdrawalsYet.
  ///
  /// In fr, this message translates to:
  /// **'Aucun retrait effectué'**
  String get noWithdrawalsYet;

  /// No description provided for @availableBalance.
  ///
  /// In fr, this message translates to:
  /// **'Solde disponible'**
  String get availableBalance;

  /// No description provided for @processingEllipsis.
  ///
  /// In fr, this message translates to:
  /// **'Traitement…'**
  String get processingEllipsis;

  /// No description provided for @withdrawEarnings.
  ///
  /// In fr, this message translates to:
  /// **'Retirer les gains'**
  String get withdrawEarnings;

  /// No description provided for @stripeConnectRequired.
  ///
  /// In fr, this message translates to:
  /// **'Configurez Stripe Connect pour activer les retraits.'**
  String get stripeConnectRequired;

  /// No description provided for @earningsBreakdown.
  ///
  /// In fr, this message translates to:
  /// **'Répartition des gains'**
  String get earningsBreakdown;

  /// No description provided for @stripeConnectAccount.
  ///
  /// In fr, this message translates to:
  /// **'Compte Stripe Connect'**
  String get stripeConnectAccount;

  /// No description provided for @stripeAccountActive.
  ///
  /// In fr, this message translates to:
  /// **'Votre compte est actif. Les retraits sont disponibles.'**
  String get stripeAccountActive;

  /// No description provided for @createStripePrompt.
  ///
  /// In fr, this message translates to:
  /// **'Créez un compte Stripe Connect pour recevoir vos paiements.'**
  String get createStripePrompt;

  /// No description provided for @continueSetupButton.
  ///
  /// In fr, this message translates to:
  /// **'Continuer la configuration'**
  String get continueSetupButton;

  /// No description provided for @createStripeButton.
  ///
  /// In fr, this message translates to:
  /// **'Créer un compte Stripe'**
  String get createStripeButton;

  /// No description provided for @podcastCoverLabel.
  ///
  /// In fr, this message translates to:
  /// **'Couverture'**
  String get podcastCoverLabel;

  /// No description provided for @podcastVisibilityLabel.
  ///
  /// In fr, this message translates to:
  /// **'Visibilité'**
  String get podcastVisibilityLabel;

  /// No description provided for @podcastFollowersVisibility.
  ///
  /// In fr, this message translates to:
  /// **'Abonnés'**
  String get podcastFollowersVisibility;

  /// No description provided for @podcastPrivateVisibility.
  ///
  /// In fr, this message translates to:
  /// **'Privé'**
  String get podcastPrivateVisibility;

  /// No description provided for @podcastVideoEpisodeLabel.
  ///
  /// In fr, this message translates to:
  /// **'Épisode vidéo'**
  String get podcastVideoEpisodeLabel;

  /// No description provided for @podcastVideoProcessing.
  ///
  /// In fr, this message translates to:
  /// **'Traitement vidéo en cours…'**
  String get podcastVideoProcessing;

  /// No description provided for @podcastEpisodeTitleLabel.
  ///
  /// In fr, this message translates to:
  /// **'Titre de l\'épisode'**
  String get podcastEpisodeTitleLabel;

  /// No description provided for @podcastAiChaptersLabel.
  ///
  /// In fr, this message translates to:
  /// **'Chapitres détectés par IA'**
  String get podcastAiChaptersLabel;

  /// No description provided for @scheduleRoomCaveat.
  ///
  /// In fr, this message translates to:
  /// **'Affiché à chaque membre dans son fuseau local lors du rappel.'**
  String get scheduleRoomCaveat;

  /// No description provided for @filesLabel.
  ///
  /// In fr, this message translates to:
  /// **'Fichiers'**
  String get filesLabel;

  /// No description provided for @embassyFormIntro.
  ///
  /// In fr, this message translates to:
  /// **'Remplissez ce formulaire pour créer une nouvelle ambassade. La demande sera vérifiée avant publication.'**
  String get embassyFormIntro;

  /// No description provided for @embassyBasicInfoSection.
  ///
  /// In fr, this message translates to:
  /// **'Informations de base'**
  String get embassyBasicInfoSection;

  /// No description provided for @embassySelectType.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionnez le type d\'établissement'**
  String get embassySelectType;

  /// No description provided for @embassyTypeEmbassy.
  ///
  /// In fr, this message translates to:
  /// **'Ambassade'**
  String get embassyTypeEmbassy;

  /// No description provided for @embassyTypeConsulate.
  ///
  /// In fr, this message translates to:
  /// **'Consulat'**
  String get embassyTypeConsulate;

  /// No description provided for @embassyTypeMission.
  ///
  /// In fr, this message translates to:
  /// **'Mission diplomatique'**
  String get embassyTypeMission;

  /// No description provided for @embassyTypeDelegation.
  ///
  /// In fr, this message translates to:
  /// **'Délégation'**
  String get embassyTypeDelegation;

  /// No description provided for @embassyNameField.
  ///
  /// In fr, this message translates to:
  /// **'Nom *'**
  String get embassyNameField;

  /// No description provided for @embassyCountryField.
  ///
  /// In fr, this message translates to:
  /// **'Pays d\'implantation *'**
  String get embassyCountryField;

  /// No description provided for @embassyCityField.
  ///
  /// In fr, this message translates to:
  /// **'Ville *'**
  String get embassyCityField;

  /// No description provided for @embassyAddressField.
  ///
  /// In fr, this message translates to:
  /// **'Adresse complète *'**
  String get embassyAddressField;

  /// No description provided for @embassyNameRequired.
  ///
  /// In fr, this message translates to:
  /// **'Le nom est obligatoire'**
  String get embassyNameRequired;

  /// No description provided for @embassyCountryRequired.
  ///
  /// In fr, this message translates to:
  /// **'Le pays est obligatoire'**
  String get embassyCountryRequired;

  /// No description provided for @embassyCityRequired.
  ///
  /// In fr, this message translates to:
  /// **'La ville est obligatoire'**
  String get embassyCityRequired;

  /// No description provided for @embassyAddressRequired.
  ///
  /// In fr, this message translates to:
  /// **'L\'adresse est obligatoire'**
  String get embassyAddressRequired;

  /// No description provided for @embassyLocationSection.
  ///
  /// In fr, this message translates to:
  /// **'Localisation GPS (optionnel)'**
  String get embassyLocationSection;

  /// No description provided for @embassyServicesSection.
  ///
  /// In fr, this message translates to:
  /// **'Services proposés'**
  String get embassyServicesSection;

  /// No description provided for @embassyJurisdictionSection.
  ///
  /// In fr, this message translates to:
  /// **'Pays sous juridiction'**
  String get embassyJurisdictionSection;

  /// No description provided for @embassyJurisdictionDesc.
  ///
  /// In fr, this message translates to:
  /// **'Indiquez les pays dont les ressortissants peuvent contacter cette ambassade.'**
  String get embassyJurisdictionDesc;

  /// No description provided for @embassyAddCountry.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un pays'**
  String get embassyAddCountry;

  /// No description provided for @embassyHoursSection.
  ///
  /// In fr, this message translates to:
  /// **'Horaires d\'ouverture'**
  String get embassyHoursSection;

  /// No description provided for @embassyHoursHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex: 09:00 - 17:00 ou Fermé'**
  String get embassyHoursHint;

  /// No description provided for @embassyCreateButton.
  ///
  /// In fr, this message translates to:
  /// **'Créer l\'ambassade'**
  String get embassyCreateButton;

  /// No description provided for @emailInvalidError.
  ///
  /// In fr, this message translates to:
  /// **'Email invalide'**
  String get emailInvalidError;

  /// No description provided for @adminDemoted.
  ///
  /// In fr, this message translates to:
  /// **'Rétrogradé'**
  String get adminDemoted;

  /// No description provided for @adminPrivacyChanged.
  ///
  /// In fr, this message translates to:
  /// **'Confidentialité modifiée'**
  String get adminPrivacyChanged;

  /// No description provided for @adminReportResolved.
  ///
  /// In fr, this message translates to:
  /// **'Signalement résolu'**
  String get adminReportResolved;

  /// No description provided for @adminAvailabilityChanged.
  ///
  /// In fr, this message translates to:
  /// **'Disponibilité modifiée'**
  String get adminAvailabilityChanged;

  /// No description provided for @adminConfigUpdated.
  ///
  /// In fr, this message translates to:
  /// **'Configuration mise à jour'**
  String get adminConfigUpdated;

  /// No description provided for @adminFeatureChanged.
  ///
  /// In fr, this message translates to:
  /// **'Feature modifiée'**
  String get adminFeatureChanged;

  /// No description provided for @adminNotificationSent.
  ///
  /// In fr, this message translates to:
  /// **'Notification envoyée'**
  String get adminNotificationSent;

  /// No description provided for @adminForceLogoutAction.
  ///
  /// In fr, this message translates to:
  /// **'Déconnexion forcée'**
  String get adminForceLogoutAction;

  /// No description provided for @adminAuditEmptyState.
  ///
  /// In fr, this message translates to:
  /// **'Les actions des administrateurs apparaîtront ici'**
  String get adminAuditEmptyState;

  /// No description provided for @adminDetailsLabel.
  ///
  /// In fr, this message translates to:
  /// **'Détails:'**
  String get adminDetailsLabel;

  /// No description provided for @adminTransferMonitoringTitle.
  ///
  /// In fr, this message translates to:
  /// **'Monitoring Transferts'**
  String get adminTransferMonitoringTitle;

  /// No description provided for @adminTransferMonitoringSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Suivi des transactions et volumes en temps réel'**
  String get adminTransferMonitoringSubtitle;

  /// No description provided for @adminTransferVolume.
  ///
  /// In fr, this message translates to:
  /// **'Volume des Transferts'**
  String get adminTransferVolume;

  /// No description provided for @adminByCurrency.
  ///
  /// In fr, this message translates to:
  /// **'Détails par Devise'**
  String get adminByCurrency;

  /// No description provided for @adminTotalVolumeUSD.
  ///
  /// In fr, this message translates to:
  /// **'Volume Total (USD)'**
  String get adminTotalVolumeUSD;

  /// No description provided for @adminFeesCollectedUSD.
  ///
  /// In fr, this message translates to:
  /// **'Frais Collectés (USD)'**
  String get adminFeesCollectedUSD;

  /// No description provided for @adminFailedTab.
  ///
  /// In fr, this message translates to:
  /// **'Échouées ({count})'**
  String adminFailedTab(int count);

  /// No description provided for @adminCompletedTab.
  ///
  /// In fr, this message translates to:
  /// **'Complétées ({count})'**
  String adminCompletedTab(int count);

  /// No description provided for @adminProcessedTab.
  ///
  /// In fr, this message translates to:
  /// **'Traités ({count})'**
  String adminProcessedTab(int count);

  /// No description provided for @adminAdminsTab.
  ///
  /// In fr, this message translates to:
  /// **'Admins ({count})'**
  String adminAdminsTab(int count);

  /// No description provided for @adminBannedTab.
  ///
  /// In fr, this message translates to:
  /// **'Bannis ({count})'**
  String adminBannedTab(int count);

  /// No description provided for @adminActiveTab.
  ///
  /// In fr, this message translates to:
  /// **'Actives ({count})'**
  String adminActiveTab(int count);

  /// No description provided for @adminSuspendedTab.
  ///
  /// In fr, this message translates to:
  /// **'Suspendues ({count})'**
  String adminSuspendedTab(int count);

  /// No description provided for @adminMarkFailedAction.
  ///
  /// In fr, this message translates to:
  /// **'Échouer'**
  String get adminMarkFailedAction;

  /// No description provided for @adminMarkAsFailedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Marquer comme échouée'**
  String get adminMarkAsFailedTitle;

  /// No description provided for @adminTransactionDebiting.
  ///
  /// In fr, this message translates to:
  /// **'Débit en cours'**
  String get adminTransactionDebiting;

  /// No description provided for @adminTransactionInProgress.
  ///
  /// In fr, this message translates to:
  /// **'En cours'**
  String get adminTransactionInProgress;

  /// No description provided for @adminTransactionSending.
  ///
  /// In fr, this message translates to:
  /// **'Envoi en cours'**
  String get adminTransactionSending;

  /// No description provided for @adminTransactionCompletedLabel.
  ///
  /// In fr, this message translates to:
  /// **'Complétée'**
  String get adminTransactionCompletedLabel;

  /// No description provided for @adminTransactionRefunding.
  ///
  /// In fr, this message translates to:
  /// **'Remboursement'**
  String get adminTransactionRefunding;

  /// No description provided for @adminActiveLabel.
  ///
  /// In fr, this message translates to:
  /// **'Actives'**
  String get adminActiveLabel;

  /// No description provided for @adminSuspendedLabel.
  ///
  /// In fr, this message translates to:
  /// **'Suspendues'**
  String get adminSuspendedLabel;

  /// No description provided for @adminSuspendedStatus.
  ///
  /// In fr, this message translates to:
  /// **'Suspendue'**
  String get adminSuspendedStatus;

  /// No description provided for @adminVerifiedStatus.
  ///
  /// In fr, this message translates to:
  /// **'Vérifiée'**
  String get adminVerifiedStatus;

  /// No description provided for @adminNoEmbassyPending.
  ///
  /// In fr, this message translates to:
  /// **'Aucune ambassade en attente de vérification'**
  String get adminNoEmbassyPending;

  /// No description provided for @adminNoEmbassyActive.
  ///
  /// In fr, this message translates to:
  /// **'Aucune ambassade active'**
  String get adminNoEmbassyActive;

  /// No description provided for @adminNoEmbassySuspended.
  ///
  /// In fr, this message translates to:
  /// **'Aucune ambassade suspendue'**
  String get adminNoEmbassySuspended;

  /// No description provided for @adminNoEmbassy.
  ///
  /// In fr, this message translates to:
  /// **'Aucune ambassade'**
  String get adminNoEmbassy;

  /// No description provided for @adminLoadingEmbassies.
  ///
  /// In fr, this message translates to:
  /// **'Chargement des ambassades...'**
  String get adminLoadingEmbassies;

  /// No description provided for @adminLoadError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur de chargement'**
  String get adminLoadError;

  /// No description provided for @adminUsersManagementTitle.
  ///
  /// In fr, this message translates to:
  /// **'Gestion des Utilisateurs'**
  String get adminUsersManagementTitle;

  /// No description provided for @adminUsersManagementSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Gérez les comptes, permissions et bannissements'**
  String get adminUsersManagementSubtitle;

  /// No description provided for @adminNoName.
  ///
  /// In fr, this message translates to:
  /// **'Sans nom'**
  String get adminNoName;

  /// No description provided for @adminNoEmail.
  ///
  /// In fr, this message translates to:
  /// **'Pas d\'email'**
  String get adminNoEmail;

  /// No description provided for @adminLastLogin.
  ///
  /// In fr, this message translates to:
  /// **'Dernière connexion : {date}'**
  String adminLastLogin(String date);

  /// No description provided for @adminBanReason.
  ///
  /// In fr, this message translates to:
  /// **'Raison : {reason}'**
  String adminBanReason(String reason);

  /// No description provided for @adminCertifiedBadge.
  ///
  /// In fr, this message translates to:
  /// **'CERTIFIÉ'**
  String get adminCertifiedBadge;

  /// No description provided for @adminAdminBadge.
  ///
  /// In fr, this message translates to:
  /// **'ADMIN'**
  String get adminAdminBadge;

  /// No description provided for @adminBannedBadge.
  ///
  /// In fr, this message translates to:
  /// **'BANNI'**
  String get adminBannedBadge;

  /// No description provided for @adminFeaturesToggleSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Activer/désactiver les options'**
  String get adminFeaturesToggleSubtitle;

  /// No description provided for @adminActiveRoomsFeature.
  ///
  /// In fr, this message translates to:
  /// **'Salons audio actifs'**
  String get adminActiveRoomsFeature;

  /// No description provided for @adminPaidRoomsFeature.
  ///
  /// In fr, this message translates to:
  /// **'Salons payants'**
  String get adminPaidRoomsFeature;

  /// No description provided for @adminTipsFeature.
  ///
  /// In fr, this message translates to:
  /// **'Pourboires'**
  String get adminTipsFeature;

  /// No description provided for @adminPaidReplaysFeature.
  ///
  /// In fr, this message translates to:
  /// **'Replays payants'**
  String get adminPaidReplaysFeature;

  /// No description provided for @adminCreatorSubscriptionsFeature.
  ///
  /// In fr, this message translates to:
  /// **'Abonnements créateurs'**
  String get adminCreatorSubscriptionsFeature;

  /// No description provided for @adminRecordingFeature.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrement'**
  String get adminRecordingFeature;

  /// No description provided for @adminCommissionsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Commissions'**
  String get adminCommissionsTitle;

  /// No description provided for @adminCommissionsSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Pourcentage prélevé par la plateforme'**
  String get adminCommissionsSubtitle;

  /// No description provided for @adminTicketsLabel.
  ///
  /// In fr, this message translates to:
  /// **'Tickets'**
  String get adminTicketsLabel;

  /// No description provided for @adminTipsLabel.
  ///
  /// In fr, this message translates to:
  /// **'Pourboires'**
  String get adminTipsLabel;

  /// No description provided for @adminReplaysLabel.
  ///
  /// In fr, this message translates to:
  /// **'Replays'**
  String get adminReplaysLabel;

  /// No description provided for @adminSubscriptionsLabel.
  ///
  /// In fr, this message translates to:
  /// **'Abonnements'**
  String get adminSubscriptionsLabel;

  /// No description provided for @adminPriceLimitsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Limites de prix'**
  String get adminPriceLimitsTitle;

  /// No description provided for @adminPriceLimitsSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Min/Max pour les transactions'**
  String get adminPriceLimitsSubtitle;

  /// No description provided for @adminMinLabel.
  ///
  /// In fr, this message translates to:
  /// **'Min'**
  String get adminMinLabel;

  /// No description provided for @adminMaxLabel.
  ///
  /// In fr, this message translates to:
  /// **'Max'**
  String get adminMaxLabel;

  /// No description provided for @adminMaxSpeakersLabel.
  ///
  /// In fr, this message translates to:
  /// **'Max speakers'**
  String get adminMaxSpeakersLabel;

  /// No description provided for @adminMaxListenersLabel.
  ///
  /// In fr, this message translates to:
  /// **'Max listeners'**
  String get adminMaxListenersLabel;

  /// No description provided for @stickerLoadError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur de chargement des stickers'**
  String get stickerLoadError;

  /// No description provided for @stickerNoRecent.
  ///
  /// In fr, this message translates to:
  /// **'Aucun sticker récent'**
  String get stickerNoRecent;

  /// No description provided for @stickerRecentLoadError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur de chargement des stickers récents'**
  String get stickerRecentLoadError;

  /// No description provided for @stickerNoFavorites.
  ///
  /// In fr, this message translates to:
  /// **'Aucun sticker favori'**
  String get stickerNoFavorites;

  /// No description provided for @stickerAddFavoritesHint.
  ///
  /// In fr, this message translates to:
  /// **'Appui long pour ajouter aux favoris'**
  String get stickerAddFavoritesHint;

  /// No description provided for @stickerFavoritesLoadError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur de chargement des favoris'**
  String get stickerFavoritesLoadError;

  /// No description provided for @stickerPackEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun sticker dans ce pack'**
  String get stickerPackEmpty;

  /// No description provided for @priceConvertedFrom.
  ///
  /// In fr, this message translates to:
  /// **'Converti depuis {currency}'**
  String priceConvertedFrom(String currency);

  /// No description provided for @onboardingWelcomeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Bienvenue sur\nDiaspo Niger'**
  String get onboardingWelcomeTitle;

  /// No description provided for @onboardingWelcomeDesc.
  ///
  /// In fr, this message translates to:
  /// **'Connectez-vous avec la diaspora nigérienne partout dans le monde. Retrouvez vos compatriotes et partagez ensemble.'**
  String get onboardingWelcomeDesc;

  /// No description provided for @onboardingDiscoverTitle.
  ///
  /// In fr, this message translates to:
  /// **'Découvrez les membres'**
  String get onboardingDiscoverTitle;

  /// No description provided for @onboardingDiscoverDesc.
  ///
  /// In fr, this message translates to:
  /// **'Trouvez des Nigériens près de chez vous grâce à notre carte interactive. Voyez qui habite dans votre région.'**
  String get onboardingDiscoverDesc;

  /// No description provided for @onboardingGroupsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Rejoignez des groupes'**
  String get onboardingGroupsTitle;

  /// No description provided for @onboardingGroupsDesc.
  ///
  /// In fr, this message translates to:
  /// **'Participez à des communautés thématiques : professionnels, étudiants, entrepreneurs... Échangez et entraidez-vous.'**
  String get onboardingGroupsDesc;

  /// No description provided for @onboardingEventsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Participez aux événements'**
  String get onboardingEventsTitle;

  /// No description provided for @onboardingEventsDesc.
  ///
  /// In fr, this message translates to:
  /// **'Organisez ou participez à des rencontres, conférences et activités culturelles de la diaspora.'**
  String get onboardingEventsDesc;

  /// No description provided for @onboardingConnectedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Restez connectés'**
  String get onboardingConnectedTitle;

  /// No description provided for @onboardingConnectedDesc.
  ///
  /// In fr, this message translates to:
  /// **'Discutez en privé avec les membres de la communauté. Créez des liens durables avec la diaspora.'**
  String get onboardingConnectedDesc;

  /// No description provided for @adminAudioLiveSection.
  ///
  /// In fr, this message translates to:
  /// **'Salons Audio Live'**
  String get adminAudioLiveSection;

  /// No description provided for @adminAudioLiveSectionDesc.
  ///
  /// In fr, this message translates to:
  /// **'Surveillez et modérez les salons audio en direct'**
  String get adminAudioLiveSectionDesc;

  /// No description provided for @adminMustBeConnected.
  ///
  /// In fr, this message translates to:
  /// **'Vous devez être connecté pour sauvegarder'**
  String get adminMustBeConnected;

  /// No description provided for @adminMaintenanceMode.
  ///
  /// In fr, this message translates to:
  /// **'Mode Maintenance'**
  String get adminMaintenanceMode;

  /// No description provided for @adminMaintenanceActive.
  ///
  /// In fr, this message translates to:
  /// **'Application en maintenance'**
  String get adminMaintenanceActive;

  /// No description provided for @adminMaintenanceInactive.
  ///
  /// In fr, this message translates to:
  /// **'Application active'**
  String get adminMaintenanceInactive;

  /// No description provided for @adminMaintenanceWarning.
  ///
  /// In fr, this message translates to:
  /// **'L\'application sera inaccessible pour tous les utilisateurs non-admin !'**
  String get adminMaintenanceWarning;

  /// No description provided for @adminFeaturesSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Activez ou désactivez les modules'**
  String get adminFeaturesSubtitle;

  /// No description provided for @featureMoneyTransfer.
  ///
  /// In fr, this message translates to:
  /// **'Transfert d\'argent'**
  String get featureMoneyTransfer;

  /// No description provided for @featureMoneyTransferDesc.
  ///
  /// In fr, this message translates to:
  /// **'Envoi d\'argent vers le Niger'**
  String get featureMoneyTransferDesc;

  /// No description provided for @featureMarketplaceDesc.
  ///
  /// In fr, this message translates to:
  /// **'Achat et vente de produits'**
  String get featureMarketplaceDesc;

  /// No description provided for @featureBusinessDirectory.
  ///
  /// In fr, this message translates to:
  /// **'Annuaire Entreprises'**
  String get featureBusinessDirectory;

  /// No description provided for @featureBusinessDirectoryDesc.
  ///
  /// In fr, this message translates to:
  /// **'Répertoire des entreprises nigériennes'**
  String get featureBusinessDirectoryDesc;

  /// No description provided for @featureEventsDesc.
  ///
  /// In fr, this message translates to:
  /// **'Création et participation aux événements'**
  String get featureEventsDesc;

  /// No description provided for @featureGroupsDesc.
  ///
  /// In fr, this message translates to:
  /// **'Création et gestion des groupes'**
  String get featureGroupsDesc;

  /// No description provided for @featureEmbassiesDesc.
  ///
  /// In fr, this message translates to:
  /// **'Services consulaires et ambassades'**
  String get featureEmbassiesDesc;

  /// No description provided for @featureAudioRoomsDesc.
  ///
  /// In fr, this message translates to:
  /// **'Salons vocaux en direct et replays'**
  String get featureAudioRoomsDesc;

  /// No description provided for @featurePodcasts.
  ///
  /// In fr, this message translates to:
  /// **'Podcasts'**
  String get featurePodcasts;

  /// No description provided for @featurePodcastsDesc.
  ///
  /// In fr, this message translates to:
  /// **'Écoute et création de podcasts'**
  String get featurePodcastsDesc;

  /// No description provided for @settingsImagesLabel.
  ///
  /// In fr, this message translates to:
  /// **'Images'**
  String get settingsImagesLabel;

  /// No description provided for @manualDownload.
  ///
  /// In fr, this message translates to:
  /// **'Manuel (demander)'**
  String get manualDownload;

  /// No description provided for @reportMessageTitle.
  ///
  /// In fr, this message translates to:
  /// **'Signaler le message'**
  String get reportMessageTitle;

  /// No description provided for @reportMessageSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Signaler ce message aux administrateurs'**
  String get reportMessageSubtitle;

  /// No description provided for @reportMotifLabel.
  ///
  /// In fr, this message translates to:
  /// **'Motif du signalement :'**
  String get reportMotifLabel;

  /// No description provided for @violenceThreats.
  ///
  /// In fr, this message translates to:
  /// **'Violence ou menaces'**
  String get violenceThreats;

  /// No description provided for @disable.
  ///
  /// In fr, this message translates to:
  /// **'Désactiver'**
  String get disable;

  /// No description provided for @noProductFound.
  ///
  /// In fr, this message translates to:
  /// **'Aucun produit trouvé'**
  String get noProductFound;

  /// No description provided for @comingSoonShort.
  ///
  /// In fr, this message translates to:
  /// **'Bientôt disponible'**
  String get comingSoonShort;

  /// No description provided for @loadingReports.
  ///
  /// In fr, this message translates to:
  /// **'Chargement des signalements...'**
  String get loadingReports;

  /// No description provided for @noReports.
  ///
  /// In fr, this message translates to:
  /// **'Aucun signalement'**
  String get noReports;

  /// No description provided for @noSearchResultsForFilter.
  ///
  /// In fr, this message translates to:
  /// **'Aucun résultat pour cette recherche'**
  String get noSearchResultsForFilter;

  /// No description provided for @notVerifiedLabel.
  ///
  /// In fr, this message translates to:
  /// **'Non vérifié'**
  String get notVerifiedLabel;

  /// No description provided for @deleteContentConfirmTitle.
  ///
  /// In fr, this message translates to:
  /// **'Êtes-vous sûr de vouloir supprimer ce contenu ?'**
  String get deleteContentConfirmTitle;

  /// No description provided for @deleteContentIrreversibleDesc.
  ///
  /// In fr, this message translates to:
  /// **'Cette action est irréversible et supprimera définitivement le {type}.'**
  String deleteContentIrreversibleDesc(String type);

  /// No description provided for @reportTypeConversation.
  ///
  /// In fr, this message translates to:
  /// **'Conversation'**
  String get reportTypeConversation;

  /// No description provided for @reportTypeEvent.
  ///
  /// In fr, this message translates to:
  /// **'Événement'**
  String get reportTypeEvent;

  /// No description provided for @reportTypeGroup.
  ///
  /// In fr, this message translates to:
  /// **'Groupe'**
  String get reportTypeGroup;

  /// No description provided for @reportTypeBusiness.
  ///
  /// In fr, this message translates to:
  /// **'Commerce'**
  String get reportTypeBusiness;

  /// No description provided for @reportTypeProduct.
  ///
  /// In fr, this message translates to:
  /// **'Produit'**
  String get reportTypeProduct;

  /// No description provided for @categoryFood.
  ///
  /// In fr, this message translates to:
  /// **'Alimentation'**
  String get categoryFood;

  /// No description provided for @categoryCrafts.
  ///
  /// In fr, this message translates to:
  /// **'Artisanat'**
  String get categoryCrafts;

  /// No description provided for @categoryElectronics.
  ///
  /// In fr, this message translates to:
  /// **'Électronique'**
  String get categoryElectronics;

  /// No description provided for @categoryClothing.
  ///
  /// In fr, this message translates to:
  /// **'Vêtements'**
  String get categoryClothing;

  /// No description provided for @categoryRealEstate.
  ///
  /// In fr, this message translates to:
  /// **'Immobilier'**
  String get categoryRealEstate;

  /// No description provided for @categoryOther.
  ///
  /// In fr, this message translates to:
  /// **'Standard (autres)'**
  String get categoryOther;

  /// No description provided for @callDeleteError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la suppression'**
  String get callDeleteError;

  /// No description provided for @typingOneName.
  ///
  /// In fr, this message translates to:
  /// **'{name} écrit...'**
  String typingOneName(String name);

  /// No description provided for @typingTwoNames.
  ///
  /// In fr, this message translates to:
  /// **'{name1} et {name2} écrivent...'**
  String typingTwoNames(String name1, String name2);

  /// No description provided for @typingManyNames.
  ///
  /// In fr, this message translates to:
  /// **'{name} et {count} autres écrivent...'**
  String typingManyNames(String name, int count);

  /// No description provided for @typingSomeone.
  ///
  /// In fr, this message translates to:
  /// **'Quelqu\'un écrit...'**
  String get typingSomeone;

  /// No description provided for @typingManyPeople.
  ///
  /// In fr, this message translates to:
  /// **'{count} personnes écrivent...'**
  String typingManyPeople(int count);

  /// No description provided for @messageTypePhoto.
  ///
  /// In fr, this message translates to:
  /// **'📷 Photo'**
  String get messageTypePhoto;

  /// No description provided for @messageTypeVideo.
  ///
  /// In fr, this message translates to:
  /// **'🎥 Vidéo'**
  String get messageTypeVideo;

  /// No description provided for @messageTypeFile.
  ///
  /// In fr, this message translates to:
  /// **'📄 Document'**
  String get messageTypeFile;

  /// No description provided for @messageTypeCall.
  ///
  /// In fr, this message translates to:
  /// **'📞 Appel'**
  String get messageTypeCall;

  /// No description provided for @messageTypeLocation.
  ///
  /// In fr, this message translates to:
  /// **'📍 Position'**
  String get messageTypeLocation;

  /// No description provided for @messageTypeSticker.
  ///
  /// In fr, this message translates to:
  /// **'🎭 Sticker'**
  String get messageTypeSticker;

  /// No description provided for @reportContentTitle.
  ///
  /// In fr, this message translates to:
  /// **'Signaler {target}'**
  String reportContentTitle(String target);

  /// No description provided for @reportTargetUser.
  ///
  /// In fr, this message translates to:
  /// **'cet utilisateur'**
  String get reportTargetUser;

  /// No description provided for @reportTargetMessage.
  ///
  /// In fr, this message translates to:
  /// **'ce message'**
  String get reportTargetMessage;

  /// No description provided for @reportTargetConversation.
  ///
  /// In fr, this message translates to:
  /// **'cette conversation'**
  String get reportTargetConversation;

  /// No description provided for @reportTargetGroup.
  ///
  /// In fr, this message translates to:
  /// **'ce groupe'**
  String get reportTargetGroup;

  /// No description provided for @reportTargetEvent.
  ///
  /// In fr, this message translates to:
  /// **'cet événement'**
  String get reportTargetEvent;

  /// No description provided for @reportTargetBusiness.
  ///
  /// In fr, this message translates to:
  /// **'ce commerce'**
  String get reportTargetBusiness;

  /// No description provided for @reportTargetProduct.
  ///
  /// In fr, this message translates to:
  /// **'ce produit'**
  String get reportTargetProduct;

  /// No description provided for @reportSentThanks.
  ///
  /// In fr, this message translates to:
  /// **'Signalement envoyé. Merci pour votre aide.'**
  String get reportSentThanks;

  /// No description provided for @reportSendFailed.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de l\'envoi du signalement'**
  String get reportSendFailed;

  /// No description provided for @reportAlreadyReportedInfo.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez déjà signalé ce contenu. Notre équipe examine votre signalement.'**
  String get reportAlreadyReportedInfo;

  /// No description provided for @reportWhyQuestion.
  ///
  /// In fr, this message translates to:
  /// **'Pourquoi signalez-vous ce contenu ?'**
  String get reportWhyQuestion;

  /// No description provided for @reportExtraDetails.
  ///
  /// In fr, this message translates to:
  /// **'Détails supplémentaires (optionnel)'**
  String get reportExtraDetails;

  /// No description provided for @reportedContentLabel.
  ///
  /// In fr, this message translates to:
  /// **'Contenu signalé'**
  String get reportedContentLabel;

  /// No description provided for @reportInfoText.
  ///
  /// In fr, this message translates to:
  /// **'Les signalements sont examinés par notre équipe de modération. Les faux signalements répétés peuvent entraîner des sanctions.'**
  String get reportInfoText;

  /// No description provided for @reportReasonSpam.
  ///
  /// In fr, this message translates to:
  /// **'Spam'**
  String get reportReasonSpam;

  /// No description provided for @reportReasonHarassment.
  ///
  /// In fr, this message translates to:
  /// **'Harcèlement'**
  String get reportReasonHarassment;

  /// No description provided for @reportReasonInappropriate.
  ///
  /// In fr, this message translates to:
  /// **'Contenu inapproprié'**
  String get reportReasonInappropriate;

  /// No description provided for @reportReasonViolence.
  ///
  /// In fr, this message translates to:
  /// **'Violence'**
  String get reportReasonViolence;

  /// No description provided for @reportReasonHateSpeech.
  ///
  /// In fr, this message translates to:
  /// **'Discours haineux'**
  String get reportReasonHateSpeech;

  /// No description provided for @reportReasonScam.
  ///
  /// In fr, this message translates to:
  /// **'Arnaque'**
  String get reportReasonScam;

  /// No description provided for @reportReasonImpersonation.
  ///
  /// In fr, this message translates to:
  /// **'Usurpation d\'identité'**
  String get reportReasonImpersonation;

  /// No description provided for @reportReasonOther.
  ///
  /// In fr, this message translates to:
  /// **'Autre'**
  String get reportReasonOther;

  /// No description provided for @maintenanceInProgress.
  ///
  /// In fr, this message translates to:
  /// **'Maintenance en cours'**
  String get maintenanceInProgress;

  /// No description provided for @maintenanceDefaultMessage.
  ///
  /// In fr, this message translates to:
  /// **'L\'application est temporairement indisponible pour maintenance. Veuillez réessayer plus tard.'**
  String get maintenanceDefaultMessage;

  /// No description provided for @maintenanceImprovingExperience.
  ///
  /// In fr, this message translates to:
  /// **'Nous travaillons pour améliorer votre expérience.'**
  String get maintenanceImprovingExperience;

  /// No description provided for @phoneVerifTitle.
  ///
  /// In fr, this message translates to:
  /// **'Vérification du numéro'**
  String get phoneVerifTitle;

  /// No description provided for @phoneVerifEnterCodeHint.
  ///
  /// In fr, this message translates to:
  /// **'Entrez le code envoyé au\n{phone}'**
  String phoneVerifEnterCodeHint(String phone);

  /// No description provided for @phoneVerifSendCodeHint.
  ///
  /// In fr, this message translates to:
  /// **'Nous allons envoyer un code de vérification au\n{phone}'**
  String phoneVerifSendCodeHint(String phone);

  /// No description provided for @sendCode.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer le code'**
  String get sendCode;

  /// No description provided for @verify.
  ///
  /// In fr, this message translates to:
  /// **'Vérifier'**
  String get verify;

  /// No description provided for @resendCode.
  ///
  /// In fr, this message translates to:
  /// **'Renvoyer le code'**
  String get resendCode;

  /// No description provided for @resendCodeIn.
  ///
  /// In fr, this message translates to:
  /// **'Renvoyer dans {seconds}s'**
  String resendCodeIn(int seconds);

  /// No description provided for @phoneVerifSendError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de l\'envoi du code'**
  String get phoneVerifSendError;

  /// No description provided for @phoneVerifEnterComplete.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez entrer le code complet'**
  String get phoneVerifEnterComplete;

  /// No description provided for @phoneVerifResendRequired.
  ///
  /// In fr, this message translates to:
  /// **'Erreur de vérification. Veuillez renvoyer le code.'**
  String get phoneVerifResendRequired;

  /// No description provided for @phoneVerifUserNotLoggedIn.
  ///
  /// In fr, this message translates to:
  /// **'Erreur : utilisateur non connecté'**
  String get phoneVerifUserNotLoggedIn;

  /// No description provided for @phoneVerifInvalidCode.
  ///
  /// In fr, this message translates to:
  /// **'Code invalide'**
  String get phoneVerifInvalidCode;

  /// No description provided for @phoneVerifError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur de vérification'**
  String get phoneVerifError;

  /// No description provided for @phoneVerifInvalidNumber.
  ///
  /// In fr, this message translates to:
  /// **'Numéro de téléphone invalide'**
  String get phoneVerifInvalidNumber;

  /// No description provided for @phoneVerifTooManyAttempts.
  ///
  /// In fr, this message translates to:
  /// **'Trop de tentatives. Réessayez plus tard'**
  String get phoneVerifTooManyAttempts;

  /// No description provided for @phoneVerifQuotaExceeded.
  ///
  /// In fr, this message translates to:
  /// **'Quota dépassé. Réessayez plus tard'**
  String get phoneVerifQuotaExceeded;

  /// No description provided for @phoneVerifNetworkError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur réseau. Vérifiez votre connexion'**
  String get phoneVerifNetworkError;

  /// No description provided for @searchUsers.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher des utilisateurs'**
  String get searchUsers;

  /// No description provided for @inviteMember.
  ///
  /// In fr, this message translates to:
  /// **'Inviter un membre'**
  String get inviteMember;

  /// No description provided for @inviteSent.
  ///
  /// In fr, this message translates to:
  /// **'Invitation envoyée !'**
  String get inviteSent;

  /// No description provided for @inviteAlreadySent.
  ///
  /// In fr, this message translates to:
  /// **'Déjà invité'**
  String get inviteAlreadySent;

  /// No description provided for @inviteError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de l\'invitation'**
  String get inviteError;

  /// No description provided for @receivedGroupInvitations.
  ///
  /// In fr, this message translates to:
  /// **'Invitations reçues'**
  String get receivedGroupInvitations;

  /// No description provided for @invitedByName.
  ///
  /// In fr, this message translates to:
  /// **'Invité par {name}'**
  String invitedByName(String name);

  /// No description provided for @noInvitationsReceived.
  ///
  /// In fr, this message translates to:
  /// **'Aucune invitation en attente'**
  String get noInvitationsReceived;

  /// No description provided for @myQrCode.
  ///
  /// In fr, this message translates to:
  /// **'Mon QR Code'**
  String get myQrCode;

  /// No description provided for @scanMode.
  ///
  /// In fr, this message translates to:
  /// **'Scanner'**
  String get scanMode;

  /// No description provided for @shareMyQr.
  ///
  /// In fr, this message translates to:
  /// **'Partager mon QR'**
  String get shareMyQr;

  /// No description provided for @myPostsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mes publications'**
  String get myPostsTitle;

  /// No description provided for @myPostsEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Vous n\'avez pas encore publié'**
  String get myPostsEmpty;

  /// No description provided for @savedPostsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Posts sauvegardés'**
  String get savedPostsTitle;

  /// No description provided for @savedPostsEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Vous n\'avez pas encore sauvegardé de post'**
  String get savedPostsEmpty;

  /// No description provided for @savedPostsCountLabel.
  ///
  /// In fr, this message translates to:
  /// **'enregistrés'**
  String get savedPostsCountLabel;

  /// No description provided for @exploreFeed.
  ///
  /// In fr, this message translates to:
  /// **'Explorer le feed'**
  String get exploreFeed;

  /// No description provided for @videos.
  ///
  /// In fr, this message translates to:
  /// **'Vidéos'**
  String get videos;

  /// No description provided for @texts.
  ///
  /// In fr, this message translates to:
  /// **'Textes'**
  String get texts;

  /// No description provided for @myPostsEmptyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Votre première\npublication vous attend'**
  String get myPostsEmptyTitle;

  /// No description provided for @myPostsEmptyBody.
  ///
  /// In fr, this message translates to:
  /// **'Partagez une nouvelle, une photo ou une question avec la diaspora.'**
  String get myPostsEmptyBody;

  /// No description provided for @savedPostsEmptyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Rien d\'enregistré\npour l\'instant'**
  String get savedPostsEmptyTitle;

  /// No description provided for @savedPostsEmptyBody.
  ///
  /// In fr, this message translates to:
  /// **'Touchez le signet d\'une publication pour la garder ici.'**
  String get savedPostsEmptyBody;

  /// No description provided for @savedPostsNote.
  ///
  /// In fr, this message translates to:
  /// **'Vos enregistrements ne sont visibles que par vous.'**
  String get savedPostsNote;

  /// No description provided for @repostsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mes repartages'**
  String get repostsTitle;

  /// No description provided for @repostsError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger vos repartages.'**
  String get repostsError;

  /// No description provided for @repostsEmptyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aucun repartage'**
  String get repostsEmptyTitle;

  /// No description provided for @repostsEmptyBody.
  ///
  /// In fr, this message translates to:
  /// **'Repartagez une publication pour la faire découvrir à vos abonnés.'**
  String get repostsEmptyBody;

  /// No description provided for @followersEmptyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Pas encore\nd\'abonnés'**
  String get followersEmptyTitle;

  /// No description provided for @followersEmptyBody.
  ///
  /// In fr, this message translates to:
  /// **'Publiez et participez pour vous faire connaître de la diaspora.'**
  String get followersEmptyBody;

  /// No description provided for @followingEmptyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Vous ne suivez\npersonne'**
  String get followingEmptyTitle;

  /// No description provided for @followingEmptyBody.
  ///
  /// In fr, this message translates to:
  /// **'Suivez des membres pour voir leurs publications dans votre fil.'**
  String get followingEmptyBody;

  /// No description provided for @searchPeopleHint.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher une personne'**
  String get searchPeopleHint;

  /// No description provided for @suggestionsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Suggestions'**
  String get suggestionsTitle;

  /// No description provided for @older.
  ///
  /// In fr, this message translates to:
  /// **'Plus ancien'**
  String get older;

  /// No description provided for @trendingHashtags.
  ///
  /// In fr, this message translates to:
  /// **'Hashtags du moment'**
  String get trendingHashtags;

  /// No description provided for @noPostsForFilter.
  ///
  /// In fr, this message translates to:
  /// **'Aucune publication chargée pour ce filtre.'**
  String get noPostsForFilter;

  /// No description provided for @todayTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aujourd\'hui'**
  String get todayTitle;

  /// No description provided for @messagesUnreadTitle.
  ///
  /// In fr, this message translates to:
  /// **'Messages non lus'**
  String get messagesUnreadTitle;

  /// No description provided for @mentions.
  ///
  /// In fr, this message translates to:
  /// **'Mentions'**
  String get mentions;

  /// No description provided for @groupActive.
  ///
  /// In fr, this message translates to:
  /// **'Actif'**
  String get groupActive;

  /// No description provided for @groupCalm.
  ///
  /// In fr, this message translates to:
  /// **'Calme'**
  String get groupCalm;

  /// No description provided for @settingsPrivacySecurity.
  ///
  /// In fr, this message translates to:
  /// **'Confidentialité et sécurité'**
  String get settingsPrivacySecurity;

  /// No description provided for @settingsAppearanceLanguage.
  ///
  /// In fr, this message translates to:
  /// **'Apparence et langue'**
  String get settingsAppearanceLanguage;

  /// No description provided for @settingsHelpAbout.
  ///
  /// In fr, this message translates to:
  /// **'Aide et à propos'**
  String get settingsHelpAbout;

  /// No description provided for @locationReciprocity.
  ///
  /// In fr, this message translates to:
  /// **'C\'est donnant-donnant : partagez votre position approximative pour voir les membres proches de vous.'**
  String get locationReciprocity;

  /// No description provided for @locationGuarantee1.
  ///
  /// In fr, this message translates to:
  /// **'Position approximative, jamais votre adresse exacte'**
  String get locationGuarantee1;

  /// No description provided for @locationGuarantee2.
  ///
  /// In fr, this message translates to:
  /// **'Désactivable à tout moment'**
  String get locationGuarantee2;

  /// No description provided for @locationGuarantee3.
  ///
  /// In fr, this message translates to:
  /// **'Invisible pour les comptes que vous bloquez'**
  String get locationGuarantee3;

  /// No description provided for @exploreOtherwise.
  ///
  /// In fr, this message translates to:
  /// **'Explorer autrement'**
  String get exploreOtherwise;

  /// No description provided for @embassyOpen.
  ///
  /// In fr, this message translates to:
  /// **'Ouvert'**
  String get embassyOpen;

  /// No description provided for @reopenExpected.
  ///
  /// In fr, this message translates to:
  /// **'Réouverture prévue'**
  String get reopenExpected;

  /// No description provided for @posts.
  ///
  /// In fr, this message translates to:
  /// **'posts'**
  String get posts;

  /// No description provided for @postSingle.
  ///
  /// In fr, this message translates to:
  /// **'post'**
  String get postSingle;

  /// No description provided for @shareToConversation.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer à...'**
  String get shareToConversation;

  /// No description provided for @sharedFromAnotherApp.
  ///
  /// In fr, this message translates to:
  /// **'Partagé depuis une autre app'**
  String get sharedFromAnotherApp;

  /// No description provided for @sharedContentSent.
  ///
  /// In fr, this message translates to:
  /// **'Contenu partagé avec succès'**
  String get sharedContentSent;

  /// No description provided for @someSharedContentNotSent.
  ///
  /// In fr, this message translates to:
  /// **'Certains éléments n\'ont pas pu être partagés'**
  String get someSharedContentNotSent;

  /// No description provided for @sharedFileCount.
  ///
  /// In fr, this message translates to:
  /// **'+{count} fichier{count, plural, =1{} other{s}}'**
  String sharedFileCount(int count);

  /// No description provided for @sharedTextCount.
  ///
  /// In fr, this message translates to:
  /// **'1 texte'**
  String get sharedTextCount;

  /// No description provided for @exportConversation.
  ///
  /// In fr, this message translates to:
  /// **'Exporter la conversation'**
  String get exportConversation;

  /// No description provided for @exportFormatTxt.
  ///
  /// In fr, this message translates to:
  /// **'Texte (.txt)'**
  String get exportFormatTxt;

  /// No description provided for @exportFormatJson.
  ///
  /// In fr, this message translates to:
  /// **'JSON (.json)'**
  String get exportFormatJson;

  /// No description provided for @exportFormatHtml.
  ///
  /// In fr, this message translates to:
  /// **'HTML (.html)'**
  String get exportFormatHtml;

  /// No description provided for @noMessagesToExport.
  ///
  /// In fr, this message translates to:
  /// **'Aucun message à exporter'**
  String get noMessagesToExport;

  /// No description provided for @exportError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de l\'export'**
  String get exportError;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
