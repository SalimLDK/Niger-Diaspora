import 'dart:convert';


import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Le code de sécurité d'un appareil MLS, et sa vérification hors bande
/// (plan MLS, phase 7).
///
/// **Le risque que ça couvre, et lui seul.** MLS protège le contenu contre
/// tout ce qui n'est pas membre du groupe. Il ne protège pas contre un
/// serveur qui **substituerait un KeyPackage** : rien, dans le protocole, ne
/// dit à Alice que la clé publique servie pour l'appareil de Bob est bien
/// celle de Bob. C'est de la confiance au premier usage, et la seule réponse
/// connue est de comparer les clés **par un autre canal** que le serveur —
/// de vive voix, ou en scannant l'écran d'en face.
///
/// **Ce qui est comparé.** L'identité MLS de l'appareil (`uid:stable_id`) et
/// sa clé publique de signature, celle-là même dont MLS se sert pour valider
/// chaque message qu'il émet. Si le serveur avait substitué quoi que ce soit,
/// les deux codes diffèrent.
///
/// **Ce qui compte le plus n'est pas la première vérification, c'est le
/// changement.** Un code vérifié puis modifié veut dire qu'une clé a changé
/// depuis — réinstallation légitime le plus souvent, substitution sinon.
/// L'application doit le dire ; se taire reviendrait à faire de la
/// vérification un geste décoratif.
@immutable
class MlsCodeSecurite {
  const MlsCodeSecurite._();

  /// Séparation de domaine : ce condensé ne doit jamais pouvoir être confondu
  /// avec un autre calculé ailleurs sur les mêmes octets.
  static const _domaine = 'dn-mls-verif-v1';

  static const _prefixeQr = 'dn-mls-verif';
  static const _versionQr = '1';

  /// Un code se calcule-t-il pour cet appareil ?
  ///
  /// Sans clé publiée, [empreinteAppareil] rendrait quand même un condensé —
  /// et deux appareils sans clé auraient **le même**. Deux personnes
  /// compareraient alors des codes identiques et en concluraient qu'elles
  /// sont vérifiées, ce qui est exactement le contraire de ce qu'on cherche.
  /// L'écran doit dire « code indisponible ».
  static bool estCalculable(Uint8List signatureKey) => signatureKey.isNotEmpty;

  /// L'empreinte d'un appareil : 32 octets qui résument son identité MLS et
  /// sa clé publique de signature.
  static Uint8List empreinteAppareil({
    required String mlsIdentity,
    required Uint8List signatureKey,
  }) {
    final entree = <int>[
      ...utf8.encode(_domaine),
      0,
      ...utf8.encode(mlsIdentity),
      0,
      ...signatureKey,
    ];
    return Uint8List.fromList(sha256.convert(entree).bytes);
  }

  /// Le code d'une conversation : une seule chaîne à comparer, quel que soit
  /// le nombre d'appareils en face.
  ///
  /// Les empreintes sont **triées** avant d'être condensées : deux personnes
  /// qui comparent ne lisent pas la liste des membres dans le même ordre, et
  /// un code qui dépendrait de l'ordre ne serait jamais égal.
  static Uint8List empreinteConversation(Iterable<Uint8List> empreintes) {
    final triees = empreintes.map(base64Encode).toList()..sort();
    final entree = <int>[
      ...utf8.encode(_domaine),
      for (final e in triees) ...[0, ...base64Decode(e)],
    ];
    return Uint8List.fromList(sha256.convert(entree).bytes);
  }

  /// 60 chiffres en 12 groupes de 5 — la forme que deux personnes peuvent
  /// s'échanger à voix haute sans se tromper.
  ///
  /// Des chiffres, et pas du base64 : lire « lI0O » au téléphone se trompe,
  /// lire « 14 » non. Douze groupes de cinq, comme le numéro de sécurité de
  /// Signal, pour la même raison — on compare par blocs, pas caractère par
  /// caractère.
  static String formater(Uint8List empreinte) {
    // `empreinteAppareil` rend 32 octets ; il en faut 60. On étire par un
    // second condensé, sans rien inventer : le tout reste une fonction
    // déterministe de l'empreinte.
    final etendu = <int>[
      ...empreinte,
      ...sha256.convert([...empreinte, 1]).bytes,
    ];
    final groupes = <String>[];
    for (var i = 0; i < 12; i++) {
      final debut = i * 5;
      var valeur = 0;
      for (var j = 0; j < 5; j++) {
        valeur = (valeur << 8) | etendu[debut + j];
      }
      groupes.add((valeur % 100000).toString().padLeft(5, '0'));
    }
    return groupes.join(' ');
  }

  /// Ce que l'appareil affiche en QR, pour que l'autre n'ait pas à lire
  /// soixante chiffres.
  ///
  /// Le QR ne porte **aucun secret** : une empreinte publique et une
  /// identité. Photographié par un tiers, il ne lui apprend rien qu'il ne
  /// puisse déjà lire dans `mls_devices`.
  static String chargeQr({
    required String mlsIdentity,
    required Uint8List empreinte,
  }) =>
      '$_prefixeQr:$_versionQr:$mlsIdentity:${base64Url.encode(empreinte)}';

  /// L'inverse. Rend `null` sur tout ce qui n'est pas un code de sécurité de
  /// cette application : un QR de partage de profil, un lien, du texte.
  /// L'écran doit dire « ce n'est pas un code de vérification », jamais
  /// afficher « ne correspond pas » — l'accusation serait fausse.
  /// **Découpé aux extrémités, pas par `split`.** L'identité MLS vaut
  /// `uid:stable_id` : elle contient déjà un `:`, et un découpage naïf rendait
  /// cinq morceaux là où on en attendait quatre — tout QR valide était rejeté
  /// comme étranger. Trouvé par le banc avant la première ligne d'écran.
  static ({String mlsIdentity, Uint8List empreinte})? lireQr(String brut) {
    final texte = brut.trim();
    final premier = texte.indexOf(':');
    if (premier == -1) return null;
    final second = texte.indexOf(':', premier + 1);
    if (second == -1) return null;
    final dernier = texte.lastIndexOf(':');
    if (dernier <= second) return null;

    if (texte.substring(0, premier) != _prefixeQr) return null;
    if (texte.substring(premier + 1, second) != _versionQr) return null;

    final identite = texte.substring(second + 1, dernier);
    if (identite.isEmpty) return null;
    try {
      final empreinte = base64Url.decode(texte.substring(dernier + 1));
      if (empreinte.length != 32) return null;
      return (mlsIdentity: identite, empreinte: Uint8List.fromList(empreinte));
    } catch (_) {
      return null;
    }
  }
}

/// Ce qu'un scan de code de sécurité peut donner.
enum ResultatScan {
  /// Le QR n'est pas un code de vérification de cette application.
  ///
  /// **Distinct de [neCorrespondPas], et ça compte** : dire « ne correspond
  /// pas » sur un QR de profil serait une accusation fausse, et la personne
  /// chercherait un attaquant qui n'existe pas.
  pasUnCode,

  /// Le code est bien formé, mais l'appareil qu'il désigne n'est pas dans le
  /// registre — ou n'a pas publié de clé. Rien à comparer, donc rien à dire.
  appareilInconnu,

  /// Les deux côtés voient la même clé.
  correspond,

  /// **Le code lu ne correspond pas à la clé servie par le serveur.** C'est
  /// exactement ce que la phase 7 cherche à détecter.
  neCorrespondPas,
}

/// La comparaison, sans caméra ni base : elle ne dépend que du contenu lu et
/// d'une façon de retrouver la clé publiée pour cette identité.
abstract final class MlsVerificationScan {
  static Future<ResultatScan> comparer({
    required String charge,
    required Future<Uint8List?> Function(String mlsIdentity) cleDe,
  }) async {
    final lu = MlsCodeSecurite.lireQr(charge);
    if (lu == null) return ResultatScan.pasUnCode;

    final cle = await cleDe(lu.mlsIdentity);
    if (cle == null || !MlsCodeSecurite.estCalculable(cle)) {
      return ResultatScan.appareilInconnu;
    }

    final attendue = MlsCodeSecurite.empreinteAppareil(
      mlsIdentity: lu.mlsIdentity,
      signatureKey: cle,
    );
    return _egales(attendue, lu.empreinte)
        ? ResultatScan.correspond
        : ResultatScan.neCorrespondPas;
  }

  static bool _egales(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}

/// L'état de vérification d'un appareil, du point de vue de celui qui
/// regarde.
enum EtatVerification {
  /// Jamais comparé. C'est l'état normal, pas une alerte.
  jamais,

  /// Comparé, et inchangé depuis.
  verifie,

  /// **Comparé, et la clé a changé depuis.** Le cas qui justifie tout le
  /// reste : réinstallation la plupart du temps, substitution sinon. Dans les
  /// deux cas, la personne doit revérifier avant de parler.
  changee,
}

/// Ce que j'ai vérifié, gardé **sur cet appareil seulement**.
///
/// Une vérification est une opinion personnelle : « j'ai comparé, de vive
/// voix, et c'était bien lui ». Elle n'a pas à être publiée au serveur, qui
/// est précisément la partie dont on se méfie — et qui pourrait sinon
/// prétendre qu'une substitution a été vérifiée. Le prix est qu'elle ne
/// survit pas à une réinstallation ; c'est le même choix que Signal.
class MlsVerifications {
  MlsVerifications({
    required this.userId,
    Future<String?> Function(String cle)? lire,
    Future<void> Function(String cle, String valeur)? ecrire,
    Future<void> Function(String cle)? effacer,
  })  : _lire = lire ?? _lirePrefs,
        _ecrire = ecrire ?? _ecrirePrefs,
        _effacer = effacer ?? _effacerPrefs;

  final String userId;
  final Future<String?> Function(String cle) _lire;
  final Future<void> Function(String cle, String valeur) _ecrire;
  final Future<void> Function(String cle) _effacer;

  static Future<String?> _lirePrefs(String cle) async =>
      (await SharedPreferences.getInstance()).getString(cle);

  static Future<void> _ecrirePrefs(String cle, String valeur) async =>
      (await SharedPreferences.getInstance()).setString(cle, valeur);

  static Future<void> _effacerPrefs(String cle) async =>
      (await SharedPreferences.getInstance()).remove(cle);

  /// Par compte : deux personnes sur le même téléphone n'ont pas vérifié les
  /// mêmes appareils.
  String _cle(String mlsIdentity) => 'mls_verif_${userId}_$mlsIdentity';

  Future<void> marquerVerifie(String mlsIdentity, Uint8List empreinte) =>
      _ecrire(_cle(mlsIdentity), base64Encode(empreinte));

  Future<void> oublier(String mlsIdentity) => _effacer(_cle(mlsIdentity));

  /// L'état de cet appareil, au vu de l'empreinte qu'il présente
  /// aujourd'hui.
  Future<EtatVerification> etat(
    String mlsIdentity,
    Uint8List empreinteActuelle,
  ) async {
    String? memorisee;
    try {
      memorisee = await _lire(_cle(mlsIdentity));
    } catch (e) {
      // Une mémoire illisible ne doit pas se lire comme une alerte : « je ne
      // sais pas » n'est pas « la clé a changé ».
      debugPrint('MlsVerifications: état illisible ($e)');
      return EtatVerification.jamais;
    }
    if (memorisee == null || memorisee.isEmpty) return EtatVerification.jamais;
    return memorisee == base64Encode(empreinteActuelle)
        ? EtatVerification.verifie
        : EtatVerification.changee;
  }
}
