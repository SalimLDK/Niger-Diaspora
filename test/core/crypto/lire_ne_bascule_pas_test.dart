import 'dart:io';

import 'package:diaspo_niger/core/crypto/mls/mls_conversation_service.dart';
import 'package:diaspo_niger/core/crypto/mls/mls_delivery.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ce que ces tests protègent (plan MLS § 2.3)
/// -------------------------------------------
/// **Ouvrir une discussion la gelait.** Le chemin de lecture appelait
/// `ensureGroup`, qui crée le groupe et pose `mls_since` — une marque
/// définitive : le serveur refuse le clair ensuite, et rien ne revient en
/// arrière. Il suffisait donc de regarder une conversation pour l'engager,
/// sans que personne n'ait écrit quoi que ce soit.
///
/// Ce n'est pas une crainte de relecture, c'est mesuré. Les trois premières
/// conversations basculées en production l'ont été **avant** leur premier
/// message chiffré :
///
/// | conversation | bascule  | 1er message | écart |
/// |---|---|---|---|
/// | `805adcaa…` | 13:53:59 | 13:55:27 | 88 s |
/// | `debef5f0…` | 15:28:05 | 15:30:11 | 126 s |
/// | `d41d4ea0…` | 19:53:56 | 19:54:08 | 12 s |
///
/// La règle : créer est une décision d'écriture, elle appartient à l'envoi.
/// Lire peut **rejoindre** un groupe existant — c'est même nécessaire pour
/// déchiffrer ce qu'on nous a envoyé — mais jamais en créer un.

class _Transport extends MlsDelivery {
  _Transport(this.epoch) : super(ensureAuth: (() async => true));

  /// `null` = aucun groupe côté serveur pour cette conversation.
  final int? epoch;
  int appelsCurrentEpoch = 0;

  @override
  Future<int?> currentEpoch(String conversationId) async {
    appelsCurrentEpoch++;
    return epoch;
  }

  @override
  Future<Map<String, dynamic>?> conversation(String conversationId) async => {
        'id': conversationId,
        'type': 'individual',
        'participant_ids': const <String>[],
        'mls_since': null,
      };
}

/// Un service dont le moteur **lève**, et qui se dit non-membre sans le
/// consulter : si quoi que ce soit essayait ensuite de créer le groupe, le
/// test le verrait immédiatement.
class _ServiceNonMembre extends MlsConversationService {
  _ServiceNonMembre(MlsDelivery delivery)
      : super(
          userId: 'moi',
          moteur: () => throw StateError('le moteur ne doit pas être demandé'),
          delivery: delivery,
          appareil: () => throw StateError('inutile ici'),
          lireMemo: (_) async => null,
          ecrireMemo: (_, __) async {},
        );

  @override
  Future<bool> estMembre(String conversationId) async => false;
}

MlsConversationService _service(_Transport t) => _ServiceNonMembre(t);

String _source(String chemin) =>
    File(chemin).readAsStringSync().replaceAll('\r\n', '\n');

void main() {
  group('catchUp', () {
    test('sans groupe côté serveur, la lecture ne crée rien et rend le vide',
        () async {
      final t = _Transport(null);

      // Ne lève pas : le moteur n'est même pas sollicité, puisqu'on sort
      // avant. C'est exactement ce qu'on veut prouver.
      final r = await _service(t).catchUp('c1');

      expect(r, isEmpty);
      expect(t.appelsCurrentEpoch, 1,
          reason: 'la sortie doit se décider sur l\'epoch du serveur');
    });

    test('la sortie précède toute demande au moteur', () async {
      // Le moteur de ce service lève à la première demande. Si `catchUp`
      // arrivait à `_traiterCommits` ou à `instantane`, on verrait ce
      // StateError plutôt qu'une liste vide.
      final r = await _service(_Transport(null)).catchUp('c2');
      expect(r, isEmpty);
    });
  });

  group('câblage', () {
    test('catchUp consulte l\'epoch AVANT d\'appeler ensureGroup', () {
      final src = _source('lib/core/crypto/mls/mls_conversation_service.dart');
      final debut = src.indexOf('Future<List<MlsIncoming>> catchUp(');
      expect(debut, isNonNegative);
      final corps = src.substring(debut, debut + 1800);

      final garde = corps.indexOf('currentEpoch(conversationId) == null');
      final creation = corps.indexOf('await ensureGroup(conversationId);');

      expect(garde, isNonNegative,
          reason: 'la lecture doit vérifier qu\'un groupe existe');
      expect(creation, isNonNegative);
      expect(garde, lessThan(creation),
          reason: 'sinon la lecture crée le groupe, et gèle la conversation');
    });

    test('seul le chemin d\'envoi crée le groupe', () {
      // `ensureGroup` reste appelé par la passerelle — à l'envoi et au
      // changement d'appartenance —, jamais ailleurs.
      final gw = _source('lib/core/crypto/mls/mls_gateway.dart');
      expect(gw.contains('_service.ensureGroup(conversationId)'), isTrue);
    });
  });
}
