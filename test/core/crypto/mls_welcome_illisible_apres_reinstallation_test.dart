import 'dart:typed_data';

import 'package:diaspo_niger/core/crypto/mls/mls_conversation_service.dart';
import 'package:diaspo_niger/core/crypto/mls/mls_delivery.dart';
import 'package:diaspo_niger/core/crypto/mls/mls_device_registry.dart';
import 'package:diaspo_niger/src/rust/api/mls.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ce que ce test protège
/// -----------------------
/// Trouvé le 2026-09-21 sur le Pixel, réinstallé la veille : la discussion
/// 1:1 avec Sim A comptait 3 messages « non lus » que l'écran n'affichait
/// jamais, sans une ligne dans `mls_diagnostics`.
///
/// Deux Welcome du 17/09 attendaient cet appareil. Ils visaient les
/// KeyPackages de l'installation d'avant, dont les secrets sont partis avec
/// l'ancienne base : `traiterWelcome` échouait, et l'exception sortait de
/// `_ensureGroup` avant la jointure externe — précisément le chemin prévu
/// pour reprendre sa place après une réinstallation.
///
/// Un Welcome illisible doit être journalisé puis dépassé, jamais bloquer ;
/// et il ne doit pas être marqué consommé (un échec passager brûlerait une
/// invitation valide).

class _MoteurReinstalle implements Moteur {
  /// `null` = aucun groupe local : la base a été recréée.
  int? epoch;

  int welcomesTentes = 0;
  bool jointureExterne = false;

  @override
  Future<InstantaneDto> instantane({required String conversationId}) async {
    final e = epoch;
    if (e == null) throw StateError('group_unknown');
    return InstantaneDto(epoch: BigInt.from(e), membres: const []);
  }

  @override
  Future<InstantaneDto> traiterWelcome({
    required String conversationId,
    required List<int> welcome,
  }) async {
    welcomesTentes++;
    throw StateError('openmls:NoMatchingKeyPackage');
  }

  @override
  Future<CommitDto> rejoindreParCommitExterne({
    required String conversationId,
    required List<int> groupInfo,
    required List<int> aad,
  }) async {
    jointureExterne = true;
    epoch = 17;
    return CommitDto(commit: Uint8List(1), groupInfo: Uint8List(1));
  }

  @override
  Future<Uint8List> exporterGroupInfo({required String conversationId}) async =>
      Uint8List(1);

  @override
  Future<EntrantDto> traiterEntrant({
    required String conversationId,
    required List<int> message,
    required List<int> aadAttendu,
  }) =>
      _interdit('traiterEntrant');

  @override
  Future<void> oublierGroupe({required String conversationId}) async {
    epoch = null;
  }

  @override
  void dispose() {}

  @override
  bool get isDisposed => false;

  Never _interdit(String nom) =>
      throw StateError('$nom : ne doit pas être appelé dans ce test');

  @override
  Future<CommitDto> ajouterMembres({
    required String conversationId,
    required List<Uint8List> keyPackages,
    required List<int> aad,
  }) =>
      _interdit('ajouterMembres');

  @override
  Future<Uint8List> chiffrer({
    required String conversationId,
    required List<int> clair,
    required List<int> aad,
  }) =>
      _interdit('chiffrer');

  @override
  Uint8List cleSignaturePublique() => _interdit('cleSignaturePublique');

  @override
  Uint8List credential() => _interdit('credential');

  @override
  Future<InstantaneDto> creerGroupe({required String conversationId}) =>
      _interdit('creerGroupe');

  @override
  Future<List<Uint8List>> creerKeyPackages({
    required int n,
    required bool dernierRecours,
  }) =>
      _interdit('creerKeyPackages');

  @override
  Future<InstantaneDto> fusionnerCommitEnAttente({
    required String conversationId,
  }) =>
      _interdit('fusionnerCommitEnAttente');

  @override
  String identite() => _interdit('identite');

  @override
  Future<void> jeterCommitEnAttente({required String conversationId}) =>
      _interdit('jeterCommitEnAttente');

  @override
  Future<CommitDto> retirerMembres({
    required String conversationId,
    required List<int> leafIndices,
    required List<int> aad,
  }) =>
      _interdit('retirerMembres');
}

class _TransportReinstalle extends MlsDelivery {
  _TransportReinstalle() : super(ensureAuth: () async => true);

  final diagnostics = <Map<String, Object?>>[];
  final welcomesConsommes = <String>[];
  final commitsPublies = <int>[];

  @override
  Future<void> diagnostic(
    String userId,
    String event, {
    String? deviceId,
    Map<String, dynamic>? detail,
  }) async {
    diagnostics.add({'event': event, 'deviceId': deviceId, 'detail': detail});
  }

  @override
  Future<int?> currentEpoch(String conversationId) async =>
      commitsPublies.isEmpty ? 16 : commitsPublies.last;

  @override
  Future<Map<String, dynamic>?> conversation(String conversationId) async => {
        'id': conversationId,
        'type': 'individual',
        'participant_ids': ['u1', 'u2'],
      };

  @override
  Future<bool> aEuUnAppareilDans(String conversationId, String userId) async => true;

  @override
  Future<Uint8List?> groupInfo(String conversationId) async => Uint8List(1);

  @override
  Future<void> publishCommit({
    required String conversationId,
    required int epoch,
    required String senderDeviceId,
    required Uint8List commit,
    Uint8List? groupInfo,
  }) async {
    commitsPublies.add(epoch);
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
  Future<List<MlsCommitRow>> commitsAfter(String conversationId, int epoch) async =>
      const [];

  // Les deux Welcome du 17/09 (epochs 13 et 15), jamais consommés.
  @override
  Future<List<MlsWelcomeRow>> welcomesFor(
    String deviceId, {
    String? conversationId,
  }) async =>
      [
        for (final e in [13, 15])
          MlsWelcomeRow(
            id: 'welcome-$e',
            conversationId: conversationId ?? 'c1',
            recipientDeviceId: deviceId,
            epoch: e,
            welcome: Uint8List(0),
          ),
      ];

  @override
  Future<void> markWelcomeConsumed(String id) async {
    welcomesConsommes.add(id);
  }

  @override
  Future<List<MlsMessageRow>> messagesAfter(
    String conversationId,
    DateTime? after, {
    int limit = 200,
  }) async =>
      const [];
}

MlsDeviceRecord _appareil() => MlsDeviceRecord(
      id: 'moi',
      userId: 'u1',
      stableId: 'stable-1',
      name: 'Pixel réinstallé',
      platform: 'android',
      mlsIdentity: 'u1:stable-1',
      createdAt: DateTime.utc(2026, 9, 16),
      lastSeenAt: DateTime.utc(2026, 9, 21),
    );

void main() {
  test(
      'des Welcome illisibles après une réinstallation ne bloquent pas : '
      'journalisés, laissés en attente, puis jointure externe', () async {
    final moteur = _MoteurReinstalle();
    final delivery = _TransportReinstalle();
    final service = MlsConversationService(
      userId: 'u1',
      moteur: () async => moteur,
      delivery: delivery,
      appareil: () async => _appareil(),
      lireMemo: (_) async => null,
      ecrireMemo: (_, __) async {},
    );

    await service.catchUp('c1');

    expect(moteur.welcomesTentes, 2, reason: 'chaque Welcome est essayé une fois');
    expect(delivery.welcomesConsommes, isEmpty,
        reason: 'un Welcome qui ne s\'ouvre pas ne doit pas être brûlé');
    expect(moteur.jointureExterne, isTrue,
        reason: 'la reprise de sa propre place doit être atteinte');
    expect(delivery.commitsPublies, [17]);
    expect(moteur.epoch, 17);

    final illisibles = delivery.diagnostics
        .where((d) => d['event'] == 'welcome_illisible')
        .map((d) => (d['detail'] as Map)['epoch'])
        .toList();
    expect(illisibles, [15, 13], reason: 'du plus récent au plus ancien');
  });
}
