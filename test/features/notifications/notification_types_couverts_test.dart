import 'dart:io';

import 'package:diaspo_niger/features/notifications/domain/entities/notification_entity.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ce que ce banc protège
/// ----------------------
/// Un type écrit en base mais absent de `NotificationType` ne casse rien : il
/// est **replié sur `general`** par `_parseNotificationType`. La notification
/// s'affiche, sous le libellé « Général », et son appui ouvre la fiche au lieu
/// du contenu. Aucune erreur, nulle part.
///
/// C'est arrivé deux fois. Une première pour le fil (`newPost`, `mentioned`,
/// `groupMention`…), corrigée en son temps. Une seconde, trouvée le
/// 2026-09-16 : `postLiked`, `postReposted`, `system` — dont les 37 lignes de
/// l'annonce du 2026-09-15 —, et treize types émis par les Cloud Functions.
///
/// Le banc relit donc les ÉCRIVAINS, pas une liste tenue à la main.
///
/// Les types sont normalisés en chameau avant comparaison : les déclencheurs
/// SQL écrivent en serpent (`new_post`), le client en chameau
/// (`friendRequest`), et `_parseNotificationType` accepte les deux.
String _chameau(String v) {
  if (!v.contains('_')) return v;
  final parts = v.split('_').where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return v;
  return parts.first +
      parts.skip(1).map((p) => p[0].toUpperCase() + p.substring(1)).join();
}

String _lire(String chemin) =>
    File(chemin).readAsStringSync().replaceAll('\r\n', '\n');

/// Ce qui ressemble à un type mais n'en est pas un.
///
/// Chaque entrée porte sa raison : sans ça, la liste devient l'endroit où l'on
/// range ce qu'on n'a pas su expliquer, et le banc ne protège plus rien.
const _pasDesTypes = <String, String>{
  // Charges FCM envoyées directement à l'appareil (`sendToDevice`), sans
  // jamais passer par une ligne `notifications` : l'app les intercepte dans
  // `_handleForegroundMessage` avant tout affichage.
  'incomingCall': 'charge FCM d\'appel entrant, pas une ligne notifications',
  'callStatus': 'charge FCM de changement d\'état d\'appel',
  'notificationDismiss': 'charge FCM de synchronisation multi-appareils',
  'mention': 'champ `type` d\'une entrée de mention dans un post, pas une notification',
  // Valeurs comparées, pas écrites : `CASE WHEN NEW.status = 'approved'`,
  // `newStatus === "completed" ? …`.
  'approved': 'valeur comparée dans un CASE WHEN, pas un type écrit',
  'completed': 'valeur comparée dans un ternaire, pas un type écrit',
  'rejected': 'valeur comparée dans un CASE WHEN, pas un type écrit',
};

/// Les types écrits par le dépôt, avec l'endroit qui les écrit.
Map<String, Set<String>> _typesEmis() {
  final emis = <String, Set<String>>{};
  void note(String type, String ou) =>
      emis.putIfAbsent(_chameau(type), () => <String>{}).add(ou);

  // --- Dart : le client ------------------------------------------------
  for (final f in Directory('lib').listSync(recursive: true)) {
    if (f is! File || !f.path.endsWith('.dart')) continue;
    final s = _lire(f.path);
    final nom = f.uri.pathSegments.last;
    for (final motif in [
      RegExp(r"createNotification\((?:[\s\S]{0,600}?)type:\s*'([A-Za-z_]+)'"),
      RegExp(r"_notifyPostAuthor\((?:[\s\S]{0,400}?)type:\s*'([A-Za-z_]+)'"),
      RegExp(r"'p_type':\s*'([A-Za-z_]+)'"),
    ]) {
      for (final m in motif.allMatches(s)) {
        note(m.group(1)!, 'dart:$nom');
      }
    }
  }

  // --- SQL : les déclencheurs et les fonctions --------------------------
  //
  // Le `type` est la 2e valeur du tuple `VALUES`. On ne cherche donc les
  // littéraux QUE dans la partie qui précède `jsonb_build_object` — au-delà,
  // ce sont les clés de `data` — et on écarte ceux qui portent un espace ou un
  // accent : ce sont les `title` et `body` écrits en dur.
  final debutInsert =
      RegExp(r'INSERT INTO (?:public\.)?notifications\s*\([^)]*\)\s*VALUES',
          caseSensitive: false);
  for (final f in Directory('supabase/migrations').listSync()) {
    if (f is! File || !f.path.endsWith('.sql')) continue;
    final s = _lire(f.path);
    final nom = f.uri.pathSegments.last;
    for (final m in debutInsert.allMatches(s)) {
      var zone = s.substring(m.end, (m.end + 800).clamp(0, s.length));
      final data = zone.indexOf('jsonb_build_object');
      if (data > 0) zone = zone.substring(0, data);
      for (final lit in RegExp(r"'([A-Za-z][A-Za-z_]*)'").allMatches(zone)) {
        // Le littéral doit occuper une PLACE d'élément dans le tuple : précédé
        // de `(`, de `,` ou de `THEN`, et suivi de `,`, `ELSE` ou `END`.
        //
        // Sans cette double borne, trois choses passaient pour des types :
        // `v_group->>'name'` (une clé JSON dans le titre), `'Quelqu''un …'`
        // (le `''` coupe la chaîne en deux, et « un » ressemble à un type), et
        // `NEW.status = 'approved'` (une comparaison).
        final avant = zone.substring(0, lit.start).trimRight();
        final apres = zone.substring(lit.end).trimLeft();
        final placeDebut = avant.endsWith('(') ||
            avant.endsWith(',') ||
            avant.toUpperCase().endsWith('THEN');
        final placeFin = apres.startsWith(',') ||
            apres.toUpperCase().startsWith('ELSE') ||
            apres.toUpperCase().startsWith('END');
        if (!placeDebut || !placeFin) continue;
        note(lit.group(1)!, 'sql:$nom');
      }
    }
  }

  // --- Cloud Functions ---------------------------------------------------
  //
  // Un objet de notification porte toujours `isRead` (ou passe par le helper
  // `createNotification`, qui le pose). C'est ce qui le distingue d'une charge
  // FCM, qui a aussi un `type`, un `title` et un `body`.
  final js = _lire('functions/index.js');
  for (final m in RegExp(r'\btype:\s*([^\n]{0,140})').allMatches(js)) {
    final debut = (m.start - 600).clamp(0, js.length);
    final fin = (m.start + 600).clamp(0, js.length);
    final contexte = js.substring(debut, fin);
    if (!contexte.contains('isRead') && !contexte.contains('createNotification(')) {
      continue;
    }
    for (final lit in RegExp(r'"([A-Za-z_]+)"').allMatches(m.group(1)!)) {
      note(lit.group(1)!, 'cf:index.js');
    }
  }

  return emis;
}

void main() {
  final connus = NotificationType.values.map((t) => t.name).toSet();

  group('tout type écrit existe dans l\'énumération', () {
    test('aucun écrivain ne produit un type qui se replierait sur `general`', () {
      final emis = _typesEmis();
      final inconnus = <String, Set<String>>{};
      emis.forEach((type, ou) {
        if (connus.contains(type)) return;
        if (_pasDesTypes.containsKey(type)) return;
        inconnus[type] = ou;
      });

      expect(
        inconnus,
        isEmpty,
        reason: 'Ces types sont écrits mais absents de NotificationType : ils '
            'seront affichés « Général » et leur appui n\'ouvrira pas le '
            'contenu. Les ajouter à l\'énumération (libellé, icône, teinte, '
            'navigation), ou les déclarer dans `_pasDesTypes` avec la raison.'
            '\n$inconnus',
      );
    });

    test('le banc voit bien les écrivains — sinon il ne prouve rien', () {
      // Une expression régulière qui ne trouve plus rien passerait « au vert »
      // en ne protégeant plus personne. On exige donc de retrouver un témoin
      // par famille d'écrivain.
      final emis = _typesEmis();
      expect(emis['postLiked'], contains('dart:feed_provider.dart'));
      expect(emis['friendRequest'],
          contains('dart:friend_repository_impl.dart'));
      expect(emis['newPost']?.any((o) => o.startsWith('sql:')), isTrue);
      expect(emis['officialGroupLeave']?.any((o) => o.startsWith('sql:')), isTrue);
      expect(emis['missedCall'], contains('cf:index.js'));
      expect(emis.length, greaterThan(25));
    });

    test('`system` en fait partie — 37 lignes en production le disaient', () {
      expect(connus, contains('system'));
      expect(NotificationType.system.label, 'Message système');
    });

    test('tout appel direct à la RPC écrit les DEUX clés de cible', () {
      // `NotificationService.createNotification` les pose pour ses douze
      // appelants. Ceux qui appellent `create_user_notification` en direct
      // doivent le faire eux-mêmes : `fromRow` essaie `targetId` puis
      // `target_id`, et `NotificationReadSync` ne sait marquer lue qu'une
      // notification dont il retrouve la cible.
      //
      // `report_resolved` n'en portait aucune : sa notification restait non
      // lue pour toujours, sans que rien ne le signale.
      final fautifs = <String>[];
      for (final f in Directory('lib').listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        final s = _lire(f.path);
        for (final m in RegExp(r"'p_type':").allMatches(s)) {
          final zone = s.substring(m.start, (m.start + 1400).clamp(0, s.length));
          final donnees = zone.indexOf("'p_data'");
          if (donnees < 0) continue;
          final bloc = zone.substring(donnees);
          if (!bloc.contains("'targetId'") || !bloc.contains("'target_id'")) {
            fautifs.add(f.uri.pathSegments.last);
          }
        }
      }
      expect(fautifs, isEmpty,
          reason: 'appels RPC sans les deux clés de cible : $fautifs');
    });

    test('les deux types du fil ouvrent la publication', () {
      final ecran = _lire(
          'lib/features/notifications/presentation/screens/notifications_screen.dart');
      final i = ecran.indexOf('case NotificationType.postLiked:');
      expect(i, greaterThan(-1));
      // Ils doivent tomber dans la branche du fil, pas dans celle qui ouvre la
      // fiche de la notification.
      expect(ecran.substring(i, i + 260), contains("context.push('/feed/"));
    });
  });
}
