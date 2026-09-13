import 'dart:io';

import 'package:diaspo_niger/core/services/deep_link_service.dart';
import 'package:diaspo_niger/core/services/qr_code_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// Un lien Diaspo Niger lu dans une discussion doit s'ouvrir dans l'app.
///
/// Avant : la bulle d'aperçu passait par `DeepLinkService.parseDeepLink`, qui
/// ne connaissait ni `/feed/` ni `/embassies/`, et le texte d'un message ne
/// reconnaissait aucun lien du projet. Les deux partaient vers Android
/// (`launchUrl`), qui renvoyait le lien à l'app : boîte « Ouvrir ce lien ? »,
/// puis `router.go` à l'arrivée — la discussion sortait de la pile.
void main() {
  group('routeInterne — liens tels qu\'ils arrivent dans un message', () {
    const cas = <String, String>{
      'https://diasponiger.web.app/groups/grp-1': '/groups/grp-1',
      'https://diasponiger.com/feed/post-1': '/feed/post-1',
      'https://diasponiger.com/embassies/e-1': '/embassies/e-1',
      'https://www.diasponiger.com/events/ev-1': '/events/ev-1',
      'https://diasponiger.com/p/u/u-1': '/profile/u-1',
      'diasponiger://groups/grp-2': '/groups/grp-2',
      // Le texte d'un message porte souvent le lien sans schéma.
      'diasponiger.com/businesses/b-1': '/businesses/b-1',
      '  https://diasponiger.com/feed/post-2  ': '/feed/post-2',
    };
    cas.forEach((lien, route) {
      test(lien.trim(), () {
        expect(QrCodeParser.routeInterne(lien), route);
      });
    });

    test('site tiers → navigateur', () {
      expect(QrCodeParser.routeInterne('https://example.com/groups/x'), isNull);
      expect(
        QrCodeParser.routeInterne('https://diasponiger.com.piege.fr/feed/x'),
        isNull,
      );
    });

    test('page du site sans écran d\'app → navigateur', () {
      expect(
        QrCodeParser.routeInterne('https://diasponiger.com/telecharger'),
        isNull,
      );
      expect(QrCodeParser.routeInterne('https://diasponiger.com/'), isNull);
    });

    test('code court de profil : pas de route, pas de navigation', () {
      expect(
        QrCodeParser.routeInterne('https://diasponiger.com/p/XyZ789'),
        isNull,
      );
    });

    test('rendez-vous de transfert de clés : jamais une route', () {
      expect(QrCodeParser.routeInterne('dn-e2ee-transfer:1:a:b:c'), isNull);
      expect(QrCodeParser.routeInterne(''), isNull);
    });
  });

  group('chaque lien fabriqué par l\'app se relit en route', () {
    final s = DeepLinkService.instance;
    final cas = <String, String>{
      s.generateProfileLink('u-1'): '/profile/u-1',
      s.generatePostLink('post-1'): '/feed/post-1',
      s.generateGroupLink('grp-1'): '/groups/grp-1',
      s.generateEventLink('ev-1'): '/events/ev-1',
      s.generateBusinessLink('b-1'): '/businesses/b-1',
      s.generateProductLink('p-1'): '/marketplace/p-1',
      s.generateAudioRoomLink('r-1'): '/audio-rooms/r-1',
      s.generatePodcastLink('pod-1'): '/podcasts/pod-1',
      s.generateEpisodeLink('ep-1'): '/podcasts/episodes/ep-1',
      s.generateCallLink('call-1'): '/calls/call-1',
    };
    cas.forEach((lien, route) {
      test(lien, () => expect(QrCodeParser.routeInterne(lien), route));
    });
  });

  group('les deux lecteurs de liens d\'une discussion passent par routeInterne',
      () {
    String lire(String chemin) =>
        File(chemin).readAsStringSync().replaceAll('\r\n', '\n');

    test('carte d\'aperçu', () {
      final source = lire(
        'lib/features/messages/presentation/widgets/link_preview_bubble.dart',
      );
      expect(source, contains('QrCodeParser.routeInterne('));
      expect(source, isNot(contains('parseDeepLink')));
    });

    test('texte du message : la route interne AVANT la boîte de confirmation',
        () {
      final source = lire(
        'lib/features/messages/presentation/widgets/message_bubble.dart',
      );
      final debut = source.indexOf('case _LinkType.url:');
      final fin = source.indexOf('case _LinkType.phone:', debut);
      expect(debut, isNonNegative);
      final branche = source.substring(debut, fin);
      final route = branche.indexOf('QrCodeParser.routeInterne(');
      final boite = branche.indexOf('_showUrlConfirmDialog(');
      expect(route, isNonNegative);
      expect(boite, greaterThan(route));
    });
  });
}
