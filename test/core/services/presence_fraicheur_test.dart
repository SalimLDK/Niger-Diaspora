// Vu sur deux téléphones le 2026-09-22 (build Play 1.2.2+26) :
// - un compte en mode avion, app fermée, restait « En ligne » chez l'autre
//   pendant plusieurs minutes ;
// - le même compte, app ouverte et utilisée, s'affichait « Vu il y a environ
//   2 minutes ».
// `isOnline` était cru sans condition, et le battement de 10 min n'écrivait
// que dans Supabase, que l'en-tête ne lit pas.
import 'dart:io';

import 'package:diaspo_niger/core/services/online_status_service.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';

const _maintenant = 1790063000000; // ms, heure du serveur

Map<String, Object?> _noeud({
  bool isOnline = true,
  int? ilYaSecondes,
  int? battement,
}) => {
  'isOnline': isOnline,
  if (ilYaSecondes != null) 'lastSeen': _maintenant - ilYaSecondes * 1000,
  if (battement != null) 'battement': battement,
};

bool _enLigne(Object? noeud) =>
    OnlineStatusService.estEnLigne(noeud, maintenantServeurMs: _maintenant);

void main() {
  group('Règle « En ligne » d\'un nouveau client (champ battement)', () {
    test('le battement est de 20 s, la fraîcheur de 55 s', () {
      // Moins d'une minute : c'est le filet quand l'app est gelée avant
      // d'avoir écrit « hors ligne » — onDisconnect, lui, prenait ~95 s.
      expect(OnlineStatusService.battement, const Duration(seconds: 20));
      expect(OnlineStatusService.fraicheurPour(20), const Duration(seconds: 55));
    });

    test('battement récent : en ligne', () {
      expect(_enLigne(_noeud(ilYaSecondes: 10, battement: 20)), isTrue);
    });

    test('deux battements manqués + marge (55 s) : encore en ligne', () {
      expect(_enLigne(_noeud(ilYaSecondes: 55, battement: 20)), isTrue);
    });

    test('au-delà : hors ligne, même si isOnline est resté à vrai', () {
      // Le cas du mode avion ou de l'app gelée : `_setOffline` n'a pas pu
      // partir, et `onDisconnect` n'a pas encore joué.
      expect(_enLigne(_noeud(ilYaSecondes: 56, battement: 20)), isFalse);
      expect(_enLigne(_noeud(ilYaSecondes: 600, battement: 20)), isFalse);
    });

    test('isOnline faux : hors ligne, quel que soit lastSeen', () {
      expect(
        _enLigne(_noeud(isOnline: false, ilYaSecondes: 1, battement: 20)),
        isFalse,
      );
    });

    test('battement sans lastSeen : hors ligne (nœud incohérent)', () {
      expect(_enLigne(_noeud(battement: 20)), isFalse);
    });

    test('la fraîcheur suit la période annoncée par le nœud', () {
      expect(_enLigne(_noeud(ilYaSecondes: 120, battement: 60)), isTrue);
      expect(_enLigne(_noeud(ilYaSecondes: 136, battement: 60)), isFalse);
    });
  });

  group('Ancien client (sans battement) : l\'ancienne règle', () {
    // Un client d'avant réécrit le nœud entier, sans ce champ : il ne
    // rafraîchit jamais lastSeen. Lui appliquer la fraîcheur l'afficherait
    // hors ligne alors qu'il est là.
    test('isOnline vrai et lastSeen ancien : toujours en ligne', () {
      expect(_enLigne(_noeud(ilYaSecondes: 3600)), isTrue);
    });

    test('isOnline faux : hors ligne', () {
      expect(_enLigne(_noeud(isOnline: false, ilYaSecondes: 5)), isFalse);
    });

    test('nœud absent ou illisible : hors ligne', () {
      expect(_enLigne(null), isFalse);
      expect(_enLigne('true'), isFalse);
    });
  });

  group('Câblage du service', () {
    final src = File(
      'lib/core/services/online_status_service.dart',
    ).readAsStringSync();

    test('le battement écrit dans RTDB, avec la période', () {
      expect(src, contains("'battement': battement.inSeconds"));
      expect(src, contains('await ref.update(_noeudEnLigne)'));
      expect(src, contains('Timer.periodic(battement'));
    });

    test('la lecture juge le nœud entier, et se réévalue avec le temps', () {
      final debut = src.indexOf('Stream<bool> getUserOnlineStatus(');
      final corps = src.substring(debut, src.indexOf('Stream<DateTime?> getUserLastSeen('));
      expect(corps, contains("_database.ref('presence/\$userId').onValue"));
      expect(corps, contains('estEnLigne(noeud, maintenantServeurMs:'));
      expect(corps, contains('Timer.periodic('));
      expect(corps, isNot(contains('/isOnline')));
    });

    test('l\'heure de référence est celle du serveur', () {
      expect(src, contains("'.info/serverTimeOffset'"));
    });

    test('le cycle de vie passe par la file, et l\'arrière-plan ne met pas en ligne',
        () {
      final debut = src.indexOf('void _handleLifecycleStateChange(');
      final corps = src.substring(debut, src.indexOf('Timer? _heartbeatTimer;'));
      expect(corps, contains('_enFile(() => _setOnline(userId))'));
      expect(corps, contains('_enFile(() => _setOffline(userId))'));
      expect(src, contains('if (_auPremierPlan) await _enFile(() => _setOnline(userId));'));
    });
  });

  group('Passage en arrière-plan (mesuré le 2026-09-22 : 3 sur 3 restaient '
      '« en ligne » ~95 s)', () {
    test('seul `resumed` met en ligne ; `inactive` ne fait rien', () {
      // `inactive` précède `hidden` sur le chemin de l'arrière-plan : y
      // écrire « en ligne » envoyait un true au moment où l'app s'en allait,
      // arrivé après le false deux fois sur trois.
      expect(OnlineStatusService.presencePour(AppLifecycleState.resumed), isTrue);
      expect(OnlineStatusService.presencePour(AppLifecycleState.inactive), isNull);
      expect(OnlineStatusService.presencePour(AppLifecycleState.hidden), isFalse);
      expect(OnlineStatusService.presencePour(AppLifecycleState.paused), isFalse);
      expect(OnlineStatusService.presencePour(AppLifecycleState.detached), isFalse);
    });

    final src = File(
      'lib/core/services/online_status_service.dart',
    ).readAsStringSync();

    String corps(String signature) {
      final debut = src.indexOf(signature);
      final fin = src.indexOf(RegExp(r'\n  (Future|void|Stream|static|Timer|bool)'), debut + 10);
      return src.substring(debut, fin);
    }

    test('passer en ligne n\'attend plus le réseau avant d\'écrire', () {
      final enLigne = corps('Future<void> _setOnline(String userId)');
      expect(enLigne, contains('_visibleEnMemoire ??= await _showOnlineStatus'));
      expect(enLigne, contains('unawaited(_persistStatus(userId, isOnline: true))'));
      expect(enLigne, isNot(contains('await _persistStatus(')));
    });

    test('le miroir Supabase du hors-ligne ne retient pas la file', () {
      final horsLigne = corps('Future<void> _setOffline(String userId)');
      expect(horsLigne, contains('unawaited(_persistStatus(userId, isOnline: false))'));
      expect(horsLigne, isNot(contains('await _persistStatus(')));
    });

    test('la préférence en mémoire suit le réglage et s\'oublie à la déconnexion',
        () {
      expect(src, contains('_visibleEnMemoire = showStatus;'));
      expect(corps('Future<void> _teardownPresence()'),
          contains('_visibleEnMemoire = null;'));
    });
  });
}
