import 'dart:typed_data';

import 'package:diaspo_niger/core/crypto/mls/mls_conversation_service.dart';
import 'package:diaspo_niger/core/crypto/mls/mls_delivery.dart';
import 'package:diaspo_niger/core/crypto/mls/mls_device_registry.dart';
import 'package:diaspo_niger/src/rust/api/mls.dart';
import 'package:flutter_test/flutter_test.dart';

/// Groupe MLS bloqué : l'alerte, et la reconstruction.
///
/// Un membre peut publier des octets quelconques à l'epoch suivant — le
/// serveur ne voit que du chiffré. Tous les autres tombaient sur
/// `commit_illisible` et s'arrêtaient là, définitivement, sans que l'écran
/// n'en dise rien. Désormais l'appareil se sait bloqué (`estBloquee`,
/// `blocages`), et `reparer` reconstruit le groupe (migration
/// 20261004120000) ; chaque autre appareil applique la reconstruction à son
/// prochain rattrapage.
void main() {
  group('alerte', () {
    test('un commit illisible sans Welcome bloque, et le dit', () async {
      final moteur = _Moteur(epoch: 2)..commitsIllisibles = true;
      final transport = _Transport()..commits = [_commit(3)];
      final service = _service(moteur, transport);
      final signaux = <String>[];
      final abonnement = service.blocages.listen(signaux.add);
      addTearDown(abonnement.cancel);

      expect(service.estBloquee('c1'), isFalse);
      await service.catchUp('c1');
      await Future<void>.delayed(Duration.zero);

      expect(service.estBloquee('c1'), isTrue);
      expect(signaux, ['c1']);
    });
  });

  group('reconstruction faite ailleurs', () {
    test('appliquée une fois : arbre oublié, curseur à la date, alerte levée',
        () async {
      final marque = DateTime.utc(2026, 10, 4, 12);
      final moteur = _Moteur(epoch: 2)..commitsIllisibles = true;
      final transport = _Transport()..commits = [_commit(3)];
      final memo = <String, String>{};
      final service = _service(moteur, transport, memo: memo);

      await service.catchUp('c1'); // bloqué
      expect(service.estBloquee('c1'), isTrue);

      // Un administrateur reconstruit : plus de commits, une marque.
      transport
        ..commits = []
        ..marque = marque;
      await service.catchUp('c1');

      expect(moteur.oublis, 1);
      expect(service.estBloquee('c1'), isFalse);
      // Le curseur est placé à la date de reconstruction : les messages
      // d'avant (indéchiffrables dans le nouveau groupe) ne se relisent pas.
      expect(memo['mls_curseur_u1_c1'], marque.toIso8601String());
      expect(memo['mls_arrivee_u1_c1'], '0',
          reason: 'les epochs repartent de zéro');

      // La même marque ne s'applique pas deux fois.
      await service.catchUp('c1');
      expect(moteur.oublis, 1);
    });

    test('rejoint après la reconstruction : la marque est déjà connue',
        () async {
      // Installation neuve, entrée dans le NOUVEAU groupe par Welcome. Sans
      // marque mémorisée à la jointure, elle prendrait la reconstruction
      // pour une à appliquer — oublier, rejoindre, oublier…
      final marque = DateTime.utc(2026, 10, 4, 12);
      final moteur = _Moteur(epoch: null);
      final transport = _Transport()
        ..marque = marque
        ..epochServeur = 1
        ..welcome = true;
      final service = _service(moteur, transport);

      await service.ensureGroup('c1');
      expect(moteur.epoch, 1);
      await service.catchUp('c1');

      expect(moteur.oublis, 0);
    });
  });

  group('réparer', () {
    test('le serveur remet à zéro, puis l\'appareil recrée le groupe',
        () async {
      final moteur = _Moteur(epoch: 2)..commitsIllisibles = true;
      final transport = _Transport()..commits = [_commit(3)];
      final service = _service(moteur, transport);
      await service.catchUp('c1');
      expect(service.estBloquee('c1'), isTrue);

      await service.reparer('c1');

      expect(transport.reconstructions, 1);
      expect(moteur.oublis, 1);
      expect(moteur.creations, 1);
      expect(transport.publies, [0], reason: 'le nouveau groupe part de l\'epoch 0');
      expect(service.estBloquee('c1'), isFalse);
    });

    test('refus du serveur : rien n\'est touché localement', () async {
      final moteur = _Moteur(epoch: 2);
      final transport = _Transport()..refus = true;
      final service = _service(moteur, transport);

      await expectLater(service.reparer('c1'), throwsA(isA<StateError>()));
      expect(moteur.oublis, 0);
      expect(moteur.creations, 0);
    });
  });
}

MlsConversationService _service(
  _Moteur moteur,
  _Transport transport, {
  Map<String, String>? memo,
}) {
  final m = memo ?? <String, String>{};
  return MlsConversationService(
    userId: 'u1',
    moteur: () async => moteur,
    delivery: transport,
    appareil: () async => _appareil,
    lireMemo: (cle) async => m[cle],
    ecrireMemo: (cle, valeur) async => m[cle] = valeur,
  );
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

MlsCommitRow _commit(int epoch) => MlsCommitRow(
      conversationId: 'c1',
      epoch: epoch,
      senderDeviceId: 'autre',
      commit: Uint8List.fromList([epoch]),
      createdAt: DateTime.utc(2026, 10, 4, 10),
    );

class _Moteur implements Moteur {
  _Moteur({required this.epoch});

  /// `null` : pas de groupe local (`group_unknown`).
  int? epoch;
  bool commitsIllisibles = false;
  int oublis = 0;
  int creations = 0;

  @override
  Future<InstantaneDto> instantane({required String conversationId}) async {
    final e = epoch;
    if (e == null) throw StateError('group_unknown');
    return InstantaneDto(epoch: BigInt.from(e), membres: const [
      MembreDto(leafIndex: 0, identity: 'u1:stable-1'),
    ]);
  }

  @override
  Future<EntrantDto> traiterEntrant({
    required String conversationId,
    required List<int> message,
    required List<int> aadAttendu,
  }) async {
    if (commitsIllisibles) throw StateError('openmls:ValidationError');
    epoch = epoch! + 1;
    return EntrantDto.commit(instantane: await instantane(conversationId: conversationId));
  }

  @override
  Future<void> oublierGroupe({required String conversationId}) async {
    oublis++;
    epoch = null;
  }

  @override
  Future<InstantaneDto> creerGroupe({required String conversationId}) async {
    creations++;
    epoch = 0;
    commitsIllisibles = false;
    return instantane(conversationId: conversationId);
  }

  @override
  Future<InstantaneDto> traiterWelcome({
    required String conversationId,
    required List<int> welcome,
  }) async {
    epoch = 1;
    return instantane(conversationId: conversationId);
  }

  @override
  Future<Uint8List> exporterGroupInfo({required String conversationId}) async =>
      Uint8List(0);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Transport extends MlsDelivery {
  _Transport() : super(ensureAuth: () async => true);

  List<MlsCommitRow> commits = const [];
  DateTime? marque;
  int? epochServeur;
  bool welcome = false;
  bool refus = false;
  int reconstructions = 0;
  final publies = <int>[];
  final lecturesDepuis = <DateTime?>[];

  @override
  Future<void> diagnostic(
    String userId,
    String event, {
    String? deviceId,
    Map<String, dynamic>? detail,
  }) async {}

  @override
  Future<DateTime?> reconstruitLe(String conversationId) async => marque;

  @override
  Future<DateTime> reconstruireGroupe(String conversationId) async {
    if (refus) {
      throw StateError('reconstruire_groupe_mls : réservé aux administrateurs du groupe');
    }
    reconstructions++;
    commits = const [];
    marque = DateTime.utc(2026, 10, 4, 13);
    return marque!;
  }

  @override
  Future<int?> currentEpoch(String conversationId) async =>
      publies.isNotEmpty ? publies.last : epochServeur;

  @override
  Future<List<MlsCommitRow>> commitsAfter(String conversationId, int epoch) async =>
      commits.where((c) => c.epoch > epoch).toList();

  @override
  Future<List<MlsMessageRow>> messagesAfter(
    String conversationId,
    DateTime? after, {
    int limit = 200,
  }) async {
    lecturesDepuis.add(after);
    return const [];
  }

  @override
  Future<List<MlsWelcomeRow>> welcomesFor(
    String deviceId, {
    String? conversationId,
  }) async =>
      welcome
          ? [
              MlsWelcomeRow(
                id: 'w1',
                conversationId: conversationId ?? 'c1',
                recipientDeviceId: deviceId,
                epoch: 1,
                welcome: Uint8List(0),
              ),
            ]
          : const [];

  @override
  Future<void> markWelcomeConsumed(String id) async => welcome = false;

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
  Future<void> marquerMlsSince(String conversationId) async {}

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
