import 'dart:io';

import 'package:diaspo_niger/core/services/notification_pref_keys.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ce que ce banc protège
/// ----------------------
/// Une bascule de réglages traverse **deux** décisions, prises par deux
/// programmes différents : l'app décide de l'AFFICHAGE au premier plan
/// (`_shouldShowNotification`), `send-push` décide de l'ENVOI (`prefKeyFor`).
///
/// Tant que la règle était recopiée des deux côtés, elle a divergé — sept
/// types au 2026-09-16, dans les deux sens. Le symptôme n'est jamais une
/// erreur : c'est une bascule qui coupe app fermée mais pas app ouverte, ou
/// l'inverse. Irreproductible pour qui ne sait pas que ce sont deux chemins.
///
/// La table Dart fait foi ; la table TypeScript en est le reflet. Ce banc les
/// compare, entrée par entrée et dans l'ordre.
String _lire(String chemin) =>
    File(chemin).readAsStringSync().replaceAll('\r\n', '\n');

/// Les couples `'type': 'cle',` d'un fichier, dans l'ordre du source.
///
/// Rendus sous forme `type=cle` : `MapEntry` n'a pas d'égalité de valeur, et
/// deux listes identiques échouent alors à se comparer — le message d'échec
/// affiche deux fois la même chose, ce qui est pire qu'inutile.
List<String> _table(String source, String depuis) {
  final corps = source.substring(source.indexOf(depuis));
  final fin = corps.indexOf('\n}');
  return RegExp(r"'([A-Za-z]+)':\s*'([a-z_]+)',")
      .allMatches(corps.substring(0, fin))
      .map((m) => '${m.group(1)}=${m.group(2)}')
      .toList();
}

void main() {
  const dart = 'lib/core/services/notification_pref_keys.dart';
  const ts = 'supabase/functions/send-push/index.ts';
  const service = 'lib/core/services/notification_service.dart';
  const prefs = 'lib/core/services/preferences_service.dart';

  group('la règle des préférences est la même des deux côtés', () {
    test('Dart et TypeScript portent la même table, dans le même ordre', () {
      final cotesDart = _table(_lire(dart), 'kClePreferenceParType = {');
      final cotesTs = _table(_lire(ts), 'CLE_PREFERENCE_PAR_TYPE: Record<string, string> = {');
      expect(cotesTs, cotesDart,
          reason: 'send-push doit refléter kClePreferenceParType à la lettre');
      expect(cotesDart.length, greaterThan(35));
    });

    test('la table Dart chargée est bien celle du fichier', () {
      // Sans ça, le banc comparerait deux fichiers texte sans jamais vérifier
      // que le code s'en sert.
      final duFichier = {
        for (final couple in _table(_lire(dart), 'kClePreferenceParType = {'))
          couple.split('=').first: couple.split('=').last,
      };
      expect(kClePreferenceParType, duFichier);
    });

    test('l\'app ne garde pas un `switch` parallèle', () {
      // C'est la copie qui avait divergé : elle ne doit pas revenir.
      final source = _lire(service);
      final i = source.indexOf('Future<bool> _shouldShowNotification(');
      expect(i, greaterThan(-1));
      final corps = source.substring(i, source.indexOf('\n  }', i));
      expect(corps, contains('kClePreferenceParType[type]'));
      expect(corps.contains('switch (type)'), isFalse,
          reason: 'la règle vit dans la table, pas dans un switch');
    });

    test('chaque clé a bien une préférence qui la porte', () {
      // `send-push` lit `users.notification_prefs`, que
      // `PreferencesService.notificationTypePrefs` recopie. Une clé absente de
      // ce miroir n'arriverait jamais au serveur : la bascule ne couperait
      // alors que l'affichage, le défaut d'origine de tout ce chantier.
      final miroir = _lire(prefs);
      final zone = miroir.substring(miroir.indexOf('notificationTypePrefs => {'));
      final portees = RegExp(r"'([a-z_]+)':")
          .allMatches(zone.substring(0, zone.indexOf('\n  };')))
          .map((m) => m.group(1)!)
          .toSet();
      final manquantes =
          kClePreferenceParType.values.toSet().difference(portees);
      expect(manquantes, isEmpty,
          reason: 'clés sans miroir dans notificationTypePrefs : $manquantes');
    });

    test('les sept divergences relevées le 2026-09-16 sont couvertes', () {
      // Nommées une par une : une table qui les reperdrait repasserait au vert
      // sur les tests génériques ci-dessus, puisqu'elle resterait symétrique.
      expect(kClePreferenceParType['friendAccepted'], 'friend_requests');
      expect(kClePreferenceParType['newFollower'], 'friend_requests');
      expect(kClePreferenceParType['eventAttendance'], 'events');
      expect(kClePreferenceParType['localEvent'], 'local_events');
      expect(kClePreferenceParType['system'], 'system_messages');
      expect(kClePreferenceParType['officialGroupLeave'], 'groups');
      expect(kClePreferenceParType['cityGroupInvite'], 'groups');
    });

    test('`general` reste hors de la table', () {
      // C'est le type de repli de `_parseNotificationType` : le rendre
      // filtrable permettrait d'éteindre par erreur tout ce qui n'a pas encore
      // de type propre.
      expect(kClePreferenceParType.containsKey('general'), isFalse);
    });
  });
}
