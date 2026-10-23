import 'dart:convert';
import 'dart:typed_data';

import 'package:diaspo_niger/core/services/cache_service.dart';
import 'package:diaspo_niger/core/services/e2ee/historique_backup_service.dart';
import 'package:diaspo_niger/core/services/e2ee/key_backup_service.dart';
import 'package:flutter_test/flutter_test.dart';

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
    final service = HistoriqueBackupService(cache: CacheService.instance);
    // Peu d'itérations : on teste la forme, pas le coût de PBKDF2.
    const iterations = 1000;
    final contenu = {
      'conversations': {
        'c1': [_msg('a', contenu: 'Salut, ça va ? éèà 🙂')],
      },
    };

    test('aller-retour avec la bonne passphrase', () async {
      final fichier = await service.sceller(
        contenu,
        'une-passphrase',
        appareil: 'test',
        iterations: iterations,
      );
      final rendu = await service.ouvrir(fichier, 'une-passphrase');
      expect(rendu, contenu);
    });

    test('le clair n\'apparaît nulle part dans le fichier', () async {
      final fichier = await service.sceller(
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
      final fichier = await service.sceller(
        contenu,
        'une-passphrase',
        appareil: 'test',
        iterations: iterations,
      );
      await expectLater(
        service.ouvrir(fichier, 'une-autre-passphrase'),
        throwsA(isA<PassphraseException>()),
      );
    });

    test('fichier altéré → PassphraseException', () async {
      final fichier = await service.sceller(
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
        service.ouvrir(
          Uint8List.fromList(utf8.encode(jsonEncode(enveloppe))),
          'une-passphrase',
        ),
        throwsA(isA<PassphraseException>()),
      );
    });

    test('un fichier qui n\'est pas une sauvegarde → PassphraseException', () async {
      await expectLater(
        service.ouvrir(Uint8List.fromList(utf8.encode('pas du json')), 'x' * 8),
        throwsA(isA<PassphraseException>()),
      );
    });

    test('deux sauvegardes du même contenu diffèrent (sel et nonce neufs)', () async {
      final a = await service.sceller(contenu, 'une-passphrase',
          appareil: 't', iterations: iterations);
      final b = await service.sceller(contenu, 'une-passphrase',
          appareil: 't', iterations: iterations);
      expect(jsonDecode(utf8.decode(a))['salt'],
          isNot(jsonDecode(utf8.decode(b))['salt']));
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
