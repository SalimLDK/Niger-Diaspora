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
  group('rangDesDerniersDAutrui', () {
    // Quand `markAsRead` a déjà tout marqué lu — il part au premier rendu,
    // avant même que le fil chiffré ne soit récupéré — l'état de lecture ne
    // dit plus rien. On place alors le séparateur par le **rang**, à partir du
    // compteur serveur relevé avant l'ouverture.
    test('trouve le rang du N-ième message d\'autrui en remontant', () {
      final fil = [
        _m('a', 'autre'),   // 0
        _m('b', 'moi'),     // 1
        _m('c', 'autre'),   // 2
        _m('d', 'autre'),   // 3
      ];

      expect(rangDesDerniersDAutrui(fil, 'moi', 1), 3);
      expect(rangDesDerniersDAutrui(fil, 'moi', 2), 2);
      expect(rangDesDerniersDAutrui(fil, 'moi', 3), 0);
    });

    test('mes propres messages ne comptent pas dans le rang', () {
      final fil = [
        _m('a', 'autre'),
        _m('b', 'moi'),
        _m('c', 'moi'),
      ];

      // Un seul message d'autrui, tout au début.
      expect(rangDesDerniersDAutrui(fil, 'moi', 1), 0);
    });

    test('un message système est sauté', () {
      final fil = [
        _m('a', 'autre'),
        MlsMessageMapper.separateur(DateTime.utc(2026, 9, 15)),
        _m('c', 'autre'),
      ];

      expect(rangDesDerniersDAutrui(fil, 'moi', 2), 0);
    });

    test('fil incomplet : on ne place rien plutôt que de se tromper', () {
      // Le serveur annonce 5 non-lus, le fil n'en porte que deux : il n'est
      // pas encore complet. Placer un séparateur au début serait faux.
      final fil = [_m('a', 'autre'), _m('b', 'autre')];

      expect(rangDesDerniersDAutrui(fil, 'moi', 5), isNull);
    });

    test('zéro ou négatif : rien à placer', () {
      final fil = [_m('a', 'autre')];

      expect(rangDesDerniersDAutrui(fil, 'moi', 0), isNull);
      expect(rangDesDerniersDAutrui(fil, 'moi', -1), isNull);
    });
  });

  group('le rattrapage MLS ne tourne pas deux fois à la fois', () {
    // `catchUp` fait avancer le cliquet MLS. Depuis que la liste déclenche un
    // rattrapage de fond, l'écran peut ouvrir le même fil au même moment :
    // sans partage du futur, le cliquet avancerait deux fois en parallèle, et
    // un cliquet abîmé rend des messages illisibles pour de bon.
    late String source;

    setUpAll(() {
      final fichier = File('lib/core/crypto/mls/mls_gateway.dart');
      expect(fichier.existsSync(), isTrue, reason: 'passerelle introuvable');
      source = fichier.readAsStringSync().replaceAll('\r\n', '\n');
    });

    test('les appelants concurrents partagent le même futur', () {
      expect(source, contains('final enCours = _rattrapages[conversationId];'));
      expect(source, contains('if (enCours != null) return enCours;'));
    });

    test('le futur est retiré une fois terminé', () {
      // Sinon un échec figerait la conversation : tout appelant suivant
      // recevrait le même futur déjà en erreur.
      expect(source, contains('_rattrapages.remove(conversationId);'));
    });

    test('le rattrapage de fond est borné', () {
      // Il ne s'agit pas de déchiffrer toute la messagerie au démarrage.
      expect(source, contains('int maximum = 3'));
      expect(source, contains('if (sortie.length >= maximum) break;'));
    });
  });

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
