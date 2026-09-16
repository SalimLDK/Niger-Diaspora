import 'dart:io';

import 'package:diaspo_niger/core/crypto/mls/mls_message_mapper.dart';
import 'package:diaspo_niger/features/messages/domain/entities/message_entity.dart';
import 'package:diaspo_niger/features/messages/presentation/screens/conversation_screen.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ce que ces tests protègent
/// --------------------------
/// Le bandeau « 1 message non lu » d'une conversation basculée ne s'effaçait
/// plus. Vu le 2026-09-15 sur SM A515F, dans la première conversation passée
/// en MLS : le séparateur de bascule (dont le libellé est désormais résolu
/// à l'affichage, voir `separateur_bascule_libelle_test.dart`) est un
/// message **système synthétique** — `senderId: 'system'`, `readBy`
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
  group('le séparateur né après la lecture réseau', () {
    // `_loadCacheSync` affiche le cache local immédiatement et pose
    // `isLoadingInitial: false`. Les messages neufs, eux, ne sont PAS dans ce
    // cache : sur une conversation chiffrée ils n'ont jamais été déchiffrés
    // et n'arrivent qu'après le réseau. Le comptage tombait donc sur zéro,
    // `_hasCalculatedUnread` se fermait pour de bon, et le séparateur
    // « nouveaux messages » ne s'affichait jamais.
    //
    // Signalé à l'usage le 2026-09-15, en même temps que le délai avant que
    // le message neuf lui-même apparaisse — c'est la même cause.
    //
    // Limite assumée, comme le reste de ce fichier : ces tests lisent la
    // source. Monter `ConversationScreen` demande GoRouter, une session
    // Supabase et une dizaine de providers.
    late String source;

    setUpAll(() {
      final fichier = File(
        'lib/features/messages/presentation/screens/conversation_screen.dart',
      );
      expect(fichier.existsSync(), isTrue, reason: 'écran introuvable');
      source = fichier.readAsStringSync().replaceAll('\r\n', '\n');
    });

    test('zéro non-lu ne ferme plus le verrou immédiatement', () {
      // Le verrou ne se ferme qu'une fois la fenêtre d'ouverture passée.
      expect(
        source,
        contains(
          "if (DateTime.now().difference(_ouvertA) >= _fenetreRecompteNonLus) {",
        ),
        reason: 'le comptage se refermerait sur le cache seul',
      );
    });

    test('la fenêtre de recompte est bornée', () {
      // Sans borne, un message reçu en direct se rangerait sous un séparateur
      // « nouveaux messages » sous les yeux de qui regarde la discussion.
      expect(source, contains('_fenetreRecompteNonLus = Duration(seconds:'));
    });

    test('le placement initial ne se rejoue pas à chaque recompte', () {
      // Sinon la vue sauterait à chaque émission pendant la fenêtre.
      expect(source, contains('bool _aFaitLePlacementInitial = false;'));
      final debut = source.indexOf('void _calculateUnreadOnOpen()');
      final corps = source.substring(debut, debut + 2200);
      expect(
        '_aFaitLePlacementInitial'.allMatches(corps).length,
        greaterThanOrEqualTo(4),
        reason: 'les deux branches doivent garder le placement',
      );
    });
  });

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
