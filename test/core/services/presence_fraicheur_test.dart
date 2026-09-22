// Vu sur deux téléphones le 2026-09-22 (build Play 1.2.2+26) :
// - un compte en mode avion, app fermée, restait « En ligne » chez l'autre
//   pendant plusieurs minutes ;
// - le même compte, app ouverte et utilisée, s'affichait « Vu il y a environ
//   2 minutes ».
// `isOnline` était cru sans condition, et le battement de 10 min n'écrivait
// que dans Supabase, que l'en-tête ne lit pas.
import 'dart:io';

import 'package:diaspo_niger/core/services/online_status_service.dart';
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
    test('battement récent : en ligne', () {
      expect(_enLigne(_noeud(ilYaSecondes: 20, battement: 60)), isTrue);
    });

    test('deux battements manqués + marge (150 s) : encore en ligne', () {
      expect(_enLigne(_noeud(ilYaSecondes: 150, battement: 60)), isTrue);
    });

    test('au-delà : hors ligne, même si isOnline est resté à vrai', () {
      // Le cas du mode avion : `_setOffline` n'a pas pu partir, et
      // `onDisconnect` n'a pas encore joué.
      expect(_enLigne(_noeud(ilYaSecondes: 151, battement: 60)), isFalse);
      expect(_enLigne(_noeud(ilYaSecondes: 600, battement: 60)), isFalse);
    });

    test('isOnline faux : hors ligne, quel que soit lastSeen', () {
      expect(
        _enLigne(_noeud(isOnline: false, ilYaSecondes: 1, battement: 60)),
        isFalse,
      );
    });

    test('battement sans lastSeen : hors ligne (nœud incohérent)', () {
      expect(_enLigne(_noeud(battement: 60)), isFalse);
    });

    test('la fraîcheur suit la période annoncée par le nœud', () {
      expect(OnlineStatusService.fraicheurPour(60), const Duration(seconds: 150));
      expect(_enLigne(_noeud(ilYaSecondes: 200, battement: 90)), isTrue);
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
}
