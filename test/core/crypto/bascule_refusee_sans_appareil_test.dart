import 'dart:io';

import 'package:diaspo_niger/core/crypto/mls/mls_conversation_service.dart';
import 'package:diaspo_niger/core/crypto/mls/mls_delivery.dart';
import 'package:diaspo_niger/core/crypto/mls/mls_device_registry.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ce que ces tests protègent (plan MLS § 2.3, § 5.4)
/// --------------------------------------------------
/// **Le défaut est mesuré, pas théorique.** Le 2026-09-15, deux conversations
/// à deux personnes avaient basculé en MLS avec **un seul appareil** dans
/// `conversation_devices` : celui de l'expéditeur. En face, personne n'avait
/// encore de ligne dans `mls_devices` — donc `reconcileMembership` ne trouvait
/// personne à ajouter, `aAjouter` était vide, et **rien n'était journalisé**.
/// Huit messages sont partis chiffrés pour un groupe d'une personne, et
/// l'autre ne les lira jamais : MLS ne redonne pas le secret d'un epoch passé.
///
/// Poser `mls_since` est irréversible — le serveur refuse le clair ensuite.
/// La vérification doit donc précéder la création du groupe, pas la suivre.
///
/// Ce que ces tests empêchent : qu'on bascule une conversation dont un
/// participant ne peut rien déchiffrer, que le refus soit muet, et que la
/// garde glisse APRÈS la création — auquel cas elle ne servirait à rien.

class _Transport extends MlsDelivery {
  _Transport({required this.participants, required this.avecAppareil})
      : super(ensureAuth: (() async => true));

  final List<String> participants;

  /// Les identifiants qui ont au moins un appareil actif.
  final Set<String> avecAppareil;

  final List<String> diagnostics = [];

  @override
  Future<Map<String, dynamic>?> conversation(String conversationId) async => {
        'id': conversationId,
        'type': 'individual',
        'participant_ids': participants,
        'mls_since': null,
      };

  @override
  Future<List<MlsDeviceRecord>> activeDevicesOf(String userId) async =>
      avecAppareil.contains(userId)
          ? [
              MlsDeviceRecord.fromRow({
                'id': '11111111-1111-1111-1111-111111111111',
                'user_id': userId,
                'stable_id': 's',
                'name': 'un téléphone',
                'platform': 'android',
                'mls_identity': '$userId:1',
                'created_at': '2026-09-15T00:00:00Z',
                'last_seen_at': '2026-09-15T00:00:00Z',
              })
            ]
          : const [];

  @override
  Future<void> diagnostic(
    String userId,
    String event, {
    String? deviceId,
    Map<String, dynamic>? detail,
  }) async {
    diagnostics.add(event);
  }
}

MlsConversationService _service(_Transport transport) =>
    MlsConversationService(
      userId: 'moi',
      moteur: () => throw StateError('le moteur ne doit pas être demandé'),
      delivery: transport,
      appareil: () => throw StateError('inutile ici'),
      lireMemo: (_) async => null,
      ecrireMemo: (_, __) async {},
    );

String _source(String chemin) =>
    File(chemin).readAsStringSync().replaceAll('\r\n', '\n');

void main() {
  group('refuserSiQuelquUnNePeutPasSuivre', () {
    test('refuse quand le seul autre participant n\'a aucun appareil',
        () async {
      final t = _Transport(
        participants: const ['moi', 'lautre'],
        avecAppareil: const {'moi'},
      );

      await expectLater(
        _service(t).refuserSiQuelquUnNePeutPasSuivre('c1'),
        throwsA(isA<MlsParticipantSansAppareil>()),
      );
      // Et le refus se voit : c'est exactement ce qui manquait.
      expect(t.diagnostics, contains('bascule_refusee_sans_appareil'));
    });

    test('laisse passer quand tout le monde a un appareil', () async {
      final t = _Transport(
        participants: const ['moi', 'lautre'],
        avecAppareil: const {'moi', 'lautre'},
      );
      await _service(t).refuserSiQuelquUnNePeutPasSuivre('c1');
      expect(t.diagnostics, isEmpty);
    });

    test('une conversation avec soi-même bascule toujours', () async {
      // « Mes notes » : aucun autre participant, donc personne à couper.
      final t = _Transport(
        participants: const ['moi'],
        avecAppareil: const {'moi'},
      );
      await _service(t).refuserSiQuelquUnNePeutPasSuivre('c1');
      expect(t.diagnostics, isEmpty);
    });

    test('mon propre compte sans appareil ne bloque pas', () async {
      // Le cas ne devrait pas arriver — on vient de s'inscrire — mais se
      // bloquer soi-même serait absurde.
      final t = _Transport(
        participants: const ['moi', 'lautre'],
        avecAppareil: const {'lautre'},
      );
      await _service(t).refuserSiQuelquUnNePeutPasSuivre('c1');
      expect(t.diagnostics, isEmpty);
    });

    test('un groupe refuse dès qu\'UN membre ne peut pas suivre', () async {
      final t = _Transport(
        participants: const ['moi', 'a', 'b', 'c'],
        avecAppareil: const {'moi', 'a', 'c'},
      );
      await expectLater(
        _service(t).refuserSiQuelquUnNePeutPasSuivre('c1'),
        throwsA(isA<MlsParticipantSansAppareil>()),
      );
    });
  });

  group('câblage', () {
    test('la garde précède la création du groupe', () {
      // Poser `mls_since` est irréversible. Une garde placée après ne
      // protégerait plus rien — elle constaterait le dégât.
      final src = _source('lib/core/crypto/mls/mls_conversation_service.dart');
      final garde = src.indexOf('await refuserSiQuelquUnNePeutPasSuivre(');
      final creation = src.indexOf('await moteur.creerGroupe(');
      final marquage = src.indexOf('await _delivery.marquerMlsSince(');

      expect(garde, isNonNegative, reason: 'la garde doit être appelée');
      expect(creation, isNonNegative);
      expect(marquage, isNonNegative);
      expect(garde, lessThan(creation));
      expect(garde, lessThan(marquage));
    });
  });
}
