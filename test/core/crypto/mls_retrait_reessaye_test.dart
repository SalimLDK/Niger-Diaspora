import 'dart:typed_data';

import 'package:diaspo_niger/core/crypto/mls/mls_conversation_service.dart';
import 'package:diaspo_niger/core/crypto/mls/mls_delivery.dart';
import 'package:diaspo_niger/core/crypto/mls/mls_device_registry.dart';
import 'package:diaspo_niger/src/rust/api/mls.dart';
import 'package:flutter_test/flutter_test.dart';

/// Un retrait de membre raté se retente — un téléphone volé n'attend plus le
/// redémarrage de l'app pour sortir du groupe.
///
/// Après un seul échec du moteur, `_retraitsEchoues` interdisait tout
/// nouveau retrait pour la durée du processus. Ce qui restait dans l'arbre
/// pouvait être un appareil révoqué, qui continuait de recevoir tout ce qui
/// s'écrivait. Désormais : au plus une tentative par
/// `delaiAvantNouveauRetrait`, et l'échec s'oublie au premier succès.
void main() {
  test('échec, puis silence pendant le délai, puis nouvelle tentative',
      () async {
    var horloge = DateTime.utc(2026, 10, 4, 9);
    final moteur = _Moteur(echecsAvantSucces: 1);
    final transport = _Transport();
    final service = MlsConversationService(
      userId: 'u1',
      moteur: () async => moteur,
      delivery: transport,
      appareil: () async => _appareil,
      lireMemo: (_) async => null,
      ecrireMemo: (_, __) async {},
      maintenant: () => horloge,
    );

    await service.reconcileMembership('c1');
    expect(moteur.tentatives, 1);
    expect(transport.publies, isEmpty);
    expect(transport.evenements, contains('retrait_membres_echoue'));

    horloge = horloge.add(const Duration(minutes: 1));
    await service.reconcileMembership('c1');
    expect(moteur.tentatives, 1, reason: 'pas de martèlement');

    horloge = horloge.add(MlsConversationService.delaiAvantNouveauRetrait);
    await service.reconcileMembership('c1');
    expect(moteur.tentatives, 2, reason: 'retenté une fois le délai passé');
    expect(transport.publies, [3], reason: 'le commit de retrait est parti');
  });
}

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

class _Moteur implements Moteur {
  _Moteur({required this.echecsAvantSucces});

  int echecsAvantSucces;
  int tentatives = 0;
  int epoch = 2;
  bool retire = false;
  bool enAttente = false;

  @override
  Future<InstantaneDto> instantane({required String conversationId}) async =>
      InstantaneDto(epoch: BigInt.from(epoch), membres: [
        MembreDto(leafIndex: 0, identity: 'u1:stable-1', signatureKey: Uint8List(0)),
        // Le téléphone révoqué : plus parmi les appareils actifs.
        if (!retire) MembreDto(leafIndex: 1, identity: 'u1:telephone-vole', signatureKey: Uint8List(0)),
      ]);

  @override
  Future<CommitDto> retirerMembres({
    required String conversationId,
    required List<int> leafIndices,
    required List<int> aad,
  }) async {
    tentatives++;
    if (echecsAvantSucces > 0) {
      echecsAvantSucces--;
      throw StateError('openmls:RemoveMembersError');
    }
    enAttente = true;
    return CommitDto(commit: Uint8List.fromList([9]));
  }

  @override
  Future<InstantaneDto> fusionnerCommitEnAttente({
    required String conversationId,
  }) async {
    if (enAttente) {
      epoch++;
      retire = true;
      enAttente = false;
    }
    return instantane(conversationId: conversationId);
  }

  @override
  Future<void> jeterCommitEnAttente({required String conversationId}) async {
    enAttente = false;
  }

  @override
  Future<Uint8List> exporterGroupInfo({required String conversationId}) async =>
      Uint8List(0);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Transport extends MlsDelivery {
  _Transport() : super(ensureAuth: () async => true);

  final evenements = <String>[];
  final publies = <int>[];

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
      const [];

  @override
  Future<void> publishCommit({
    required String conversationId,
    required int epoch,
    required String senderDeviceId,
    required Uint8List commit,
    Uint8List? groupInfo,
  }) async =>
      publies.add(epoch);

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
