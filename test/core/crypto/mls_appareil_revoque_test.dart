import 'dart:typed_data';

import 'package:diaspo_niger/core/crypto/mls/mls_conversation_service.dart';
import 'package:diaspo_niger/core/crypto/mls/mls_delivery.dart';
import 'package:diaspo_niger/core/crypto/mls/mls_device_registry.dart';
import 'package:diaspo_niger/core/crypto/mls/mls_payload_codec.dart';
import 'package:diaspo_niger/src/rust/api/mls.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ce que ces tests protègent
/// -------------------------
/// Trouvé le 2026-09-17 sur le Pixel de test : `MlsDeviceRegistry
/// .ensureRegistered` détecte un appareil révoqué et écrit le diagnostic,
/// mais renvoie quand même le `MlsDeviceRecord` — et rien, nulle part
/// ailleurs dans la pile MLS, ne relisait `estRevoque`. Un appareil révoqué
/// rejoignait donc des groupes par commit externe, s'inscrivait dans
/// `conversation_devices` comme membre actif, et chiffrait/déchiffrait avec
/// des clés que le serveur ne tenait plus à jour pour lui : échec
/// cryptographique systématique (`GroupStateError`/`ValidationError`), à
/// chaque appel, sans qu'aucun message ne le dise. Voir la mémoire
/// `project_mls_epoch_desync_maj_pixel`.
///
/// `_refuserSiRevoque` ferme ce trou à quatre points d'entrée
/// (`ensureGroup`, `reconcileMembership`, `send`, `catchUp`). Ces tests
/// prouvent qu'elle lève AVANT tout appel au moteur autre que la simple
/// lecture d'état (`instantane`) qui décide si l'appareil est déjà membre —
/// jamais de jointure, de commit, de chiffrement ni de déchiffrement.

/// Un moteur qui ne sait dire qu'une chose : son état de rattachement local
/// (membre ou pas). Tout le reste doit rester hors d'atteinte tant que la
/// garde protège un appareil révoqué — l'appeler fait échouer le test avec
/// un message qui nomme l'opération interdite, plutôt qu'un `NoSuchMethod`
/// muet.
class _MoteurGarde implements Moteur {
  _MoteurGarde({required this.membre});

  /// Vrai : l'appareil a déjà un état local pour ce groupe — le cas réel du
  /// Pixel, joint (mal) avant sa révocation. Faux : `group_unknown`, comme
  /// un appareil qui n'a encore jamais rejoint.
  final bool membre;

  @override
  Future<InstantaneDto> instantane({required String conversationId}) async {
    if (!membre) throw StateError('group_unknown');
    return InstantaneDto(epoch: BigInt.from(4), membres: const []);
  }

  @override
  void dispose() {}

  @override
  bool get isDisposed => false;

  Never _interdit(String nom) => throw StateError(
      '$nom : ne doit jamais être appelé pour un appareil révoqué');

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
  Future<void> oublierGroupe({required String conversationId}) =>
      _interdit('oublierGroupe');

  @override
  Future<CommitDto> rejoindreParCommitExterne({
    required String conversationId,
    required List<int> groupInfo,
    required List<int> aad,
  }) =>
      _interdit('rejoindreParCommitExterne');

  @override
  Future<CommitDto> retirerMembres({
    required String conversationId,
    required List<int> leafIndices,
    required List<int> aad,
  }) =>
      _interdit('retirerMembres');

  @override
  Future<EntrantDto> traiterEntrant({
    required String conversationId,
    required List<int> message,
    required List<int> aadAttendu,
  }) =>
      _interdit('traiterEntrant');

  @override
  Future<InstantaneDto> traiterWelcome({
    required String conversationId,
    required List<int> welcome,
  }) =>
      _interdit('traiterWelcome');
}

/// Le transport, sans réseau : les commits et messages sont toujours vides,
/// et les diagnostics écrits sont retenus pour être inspectés.
class _TransportGarde extends MlsDelivery {
  _TransportGarde() : super(ensureAuth: () async => true);

  final diagnostics = <Map<String, Object?>>[];

  @override
  Future<void> diagnostic(
    String userId,
    String event, {
    String? deviceId,
    Map<String, dynamic>? detail,
  }) async {
    diagnostics.add({'userId': userId, 'event': event, 'deviceId': deviceId});
  }

  @override
  Future<List<MlsCommitRow>> commitsAfter(String conversationId, int epoch) async =>
      const [];

  @override
  Future<List<MlsMessageRow>> messagesAfter(
    String conversationId,
    DateTime? after, {
    int limit = 200,
  }) async =>
      const [];
}

MlsDeviceRecord _appareil({required bool revoque}) => MlsDeviceRecord(
      id: 'appareil-1',
      userId: 'u1',
      stableId: 'stable-1',
      name: 'Pixel de test',
      platform: 'android',
      mlsIdentity: 'u1:stable-1',
      createdAt: DateTime.utc(2026, 9, 16),
      lastSeenAt: DateTime.utc(2026, 9, 17),
      revokedAt: revoque ? DateTime.utc(2026, 9, 16, 18, 54) : null,
    );

MlsConversationService _service({
  required _MoteurGarde moteur,
  required _TransportGarde delivery,
  required bool revoque,
}) =>
    MlsConversationService(
      userId: 'u1',
      moteur: () async => moteur,
      delivery: delivery,
      appareil: () async => _appareil(revoque: revoque),
      lireMemo: (_) async => null,
      ecrireMemo: (_, __) async {},
    );

void main() {
  group('appareil révoqué', () {
    test(
        'catchUp refuse un appareil déjà joint mais révoqué, sans tenter '
        'le moindre déchiffrement', () async {
      final moteur = _MoteurGarde(membre: true);
      final delivery = _TransportGarde();
      final service = _service(moteur: moteur, delivery: delivery, revoque: true);

      await expectLater(
        service.catchUp('c1'),
        throwsA(isA<MlsAppareilRevoque>()),
      );

      expect(delivery.diagnostics, hasLength(1));
      expect(delivery.diagnostics.single['event'], 'appareil_revoque_refuse');
      expect(delivery.diagnostics.single['deviceId'], 'appareil-1');
    });

    test(
        'send refuse de chiffrer et publier depuis un appareil révoqué',
        () async {
      final moteur = _MoteurGarde(membre: true);
      final delivery = _TransportGarde();
      final service = _service(moteur: moteur, delivery: delivery, revoque: true);

      await expectLater(
        service.send('c1', MlsPayload.texte('m1', 'salut')),
        throwsA(isA<MlsAppareilRevoque>()),
      );
    });

    test(
        'ensureGroup refuse de rejoindre un groupe depuis un appareil '
        'révoqué qui n\'y est pas encore', () async {
      final moteur = _MoteurGarde(membre: false);
      final delivery = _TransportGarde();
      final service = _service(moteur: moteur, delivery: delivery, revoque: true);

      await expectLater(
        service.ensureGroup('c1'),
        throwsA(isA<MlsAppareilRevoque>()),
      );
    });

    test(
        'reconcileMembership refuse d\'aligner l\'appartenance depuis un '
        'appareil révoqué', () async {
      final moteur = _MoteurGarde(membre: true);
      final delivery = _TransportGarde();
      final service = _service(moteur: moteur, delivery: delivery, revoque: true);

      await expectLater(
        service.reconcileMembership('c1'),
        throwsA(isA<MlsAppareilRevoque>()),
      );
    });

    test('un appareil non révoqué continue de fonctionner normalement',
        () async {
      final moteur = _MoteurGarde(membre: true);
      final delivery = _TransportGarde();
      final service = _service(moteur: moteur, delivery: delivery, revoque: false);

      final resultat = await service.catchUp('c1');

      expect(resultat, isEmpty);
      expect(delivery.diagnostics, isEmpty);
    });
  });
}
