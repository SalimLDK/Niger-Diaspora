import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Ce que ces tests protègent (plan MLS § 8, moitié iOS)
/// ------------------------------------------------------
/// L'aperçu d'un message chiffré est reconstruit sur l'appareil. Sur Android
/// c'est un isolate Dart ; sur iOS, une Notification Service Extension, donc
/// **un autre binaire, en Swift, dans un autre bac à sable**. Quatre valeurs se
/// retrouvent donc écrites dans deux ou trois langages à la fois, et il n'y a
/// aucun compilateur pour les rapprocher.
///
/// **Le vrai danger n'est pas qu'elles divergent : c'est que ça ne se voie
/// pas.** Un identifiant de groupe mal recopié, et l'extension ouvre un
/// conteneur vide ; un chemin de base qui ne correspond plus, et elle lit un
/// fichier absent ; une étiquette « Photo » devenue « Image » d'un seul côté,
/// et deux téléphones affichent deux textes. Dans les quatre cas, le code de
/// repli fait son travail : la notification s'affiche, générique, sans erreur
/// et sans journal. Le défaut peut vivre des mois.
///
/// Ces tests lisent les fichiers source — c'est le seul moyen depuis ce poste,
/// qui n'a pas de Mac et ne compile donc jamais le Swift.
///
/// Voir `ios/NotificationService/README.md` pour ce qui reste à faire dans
/// Xcode, et pourquoi `project.pbxproj` n'est pas modifié à la main.

String _lire(String chemin) =>
    File(chemin).readAsStringSync().replaceAll('\r\n', '\n');

/// Le corps d'une fonction, de son en-tête jusqu'à la suivante.
String _corps(String source, String ancre, {String? jusqua}) {
  final debut = source.indexOf(ancre);
  expect(debut, isNot(-1), reason: '$ancre introuvable');
  if (jusqua == null) return source.substring(debut);
  final fin = source.indexOf(jusqua, debut + ancre.length);
  return source.substring(debut, fin == -1 ? source.length : fin);
}

/// Les `case 'x': return 'Y';` d'un `switch`, sous forme de table.
///
/// Le cas `text` n'en fait volontairement pas partie des deux côtés : il rend
/// le contenu de l'utilisateur, pas une étiquette fixe.
Map<String, String> _etiquettes(String corps, RegExp motif) => {
      for (final m in motif.allMatches(corps)) m.group(1)!: m.group(2)!,
    };

void main() {
  const dartPreview = 'lib/core/crypto/mls/mls_notification_preview.dart';
  const dartChemin = 'lib/core/crypto/mls/mls_chemin_base.dart';
  const dartPartage = 'lib/core/crypto/mls/mls_partage_extension_ios.dart';
  const dartCodec = 'lib/core/crypto/mls/mls_payload_codec.dart';
  const swiftPont = 'ios/NotificationService/MlsPontNatif.swift';
  const swiftService = 'ios/NotificationService/NotificationService.swift';
  const entitlementsApp = 'ios/Runner/Runner.entitlements';
  const entitlementsExt =
      'ios/NotificationService/NotificationService.entitlements';
  const infoPlist = 'ios/NotificationService/Info.plist';
  const entete = 'ios/NotificationService/NotificationService-Bridging-Header.h';
  const ffi = 'rust/src/ffi.rs';
  const sendPush = 'supabase/functions/send-push/index.ts';

  group('le groupe d\'application est le même partout', () {
    const groupe = 'group.com.diasponiger.diasponiger';

    test('les quatre déclarations portent la même valeur', () {
      // Sans conteneur commun, l'extension ne voit pas la base du moteur :
      // c'est la condition sine qua non de tout le reste.
      expect(_lire(dartPartage).contains("groupeAppIos = '$groupe'"), isTrue,
          reason: 'la constante Dart');
      expect(_lire(swiftPont).contains('groupeApp = "$groupe"'), isTrue,
          reason: 'la constante Swift');
      expect(_lire(entitlementsApp).contains('<string>$groupe</string>'), isTrue,
          reason: 'les entitlements du Runner');
      expect(_lire(entitlementsExt).contains('<string>$groupe</string>'), isTrue,
          reason: "les entitlements de l'extension");
    });

    test('les entitlements déclarent bien la clé App Groups', () {
      // La valeur seule ne suffit pas : c'est la clé qui ouvre le conteneur.
      for (final f in [entitlementsApp, entitlementsExt]) {
        expect(
          _lire(f).contains('com.apple.security.application-groups'),
          isTrue,
          reason: f,
        );
      }
    });
  });

  group('le chemin de la base est le même des deux côtés', () {
    test('Dart et Swift assainissent la même classe de caractères', () {
      // `isLetter` de Swift est Unicode ; la classe Dart est ASCII. Sans
      // `isASCII`, un uid non ASCII donnerait deux noms de fichiers.
      expect(_lire(dartChemin).contains(r"RegExp(r'[^A-Za-z0-9_-]'), '_'"),
          isTrue,
          reason: "l'assainissement Dart");
      final pont = _lire(swiftPont);
      expect(pont.contains('c.isASCII && (c.isLetter || c.isNumber)'), isTrue,
          reason: "l'assainissement Swift doit être ASCII comme le Dart");
      expect(pont.contains('c == "_" || c == "-"'), isTrue);
    });

    test('la même forme de chemin, `mls/<uid>.sqlite`', () {
      expect(_lire(dartChemin).contains(".sqlite'"), isTrue);
      expect(_lire(swiftPont).contains('"mls/\\(sain).sqlite"'), isTrue);
    });

    test('le Dart ne recopie plus le chemin en deux endroits', () {
      // Il l'était : `mlsEngineProvider` et `MlsNotificationPreview` le
      // construisaient chacun de son côté, à partir de
      // `getApplicationSupportDirectory`. Sur iOS le dossier a changé — une
      // copie oubliée aurait fait lire l'ancien emplacement, vide.
      expect(_lire(dartPreview).contains('getApplicationSupportDirectory'),
          isFalse,
          reason: "l'aperçu doit passer par cheminBaseMls");
      expect(
        _lire('lib/core/crypto/mls/mls_engine_provider.dart')
            .contains('getApplicationSupportDirectory'),
        isFalse,
        reason: 'le moteur doit passer par dossierBaseMls',
      );
    });
  });

  group("l'AAD est composée à l'identique", () {
    /// `dn-mls/1|conv|msg|appareil|kind`, les interpolations réduites à `*`.
    String forme(String litteral, RegExp interpolation) =>
        litteral.replaceAll(interpolation, '*');

    test('même gabarit en Dart et en Swift', () {
      final source = _lire(dartCodec);
      final debut = source.indexOf("utf8.encode('") + "utf8.encode('".length;
      final litteralDart = source.substring(debut, source.indexOf("')", debut));
      final gabaritDart = forme(
        litteralDart.replaceAll(r'$version', 'dn-mls/1'),
        RegExp(r'\$[A-Za-z]+'),
      );

      final pont = _lire(swiftPont);
      final d2 = pont.indexOf('Data("') + 'Data("'.length;
      final litteralSwift = pont.substring(d2, pont.indexOf('".utf8)', d2));
      final gabaritSwift = forme(litteralSwift, RegExp(r'\\\([A-Za-z]+\)'));

      expect(gabaritDart, 'dn-mls/1|*|*|*|*');
      expect(gabaritSwift, gabaritDart,
          reason: 'le moteur refuse tout écart : c\'est le but de l\'AAD');
    });
  });

  group('les étiquettes d\'aperçu sont les mêmes', () {
    const attendues = {
      'image': 'Photo',
      'video': 'Vidéo',
      'voiceNote': 'Note vocale',
      'audio': 'Audio',
      'file': 'Fichier',
      'location': 'Position',
      'sticker': 'Sticker',
      // Deux types que `MlsPayload` documente et que les deux tables
      // ignoraient : message déchiffré, aperçu générique quand même.
      'poll': 'Sondage',
      'call': 'Appel',
    };

    test('Dart et Swift rendent le même texte pour chaque type', () {
      final dart = _etiquettes(
        _corps(_lire(dartPreview), 'static String? resume(',
            jusqua: '\n  static '),
        RegExp("case '([A-Za-z]+)':\\s*\\n\\s*return '([^']+)';"),
      );
      final swift = _etiquettes(
        _corps(_lire(swiftPont), 'static func resume('),
        RegExp('case "([A-Za-z]+)": return "([^"]+)"'),
      );

      expect(dart, attendues, reason: 'la table Dart a bougé');
      expect(swift, attendues, reason: 'la table Swift a bougé');
    });

    test('tout ce que le service appelle sur le pont existe', () {
      // Le seul compilateur Swift de ce dépôt, c'est ce test. Une méthode
      // supprimée en même temps que son commentaire est passée inaperçue le
      // 2026-09-16 : le service appelait `compteCourant()`, disparu du pont.
      // Rien ne l'aurait dit avant la première compilation, sur un Mac.
      final pont = _lire(swiftPont);
      final appels = RegExp(r'MlsPontNatif\.([A-Za-z]+)\(')
          .allMatches(_lire(swiftService))
          .map((m) => m.group(1)!)
          .toSet();
      expect(appels, isNotEmpty, reason: 'le service doit passer par le pont');
      for (final nom in appels) {
        expect(
          pont.contains('static func $nom('),
          isTrue,
          reason: 'MlsPontNatif.$nom est appelé mais n\'existe pas',
        );
      }
    });

    test('le Swift ne met jamais la charge utile brute dans la bannière', () {
      // Le moteur rend le payload du § 6.2 — du JSON portant la citation, les
      // mentions et les identifiants. L'afficher tel quel mettrait tout ça sur
      // l'écran verrouillé. Défaut réel, corrigé le 2026-09-16.
      final service = _lire(swiftService);
      expect(service.contains('MlsPontNatif.resume(charge)'), isTrue,
          reason: 'le résumé doit passer par resume');
      expect(_lire(swiftPont).contains('static func chargeUtile('), isTrue,
          reason: 'le nom doit dire que ce ne sont pas des caractères');
    });
  });

  group("l'ABI C est déclarée pareil des deux côtés", () {
    /// Les noms de paramètres, dans l'ordre.
    List<String> parametres(String signature) => signature
        .split(',')
        .map((p) => RegExp(r'([A-Za-z_][A-Za-z0-9_]*)\s*(?:\:|$)')
            .firstMatch(p.trim().replaceAll(RegExp(r'\s+'), ' ')))
        .map((m) => m?.group(1) ?? '')
        .toList();

    test('mêmes paramètres, dans le même ordre', () {
      // Le lieur ne vérifie que le NOM du symbole, jamais les types : un
      // paramètre en trop passerait la compilation et corromprait la pile.
      final rust = _lire(ffi);
      final dRust = rust.indexOf('pub unsafe extern "C" fn diaspo_mls_apercu(');
      final sigRust = rust.substring(
        rust.indexOf('(', dRust) + 1,
        rust.indexOf(') -> c_int', dRust),
      );

      final h = _lire(entete);
      final dH = h.indexOf('int diaspo_mls_apercu(');
      final sigH = h.substring(h.indexOf('(', dH) + 1, h.indexOf(');', dH));

      final nomsRust =
          sigRust.split(',').map((p) => p.trim().split(':').first.trim());
      final nomsH = parametres(sigH)
          .map((p) => p)
          .where((p) => p.isNotEmpty)
          .toList();

      expect(nomsRust.where((n) => n.isNotEmpty).toList(), nomsH);
      expect(nomsH.length, 11,
          reason: 'onze paramètres : quatre chaînes, deux tampons, la sortie');
    });

    test('le code de tampon trop petit est le même', () {
      expect(_lire(ffi).contains('CODE_TAMPON_TROP_PETIT: c_int = -3'), isTrue);
      expect(_lire(swiftPont).contains('r.code == -3'), isTrue,
          reason: 'sinon un message long ne serait jamais affiché');
    });
  });

  group("l'extension est déclarée et peut être invoquée", () {
    test('Info.plist désigne le bon point d\'extension et la bonne classe', () {
      final p = _lire(infoPlist);
      expect(p.contains('com.apple.usernotifications.service'), isTrue);
      expect(
        p.contains(r'$(PRODUCT_MODULE_NAME).NotificationService'),
        isTrue,
        reason: 'sans le préfixe de module, iOS ne trouve pas la classe Swift',
      );
    });

    test('la version suit celle du Runner', () {
      // Une archive dont l'extension n'a pas exactement la version de l'app est
      // refusée par l'App Store — et ça ne se voit qu'à la soumission.
      final p = _lire(infoPlist);
      expect(p.contains(r'$(FLUTTER_BUILD_NAME)'), isTrue);
      expect(p.contains(r'$(FLUTTER_BUILD_NUMBER)'), isTrue);
    });

    test('le serveur pose mutable-content sur les messages MLS', () {
      // C'est la SEULE chose qui autorise iOS à invoquer l'extension. Sans ce
      // drapeau, tout le reste de ce dossier est inerte.
      final s = _lire(sendPush);
      expect(
        s.contains("dataMap.protocol === 'mls' && dataMap.mlsCiphertext"),
        isTrue,
      );
      expect(s.contains("aps['mutable-content'] = 1"), isTrue);
    });

    test('elle rend toujours un contenu, même à l\'expiration', () {
      // Ne rien rendre fait DISPARAÎTRE la notification : iOS n'affiche pas le
      // repli du serveur à la place.
      final s = _lire(swiftService);
      expect(s.contains('override func serviceExtensionTimeWillExpire()'),
          isTrue);
      expect(RegExp(r'contentHandler\(contenu\)').allMatches(s).length,
          greaterThanOrEqualTo(3),
          reason: 'chaque sortie anticipée doit rendre le contenu générique');
    });
  });
}
