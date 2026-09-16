import Foundation

/// Le pont entre l'extension et le moteur Rust.
///
/// Séparé de `NotificationService` pour une raison pratique : cette moitié est
/// testable dans un test unitaire d'extension, la première ne l'est pas.
///
/// ⚠️ JAMAIS COMPILÉ. Voir `README.md` du dossier.
enum MlsPontNatif {

  /// Groupe d'application partagé entre l'app et l'extension.
  ///
  /// C'est la condition sine qua non : sans conteneur partagé, l'extension ne
  /// voit tout simplement pas la base du moteur, qui vit dans le bac à sable
  /// de l'application. À déclarer dans les deux cibles, avec le MÊME
  /// identifiant, et à reporter côté Dart (`mlsEngineProvider`) pour que la
  /// base soit créée là et pas ailleurs.
  static let groupeApp = "group.com.diasponiger.diasponiger"

  /// Chemin de la base du moteur pour ce compte, dans le conteneur partagé.
  ///
  /// Doit rester le miroir exact de ce que `nomFichierBaseMls` construit
  /// (`lib/core/crypto/mls/mls_chemin_base.dart`) :
  /// `<conteneur>/mls/<uid assaini>.sqlite`. Un écart, et l'extension lit une
  /// base qui n'existe pas — donc rien, en silence.
  ///
  /// `isASCII` n'est pas une précaution de style : côté Dart la classe est
  /// `[^A-Za-z0-9_-]`, purement ASCII, alors que `isLetter` de Swift est
  /// Unicode et laisserait passer `é` ou `中`. Les uid Firebase sont ASCII,
  /// donc l'écart ne se verrait sur aucun compte réel — jusqu'au jour où le
  /// dépôt changerait de fournisseur d'identité.
  static func cheminBase(pour userId: String) -> String? {
    guard let conteneur = FileManager.default
      .containerURL(forSecurityApplicationGroupIdentifier: groupeApp)
    else { return nil }
    let sain = userId.map { c -> String in
      let ok = (c.isASCII && (c.isLetter || c.isNumber)) || c == "_" || c == "-"
      return ok ? String(c) : "_"
    }.joined()
    return conteneur.appendingPathComponent("mls/\(sain).sqlite").path
  }

  /// Le compte connecté, déposé par l'application.
  ///
  /// La charge du push ne porte pas le destinataire — c'est déjà vrai sur
  /// Android, où l'isolate le relit dans les préférences sous `currentUserId`.
  /// Ici, dans celles du groupe partagé, écrites par
  /// `AppDelegate.deposerContexteMls` et retirées à la déconnexion.
  static func compteCourant() -> String? {
    UserDefaults(suiteName: groupeApp)?.string(forKey: "currentUserId")
  }

  /// Identifiant d'appareil, déposé par l'application à l'inscription.
  ///
  /// L'extension ne peut pas le recalculer : il vient d'`identifierForVendor`
  /// via un canal natif que l'app seule possède. Android a exactement le même
  /// problème, et le résout de la même façon — l'identifiant est mémorisé au
  /// moment où il est connu de façon sûre.
  ///
  /// Le dépôt doit se faire dans les `UserDefaults` du groupe partagé, pas
  /// dans ceux de l'application : sinon l'extension ne les voit pas.
  static func identifiantAppareil(pour userId: String) -> String? {
    UserDefaults(suiteName: groupeApp)?
      .string(forKey: "mls_stable_device_id_\(userId)")
  }

  /// L'AAD d'un message, **exactement** comme le construit le Dart
  /// (`MlsAad.message`). Le moteur refuse tout écart : c'est le but de l'AAD.
  static func aadMessage(
    conversationId: String,
    messageId: String,
    senderDeviceId: String,
    kind: String
  ) -> Data {
    Data("dn-mls/1|\(conversationId)|\(messageId)|\(senderDeviceId)|\(kind)".utf8)
  }

  /// Appelle le moteur. Rend la **charge utile** déchiffrée, ou `nil` — jamais
  /// une exception.
  ///
  /// ⚠️ Ce n'est PAS du texte affichable : `preview_without_state` rend le
  /// payload du plan MLS § 6.2, c'est-à-dire du JSON portant le type, le
  /// corps, la citation, les mentions et le minuteur. Le poser tel quel dans
  /// une notification afficherait tout ça sur l'écran verrouillé. Passer par
  /// [resume].
  ///
  /// Le tampon est fourni par nous : l'ABI n'alloue rien qu'il faudrait
  /// libérer ici. S'il est trop court, le moteur dit la taille qu'il fallait
  /// et on réessaie une fois.
  static func chargeUtile(
    cheminBase: String,
    userId: String,
    deviceId: String,
    conversationId: String,
    message: Data,
    aad: Data
  ) -> Data? {
    func tenter(_ taille: Int) -> (code: Int32, octets: [UInt8], ecrits: Int) {
      var sortie = [UInt8](repeating: 0, count: max(taille, 1))
      var ecrits = 0
      let code = cheminBase.withCString { cBase in
        userId.withCString { cUser in
          deviceId.withCString { cDevice in
            conversationId.withCString { cConv in
              message.withUnsafeBytes { mBuf in
                aad.withUnsafeBytes { aBuf in
                  diaspo_mls_apercu(
                    cBase, cUser, cDevice, cConv,
                    mBuf.bindMemory(to: UInt8.self).baseAddress, message.count,
                    aBuf.bindMemory(to: UInt8.self).baseAddress, aad.count,
                    &sortie, sortie.count, &ecrits
                  )
                }
              }
            }
          }
        }
      }
      return (code, sortie, ecrits)
    }

    var r = tenter(4096)
    if r.code == -3 /* CODE_TAMPON_TROP_PETIT */ {
      r = tenter(r.ecrits)
    }
    guard r.code == 0, r.ecrits <= r.octets.count else { return nil }
    return Data(r.octets.prefix(r.ecrits))
  }

  /// Le texte d'aperçu tiré d'une charge utile, ou `nil` s'il n'y en a pas.
  ///
  /// **Pendant Swift de `MlsNotificationPreview.resume`.** Les deux tables
  /// d'étiquettes doivent rester identiques : un « Photo » devenu « Image »
  /// d'un seul côté donnerait deux libellés selon la plateforme, et rien ne le
  /// signalerait. Verrouillé par
  /// `test/core/crypto/mls_apercu_ios_parite_test.dart`, qui lit les deux
  /// fichiers et compare.
  ///
  /// Seul `text` fait sortir du contenu de l'utilisateur ; tous les autres
  /// types rendent une étiquette fixe, et un type inconnu ne rend rien — le
  /// repli générique du serveur est alors préférable à une fuite.
  static func resume(_ charge: Data) -> String? {
    guard let objet = try? JSONSerialization.jsonObject(with: charge),
          let json = objet as? [String: Any],
          let type = json["type"] as? String
    else { return nil }

    switch type {
    case "text":
      let corps = json["body"] as? [String: Any]
      let texte = (corps?["content"] as? String)?
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      return texte.isEmpty ? nil : texte
    case "image": return "Photo"
    case "video": return "Vidéo"
    case "voiceNote": return "Note vocale"
    case "audio": return "Audio"
    case "file": return "Fichier"
    case "location": return "Position"
    case "sticker": return "Sticker"
    case "poll": return "Sondage"
    case "call": return "Appel"
    default: return nil
    }
  }
}
