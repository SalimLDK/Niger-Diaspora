import 'dart:async';
import 'dart:typed_data';

import 'package:diaspo_niger/core/crypto/mls/mls_conversation_service.dart';
import 'package:diaspo_niger/core/crypto/mls/mls_delivery.dart';
import 'package:diaspo_niger/core/crypto/mls/mls_device_registry.dart';
import 'package:diaspo_niger/src/rust/api/mls.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mon propre commit, accepté par le serveur, mais jamais fusionné chez moi.
///
/// Deux portes y menaient :
///  · la réponse à la publication se perd (délai dépassé) alors que l'INSERT
///    a eu lieu — `_publierOuJeter` jetait le commit en attente ;
///  · l'app est tuée entre la publication et la fusion.
/// Dans les deux cas le serveur est à N+1, l'appareil à N, et
/// `_traiterCommits` SAUTAIT tout commit de cet appareil : MLS ne rejoue pas
/// ses propres commits. Plus rien ne se déchiffrait — `epoch_futur`,
/// `commit_manquant`, pour toujours.
void main() {
  group('au rattrapage', () {
    test('mon commit publié mais pas fusionné est fusionné, et la suite passe',
        () async {
      final moteur = _Moteur(epoch: 2, enAttente: true);
      final transport = _Transport(commits: [
        _commit(3, 'moi'),
        _commit(4, 'autre'),
      ]);

      await _service(moteur, transport).catchUp('c1');

      expect(moteur.epoch, 4, reason: 'le mien fusionné, puis celui de l\'autre');
      expect(transport.evenements, contains('propre_commit_fusionne_au_rattrapage'));
      expect(transport.evenements, isNot(contains('commit_manquant')));
    });

    test('plus rien en attente : dit « orphelin » au lieu de se taire',
        () async {
      final moteur = _Moteur(epoch: 2, enAttente: false);
      final transport = _Transport(commits: [
        _commit(3, 'moi'),
        _commit(4, 'autre'),
      ]);

      await _service(moteur, transport).catchUp('c1');

      expect(moteur.epoch, 2);
      expect(moteur.entrantsTraites, 0,
          reason: 'le commit 4 ne se traite pas par-dessus un trou');
      expect(transport.evenements, contains('propre_commit_orphelin'));
    });
  });

  group('à la publication', () {
    test('réponse perdue mais commit reçu : fusionné, pas jeté', () async {
      final moteur = _Moteur(epoch: 2, enAttente: false, fantome: true);
      final transport = _Transport(
        commits: const [],
        publicationPerdue: true,
      );

      await _service(moteur, transport).reconcileMembership('c1');

      expect(moteur.jete, isFalse, reason: 'le serveur l\'a : le jeter désynchronise');
      expect(moteur.epoch, 3);
      expect(transport.evenements, contains('commit_publie_reponse_perdue'));
    });

    test('vrai échec (rien au serveur) : jeté, et l\'erreur remonte', () async {
      final moteur = _Moteur(epoch: 2, enAttente: false, fantome: true);
      final transport = _Transport(
        commits: const [],
        publicationPerdue: true,
        serveurARecu: false,
      );

      await expectLater(
        _service(moteur, transport).reconcileMembership('c1'),
        throwsA(isA<TimeoutException>()),
      );
      expect(moteur.jete, isTrue);
      expect(moteur.epoch, 2);
    });
  });
}

MlsConversationService _service(_Moteur moteur, _Transport transport) =>
    MlsConversationService(
      userId: 'u1',
      moteur: () async => moteur,
      delivery: transport,
      appareil: () async => _appareil,
      lireMemo: (_) async => null,
      ecrireMemo: (_, __) async {},
    );

final _appareil = MlsDeviceRecord(
  id: 'moi',
  userId: 'u1',
  stableId: 'stable-1',
  name: 'Pixel de test',
  platform: 'android',
  mlsIdentity: 'u1:stable-1',
  createdAt: DateTime.utc(2026, 9, 16),
  lastSeenAt: DateTime.utc(2026, 9, 17),
);

final _octetsDuRetrait = Uint8List.fromList([7, 7, 7]);

MlsCommitRow _commit(int epoch, String appareil) => MlsCommitRow(
      conversationId: 'c1',
      epoch: epoch,
      senderDeviceId: appareil,
      commit: Uint8List.fromList([epoch]),
      createdAt: DateTime.utc(2026, 10, 4),
    );

class _Moteur implements Moteur {
  _Moteur({required this.epoch, required this.enAttente, this.fantome = false});

  int epoch;
  bool enAttente;

  /// Un membre de l'arbre qui n'est plus un appareil actif : à retirer.
  final bool fantome;
  bool jete = false;
  int entrantsTraites = 0;

  @override
  Future<InstantaneDto> instantane({required String conversationId}) async =>
      InstantaneDto(epoch: BigInt.from(epoch), membres: [
        MembreDto(leafIndex: 0, identity: 'u1:stable-1', signatureKey: Uint8List(0)),
        if (fantome) MembreDto(leafIndex: 1, identity: 'u1:ancienne-install', signatureKey: Uint8List(0)),
      ]);

  @override
  Future<InstantaneDto> fusionnerCommitEnAttente({
    required String conversationId,
  }) async {
    // OpenMLS : sans commit en attente, la fusion ne fait rien.
    if (enAttente) {
      epoch++;
      enAttente = false;
    }
    return instantane(conversationId: conversationId);
  }

  @override
  Future<void> jeterCommitEnAttente({required String conversationId}) async {
    jete = true;
    enAttente = false;
  }

  @override
  Future<EntrantDto> traiterEntrant({
    required String conversationId,
    required List<int> message,
    required List<int> aadAttendu,
  }) async {
    entrantsTraites++;
    epoch++;
    return EntrantDto.commit(
      instantane: await instantane(conversationId: conversationId),
    );
  }

  @override
  Future<CommitDto> retirerMembres({
    required String conversationId,
    required List<int> leafIndices,
    required List<int> aad,
  }) async {
    enAttente = true;
    return CommitDto(commit: _octetsDuRetrait);
  }

  @override
  Future<Uint8List> exporterGroupInfo({required String conversationId}) async =>
      Uint8List(0);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Transport extends MlsDelivery {
  _Transport({
    required this.commits,
    this.publicationPerdue = false,
    this.serveurARecu = true,
  }) : super(ensureAuth: () async => true);

  final List<MlsCommitRow> commits;
  final bool publicationPerdue;
  final bool serveurARecu;
  final evenements = <String>[];
  final _publies = <MlsCommitRow>[];

  @override
  Future<void> diagnostic(
    String userId,
    String event, {
    String? deviceId,
    Map<String, dynamic>? detail,
  }) async =>
      evenements.add(event);

  @override
  Future<List<MlsCommitRow>> commitsAfter(String conversationId, int epoch) async =>
      [...commits, ..._publies].where((c) => c.epoch > epoch).toList();

  @override
  Future<void> publishCommit({
    required String conversationId,
    required int epoch,
    required String senderDeviceId,
    required Uint8List commit,
    Uint8List? groupInfo,
  }) async {
    if (serveurARecu) {
      _publies.add(MlsCommitRow(
        conversationId: conversationId,
        epoch: epoch,
        senderDeviceId: senderDeviceId,
        commit: commit,
        createdAt: DateTime.utc(2026, 10, 4),
      ));
    }
    if (publicationPerdue) throw TimeoutException('réponse perdue');
  }

  @override
  Future<Map<String, dynamic>?> conversation(String conversationId) async => {
        'id': conversationId,
        'type': 'individual',
        'participant_ids': const ['u1'],
        'mls_since': '2026-09-15T00:00:00Z',
      };

  @override
  Future<List<MlsDeviceRecord>> activeDevicesOf(String userId) async =>
      [_appareil];

  @override
  Future<void> publierGroupInfo(String conversationId, Uint8List groupInfo) async {}

  @override
  Future<List<MlsMessageRow>> messagesAfter(
    String conversationId,
    DateTime? after, {
    int limit = 200,
  }) async =>
      const [];

  @override
  Future<List<MlsWelcomeRow>> welcomesFor(
    String deviceId, {
    String? conversationId,
  }) async =>
      const [];
}
