import 'package:diaspo_niger/core/services/qr_code_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le scanner de l'accueil est le seul point d'entrée QR de l'app : ce qu'il
/// ne sait pas lire n'est lisible nulle part. Ces cas fixent donc, un par un,
/// les QR que le projet fabrique ou partage.
void main() {
  group('QrCodeParser — QR fabriqués par l\'app', () {
    test('profil, lien long', () {
      final target = QrCodeParser.parse('https://diasponiger.com/p/u/abc123');
      expect(target?.kind, QrCodeKind.profile);
      expect(target?.routePath, '/profile/abc123');
    });

    test('profil, code court à résoudre', () {
      final target = QrCodeParser.parse('https://diasponiger.com/p/XyZ789');
      expect(target?.kind, QrCodeKind.profileShortCode);
      expect(target?.shortCode, 'XyZ789');
      expect(target?.routePath, isNull);
    });

    test('groupe — l\'hôte du .env, que l\'ancien scanner refusait', () {
      final target = QrCodeParser.parse(
        'https://diasponiger.web.app/groups/grp-1',
      );
      expect(target?.kind, QrCodeKind.group);
      expect(target?.routePath, '/groups/grp-1');
    });

    test('transfert de clés E2EE', () {
      final target = QrCodeParser.parse(
        'dn-e2ee-transfer:1:rdv-1:user-1:' 'AAAAAAAAAAAAAAAAAAAAAA',
      );
      expect(target?.kind, QrCodeKind.keyTransfer);
      expect(target?.routePath, isNull);
    });
  });

  group('QrCodeParser — liens profonds du site', () {
    const cas = <String, (QrCodeKind, String)>{
      'https://diasponiger.com/feed/post-1': (QrCodeKind.post, '/feed/post-1'),
      'https://diasponiger.com/events/ev-1': (
        QrCodeKind.event,
        '/events/ev-1',
      ),
      'https://diasponiger.com/businesses/b-1': (
        QrCodeKind.business,
        '/businesses/b-1',
      ),
      'https://diasponiger.com/marketplace/p-1': (
        QrCodeKind.product,
        '/marketplace/p-1',
      ),
      'https://diasponiger.com/embassies/e-1': (
        QrCodeKind.embassy,
        '/embassies/e-1',
      ),
      'https://diasponiger.com/audio-rooms/r-1': (
        QrCodeKind.audioRoom,
        '/audio-rooms/r-1',
      ),
      'https://diasponiger.com/podcasts/pod-1': (
        QrCodeKind.podcast,
        '/podcasts/pod-1',
      ),
      'https://diasponiger.com/podcasts/episodes/ep-1': (
        QrCodeKind.episode,
        '/podcasts/episodes/ep-1',
      ),
      'https://diasponiger.com/calls/call-1': (
        QrCodeKind.call,
        '/calls/call-1',
      ),
      'https://diasponiger.com/g/grp-2': (QrCodeKind.group, '/groups/grp-2'),
      'https://diasponiger.com/profile/u-2': (
        QrCodeKind.profile,
        '/profile/u-2',
      ),
    };

    cas.forEach((url, attendu) {
      test(url, () {
        final target = QrCodeParser.parse(url);
        expect(target?.kind, attendu.$1);
        expect(target?.routePath, attendu.$2);
      });
    });

    test('l\'épisode passe avant le podcast', () {
      // `/podcasts/episodes/<id>` lu comme un podcast nommé « episodes »
      // ouvrirait une fiche vide, sans erreur.
      final target = QrCodeParser.parse(
        'https://diasponiger.com/podcasts/episodes/ep-2',
      );
      expect(target?.kind, QrCodeKind.episode);
    });

    test('schéma maison diasponiger://', () {
      final target = QrCodeParser.parse('diasponiger://groups/grp-3');
      expect(target?.kind, QrCodeKind.group);
      expect(target?.routePath, '/groups/grp-3');
    });
  });

  group('QrCodeParser — refus', () {
    test('hôte qui ressemble sans en être un', () {
      // L'ancien scanner faisait un `contains` sur l'hôte : celui-ci passait.
      expect(
        QrCodeParser.parse('https://diasponiger.com.piege.example/p/u/abc'),
        isNull,
      );
    });

    test('site tiers', () {
      expect(QrCodeParser.parse('https://example.com/groups/g'), isNull);
    });

    test('texte libre', () {
      expect(QrCodeParser.parse('bonjour'), isNull);
      expect(QrCodeParser.parse('   '), isNull);
    });

    test('chemin du projet sans destination connue', () {
      expect(QrCodeParser.parse('https://diasponiger.com/'), isNull);
      expect(QrCodeParser.parse('https://diasponiger.com/inconnu/1'), isNull);
    });

    test('identifiant manquant', () {
      expect(QrCodeParser.parse('https://diasponiger.com/groups'), isNull);
      expect(QrCodeParser.parse('https://diasponiger.com/p/u'), isNull);
    });

    test('identifiant hors charset', () {
      expect(
        QrCodeParser.parse('https://diasponiger.com/groups/..%2Fadmin'),
        isNull,
      );
    });
  });
}
