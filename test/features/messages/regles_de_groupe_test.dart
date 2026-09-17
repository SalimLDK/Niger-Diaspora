import 'dart:io';

import 'package:diaspo_niger/features/messages/domain/entities/message_entity.dart';
import 'package:diaspo_niger/features/messages/presentation/screens/conversation_screen.dart';
import 'package:diaspo_niger/features/messages/presentation/utils/accuse_de_groupe.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ce que ces tests protègent
/// --------------------------
/// Étape C du plan du séparateur : les règles propres aux groupes.
///
/// 1. **Rien d'avant mon arrivée ne compte comme non lu.** Mesuré le
///    2026-09-17 : trois membres d'un groupe de 26 voyaient 7, 4 et 3 messages
///    d'avant leur arrivée comptés non lus, et le séparateur se posait dessus.
///    Tenu côté serveur (`tools/rls_tests/groupes_non_lus.sql`), et ici par le
///    texte de la migration.
/// 2. **Les messages système ne comptent pas.** `sendSystemMessage` écrit
///    l'expéditeur `system` ; `_updateConversationLastMessage` incrémentait
///    alors la pastille de TOUS les participants, l'auteur du geste compris.
/// 3. **« Lu » en groupe attend tous les membres présents**, arrivés avant le
///    message. Un membre parti ne bloque rien. Dans la liste, la tuile passait
///    au vert dès que le PREMIER autre membre venu avait lu.
/// 4. **Une écriture par lot vu, jamais une par message** — en groupe, le coût
///    se multiplie par le nombre de lecteurs.
String _lire(String chemin) =>
    File(chemin).readAsStringSync().replaceAll('\r\n', '\n');

final _t0 = DateTime.utc(2026, 9, 17, 12);

MessageEntity _m(
  String id,
  String expediteur, {
  int minutes = 0,
  MessageType type = MessageType.text,
  List<String> lu = const [],
}) =>
    MessageEntity(
      id: id,
      senderId: expediteur,
      senderName: expediteur,
      content: id,
      type: type,
      status: MessageStatus.sent,
      createdAt: _t0.add(Duration(minutes: minutes)),
      readBy: lu,
    );

void main() {
  group('C.2 — les messages système', () {
    test('le type OU l\'expéditeur « system » font un message système', () {
      expect(_m('a', 'x', type: MessageType.system).isSystem, isTrue);
      expect(_m('b', 'system').isSystem, isTrue, reason: 'mal typé, mais système');
      expect(_m('c', 'x').isSystem, isFalse);
    });

    test('un message système mal typé ne compte pas comme non lu', () {
      final fil = [_m('retrait', 'system'), _m('vrai', 'autre', minutes: 1)];
      final r = compterNonLus(fil, 'moi');
      expect(r.nombre, 1);
      expect(r.premier, 1, reason: 'le séparateur ne se pose jamais sur lui');
    });

    test('ni dans le repli par date, ni dans le repli par rang', () {
      final fil = [_m('retrait', 'system', minutes: 5), _m('vrai', 'autre', minutes: 6)];
      expect(compterDepuis(fil, 'moi', _t0).nombre, 1);
      expect(rangDesDerniersDAutrui(fil, 'moi', 2), isNull);
    });

    test('et il ne porte jamais le curseur', () {
      final cible = plusRecentALire([_m('vrai', 'autre'), _m('retrait', 'system', minutes: 9)], moi: 'moi');
      expect(cible?.id, 'vrai');
    });

    test('un message système n\'incrémente plus la pastille de personne', () {
      final source = _lire('lib/features/messages/data/datasources/message_supabase_datasource.dart');
      final debut = source.indexOf('Future<void> _updateConversationLastMessage(');
      final corps = source.substring(debut, source.indexOf('// 3. Merge update', debut));
      expect(corps, contains("final estSysteme = senderId == 'system' || type == 'system';"));
      expect(corps, contains('if (!estSysteme && pid != senderId) {'));
    });
  });

  group('C.3 — « Lu » en groupe', () {
    final message = _m('msg', 'moi', minutes: 10);

    test('attendus : présents, arrivés avant le message, hors expéditeur', () {
      final attendus = lecteursAttendus(
        message,
        membres: const ['moi', 'ancien_membre', 'nouveau', 'inconnu'],
        arrivees: {
          'ancien_membre': _t0,
          'nouveau': _t0.add(const Duration(minutes: 11)),
        },
      );
      expect(attendus, {'ancien_membre', 'inconnu'});
    });

    test('arrivé à l\'instant pile : pas attendu (même borne que le filtre privé)', () {
      final attendus = lecteursAttendus(
        message,
        membres: const ['pile'],
        arrivees: {'pile': message.createdAt},
      );
      expect(attendus, isEmpty);
    });

    test('tous les attendus ont lu : lu ; un de moins : pas lu', () {
      expect(tousOntLu(const ['a', 'b'], {'a', 'b'}), isTrue);
      expect(tousOntLu(const ['a'], {'a', 'b'}), isFalse);
    });

    test('un membre parti qui avait lu ne change rien', () {
      expect(tousOntLu(const ['a', 'parti'], {'a'}), isTrue);
    });

    test('personne d\'attendu, ou membres inconnus : jamais « Lu »', () {
      expect(tousOntLu(const ['a'], const {}), isFalse);
      expect(tousOntLu(const ['a'], null), isFalse);
    });

    test('l\'écran passe les attendus du groupe à la bulle', () {
      final source = _lire('lib/features/messages/presentation/screens/conversation_screen.dart');
      expect(source, contains('membres: groupForAdminCheck.memberIds,'));
      expect(source, contains('groupForAdminCheck.memberJoinedAt,'));
      expect(source, contains('lecteursAttendus:\n                                _isGroup && isMe'));
    });

    test('la tuile d\'un groupe n\'attend plus un seul membre pris au hasard', () {
      final source = _lire('lib/features/messages/presentation/widgets/conversation_item.dart');
      final debut = source.indexOf('Widget _buildStatusIcon(');
      final corps = source.substring(debut, source.indexOf('\n  }\n', debut));
      expect(corps, contains('final isRead = estGroupe\n            ? tousOntLu(readBy, {'));
    });
  });

  group('C.4 — une écriture par lot vu', () {
    late String ecran;
    setUpAll(() => ecran = _lire('lib/features/messages/presentation/screens/conversation_screen.dart'));

    test('les bulles vues se regroupent derrière UN seul envoi différé', () {
      final debut = ecran.indexOf('void _attendreAvantDeLire(MessageEntity message) {');
      final corps = ecran.substring(debut, ecran.indexOf('void _lireCeQuiEstALEcran()', debut));
      // Un seul minuteur d'envoi pour tout l'écran : chaque bulle vue le
      // repousse au lieu d'en créer un.
      expect(corps, contains('_envoiCurseur?.cancel();'));
      expect(corps, contains('_envoiCurseur = Timer(_delaiAvantEnvoi, _pousserCurseur);'));
      expect(ecran, contains('Timer? _envoiCurseur;'));
    });

    test('un envoi : au plus une écriture par magasin', () {
      final debut = ecran.indexOf('Future<void> _pousserCurseur() async {');
      final corps = ecran.substring(debut, ecran.indexOf('final SuiviDesNonLus _suivi', debut));
      expect('.avancerJusqua('.allMatches(corps).length, 1);
      expect('avancerCurseur('.allMatches(corps).length, 1);
    });

    test('côté serveur, un seul UPDATE pour tout le lot, sans boucle', () {
      final sql = _lire('supabase/migrations/20260917003700_groupes_non_lus_depuis_l_arrivee.sql');
      final debut = sql.indexOf('CREATE OR REPLACE FUNCTION public.marquer_lus_jusqua(');
      final corps = sql.substring(debut, sql.indexOf(r'$$;', sql.indexOf(r'AS $$', debut) + 5));
      expect(RegExp(r'\bLOOP\b').hasMatch(corps), isFalse);
      expect(RegExp(r'\bFOR\s+\w+\s+IN\b').hasMatch(corps), isFalse);
      expect('UPDATE messages m'.allMatches(corps).length, 1);
    });
  });

  group('C.1 — la migration borne tout à l\'arrivée', () {
    late String sql;
    setUpAll(() => sql = _lire('supabase/migrations/20260917003700_groupes_non_lus_depuis_l_arrivee.sql'));

    String corpsDe(String signature) {
      final debut = sql.indexOf(signature);
      expect(debut, isNot(-1), reason: signature);
      return sql.substring(debut, sql.indexOf(r'$$;', sql.indexOf(r'AS $$', debut) + 5));
    }

    test('repere_de_lecture : les deux magasins bornés', () {
      final corps = corpsDe('CREATE OR REPLACE FUNCTION public.repere_de_lecture(');
      expect(corps, contains("AND m.created_at > COALESCE(v_arrivee, '-infinity'::timestamptz)"));
      expect(corps, contains("AND mm.created_at > COALESCE(v_arrivee, '-infinity'::timestamptz)"));
      expect(corps, contains("AND m.sender_id <> 'system'"));
      // La colonne du dernier non-lu (étape B) ne doit pas se perdre.
      expect(corps, contains('dernier_non_lu_a  TIMESTAMPTZ'));
    });

    test('marquer_lus_jusqua : le recompte borné, pas le marquage', () {
      final corps = corpsDe('CREATE OR REPLACE FUNCTION public.marquer_lus_jusqua(');
      final recompte = corps.indexOf('SELECT count(*)::INTEGER INTO v_reste');
      final borne = corps.indexOf("AND m.created_at > COALESCE(v_arrivee, '-infinity'::timestamptz)");
      expect(borne, greaterThan(recompte));
      expect(corps, contains('AND m.created_at <= v_borne'));
    });

    test('la date vient de group_members, sans cast qui casserait un id hérité', () {
      expect(sql, contains('JOIN group_members gm ON gm.group_id::text = c.group_id AND gm.user_id = v_uid'));
      expect(sql, isNot(contains('c.group_id::uuid')));
    });

    test('la vue garde security_invoker et ses droits', () {
      expect(sql, contains('CREATE OR REPLACE VIEW public.mls_unread_counts\nWITH (security_invoker = on) AS'));
      expect(sql, contains('AND (gm.joined_at IS NULL OR m.created_at > gm.joined_at)'));
      expect(sql, contains('REVOKE ALL ON public.mls_unread_counts FROM anon;'));
    });
  });
}
