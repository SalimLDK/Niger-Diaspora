import 'package:diaspo_niger/core/crypto/mls/mls_message_mapper.dart';
import 'package:diaspo_niger/features/messages/domain/entities/message_entity.dart';
import 'package:diaspo_niger/features/messages/presentation/screens/conversation_screen.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ce que ces tests protègent
/// --------------------------
/// Le bandeau « 1 message non lu » d'une conversation basculée ne s'effaçait
/// plus. Vu le 2026-09-15 sur SM A515F, dans la première conversation passée
/// en MLS : le séparateur « Messages d'avant le chiffrement de bout en bout »
/// est un message **système synthétique** — `senderId: 'system'`, `readBy`
/// vide — donc éternellement non lu. Rien ne viendra jamais le marquer, il
/// n'existe pas côté serveur.
///
/// Et le serveur ne le comptait pas : la vue `mls_unread_counts` ne retient
/// que `kind = 'content'` et exclut l'expéditeur. L'écran disait un, la base
/// disait zéro.
///
/// Ce que ces tests empêchent : qu'un message système redevienne du courrier,
/// que mes propres messages comptent, et que le rang du premier non-lu
/// désigne un séparateur — l'écran s'y déroule.

MessageEntity _m(
  String id,
  String expediteur, {
  List<String> lu = const [],
  MessageType type = MessageType.text,
}) =>
    MessageEntity(
      id: id,
      senderId: expediteur,
      senderName: expediteur,
      content: id,
      type: type,
      status: MessageStatus.sent,
      createdAt: DateTime.utc(2026, 9, 15),
      readBy: lu,
    );

void main() {
  const moi = 'uid-moi';

  group('compterNonLus', () {
    test('le séparateur de bascule MLS ne compte pas', () {
      // Le cas exact rencontré sur l'appareil : une conversation avec
      // soi-même, un seul message, et un bandeau qui annonçait un non-lu.
      final fil = [
        _m('vieux', moi, lu: [moi]),
        MlsMessageMapper.separateur(DateTime.utc(2026, 9, 15)),
        _m('mien', moi, lu: [moi]),
      ];

      final r = compterNonLus(fil, moi);
      expect(r.nombre, 0);
      expect(r.premier, isNull);
    });

    test('aucun message système ne compte, quel qu\'il soit', () {
      final fil = [
        _m('arrivee', 'system', type: MessageType.system),
        _m('depart', 'system', type: MessageType.system),
      ];
      expect(compterNonLus(fil, moi).nombre, 0);
    });

    test('mes propres messages ne comptent pas, lus ou non', () {
      final fil = [_m('a', moi), _m('b', moi, lu: [moi])];
      expect(compterNonLus(fil, moi).nombre, 0);
    });

    test('un message d\'autrui non lu compte, et donne son rang', () {
      final fil = [
        _m('a', moi, lu: [moi]),
        _m('b', 'autre', lu: [moi]),
        _m('c', 'autre'),
        _m('d', 'autre'),
      ];
      final r = compterNonLus(fil, moi);
      expect(r.nombre, 2);
      expect(r.premier, 2);
    });

    test('le rang du premier non-lu saute le séparateur', () {
      // Sans ça, le bandeau se posait SUR le séparateur, et l'écran s'y
      // déroulait — au mauvais endroit du fil.
      final fil = [
        _m('vieux', 'autre', lu: [moi]),
        MlsMessageMapper.separateur(DateTime.utc(2026, 9, 15)),
        _m('neuf', 'autre'),
      ];
      final r = compterNonLus(fil, moi);
      expect(r.nombre, 1);
      expect(r.premier, 2);
    });

    test('fil vide', () {
      final r = compterNonLus(const [], moi);
      expect(r.nombre, 0);
      expect(r.premier, isNull);
    });
  });
}
