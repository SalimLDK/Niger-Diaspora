import 'dart:typed_data';

import 'package:diaspo_niger/core/crypto/mls/mls_conversation_service.dart';
import 'package:diaspo_niger/core/crypto/mls/mls_delivery.dart';
import 'package:diaspo_niger/core/crypto/mls/mls_device_registry.dart';
import 'package:diaspo_niger/core/crypto/mls/mls_payload_codec.dart';
import 'package:diaspo_niger/src/rust/api/mls.dart';
import 'package:flutter_test/flutter_test.dart';

/// De retour après plus de trois commits, les messages d'avant restent
/// lisibles.
///
/// `catchUp` appliquait TOUS les commits avant le moindre message. Le moteur
/// ne garde les secrets que des trois derniers epochs (`MAX_PAST_EPOCHS = 3`,
/// rust/src/engine.rs) : un membre revenu après cinq commits — une arrivée
/// dans un groupe ouvert en fait un — trouvait les messages d'avant en
/// `decrypt_failed`, et le curseur passait dessus. Perdus.
///
/// Le moteur factice applique la même fenêtre : un message se déchiffre si
/// son epoch est entre `epoch local − 3` et `epoch local`.
void main() {
  test('cinq commits plus tard, les messages d\'avant se lisent encore',
      () async {
    final moteur = _Moteur(epoch: 2);
    final transport = _Transport(
      commits: [for (var e = 3; e <= 7; e++) _commit(e)],
      messages: [
        _message('ancien-1', epoch: 2, minute: 1),
        _message('ancien-2', epoch: 2, minute: 2),
        _message('recent', epoch: 7, minute: 30),
      ],
    );

    final lus = await _service(moteur, transport).catchUp('c1');

    expect(
      {for (final e in lus) e.row.id: e.erreur},
      {'ancien-1': null, 'ancien-2': null, 'recent': null},
      reason: 'aucun decrypt_failed',
    );
    expect(transport.evenements, isNot(contains('decrypt_failed')));
    expect(moteur.epoch, 7, reason: 'à la fin, tous les commits sont appliqués');
  });

  test('sans message à lire, tous les commits s\'appliquent', () async {
    final moteur = _Moteur(epoch: 2);
    final transport = _Transport(
      commits: [for (var e = 3; e <= 7; e++) _commit(e)],
      messages: const [],
    );

    await _service(moteur, transport).catchUp('c1');

    expect(moteur.epoch, 7);
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

final _t0 = DateTime.utc(2026, 10, 4, 8);

MlsCommitRow _commit(int epoch) => MlsCommitRow(
      conversationId: 'c1',
      epoch: epoch,
      senderDeviceId: 'autre',
      commit: Uint8List.fromList([0, epoch]),
      createdAt: _t0.add(Duration(minutes: 10 + epoch)),
    );

MlsMessageRow _message(String id, {required int epoch, required int minute}) =>
    MlsMessageRow(
      id: id,
      conversationId: 'c1',
      senderId: 'u2',
      senderDeviceId: 'autre',
      epoch: epoch,
      kind: 'content',
      contentType: 'text',
      // Premier octet 1 : un message ; son epoch en second.
      ciphertext: Uint8List.fromList([1, epoch]),
      createdAt: _t0.add(Duration(minutes: minute)),
    );

class _Moteur implements Moteur {
  _Moteur({required this.epoch});

  int epoch;

  @override
  Future<InstantaneDto> instantane({required String conversationId}) async =>
      InstantaneDto(epoch: BigInt.from(epoch), membres: [
        MembreDto(leafIndex: 0, identity: 'u1:stable-1', signatureKey: Uint8List(0)),
      ]);

  @override
  Future<EntrantDto> traiterEntrant({
    required String conversationId,
    required List<int> message,
    required List<int> aadAttendu,
  }) async {
    if (message.first == 0) {
      // Un commit : l'epoch suivant.
      epoch = message[1];
      return EntrantDto.commit(
        instantane: await instantane(conversationId: conversationId),
      );
    }
    final epochMessage = message[1];
    // La fenêtre du vrai moteur : trois epochs passés, pas plus.
    if (epochMessage < epoch - 3 || epochMessage > epoch) {
      throw StateError('openmls:SecretTreeError');
    }
    return EntrantDto.application(
      clair: MlsPayload(
        id: '',
        type: 'text',
        sentAt: 0,
        body: const {'content': 'bonjour'},
      ).encode(),
      emetteur: 'u2:telephone',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Transport extends MlsDelivery {
  _Transport({required this.commits, required this.messages})
      : super(ensureAuth: () async => true);

  final List<MlsCommitRow> commits;
  final List<MlsMessageRow> messages;
  final evenements = <String>[];

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
      commits.where((c) => c.epoch > epoch).toList();

  @override
  Future<List<MlsMessageRow>> messagesAfter(
    String conversationId,
    DateTime? after, {
    int limit = 200,
  }) async =>
      messages.where((m) => after == null || m.createdAt.isAfter(after)).toList();

  @override
  Future<List<MlsWelcomeRow>> welcomesFor(
    String deviceId, {
    String? conversationId,
  }) async =>
      const [];
}
