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
}
