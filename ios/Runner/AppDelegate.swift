import Flutter
import UIKit
import GoogleMaps
import UserNotifications

/// Pendant iOS de `MainActivity.java`.
///
/// Tous les canaux natifs d'Android n'ont pas vocation à être portés :
///
/// - `diaspo_niger/lockscreen` n'a pas d'équivalent. Il remplace les attributs
///   `showWhenLocked`/`turnScreenOn` d'Android ; sur iOS, l'affichage d'un appel
///   par-dessus l'écran verrouillé relève de CallKit, géré par
///   `flutter_callkit_incoming`. `LockScreenService._apply` sort d'ailleurs
///   avant l'appel dès que la plateforme n'est pas Android.
///
/// - `diaspo_niger/deep_link` n'est PAS reproduit ici, et c'est délibéré. Côté
///   Android il contourne un vrai défaut : le moteur mis en cache qu'impose
///   `audio_service` empêche le canal de navigation de l'embedding d'aboutir,
///   donc les liens reçus à chaud n'atteignaient jamais GoRouter. Ce montage
///   n'existe pas sur iOS : `FlutterDeepLinkingEnabled` étant à `true` dans
///   `Info.plist`, `FlutterAppDelegate` relaie lui-même les Universal Links et
///   le schéma `diasponiger://` au canal de navigation. Ajouter le canal ici
///   ferait naviguer DEUX fois pour un même lien.
@main
@objc class AppDelegate: FlutterAppDelegate {

  /// Canal partagé avec Android. Sur iOS il ne porte que `getInstallationId` :
  /// `clearSharedIntent` manipule l'intent de l'activité Android, notion qui
  /// n'existe pas ici (le Dart le garde d'ailleurs derrière `Platform.isAndroid`).
  private static let shareIntentChannel = "diaspo_niger/share_intent"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("AIzaSyCnbdymYwzJXPA2YY1PMexCU_iGaN5tPek")

    GeneratedPluginRegistrant.register(with: self)

    // Sans ce délégué, `flutter_local_notifications` ne peut rien présenter
    // pendant que l'app est au premier plan : iOS supprime silencieusement la
    // bannière et aucune erreur n'apparaît nulle part. À poser APRÈS
    // l'enregistrement des plugins, pour que FirebaseMessaging ait déjà installé
    // son relais de swizzling.
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }

    registerShareIntentChannel()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func registerShareIntentChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      NSLog("AppDelegate: FlutterViewController introuvable, canal share_intent non enregistré")
      return
    }

    let channel = FlutterMethodChannel(
      name: AppDelegate.shareIntentChannel,
      binaryMessenger: controller.binaryMessenger
    )

    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "getInstallationId":
        result(Self.installationId())
      case "clearSharedIntent":
        // Sans objet sur iOS : `receive_sharing_intent` fait son propre ménage
        // via `reset()`. On répond quand même pour ne pas laisser l'appelant
        // sur une MissingPluginException.
        result(nil)
      case "exclureDeLaSauvegarde":
        guard let chemin = call.arguments as? String else {
          result(false)
          return
        }
        result(Self.exclureDeLaSauvegarde(chemin))
      case "cheminGroupeApp":
        guard let groupe = call.arguments as? String else {
          result(nil)
          return
        }
        result(Self.cheminGroupeApp(groupe))
      case "deposerContexteMls":
        guard let args = call.arguments as? [String: String],
              let groupe = args["groupe"],
              let userId = args["userId"],
              let deviceId = args["deviceId"] else {
          result(false)
          return
        }
        result(Self.deposerContexteMls(groupe: groupe, userId: userId, deviceId: deviceId))
      case "effacerContexteMls":
        guard let groupe = call.arguments as? String else {
          result(false)
          return
        }
        result(Self.effacerContexteMls(groupe))
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// Identifiant d'installation stable, pendant iOS du SSAID Android.
  ///
  /// `identifierForVendor` a exactement les propriétés recherchées : propre au
  /// couple (vendeur, appareil), stable d'une réinstallation à l'autre tant
  /// qu'une app du même vendeur reste installée, et non partagé entre éditeurs
  /// — ce n'est donc pas un identifiant matériel.
  ///
  /// Ce que ça corrige : sans lui, `stableDeviceId` retombait sur un UUID
  /// aléatoire, et chaque régénération de clés créait une NOUVELLE ligne dans
  /// `e2ee_devices`. Les identités mortes s'accumulent, et tout message destiné
  /// au compte doit être chiffré pour **chacune** d'entre elles.
  ///
  /// Jamais transmis tel quel : le Dart en publie un condensé SHA-256 salé par
  /// l'identifiant de compte (cf. `stableDeviceId`).
  ///
  /// Peut être nil — l'appelant retombe alors sur l'UUID aléatoire, c'est-à-dire
  /// le comportement d'avant.
  private static func installationId() -> String? {
    return UIDevice.current.identifierForVendor?.uuidString
  }

  /// Retire un dossier de la sauvegarde iCloud.
  ///
  /// Pendant iOS de ce qu'Android obtient par `regles_sauvegarde.xml` : la
  /// base SQLite du moteur MLS — clé privée de signature de l'appareil,
  /// secrets d'epoch, arbres de groupe — vit dans le conteneur du groupe
  /// d'application (`Application Support` en repli), sauvegardé par défaut dans
  /// les deux cas. Sans cet appel, elle quitte le téléphone.
  ///
  /// `Library/Caches` échapperait aussi à la sauvegarde, mais le système peut
  /// le vider quand il veut : un état MLS effacé sans prévenir rendrait toutes
  /// les conversations basculées illisibles. Ce drapeau est donc la seule voie
  /// correcte.
  ///
  /// Rend `false` plutôt que de lever : une exclusion qui échoue est un
  /// problème de confidentialité, pas une raison d'empêcher l'application de
  /// démarrer. L'appelant le journalise.
  /// Chemin du conteneur du groupe d'application, ou nil s'il n'est pas
  /// provisionné.
  ///
  /// C'est le seul terrain commun entre l'application et l'extension de
  /// notification : deux processus, deux bacs à sable. La base du moteur MLS y
  /// vit désormais, faute de quoi l'extension n'aurait rien à ouvrir.
  ///
  /// **Rend nil sans drame.** Tant que la capability « App Groups » n'est pas
  /// activée sur l'App ID et le profil régénéré, `containerURL` renvoie nil.
  /// Le Dart reste alors sur `Application Support` : l'app fonctionne comme
  /// avant, seul l'aperçu des notifications retombe sur le texte générique.
  private static func cheminGroupeApp(_ groupe: String) -> String? {
    return FileManager.default
      .containerURL(forSecurityApplicationGroupIdentifier: groupe)?
      .path
  }

  /// Dépose le compte courant et son identifiant d'appareil pour l'extension.
  ///
  /// **Pourquoi pas `SharedPreferences`.** Le greffon Flutter écrit dans
  /// `UserDefaults.standard` en préfixant toutes ses clés par `flutter.`. Une
  /// extension qui lit `"currentUserId"` dans la suite du groupe ne trouverait
  /// donc rien — sans erreur et sans journal. Les clés sont écrites ici telles
  /// que `MlsPontNatif` les lit, au caractère près.
  private static func deposerContexteMls(
    groupe: String,
    userId: String,
    deviceId: String
  ) -> Bool {
    guard let defaults = UserDefaults(suiteName: groupe) else {
      NSLog("AppDelegate: suite \(groupe) indisponible, contexte MLS non déposé")
      return false
    }
    defaults.set(userId, forKey: "currentUserId")
    defaults.set(deviceId, forKey: "mls_stable_device_id_\(userId)")
    return true
  }

  /// Efface le dépôt à la déconnexion.
  ///
  /// Seul `currentUserId` est retiré : c'est lui qui désigne le compte, et
  /// l'extension n'ouvre rien sans lui. Les identifiants d'appareil restent,
  /// car ils sont valables pour une reconnexion sur le même compte et ne
  /// désignent personne à eux seuls.
  private static func effacerContexteMls(_ groupe: String) -> Bool {
    guard let defaults = UserDefaults(suiteName: groupe) else { return false }
    defaults.removeObject(forKey: "currentUserId")
    return true
  }

  private static func exclureDeLaSauvegarde(_ chemin: String) -> Bool {
    var url = URL(fileURLWithPath: chemin)
    do {
      var valeurs = URLResourceValues()
      valeurs.isExcludedFromBackup = true
      try url.setResourceValues(valeurs)
      return true
    } catch {
      NSLog("AppDelegate: exclusion de sauvegarde refusée pour \(chemin) : \(error)")
      return false
    }
  }
}
