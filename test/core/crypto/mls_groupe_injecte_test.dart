import 'dart:typed_data';

import 'package:diaspo_niger/core/crypto/mls/mls_conversation_service.dart';
import 'package:diaspo_niger/core/crypto/mls/mls_delivery.dart';
import 'package:diaspo_niger/core/crypto/mls/mls_device_registry.dart';
import 'package:diaspo_niger/src/rust/api/mls.dart';
import 'package:flutter_test/flutter_test.dart';

/// Un groupe qu'on rejoint est contrôlé avant d'être accepté (M8).
///
/// N'importe quel participant peut déposer un Welcome pour un appareil
/// (policy « emis par un participant »), et l'arbre public
/// (`mls_group_info`) est écrit par les participants. Un groupe fabriqué
/// s'ouvrait aussi bien qu'un vrai, et l'appareil s'y installait comme dans
/// celui de la conversation. Il est désormais refusé s'il contient une
/// feuille qui se fait passer pour un appareil actif (autre clé), ou un epoch
/// au-delà de la chaîne du serveur. Le compte d'un participant qui vient de
/// partir n'est PAS un motif : le Welcome d'un arrivant porte légitimement sa
/// feuille, pas encore retirée.
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
        lastSeenAt: DateTime.utc(2026, 10, 8),
      );
  MembreDto feuille(int i, String identite, Uint8List cle) =>
      MembreDto(leafIndex: i, identity: identite, signatureKey: cle);

  final moi = appareil('u1:s1', cleMoi);
  final bob = appareil('u2:b1', cleBob);

  MlsConversationService service(_Moteur moteur, _Transport transport) =>
      MlsConversationService(
        userId: 'u1',
        moteur: () async => moteur,
        delivery: transport,
        appareil: () async => moi,
        lireMemo: (_) async => null,
        ecrireMemo: (_, __) async {},
      );

  group('Welcome', () {
    test('le vrai groupe est accepté', () async {
      final moteur = _Moteur(welcome: (
        epoch: 4,
        membres: [feuille(0, 'u1:s1', cleMoi), feuille(1, 'u2:b1', cleBob)],
      ));
      final transport = _Transport(registre: [moi, bob], epochServeur: 4);

      await service(moteur, transport).ensureGroup('c1');

      expect(moteur.epoch, 4);
      expect(transport.consommes, ['w1']);
      expect(transport.evenements, isNot(contains('welcome_suspect')));
    });

    for (final (motif, membres, epochServeur) in [
      (
        'cle_etrangere',
        [feuille(0, 'u1:s1', cleMoi), feuille(1, 'u2:b1', cleIntruse)],
        4,
      ),
      (
        'epoch_hors_chaine',
        [feuille(0, 'u1:s1', cleMoi), feuille(1, 'u2:b1', cleBob)],
        2,
      ),
    ]) {
      test('$motif : refusé, oublié, consommé', () async {
        final moteur = _Moteur(welcome: (epoch: 4, membres: membres));
        final transport =
            _Transport(registre: [moi, bob], epochServeur: epochServeur);

        await expectLater(service(moteur, transport).ensureGroup('c1'),
            throwsA(isA<MlsEnAttenteDeWelcome>()));

        expect(moteur.epoch, isNull, reason: 'le groupe fabriqué est oublié');
        expect(transport.consommes, ['w1']);
        expect(transport.motifs, [motif]);
      });
    }
  });

  test('un partant pas encore retiré ne fait pas refuser le vrai groupe',
      () async {
    final moteur = _Moteur(welcome: (
      epoch: 4,
      membres: [
        feuille(0, 'u1:s1', cleMoi),
        feuille(1, 'u2:b1', cleBob),
        feuille(2, 'u7:parti', cleIntruse),
      ],
    ));
    final transport = _Transport(registre: [moi, bob], epochServeur: 4);

    await service(moteur, transport).ensureGroup('c1');

    expect(moteur.epoch, 4);
    expect(transport.motifs, isEmpty);
  });

  test('arbre public fabriqué : la jointure externe est abandonnée', () async {
    final moteur = _Moteur(
      externe: [feuille(0, 'u1:s1', cleMoi), feuille(1, 'u2:b1', cleIntruse)],
    );
    final transport = _Transport(
      registre: [moi, bob],
      epochServeur: 4,
      welcomes: false,
      type: 'group',
    );

    await expectLater(service(moteur, transport).ensureGroup('c1'),
        throwsA(isA<MlsEnAttenteDeWelcome>()));

    expect(transport.evenements, contains('arbre_suspect'));
    expect(transport.commitsPublies, isEmpty,
        reason: 'rien n\'est publié depuis un arbre fabriqué');
    expect(moteur.epoch, isNull);
  });
}

class _Moteur implements Moteur {
  _Moteur({this.welcome, this.externe});

  final ({int epoch, List<MembreDto> membres})? welcome;
  final List<MembreDto>? externe;
  int? epoch;
  List<MembreDto> membres = const [];

  @override
  Future<InstantaneDto> instantane({required String conversationId}) async {
    final e = epoch;
    if (e == null) throw StateError('group_unknown');
    return InstantaneDto(epoch: BigInt.from(e), membres: membres);
  }

  @override
  Future<InstantaneDto> traiterWelcome({
    required String conversationId,
    required List<int> welcome,
  }) async {
    final w = this.welcome!;
    epoch = w.epoch;
    membres = w.membres;
    return instantane(conversationId: conversationId);
  }

  @override
  Future<CommitDto> rejoindreParCommitExterne({
    required String conversationId,
    required List<int> groupInfo,
    required List<int> aad,
  }) async {
    epoch = 5;
    membres = externe!;
    return CommitDto(commit: Uint8List.fromList([7]));
  }

  @override
  Future<void> oublierGroupe({required String conversationId}) async {
    epoch = null;
    membres = const [];
  }

  @override
  Future<Uint8List> exporterGroupInfo({required String conversationId}) async =>
      Uint8List(0);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Transport extends MlsDelivery {
  _Transport({
    required this.registre,
    required this.epochServeur,
    this.welcomes = true,
    this.type = 'individual',
  }) : super(ensureAuth: () async => true);

  final List<MlsDeviceRecord> registre;
  final int epochServeur;
  final bool welcomes;
  final String type;
  final evenements = <String>[];
  final motifs = <String>[];
  final consommes = <String>[];
  final commitsPublies = <int>[];

  @override
  Future<void> diagnostic(
    String userId,
    String event, {
    String? deviceId,
    Map<String, dynamic>? detail,
  }) async {
    evenements.add(event);
    if (event == 'welcome_suspect') motifs.add(detail!['motif'] as String);
  }

  @override
  Future<Map<String, dynamic>?> conversation(String conversationId) async => {
        'id': conversationId,
        'type': type,
        'participant_ids': const ['u1', 'u2'],
        'mls_since': '2026-09-15T00:00:00Z',
      };

  @override
  Future<List<MlsDeviceRecord>> appareilsActifsParIdentite(
    List<String> identites,
  ) async =>
      [for (final d in registre) if (identites.contains(d.mlsIdentity)) d];

  @override
  Future<int?> currentEpoch(String conversationId) async => epochServeur;

  @override
  Future<Uint8List?> groupInfo(String conversationId) async =>
      Uint8List.fromList([1]);

  @override
  Future<List<MlsWelcomeRow>> welcomesFor(
    String deviceId, {
    String? conversationId,
  }) async =>
      welcomes
          ? [
              MlsWelcomeRow(
                id: 'w1',
                conversationId: conversationId ?? 'c1',
                recipientDeviceId: deviceId,
                epoch: 4,
                welcome: Uint8List(0),
              ),
            ]
          : const [];

  @override
  Future<void> markWelcomeConsumed(String id) async => consommes.add(id);

  @override
  Future<bool> aEuUnAppareilDans(String conversationId, String userId) async =>
      false;

  @override
  Future<DateTime?> reconstruitLe(String conversationId) async => null;

  @override
  Future<void> publishCommit({
    required String conversationId,
    required int epoch,
    required String senderDeviceId,
    required Uint8List commit,
    Uint8List? groupInfo,
  }) async =>
      commitsPublies.add(epoch);

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
}
