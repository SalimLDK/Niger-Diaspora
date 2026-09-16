import UserNotifications

/// Reconstruit l'aperçu d'un message MLS, dans l'extension de notification.
///
/// PENDANT iOS DE L'ISOLATE ANDROID
/// Sur Android, l'aperçu est reconstruit par un isolate Dart, qui a le pont
/// Flutter Rust Bridge. iOS n'offre pas ça : une Notification Service
/// Extension est un binaire séparé, sans moteur Flutter et sans Dart. Elle
/// appelle donc le moteur par son ABI C (`diaspo_mls_apercu`, `rust/src/ffi.rs`).
///
/// CE QU'ELLE NE FAIT JAMAIS
/// Elle ne fait pas avancer l'état MLS. Le moteur travaille sur une copie
/// jetable produite par `VACUUM INTO` : si l'extension consommait le cliquet,
/// l'application, en traitant ensuite le même message, ne pourrait plus le
/// lire — et la conversation deviendrait illisible **en silence**. Un seul
/// écrivain de l'état, et c'est l'application.
///
/// TROIS RAISONS DE NE RIEN FAIRE, TOUTES NORMALES
/// 1. la charge ne porte pas de ciphertext (message trop gros pour le push,
///    ou conversation encore en clair) ;
/// 2. l'utilisateur a désactivé l'aperçu des messages ;
/// 3. le moteur refuse — groupe inconnu, message déjà consommé par l'app,
///    base absente.
/// Dans les trois cas on laisse le contenu générique que le serveur a déjà
/// posé. Une notification dégradée vaut mieux qu'une notification perdue :
/// `iOS` remplace le contenu par le nôtre **ou** garde le sien, jamais rien.
///
/// ⚠️ JAMAIS COMPILÉ. Ce dépôt n'a pas de Mac. Voir `README.md` du dossier
/// pour les étapes Xcode qui restent, et ce qu'elles conditionnent.
final class NotificationService: UNNotificationServiceExtension {

  private var handler: ((UNNotificationContent) -> Void)?
  private var contenu: UNMutableNotificationContent?

  override func didReceive(
    _ request: UNNotificationRequest,
    withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
  ) {
    self.handler = contentHandler
    let modifiable = request.content.mutableCopy() as? UNMutableNotificationContent
    self.contenu = modifiable

    guard let contenu = modifiable else {
      contentHandler(request.content)
      return
    }

    let data = request.content.userInfo

    // Le serveur ne pose `mutable-content` que sur un message MLS, mais rien
    // n'interdit qu'une autre charge arrive ici un jour : on revérifie.
    guard (data["protocol"] as? String) == "mls",
          let base64 = data["mlsCiphertext"] as? String,
          !base64.isEmpty,
          let chiffre = Data(base64Encoded: base64)
    else {
      contentHandler(contenu)
      return
    }

    // Réglage « aperçu des messages » : le serveur l'a déjà consulté, mais
    // c'est ici que le clair existerait. On le respecte au plus près.
    if (data["showMessagePreview"] as? String) == "false" {
      contentHandler(contenu)
      return
    }

    guard let clair = Self.dechiffrer(data: data, chiffre: chiffre) else {
      contentHandler(contenu)
      return
    }

    contenu.body = clair
    contentHandler(contenu)
  }

  /// iOS coupe l'extension au bout de ~30 s. Rendre le contenu tel quel est la
  /// seule chose correcte : ne rien rendre ferait disparaître la notification.
  override func serviceExtensionTimeWillExpire() {
    if let handler = handler, let contenu = contenu {
      handler(contenu)
    }
  }

  private static func dechiffrer(data: [AnyHashable: Any], chiffre: Data) -> String? {
    // Les memes cles que l'isolate Android lit, au caractere pres. La charge
    // ne porte PAS le destinataire : comme sur Android, le compte courant est
    // relu la ou l'application l'a depose.
    guard let conversationId = data["conversationId"] as? String,
          let messageId = data["messageId"] as? String,
          let senderDeviceId = data["mlsSenderDeviceId"] as? String,
          let userId = MlsPontNatif.compteCourant(),
          let deviceId = MlsPontNatif.identifiantAppareil(pour: userId),
          let base = MlsPontNatif.cheminBase(pour: userId)
    else { return nil }

    let aad = MlsPontNatif.aadMessage(
      conversationId: conversationId,
      messageId: messageId,
      senderDeviceId: senderDeviceId,
      kind: (data["mlsKind"] as? String) ?? "content"
    )

    guard let charge = MlsPontNatif.chargeUtile(
      cheminBase: base,
      userId: userId,
      deviceId: deviceId,
      conversationId: conversationId,
      message: chiffre,
      aad: aad
    ) else { return nil }

    // Le moteur rend la charge utile, pas un texte : l'afficher telle quelle
    // mettrait tout le JSON (citation, mentions, identifiants) sur l'écran
    // verrouillé.
    return MlsPontNatif.resume(charge)
  }
}
