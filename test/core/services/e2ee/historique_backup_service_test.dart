import 'dart:convert';
import 'dart:typed_data';

import 'package:diaspo_niger/core/services/cache_service.dart';
import 'package:diaspo_niger/core/services/e2ee/historique_backup_service.dart';
import 'package:diaspo_niger/core/services/e2ee/key_backup_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _msg(
  String id, {
  String contenu = 'bonjour',
  String type = 'text',
  String niveau = 'e2ee',
  String creeLe = '2026-10-01T10:00:00.000Z',
  Map<String, dynamic> en = const {},
}) => {
  'id': id,
  'content': contenu,
  'type': type,
  'encryptionLevel': niveau,
  'createdAt': creeLe,
  ...en,
};

void main() {
  const moi = 'uid-moi';

  group('selectionner : ce qui a le droit de quitter l\'appareil', () {
    test('garde le texte chiffré de bout en bout', () {
      final r = HistoriqueBackupService.selectionner({
        'c1': [_msg('a'), _msg('b')],
      }, moi);
      expect(r['c1']!.map((m) => m['id']), ['a', 'b']);
    });

    test('écarte médias, éphémères, supprimés et placeholders', () {
      final r = HistoriqueBackupService.selectionner({
        'c1': [
          _msg('ok'),
          _msg('image', type: 'image'),
          _msg('fichier', en: {'fileUrl': 'https://x/y'}),
          _msg('chiffre', en: {'mediaChiffre': {'k': 'v'}}),
          _msg('ephemere', en: {'expiresAt': '2026-10-02T10:00:00.000Z'}),
          _msg('pourTous', en: {'deletedForEveryone': true}),
          _msg('pourMoi', en: {'deletedFor': [moi]}),
          _msg('placeholder', contenu: '🔐 Message chiffré'),
          _msg('vide', contenu: ''),
        ],
      }, moi);
      expect(r['c1']!.map((m) => m['id']), ['ok']);
    });

    test('un message supprimé pour un AUTRE reste', () {
      final r = HistoriqueBackupService.selectionner({
        'c1': [_msg('a', en: {'deletedFor': ['uid-autre']})],
      }, moi);
      expect(r['c1'], hasLength(1));
    });

    test('le clair des discussions non chiffrées n\'est pas emporté', () {
      final r = HistoriqueBackupService.selectionner({
        'c1': [_msg('a', niveau: 'aes')],
      }, moi);
      expect(r, isEmpty);
    });

    test('une conversation sans rien à garder disparaît', () {
      final r = HistoriqueBackupService.selectionner({
        'c1': [_msg('a', type: 'image')],
        'c2': [_msg('b')],
      }, moi);
      expect(r.keys, ['c2']);
    });
  });

  group('enveloppe chiffrée', () {
    // Peu d'itérations : on teste la forme, pas le coût de PBKDF2.
    const iterations = 1000;
    final contenu = {
      'conversations': {
        'c1': [_msg('a', contenu: 'Salut, ça va ? éèà 🙂')],
      },
    };

    test('aller-retour avec la bonne passphrase', () async {
      final fichier = await HistoriqueBackupService.sceller(
        contenu,
        'une-passphrase',
        appareil: 'test',
        iterations: iterations,
      );
      final rendu = await HistoriqueBackupService.ouvrir(fichier, 'une-passphrase');
      expect(rendu, contenu);
    });

    test('le clair n\'apparaît nulle part dans le fichier', () async {
      final fichier = await HistoriqueBackupService.sceller(
        contenu,
        'une-passphrase',
        appareil: 'test',
        iterations: iterations,
      );
      final texte = utf8.decode(fichier);
      expect(texte, isNot(contains('Salut')));
      expect(texte, isNot(contains('uid-moi')));
    });

    test('mauvaise passphrase → PassphraseException', () async {
      final fichier = await HistoriqueBackupService.sceller(
        contenu,
        'une-passphrase',
        appareil: 'test',
        iterations: iterations,
      );
      await expectLater(
        HistoriqueBackupService.ouvrir(fichier, 'une-autre-passphrase'),
        throwsA(isA<PassphraseException>()),
      );
    });

    test('fichier altéré → PassphraseException', () async {
      final fichier = await HistoriqueBackupService.sceller(
        contenu,
        'une-passphrase',
        appareil: 'test',
        iterations: iterations,
      );
      final enveloppe = jsonDecode(utf8.decode(fichier)) as Map<String, dynamic>;
      final chiffre = base64Decode(enveloppe['ciphertext'] as String);
      chiffre[0] ^= 0xFF;
      enveloppe['ciphertext'] = base64Encode(chiffre);
      await expectLater(
        HistoriqueBackupService.ouvrir(
          Uint8List.fromList(utf8.encode(jsonEncode(enveloppe))),
          'une-passphrase',
        ),
        throwsA(isA<PassphraseException>()),
      );
    });

    test('un fichier qui n\'est pas une sauvegarde → PassphraseException', () async {
      await expectLater(
        HistoriqueBackupService.ouvrir(Uint8List.fromList(utf8.encode('pas du json')), 'x' * 8),
        throwsA(isA<PassphraseException>()),
      );
    });

    test('deux sauvegardes du même contenu diffèrent (sel et nonce neufs)', () async {
      final a = await HistoriqueBackupService.sceller(contenu, 'une-passphrase',
          appareil: 't', iterations: iterations);
      final b = await HistoriqueBackupService.sceller(contenu, 'une-passphrase',
          appareil: 't', iterations: iterations);
      expect(jsonDecode(utf8.decode(a))['salt'],
          isNot(jsonDecode(utf8.decode(b))['salt']));
    });
  });

  group('fusionner : une sauvegarde ne rétrécit jamais', () {
    test('un téléphone réinstallé (cache vide) garde tout l\'ancien', () {
      final r = HistoriqueBackupService.fusionner(
        ancien: {'c1': [_msg('a'), _msg('b')]},
        local: {},
        idsInterdits: {},
      );
      expect(r['c1']!.map((m) => m['id']), ['a', 'b']);
    });

    test('le cache local gagne sur l\'ancienne copie du même message', () {
      final r = HistoriqueBackupService.fusionner(
        ancien: {'c1': [_msg('a', contenu: 'avant')]},
        local: {'c1': [_msg('a', contenu: 'après modification')]},
        idsInterdits: {},
      );
      expect(r['c1'], hasLength(1));
      expect(r['c1']!.single['content'], 'après modification');
    });

    test('un message supprimé depuis ne survit pas dans l\'ancienne copie', () {
      final r = HistoriqueBackupService.fusionner(
        ancien: {'c1': [_msg('a'), _msg('supprime')]},
        local: {'c1': [_msg('a')]},
        idsInterdits: {'supprime'},
      );
      expect(r['c1']!.map((m) => m['id']), ['a']);
    });

    test('un message absent du cache (élagué) est conservé', () {
      final r = HistoriqueBackupService.fusionner(
        ancien: {'c1': [_msg('vieux')]},
        local: {'c1': [_msg('neuf', creeLe: '2026-10-02T10:00:00.000Z')]},
        idsInterdits: {},
      );
      expect(r['c1']!.map((m) => m['id']), ['vieux', 'neuf']);
    });

    test('le résultat est trié du plus ancien au plus récent', () {
      final r = HistoriqueBackupService.fusionner(
        ancien: {'c1': [_msg('b', creeLe: '2026-10-03T00:00:00.000Z')]},
        local: {'c1': [_msg('a', creeLe: '2026-10-01T00:00:00.000Z')]},
        idsInterdits: {},
      );
      expect(r['c1']!.map((m) => m['id']), ['a', 'b']);
    });
  });

  group('clé de récupération et activation', () {
    late HistoriqueBackupService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      service = HistoriqueBackupService(cache: CacheService.instance);
    });

    test('genererCle : six mots et un nombre, jamais deux fois la même', () {
      final a = HistoriqueBackupService.genererCle();
      final b = HistoriqueBackupService.genererCle();
      expect(a, matches(RegExp(r'^[a-z\-]+-\d\d$')));
      expect(a, isNot(b));
      expect(a.split('-').length, greaterThanOrEqualTo(7));
    });

    test('inactive par défaut', () async {
      expect(await service.estActive('u1'), isFalse);
    });

    test('activer : la clé rendue est celle qui est gardée', () async {
      final cle = await service.activer('u1');
      expect(await service.estActive('u1'), isTrue);
      expect(cle, isNotEmpty);
    });

    test('activer avec une clé donnée (restauration) la garde telle quelle', () async {
      expect(await service.activer('u1', cle: 'ma-cle-notee-42'), 'ma-cle-notee-42');
    });

    test('le drapeau seul ne suffit pas : sans clé, pas active', () async {
      // Téléphone restauré : les préférences reviennent, le Keystore non.
      SharedPreferences.setMockInitialValues({'historique_auto_u1': true});
      FlutterSecureStorage.setMockInitialValues({});
      expect(await service.estActive('u1'), isFalse);
    });

    test('désactiver oublie la clé', () async {
      await service.activer('u1');
      await service.desactiver('u1');
      expect(await service.estActive('u1'), isFalse);
    });

    test('un compte n\'active pas la sauvegarde d\'un autre', () async {
      await service.activer('u1');
      expect(await service.estActive('u2'), isFalse);
    });
  });

  group('ajusterALaTaille', () {
    Map<String, List<Map<String, dynamic>>> gros() => {
      'c1': [
        for (var i = 0; i < 400; i++)
          _msg(
            'm$i',
            // Du contenu peu compressible, pour que le gzip pèse vraiment.
            contenu: List.generate(40, (j) => (i * 7919 + j * 104729) % 9973)
                .join('-'),
            creeLe: DateTime.utc(2026, 1, 1)
                .add(Duration(hours: i))
                .toIso8601String(),
          ),
      ],
    };

    test('rend tout tel quel quand ça tient', () {
      final r = HistoriqueBackupService.ajusterALaTaille(gros());
      expect(r.tronque, isFalse);
      expect(r.retenu['c1'], hasLength(400));
    });

    test('retire les plus ANCIENS d\'abord, jamais les récents', () {
      final r = HistoriqueBackupService.ajusterALaTaille(gros(), tailleMax: 4000);
      expect(r.tronque, isTrue);
      final ids = r.retenu['c1']!.map((m) => m['id']).toList();
      expect(ids.length, lessThan(400));
      expect(ids.last, 'm399');
      expect(ids, isNot(contains('m0')));
    });
  });
}
