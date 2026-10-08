import 'dart:typed_data';

import 'package:diaspo_niger/core/crypto/mls/mls_conversation_service.dart';
import 'package:diaspo_niger/core/crypto/mls/mls_delivery.dart';
import 'package:diaspo_niger/core/crypto/mls/mls_device_registry.dart';
import 'package:diaspo_niger/core/crypto/mls/mls_payload_codec.dart';
import 'package:diaspo_niger/src/rust/api/mls.dart';
import 'package:flutter_test/flutter_test.dart';

/// L'auteur affiché d'un message chiffré est celui que MLS a authentifié.
///
/// L'app prenait l'auteur sur la ligne `mls_messages`, inscrit par le
/// serveur. L'AAD lie bien `sender_device_id` au chiffré — mais c'est
/// l'émetteur qui la compose : un membre pouvait chiffrer en désignant
/// l'appareil de Bob, et un serveur complice publier la ligne au nom de Bob.
/// Le moteur rend désormais l'identité de la credential vérifiée par MLS
/// (banc Rust `l_emetteur_est_celui_que_mls_authentifie`) ; ce qui ne
/// concorde pas avec la ligne ne s'affiche pas.
void main() {
  group('emetteurConforme', () {
    test('uid:stable de l\'auteur de la ligne', () {
      expect(MlsConversationService.emetteurConforme('u2:tel', 'u2'), isTrue);
    });
    test('un autre compte', () {
      expect(MlsConversationService.emetteurConforme('u3:tel', 'u2'), isFalse);
    });
    test('un uid qui en préfixe un autre', () {
      expect(MlsConversationService.emetteurConforme('u22:tel', 'u2'), isFalse);
    });
    test('émetteur ou auteur vide', () {
      expect(MlsConversationService.emetteurConforme('', 'u2'), isFalse);
      expect(MlsConversationService.emetteurConforme('u2:tel', ''), isFalse);
    });
  });

  for (final (emetteur, conforme) in [('u2:tel', true), ('u3:tel', false)]) {
    test('rattrapage : émetteur $emetteur, ligne au nom de u2', () async {
      final transport = _Transport();
      final service = MlsConversationService(
        userId: 'u1',
        moteur: () async => _Moteur(emetteur),
        delivery: transport,
        appareil: () async => _appareil,
        lireMemo: (_) async => null,
        ecrireMemo: (_, __) async {},
      );

      final recus = await service.catchUp('c1');

      expect(recus, hasLength(1));
      if (conforme) {
        expect(recus.single.payload?.texte, 'bonjour');
      } else {
        expect(recus.single.payload, isNull);
        expect(recus.single.erreur, 'auteur_usurpe');
        expect(transport.evenements, contains('auteur_usurpe'));
      }
    });
  }
}

final _appareil = MlsDeviceRecord(
  id: 'moi',
  userId: 'u1',
  stableId: 's1',
  name: 'Pixel',
  platform: 'android',
  mlsIdentity: 'u1:s1',
  createdAt: DateTime.utc(2026, 9, 16),
  lastSeenAt: DateTime.utc(2026, 10, 8),
);

class _Moteur implements Moteur {
  _Moteur(this.emetteur);

  final String emetteur;

  @override
  Future<InstantaneDto> instantane({required String conversationId}) async =>
      InstantaneDto(epoch: BigInt.from(1), membres: [
        MembreDto(leafIndex: 0, identity: 'u1:s1', signatureKey: Uint8List(0)),
      ]);

  @override
  Future<EntrantDto> traiterEntrant({
    required String conversationId,
    required List<int> message,
    required List<int> aadAttendu,
  }) async =>
      EntrantDto.application(
        clair: MlsPayload(
          id: '',
          type: 'text',
          sentAt: 0,
          body: const {'content': 'bonjour'},
        ).encode(),
        emetteur: emetteur,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Transport extends MlsDelivery {
  _Transport() : super(ensureAuth: () async => true);

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
  Future<DateTime?> reconstruitLe(String conversationId) async => null;

  @override
  Future<int?> currentEpoch(String conversationId) async => 1;

  @override
  Future<List<MlsCommitRow>> commitsAfter(String conversationId, int epoch) async =>
      const [];

  @override
  Future<List<MlsMessageRow>> messagesAfter(
    String conversationId,
    DateTime? after, {
    int limit = 200,
  }) async =>
      [
        MlsMessageRow(
          id: 'm1',
          conversationId: conversationId,
          senderId: 'u2',
          senderDeviceId: 'appareil-de-u2',
          epoch: 1,
          kind: 'content',
          contentType: 'text',
          ciphertext: Uint8List.fromList([1]),
          createdAt: DateTime.utc(2026, 10, 8, 9),
        ),
      ];

  @override
  Future<List<MlsWelcomeRow>> welcomesFor(
    String deviceId, {
    String? conversationId,
  }) async =>
      const [];
}
