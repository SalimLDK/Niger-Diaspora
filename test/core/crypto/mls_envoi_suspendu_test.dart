import 'dart:typed_data';

import 'package:diaspo_niger/core/crypto/mls/mls_conversation_service.dart';
import 'package:diaspo_niger/core/crypto/mls/mls_delivery.dart';
import 'package:diaspo_niger/core/crypto/mls/mls_device_registry.dart';
import 'package:diaspo_niger/src/rust/api/mls.dart';
import 'package:flutter_test/flutter_test.dart';

/// Un appareil révoqué encore dans le groupe suspend l'envoi — sans impasse.
///
/// Révoquer un appareil (un téléphone volé) le retire du groupe au prochain
/// envoi. Mais si ce retrait échouait, le message partait quand même, chiffré
/// AUSSI pour lui : la révocation n'empêchait pas ce qu'elle doit empêcher.
///
/// Le choix : idéaliste sur ce qu'on SAIT dangereux — un appareil révoqué ou
/// une feuille à clé étrangère ne reçoit jamais un message de plus ; réaliste
/// sur le reste — une ancienne installation simplement inactive ne bloque
/// rien, un registre illisible non plus, et la suspension n'est pas une
/// impasse : le retrait est retenté à chaque envoi, sans le délai de dix
/// minutes, et le bandeau « chiffrement bloqué » propose la reconstruction.
void main() {
  final cleMoi = Uint8List.fromList(List.filled(32, 1));
  final cleBob = Uint8List.fromList(List.filled(32, 2));
  final cleIntruse = Uint8List.fromList(List.filled(32, 9));

  MlsDeviceRecord appareil(String identite, Uint8List cle) => MlsDeviceRecord(
        id: identite,
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

  ({MlsConversationService service, _Moteur moteur, _Transport transport})
      monter({
    required List<MembreDto> membres,
    int echecs = 0,
    Set<String>? revoquees = const {},
  }) {
    final moteur = _Moteur(membres, echecs: echecs);
    final transport = _Transport([moi], {'u2': [bob]}, revoquees: revoquees);
    final service = MlsConversationService(
      userId: 'u1',
      moteur: () async => moteur,
      delivery: transport,
      appareil: () async => moi,
      lireMemo: (_) async => null,
      ecrireMemo: (_, __) async {},
    );
    return (service: service, moteur: moteur, transport: transport);
  }

  test('appareil révoqué, retrait raté : envoi suspendu, et ça se voit',
      () async {
    final t = monter(
      membres: [
        feuille(0, 'u1:s1', cleMoi),
        feuille(1, 'u2:b1', cleBob),
        feuille(2, 'u2:vole', cleIntruse),
      ],
      echecs: 1,
      revoquees: {'u2:vole'},
    );
    final signaux = <String>[];
    final abonnement = t.service.blocages.listen(signaux.add);
    addTearDown(abonnement.cancel);

    await expectLater(t.service.reconcileMembership('c1'),
        throwsA(isA<MlsEnvoiSuspendu>()));
    await Future<void>.delayed(Duration.zero);

    expect(t.service.estBloquee('c1'), isTrue);
    expect(signaux, ['c1']);
    expect(t.transport.evenements, contains('envoi_suspendu'));
  });

  test('retenté au prochain envoi, sans attendre : la suspension tombe',
      () async {
    final t = monter(
      membres: [
        feuille(0, 'u1:s1', cleMoi),
        feuille(1, 'u2:b1', cleBob),
        feuille(2, 'u2:vole', cleIntruse),
      ],
      echecs: 1,
      revoquees: {'u2:vole'},
    );
    await expectLater(t.service.reconcileMembership('c1'),
        throwsA(isA<MlsEnvoiSuspendu>()));

    // Aussitôt — bien en deçà de `delaiAvantNouveauRetrait`.
    await t.service.reconcileMembership('c1');

    expect(t.moteur.retraits, hasLength(2));
    expect(t.service.estBloquee('c1'), isFalse);
  });

  test('feuille à clé étrangère, retrait raté : suspendu aussi', () async {
    final t = monter(
      membres: [feuille(0, 'u1:s1', cleMoi), feuille(1, 'u2:b1', cleIntruse)],
      echecs: 1,
    );
    await expectLater(t.service.reconcileMembership('c1'),
        throwsA(isA<MlsEnvoiSuspendu>()));
  });

  test('ancienne installation inactive, retrait raté : l\'envoi part', () async {
    final t = monter(
      membres: [
        feuille(0, 'u1:s1', cleMoi),
        feuille(1, 'u2:b1', cleBob),
        feuille(2, 'u2:ancienne', cleIntruse),
      ],
      echecs: 1,
    );
    await t.service.reconcileMembership('c1');
    expect(t.service.estBloquee('c1'), isFalse);
  });

  test('registre des révoqués illisible : on ne bloque pas sur un doute',
      () async {
    final t = monter(
      membres: [
        feuille(0, 'u1:s1', cleMoi),
        feuille(1, 'u2:b1', cleBob),
        feuille(2, 'u2:vole', cleIntruse),
      ],
      echecs: 1,
      revoquees: null,
    );
    await t.service.reconcileMembership('c1');
    expect(t.service.estBloquee('c1'), isFalse);
    expect(t.transport.evenements, contains('revoques_illisibles'));
  });
}

class _Moteur implements Moteur {
  _Moteur(this.membres, {this.echecs = 0});

  List<MembreDto> membres;
  final retraits = <List<int>>[];
  int epoch = 2;

  /// Retraits à faire échouer avant le premier qui réussit.
  int echecs;
  List<int>? enAttente;

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
    if (echecs > 0) {
      echecs--;
      throw StateError('openmls:RemoveMembersError');
    }
    enAttente = leafIndices;
    return CommitDto(commit: Uint8List.fromList([9]));
  }

  @override
  Future<InstantaneDto> fusionnerCommitEnAttente({
    required String conversationId,
  }) async {
    final partis = enAttente;
    if (partis != null) {
      membres = [for (final m in membres) if (!partis.contains(m.leafIndex)) m];
      enAttente = null;
    }
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
  _Transport(this.miens, this.autres, {this.revoquees = const {}})
      : super(ensureAuth: () async => true);

  final List<MlsDeviceRecord> miens;
  final Map<String, List<MlsDeviceRecord>> autres;

  /// `null` : le registre des révoqués est illisible.
  Set<String>? revoquees;

  @override
  Future<Set<String>> identitesRevoquees(List<String> userIds) async {
    final r = revoquees;
    if (r == null) throw StateError('réseau');
    return r;
  }
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
