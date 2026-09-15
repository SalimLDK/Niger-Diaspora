import 'package:diaspo_niger/core/crypto/mls/mls_conversation_service.dart';
import 'package:diaspo_niger/core/crypto/mls/mls_delivery.dart';
import 'package:diaspo_niger/core/crypto/mls/mls_gateway.dart';
import 'package:diaspo_niger/core/crypto/mls/mls_metadonnees.dart';
import 'package:diaspo_niger/features/messages/domain/entities/message_entity.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ce que ces tests protègent
/// --------------------------
/// **Absence n'est pas échec.** `MlsMetadonnees.pour` rendait un lot *vide*
/// dans les deux cas : quand le serveur ne porte aucune métadonnée, et quand
/// la lecture avait échoué. L'appelant ne pouvait pas les distinguer, et
/// sortait sur le vide — donc sans recoller, donc sans **effacer** ce que le
/// serveur ne porte plus.
///
/// Or le fil vient du cache de l'appareil, qui garde les réactions, étoiles et
/// marques d'hier. Mesuré le 2026-09-15 sur SM A515F : une bulle affichait un
/// pouce levé alors que `mls_message_reactions` était vide. Une réaction
/// retirée restait affichée pour toujours, et une réaction dont l'écriture
/// avait échoué paraissait avoir pris.
///
/// C'est la septième forme d'échec muet de ce dépôt — la requête qui réussit à
/// vide, où l'absence se confond avec la suppression.

MessageEntity _m(String id, {Map<String, String> reactions = const {}}) =>
    MessageEntity(
      id: id,
      senderId: 'u2',
      senderName: 'Amina',
      content: id,
      type: MessageType.text,
      status: MessageStatus.sent,
      createdAt: DateTime.utc(2026, 9, 15),
      reactions: reactions,
      starredBy: const ['moi'],
    );

class _Transport extends MlsDelivery {
  _Transport() : super(ensureAuth: (() async => true));
}

class _ServiceMuet extends MlsConversationService {
  _ServiceMuet()
      : super(
          userId: 'moi',
          moteur: () => throw StateError('inutile ici'),
          delivery: _Transport(),
          appareil: () => throw StateError('inutile ici'),
          lireMemo: (_) async => null,
          ecrireMemo: (_, __) async {},
        );

  @override
  Future<List<MlsIncoming>> catchUp(String conversationId) async => const [];
}

/// Rend le lot qu'on lui donne, sans réseau.
class _Meta extends MlsMetadonnees {
  _Meta(this.lot) : super(userId: 'moi', ensureAuth: (() async => true));

  final MlsMetadonneesLot lot;

  @override
  Future<MlsMetadonneesLot> pour(Iterable<String> messageIds) async => lot;
}

MlsGateway _passerelle(MlsMetadonneesLot lot) => MlsGateway(
      userId: 'moi',
      actif: () => true,
      service: _ServiceMuet(),
      delivery: _Transport(),
      metadonnees: _Meta(lot),
    );

void main() {
  group('le lot dit s\'il a été lu', () {
    test('un lot vide est lu ; un lot illisible ne l\'est pas', () {
      expect(MlsMetadonneesLot.vide.lu, isTrue);
      expect(MlsMetadonneesLot.illisible.lu, isFalse);
      // Les deux sont vides : c'est bien le drapeau, et lui seul, qui les
      // sépare.
      expect(MlsMetadonneesLot.vide.estVide, isTrue);
      expect(MlsMetadonneesLot.illisible.estVide, isTrue);
    });
  });

  group('recollage sur le fil', () {
    test('serveur sans métadonnée : la réaction du cache est effacée',
        () async {
      final p = _passerelle(MlsMetadonneesLot.vide);
      p.amorcer('c1', [_m('m1', reactions: {'moi': '👍'})]);

      final fil = await p.messages('c1');

      expect(fil.single.reactions, isEmpty,
          reason: 'le serveur fait foi : plus de ligne, plus de badge');
      expect(fil.single.starredBy, isEmpty);
    });

    test('lecture en échec : l\'écran garde ce qu\'il affichait', () async {
      // Une coupure réseau ne doit pas faire disparaître les réactions de
      // tout le fil — ce serait échanger un défaut contre un pire.
      final p = _passerelle(MlsMetadonneesLot.illisible);
      p.amorcer('c1', [_m('m1', reactions: {'moi': '👍'})]);

      final fil = await p.messages('c1');

      expect(fil.single.reactions, {'moi': '👍'});
      expect(fil.single.starredBy, ['moi']);
    });

    test('le serveur porte une réaction : elle remplace celle du cache',
        () async {
      final p = _passerelle(const MlsMetadonneesLot(
        reactions: {'m1': {'moi': '❤️'}},
      ));
      p.amorcer('c1', [_m('m1', reactions: {'moi': '👍'})]);

      final fil = await p.messages('c1');

      expect(fil.single.reactions, {'moi': '❤️'});
    });
  });
}
