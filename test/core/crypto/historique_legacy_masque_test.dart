import 'dart:io';

import 'package:diaspo_niger/core/crypto/mls/mls_base_neuve.dart';
import 'package:diaspo_niger/core/crypto/mls/mls_conversation_service.dart';
import 'package:diaspo_niger/core/crypto/mls/mls_delivery.dart';
import 'package:diaspo_niger/core/crypto/mls/mls_gateway.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ce que ces tests protègent
/// --------------------------
/// Après une réinstallation, l'ancien historique d'une discussion passée à MLS
/// (gelé, lisible par le serveur) revenait en haut du fil alors que les
/// messages MLS d'avant l'arrivée sont masqués : un fil à moitié rempli, puis
/// un trou. Une installation neuve repart de zéro dans ces discussions — mais
/// SEULEMENT dans celles qui avaient déjà basculé quand elle est née. Un
/// appareil qui n'a rien réinstallé, ou une discussion qui bascule plus tard,
/// garde tout.

class _TransportFige extends MlsDelivery {
  _TransportFige(this.mlsSince) : super(ensureAuth: (() async => true));

  final String? mlsSince;

  @override
  Future<Map<String, dynamic>?> conversation(String conversationId) async => {
    'id': conversationId,
    'type': 'group',
    'participant_ids': <String>[],
    'mls_since': mlsSince,
  };
}

class _ServiceCompteur extends MlsConversationService {
  _ServiceCompteur({this.echoue = false})
    : super(
        userId: 'u1',
        moteur: () => throw StateError('le moteur ne doit pas être demandé'),
        delivery: _TransportFige(null),
        appareil: () => throw StateError('inutile ici'),
      );

  final bool echoue;
  int ouvertures = 0;

  @override
  Future<void> ouvrirMoteur() async {
    ouvertures++;
    if (echoue) throw StateError('Rust ne démarre pas');
  }
}

MlsGateway _passerelle(_ServiceCompteur service, {String? mlsSince}) =>
    MlsGateway(
      userId: 'u1',
      actif: () => true,
      service: service,
      delivery: _TransportFige(mlsSince),
    );

void main() {
  final bascule = DateTime.utc(2026, 9, 15);

  group('legacyDoitEtreMasque : la règle', () {
    test('base née après la bascule → masqué', () {
      expect(
        legacyDoitEtreMasque(
          baseNeuve: DateTime.utc(2026, 10, 1),
          mlsSince: bascule,
        ),
        isTrue,
      );
    });

    test('bascule survenue APRÈS la naissance de la base → visible', () {
      expect(
        legacyDoitEtreMasque(
          baseNeuve: DateTime.utc(2026, 9, 1),
          mlsSince: bascule,
        ),
        isFalse,
      );
    });

    test('pas de repère (installation d\'avant ce changement) → visible', () {
      expect(
        legacyDoitEtreMasque(baseNeuve: null, mlsSince: bascule),
        isFalse,
      );
    });

    test('discussion pas passée à MLS → visible', () {
      expect(
        legacyDoitEtreMasque(
          baseNeuve: DateTime.utc(2026, 10, 1),
          mlsSince: null,
        ),
        isFalse,
      );
    });
  });

  group('repère de base neuve', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('absent par défaut', () async {
      expect(await baseNeuveDepuis('u1'), isNull);
    });

    test('posé, relu à la seconde près', () async {
      final date = DateTime.utc(2026, 10, 22, 8, 30, 15);
      await marquerBaseNeuve('u1', maintenant: date);
      expect(await baseNeuveDepuis('u1'), date);
    });

    test('propre à chaque compte du téléphone', () async {
      await marquerBaseNeuve('u1', maintenant: DateTime.utc(2026, 10, 22));
      expect(await baseNeuveDepuis('u2'), isNull);
    });

    test('une mémoire en panne ne lève jamais', () async {
      Future<SharedPreferences> panne() async => throw StateError('disque');
      await marquerBaseNeuve('u1', preferences: panne);
      expect(await baseNeuveDepuis('u1', preferences: panne), isNull);
    });
  });

  group('MlsGateway.historiqueLegacyMasque', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('discussion non basculée : faux, sans même ouvrir le moteur', () async {
      final service = _ServiceCompteur();
      expect(
        await _passerelle(service).historiqueLegacyMasque('c1'),
        isFalse,
      );
      expect(service.ouvertures, 0);
    });

    test('installation neuve après la bascule : vrai, moteur ouvert d\'abord', () async {
      await marquerBaseNeuve('u1', maintenant: DateTime.utc(2026, 10, 1));
      final service = _ServiceCompteur();
      final passerelle = _passerelle(service, mlsSince: '2026-09-15T00:00:00Z');
      expect(await passerelle.historiqueLegacyMasque('c1'), isTrue);
      expect(service.ouvertures, 1);
    });

    test('installation d\'avant la bascule : faux', () async {
      await marquerBaseNeuve('u1', maintenant: DateTime.utc(2026, 9, 1));
      final passerelle = _passerelle(
        _ServiceCompteur(),
        mlsSince: '2026-09-15T00:00:00Z',
      );
      expect(await passerelle.historiqueLegacyMasque('c1'), isFalse);
    });

    test('moteur qui ne s\'ouvre pas : l\'historique reste visible', () async {
      await marquerBaseNeuve('u1', maintenant: DateTime.utc(2026, 10, 1));
      final passerelle = _passerelle(
        _ServiceCompteur(echoue: true),
        mlsSince: '2026-09-15T00:00:00Z',
      );
      expect(await passerelle.historiqueLegacyMasque('c1'), isFalse);
    });
  });

  group('câblage', () {
    String source(String chemin) =>
        File(chemin).readAsStringSync().replaceAll('\r\n', '\n');

    test('le moteur pose le repère avant d\'ouvrir une base absente ou vide', () {
      final s = source('lib/core/crypto/mls/mls_engine_provider.dart');
      expect(s, contains('marquerBaseNeuve(userId)'));
      expect(s, contains('length() == 0'));
      expect(
        s.indexOf('marquerBaseNeuve(userId)'),
        lessThan(s.indexOf('Moteur.ouvrir(')),
      );
    });

    test('le dépôt ne met pas en cache l\'historique masqué', () {
      final s = source(
        'lib/features/messages/data/repositories/message_repository_impl.dart',
      );
      expect(s, contains('final masque = await _historiqueLegacyMasque(conversationId);'));
      expect(s, contains('if (!masque) {'));
      expect(s, contains('hasMore: masque ? false : hasMore'));
    });
  });
}
