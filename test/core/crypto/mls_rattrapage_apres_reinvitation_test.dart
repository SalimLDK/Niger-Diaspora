import 'dart:typed_data';

import 'package:diaspo_niger/core/crypto/mls/mls_conversation_service.dart';
import 'package:diaspo_niger/core/crypto/mls/mls_delivery.dart';
import 'package:diaspo_niger/core/crypto/mls/mls_device_registry.dart';
import 'package:diaspo_niger/src/rust/api/mls.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ce que ce test protège
/// -----------------------
/// Trouvé le 2026-09-17 sur le Pixel, APRÈS un retrait + réinvitation
/// pourtant réussis côté serveur (commit Remove, commit Add, Welcome frais
/// publié) : l'appareil restait bloqué pour toujours sur le commit suivant,
/// en `GroupStateError`, sans jamais regarder le Welcome qui l'attendait.
///
/// Cause : `_ensureGroup` — le seul endroit qui lit `welcomesFor` — n'est
/// appelé par `catchUp` que si `estMembre` répond faux. Un commit qui
/// échoue une fois laissait `estMembre` répondre vrai indéfiniment (l'état
/// local, bien que dépassé par le pair, restait présent et valide à ses
/// propres yeux) : le Welcome restait invisible, pour toujours.
///
/// `_rattraperCommits` ferme ce trou : si un commit échoue alors qu'un
/// Welcome attend, on oublie l'état local corrompu (`estMembre` devient
/// faux) et on rejoint proprement par ce Welcome avant de reprendre.

class _MoteurRattrapage implements Moteur {
  /// `null` = groupe oublié (`group_unknown`, comme le rendrait le vrai
  /// moteur après `oublierGroupe`). Sinon l'epoch local courant.
  int? epoch = 2;

  bool oublieAppele = false;
  bool welcomeTraite = false;

  @override
  Future<InstantaneDto> instantane({required String conversationId}) async {
    final e = epoch;
    if (e == null) throw StateError('group_unknown');
    return InstantaneDto(epoch: BigInt.from(e), membres: const []);
  }

  @override
  Future<EntrantDto> traiterEntrant({
    required String conversationId,
    required List<int> message,
    required List<int> aadAttendu,
  }) async {
    // Le commit suivant échoue systématiquement — c'est le `GroupStateError`
    // constaté sur le Pixel : rejouer ce commit précis ne marchera jamais.
    throw StateError('openmls:GroupStateError');
  }

  @override
  Future<InstantaneDto> traiterWelcome({
    required String conversationId,
    required List<int> welcome,
  }) async {
    welcomeTraite = true;
    epoch = 5; // l'epoch encodé par le Welcome frais.
    return InstantaneDto(epoch: BigInt.from(5), membres: const []);
  }

  @override
  Future<void> oublierGroupe({required String conversationId}) async {
    oublieAppele = true;
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
  Future<Uint8List> exporterGroupInfo({required String conversationId}) =>
      _interdit('exporterGroupInfo');

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
  Future<CommitDto> rejoindreParCommitExterne({
    required String conversationId,
    required List<int> groupInfo,
    required List<int> aad,
  }) =>
      // La garde qu'on vérifie ici : un Welcome disponible doit être
      // préféré à une jointure externe. Si ce test l'appelle, la régression
      // exacte du 2026-09-16 (rejointures fantômes) est de retour.
      _interdit('rejoindreParCommitExterne');

  @override
  Future<CommitDto> retirerMembres({
    required String conversationId,
    required List<int> leafIndices,
    required List<int> aad,
  }) =>
      _interdit('retirerMembres');
}

class _TransportRattrapage extends MlsDelivery {
  _TransportRattrapage() : super(ensureAuth: () async => true);

  final diagnostics = <Map<String, Object?>>[];
  bool welcomeConsomme = false;

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
  Future<List<MlsCommitRow>> commitsAfter(String conversationId, int epoch) async {
    // Le commit epoch 3 est celui que ce moteur ne saura jamais rejouer
    // (voir `traiterEntrant`). Une fois le Welcome traité (epoch 5, plus
    // haut que ce commit), il n'y a plus rien en attente : l'arbre d'en
    // face n'avait justement plus rien à offrir par la voie des commits.
    if (epoch != 2) return const [];
    return [
      MlsCommitRow(
        conversationId: conversationId,
        epoch: 3,
        senderDeviceId: 'autre-appareil',
        commit: Uint8List(0),
        createdAt: DateTime.now(),
      ),
    ];
  }

  @override
  Future<List<MlsWelcomeRow>> welcomesFor(
    String deviceId, {
    String? conversationId,
  }) async =>
      [
        MlsWelcomeRow(
          id: 'welcome-1',
          conversationId: conversationId ?? 'c1',
          recipientDeviceId: deviceId,
          epoch: 5,
          welcome: Uint8List(0),
        ),
      ];

  @override
  Future<void> markWelcomeConsumed(String id) async {
    welcomeConsomme = true;
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
      name: 'Pixel de test',
      platform: 'android',
      mlsIdentity: 'u1:stable-1',
      createdAt: DateTime.utc(2026, 9, 16),
      lastSeenAt: DateTime.utc(2026, 9, 17),
    );

void main() {
  test(
      'un commit qui échoue alors qu\'un Welcome attend oublie le groupe et '
      'rejoint proprement, sans jamais tenter une jointure externe', () async {
    final moteur = _MoteurRattrapage();
    final delivery = _TransportRattrapage();
    final service = MlsConversationService(
      userId: 'u1',
      moteur: () async => moteur,
      delivery: delivery,
      appareil: () async => _appareil(),
      lireMemo: (_) async => null,
      ecrireMemo: (_, __) async {},
    );

    final resultat = await service.catchUp('c1');

    expect(resultat, isEmpty);
    expect(moteur.oublieAppele, isTrue,
        reason: 'le groupe corrompu doit être oublié');
    expect(moteur.welcomeTraite, isTrue,
        reason: 'le Welcome frais doit être consommé, pas ignoré');
    expect(delivery.welcomeConsomme, isTrue);
    expect(moteur.epoch, 5, reason: 'l\'epoch doit venir du Welcome, pas d\'une jointure externe');

    final evenements = delivery.diagnostics.map((d) => d['event']).toList();
    expect(evenements, contains('groupe_oublie_pour_welcome'));
    expect(evenements, isNot(contains('commit_illisible')),
        reason: 'un Welcome disponible ne doit jamais retomber sur le simple abandon');
  });
}
