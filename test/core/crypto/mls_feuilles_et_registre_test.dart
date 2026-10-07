import 'dart:typed_data';

import 'package:diaspo_niger/core/crypto/mls/mls_conversation_service.dart';
import 'package:diaspo_niger/core/crypto/mls/mls_delivery.dart';
import 'package:diaspo_niger/core/crypto/mls/mls_device_registry.dart';
import 'package:diaspo_niger/src/rust/api/mls.dart';
import 'package:flutter_test/flutter_test.dart';

/// Une feuille du groupe est l'appareil qu'elle prétend être — par sa CLÉ.
///
/// L'identité d'une feuille MLS (`BasicCredential`) n'est qu'une chaîne
/// déclarée, `uid:stable_id`. La réconciliation des membres comparait les
/// feuilles au registre d'appareils par cette seule chaîne : n'importe quel
/// participant — ou le serveur — pouvait faire entrer une feuille au nom de
/// Bob avec sa propre clé. Elle passait pour l'appareil de Bob, lisait tout,
/// et le code de sécurité de Bob, calculé sur la clé du registre, restait
/// « vérifié ». Désormais la clé de chaque feuille (exposée par le moteur
/// Rust) est comparée à celle du registre ; une feuille d'une autre clé sort.
void main() {
  final cleMoi = Uint8List.fromList(List.filled(32, 1));
  final cleBob = Uint8List.fromList(List.filled(32, 2));
  final cleIntruse = Uint8List.fromList(List.filled(32, 9));

  MlsDeviceRecord appareil(String identite, Uint8List cle, {String? id}) =>
      MlsDeviceRecord(
        id: id ?? identite,
        userId: identite.split(':').first,
        stableId: identite.split(':').last,
        name: identite,
        platform: 'android',
        mlsIdentity: identite,
        signatureKey: cle,
        createdAt: DateTime.utc(2026, 9, 16),
        lastSeenAt: DateTime.utc(2026, 10, 7),
      );
  MembreDto feuille(int i, String identite, Uint8List cle) =>
      MembreDto(leafIndex: i, identity: identite, signatureKey: cle);

  final moi = appareil('u1:s1', cleMoi);
  final bob = appareil('u2:b1', cleBob);

  group('trierFeuilles', () {
    test('la bonne clé : membre fiable, rien à retirer', () {
      final r = MlsConversationService.trierFeuilles(
        membres: [feuille(0, 'u1:s1', cleMoi), feuille(1, 'u2:b1', cleBob)],
        actifs: [moi, bob],
        moi: moi,
      );
      expect(r.fiables, {'u1:s1', 'u2:b1'});
      expect(r.aRetirer, isEmpty);
      expect(r.usurpatrices, isEmpty);
    });

    test('l\'identité de Bob avec une autre clé : retirée, Bob à ajouter', () {
      final r = MlsConversationService.trierFeuilles(
        membres: [feuille(0, 'u1:s1', cleMoi), feuille(1, 'u2:b1', cleIntruse)],
        actifs: [moi, bob],
        moi: moi,
      );
      expect(r.aRetirer, [1]);
      expect(r.usurpatrices.map((m) => m.leafIndex), [1]);
      expect(r.fiables.contains('u2:b1'), isFalse,
          reason: 'le vrai appareil de Bob doit entrer');
    });

    test('la vraie et l\'usurpatrice côte à côte : seule l\'intruse sort', () {
      // Une table indexée sur l'identité gardait l'une des deux, au hasard
      // de l'ordre : l'autre devenait invisible.
      final r = MlsConversationService.trierFeuilles(
        membres: [
          feuille(0, 'u1:s1', cleMoi),
          feuille(1, 'u2:b1', cleBob),
          feuille(2, 'u2:b1', cleIntruse),
        ],
        actifs: [moi, bob],
        moi: moi,
      );
      expect(r.aRetirer, [2]);
      expect(r.fiables, contains('u2:b1'));
    });

    test('registre sans clé (ligne ancienne) : rien à conclure', () {
      final r = MlsConversationService.trierFeuilles(
        membres: [feuille(0, 'u1:s1', cleMoi), feuille(1, 'u2:b1', cleIntruse)],
        actifs: [moi, appareil('u2:b1', Uint8List(0))],
        moi: moi,
      );
      expect(r.aRetirer, isEmpty);
    });

    test('appareil plus actif : retiré, sans être traité d\'usurpateur', () {
      final r = MlsConversationService.trierFeuilles(
        membres: [feuille(0, 'u1:s1', cleMoi), feuille(1, 'u2:ancien', cleBob)],
        actifs: [moi, bob],
        moi: moi,
      );
      expect(r.aRetirer, [1]);
      expect(r.usurpatrices, isEmpty);
    });

    test('seule à mon nom, une feuille n\'est jamais retirée', () {
      // Fiche de registre périmée : c'est moi quand même — on ne se retire
      // pas soi-même.
      final r = MlsConversationService.trierFeuilles(
        membres: [feuille(0, 'u1:s1', cleIntruse)],
        actifs: [moi],
        moi: moi,
      );
      expect(r.aRetirer, isEmpty);
    });

    test('une seconde feuille à mon nom, d\'une autre clé : retirée', () {
      final r = MlsConversationService.trierFeuilles(
        membres: [feuille(0, 'u1:s1', cleMoi), feuille(1, 'u1:s1', cleIntruse)],
        actifs: [moi],
        moi: moi,
      );
      expect(r.aRetirer, [1]);
      expect(r.usurpatrices.map((m) => m.leafIndex), [1]);
    });
  });

  test('réconciliation : l\'usurpatrice est retirée, et c\'est journalisé',
      () async {
    final moteur = _Moteur([
      feuille(0, 'u1:s1', cleMoi),
      feuille(1, 'u2:b1', cleIntruse),
    ]);
    final transport = _Transport([moi], {'u2': [bob]});
    final service = MlsConversationService(
      userId: 'u1',
      moteur: () async => moteur,
      delivery: transport,
      appareil: () async => moi,
      lireMemo: (_) async => null,
      ecrireMemo: (_, __) async {},
    );

    await service.reconcileMembership('c1');

    expect(transport.evenements, contains('feuille_cle_etrangere'));
    expect(moteur.retraits, [
      [1],
    ]);
    expect(transport.paquetsReclames, ['u2:b1'],
        reason: 'le vrai appareil de Bob est invité');
  });
}

class _Moteur implements Moteur {
  _Moteur(this.membres);

  List<MembreDto> membres;
  final retraits = <List<int>>[];
  int epoch = 2;

  @override
  Future<InstantaneDto> instantane({required String conversationId}) async =>
      InstantaneDto(epoch: BigInt.from(epoch), membres: membres);

  @override
  Future<CommitDto> retirerMembres({
    required String conversationId,
    required List<int> leafIndices,
    required List<int> aad,
  }) async {
    retraits.add(leafIndices);
    return CommitDto(commit: Uint8List.fromList([9]));
  }

  @override
  Future<InstantaneDto> fusionnerCommitEnAttente({
    required String conversationId,
  }) async {
    epoch++;
    return instantane(conversationId: conversationId);
  }

  @override
  Future<void> jeterCommitEnAttente({required String conversationId}) async {}

  @override
  Future<Uint8List> exporterGroupInfo({required String conversationId}) async =>
      Uint8List(0);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Transport extends MlsDelivery {
  _Transport(this.miens, this.autres) : super(ensureAuth: () async => true);

  final List<MlsDeviceRecord> miens;
  final Map<String, List<MlsDeviceRecord>> autres;
  final evenements = <String>[];
  final paquetsReclames = <String>[];

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
  }) async {}

  @override
  Future<Map<String, dynamic>?> conversation(String conversationId) async => {
        'id': conversationId,
        'type': 'individual',
        'participant_ids': const ['u1', 'u2'],
        'mls_since': '2026-09-15T00:00:00Z',
      };

  @override
  Future<List<MlsDeviceRecord>> activeDevicesOf(String userId) async =>
      userId == 'u1' ? miens : (autres[userId] ?? const []);

  @override
  Future<MlsKeyPackageClaim?> claimKeyPackage(String deviceId) async {
    paquetsReclames.add(deviceId);
    return null;
  }

  @override
  Future<void> upsertConversationDevice(
    String conversationId,
    String deviceId,
    String status, {
    int? epochAdded,
    int? epochRemoved,
  }) async {}

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
